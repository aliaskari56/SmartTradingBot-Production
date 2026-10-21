#property strict
#property version   "1.000"
#property description "SmartTradingBot backtest-only harness. It NEVER sends live or pending orders."

// Simulation-only research harness. No CTrade, OrderSend, Buy/Sell, or PositionModify calls.
// Signals are evaluated on completed bars. Virtual positions are used only for tester statistics.

input int      InpFastEMA       = 12;
input int      InpSlowEMA       = 26;
input int      InpATRPeriod     = 14;
input double   InpSL_ATR        = 1.5;
input double   InpTP_ATR        = 2.0;
input double   InpTrail_ATR     = 1.0;
input double   InpRiskPct       = 0.25; // virtual equity risk only; no real order sizing
input double   InpStartBalance  = 10000.0;
input bool     InpAllowLong     = true;
input bool     InpAllowShort    = true;
input bool     InpUseTrailing   = true;

int hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE, hATR = INVALID_HANDLE;
datetime lastBar = 0;

struct VirtualTrade
{
   bool     active;
   int      direction; // +1 long, -1 short
   datetime entryTime;
   double   entry;
   double   sl;
   double   tp;
   double   volume;
   double   riskMoney;
};
VirtualTrade vt;

double simBalance = 0.0, peakBalance = 0.0, maxDrawdownPct = 0.0;
int trades = 0, wins = 0, losses = 0;
double grossProfit = 0.0, grossLoss = 0.0;

bool ReadValue(const int handle, const int shift, double &value)
{
   double b[];
   ArraySetAsSeries(b, true);
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return false;
   value = b[0];
   return MathIsValidNumber(value) && value != EMPTY_VALUE;
}

double NormalizePrice(const double p)
{
   return NormalizeDouble(p, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double VirtualVolume(const double entry, const double sl, const double riskMoney)
{
   double loss1Lot = 0.0;
   ENUM_ORDER_TYPE type = (sl < entry ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, loss1Lot)) return 0.0;
   loss1Lot = MathAbs(loss1Lot);
   if(loss1Lot <= 0.0) return 0.0;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0 || vmin <= 0.0 || vmax < vmin) return 0.0;
   double raw = riskMoney / loss1Lot;
   double vol = MathFloor(raw / step) * step;
   // If the minimum volume exceeds the intended virtual risk, skip instead of rounding up.
   if(vol < vmin || vol > vmax) return 0.0;
   return NormalizeDouble(vol, 8);
}

void UpdateDrawdown()
{
   if(simBalance > peakBalance) peakBalance = simBalance;
   if(peakBalance > 0.0)
   {
      double dd = (peakBalance - simBalance) / peakBalance * 100.0;
      if(dd > maxDrawdownPct) maxDrawdownPct = dd;
   }
}

void CloseVirtual(const double exitPrice, const string reason)
{
   if(!vt.active) return;
   double pnl = 0.0;
   ENUM_ORDER_TYPE type = (vt.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type, _Symbol, vt.volume, vt.entry, exitPrice, pnl))
   {
      Print("SIM_CLOSE_CALC_FAILED; trade retained; reason=", reason);
      return;
   }
   simBalance += pnl;
   trades++;
   if(pnl >= 0.0) { wins++; grossProfit += pnl; }
   else           { losses++; grossLoss += MathAbs(pnl); }
   Print("SIM_CLOSE direction=", vt.direction,
         " entry=", DoubleToString(vt.entry, _Digits),
         " exit=", DoubleToString(exitPrice, _Digits),
         " pnl=", DoubleToString(pnl, 2),
         " balance=", DoubleToString(simBalance, 2),
         " reason=", reason);
   vt.active = false;
   UpdateDrawdown();
}

void ManageVirtual(const MqlRates &bar, const double atr)
{
   if(!vt.active) return;
   // Conservative bar simulation: if SL and TP both fall inside one candle, assume SL first.
   if(vt.direction > 0)
   {
      if(bar.low <= vt.sl) { CloseVirtual(vt.sl, "SL"); return; }
      if(bar.high >= vt.tp) { CloseVirtual(vt.tp, "TP"); return; }
      if(InpUseTrailing && atr > 0.0)
      {
         double nextSL = NormalizePrice(bar.close - atr * InpTrail_ATR);
         if(nextSL > vt.sl && nextSL < bar.close) vt.sl = nextSL;
      }
   }
   else
   {
      if(bar.high >= vt.sl) { CloseVirtual(vt.sl, "SL"); return; }
      if(bar.low <= vt.tp) { CloseVirtual(vt.tp, "TP"); return; }
      if(InpUseTrailing && atr > 0.0)
      {
         double nextSL = NormalizePrice(bar.close + atr * InpTrail_ATR);
         if(nextSL < vt.sl && nextSL > bar.close) vt.sl = nextSL;
      }
   }
}

void OpenVirtual(const int direction, const double entry, const double atr, const datetime when)
{
   if(vt.active || atr <= 0.0 || InpRiskPct <= 0.0) return;
   double sl = NormalizePrice(entry - direction * atr * InpSL_ATR);
   double tp = NormalizePrice(entry + direction * atr * InpTP_ATR);
   double riskMoney = simBalance * InpRiskPct / 100.0;
   double volume = VirtualVolume(entry, sl, riskMoney);
   if(volume <= 0.0)
   {
      Print("SIM_ENTRY_SKIPPED volume/risk constraints; direction=", direction);
      return;
   }
   vt.active = true;
   vt.direction = direction;
   vt.entryTime = when;
   vt.entry = NormalizePrice(entry);
   vt.sl = sl;
   vt.tp = tp;
   vt.volume = volume;
   vt.riskMoney = riskMoney;
   Print("SIM_OPEN direction=", direction, " time=", TimeToString(when),
         " entry=", DoubleToString(vt.entry, _Digits),
         " sl=", DoubleToString(vt.sl, _Digits),
         " tp=", DoubleToString(vt.tp, _Digits),
         " virtualVolume=", DoubleToString(vt.volume, 4),
         " plannedRisk=", DoubleToString(riskMoney, 2));
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print("INIT_FAILED: this expert is restricted to Strategy Tester; it does not run on charts.");
      return INIT_FAILED;
   }
   if(InpFastEMA < 2 || InpSlowEMA <= InpFastEMA || InpATRPeriod < 2 ||
      InpSL_ATR <= 0.0 || InpTP_ATR <= 0.0 || InpRiskPct <= 0.0 ||
      InpRiskPct > 0.50 || InpStartBalance <= 0.0)
   {
      Print("INIT_FAILED: invalid parameters; virtual risk must be <= 0.50%.");
      return INIT_PARAMETERS_INCORRECT;
   }
   hFast = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hATR  = iATR(_Symbol, _Period, InpATRPeriod);
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE || hATR == INVALID_HANDLE)
   {
      Print("INIT_FAILED: indicator handle creation failed.");
      return INIT_FAILED;
   }
   simBalance = InpStartBalance;
   peakBalance = simBalance;
   vt.active = false;
   Print("BACKTEST_ONLY_READY; no real or pending orders are ever submitted.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hATR  != INVALID_HANDLE) IndicatorRelease(hATR);
   double pf = (grossLoss > 0.0 ? grossProfit / grossLoss : (grossProfit > 0.0 ? 999.0 : 0.0));
   Print("SIM_REPORT trades=", trades, " wins=", wins, " losses=", losses,
         " winRatePct=", (trades > 0 ? DoubleToString(100.0*wins/trades, 2) : "0.00"),
         " profitFactor=", DoubleToString(pf, 3),
         " net=", DoubleToString(simBalance - InpStartBalance, 2),
         " finalBalance=", DoubleToString(simBalance, 2),
         " maxDrawdownPct=", DoubleToString(maxDrawdownPct, 2),
         " reason=", reason);
}

void OnTick()
{
   if(!MQLInfoInteger(MQL_TESTER)) return;
   datetime t = iTime(_Symbol, _Period, 0);
   if(t == 0 || t == lastBar) return;
   lastBar = t;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, _Period, 1, 2, bars) < 2) return;

   double fast1, fast2, slow1, slow2, atr1;
   if(!ReadValue(hFast, 1, fast1) || !ReadValue(hFast, 2, fast2) ||
      !ReadValue(hSlow, 1, slow1) || !ReadValue(hSlow, 2, slow2) ||
      !ReadValue(hATR, 1, atr1)) return;

   // Manage exits using the last completed candle before processing a new signal.
   ManageVirtual(bars[0], atr1);

   bool crossUp   = (fast2 <= slow2 && fast1 > slow1);
   bool crossDown = (fast2 >= slow2 && fast1 < slow1);
   if(vt.active)
   {
      if(vt.direction > 0 && crossDown) CloseVirtual(bars[0].close, "OPPOSITE_SIGNAL");
      else if(vt.direction < 0 && crossUp) CloseVirtual(bars[0].close, "OPPOSITE_SIGNAL");
   }
   if(!vt.active)
   {
      if(crossUp && InpAllowLong) OpenVirtual(+1, bars[0].close, atr1, bars[0].time);
      else if(crossDown && InpAllowShort) OpenVirtual(-1, bars[0].close, atr1, bars[0].time);
   }
}
