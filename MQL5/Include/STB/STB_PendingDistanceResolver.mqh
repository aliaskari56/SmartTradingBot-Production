//+------------------------------------------------------------------+
//| STB_PendingDistanceResolver.mqh                                  |
//| Safe-integration distance service for SmartTradingBot.           |
//|                                                                  |
//| NOT an EA. NOT an Adaptive Engine.                               |
//| This module is a SPECIALIZED SERVICE: it consumes the EXISTING   |
//| STB adaptive context (STB_EffectiveEntryBuffer /                 |
//| STB_EffectiveSLBuffer) and EXISTING broker helpers               |
//| (TradeMinDistance, NormalizePrice) and produces broker-validated |
//| Entry / SL geometry for BUY STOP / SELL STOP pending orders.     |
//|                                                                  |
//| Responsibilities:                                                |
//|   EntryOffset, SLBuffer, Broker validation, Tick alignment,      |
//|   Final Entry, Final SL                                          |
//+------------------------------------------------------------------+
#ifndef _STB_PENDING_DISTANCE_RESOLVER_MQH
#define _STB_PENDING_DISTANCE_RESOLVER_MQH

//--- Broker symbol limits snapshot ---------------------------------
struct STBBrokerLimits
{
   string symbol;
   double point;          // SYMBOL_POINT
   int    digits;         // SYMBOL_DIGITS
   double tickSize;       // SYMBOL_TRADE_TICK_SIZE
   long   stopsLevel;     // SYMBOL_TRADE_STOPS_LEVEL
   long   freezeLevel;    // SYMBOL_TRADE_FREEZE_LEVEL
   double minDistance;    // existing STB broker minimum distance
   bool   valid;
};

//--- Resolver output -------------------------------------------------
struct STBPendingResolution
{
   bool   valid;
   string reason;
   double entry;             // validated entry (tick aligned)
   double sl;                // validated SL (tick aligned)
   double entryOffset;       // applied entry offset (price units)
   double slBuffer;          // applied SL buffer (price units)
   double brokerMinDistance; // broker minimum distance (price units)
};

//--- Read symbol broker constraints --------------------------------
bool STB_ReadBrokerLimits(const string symbol, STBBrokerLimits &bl)
{
   ZeroMemory(bl);

   bl.symbol=      symbol;
   bl.point=       SymbolInfoDouble(symbol,SYMBOL_POINT);
   bl.digits=      (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   bl.tickSize=    SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   bl.stopsLevel=  (long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   bl.freezeLevel= (long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   bl.minDistance= TradeMinDistance(symbol);

   bl.valid=(bl.point>0.0 && bl.minDistance>0.0);
   return bl.valid;
}

//--- Tick-size alignment (NormalizeDouble alone is NOT sufficient) ----
double STB_TickAlignPrice(const string symbol,const double price)
{
   if(price<=0.0)
      return 0.0;

   STBBrokerLimits bl;
   if(!STB_ReadBrokerLimits(symbol,bl))
      return NormalizePrice(symbol,price);

   if(bl.tickSize<=0.0)
      return NormalizePrice(symbol,price);

   double aligned=MathRound(price/bl.tickSize)*bl.tickSize;

   return NormalizePrice(symbol,aligned);
}

//--- Resolve Entry / SL for a BUY STOP / SELL STOP ------------------
// Inputs:
//   symbol                  - target symbol
//   direction               - +1 BUY STOP, -1 SELL STOP
//   extreme                 - tracked extreme (Low for buy, High for sell)
//   configuredBaseDistance  - caller override in pips; <=0 means use the
//                             EXISTING STB adaptive entry/SL buffers
// Outputs (validated):
//   entry, sl, entryOffset, slBuffer, brokerMinDistance
bool STB_ResolvePendingDistance(const string symbol,
                                const int direction,
                                const double extreme,
                                const double configuredBaseDistance,
                                STBPendingResolution &r,
                                const double configuredSLBufferPips=-1.0)
{
   ZeroMemory(r);
   r.valid=false;
   r.reason="UNRESOLVED";

   if(symbol=="" || direction==0 || extreme<=0.0)
   {
      r.reason="IDENTITY_INVALID";
      return false;
   }

   STBBrokerLimits bl;
   if(!STB_ReadBrokerLimits(symbol,bl))
   {
      r.reason="BROKER_LIMITS_UNAVAILABLE";
      return false;
   }

   // Adaptive context remains available for Strategy-owned callers. Lifecycle
   // managers can pass immutable stored buffers and therefore do not need
   // Adaptive access.
   double entryOffsetPips=STB_EffectiveEntryBuffer();
   double slBufferPips   =STB_EffectiveSLBuffer();

   if(configuredBaseDistance>0.0)
      entryOffsetPips=configuredBaseDistance;

   if(configuredSLBufferPips>=0.0)
      slBufferPips=configuredSLBufferPips;
   else if(configuredBaseDistance>0.0)
      slBufferPips=configuredBaseDistance;

   // STB configuration values are expressed in pips, not raw broker points.
   // Use the EA's canonical PipSize() so XAU/XAG/3-5 digit symbols receive
   // the intended price distance.
   double pip=PipSize(symbol);
   if(pip<=0.0)
   {
      r.reason="PIP_SIZE_INVALID";
      return false;
   }

   double rawEntry=0.0;
   double rawSL=0.0;

   if(direction>0)
   {
      rawEntry=extreme+entryOffsetPips*pip;
      rawSL   =extreme-slBufferPips*pip;
   }
   else
   {
      rawEntry=extreme-entryOffsetPips*pip;
      rawSL   =extreme+slBufferPips*pip;
   }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
   {
      r.reason="NO_TICK";
      return false;
   }

   double entry=STB_TickAlignPrice(symbol,rawEntry);
   double sl   =STB_TickAlignPrice(symbol,rawSL);

   if(entry<=0.0 || sl<=0.0)
   {
      r.reason="PRICE_INVALID";
      return false;
   }

   // Broker validation. BUY  : SL < Low < Entry  with valid distance.
   //                    SELL : Entry < High < SL with valid distance.
   if(direction>0)
   {
      if(sl>=entry-bl.minDistance)
      {
         r.reason="BUY_SL_TOO_CLOSE_TO_ENTRY";
         return false;
      }
      if(entry<=tick.ask+bl.minDistance)
      {
         r.reason="BUY_ENTRY_INSIDE_BROKER_ZONE";
         return false;
      }
      if(sl>tick.bid-bl.minDistance)
      {
         r.reason="BUY_SL_INSIDE_BROKER_ZONE";
         return false;
      }
   }
   else
   {
      if(sl<=entry+bl.minDistance)
      {
         r.reason="SELL_SL_TOO_CLOSE_TO_ENTRY";
         return false;
      }
      if(entry>=tick.bid-bl.minDistance)
      {
         r.reason="SELL_ENTRY_INSIDE_BROKER_ZONE";
         return false;
      }
      if(sl<tick.ask+bl.minDistance)
      {
         r.reason="SELL_SL_INSIDE_BROKER_ZONE";
         return false;
      }
   }

   r.entry=entry;
   r.sl=sl;
   r.entryOffset=entryOffsetPips*pip;
   r.slBuffer=slBufferPips*pip;
   r.brokerMinDistance=bl.minDistance;
   r.valid=true;
   r.reason="OK";
   return true;
}

#endif