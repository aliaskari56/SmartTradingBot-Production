#property strict
#property script_show_inputs
#property description "Read-only SmartTradingBot scanner-universe diagnostics. Does not submit or modify orders."

input bool InpSelectedSymbolsOnly = true;
input int  InpMaxSymbols = 500;
input int  InpMaxQuoteAgeSeconds = 300;
input int  InpRequiredM15Bars = 240;
input int  InpRequiredH4Bars = 180;
input double InpRelativeSpreadCapPct = 10.0;

bool IsInsideTradeSession(const string symbol,const datetime now)
  {
   if(now<=0)
      return false;

   MqlDateTime day;
   if(!TimeToStruct(now,day))
      return false;

   int nowSec=day.hour*3600+day.min*60+day.sec;

   for(uint session=0;session<32;session++)
     {
      datetime from=0,to=0;
      if(!SymbolInfoSessionTrade(symbol,(ENUM_DAY_OF_WEEK)day.day_of_week,
                                 session,from,to))
         break;

      MqlDateTime f,t;
      TimeToStruct(from,f);
      TimeToStruct(to,t);

      int fromSec=f.hour*3600+f.min*60+f.sec;
      int toSec=t.hour*3600+t.min*60+t.sec;

      if(fromSec==toSec)
         return true;

      if(fromSec<toSec)
        {
         if(nowSec>=fromSec && nowSec<=toSec)
            return true;
        }
      else
        {
         if(nowSec>=fromSec || nowSec<=toSec)
            return true;
        }
     }

   return false;
  }

double CalculateM15ATR14(const string symbol,bool &ready)
  {
   ready=false;
   MqlRates r[];
   ArraySetAsSeries(r,true);
   int copied=CopyRates(symbol,PERIOD_M15,0,16,r);
   if(copied<16)
      return 0.0;

   double sum=0.0;
   for(int i=1;i<=14;i++)
     {
      double range1=r[i].high-r[i].low;
      double range2=MathAbs(r[i].high-r[i+1].close);
      double range3=MathAbs(r[i].low-r[i+1].close);
      sum+=MathMax(range1,MathMax(range2,range3));
     }

   double atr=sum/14.0;
   if(!MathIsValidNumber(atr) || atr<=0.0)
      return 0.0;

   ready=true;
   return atr;
  }

void OnStart()
  {
   int total=(InpSelectedSymbolsOnly ? SymbolsTotal(true):SymbolsTotal(false));
   int limit=MathMin(total,MathMax(1,InpMaxSymbols));

   datetime serverNow=TimeTradeServer();
   if(serverNow<=0)
      serverNow=TimeCurrent();

   string stamp=TimeToString(TimeLocal(),TIME_DATE|TIME_MINUTES);
   StringReplace(stamp,".","");
   StringReplace(stamp,":","");
   StringReplace(stamp," ","_");
   string filename="STB_ScannerDiag_"+stamp+".csv";

   ResetLastError();
   int file=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,';');
   if(file==INVALID_HANDLE)
     {
      Print("STB_DIAG_ERROR cannot open CSV. error=",GetLastError(),
            " expected folder=MQL5\\Files");
      return;
     }

   FileWrite(file,
      "symbol","selected","synchronized","session_open",
      "trade_mode","order_mode","m15_bars","h4_bars",
      "has_tick","tick_time","quote_age_seconds","quote_fresh",
      "bid","ask","spread_price","spread_points",
      "m15_atr14","relative_spread_pct","reason");

   int noTickCount=0;
   int staleCount=0;
   int dataCount=0;
   int sessionClosedCount=0;
   int spreadCount=0;

   for(int i=0;i<limit;i++)
     {
      string symbol=SymbolName(i,InpSelectedSymbolsOnly);
      if(symbol=="")
         continue;

      bool selected=(bool)SymbolInfoInteger(symbol,SYMBOL_SELECT);
      bool synchronized=SymbolIsSynchronized(symbol);
      long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
      int m15Bars=Bars(symbol,PERIOD_M15);
      int h4Bars=Bars(symbol,PERIOD_H4);
      bool sessionOpen=IsInsideTradeSession(symbol,serverNow);

      MqlTick tick;
      ZeroMemory(tick);
      bool hasTick=SymbolInfoTick(symbol,tick);

      long age=-999;
      if(hasTick && tick.time>0 && serverNow>0)
         age=(long)serverNow-(long)tick.time;

      int ageLimit=(int)MathMax(30,InpMaxQuoteAgeSeconds);
      bool quoteFresh=(hasTick && tick.time>0 &&
                       age>=-2 && age<=ageLimit &&
                       tick.bid>0.0 && tick.ask>=tick.bid);

      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double spreadPrice=(hasTick ? tick.ask-tick.bid:0.0);
      double spreadPoints=(point>0.0 ? spreadPrice/point:0.0);

      bool atrReady=false;
      double atr=CalculateM15ATR14(symbol,atrReady);
      double relSpread=(atrReady && spreadPrice>=0.0 ?
                        spreadPrice/atr*100.0:-1.0);

      string reason="OK";
      if(!hasTick)
        {
         reason="NO_TICK";
         noTickCount++;
        }
      else if(!sessionOpen)
        {
         reason="OUTSIDE_TRADE_SESSION";
         sessionClosedCount++;
        }
      else if(!synchronized)
        {
         reason="SYMBOL_NOT_SYNCHRONIZED";
         dataCount++;
        }
      else if(age < -2)
        {
         reason="FUTURE_DATED_QUOTE";
        }
      else if(!quoteFresh)
        {
         reason="STALE_OR_INVALID_QUOTE";
         staleCount++;
        }
      else if(m15Bars<InpRequiredM15Bars && h4Bars<InpRequiredH4Bars)
        {
         reason="M15_AND_H4_HISTORY_SHORT";
         dataCount++;
        }
      else if(m15Bars<InpRequiredM15Bars)
        {
         reason="M15_HISTORY_SHORT";
         dataCount++;
        }
      else if(h4Bars<InpRequiredH4Bars)
        {
         reason="H4_HISTORY_SHORT";
         dataCount++;
        }
      else if(!atrReady)
        {
         reason="M15_ATR_UNAVAILABLE";
         dataCount++;
        }
      else if(InpRelativeSpreadCapPct>0.0 &&
              relSpread>InpRelativeSpreadCapPct)
        {
         reason="RELATIVE_SPREAD_OVER_CAP";
         spreadCount++;
        }

      FileWrite(file,
         symbol,
         (selected ? "true":"false"),
         (synchronized ? "true":"false"),
         (sessionOpen ? "true":"false"),
         (string)tradeMode,
         (string)orderMode,
         (string)m15Bars,
         (string)h4Bars,
         (hasTick ? "true":"false"),
         (tick.time>0 ? TimeToString(tick.time,TIME_DATE|TIME_SECONDS):""),
         (string)age,
         (quoteFresh ? "true":"false"),
         DoubleToString(tick.bid,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         DoubleToString(tick.ask,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         DoubleToString(spreadPrice,10),
         DoubleToString(spreadPoints,2),
         DoubleToString(atr,10),
         DoubleToString(relSpread,3),
         reason);

      if(reason!="OK")
         Print("STB_DIAG symbol=",symbol,
               " reason=",reason,
               " session=",sessionOpen,
               " synced=",synchronized,
               " M15bars=",m15Bars,
               " H4bars=",h4Bars,
               " ageSec=",age,
               " relSpreadPct=",DoubleToString(relSpread,3));
     }

   FileClose(file);

   Print("STB_DIAG_COMPLETE symbols=",limit,
         " totalAvailable=",total,
         " noTick=",noTickCount,
         " outsideSession=",sessionClosedCount,
         " staleQuote=",staleCount,
         " dataOrHistory=",dataCount,
         " relativeSpreadOverCap=",spreadCount,
         " serverTime=",TimeToString(serverNow,TIME_DATE|TIME_SECONDS),
         " csv=MQL5\\Files\\",filename,
         " noOrdersSubmitted=true");
  }
