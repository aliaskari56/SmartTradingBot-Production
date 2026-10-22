double STB_ParsePendingEntryBufferPips(const string comment,const double fallback)
{
   int pos=StringFind(comment,"|EB");
   if(pos<0) return fallback;
   int start=pos+3;
   int end=StringFind(comment,"|",start);
   string raw=(end>=0 ? StringSubstr(comment,start,end-start)
                      : StringSubstr(comment,start));
   double value=StringToDouble(raw);
   return (MathIsValidNumber(value) && value>=0.0) ? value:fallback;
}

//+------------------------------------------------------------------+
//| STB_PendingTrail.mqh                                             |
//| Safe-integration Pending Trail service for SmartTradingBot.      |
//|                                                                  |
//| NOT an EA. NOT a Trade Manager.                                  |
//| This module OWNS the pre-trigger lifecycle of EVERY supported    |
//| pending type through ONE engine:                                 |
//|   BUY STOP / SELL STOP / BUY LIMIT / SELL LIMIT /                |
//|   BUY STOP-LIMIT / SELL STOP-LIMIT.                              |
//|   - ticket-based state (never symbol-only state)                 |
//|   - BUY STOP: each closed M5 low is tested as a favorable extreme|
//|   - SELL STOP: each closed M5 high is tested as a favorable extreme|
//|   - other pending types retain live Bid/Ask extreme trailing     |
//|   - broker validation via STB_PendingDistanceResolver            |
//|   - restart recovery (state rebuilt from terminal orders)        |
//|   - multi-ticket isolation                                       |
//|   - P4: this module only PROPOSES geometry. The single pending   |
//|     geometry writer is STB_ModifyPendingOrderGeometry() (EA).    |
//|   - P4: bounded time throttle + failure backoff per ticket.      |
//|   - P4: entry Step + monotonic trackedExtreme.                   |
//|   - trigger handoff: PENDING_TRIGGERED then                      |
//|     PENDING_TRAIL_STOPPED handoff=TRADE_MANAGEMENT               |
//|                                                                  |
//| After trigger this module MUST NOT touch the resulting position. |
//+------------------------------------------------------------------+
#ifndef _STB_PENDING_TRAIL_MQH
#define _STB_PENDING_TRAIL_MQH

//--- P4: proposal source + modify result classification -------------
enum ENUM_STB_PENDING_SRC
{
   STB_PEND_SRC_INITIAL=0,
   STB_PEND_SRC_TRAIL=1
};

enum ENUM_STB_PENDING_RESULT
{
   STB_PEND_RES_SUCCESS=0,
   STB_PEND_RES_NO_CHANGE=1,
   STB_PEND_RES_TEMPORARY_FAILURE=2,
   STB_PEND_RES_INVALID_STOPS=3,
   STB_PEND_RES_INVALID_PRICE=4,
   STB_PEND_RES_FREEZE_LEVEL=5,
   STB_PEND_RES_TOO_MANY_REQUESTS=6,
   STB_PEND_RES_ORDER_GONE=7,
   STB_PEND_RES_OTHER_FAILURE=8
};

//--- P4: bounded retry policy (never retry every tick) --------------
#define STB_PEND_TRAIL_COOLDOWN_SEC   2
#define STB_PEND_BACKOFF_1_SEC        5
#define STB_PEND_BACKOFF_2_SEC        15
#define STB_PEND_BACKOFF_3_SEC        60

//--- P4: pending geometry proposal (Entry and SL resolved apart) ----
struct STBPendingGeometryProposal
{
   bool   valid;
   double entry;
   double sl;
   double tp;
   int    source;
   string reason;
};

//--- Ticket-based pending trail state --------------------------------
struct STBPendingTrailState
{
   ulong    ticket;
   string   symbol;
   long     orderType;   // BUY/SELL STOP, BUY/SELL LIMIT, STOP-LIMIT
   string   source;      // AUTO | UI_MANUAL | HEDGE | TERMINAL_SCAN | RESTART_RECOVERY
   double   trackedExtreme;
   double   lastEntry;
   double   lastSL;
   datetime lastModifyTime;
   datetime lastNoNewExtremeLogBar;
   datetime lastProcessedM5Bar; // latest closed M5 candle considered for STOP-order trailing
   datetime lastFailLogBar;
   int      lastProcessedCycle;
   double   entryBufferPips;
   double   slBufferPips;
   int      failureCount;   // P4 failure backoff counter
   datetime nextRetryTime;  // P4 earliest next modify attempt
   bool     active;
};

//--- Single central instance -----------------------------------------
STBPendingTrailState g_stbPendingTrail[];
int g_stbPendingTrailCycle=0;

int STB_PendingTrailFind(const ulong ticket)
{
   for(int i=0;i<ArraySize(g_stbPendingTrail);i++)
      if(g_stbPendingTrail[i].ticket==ticket)
         return i;

   return -1;
}

// Distinguish a filled order from cancelled/expired/rejected orders when it
// disappears from the live order pool. A missing live ticket alone is not proof
// that the pending order was triggered.
string STB_PendingTrailMissingOrderReason(const ulong ticket)
{
   if(!HistoryOrderSelect(ticket))
      return "ORDER_HISTORY_UNAVAILABLE";

   ENUM_ORDER_STATE state=
      (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket,ORDER_STATE);

   if(state==ORDER_STATE_FILLED)
      return "ORDER_FILLED";
   if(state==ORDER_STATE_CANCELED)
      return "ORDER_CANCELED";
   if(state==ORDER_STATE_EXPIRED)
      return "ORDER_EXPIRED";
   if(state==ORDER_STATE_REJECTED)
      return "ORDER_REJECTED";

   return "ORDER_STATE_"+EnumToString(state);
}

void STB_PendingTrailClear()
{
   ArrayResize(g_stbPendingTrail,0);
   g_stbPendingTrailCycle=0;
}

// Drop completed/cancelled order records. Without compaction, every historical
// pending ticket would remain in this per-cycle array for the EA's lifetime.
void STB_PendingTrailPruneInactive()
{
   for(int i=ArraySize(g_stbPendingTrail)-1;i>=0;i--)
      if(!g_stbPendingTrail[i].active)
         ArrayRemove(g_stbPendingTrail,i,1);
}

// Every supported pending geometry is managed by the same trail engine:
// BUY/SELL STOP, BUY/SELL LIMIT and BUY/SELL STOP-LIMIT.
bool STB_PendingTrailIsManagedType(const long orderType)
{
   return orderType==(long)ORDER_TYPE_BUY_STOP       ||
          orderType==(long)ORDER_TYPE_SELL_STOP      ||
          orderType==(long)ORDER_TYPE_BUY_LIMIT      ||
          orderType==(long)ORDER_TYPE_SELL_LIMIT     ||
          orderType==(long)ORDER_TYPE_BUY_STOP_LIMIT ||
          orderType==(long)ORDER_TYPE_SELL_STOP_LIMIT;
}

// +1 => BUY side (anchor = live Bid low), -1 => SELL side (anchor = live Ask high).
int STB_PendingTrailDirection(const long orderType)
{
   ENUM_ORDER_TYPE t=(ENUM_ORDER_TYPE)orderType;

   if(STB_PendingIsBuySide(t))
      return 1;

   if(STB_PendingIsSellSide(t))
      return -1;

   return 0;
}

string STB_PendingTrailTypeName(const long orderType)
{
   if(orderType==(long)ORDER_TYPE_BUY_STOP)
      return "BUY_STOP";

   if(orderType==(long)ORDER_TYPE_SELL_STOP)
      return "SELL_STOP";

   if(orderType==(long)ORDER_TYPE_BUY_LIMIT)
      return "BUY_LIMIT";

   if(orderType==(long)ORDER_TYPE_SELL_LIMIT)
      return "SELL_LIMIT";

   if(orderType==(long)ORDER_TYPE_BUY_STOP_LIMIT)
      return "BUY_STOP_LIMIT";

   if(orderType==(long)ORDER_TYPE_SELL_STOP_LIMIT)
      return "SELL_STOP_LIMIT";

   return "UNKNOWN";
}

//--- P4: classify the last modify outcome (policy only, no new logs) -
int STB_PendingClassifyResult(const bool ok)
{
   if(ok)
      return STB_PEND_RES_SUCCESS;

   uint ret=(uint)trade.ResultRetcode();

   switch(ret)
   {
      case TRADE_RETCODE_DONE:
         return STB_PEND_RES_SUCCESS;
      case TRADE_RETCODE_NO_CHANGES:
         return STB_PEND_RES_NO_CHANGE;
      case TRADE_RETCODE_INVALID_STOPS:
         return STB_PEND_RES_INVALID_STOPS;
      case TRADE_RETCODE_INVALID_PRICE:
         return STB_PEND_RES_INVALID_PRICE;
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         return STB_PEND_RES_TOO_MANY_REQUESTS;
      case TRADE_RETCODE_MARKET_CLOSED:
         return STB_PEND_RES_TEMPORARY_FAILURE;
   }

   return STB_PEND_RES_OTHER_FAILURE;
}

//--- Register a real terminal pending order --------------------------
// Called ONLY after the terminal confirmed the ticket. BUY STOP / SELL STOP
// state anchors use the latest closed M5 candle; other pending types retain
// their existing geometry/live-quote anchor and one-way trailing path.
// Universal intake: EA-created, manual/mobile, other-EA and restart-recovered
// tickets all register through this single entry point.
bool STB_PendingTrailRegister(const ulong ticket,const string source)
{
   if(ticket==0 || !OrderSelect(ticket) || !IsManagedOrder(ticket))
      return false;

   // Do not create partial Pending Trail state unless the shared exposure
   // registry can represent this terminal order. Later scan/reconcile passes
   // will retry registration if allocation is temporarily unavailable.
   if(STB_ExposureEnsure(ticket,false)<0)
     {
      Print("STB PENDING TRAIL REGISTER DEFERRED ticket=",ticket,
            " source=",source,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return false;
     }

   long orderType=OrderGetInteger(ORDER_TYPE);
   if(!STB_PendingTrailIsManagedType(orderType))
      return false;

   int existing=STB_PendingTrailFind(ticket);
   if(existing>=0)
   {
      if(!g_stbPendingTrail[existing].active)
      {
         g_stbPendingTrail[existing].active=true;
         g_stbPendingTrail[existing].source=source;
         g_stbPendingTrail[existing].lastProcessedCycle=-1;
      }
      return true;
   }

   string symbol=OrderGetString(ORDER_SYMBOL);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);

   if(symbol=="" || point<=0.0 || pip<=0.0)
      return false;

   string comment=OrderGetString(ORDER_COMMENT);
   double currentEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double currentSL=OrderGetDouble(ORDER_SL);

   // P4 EB contract: this EA writes the effective offset to the order comment.
   // For older manual/foreign orders without EB, infer a stable offset from
   // their current entry versus the appropriate live quote. This avoids
   // snapping an inherited order toward the EA's tiny default buffer.
   double fallbackEntryBufferPips=MathMax(0.0,InpEntryBufferPips);
   if(StringFind(comment,"|EB")<0 && currentEntry>0.0)
     {
      MqlTick currentTick;
      if(!SymbolInfoTick(symbol,currentTick) || pip<=0.0)
         return false;

      bool buySide=STB_PendingIsBuySide((ENUM_ORDER_TYPE)orderType);
      // The pending trail's canonical anchor is Bid for BUY-side orders and
      // Ask for SELL-side orders, regardless of STOP vs LIMIT geometry.
      double anchorQuote=buySide ? currentTick.bid:currentTick.ask;
      fallbackEntryBufferPips=MathAbs(currentEntry-anchorQuote)/pip;

      double minDistance=TradeMinDistance(symbol);
      if(minDistance>0.0)
         fallbackEntryBufferPips=MathMax(fallbackEntryBufferPips,
                                         minDistance/pip);
     }

   // Persisted manual authority means the user may have changed entry/SL/TP
   // since the original comment was written. On recovery, re-anchor to the
   // current geometry rather than trusting a stale historical EB value.
   double entryBufferPips=0.0;
   if(STB_ManualOverrideIs(ticket) || StringFind(comment,"|EB")<0)
      entryBufferPips=fallbackEntryBufferPips;
   else
      entryBufferPips=STB_ParsePendingEntryBufferPips(comment,
                                                     fallbackEntryBufferPips);

   if(entryBufferPips<0.0 || !MathIsValidNumber(entryBufferPips))
      return false;

   // P4 STB-002: the pending SL distance is the STRUCTURAL risk of the order
   // (|Entry-SL|), never an arbitrary constant. A constant could otherwise
   // expand risk beyond the structural floor. If the order has no SL yet the
   // trail may create the initial structural SL using the configured fallback.
   double structuralRiskPips=(currentEntry>0.0 && currentSL>0.0)
                             ? MathAbs(currentEntry-currentSL)/pip
                             : 0.0;

   // Pending protection is independent from whether live trailing is
   // disabled. If no SL exists yet, reserve a positive structural-buffer
   // fallback; the EA's initial-protection path must install the real SL.
   double slBufferPips=(structuralRiskPips>0.0)
                        ? structuralRiskPips
                        : MathMax(1.0,
                                  MathMax(InpInitialSLBufferPips,
                                          InpSLBufferPips));

   int direction=STB_PendingTrailDirection(orderType);
   int offSign  =STB_PendingEntryOffsetSign((ENUM_ORDER_TYPE)orderType);

   if(direction==0 || offSign==0)
      return false;

   // Recover the anchor extreme from the live pending geometry:
   //   entry = extreme + offSign*offset  =>  extreme = entry - offSign*offset.
   double inferredExtreme=currentEntry-offSign*entryBufferPips*pip;

   // Keep the anchor reconstructed from the CURRENT order geometry and its
   // EB offset. EB is defined against Bid for BUY-side orders and Ask for
   // SELL-side orders at registration/recovery. Unconditionally replacing this
   // anchor with a candle extreme combines an unrelated extreme with the EB
   // offset and can make the first trail proposal jump or fail broker geometry.
   // Actual STOP trailing still evaluates each NEW closed M5 low/high below.

   if(inferredExtreme<=0.0)
      return false;

   STBPendingTrailState st;
   ZeroMemory(st);

   st.ticket=ticket;
   st.symbol=symbol;
   st.orderType=orderType;
   st.source=source;
   st.trackedExtreme=inferredExtreme;
   st.lastEntry=currentEntry;
   st.lastSL=currentSL;
   st.lastModifyTime=0;
   st.lastNoNewExtremeLogBar=0;
   st.lastProcessedM5Bar=iTime(symbol,PERIOD_M5,1);
   st.lastFailLogBar=0;
   st.lastProcessedCycle=-1;
   st.entryBufferPips=entryBufferPips;
   st.slBufferPips=slBufferPips;
   st.failureCount=0;
   st.nextRetryTime=0;
   st.active=true;

   int n=ArraySize(g_stbPendingTrail);
   if(ArrayResize(g_stbPendingTrail,n+1)!=n+1)
     {
      Print("STB PENDING TRAIL STATE ALLOCATION FAILED ticket=",ticket,
            " source=",source,
            " requestedSize=",n+1);
      return false;
     }
   g_stbPendingTrail[n]=st;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   Print("PENDING_CREATED ticket=",IntegerToString((int)ticket),
         " symbol=",symbol,
         " type=",STB_PendingTrailTypeName(orderType),
         " source=",source,
         " trackedExtreme=",DoubleToString(st.trackedExtreme,digits),
         " entryBufferPips=",DoubleToString(st.entryBufferPips,4),
         " structuralRiskPips=",DoubleToString(st.slBufferPips,4),
         " entry=",DoubleToString(st.lastEntry,digits),
         " sl=",DoubleToString(st.lastSL,digits));

   STBPendingResolution res;
   bool distanceOK=
      STB_ResolvePendingDistance(symbol,
                                 (ENUM_ORDER_TYPE)st.orderType,
                                 st.trackedExtreme,
                                 st.entryBufferPips,
                                 res,
                                 st.slBufferPips);

   if(distanceOK && res.valid)
   {
      Print("PENDING_DISTANCE ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " entryOffset=",DoubleToString(res.entryOffset,digits),
            " slBuffer=",DoubleToString(res.slBuffer,digits),
            " brokerMinDistance=",DoubleToString(res.brokerMinDistance,digits));
   }

   return true;
}

//--- Rate-limited NO_NEW_EXTREME log --------------------------------
void STB_PendingTrailLogNoNewExtreme(const ulong ticket,
                                     const string symbol,
                                     const int logIdx)
{
   datetime bar=iTime(symbol,PERIOD_M15,1);

   if(bar<=0)
      bar=TimeCurrent();

   if(logIdx>=0 && g_stbPendingTrail[logIdx].lastNoNewExtremeLogBar==bar)
      return;

   if(logIdx>=0)
      g_stbPendingTrail[logIdx].lastNoNewExtremeLogBar=bar;

   Print("PENDING_TRAIL_NO_NEW_EXTREME ticket=",IntegerToString((int)ticket),
         " symbol=",symbol);
}

//--- P4 central submit gate: throttle + backoff + Step + state --------
// This gate NEVER talks to the broker. It applies the time throttle, the
// failure backoff and the meaningful Step gate, then forwards the proposal
// to the single pending geometry writer STB_ModifyPendingOrderGeometry().
// Returns true only when the writer confirmed the change.
bool STB_SubmitPendingTrailGeometry(const ulong ticket,
                                    const double propEntry,
                                    const double propSL,
                                    const double propTP,
                                    const bool manual=false)
{
   int idx=STB_PendingTrailFind(ticket);

   if(idx<0 || !g_stbPendingTrail[idx].active)
      return false;

   string symbol=g_stbPendingTrail[idx].symbol;
   double pip=PipSize(symbol);
   datetime now=TimeCurrent();

   // Time throttle: at most one modification per cooldown window.
   if(g_stbPendingTrail[idx].nextRetryTime>0 &&
      now<g_stbPendingTrail[idx].nextRetryTime)
      return false;

   if(g_stbPendingTrail[idx].lastModifyTime>0 &&
      now<g_stbPendingTrail[idx].lastModifyTime+STB_PEND_TRAIL_COOLDOWN_SEC)
      return false;

   // Step gate: skip a proposal whose protection improvement is below the
   // configured meaningful step (existing input, no new input introduced).
   if(OrderSelect(ticket) && pip>0.0)
   {
      double step=MathMax(0.0,InpTrailStepPips)*pip;
      double curEntry=OrderGetDouble(ORDER_PRICE_OPEN);
      double curSL=OrderGetDouble(ORDER_SL);

      if(step>0.0 &&
         MathAbs(propEntry-curEntry)<step &&
         MathAbs(propSL-curSL)<step)
         return false;
   }

   // Forward to the ONE central pending geometry writer.
   bool ok=STB_ModifyPendingOrderGeometry(ticket,propEntry,propSL,propTP,manual);
   int cls=STB_PendingClassifyResult(ok);

   if(ok)
   {
      if(manual)
         STB_ManualOverrideSet(ticket); // MANUAL_OVERRIDE: user PEND_TRAIL command is final
      // SUCCESS (or broker NO_CHANGE accepted): reset failure backoff.
      g_stbPendingTrail[idx].failureCount=0;
      g_stbPendingTrail[idx].nextRetryTime=0;
      g_stbPendingTrail[idx].lastModifyTime=TimeCurrent();

      if(OrderSelect(ticket))
      {
         g_stbPendingTrail[idx].lastEntry=OrderGetDouble(ORDER_PRICE_OPEN);
         g_stbPendingTrail[idx].lastSL=OrderGetDouble(ORDER_SL);
      }

      return true;
   }

   if(cls==STB_PEND_RES_ORDER_GONE)
   {
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   // Failure: bounded exponential-ish backoff. Never retry every tick.
   g_stbPendingTrail[idx].failureCount++;

   int fc=g_stbPendingTrail[idx].failureCount;
   int backoffSec=(fc<=1 ? STB_PEND_BACKOFF_1_SEC
                         : (fc==2 ? STB_PEND_BACKOFF_2_SEC
                                  : STB_PEND_BACKOFF_3_SEC));

   g_stbPendingTrail[idx].nextRetryTime=TimeCurrent()+backoffSec;

   return false;
}

//--- Proposal-only pipeline for ONE ticket ---------------------------
// Reads, verifies ownership, reads geometry, reads the tracked extreme,
// calculates a candidate, validates it and returns a PROPOSAL. It never
// calls the broker itself.
bool STB_PendingTrailManageOne(const ulong ticket,const bool manual=false)
{
   int idx=STB_PendingTrailFind(ticket);

   if(idx<0 || !g_stbPendingTrail[idx].active)
      return false;

   // Resolve terminal lifecycle before requiring the exposure registry.
   // A deleted/filled ticket must be retired even if registry allocation is
   // currently failing; otherwise stale active states can persist indefinitely.
   if(!OrderSelect(g_stbPendingTrail[idx].ticket))
   {
      // Terminal no longer exposes this order: filled (triggered),
      // cancelled or deleted. The trail stops here; the existing
      // STB Trade Manager owns any resulting position.
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=",STB_PendingTrailMissingOrderReason(ticket));
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   // If the shared registry becomes unavailable after registration, defer
   // processing before consuming bars or mutating trail state. The next
   // management cycle retries from the still-live terminal order.
   if(STB_ExposureEnsure(ticket,false)<0)
     {
      Print("STB PENDING TRAIL PROCESS DEFERRED ticket=",ticket,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return false;
     }

   if(!IsManagedOrder(ticket))
   {
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=OWNERSHIP_LOST");
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   // Only the terminal-wide symbol lease owner may evaluate/submit this
   // ticket. Other chart instances must defer silently rather than generate
   // a false SUBMIT failure for a writer request they are not authorized to make.
   string managedSymbol=OrderGetString(ORDER_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(managedSymbol))
      return true;

   // Honor retry backoff and the successful-write cooldown before rebuilding
   // an actionable-bar proposal. These are normal no-op states, not failures.
   if(g_stbPendingTrail[idx].nextRetryTime>TimeCurrent())
      return true;
   if(g_stbPendingTrail[idx].lastModifyTime>0 &&
      TimeCurrent()<g_stbPendingTrail[idx].lastModifyTime+
                   STB_PEND_TRAIL_COOLDOWN_SEC)
      return true;

   long orderType=OrderGetInteger(ORDER_TYPE);

   // Every supported pending type remains under automatic management,
   // including orders created or edited manually/from mobile. Manual-override
   // metadata is not a permanent opt-out from protective trailing.
   bool candleStop=(orderType==(long)ORDER_TYPE_BUY_STOP ||
                    orderType==(long)ORDER_TYPE_SELL_STOP);

   if(!STB_PendingTrailIsManagedType(orderType))
   {
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=ORDER_TYPE_CHANGED");
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   if(OrderGetString(ORDER_SYMBOL)!=g_stbPendingTrail[idx].symbol)
   {
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=SYMBOL_CHANGED");
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   // Initial structural protection owns unprotected pending orders. Do not
   // let the trail fallback silently install a generic fixed-distance SL.
   if(OrderGetDouble(ORDER_SL)<=0.0)
     {
      Print("PENDING_TRAIL_WAIT ticket=",ticket,
            " symbol=",g_stbPendingTrail[idx].symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=SL_NOT_INSTALLED");
      return true;
     }

   g_stbPendingTrail[idx].orderType=orderType;

   string symbol=g_stbPendingTrail[idx].symbol;
   int direction=STB_PendingTrailDirection(orderType);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);

   if(direction==0 || point<=0.0 || pip<=0.0)
     {
      Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=INVALID_SYMBOL_GEOMETRY",
            " direction=",direction,
            " point=",DoubleToString(point,10),
            " pip=",DoubleToString(pip,10));
      return true;
     }

   // 1) STOP orders use closed M5 structure, never the forming candle.
   // BUY STOP evaluates each closed candle's low; SELL STOP its high.
   // Candle body color is deliberately irrelevant: a wick can create the
   // favorable extreme. Other pending types retain live Bid/Ask behavior.
   double extreme=0.0;
   datetime actionableClosedBar=0;
   if(candleStop)
     {
      datetime closedBar=iTime(symbol,PERIOD_M5,1);
      if(closedBar<=0)
        {
         Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=M5_CLOSED_BAR_UNAVAILABLE");
         return true;
        }
      if(closedBar==g_stbPendingTrail[idx].lastProcessedM5Bar)
         return true;

      double barOpen=iOpen(symbol,PERIOD_M5,1);
      double barClose=iClose(symbol,PERIOD_M5,1);
      double barLow=iLow(symbol,PERIOD_M5,1);
      double barHigh=iHigh(symbol,PERIOD_M5,1);
      bool ohlcFinite=(MathIsValidNumber(barOpen) &&
                       MathIsValidNumber(barClose) &&
                       MathIsValidNumber(barLow) &&
                       MathIsValidNumber(barHigh));
      bool ohlcPositive=(barOpen>0.0 && barClose>0.0 &&
                         barLow>0.0 && barHigh>0.0);
      bool ohlcOrdered=(barLow<=barHigh &&
                        barLow<=MathMin(barOpen,barClose) &&
                        barHigh>=MathMax(barOpen,barClose));
      if(!ohlcFinite || !ohlcPositive || !ohlcOrdered)
        {
         Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=M5_OHLC_INVALID",
               " finite=",ohlcFinite,
               " positive=",ohlcPositive,
               " ordered=",ohlcOrdered,
               " open=",DoubleToString(barOpen,10),
               " close=",DoubleToString(barClose,10),
               " low=",DoubleToString(barLow,10),
               " high=",DoubleToString(barHigh,10));
         return true;
        }

      // Candle color is not a trailing criterion: a wick can set a valid
      // favorable extreme on either candle body color. The monotonic extreme
      // gate below decides whether the closed bar can improve the proposal.
      // Commit this bar only after a no-change decision or confirmed write;
      // resolver/writer failures leave it retryable under bounded backoff.
      actionableClosedBar=closedBar;
      extreme=(orderType==(long)ORDER_TYPE_BUY_STOP ? barLow:barHigh);
     }
   else
     {
      MqlTick liveTick;
      if(!SymbolInfoTick(symbol,liveTick))
        {
         Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=LIVE_TICK_UNAVAILABLE");
         return true;
        }
      extreme=(direction>0 ? liveTick.bid:liveTick.ask);
     }

   if(extreme<=0.0)
     {
      Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=EXTREME_INVALID",
            " extreme=",DoubleToString(extreme,10));
      return true;
     }

   // P4 monotonic trackedExtreme: BUY side only moves down, SELL side only up.
   bool isNewExtreme=false;

   if(direction>0)
      isNewExtreme=(extreme < g_stbPendingTrail[idx].trackedExtreme-point*0.5);
   else
      isNewExtreme=(extreme > g_stbPendingTrail[idx].trackedExtreme+point*0.5);

   if(!isNewExtreme)
   {
      // This closed candle produced no favorable new extreme. It is safe to
      // consume; a later candle will provide a new anchor.
      if(candleStop && actionableClosedBar>0)
         g_stbPendingTrail[idx].lastProcessedM5Bar=actionableClosedBar;

      Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=NO_NEW_EXTREME",
            " extreme=",DoubleToString(extreme,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " trackedExtreme=",DoubleToString(g_stbPendingTrail[idx].trackedExtreme,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      STB_PendingTrailLogNoNewExtreme(ticket,symbol,
                                      STB_PendingTrailFind(ticket));
      return true;
   }

   // 3) Build a PROPOSAL: resolve entry + SL via the immutable metadata.
   STBPendingResolution res;

   bool resolved=
      STB_ResolvePendingDistance(symbol,
                                 (ENUM_ORDER_TYPE)g_stbPendingTrail[idx].orderType,
                                 extreme,
                                 g_stbPendingTrail[idx].entryBufferPips,
                                 res,
                                 g_stbPendingTrail[idx].slBufferPips,
                                 STB_PendingIsStopKind((ENUM_ORDER_TYPE)g_stbPendingTrail[idx].orderType)
                                 ? OrderGetDouble(ORDER_PRICE_OPEN):0.0);

   // Do not fabricate a synthetic candle extreme merely to push a pending
   // STOP beyond the current market. If the true candle-derived geometry is
   // currently invalid, retain the real extreme and retry after bounded
   // backoff; the resolver will re-evaluate it against the latest quote.

   if(!resolved || !res.valid)
   {
      datetime bar=iTime(symbol,PERIOD_M15,1);

      if(bar<=0)
         bar=TimeCurrent();

      bool noFavorableEntry=
         (res.reason=="BUY_STOP_NO_FAVORABLE_VALID_ENTRY" ||
          res.reason=="SELL_STOP_NO_FAVORABLE_VALID_ENTRY");

      if(g_stbPendingTrail[idx].lastFailLogBar!=bar)
      {
         g_stbPendingTrail[idx].lastFailLogBar=bar;

         if(noFavorableEntry)
            Print("PENDING_TRAIL_WAIT ticket=",IntegerToString((int)ticket),
                  " symbol=",symbol,
                  " type=",STB_PendingTrailTypeName(orderType),
                  " reason=",res.reason,
                  " extreme=",DoubleToString(extreme,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                  " currentEntry=",DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN),
                                                   (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
         else
            Print("PENDING_TRAIL_MODIFY_FAILED ticket=",IntegerToString((int)ticket),
                  " symbol=",symbol,
                  " type=",STB_PendingTrailTypeName(orderType),
                  " stage=RESOLVE",
                  " reason=",res.reason);
      }

      // A no-favorable-entry condition is transient: retry at a short fixed
      // interval without treating it as repeated broker failure. Keep the bar
      // unconsumed so the same structural anchor can be re-evaluated if quotes
      // move back into a valid, monotonic geometry window.
      if(noFavorableEntry)
        {
         g_stbPendingTrail[idx].nextRetryTime=
            TimeCurrent()+STB_PEND_BACKOFF_1_SEC;
         return true;
        }

      // Other resolver failures retain bounded backoff. Retry with the same bounded 5/15/60s policy.
      // The actionable M5 bar remains unconsumed so broker geometry can recover.
      g_stbPendingTrail[idx].failureCount++;
      int fc=g_stbPendingTrail[idx].failureCount;
      int backoffSec=(fc<=1 ? STB_PEND_BACKOFF_1_SEC
                            : (fc==2 ? STB_PEND_BACKOFF_2_SEC
                                     : STB_PEND_BACKOFF_3_SEC));
      g_stbPendingTrail[idx].nextRetryTime=TimeCurrent()+backoffSec;
      return true;
   }

   STBPendingGeometryProposal prop;
   ZeroMemory(prop);
   prop.valid=true;
   prop.entry=res.entry;
   prop.sl=res.sl;
   prop.tp=OrderGetDouble(ORDER_TP);
   prop.source=STB_PEND_SRC_TRAIL;
   prop.reason=res.reason;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   // Apply the step gate before calling the submit wrapper for every
   // pending type. A step/cooldown no-op is not a failed broker modification.
   double currentEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double currentSL=OrderGetDouble(ORDER_SL);
   double step=MathMax(0.0,InpTrailStepPips)*pip;
   if(step>0.0 &&
      MathAbs(prop.entry-currentEntry)<step &&
      MathAbs(prop.sl-currentSL)<step)
     {
      if(candleStop && actionableClosedBar>0)
        {
         g_stbPendingTrail[idx].lastProcessedM5Bar=actionableClosedBar;
         Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=STEP_GATE",
               " entryDelta=",DoubleToString(MathAbs(prop.entry-currentEntry)/pip,2),
               " slDelta=",DoubleToString(MathAbs(prop.sl-currentSL)/pip,2),
               " stepPips=",DoubleToString(InpTrailStepPips,2));
        }
      return true;
     }

   // 4) Forward the proposal to the central submit gate. A failed broker
   //    write leaves the action bar unconsumed, so a later cycle can retry.
   ResetLastError();
   bool committed=STB_SubmitPendingTrailGeometry(ticket,
                                                 prop.entry,
                                                 prop.sl,
                                                 prop.tp,
                                                 manual);

   if(!committed)
     {
      int writerIdx=STB_PendingTrailFind(ticket);
      int failures=(writerIdx>=0 ? g_stbPendingTrail[writerIdx].failureCount:0);
      datetime retryAt=(writerIdx>=0 ? g_stbPendingTrail[writerIdx].nextRetryTime:0);
      Print("PENDING_TRAIL_MODIFY_FAILED ticket=",ticket,
            " symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " stage=SUBMIT",
            " proposedEntry=",DoubleToString(prop.entry,digits),
            " proposedSL=",DoubleToString(prop.sl,digits),
            " currentEntry=",DoubleToString(currentEntry,digits),
            " currentSL=",DoubleToString(currentSL,digits),
            " failureCount=",failures,
            " retryAt=",(string)retryAt,
            " writerOutcome=NOT_CONFIRMED");
     }

   if(committed)
   {
      if(candleStop && actionableClosedBar>0)
         g_stbPendingTrail[idx].lastProcessedM5Bar=actionableClosedBar;

      // P4: trackedExtreme advances only in the favorable direction.
      if(direction>0)
         g_stbPendingTrail[idx].trackedExtreme=
            MathMin(g_stbPendingTrail[idx].trackedExtreme,extreme);
      else
         g_stbPendingTrail[idx].trackedExtreme=
            MathMax(g_stbPendingTrail[idx].trackedExtreme,extreme);

      Print("PENDING_TRAIL_UPDATE ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " entry=",DoubleToString(prop.entry,digits),
            " sl=",DoubleToString(prop.sl,digits),
            " trackedExtreme=",DoubleToString(g_stbPendingTrail[idx].trackedExtreme,digits));
   }

   return true;
}

//--- Per-cycle processing (OnTick / OnTimer with cycle dedup) ---------
int STB_PendingTrailProcess(const bool manual=false)
{
   STB_PendingTrailPruneInactive();
   g_stbPendingTrailCycle++;
   int moved=0;

   // Registration pass: TERMINAL-SCAN every managed pending order type that
   // is not yet tracked (multi-ticket + manual/mobile/other-EA discovery).
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(!STB_PendingTrailIsManagedType(OrderGetInteger(ORDER_TYPE)))
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      if(STB_PendingTrailFind(ticket)>=0)
         continue;

      STB_PendingTrailRegister(ticket,"TERMINAL_SCAN");
   }

   // Manage pass: maximum ONE modify per ticket per cycle.
   for(int i=0;i<ArraySize(g_stbPendingTrail);i++)
   {
      if(!g_stbPendingTrail[i].active)
         continue;

      if(g_stbPendingTrail[i].lastProcessedCycle==g_stbPendingTrailCycle)
         continue;

      ulong ticket=g_stbPendingTrail[i].ticket;
      datetime previousModifyTime=g_stbPendingTrail[i].lastModifyTime;
      g_stbPendingTrail[i].lastProcessedCycle=g_stbPendingTrailCycle;

      STB_PendingTrailManageOne(ticket,manual);

      int updatedIdx=STB_PendingTrailFind(ticket);
      if(updatedIdx>=0 &&
         g_stbPendingTrail[updatedIdx].lastModifyTime>previousModifyTime)
         moved++;
   }

   STB_PendingTrailPruneInactive();
   return moved;
}

//--- Trigger handoff -------------------------------------------------
void STB_PendingTrailOnOrderFilled(const ulong ticket)
{
   if(ticket==0)
      return;

   int idx=STB_PendingTrailFind(ticket);

   if(idx<0 || !g_stbPendingTrail[idx].active)
      return;

   // DEAL_ADD can represent a partial fill. If the original pending ticket
   // still exists in the active-order pool, keep its trail state alive for
   // the unfilled remainder; only hand off after the pending order is gone.
   // Transaction arrival order is not assumed: the next manager pass will
   // also deactivate stale state if the order disappears after this check.
   if(OrderSelect(ticket) &&
      IsManagedOrder(ticket) &&
      STB_PendingTrailIsManagedType(OrderGetInteger(ORDER_TYPE)))
   {
      Print("PENDING_PARTIAL_FILL_REMAINDER ticket=",IntegerToString((int)ticket),
            " symbol=",OrderGetString(ORDER_SYMBOL),
            " remainingVolume=",DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT),2),
            " action=KEEP_TRAIL_ACTIVE");
      return;
   }

   Print("PENDING_TRIGGERED ticket=",IntegerToString((int)ticket),
         " symbol=",g_stbPendingTrail[idx].symbol,
         " type=",STB_PendingTrailTypeName(g_stbPendingTrail[idx].orderType));

   Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
         " symbol=",g_stbPendingTrail[idx].symbol,
         " handoff=TRADE_MANAGEMENT");

   g_stbPendingTrail[idx].active=false;
}

//--- Restart recovery -------------------------------------------------
// Registers / reconstructs state from terminal orders for every managed
// pending type (EA-created, manual/mobile, other-EA, pre-existing). It NEVER
// modifies an order by itself: a proposal is only produced when the live
// market creates a new favorable extreme (see STB_PendingTrailManageOne).
int STB_PendingTrailRebuildFromTerminal()
{
   STB_PendingTrailClear();

   int recovered=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(!STB_PendingTrailIsManagedType(OrderGetInteger(ORDER_TYPE)))
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      string symbol=OrderGetString(ORDER_SYMBOL);

      if(STB_PendingTrailRegister(ticket,"RESTART_RECOVERY"))
      {
         recovered++;
         Print("PENDING_RECOVERED ticket=",IntegerToString((int)ticket),
               " symbol=",symbol,
               " type=",STB_PendingTrailTypeName(
                  OrderGetInteger(ORDER_TYPE)));
      }
   }

   return recovered;
}

#endif
