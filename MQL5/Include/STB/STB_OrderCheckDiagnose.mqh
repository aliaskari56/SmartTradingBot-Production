//+------------------------------------------------------------------+
//|                                    STB_OrderCheckDiagnose.mqh    |
//|     FORENSIC DIAGNOSTICS ONLY - read-only, never owns execution  |
//|                                     (no OrderSend, no OrderModify)|
//+------------------------------------------------------------------+
#ifndef STB_ORDERCHECK_DIAGNOSE_MQH
#define STB_ORDERCHECK_DIAGNOSE_MQH

//--------------------------------------------------------------------
// Short mnemonic for any TRADE_RETCODE_* value (0 included).
//--------------------------------------------------------------------
string STB_TradeRetcodeName(const uint retcode)
{
   switch((int)retcode)
   {
      case TRADE_RETCODE_REQUOTE:              return "REQUOTE";
      case TRADE_RETCODE_REJECT:               return "REJECT";
      case TRADE_RETCODE_CANCEL:               return "CANCEL";
      case TRADE_RETCODE_PLACED:               return "PLACED";
      case TRADE_RETCODE_DONE:                 return "DONE";
      case TRADE_RETCODE_DONE_PARTIAL:         return "DONE_PARTIAL";
      case TRADE_RETCODE_ERROR:                return "ERROR";
      case TRADE_RETCODE_TIMEOUT:              return "TIMEOUT";
      case TRADE_RETCODE_INVALID:              return "INVALID";
      case TRADE_RETCODE_INVALID_VOLUME:       return "INVALID_VOLUME";
      case TRADE_RETCODE_INVALID_PRICE:        return "INVALID_PRICE";
      case TRADE_RETCODE_INVALID_STOPS:        return "INVALID_STOPS";
      case TRADE_RETCODE_TRADE_DISABLED:       return "TRADE_DISABLED";
      case TRADE_RETCODE_MARKET_CLOSED:        return "MARKET_CLOSED";
      case TRADE_RETCODE_NO_MONEY:             return "NO_MONEY";
      case TRADE_RETCODE_PRICE_CHANGED:        return "PRICE_CHANGED";
      case TRADE_RETCODE_PRICE_OFF:            return "PRICE_OFF";
      case TRADE_RETCODE_INVALID_EXPIRATION:   return "INVALID_EXPIRATION";
      case TRADE_RETCODE_ORDER_CHANGED:        return "ORDER_CHANGED";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:    return "TOO_MANY_REQUESTS";
      case TRADE_RETCODE_NO_CHANGES:           return "NO_CHANGES";
      case TRADE_RETCODE_SERVER_DISABLES_AT:   return "SERVER_DISABLES_AT";
      case TRADE_RETCODE_CLIENT_DISABLES_AT:   return "CLIENT_DISABLES_AT";
      case TRADE_RETCODE_LOCKED:               return "LOCKED";
      case TRADE_RETCODE_FROZEN:               return "FROZEN";
      case TRADE_RETCODE_INVALID_FILL:         return "INVALID_FILL";
      case TRADE_RETCODE_CONNECTION:           return "CONNECTION";
      case TRADE_RETCODE_ONLY_REAL:            return "ONLY_REAL";
      case TRADE_RETCODE_LIMIT_ORDERS:         return "LIMIT_ORDERS";
      case TRADE_RETCODE_LIMIT_VOLUME:         return "LIMIT_VOLUME";
      case TRADE_RETCODE_INVALID_ORDER:        return "INVALID_ORDER";
      case TRADE_RETCODE_POSITION_CLOSED:      return "POSITION_CLOSED";
      // TRADE_RETCODE_UNKNOWN is not defined in this MQL5 build
      default:                                 return "RETCODE_"+IntegerToString(retcode);
   }
}

//--------------------------------------------------------------------
// Map retcode to the ORDERCHECK_* forensic taxonomy (rule 7).
//--------------------------------------------------------------------
string STB_OrderCheckClassify(const uint retcode,const string comment)
{
   switch((int)retcode)
   {
      case TRADE_RETCODE_INVALID_PRICE:      return "ORDERCHECK_INVALID_PRICE";
      case TRADE_RETCODE_INVALID_STOPS:      return "ORDERCHECK_INVALID_STOPS";
      case TRADE_RETCODE_INVALID_VOLUME:     return "ORDERCHECK_INVALID_VOLUME";
      case TRADE_RETCODE_MARKET_CLOSED:      return "ORDERCHECK_MARKET_CLOSED";
      case TRADE_RETCODE_TRADE_DISABLED:     return "ORDERCHECK_TRADE_DISABLED";
      case TRADE_RETCODE_NO_MONEY:           return "ORDERCHECK_NO_MONEY";
      case TRADE_RETCODE_INVALID_FILL:       return "ORDERCHECK_INVALID_FILL";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "ORDERCHECK_INVALID_EXPIRATION";
      case TRADE_RETCODE_PRICE_CHANGED:      return "ORDERCHECK_PRICE_CHANGED";
      case TRADE_RETCODE_REQUOTE:            return "ORDERCHECK_REQUOTE";
      case TRADE_RETCODE_REJECT:             return "ORDERCHECK_BROKER_RULE";
      case TRADE_RETCODE_LIMIT_ORDERS:       return "ORDERCHECK_BROKER_RULE";
      case TRADE_RETCODE_LIMIT_VOLUME:       return "ORDERCHECK_BROKER_RULE";
      case TRADE_RETCODE_LOCKED:             return "ORDERCHECK_BROKER_RULE";
      case TRADE_RETCODE_FROZEN:             return "ORDERCHECK_BROKER_RULE";
      case TRADE_RETCODE_INVALID_ORDER:      return "ORDERCHECK_BROKER_RULE";
      case TRADE_RETCODE_INVALID:            return "ORDERCHECK_INVALID_PRICE";
      case TRADE_RETCODE_ERROR:              return "ORDERCHECK_UNKNOWN";
      // handled by default branch below
      default:
         if(retcode==0)
            return "ORDERCHECK_RETCODE_ZERO";
         return "ORDERCHECK_UNKNOWN";
   }
}

//--------------------------------------------------------------------
// One OrderCheck probe with a FULL request/result dump.
// tag    : REQUEST|POSITIVE_CONTROL|NEGATIVE_CONTROL
//--------------------------------------------------------------------
void STB_OrderCheckProbe(const string tag,
                         const string symbol,
                         const ENUM_ORDER_TYPE orderType,
                         const double volume,
                         const double price,
                         const double sl,
                         const double tp,
                         const ENUM_ORDER_TYPE_TIME typeTime,
                         const datetime expiration)
{
   MqlTradeRequest request={};
   MqlTradeCheckResult check={};

   request.action=TRADE_ACTION_PENDING;
   request.symbol=symbol;
   request.magic=InpMagic;
   request.volume=volume;
   request.type=orderType;
   request.price=price;
   request.sl=sl;
   request.tp=tp;
   request.type_filling=ORDER_FILLING_RETURN;
   request.type_time=typeTime;
   request.expiration=expiration;
   request.comment="STB";

   ResetLastError();
   bool apiReturn=OrderCheck(request,check);
   int lastError=GetLastError();

   Print("STB_ORDERCHECK_PROBE tag=",tag,
         " symbol=",symbol,
         " type=",EnumToString(orderType),
         " volume=",DoubleToString(volume,3),
         " price=",DoubleToString(price,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " sl=",DoubleToString(sl,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " tp=",DoubleToString(tp,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " A_ApiReturn=",apiReturn ? "TRUE":"FALSE",
         " B_retcode=",check.retcode,
         " B_retcodeName=",STB_TradeRetcodeName(check.retcode),
         " C_comment=\"",check.comment,"\"",
         " class=",STB_OrderCheckClassify(check.retcode,check.comment),
         " balance=",DoubleToString(check.balance,2),
         " equity=",DoubleToString(check.equity,2),
         " margin=",DoubleToString(check.margin,2),
         " marginFree=",DoubleToString(check.margin_free,2),
         " lastError=",lastError);
}

//--------------------------------------------------------------------
// Read-only OrderCheck forensic diagnostics (rule 13).
// Runs BEFORE the real gate: full request context + exact replay +
// POSITIVE and NEGATIVE differential controls. Never places orders.
//--------------------------------------------------------------------
void STB_PendingOrderCheckDiagnose(const Setup &s,
                                   const double volume,
                                   const ENUM_ORDER_TYPE_TIME typeTime,
                                   const datetime expiration,
                                   const string caller)
{
   static int s_stbDiagCount=0;
   if(s_stbDiagCount>=1000)
      return;
   s_stbDiagCount++;

   string symbol=s.symbol;
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   ENUM_ORDER_TYPE orderType=(s.direction>0 ? ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP);

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
   {
      Print("STB_ORDERCHECK_DIAG ",caller," symbol=",symbol," NOTICK err=",GetLastError());
      return;
   }

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   long   stopsLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long   freezeLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   long   spread=SymbolInfoInteger(symbol,SYMBOL_SPREAD);
   long   tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   long   orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
   long   fillModes=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
   long   expModes=SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);
   double minDist=TradeMinDistance(symbol);
   double marginFree=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   // Distance breakdown per side (rules 4/8/9/10).
   double entryToMarket=0.0;
   double slToEntry=0.0;
   double tpToEntry=0.0;
   if(s.direction>0)
   {
      entryToMarket=s.entry-tick.ask;
      slToEntry=s.entry-s.sl;
      tpToEntry=s.tp-s.entry;
   }
   else
   {
      entryToMarket=tick.bid-s.entry;
      slToEntry=s.sl-s.entry;
      tpToEntry=s.entry-s.tp;
   }

   double tolerance=point*0.5;
   bool geometryOK=(s.direction>0)
      ? (s.entry>=tick.ask+minDist-tolerance &&
         s.sl<=s.entry-minDist+tolerance &&
         s.tp>=s.entry+minDist-tolerance)
      : (s.entry<=tick.bid-minDist+tolerance &&
         s.sl>=s.entry+minDist+tolerance &&
         s.tp<=s.entry-minDist+tolerance);

   Print("STB_ORDERCHECK_DIAG ",caller,
         " symbol=",symbol,
         " type=",(s.direction>0 ? "BUY_STOP":"SELL_STOP"),
         " volume=",DoubleToString(volume,3),
         " requestPrice=",DoubleToString(s.entry,digits),
         " sl=",DoubleToString(s.sl,digits),
         " tp=",DoubleToString(s.tp,digits),
         " bid=",DoubleToString(tick.bid,digits),
         " ask=",DoubleToString(tick.ask,digits),
         " entryToMarket=",DoubleToString(entryToMarket,digits),
         " slToEntry=",DoubleToString(slToEntry,digits),
         " tpToEntry=",DoubleToString(tpToEntry,digits),
         " point=",DoubleToString(point,digits),
         " tickSize=",DoubleToString(tickSize,digits),
         " stopsLevel=",IntegerToString((int)stopsLevel),
         " freezeLevel=",IntegerToString((int)freezeLevel),
         " minDist=",DoubleToString(minDist,digits),
         " tolerance=",DoubleToString(tolerance,digits),
         " geometryOK=",geometryOK ? "YES":"NO",
         " spread=",IntegerToString((int)spread),
         " tradeMode=",IntegerToString((int)tradeMode),
         " orderMode=",IntegerToString((int)orderMode),
         " fillModes=",IntegerToString((int)fillModes),
         " expModes=",IntegerToString((int)expModes),
         " typeTime=",IntegerToString((int)typeTime),
         " expiration=",IntegerToString((int)expiration),
         " marginFree=",DoubleToString(marginFree,2),
         " marginLevel=",DoubleToString(marginLevel,2));

   // Probe 1: exact replay of the EA request (identical request fields).
   STB_OrderCheckProbe("REPLAY",symbol,orderType,volume,
                       s.entry,s.sl,s.tp,typeTime,expiration);

   // Probe 2: POSITIVE CONTROL - far from market, tiny volume, GTC.
   double ctrlDist=20.0*MathMax(minDist,point);
   double cPrice=0.0,cSL=0.0,cTP=0.0;
   if(s.direction>0)
   {
      cPrice=NormalizePrice(symbol,tick.ask+ctrlDist);
      cSL  =NormalizePrice(symbol,cPrice-10.0*minDist);
      cTP  =NormalizePrice(symbol,cPrice+10.0*minDist);
   }
   else
   {
      cPrice=NormalizePrice(symbol,tick.bid-ctrlDist);
      cSL  =NormalizePrice(symbol,cPrice+10.0*minDist);
      cTP  =NormalizePrice(symbol,cPrice-10.0*minDist);
   }
   STB_OrderCheckProbe("POSITIVE_CONTROL",symbol,orderType,0.01,
                       cPrice,cSL,cTP,ORDER_TIME_GTC,0);

   // Probe 3: NEGATIVE CONTROL - entry on the WRONG side of the market.
   double bPrice=0.0,bSL=0.0,bTP=0.0;
   if(s.direction>0)
   {
      bPrice=NormalizePrice(symbol,tick.ask-minDist);
      bSL   =NormalizePrice(symbol,bPrice-10.0*minDist);
      bTP   =NormalizePrice(symbol,bPrice+10.0*minDist);
   }
   else
   {
      bPrice=NormalizePrice(symbol,tick.bid+minDist);
      bSL   =NormalizePrice(symbol,bPrice+10.0*minDist);
      bTP   =NormalizePrice(symbol,bPrice-10.0*minDist);
   }
   STB_OrderCheckProbe("NEGATIVE_CONTROL",symbol,orderType,0.01,
                       bPrice,bSL,bTP,ORDER_TIME_GTC,0);
}

//--------------------------------------------------------------------
// Diagnostic delegate: runs the read-only probe set, then delegates
// to the UNCHANGED execution gate CheckPendingOrder and returns its
// exact result. The execution owner stays CheckPendingOrder.
//--------------------------------------------------------------------
bool STB_OrderCheckDiagnoseAndCheck(const Setup &s,
                                    const double volume,
                                    const ENUM_ORDER_TYPE_TIME typeTime,
                                    const datetime expiration)
{
   STB_PendingOrderCheckDiagnose(s,volume,typeTime,expiration,"EXECUTE_SETUP");

   bool ok=CheckPendingOrder(s,volume,typeTime,expiration);

   Print("STB_ORDERCHECK_RESULT ",
         " symbol=",s.symbol,
         " type=",(s.direction>0 ? "BUY_STOP":"SELL_STOP"),
         " gateResult=",ok ? "PASS":"REJECT");

   return ok;
}

#endif // STB_ORDERCHECK_DIAGNOSE_MQH