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
//|   - BUY STOP: closed bearish M5 candle low drives trailing       |
//|   - SELL STOP: closed bullish M5 candle high drives trailing     |
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
      case TRADE_RETCODE_DONE_PARTIAL:
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

   // STOP orders use the latest CLOSED M5 candle as their initial structural
   // anchor. Subsequent trailing is evaluated once per newly closed M5 bar.
   if(orderType==(long)ORDER_TYPE_BUY_STOP)
     {
      double m5Low=iLow(symbol,PERIOD_M5,1);
      if(m5Low>0.0)
         inferredExtreme=m5Low;
     }
   else if(orderType==(long)ORDER_TYPE_SELL_STOP)
     {
      double m5High=iHigh(symbol,PERIOD_M5,1);
      if(m5High>0.0)
         inferredExtreme=m5High;
     }

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
      Print("PENDING_TRAIL_REGISTER_FAILED ticket=",IntegerToString((int)ticket),
            " reason=STATE_ALLOCATION_FAILED");
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

   bool candleStop=(g_stbPendingTrail[idx].orderType==(long)ORDER_TYPE_BUY_STOP ||
                    g_stbPendingTrail[idx].orderType==(long)ORDER_TYPE_SELL_STOP);
   if(!manual && STB_ManualOverrideIs(ticket) && !candleStop)
      return false; // M5 candle-follow remains active for BUY STOP / SELL STOP

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

   if(!OrderSelect(g_stbPendingTrail[idx].ticket))
   {
      // Terminal no longer exposes this order: filled (triggered),
      // cancelled or deleted. The trail stops here; the existing
      // STB Trade Manager owns any resulting position.
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=ORDER_NOT_ON_TERMINAL");
      g_stbPendingTrail[idx].active=false;
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

   long orderType=OrderGetInteger(ORDER_TYPE);

   // BUY STOP / SELL STOP orders explicitly opt into the M5 candle-follow
   // lifecycle, including orders created by the chart buttons. Preserve the
   // existing manual-override pause for LIMIT and STOP-LIMIT orders.
   bool candleStop=(orderType==(long)ORDER_TYPE_BUY_STOP ||
                    orderType==(long)ORDER_TYPE_SELL_STOP);
   if(!manual && STB_ManualOverrideIs(ticket) && !candleStop)
      return true;

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
      return true;

   g_stbPendingTrail[idx].orderType=orderType;

   string symbol=g_stbPendingTrail[idx].symbol;
   int direction=STB_PendingTrailDirection(orderType);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(direction==0 || point<=0.0)
      return true;

   // A failed qualifying candle remains eligible for a bounded retry.
   if(!manual && g_stbPendingTrail[idx].nextRetryTime>0 &&
      TimeCurrent()<g_stbPendingTrail[idx].nextRetryTime)
      return true;

   // 1) STOP orders follow the latest CLOSED M5 candle, not live ticks.
   // BUY STOP moves only after a bearish M5 candle and anchors to its low.
   // SELL STOP moves only after a bullish M5 candle and anchors to its high.
   // Other pending types retain their previous live-extreme behavior.
   double extreme=0.0;
   datetime candidateClosedBar=0;
   if(candleStop)
     {
      datetime closedBar=iTime(symbol,PERIOD_M5,1);
      if(closedBar<=0 ||
         closedBar==g_stbPendingTrail[idx].lastProcessedM5Bar)
         return true;

      double barOpen=iOpen(symbol,PERIOD_M5,1);
      double barClose=iClose(symbol,PERIOD_M5,1);
      double barLow=iLow(symbol,PERIOD_M5,1);
      double barHigh=iHigh(symbol,PERIOD_M5,1);
      if(barOpen<=0.0 || barClose<=0.0 || barLow<=0.0 || barHigh<=0.0)
         return true;

      // Retain the candidate bar until a qualifying update succeeds; a failed
      // resolver/broker request can then retry this same closed candle.
      candidateClosedBar=closedBar;

      if(orderType==(long)ORDER_TYPE_BUY_STOP)
        {
         if(barClose>=barOpen)
           {
            g_stbPendingTrail[idx].lastProcessedM5Bar=closedBar;
            return true; // only a completed bearish candle may move BUY STOP down
           }
         extreme=barLow;
        }
      else
        {
         if(barClose<=barOpen)
           {
            g_stbPendingTrail[idx].lastProcessedM5Bar=closedBar;
            return true; // only a completed bullish candle may move SELL STOP up
           }
         extreme=barHigh;
        }
     }
   else
     {
      MqlTick liveTick;
      if(!SymbolInfoTick(symbol,liveTick))
         return true;
      extreme=(direction>0 ? liveTick.bid:liveTick.ask);
     }

   if(extreme<=0.0)
      return true;

   // P4 monotonic trackedExtreme: BUY side only moves down, SELL side only up.
   bool isNewExtreme=false;

   if(direction>0)
      isNewExtreme=(extreme < g_stbPendingTrail[idx].trackedExtreme-point*0.5);
   else
      isNewExtreme=(extreme > g_stbPendingTrail[idx].trackedExtreme+point*0.5);

   if(!isNewExtreme)
   {
      // This closed candle is fully evaluated; there is no candidate to retry.
      if(candidateClosedBar>0)
         g_stbPendingTrail[idx].lastProcessedM5Bar=candidateClosedBar;
      // 2) No new extreme -> NO MODIFY (rate-limited).
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
                                 g_stbPendingTrail[idx].slBufferPips);

   if(!resolved || !res.valid)
   {
      datetime bar=iTime(symbol,PERIOD_M15,1);

      if(bar<=0)
         bar=TimeCurrent();

      if(g_stbPendingTrail[idx].lastFailLogBar!=bar)
      {
         g_stbPendingTrail[idx].lastFailLogBar=bar;

         Print("PENDING_TRAIL_MODIFY_FAILED ticket=",IntegerToString((int)ticket),
               " symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " stage=RESOLVE",
               " reason=",res.reason);
      }

      // Retry this same qualifying candle with bounded backoff; do not mark
      // it processed because the candidate was not resolved/committed.
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

   // 4) Forward the proposal to the central submit gate. The gate applies
   //    throttle / backoff / Step and then calls the single writer.
   bool committed=STB_SubmitPendingTrailGeometry(ticket,
                                                 prop.entry,
                                                 prop.sl,
                                                 prop.tp,
                                                 manual);

   if(committed)
   {
      // P4: trackedExtreme advances only in the favorable direction.
      if(direction>0)
         g_stbPendingTrail[idx].trackedExtreme=
            MathMin(g_stbPendingTrail[idx].trackedExtreme,extreme);
      else
         g_stbPendingTrail[idx].trackedExtreme=
            MathMax(g_stbPendingTrail[idx].trackedExtreme,extreme);

      if(candidateClosedBar>0)
         g_stbPendingTrail[idx].lastProcessedM5Bar=candidateClosedBar;

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
