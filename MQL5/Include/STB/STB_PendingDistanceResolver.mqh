//+------------------------------------------------------------------+
//| STB_PendingDistanceResolver.mqh                                  |
//| Safe-integration distance service for SmartTradingBot.           |
//|                                                                  |
//| NOT an EA. NOT an Adaptive Engine.                               |
//| This module is a SPECIALIZED SERVICE: it consumes the EXISTING   |
//| STB adaptive context (STB_EffectiveEntryBuffer /                 |
//| STB_EffectiveSLBuffer) and EXISTING broker helpers               |
//| (TradeMinDistance, NormalizePrice) and produces broker-validated |
//| Entry / SL geometry for EVERY supported pending type:            |
//|   BUY STOP / SELL STOP / BUY LIMIT / SELL LIMIT /                |
//|   BUY STOP-LIMIT / SELL STOP-LIMIT.                              |
//|                                                                  |
//| Responsibilities:                                                |
//|   EntryOffset, SLBuffer, Broker validation, Tick alignment,      |
//|   Final Entry, Final SL                                          |
//| The broker minimum distance is only a VALIDITY FLOOR, never the  |
//| strategy SL target.                                              |
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

//--- Pending classification (single source of truth) ---------------
bool STB_PendingIsBuySide(const ENUM_ORDER_TYPE orderType)
{
   return orderType==ORDER_TYPE_BUY_STOP       ||
          orderType==ORDER_TYPE_BUY_LIMIT      ||
          orderType==ORDER_TYPE_BUY_STOP_LIMIT;
}

bool STB_PendingIsSellSide(const ENUM_ORDER_TYPE orderType)
{
   return orderType==ORDER_TYPE_SELL_STOP      ||
          orderType==ORDER_TYPE_SELL_LIMIT     ||
          orderType==ORDER_TYPE_SELL_STOP_LIMIT;
}

// STOP-kind orders enter on a breakout; LIMIT-kind orders enter on a pullback.
bool STB_PendingIsStopKind(const ENUM_ORDER_TYPE orderType)
{
   return orderType==ORDER_TYPE_BUY_STOP       ||
          orderType==ORDER_TYPE_SELL_STOP      ||
          orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
          orderType==ORDER_TYPE_SELL_STOP_LIMIT;
}

//--- Entry offset sign relative to the tracked anchor extreme ------
//   +1 => entry sits ABOVE the anchor
//         (BUY STOP, BUY STOP-LIMIT, SELL LIMIT)
//   -1 => entry sits BELOW the anchor
//         (SELL STOP, SELL STOP-LIMIT, BUY LIMIT)
int STB_PendingEntryOffsetSign(const ENUM_ORDER_TYPE orderType)
{
   if(orderType==ORDER_TYPE_BUY_STOP       ||
      orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
      orderType==ORDER_TYPE_SELL_LIMIT)
      return 1;

   if(orderType==ORDER_TYPE_SELL_STOP      ||
      orderType==ORDER_TYPE_SELL_STOP_LIMIT ||
      orderType==ORDER_TYPE_BUY_LIMIT)
      return -1;

   return 0;
}

//--- Resolve Entry / SL for any supported pending type -------------
// Inputs:
//   symbol                  - target symbol
//   orderType               - BUY/SELL STOP, BUY/SELL LIMIT, STOP-LIMIT
//   extreme                 - tracked anchor extreme
//                             (live Bid for BUY side, live Ask for SELL side)
//   configuredBaseDistance  - caller override in pips; <=0 means use the
//                             EXISTING STB adaptive entry/SL buffers
// Outputs (validated):
//   entry, sl, entryOffset, slBuffer, brokerMinDistance
bool STB_ResolvePendingDistance(const string symbol,
                                const ENUM_ORDER_TYPE orderType,
                                const double extreme,
                                const double configuredBaseDistance,
                                STBPendingResolution &r,
                                const double configuredSLBufferPips=-1.0)
{
   ZeroMemory(r);
   r.valid=false;
   r.reason="UNRESOLVED";

   if(symbol=="" || extreme<=0.0)
   {
      r.reason="IDENTITY_INVALID";
      return false;
   }

   bool isBuy =STB_PendingIsBuySide(orderType);
   bool isSell=STB_PendingIsSellSide(orderType);
   bool isStop=STB_PendingIsStopKind(orderType);
   int  offSign=STB_PendingEntryOffsetSign(orderType);

   if((!isBuy && !isSell) || offSign==0)
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

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
   {
      r.reason="NO_TICK";
      return false;
   }

   // Broker validity floor for the entry offset. The configured buffer is a
   // preference; the broker minimum distance is the hard validity floor. For
   // STOP-kind geometry the pending entry must also clear the current spread
   // relative to the near-side market price.
   double spread=MathMax(0.0,tick.ask-tick.bid);
   double minOffset=(isStop ? (spread+bl.minDistance+bl.point)
                            : (bl.minDistance+bl.point));
   double effectiveOffset=MathMax(entryOffsetPips*pip,minOffset);

   // The entry keeps a fixed offset from the tracked anchor extreme; the offset
   // sign encodes stop (breakout) vs limit (pullback) geometry per side.
   double rawEntry=extreme+offSign*effectiveOffset;

   // Pending SL distance is measured from the pending Entry itself and the SL
   // sits on the risk side of the order direction (BUY below, SELL above).
   double rawSL=(isBuy ? rawEntry-slBufferPips*pip
                       : rawEntry+slBufferPips*pip);

   double entry=STB_TickAlignPrice(symbol,rawEntry);
   double sl   =STB_TickAlignPrice(symbol,rawSL);

   if(entry<=0.0 || sl<=0.0)
   {
      r.reason="PRICE_INVALID";
      return false;
   }

   // Broker validation, per pending geometry:
   //   BUY  STOP      : sl < bid < ask < entry          (breakout above)
   //   BUY  LIMIT     : sl < entry < bid                (pullback below)
   //   SELL STOP      : entry < bid < ask < sl          (breakout below)
   //   SELL LIMIT     : bid < ask < entry < sl          (pullback above)
   if(isBuy)
   {
      if(sl>=entry-bl.minDistance)
      {
         r.reason="BUY_SL_TOO_CLOSE_TO_ENTRY";
         return false;
      }

      if(sl>tick.bid-bl.minDistance)
      {
         r.reason="BUY_SL_INSIDE_BROKER_ZONE";
         return false;
      }

      if(isStop)
      {
         if(entry<=tick.ask+bl.minDistance)
         {
            r.reason="BUY_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
      else
      {
         if(entry>=tick.bid-bl.minDistance)
         {
            r.reason="BUY_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
   }
   else
   {
      if(sl<=entry+bl.minDistance)
      {
         r.reason="SELL_SL_TOO_CLOSE_TO_ENTRY";
         return false;
      }

      if(sl<tick.ask+bl.minDistance)
      {
         r.reason="SELL_SL_INSIDE_BROKER_ZONE";
         return false;
      }

      if(isStop)
      {
         if(entry>=tick.bid-bl.minDistance)
         {
            r.reason="SELL_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
      else
      {
         if(entry<=tick.ask+bl.minDistance)
         {
            r.reason="SELL_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
   }

   r.entry=entry;
   r.sl=sl;
   r.entryOffset=effectiveOffset;
   r.slBuffer=slBufferPips*pip;
   r.brokerMinDistance=bl.minDistance;
   r.valid=true;
   r.reason="OK";
   return true;
}

#endif
