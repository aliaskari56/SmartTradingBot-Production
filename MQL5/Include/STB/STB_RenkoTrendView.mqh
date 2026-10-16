#ifndef STB_RENKO_TREND_VIEW_MQH
#define STB_RENKO_TREND_VIEW_MQH

// Chart-only Renko overlay. This module must not place or manage trades.
bool     g_stbRenkoViewEnabled = false;
string   g_stbRenkoPrefix      = "";
datetime g_stbRenkoLastBar     = 0;

// Delete only objects owned by this module. Never clear the chart when the
// prefix has not yet been initialized.
void STB_RenkoClear()
  {
   if(g_stbRenkoPrefix == "")
      return;

   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, g_stbRenkoPrefix) == 0)
         ObjectDelete(0, name);
     }
  }

void STB_RenkoRender()
  {
   if(!g_stbRenkoViewEnabled || g_stbRenkoPrefix == "")
      return;

   datetime currentBar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(currentBar == 0 || currentBar == g_stbRenkoLastBar)
      return;

   double brickPoints = InpRenkoBrickSizePoints;
   if(!MathIsValidNumber(brickPoints) || brickPoints <= 0.0 ||
      InpRenkoBarsToDraw < 20 || InpRenkoBarsToDraw > 500)
      return;

   g_stbRenkoLastBar = currentBar;
   double step = brickPoints * _Point;
   if(!MathIsValidNumber(step) || step <= 0.0)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);

   int requested = (int)MathMax(300, InpRenkoBarsToDraw * 8);
   requested = (int)MathMin(requested, 4000);
   int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, requested, rates);
   if(copied < 30)
      return;

   double lastClose = MathRound(rates[0].close / step) * step;
   int direction = 0;
   int count = 0;

   datetime brickTime[500];
   double brickOpen[500];
   double brickClose[500];
   int brickDirection[500];

   for(int i = 1; i < copied; i++)
     {
      double price = rates[i].close;
      int guard = 0;

      while(guard++ < 100)
        {
         double openPrice = lastClose;
         double closePrice = lastClose;
         int newDirection = 0;

         if(direction == 0)
           {
            if(price >= lastClose + step)
              {
               closePrice = lastClose + step;
               newDirection = 1;
              }
            else
               if(price <= lastClose - step)
                 {
                  closePrice = lastClose - step;
                  newDirection = -1;
                 }
               else
                  break;
           }
         else
            if(direction > 0)
              {
               if(price >= lastClose + step)
                 {
                  closePrice = lastClose + step;
                  newDirection = 1;
                 }
               else
                  if(price <= lastClose - 2.0 * step)
                    {
                     openPrice = lastClose - step;
                     closePrice = lastClose - 2.0 * step;
                     newDirection = -1;
                    }
                  else
                     break;
              }
            else
              {
               if(price <= lastClose - step)
                 {
                  closePrice = lastClose - step;
                  newDirection = -1;
                 }
               else
                  if(price >= lastClose + 2.0 * step)
                    {
                     openPrice = lastClose + step;
                     closePrice = lastClose + 2.0 * step;
                     newDirection = 1;
                    }
                  else
                     break;
              }

         if(count >= 500)
           {
            for(int k = 1; k < 500; k++)
              {
               brickTime[k - 1] = brickTime[k];
               brickOpen[k - 1] = brickOpen[k];
               brickClose[k - 1] = brickClose[k];
               brickDirection[k - 1] = brickDirection[k];
              }
            count = 499;
           }

         brickTime[count] = rates[i].time;
         brickOpen[count] = openPrice;
         brickClose[count] = closePrice;
         brickDirection[count] = newDirection;
         count++;

         lastClose = closePrice;
         direction = newDirection;
        }
     }

   STB_RenkoClear();

   for(int j = 0; j < count; j++)
     {
      string name = g_stbRenkoPrefix + "B" + IntegerToString(j);
      datetime endTime = brickTime[j] +
                         (datetime)MathMax(60, PeriodSeconds((ENUM_TIMEFRAMES)_Period));

      double highPrice = MathMax(brickOpen[j], brickClose[j]);
      double lowPrice = MathMin(brickOpen[j], brickClose[j]);

      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                      brickTime[j], highPrice, endTime, lowPrice))
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR,
                          brickDirection[j] > 0 ? clrDodgerBlue : clrTomato);
         ObjectSetInteger(0, name, OBJPROP_FILL, true);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        }
     }

   // Draw automatic resistance/support trendlines using the last two
   // confirmed Renko reversal pivots. User-created chart trendlines are untouched.
   int high1 = -1;
   int high2 = -1;
   int low1  = -1;
   int low2  = -1;

   for(int j = 1; j < count; j++)
     {
      if(brickDirection[j - 1] > 0 && brickDirection[j] < 0)
        {
         high2 = high1;
         high1 = j - 1;
        }

      if(brickDirection[j - 1] < 0 && brickDirection[j] > 0)
        {
         low2 = low1;
         low1 = j - 1;
        }
     }

   if(high1 >= 0 && high2 >= 0 && brickTime[high2] < brickTime[high1])
     {
      string name = g_stbRenkoPrefix + "HIGH";
      if(ObjectCreate(0, name, OBJ_TREND, 0,
                      brickTime[high2], brickClose[high2],
                      brickTime[high1], brickClose[high1]))
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        }
     }

   if(low1 >= 0 && low2 >= 0 && brickTime[low2] < brickTime[low1])
     {
      string name = g_stbRenkoPrefix + "LOW";
      if(ObjectCreate(0, name, OBJ_TREND, 0,
                      brickTime[low2], brickClose[low2],
                      brickTime[low1], brickClose[low1]))
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrDeepSkyBlue);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        }
     }

   ChartRedraw(0);
  }

void STB_RenkoSetEnabled(const bool enabled)
  {
   g_stbRenkoViewEnabled = enabled;
   g_stbRenkoLastBar = 0;

   if(!enabled)
      STB_RenkoClear();
   else
      STB_RenkoRender();
  }

void STB_RenkoInit()
  {
   g_stbRenkoPrefix = g_prefix + "RENKO_";
   g_stbRenkoViewEnabled = InpShowRenkoTrendView;
   g_stbRenkoLastBar = 0;

   if(g_stbRenkoViewEnabled)
      STB_RenkoRender();
   else
      STB_RenkoClear();
  }

#endif // STB_RENKO_TREND_VIEW_MQH
