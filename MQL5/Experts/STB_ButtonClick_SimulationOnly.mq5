//+------------------------------------------------------------------+
//| STB_ButtonClick_SimulationOnly.mq5                               |
//| UI event diagnostic only. It cannot submit, modify, or close     |
//| any trade/order. This file is intentionally separate from the EA. |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "SIMULATION ONLY: tests chart button click events; sends no trade requests."

#define SIM_PREFIX "STB_SIM_ONLY_"

bool CreateSimButton(const string name,
                     const string caption,
                     const int x,
                     const int y)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
   {
      Print("SIM-ONLY: ObjectCreate failed. object=", name,
            " error=", GetLastError());
      return false;
   }

   bool ok = true;
   ok = ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_XSIZE, 145) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_YSIZE, 22) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_SELECTED, false) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_STATE, false) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_HIDDEN, false) && ok;
   ok = ObjectSetInteger(0, name, OBJPROP_ZORDER, 100000) && ok;
   ok = ObjectSetString(0, name, OBJPROP_TEXT, caption) && ok;

   if(!ok)
   {
      Print("SIM-ONLY: failed to configure button. object=", name,
            " error=", GetLastError());
      ObjectDelete(0, name);
      return false;
   }

   return true;
}

int OnInit()
{
   Print("SIM-ONLY diagnostic loaded. No trade API is used; no orders can be sent.");

   bool ok = true;
   ok = CreateSimButton(SIM_PREFIX "BUY_STOP",  "SIM: BUY STOP",  16, 108) && ok;
   ok = CreateSimButton(SIM_PREFIX "SELL_STOP", "SIM: SELL STOP", 16, 82)  && ok;
   ok = CreateSimButton(SIM_PREFIX "BUY_LIMIT", "SIM: BUY LIMIT", 16, 56)  && ok;
   ok = CreateSimButton(SIM_PREFIX "SELL_LIMIT","SIM: SELL LIMIT",16, 30)  && ok;

   ChartRedraw(0);

   if(!ok)
   {
      Print("SIM-ONLY: one or more buttons could not be created.");
      return INIT_FAILED;
   }

   Comment("SIMULATION ONLY - no trading requests are possible.\n",
           "Click a button and check the Experts log for SIM-ONLY CLICK.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, SIM_PREFIX "BUY_STOP");
   ObjectDelete(0, SIM_PREFIX "SELL_STOP");
   ObjectDelete(0, SIM_PREFIX "BUY_LIMIT");
   ObjectDelete(0, SIM_PREFIX "SELL_LIMIT");
   Comment("");
   ChartRedraw(0);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(StringFind(sparam, SIM_PREFIX) != 0)
      return;

   // Release the toggle state so the same button can be clicked repeatedly.
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   ChartRedraw(0);

   Print("SIM-ONLY CLICK captured | object=", sparam,
         " | event=CHARTEVENT_OBJECT_CLICK",
         " | action=UI_DIAGNOSTIC_ONLY",
         " | trade_request_sent=NO");

   Comment("SIMULATION ONLY - last click captured:\n", sparam,
           "\nNo trade request was sent.");
}
