#ifndef STB_RENKO_TREND_VIEW_MQH
#define STB_RENKO_TREND_VIEW_MQH
bool g_stbRenkoViewEnabled=false;
string g_stbRenkoPrefix="";
datetime g_stbRenkoLastBar=0;
void STB_RenkoClear()
{
 int n=ObjectsTotal(0,-1,-1);
 for(int i=n-1;i>=0;i--)
 {
  string name=ObjectName(0,i,-1,-1);
  if(StringFind(name,g_stbRenkoPrefix)==0) ObjectDelete(0,name);
 }
}
void STB_RenkoRender()
{
 if(!g_stbRenkoViewEnabled) return;
 datetime bar=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
 if(bar==0 || bar==g_stbRenkoLastBar) return;
 g_stbRenkoLastBar=bar;
 double step=InpRenkoBrickSizePoints*_Point;
 if(step<=0 || InpRenkoBarsToDraw<20 || InpRenkoBarsToDraw>500) return;
 MqlRates r[];
 ArraySetAsSeries(r,false);
 int copied=CopyRates(_Symbol,(ENUM_TIMEFRAMES)_Period,1,MathMin(4000,MathMax(300,InpRenkoBarsToDraw*8)),r);
 if(copied<30) return;
 double last=MathRound(r[0].close/step)*step;
 int dir=0, count=0, maxCount=InpRenkoBarsToDraw;
 datetime ts[500]; double op[500],cl[500]; int dr[500];
 for(int i=1;i<copied;i++)
 {
  double p=r[i].close; int guard=0;
  while(guard++<100)
  {
   double o=last,c=last; int d=0;
   if(dir==0)
   { if(p>=last+step){c=last+step;d=1;} else if(p<=last-step){c=last-step;d=-1;} else break; }
   else if(dir>0)
   { if(p>=last+step){c=last+step;d=1;} else if(p<=last-2*step){o=last-step;c=last-2*step;d=-1;} else break; }
   else
   { if(p<=last-step){c=last-step;d=-1;} else if(p>=last+2*step){o=last+step;c=last+2*step;d=1;} else break; }
   if(count==500)
   {
    for(int k=1;k<500;k++){ts[k-1]=ts[k];op[k-1]=op[k];cl[k-1]=cl[k];dr[k-1]=dr[k];}
    count=499;
   }
   ts[count]=r[i].time;op[count]=o;cl[count]=c;dr[count]=d;count++;last=c;dir=d;
  }
 }
 STB_RenkoClear();
 for(int j=0;j<count;j++)
 {
  string nm=g_stbRenkoPrefix+"B"+IntegerToString(j);
  datetime t2=ts[j]+(datetime)MathMax(60,PeriodSeconds((ENUM_TIMEFRAMES)_Period));
  if(ObjectCreate(0,nm,OBJ_RECTANGLE,0,ts[j],MathMax(op[j],cl[j]),t2,MathMin(op[j],cl[j])))
  {
   ObjectSetInteger(0,nm,OBJPROP_COLOR,dr[j]>0?clrDodgerBlue:clrTomato);
   ObjectSetInteger(0,nm,OBJPROP_FILL,true);ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
  }
 }
 int h1=-1,h2=-1,l1=-1,l2=-1;
 for(int j=1;j<count;j++)
 {
  if(dr[j-1]>0 && dr[j]<0){h2=h1;h1=j-1;}
  if(dr[j-1]<0 && dr[j]>0){l2=l1;l1=j-1;}
 }
 if(h1>=0 && h2>=0 && ts[h2]<ts[h1])
 {
  string nm=g_stbRenkoPrefix+"HIGH";
  if(ObjectCreate(0,nm,OBJ_TREND,0,ts[h2],cl[h2],ts[h1],cl[h1]))
  {ObjectSetInteger(0,nm,OBJPROP_COLOR,clrOrangeRed);ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,true);ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);}
 }
 if(l1>=0 && l2>=0 && ts[l2]<ts[l1])
 {
  string nm=g_stbRenkoPrefix+"LOW";
  if(ObjectCreate(0,nm,OBJ_TREND,0,ts[l2],cl[l2],ts[l1],cl[l1]))
  {ObjectSetInteger(0,nm,OBJPROP_COLOR,clrDeepSkyBlue);ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,true);ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);}
 }
 ChartRedraw(0);
}
void STB_RenkoSetEnabled(bool enabled)
{
 g_stbRenkoViewEnabled=enabled;g_stbRenkoLastBar=0;
 if(!enabled) STB_RenkoClear(); else STB_RenkoRender();
}
void STB_RenkoInit()
{
 g_stbRenkoPrefix=g_prefix+"RENKO_";
 g_stbRenkoViewEnabled=InpShowRenkoTrendView;g_stbRenkoLastBar=0;
 if(g_stbRenkoViewEnabled) STB_RenkoRender(); else STB_RenkoClear();
}
#endif