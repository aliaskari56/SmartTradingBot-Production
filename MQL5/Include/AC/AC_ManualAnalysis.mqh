//+------------------------------------------------------------------+
//| AC_ManualAnalysis.mqh                                            |
//| ASTRACORE MANUAL ANALYSIS TOOLKIT (ACMA_) - ANALYSIS ONLY        |
//|                                                                  |
//| MASTER EXECUTION TASK Phases 35-37.                              |
//| Independent manual visualization namespace: ACMA_                |
//|                                                                  |
//| AVAILABLE TOOLS (no Trendline, no Ray):                          |
//|   ACMA_Horizontal        - Horizontal Level (OBJ_HLINE)          |
//|   ACMA_Vertical          - Vertical Marker   (OBJ_VLINE)         |
//|   ACMA_Rectangle         - Rectangle Zone    (OBJ_RECTANGLE)     |
//|   ACMA_FibRetracement    - Fibonacci Retracement (OBJ_FIBO)      |
//|   ACMA_FibExtension      - Fibonacci Extension   (OBJ_FIBO)      |
//|   ACMA_Text              - Text Note          (OBJ_TEXT)         |
//|   ACMA_Marker            - Point/Marker       (OBJ_ARROW)        |
//|                                                                  |
//| ISOLATION RULES:                                                 |
//|   * objects are owned ONLY by namespace ACMA_                    |
//|   * never recreated by Smart ZigZag / Channel / Dashboard        |
//|   * never deleted by ACSS cleanup (ACSS_/ACSC_ prefixes only)    |
//|   * removed ONLY by explicit ACMA_Cleanup() (or user)            |
//|                                                                  |
//| This file contains no automatic drawing and no trading calls.    |
//+------------------------------------------------------------------+
#property strict

//--- namespace prefix -------------------------------------------------
#define ACMA_PREFIX "ACMA_"

string ACMA_Name(const string tag)
  {
   return ACMA_PREFIX+tag;
  }

//--- horizontal level (OBJ_HLINE) --------------------------------------
bool ACMA_Horizontal(const string tag,const double price,const color clr)
  {
   string name=ACMA_Name(tag);
   ObjectDelete(0,name);
   if(price<=0.0) return false;
   if(!ObjectCreate(0,name,OBJ_HLINE,0,0,price)) return false;
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   return true;
  }

//--- vertical marker (OBJ_VLINE) ----------------------------------------
bool ACMA_Vertical(const string tag,const datetime t,const color clr)
  {
   string name=ACMA_Name(tag);
   ObjectDelete(0,name);
   if(t<=0) return false;
   if(!ObjectCreate(0,name,OBJ_VLINE,0,t,0.0)) return false;
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   return true;
  }

//--- rectangle zone (OBJ_RECTANGLE) --------------------------------------
bool ACMA_Rectangle(const string tag,const datetime t1,const double p1,
                    const datetime t2,const double p2,const color clr)
  {
   string name=ACMA_Name(tag);
   ObjectDelete(0,name);
   if(t1<=0||t2<=0||p1<=0.0||p2<=0.0) return false;
   if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,p1,t2,p2)) return false;
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   return true;
  }

//--- fibonacci level layout helper ---------------------------------------
void ACMA_FibStyle(const string name,const color clr)
  {
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_LEVELCOLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
  }

//--- fibonacci retracement (OBJ_FIBO) ------------------------------------
bool ACMA_FibRetracement(const string tag,const datetime t1,const double p1,
                         const datetime t2,const double p2,const color clr)
  {
   string name=ACMA_Name(tag);
   ObjectDelete(0,name);
   if(t1<=0||t2<=0||p1<=0.0||p2<=0.0) return false;
   if(!ObjectCreate(0,name,OBJ_FIBO,0,t1,p1,t2,p2)) return false;
   ACMA_FibStyle(name,clr);
   return true;
  }

//--- fibonacci extension (OBJ_FIBO) ---------------------------------------
bool ACMA_FibExtension(const string tag,const datetime t1,const double p1,
                       const datetime t2,const double p2,const color clr)
  {
   string name=ACMA_Name(tag);
   ObjectDelete(0,name);
   if(t1<=0||t2<=0||p1<=0.0||p2<=0.0) return false;
   if(!ObjectCreate(0,name,OBJ_FIBO,0,t1,p1,t2,p2)) return false;
   ACMA_FibStyle(name,clr);
   return true;
  }

//--- text note (OBJ_TEXT) --------------------------------------------------
bool ACMA_Text(const string tag,const datetime t,const double price,
               const string text,const color clr,const int fontSize=8)
  {
   string name=ACMA_Name(tag);
   ObjectDelete(0,name);
   if(t<=0||price<=0.0||text=="") return false;
   if(!ObjectCreate(0,name,OBJ_TEXT,0,t,price)) return false;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   return true;
  }

//--- point / marker (OBJ_ARROW) ---------------------------------------------
bool ACMA_Marker(const string tag,const datetime t,const double price,
                 const color clr,const int arrowCode=159)
  {
   string name=ACMA_Name(tag);
   ObjectDelete(0,name);
   if(t<=0||price<=0.0) return false;
   if(!ObjectCreate(0,name,OBJ_ARROW,0,t,price)) return false;
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,arrowCode);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   return true;
  }

//--- manual object count (read-only) -----------------------------------------
int ACMA_Count()
  {
   int total=0;
   int n=ObjectsTotal(0,-1,-1);
   for(int i=0;i<n;i++)
     {
      string nm=ObjectName(0,i,-1,-1);
      if(StringFind(nm,ACMA_PREFIX)==0) total++;
     }
   return total;
  }

//--- explicit cleanup (only THIS removes manual objects) ----------------------
void ACMA_Cleanup()
  {
   ObjectsDeleteAll(0,ACMA_PREFIX);
  }
//+------------------------------------------------------------------+
