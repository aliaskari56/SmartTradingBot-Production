//+------------------------------------------------------------------+
//| STB_PendingTrail.mqh                                             |
//| Safe-integration Pending Trail service for SmartTradingBot.      |
//|                                                                  |
//| NOT an EA. NOT a Trade Manager.                                  |
//| This module OWNS the pre-trigger lifecycle of BUY STOP /         |
//| SELL STOP pending orders ONLY:                                   |
//|   - ticket-based state (never symbol-only state)                 |
//|   - BUY STOP  : new lower Low  -> Entry/SL move lower            |
//|   - SELL STOP : new higher High-> Entry/SL move higher           |
//|   - broker validation via STB_PendingDistanceResolver            |
//|   - restart recovery (state rebuilt from terminal orders)        |
//|   - multi-ticket isolation                                       |
//|   - atomic modify pipeline (read->calc->validate->align->diff->  |
//|     modify once->read->confirm->commit)                          |
//|   - trigger handoff: PENDING_TRIGGERED then                      |
//|     PENDING_TRAIL_STOPPED handoff=TRADE_MANAGEMENT               |
//|                                                                  |
//| After trigger this module MUST NOT touch the resulting position. |
//+------------------------------------------------------------------+
#ifndef _STB_PENDING_TRAIL_MQH
#define _STB_PENDING_TRAIL_MQH

//--- Ticket-based pending trail state --------------------------------
struct STBPendingTrailState
{
   ulong    ticket;
   string   symbol;
   long     orderType;   // ORDER_TYPE_BUY_STOP / ORDER_TYPE_SELL_STOP
   string   source;      // AUTO | UI_MANUAL | TERMINAL_SCAN | RESTART_RECOVERY
   double   trackedExtreme;
   double   lastEntry;
   double   lastSL;
   datetime lastModifyTime;
   datetime lastNoNewExtremeLogBar;
   datetime lastFailLogBar;
   int      lastProcessedCycle;
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

int STB_PendingTrailActiveCount()
{
   int n=0;

   for(int i=0;i<ArraySize(g_stbPendingTrail);i++)
      if(g_stbPendingTrail[i].active)
         n++;

   return n;
}

void STB_PendingTrailClear()
{
   ArrayResize(g_stbPendingTrail,0);
   g_stbPendingTrailCycle=0;
}

void STB_PendingTrailInit()
{
   STB_PendingTrailClear();
}

bool STB_PendingTrailIsStopType(const long orderType)
{
   return orderType==(long)ORDER_TYPE_BUY_STOP ||
          orderType==(long)ORDER_TYPE_SELL_STOP;
}

int STB_PendingTrailDirection(const long orderType)
{
   if(orderType==(long)ORDER_TYPE_BUY_STOP)
      return 1;

   if(orderType==(long)ORDER_TYPE_SELL_STOP)
      return -1;

   return 0;
}

string STB_PendingTrailTypeName(const long orderType)
{
   if(orderType==(long)ORDER_TYPE_BUY_STOP)
      return "BUY_STOP";

   if(orderType==(long)ORDER_TYPE_SELL_STOP)
      return "SELL_STOP";

   return "UNKNOWN";
}

//--- Register a real terminal pending order --------------------------
// Called ONLY after the terminal confirmed the ticket. The anchor uses
// the latest CLOSED M15 extreme (Low[1] for buy / High[1] for sell).
bool STB_PendingTrailRegister(const ulong ticket,const string source)
{
   if(ticket==0)
      return false;

   if(!OrderSelect(ticket))
      return false;

   if(!IsManagedOrder(ticket))
      return false;

   long orderType=OrderGetInteger(ORDER_TYPE);

   if(!STB_PendingTrailIsStopType(orderType))
      return false;

   int existing=STB_PendingTrailFind(ticket);

   if(existing>=0)
   {
      if(!g_stbPendingTrail[existing].active)
      {
         // Slot reuse: previously stopped for this ticket.
         g_stbPendingTrail[existing].active=true;
         g_stbPendingTrail[existing].source=source;
         g_stbPendingTrail[existing].lastProcessedCycle=-1;
      }

      return true;
   }

   string symbol=OrderGetString(ORDER_SYMBOL);

   if(symbol=="")
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(point<=0.0)
      return false;

   int direction=STB_PendingTrailDirection(orderType);

   double extreme=(direction>0)
                  ? iLow(symbol,PERIOD_M15,1)
                  : iHigh(symbol,PERIOD_M15,1);

   if(extreme<=0.0)
      return false;

   STBPendingTrailState st;
   ZeroMemory(st);

   st.ticket=ticket;
   st.symbol=symbol;
   st.orderType=orderType;
   st.source=source;
   st.trackedExtreme=extreme;
   st.lastEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   st.lastSL=OrderGetDouble(ORDER_SL);
   st.lastModifyTime=0;
   st.lastNoNewExtremeLogBar=0;
   st.lastFailLogBar=0;
   st.lastProcessedCycle=-1;
   st.active=true;

   int n=ArraySize(g_stbPendingTrail);
   ArrayResize(g_stbPendingTrail,n+1);
   g_stbPendingTrail[n]=st;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   Print("PENDING_CREATED ticket=",IntegerToString((int)ticket),
         " symbol=",symbol,
         " type=",STB_PendingTrailTypeName(orderType),
         " source=",source,
         " trackedExtreme=",DoubleToString(extreme,digits),
         " entry=",DoubleToString(st.lastEntry,digits),
         " sl=",DoubleToString(st.lastSL,digits));

   // PENDING_DISTANCE: resolved offsets and broker minimum distance.
   STBPendingResolution res;

   if(STB_ResolvePendingDistance(symbol,direction,extreme,0.0,res) && res.valid)
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

//--- Atomic modify pipeline for ONE ticket ---------------------------
bool STB_PendingTrailManageOne(const ulong ticket)
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

   long orderType=OrderGetInteger(ORDER_TYPE);

   if(!STB_PendingTrailIsStopType(orderType))
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

   g_stbPendingTrail[idx].orderType=orderType;

   string symbol=g_stbPendingTrail[idx].symbol;
   int direction=STB_PendingTrailDirection(orderType);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(direction==0 || point<=0.0)
      return true;

   // 1) Read terminal / bar extreme.
   double extreme=(direction>0)
                  ? iLow(symbol,PERIOD_M15,1)
                  : iHigh(symbol,PERIOD_M15,1);

   if(extreme<=0.0)
      return true;

   bool isNewExtreme=false;

   if(direction>0)
      isNewExtreme=(extreme < g_stbPendingTrail[idx].trackedExtreme-point*0.5);
   else
      isNewExtreme=(extreme > g_stbPendingTrail[idx].trackedExtreme+point*0.5);

   if(!isNewExtreme)
   {
      // 2) No new extreme -> NO MODIFY (rate-limited).
      STB_PendingTrailLogNoNewExtreme(ticket,symbol,
                                      STB_PendingTrailFind(ticket));
      return true;
   }

   // 3) Calculate + validate + tick align via the resolver.
   STBPendingResolution res;

   if(!STB_ResolvePendingDistance(symbol,direction,extreme,0.0,res) || !res.valid)
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

      // State NOT committed as success.
      return true;
   }

   double curEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double curSL=OrderGetDouble(ORDER_SL);

   // 4) Check actual difference: skip a broker no-op modify.
   bool meaningfulChange=
      MathAbs(res.entry-curEntry)>point*0.5 ||
      MathAbs(res.sl-curSL)>point*0.5;

   if(!meaningfulChange)
   {
      STB_PendingTrailLogNoNewExtreme(ticket,symbol,
                                      STB_PendingTrailFind(ticket));
      return true;
   }

   double tp=OrderGetDouble(ORDER_TP);
   ENUM_ORDER_TYPE_TIME typeTime=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   double stopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);

   double oldEntry=curEntry;
   double oldSL=curSL;
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   // 5) Modify once.
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);

   if(!trade.OrderModify(ticket,res.entry,res.sl,tp,typeTime,expiration,stopLimit))
   {
      Print("PENDING_TRAIL_MODIFY_FAILED ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " stage=MODIFY_REQUEST",
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return true;
   }

   if(!TradeRetcodeModifySucceeded())
   {
      Print("PENDING_TRAIL_MODIFY_FAILED ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " stage=SERVER_REJECT",
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return true;
   }

   // 6) Read terminal again and confirm.
   if(!OrderSelect(ticket))
   {
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " reason=ORDER_NOT_ON_TERMINAL_AFTER_MODIFY");
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   double confirmedEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double confirmedSL=OrderGetDouble(ORDER_SL);

   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tolerance=MathMax(point*0.5,
                            tickSize>0.0 ? tickSize*0.5 : point*0.5);

   if(MathAbs(confirmedEntry-res.entry)>tolerance ||
      MathAbs(confirmedSL-res.sl)>tolerance)
   {
      Print("PENDING_TRAIL_MODIFY_NOT_CONFIRMED ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " requestedEntry=",DoubleToString(res.entry,digits),
            " actualEntry=",DoubleToString(confirmedEntry,digits),
            " requestedSL=",DoubleToString(res.sl,digits),
            " actualSL=",DoubleToString(confirmedSL,digits),
            " ret=",trade.ResultRetcode());
      return true;
   }

   // 7) Commit internal state ONLY after terminal confirmation.
   g_stbPendingTrail[idx].trackedExtreme=extreme;
   g_stbPendingTrail[idx].lastEntry=confirmedEntry;
   g_stbPendingTrail[idx].lastSL=confirmedSL;
   g_stbPendingTrail[idx].lastModifyTime=TimeCurrent();

   Print("PENDING_TRAIL_UPDATE ticket=",IntegerToString((int)ticket),
         " symbol=",symbol,
         " type=",STB_PendingTrailTypeName(orderType),
         " entry ",DoubleToString(oldEntry,digits)," -> ",DoubleToString(confirmedEntry,digits),
         " sl ",DoubleToString(oldSL,digits)," -> ",DoubleToString(confirmedSL,digits),
         " entryOffset=",DoubleToString(res.entryOffset,digits),
         " slBuffer=",DoubleToString(res.slBuffer,digits),
         " brokerMin=",DoubleToString(res.brokerMinDistance,digits));

   return true;
}

//--- Per-cycle processing (OnTick / OnTimer with cycle dedup) ---------
void STB_PendingTrailProcess()
{
   g_stbPendingTrailCycle++;

   // Registration pass: TERMINAL-SCAN any managed BUY_STOP/SELL_STOP
   // order that is not yet tracked (multi-ticket + manual discovery).
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(!STB_PendingTrailIsStopType(OrderGetInteger(ORDER_TYPE)))
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

      g_stbPendingTrail[i].lastProcessedCycle=g_stbPendingTrailCycle;
      STB_PendingTrailManageOne(g_stbPendingTrail[i].ticket);
   }
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

      if(!STB_PendingTrailIsStopType(OrderGetInteger(ORDER_TYPE)))
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