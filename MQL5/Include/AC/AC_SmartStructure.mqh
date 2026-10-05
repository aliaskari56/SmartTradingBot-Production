//+------------------------------------------------------------------+
//| AC_SmartStructure.mqh                                            |
//| ACSS - Advanced Smart ZigZag + DUAL Smart Channel engine         |
//| TASK 37. ANALYSIS + VISUALIZATION ONLY. READ-ONLY.              |
//|                                                                |
//| HARD LIMITS:                                                     |
//|   ACTIVE LONG-TERM CHANNEL  <= 1                                |
//|   ACTIVE SHORT-TERM CHANNEL <= 1                                |
//|   TOTAL ACTIVE CHANNELS     <= 2                                |
//|   Runtime assertion in ACSS_AssertLimits() logs the count.      |
//|                                                                |
//| No trading call is reachable from this module. No CTrade, no     |
//| OrderSend, no position/order modification. Objects use the      |
//| "ACSS_" namespace only and never touch the STB_ dashboard.      |
//+------------------------------------------------------------------+

//--- enums ----------------------------------------------------------
enum ENUM_ACSS_TF_MODE
  {
   ACSS_TF_AUTO    = 0,   // derive long/inter/short from chart TF
   ACSS_TF_MANUAL  = 1    // user selects long/short TF (long > short required)
  };

enum ENUM_ACSS_ZZ_MODE
  {
   ACSS_ZZ_NORMAL     = 0,  // balanced sensitivity
   ACSS_ZZ_AGGRESSIVE = 1,  // lower net threshold (more pivots)
   ACSS_ZZ_STRICT     = 2   // higher net threshold (fewer pivots)
  };

enum ENUM_ACSS_CH_MODEL
  {
   ACSS_CH_STRUCTURAL = 0,  // parallel line through dominant-polarity swings
   ACSS_CH_REGRESSION = 1,  // OLS fit of swing prices
   ACSS_CH_EXTREMES   = 2   // min/max envelope of window
  };

enum ENUM_ACSS_WIDTH_MODE
  {
   ACSS_WIDTH_ATR    = 0,   // width from ATR-normalized residual band
   ACSS_WIDTH_STDDEV = 1    // width from residual standard deviation
  };

enum ENUM_ACSS_CH_STATE
  {
   ACSS_STATE_NEUTRAL     = 0,
   ACSS_STATE_BULLISH     = 1,
   ACSS_STATE_BEARISH     = 2,
   ACSS_STATE_WEAKENING   = 3,
   ACSS_STATE_BROKEN_UP   = 4,
   ACSS_STATE_BROKEN_DOWN = 5,
   ACSS_STATE_RETEST      = 6,
   ACSS_STATE_INVALID     = 7
  };

enum ENUM_ACSS_BREAK
  {
   ACSS_BREAK_NONE          = 0,
   ACSS_BREAK_TENTATIVE     = 1,
   ACSS_BREAK_CONFIRMED     = 2,
   ACSS_BREAK_FALSE         = 3,
   ACSS_BREAK_RETEST        = 4,
   ACSS_BREAK_FAILED_RETEST = 5
  };

enum ENUM_ACSS_REGIME
  {
   ACSS_REGIME_TRENDING       = 0,
   ACSS_REGIME_RANGING        = 1,
   ACSS_REGIME_TRANSITION     = 2,
   ACSS_REGIME_EXPANSION      = 3,
   ACSS_REGIME_CONTRACTION    = 4,
   ACSS_REGIME_BREAKOUT       = 5,
   ACSS_REGIME_PULLBACK       = 6,
   ACSS_REGIME_REVERSAL_RISK  = 7
  };

enum ENUM_ACSS_MTF
  {
   ACSS_MTF_BULLISH_ALIGNMENT     = 0,
   ACSS_MTF_SHORT_TERM_PULLBACK   = 1,
   ACSS_MTF_INTERMEDIATE_CORRECTION=2,
   ACSS_MTF_COUNTER_TREND_RALLY   = 3,
   ACSS_MTF_BEARISH_ALIGNMENT     = 4,
   ACSS_MTF_MIXED                 = 5
  };

//--- structs ---------------------------------------------------------
// PHASE 59: advanced smart trendline engine — deterministic constants.
const int    ACSS_SMART_MAX_HISTORY    = 20;    // retained broken-line history objects (max)
const double ACSS_SMART_MAJOR_ATR_MULT = 1.00;  // major swing = recent leg >= 1.0 x ATR (current context)
const double ACSS_SMART_TOUCH_ZONE_ATR = 0.75;  // touch zone factor (bounded 0.25..1.5)
const double ACSS_SMART_BREAK_DISP_ATR = 0.50;  // minimum close displacement beyond the line
const int    ACSS_SMART_BREAK_PERSIST  = 2;     // consecutive closed bars beyond the line
const double ACSS_SMART_MIN_SCORE      = 30.0;  // below this: no candidate (NO FAKE TRENDLINE)
const double ACSS_SMART_REPLACE_DELTA  = 15.0;  // LOCKED replacement threshold (score points)

struct ACSS_Swing
  {
   datetime time;
   double   price;
   bool     isHigh;
   int      shift;
   bool     confirmed;
   double   score;
  };

struct ACSS_Leg
  {
   datetime t0;
   datetime t1;
   double   p0;
   double   p1;
   bool     up;
   double   distPts;
   double   distPct;
   double   atrMult;
   int      duration;
   double   slope;
   double   velocity;
   double   strength;
   int      cls;   // 1 = continuation, 0 = correction
  };

struct ACSS_StructEvent
  {
   datetime time;
   int      type;      // 0=HH 1=HL 2=LH 3=LL 4=BOS 5=CHoCH
   int      sigA;      // source swing index (confirmed array)
   int      sigB;      // reference swing index
   bool     confirmed;
   ulong    id;        // deterministic identity
  };

// PHASE 57: broken structural floor/ceiling level (closed-bar evidence)
struct ACSS_Level
  {
   double   price;
   int      kind;    // 0=floor 1=ceiling
   int      cls;     // 0=BOS 1=CHoCH
   datetime t;       // closed-bar break time
  };

struct ACSS_Channel
  {
   bool   valid;
   int    slot;        // 0 = long term, 1 = short term
   int    model;       // winning candidate model
   int    state;
   int    brk;
   double upper;
   double lower;
   double mid;
   double width;
   double slope;
   int    age;
   int    touches;
   double fit;
   double confidence;
   datetime anchorTime;
   double anchorPrice;
   datetime lastTouchTime;
   datetime breakTime;
   bool   brokenUp;
   bool   brokenDown;
  };

struct ACSS_TFState
  {
   int      direction;      // 1 bull, -1 bear, 0 neutral
   int      hh,hl,lh,ll;    // structure event counts
   int      bosCount;
   int      chochCount;
   datetime lastBosTime;
   datetime lastChochTime;
   double   qualityAvg;     // average confirmed swing score
  };

struct ACSS_Config
  {
   bool   enabled;
   int    tfMode;
   int    longTF;
   int    shortTF;
   int    interTF;
   int    lookback;
   int    visualLegs;      // PHASE 55: max rendered confirmed zigzag legs per TF (visual budget only)

   bool   showZigZag;
   bool   showSwings;
   bool   showHHLL;
   bool   showBOS;
   bool   showCHoCH;
   bool   showConfidence;
   bool   showRegime;

   int    zzMode;
   int    zzSensitivity;    // 50..200 %
   int    zzDepth;
   int    zzDeviation;      // % of ATR
   int    zzBackstep;
   bool   zzAdaptive;
   int    zzATRPeriod;
   int    zzVolMode;        // 0 = ATR, 1 = ATR/median normalization
   bool   zzSwingQuality;
   bool   zzShowProvisional;

   bool   longEnabled;
   bool   longShow;
   int    longModel;
   int    longMinTouches;
   int    longMaxBars;
   int    longWidthMode;
   int    longATRPeriod;
   bool   longShowMid;
   bool   longShowBrk;
   bool   longShowRetest;

   bool   shortEnabled;
   bool   shortShow;
   int    shortModel;
   int    shortMinTouches;
   int    shortMaxBars;
   int    shortWidthMode;
   int    shortATRPeriod;
   bool   shortShowMid;
   bool   shortShowBrk;
   bool   shortShowRetest;

   color  longColor;
   color  shortColor;
   int    lineWidth;
   int    lineStyle;
   color  midColor;
   int    midStyle;
   int    labelSize;
   int    pivotSize;
   bool   showDebug;
  };

//+------------------------------------------------------------------+
// PHASE 59: advanced smart trendline state machine (visual/analytical only)
enum ENUM_ACSS_SMART_STATE
  {
   ACSS_SMART_NONE      = 0,   // no active smart trendline
   ACSS_SMART_CANDIDATE = 1,   // 2 major confirmed swings -> candidate (not yet validated)
   ACSS_SMART_VALIDATED = 2,   // 3rd structural interaction confirmed the line
   ACSS_SMART_LOCKED    = 3,   // validated + promoted; replaced only if score improves enough
   ACSS_SMART_TOUCHED   = 4,   // first valid touch -> STYLE_DOT (same object, anchors kept)
   ACSS_SMART_BROKEN    = 5,   // confirmed break -> moved to HISTORY
   ACSS_SMART_ENDED     = 6    // history record state (not active)
  };

// PHASE 59: active smart trendline state (persisted across renders)
struct ACSS_SmartTrend
  {
   int      state;          // ENUM_ACSS_SMART_STATE
   int      dir;            // 1 = support (bull), -1 = resistance (bear), 0 = none
   datetime t0;
   datetime t1;
   double   p0;
   double   p1;
   double   score;          // structural score 0..100
   int      validations;    // 2 anchors + confirmed 3rd interactions
   datetime lastTouchTime;
   double   lastTouchPrice;
   double   atrRef;         // ATR of the current chart context at build time
   datetime breakTime;
   double   breakPrice;
  };

// PHASE 59: one broken-line history record (rendered as an OBJ_TREND segment)
struct ACSS_SmartHist
  {
   string   name;
   datetime t0;             // first anchor
   double   p0;
   datetime endTime;        // break confirmation time
   double   endPrice;       // trendline price at break
   int      dir;
   int      state;          // ACSS_SMART_ENDED
  };

class ACSS_Engine
  {
private:
   ACSS_Config      m_cfg;
   string           m_symbol;
   int              m_longTF, m_shortTF, m_interTF;
   bool             m_ready;
   bool             m_ok;          // config accepted
   datetime         m_lastChartBar;
   bool             m_chartBarInit;
   double           m_tick;

   // per-TF confirmed+provisional swings
   ACSS_Swing       m_longSw[];
   ACSS_Swing       m_interSw[];
   ACSS_Swing       m_shortSw[];
   ACSS_Swing       m_longProv[];
   ACSS_Swing       m_interProv[];
   ACSS_Swing       m_shortProv[];

   ACSS_Leg         m_legs[];
   double           m_floor;      // PHASE 57: structural floor (confirmed swings)
   double           m_ceiling;    // PHASE 57: structural ceiling (confirmed swings)
   datetime         m_lastBreakBar;
   ACSS_Level       m_broken[];   // PHASE 57: broken levels (analytical state NEVER deleted)
   ACSS_StructEvent m_events[];
   ACSS_Channel     m_ch[2];       // [0]=long, [1]=short
   ACSS_TFState     m_st[3];       // [0]=long, [1]=inter, [2]=short
   int              m_mtf;
   int              m_regime;
   double           m_confidence;
   int              m_objCount;

   //--- PHASE 59: advanced smart trendline state (active line + broken-line history)
   ACSS_SmartTrend   m_smart;
   ACSS_SmartHist    m_smartHist[];
   datetime          m_smartLastBreak;

   //--- helpers ----------------------------------------------------
   bool GetRates(const int tf,const int count,MqlRates &r[])
     {
      ArraySetAsSeries(r,true);
      return CopyRates(m_symbol,(ENUM_TIMEFRAMES)tf,0,count,r)>=count;
     }

   void ATR(const MqlRates &r[],const int period,double &atr[])
     {
      int n=ArraySize(r);
      ArrayResize(atr,n);
      for(int i=0;i<n;i++) atr[i]=0.0;
      if(period<=1) return;
      double tr[]; ArrayResize(tr,n);
      for(int i=0;i<n;i++)
        {
         double h=r[i].high,l=r[i].low;
         tr[i]=(i+1<n)? MathMax(h-r[i+1].close,r[i+1].close-l): 0.0;
         if(tr[i]<h-l) tr[i]=h-l;
        }
      double sum=0.0;
      for(int i=n-1;i>=0;i--)
        {
         sum+=tr[i];
         if(i+period<n) sum-=tr[i+period];
         if(i+period-1<n) atr[i]=sum/(double)period;
        }
     }

   double Tick()
     {
      if(m_tick<=0.0)
        {
         m_tick=SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_SIZE);
         if(m_tick<=0.0) m_tick=0.00001;
        }
      return m_tick;
     }

   double NetDev(const int zzMode,const int sensPct,const int devPct)
     {
      double k=1.0;
      if(zzMode==ACSS_ZZ_AGGRESSIVE) k=0.6;   // more pivots
      if(zzMode==ACSS_ZZ_STRICT)     k=1.5;   // fewer pivots
      return MathMax(0.02,(double)devPct*0.01)* ((double)sensPct/100.0) * k;
     }

   //--- zigzag -----------------------------------------------------
   void BuildZigZagTF(const int tf,ACSS_Swing &conf[],ACSS_Swing &prov[])
     {
      ArrayResize(conf,0);
      ArrayResize(prov,0);
      MqlRates r[];
      int need=m_cfg.lookback+m_cfg.zzDepth*2+20;
      if(!GetRates(tf,need,r)) return;
      int n=ArraySize(r);
      double atr[]; ATR(r,m_cfg.zzATRPeriod,atr);
      double netDev=NetDev(m_cfg.zzMode,m_cfg.zzSensitivity,m_cfg.zzDeviation);
      int depth=m_cfg.zzDepth;

      ACSS_Swing raw[];
      for(int s=n-depth-1;s>=depth;s--)
        {
         bool isH=true,isL=true;
         double h=r[s].high,l=r[s].low;
         for(int k=1;k<=depth;k++)
           {
            if(h<=r[s-k].high||h<=r[s+k].high) isH=false;
            if(l>=r[s-k].low ||l>=r[s+k].low)  isL=false;
           }
         if(isH||isL)
           {
            int m=ArraySize(raw);
            ArrayResize(raw,m+1);
            raw[m].time=r[s].time;
            raw[m].price=(isH?r[s].high:r[s].low);
            raw[m].isHigh=isH;
            raw[m].shift=s;
            raw[m].confirmed=false;
            raw[m].score=0.0;
           }
        }

      //--- threshold filter + alternation + backstep merge (deterministic)
      ACSS_Swing keep[];
      for(int i=0;i<ArraySize(raw);i++)
        {
         int m=ArraySize(keep);
         if(m==0)
           {
            ArrayResize(keep,1);
            keep[0]=raw[i];
            continue;
           }
         ACSS_Swing last=keep[m-1];
         if(raw[i].isHigh==last.isHigh)
           {
            bool replace=(raw[i].isHigh&&raw[i].price>last.price)||
                         (!raw[i].isHigh&&raw[i].price<last.price);
            if(replace) keep[m-1]=raw[i];
           }
         else
           {
            double thr=atr[raw[i].shift]*netDev;
            double move=MathAbs(raw[i].price-last.price);
            if(move>=thr)
              {
               ArrayResize(keep,m+1);
               keep[m]=raw[i];
              }
           }
        }

      //--- provisional vs confirmed (no silent promotion)
      int confBars=depth+m_cfg.zzBackstep;
      for(int i=0;i<ArraySize(keep);i++)
        {
         bool cf=(keep[i].shift>=confBars);
         keep[i].confirmed=cf;
         if(m_cfg.zzSwingQuality)
            keep[i].score=SwingScore(r,atr,keep,i);
         if(cf||m_cfg.zzShowProvisional)
           {
            if(cf)
              {
               int c=ArraySize(conf);
               ArrayResize(conf,c+1);
               conf[c]=keep[i];
              }
            else
              {
               int p=ArraySize(prov);
               ArrayResize(prov,p+1);
               prov[p]=keep[i];
              }
           }
        }
     }

   double SwingScore(const MqlRates &r[],const double &atr[],
                     ACSS_Swing &keep[],const int idx)
     {
      double score=0.0;
      double a=atr[keep[idx].shift];
      if(a<=0.0) a=0.0001;
      if(idx>0)
        {
         double rev=MathAbs(keep[idx].price-keep[idx-1].price);
         score+=MathMin(35.0,35.0*rev/(a*3.0));
        }
      int bars=(int)MathMax(1,MathRound((keep[idx].time-keep[idx>0?idx-1:0].time)/
                 (double)PeriodSeconds((ENUM_TIMEFRAMES)m_longTF)));
      score+=MathMin(15.0,(double)MathMin(bars,10)*1.5);
      double body=MathAbs(r[keep[idx].shift].close-r[keep[idx].shift].open);
      score+=MathMin(20.0,20.0*body/(a*2.0));
      double volK=MathMax(a,0.0001);
      double norm=1.0-MathMin(1.0,MathAbs(a-volK)/volK);
      score+=MathMin(20.0,10.0+10.0*norm);
      double ref=atr[MathMin(keep[idx].shift+10,ArraySize(atr)-1)];
      if(ref>0.0)
         score+=MathMin(10.0,10.0*MathMin(1.0,ref/a));
      if(score>100.0) score=100.0;
      return score;
     }

   //--- legs + structure -------------------------------------------
   void BuildLegs(const int tf,ACSS_Swing &sw[],ACSS_Leg &legs[])
     {
      ArrayResize(legs,0);
      int n=ArraySize(sw);
      if(n<2) return;
      double atrAvg=0.0;
      MqlRates r[];
      if(GetRates(tf,200,r))
        {
         double atr[]; ATR(r,m_cfg.zzATRPeriod,atr);
         atrAvg=atr[MathMin(5,ArraySize(atr)-1)];
        }
      int sec=PeriodSeconds((ENUM_TIMEFRAMES)tf);
      if(sec<=0) sec=3600;
      double tick=Tick();
      for(int i=1;i<n;i++)
        {
         if(!sw[i-1].confirmed||!sw[i].confirmed) continue;
         ACSS_Leg L; ZeroMemory(L);
         L.t0=sw[i-1].time; L.t1=sw[i].time;
         L.p0=sw[i-1].price; L.p1=sw[i].price;
         L.up=(L.p1>L.p0);
         double d=MathAbs(L.p1-L.p0);
         L.distPts=d/tick;
         L.distPct=(L.p0!=0.0? d/MathAbs(L.p0)*100.0:0.0);
         L.atrMult=(atrAvg>0.0? d/atrAvg:0.0);
         L.duration=(int)MathMax(1,(L.t1-L.t0)/sec);
         L.slope=d/(double)L.duration;
         L.velocity=L.slope/(atrAvg>0.0?atrAvg:0.0001);
         int idxPrev=(i>=2? i-2 : 0);
         bool prevUp=(sw[i].isHigh==sw[i-1].isHigh? !sw[i].isHigh : true);
         if(i>=2)
            prevUp=(sw[i-1].isHigh? (sw[i-1].price>sw[idxPrev].price) : (sw[i-1].price<sw[idxPrev].price));
         L.cls=(prevUp==L.up?1:0);
         L.strength=MathMin(100.0,L.atrMult*25.0);
         int m=ArraySize(legs);
         ArrayResize(legs,m+1);
         legs[m]=L;
        }
     }

   void BuildStructure(const ACSS_Swing &sw[],ACSS_StructEvent &ev[],ACSS_TFState &st,
                       const int tf,const int atrPeriod,const int zzBackstep)
     {
      st.hh=0; st.hl=0; st.lh=0; st.ll=0;
      st.bosCount=0; st.chochCount=0;
      st.lastBosTime=0; st.lastChochTime=0;
      st.direction=0;
      st.qualityAvg=0.0;
      int n=ArraySize(sw);
      if(n<4) return;
      ArrayResize(ev,0);

      double qSum=0.0; int qN=0;
      for(int i=0;i<n;i++)
        {
         if(!sw[i].confirmed) continue;
         if(sw[i].isHigh && i>=2)
           {
            int type=(sw[i].price>sw[i-2].price? 0:2);   // HH / LH
            int m=ArraySize(ev);
            ArrayResize(ev,m+1);
            ev[m].time=sw[i].time; ev[m].type=type;
            ev[m].sigA=i; ev[m].sigB=i-2;
            ev[m].confirmed=true;
            ulong h=2166136261;
            h=(h^ (ulong)(sw[i].time>>16));
            h*=16777619;
            h^=(h<<13); h^=(h>>7); h^=(h<<17);
            ev[m].id=h;
            if(type==0) st.hh++; else st.lh++;
           }
         if(!sw[i].isHigh && i>=2)
           {
            int type=(sw[i].price<sw[i-2].price? 3:1);   // LL / HL
            int m=ArraySize(ev);
            ArrayResize(ev,m+1);
            ev[m].time=sw[i].time; ev[m].type=type;
            ev[m].sigA=i; ev[m].sigB=i-2;
            ev[m].confirmed=true;
            ulong h=2166136261;
            h=(h^ (ulong)(sw[i].time>>16)); h*=16777619;
            h^=(h<<13); h^=(h>>7); h^=(h<<17);
            ev[m].id=h;
            if(type==3) st.ll++; else st.hl++;
           }
         qSum+=sw[i].score; qN++;
        }
      if(qN>0) st.qualityAvg=qSum/(double)qN;

      //--- last BOS/CHoCH on CLOSES only (no wicks, no future bars)
      MqlRates r[];
      if(!GetRates(tf,50,r)) return;
      double lastClose=r[0].close;
      int lastHigh=-1,lastLow=-1;
      for(int i=n-1;i>=0;i--)
        {
         if(sw[i].confirmed&&sw[i].isHigh&&lastHigh<0) lastHigh=i;
         if(sw[i].confirmed&&!sw[i].isHigh&&lastLow<0) lastLow=i;
         if(lastHigh>=0&&lastLow>=0) break;
        }
      if(lastHigh>=0&&lastLow>=0)
        {
         bool upStructure=(sw[lastLow].price>=(lastLow-2>=0?sw[lastLow-2].price:0.0));
         if(upStructure && lastClose>sw[lastHigh].price)
           {
            st.bosCount=1; st.lastBosTime=r[0].time;
            int m=ArraySize(ev); ArrayResize(ev,m+1);
            ev[m].time=r[0].time; ev[m].type=4; ev[m].sigA=lastHigh; ev[m].sigB=-1;
            ev[m].confirmed=true;
           }
         if(upStructure && lastClose<sw[lastLow].price)
           {
            st.chochCount=1; st.lastChochTime=r[0].time;
            int m=ArraySize(ev); ArrayResize(ev,m+1);
            ev[m].time=r[0].time; ev[m].type=5; ev[m].sigA=lastLow; ev[m].sigB=-1;
            ev[m].confirmed=true;
           }
         bool downStructure=(lastLow-2>=0 && sw[lastLow].price<=sw[lastLow-2].price);
         if(downStructure && lastClose<sw[lastLow].price)
           {
            st.bosCount=1; st.lastBosTime=r[0].time;
            int m=ArraySize(ev); ArrayResize(ev,m+1);
            ev[m].time=r[0].time; ev[m].type=4; ev[m].sigA=lastLow; ev[m].sigB=-1;
            ev[m].confirmed=true;
           }
         if(downStructure && lastClose>sw[lastHigh].price)
           {
            st.chochCount=1; st.lastChochTime=r[0].time;
            int m=ArraySize(ev); ArrayResize(ev,m+1);
            ev[m].time=r[0].time; ev[m].type=5; ev[m].sigA=lastHigh; ev[m].sigB=-1;
            ev[m].confirmed=true;
           }
        }
      //--- direction from last two confirmed pivots
      double h2=(lastHigh-2>=0? sw[lastHigh].price:0.0);
      double l2=(lastLow-2>=0? sw[lastLow].price:0.0);
      if(lastHigh>=0&&lastLow>=0)
        {
         bool up=(sw[lastLow].price>l2);
         bool dn=(sw[lastHigh].price<h2);
         st.direction=(up&&!dn?1:(dn&&!up?-1:0));
        }
     }

   //--- channels ----------------------------------------------------
   bool LinearFit(const ACSS_Swing &sw[],const int i0,const int i1,
                  double &slope,double &offset)
     {
      if(i1-i0<2) return false;
      double sx=0,sy=0,sxx=0,sxy=0; int nv=i1-i0+1;
      for(int i=i0;i<=i1;i++)
        {
         double x=(double)sw[i].time;
         sx+=x; sy+=sw[i].price; sxx+=x*x; sxy+=x*sw[i].price;
        }
      double d=nv*sxx-sx*sx;
      if(MathAbs(d)<1e-9) return false;
      slope=(nv*sxy-sx*sy)/d;
      offset=(sy-slope*sx)/nv;
      return true;
     }

   bool BuildChannelSlot(const int slot, ACSS_Channel &ch)
     {
      ZeroMemory(ch);
      ch.slot=slot;
      ch.state=ACSS_STATE_INVALID;
      ch.brk=ACSS_BREAK_NONE;
      int tf=(slot==0?m_longTF:m_shortTF);
      ACSS_Swing sw[];
      if(slot==0) ArrayCopy(sw,m_longSw);
      else        ArrayCopy(sw,m_shortSw);
      int n=ArraySize(sw);
      if(n<m_cfg.longMinTouches) return false;   // same min for both slots (safe)
      if(n<4) return false;
      int sec=PeriodSeconds((ENUM_TIMEFRAMES)tf);
      if(sec<=0) sec=3600;
      int maxBars=(slot==0?m_cfg.longMaxBars:m_cfg.shortMaxBars);
      int minTouches=(slot==0?m_cfg.longMinTouches:m_cfg.shortMinTouches);
      int widthMode=(slot==0?m_cfg.longWidthMode:m_cfg.shortWidthMode);
      int atrPeriod=(slot==0?m_cfg.longATRPeriod:m_cfg.shortATRPeriod);
      int modelPref=(slot==0?m_cfg.longModel:m_cfg.shortModel);

      MqlRates r[];
      GetRates(tf,maxBars+20,r);
      int rn=ArraySize(r);
      double atr[]; ATR(r,MathMax(1,atrPeriod),atr);
      double atrAvg=(rn>0?atr[MathMin(5,rn-1)]:0.0);
      if(atrAvg<=0.0) atrAvg=0.0001;

      // candidates: 3 models -> {upper,lower,mid,slope,touches,fit,resid,score}
      double candUp[3],candLo[3],candMid[3],candSlope[3],candScore[3];
      int    candTouch[3];
      bool   candOk[3];
      for(int m=0;m<3;m++){candOk[m]=false;candTouch[m]=0;candScore[m]=0;}

      int iEnd=MathMin(n-1,maxBars);
      int iStart=MathMax(0,n-1-maxBars/2);

      // MODEL 0: STRUCTURAL parallel
      {
       int i1=n-1,i0=n-2;
       if(i1-i0>=1 && i0>=0)
         {
          datetime aTime=0,bTime=0; double aPrice=0.0,bPrice=0.0;
          int ia=i0;
          // dominant polarity = the polarity of the latest swing
          bool pol=sw[i1].isHigh;
          int cnt=0;
          for(int i=n-1;i>=0;i--)
            {
             if(sw[i].confirmed&&sw[i].isHigh==pol)
               {
                if(cnt==0){bPrice=sw[i].price;bTime=sw[i].time;}
                else if(cnt==1){aPrice=sw[i].price;aTime=sw[i].time;break;}
                cnt++;
               }
            }
          if(cnt>=2)
            {
             double slope=(bPrice-aPrice)/((double)(bTime-aTime));
             double offset=aPrice-slope*(double)aTime;
             double upper=0,lower=0;
             double extreme=sw[ia].price;
             double maxDev=0.0,res=0.0;int resN=0;
             // find extreme opposite swing between anchors
             for(int i=0;i<n;i++)
               {
                if(!sw[i].confirmed) continue;
                if(sw[i].time<aTime||sw[i].time>bTime) continue;
                double expect=slope*((double)sw[i].time)+offset;
                double dev=sw[i].price-expect;
                if(pol)
                  {
                   if(sw[i].price<extreme) extreme=sw[i].price;
                  }
                else
                  {
                   if(sw[i].price>extreme) extreme=sw[i].price;
                  }
                if(MathAbs(dev)>MathAbs(maxDev)) maxDev=dev;
                res+=MathAbs(dev); resN++;
               }
             if(pol){upper=extreme; lower=extreme - MathAbs(maxDev)*2.0;}
             else   {lower=extreme; upper=extreme + MathAbs(maxDev)*2.0;}
             if(upper<=lower){double t=upper;upper=lower;lower=t;}
             double width=upper-lower;
             if(width>atrAvg*0.2)
               {
                candUp[0]=upper;candLo[0]=lower;
                candMid[0]=(upper+lower)/2.0;
                candSlope[0]=slope;
                // touches: swings close to a boundary
                int touches=0;
                for(int i=0;i<n;i++)
                  {
                   if(!sw[i].confirmed) continue;
                   double dU=MathAbs(sw[i].price-upper);
                   double dL=MathAbs(sw[i].price-lower);
                   if(dU<=width*0.2||dL<=width*0.2) touches++;
                  }
                candTouch[0]=touches;
                candScore[0]=(double)MathMin(touches,10)*8.0
                            +MathMin(30.0,30.0*atrAvg/MathMax(width,atrAvg))
                            -MathMin(15.0,resN>0?res/(double)resN/atrAvg*5.0:0.0);
                candOk[0]=(touches>=minTouches);
               }
            }
         }
      }

      // MODEL 1: REGRESSION (OLS over confirmed swings)
      {
       double slope,offset;
       if(LinearFit(sw,iStart,iEnd,slope,offset))
         {
          double sum=0.0;int rv=0;
          for(int i=iStart;i<=iEnd;i++)
            {
             double e=sw[i].price-(slope*(double)sw[i].time+offset);
             sum+=e*e; rv++;
            }
          double std=(rv>0?MathSqrt(sum/(double)rv):0.0);
          double width=(widthMode==ACSS_WIDTH_ATR? MathMax(std*1.5,atrAvg*0.4)
                                                  : MathMax(std*1.5,atrAvg*0.2));
          double mid=slope*((double)sw[iEnd].time)+offset;
          candUp[1]=mid+width; candLo[1]=mid-width; candMid[1]=mid;
          candSlope[1]=slope;
          int touches=0;
          for(int i=iStart;i<=iEnd;i++)
            {
             if(!sw[i].confirmed) continue;
             double ev0=sw[i].price-(slope*(double)sw[i].time+offset);
             if(MathAbs(ev0)>=width*0.7) touches++;
            }
          candTouch[1]=touches;
          candScore[1]=(double)MathMin(touches,10)*8.0
                      +MathMin(30.0,30.0*atrAvg/MathMax(width,atrAvg))
                      -MathMin(20.0,std/atrAvg*8.0);
          candOk[1]=(touches>=minTouches);
         }
      }

      // MODEL 2: EXTREMES
      {
       double hi=0,lo=DBL_MAX;
       for(int i=iStart;i<=iEnd;i++)
         {
          if(sw[i].isHigh&&sw[i].price>hi) hi=sw[i].price;
          if(!sw[i].isHigh&&sw[i].price<lo) lo=sw[i].price;
         }
       if(lo<hi)
         {
          double width=hi-lo;
          candUp[2]=hi;candLo[2]=lo;candMid[2]=(hi+lo)/2.0;
          candSlope[2]=0.0;
          int touches=0;
          for(int i=iStart;i<=iEnd;i++)
            {
             if(!sw[i].confirmed) continue;
             if(MathAbs(sw[i].price-hi)<=width*0.15||
                MathAbs(sw[i].price-lo)<=width*0.15) touches++;
            }
          candTouch[2]=touches;
          candScore[2]=(double)MathMin(touches,10)*8.0+10.0;
          candOk[2]=(touches>=minTouches);
         }
      }

      //--- pick best valid candidate
      int best=-1; double bestS=-1e9;
      for(int m=0;m<3;m++)
        {
         if(!candOk[m]) continue;
         if(modelPref>=0&&modelPref<=2 && candOk[modelPref])
           {
            if(m!=modelPref){continue;}   // honor explicit preference
           }
         if(candScore[m]>bestS){bestS=candScore[m];best=m;}
        }
      if(best<0)
        {
         // fall back to model preference if any candidate of it is valid
         for(int m=0;m<3;m++)
           {
            if(candOk[m]&&candScore[m]>bestS){bestS=candScore[m];best=m;}
           }
        }
      if(best<0) return false;

      ch.valid=true;
      ch.model=best;
      ch.upper=candUp[best]; ch.lower=candLo[best];
      ch.mid=candMid[best];
      ch.slope=candSlope[best];
      ch.touches=candTouch[best];
      ch.width=ch.upper-ch.lower;
      if(ch.width<=0.0) return false;
      ch.anchorTime=sw[n-1].time;
      ch.anchorPrice=sw[n-1].price;
      ch.age=(int)MathMax(1,(int)((sw[n-1].time-sw[iStart].time)/sec));
      double fitRatio=MathMin(1.0,(ch.touches>=minTouches+2?1.0:
              (double)ch.touches/(double)(minTouches+2)));
      ch.fit=fitRatio*100.0;
      double widthK=MathMin(1.0,ch.width/MathMax(ch.width,atrAvg*2.5));
      ch.confidence=MathMin(100.0,ch.fit*0.6+widthK*60.0+20.0);
      // initial state from slope
      UpdateStateFromSlope(ch);
      return true;
     }

   void UpdateStateFromSlope(ACSS_Channel &ch)
     {
      double s=ch.slope;
      if(s>0) ch.state=ACSS_STATE_BULLISH;
      else if(s<0) ch.state=ACSS_STATE_BEARISH;
      else ch.state=ACSS_STATE_NEUTRAL;
     }

   void UpdateChannelBreak(const int slot,ACSS_Channel &ch)
     {
      int tf=(slot==0?m_longTF:m_shortTF);
      MqlRates r[];
      if(!GetRates(tf,m_cfg.zzBackstep+3,r)) return;
      int rn=ArraySize(r);
      if(rn<2) return;
      double close=r[0].close;
      int confBars=m_cfg.zzBackstep;
      int upCount=0,dnCount=0;
      for(int i=0;i<MathMin(confBars,rn);i++)
        {
         bool u=r[i].close>ch.upper;
         bool d=r[i].close<ch.lower;
         if(u&&!d){upCount++;}
         if(d&&!u){dnCount++;}
        }
      bool upBreak=close>ch.upper;
      bool dnBreak=close<ch.lower;
      // state transitions (deterministic, close-based)
      if(upCount>=confBars&&upBreak)
        {
         ch.brk=ACSS_BREAK_CONFIRMED;
         ch.state=ACSS_STATE_BROKEN_UP;
         ch.brokenUp=true; ch.breakTime=r[0].time;
        }
      else if(dnCount>=confBars&&dnBreak)
        {
         ch.brk=ACSS_BREAK_CONFIRMED;
         ch.state=ACSS_STATE_BROKEN_DOWN;
         ch.brokenDown=true; ch.breakTime=r[0].time;
        }
      else if(upBreak||dnBreak)
         ch.brk=ACSS_BREAK_TENTATIVE;
      else
        {
         // retest: broken before and price now at the boundary
         if(ch.brokenUp&&MathAbs(close-ch.upper)<=ch.width*0.12)
           { ch.brk=ACSS_BREAK_RETEST; ch.state=ACSS_STATE_RETEST; }
         else if(ch.brokenDown&&MathAbs(close-ch.lower)<=ch.width*0.12)
           { ch.brk=ACSS_BREAK_RETEST; ch.state=ACSS_STATE_RETEST; }
         else
           ch.brk=ACSS_BREAK_NONE;
        }
     }

   //--- MTF / regime / confidence -----------------------------------
   void ComputeMTF()
     {
      int dL=m_st[0].direction;
      int dI=m_st[1].direction;
      int dS=m_st[2].direction;
      int bull=(dL>0?1:0)+(dI>0?1:0)+(dS>0?1:0);
      int bear=(dL<0?1:0)+(dI<0?1:0)+(dS<0?1:0);
      if(bull==3)      m_mtf=ACSS_MTF_BULLISH_ALIGNMENT;
      else if(bear==3) m_mtf=ACSS_MTF_BEARISH_ALIGNMENT;
      else if(dL>0&&dI>0&&dS<0) m_mtf=ACSS_MTF_SHORT_TERM_PULLBACK;
      else if(dL>0&&dI<0&&dS<0) m_mtf=ACSS_MTF_INTERMEDIATE_CORRECTION;
      else if(dL<0&&dI>0&&dS>0) m_mtf=ACSS_MTF_COUNTER_TREND_RALLY;
      else m_mtf=ACSS_MTF_MIXED;
     }

   void ComputeRegime()
     {
      ACSS_Channel lc=m_ch[0];
      ACSS_Channel sc=m_ch[1];
      bool anyBroken=lc.brk==ACSS_BREAK_CONFIRMED||sc.brk==ACSS_BREAK_CONFIRMED;
      bool trending=(m_st[0].direction!=0&&m_st[0].direction==m_st[2].direction);
      bool alignedBull=(m_mtf==ACSS_MTF_BULLISH_ALIGNMENT);
      bool alignedBear=(m_mtf==ACSS_MTF_BEARISH_ALIGNMENT);
      bool pullback=(m_mtf==ACSS_MTF_SHORT_TERM_PULLBACK);
      bool counter=(m_mtf==ACSS_MTF_COUNTER_TREND_RALLY);
      bool flatL=(lc.state==ACSS_STATE_NEUTRAL||lc.state==ACSS_STATE_WEAKENING);
      bool flatS=(sc.state==ACSS_STATE_NEUTRAL||sc.state==ACSS_STATE_WEAKENING);

      if(anyBroken)            m_regime=ACSS_REGIME_BREAKOUT;
      else if(pullback)        m_regime=ACSS_REGIME_PULLBACK;
      else if(counter)         m_regime=ACSS_REGIME_REVERSAL_RISK;
      else if(trending&&(alignedBull||alignedBear)) m_regime=ACSS_REGIME_TRENDING;
      else if(flatL&&flatS)    m_regime=ACSS_REGIME_RANGING;
      else if(m_mtf==ACSS_MTF_INTERMEDIATE_CORRECTION||m_mtf==ACSS_MTF_MIXED)
                               m_regime=ACSS_REGIME_TRANSITION;
      else                     m_regime=ACSS_REGIME_TRENDING;
     }

   void ComputeConfidence()
     {
      double v=0.0; int nv=0;
      for(int k=0;k<3;k++)
        {
         if(m_st[k].qualityAvg>0.0){v+=m_st[k].qualityAvg;nv++;}
        }
      double q=(nv>0?v/(double)nv:40.0);
      double chC=0.0; int nc=0;
      for(int k=0;k<2;k++)
        {
         if(m_ch[k].valid){chC+=m_ch[k].confidence;nc++;}
        }
      double c=(nc>0?chC/(double)nc:35.0);
      double event=0.0;
      for(int k=0;k<3;k++)
        {
         if(m_st[k].bosCount>0||m_st[k].chochCount>0) event+=18.0;
        }
      if(event>54.0) event=54.0;
      m_confidence=q*0.40+c*0.35+event*0.25;
      if(m_confidence>100.0) m_confidence=100.0;
     }

   //--- PHASE 57: structural floor/ceiling (CONFIRMED swings only, no lookahead) ---
   void ComputeFloorCeiling()
     {
      m_floor=0.0; m_ceiling=0.0;
      int n=ArraySize(m_shortSw);
      for(int i=0;i<n;i++)
        {
         if(!m_shortSw[i].confirmed) continue;
         if(m_shortSw[i].isHigh)
           { if(m_ceiling==0.0||m_shortSw[i].price>m_ceiling) m_ceiling=m_shortSw[i].price; }
         else
           { if(m_floor==0.0||m_shortSw[i].price<m_floor) m_floor=m_shortSw[i].price; }
        }
     }

   //--- PHASE 57: closed-bar floor/ceiling break -> BOS(0 same-direction) / CHoCH(1 against)
   void DetectBreak()
     {
      if(m_floor==0.0||m_ceiling==0.0) return;
      datetime closed=iTime(m_symbol,(ENUM_TIMEFRAMES)_Period,1);
      if(closed==0||closed==m_lastBreakBar) return;
      m_lastBreakBar=closed;
      double closeLast=iClose(m_symbol,(ENUM_TIMEFRAMES)_Period,1);
      int dir=m_st[2].direction;                 // structure direction BEFORE rebuild
      if(closeLast>m_ceiling)
        {
         int m=ArraySize(m_broken); ArrayResize(m_broken,m+1);
         m_broken[m].price=m_ceiling; m_broken[m].kind=1; m_broken[m].t=closed;
         m_broken[m].cls=(dir>=0?0:1);           // continuation->BOS; against->CHoCH
        }
      else if(closeLast<m_floor)
        {
         int m=ArraySize(m_broken); ArrayResize(m_broken,m+1);
         m_broken[m].price=m_floor; m_broken[m].kind=0; m_broken[m].t=closed;
         m_broken[m].cls=(dir<=0?0:1);
        }
     }

   //--- rendering ---------------------------------------------------
   void ObjTrend(const string name,const datetime t0,const double p0,
                 const datetime t1,const double p1,
                 const color clr,const int width,const int style)
     {
      if(ObjectCreate(0,name,OBJ_TREND,0,t0,p0,t1,p1))
        {
         ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
         ObjectSetInteger(0,name,OBJPROP_STYLE,style);
         ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
         ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
         m_objCount++;
        }
     }

   // PHASE: VISUAL RETENTION — stable in-place trendline (delete-then-create).
   // Keeps exactly one chart object per active channel so old trendlines
   // never accumulate. Rendering-only; all analysis state is untouched.
   void ObjTrendStable(const string name,const datetime t0,const double p0,
                       const datetime t1,const double p1,
                       const color clr,const int width,const int style)
     {
      ObjectDelete(0,name);
      if(ObjectCreate(0,name,OBJ_TREND,0,t0,p0,t1,p1))
        {
         ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
         ObjectSetInteger(0,name,OBJPROP_STYLE,style);
         ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
         ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
         m_objCount++;
        }
     }

   // PHASE: VISUAL RETENTION — scoped budget sweep. Deletes the OLDEST
   // ACSS_/ACSC_ OBJ_TREND objects when the active trendline budget (1) is
   // exceeded. Scoped to this module's own prefixes only; never touches
   // Floor/Ceiling OBJ_HLINE objects or objects of other programs.
   void EnforceTrendlineRetention()
     {
      const int ACSS_ACTIVE_TRENDLINE_LIMIT=1;   // max active OBJ_TREND owned by ACSS
      int total=ObjectsTotal(0,-1,-1);
      if(total<=0) return;
      string names[];
      long   times[];
      for(int i=0;i<total;i++)
        {
         string nm=ObjectName(0,i,-1,-1);
         if(nm=="") continue;
         if(StringFind(nm,"ACSS_")!=0 && StringFind(nm,"ACSC_")!=0) continue;
         // PHASE 59: broken-line history objects are governed by MAX_SMART_TREND_HISTORY,
         // never by the ACTIVE trendline budget -> excluded here so retention keeps
         // ACTIVE_OBJECT_COUNT always = 1 without ever pruning retained history.
         if(StringFind(nm,"ACSC_SMART_HIST_")==0) continue;
         if(ObjectGetInteger(0,nm,OBJPROP_TYPE)!=(long)OBJ_TREND) continue;
         int n=ArraySize(names);
         ArrayResize(names,n+1);
         ArrayResize(times,n+1);
         names[n]=nm;
         times[n]=ObjectGetInteger(0,nm,OBJPROP_CREATETIME);
        }
      int cnt=ArraySize(names);
      if(cnt<=ACSS_ACTIVE_TRENDLINE_LIMIT) return;
      // sort ascending by creation time (oldest first); name as tie-break
      for(int a=0;a<cnt-1;a++)
        for(int b=a+1;b<cnt;b++)
          {
           bool swap=times[b]<times[a] ||
                     (times[b]==times[a] && names[b]<names[a]);
           if(swap)
             {
              string tn=names[a]; names[a]=names[b]; names[b]=tn;
              long   tt=times[a]; times[a]=times[b]; times[b]=tt;
             }
          }
      for(int k=0;k<cnt-ACSS_ACTIVE_TRENDLINE_LIMIT;k++)
         ObjectDelete(0,names[k]);
     }

   // PHASE 57: horizontal structural level line
   void ObjHLine(const string name,const double price,const color clr,
                 const int width,const int style)
     {
      if(ObjectCreate(0,name,OBJ_HLINE,0,0,price))
        {
         ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
         ObjectSetInteger(0,name,OBJPROP_STYLE,style);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
         m_objCount++;
        }
     }

   void ObjMarker(const string name,const datetime t,const double p,
                  const int arrow,const color clr,const int size)
     {
      if(ObjectCreate(0,name,OBJ_ARROW,0,t,p))
        {
         ObjectSetInteger(0,name,OBJPROP_ARROWCODE,arrow);
         ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,size);
         ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_BOTTOM);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
         m_objCount++;
        }
     }

   void ObjText(const string name,const datetime t,const double p,
                const string text,const color clr,const int size,
                const int anchor)
     {
      if(ObjectCreate(0,name,OBJ_TEXT,0,t,p))
        {
         ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
         ObjectSetString(0,name,OBJPROP_TEXT,text);
         ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
         ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
         ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_ZORDER,0);
         m_objCount++;
        }
     }

   void ObjHud(const string text)
     {
      int hx=6,hy=6;
      if(ObjectCreate(0,"ACSS_HUD",OBJ_LABEL,0,0,0))
        {
         ObjectSetInteger(0,"ACSS_HUD",OBJPROP_CORNER,CORNER_LEFT_LOWER);
         ObjectSetInteger(0,"ACSS_HUD",OBJPROP_XDISTANCE,hx);
         ObjectSetInteger(0,"ACSS_HUD",OBJPROP_YDISTANCE,hy);
         ObjectSetInteger(0,"ACSS_HUD",OBJPROP_FONTSIZE,MathMax(7,m_cfg.labelSize));
         ObjectSetString(0,"ACSS_HUD",OBJPROP_FONT,"Consolas");
         ObjectSetString(0,"ACSS_HUD",OBJPROP_TEXT,text);
         ObjectSetInteger(0,"ACSS_HUD",OBJPROP_COLOR,clrSilver);
         ObjectSetInteger(0,"ACSS_HUD",OBJPROP_BACK,true);
         ObjectSetInteger(0,"ACSS_HUD",OBJPROP_ZORDER,0);
         m_objCount++;
        }
     }

   // PHASE 58G: single timeframe-independent smart trendline.
   // - Confirmed swings from the ACTIVE chart timeframe (_Period) only; no fixed PERIOD_*.
   // - Directional structural anchors: bullish -> two structural higher-lows,
   //   bearish -> two structural lower-highs. No MODEL 2 / slope=0 lines.
   // - Exactly one OBJ_TREND remains: ACSC_SMART_TREND.
   // PHASE 59: ADVANCED SMART TRENDLINE ENGINE
   // -------------------------------------------------------------
   // ONE active OBJ_TREND ACSC_SMART_TREND (ACTIVE_OBJECT_COUNT=1).
   // Timeframe-independent: data source = ACTIVE chart timeframe (_Period) only;
   // no m_longTF/m_interTF/m_shortTF, no PERIOD_H4/H1/M15 in this path.
   // State machine: NONE -> CANDIDATE -> VALIDATED -> LOCKED -> TOUCHED
   //                LOCKED/TOUCHED -> BROKEN -> HISTORY (kept on chart).
   // Visual/analytical ONLY — no trade path is reachable.
   // -------------------------------------------------------------

   // current-context ATR (active chart timeframe)
   double SmartATRCur()
     {
      MqlRates r[];
      if(!GetRates((int)_Period,200,r)) return 0.0;
      double atr[];
      ATR(r,MathMax(1,m_cfg.zzATRPeriod),atr);
      int n=ArraySize(atr);
      if(n<=0) return 0.0;
      double v=atr[0];
      if(v<=0.0 && n>1) v=atr[1];
      return v;
     }

   // linear price of the line at time t (anchors t0<t1)
   double SmartLinePrice(const datetime t,const datetime t0,const double p0,
                         const datetime t1,const double p1)
     {
      if(t1==t0) return (p0+p1)*0.5;
      if(t<=t0) return p0-(p1-p0)*((double)(t0-t)/(double)(t1-t0));
      if(t>=t1) return p1+(p1-p0)*((double)(t-t1)/(double)(t1-t0));
      return p0+(p1-p0)*((double)(t-t0)/(double)(t1-t0));
     }

   // major swing: the recent leg (prev swing -> this swing) is >= ATR of the
   // current chart context (ACSS_SMART_MAJOR_ATR_MULT). Adaptive, not a fixed
   // absolute threshold. The oldest swing is accepted as a structural reference.
   bool SmartIsMajor(const ACSS_Swing &sw[],const int i,const double atrCur)
     {
      if(i<=0) return true;
      if(atrCur<=0.0) return true;
      return MathAbs(sw[i].price-sw[i-1].price)>=ACSS_SMART_MAJOR_ATR_MULT*atrCur;
     }

   // third-swing validation: count of interior confirmed swings that RESPECT the
   // line (no hard violation beyond the ATR-normalized zone)
   int SmartValidInteractions(const ACSS_Swing &sw[],const int n,
                              const ACSS_SmartTrend &cand,const double zone)
     {
      if(cand.dir==0||cand.t0<=0||cand.t1<=0||cand.p0<=0.0||cand.p1<=0.0) return 0;
      int cnt=0;
      for(int i=0;i<n;i++)
        {
         if(!sw[i].confirmed) continue;
         if(sw[i].time<=cand.t0||sw[i].time>=cand.t1) continue;
         double lp=SmartLinePrice(sw[i].time,cand.t0,cand.p0,cand.t1,cand.p1);
         double dev=sw[i].price-lp;
         bool ok=(cand.dir>0? dev>=-zone : dev<=zone);
         if(ok) cnt++;
        }
      return cnt;
     }

   // structural score 0..100 — fixed transparent deterministic weights (sum 1.00)
   double SmartScore(const ACSS_Swing &sw[],const int n,
                     const int i0,const int i1,const int dir,
                     const double atrCur,const double zone)
     {
      const double wMQ=0.25;   // MajorSwingQuality  (anchor leg sizes in ATR units)
      const double wSA=0.20;   // StructuralAlignment (monotonic same-polarity anchors)
      const double wAS=0.15;   // AnchorSeparation   (time span in period bars)
      const double wLC=0.20;   // LineCleanliness    (no hard violations between anchors)
      const double wTQ=0.10;   // TouchQuality       (in-zone approaches between anchors)
      const double wRC=0.10;   // Recency            (latest anchor proximity to now)
      const double VP=30.0;    // ViolationPenalty per hard violation (capped at 60)
      if(atrCur<=0.0) return 0.0;
      if(i0<0||i1>=n||i0>=i1) return 0.0;
      ACSS_Swing a0=sw[i0], a1=sw[i1];
      if(a0.time>=a1.time||a0.isHigh!=a1.isHigh) return 0.0;

      // MQ (0..100): anchor leg size vs ATR (cap 2.0 ATR per anchor)
      double mq=0.0;
      double leg0=(i0>0? MathAbs(a0.price-sw[i0-1].price)/atrCur : 0.0);
      double leg1=(i1>0? MathAbs(a1.price-sw[i1-1].price)/atrCur : 0.0);
      mq=(MathMin(2.0,leg0)+MathMin(2.0,leg1))*25.0;

      // SA (0..100): fraction of same-polarity swings inside [t0..t1] that stay monotonic
      int sameN=0, monoN=0; double prev=0.0; bool have=false;
      for(int i=i0;i<=i1;i++)
        {
         if(sw[i].isHigh!=a0.isHigh) continue;
         sameN++;
         if(!have){prev=sw[i].price;have=true;continue;}
         bool ok=(dir>0? sw[i].price>prev : sw[i].price<prev);
         if(ok) monoN++;
         prev=sw[i].price;
        }
      double sa=(sameN>1? 100.0*(double)monoN/(double)(sameN-1) : 50.0);

      // AS (0..100): separation in bars of the ACTIVE chart period (100 @ 25 bars)
      int sec=PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(sec<=0) sec=3600;
      double bars=(double)(a1.time-a0.time)/(double)sec;
      double as=MathMin(100.0,bars*4.0);

      // LC / TQ / hard violations between anchors
      int interiorN=0, cleanN=0, touchN=0, hardV=0;
      for(int i=0;i<n;i++)
        {
         if(i==i0||i==i1) continue;
         if(!sw[i].confirmed) continue;
         if(sw[i].time<=a0.time||sw[i].time>=a1.time) continue;
         interiorN++;
         double lp=SmartLinePrice(sw[i].time,a0.time,a0.price,a1.time,a1.price);
         double dev=sw[i].price-lp;
         if(dir>0)   // support: price must stay at/above the line
           {
            if(dev<-zone){hardV++; continue;}
            if(dev<=zone) touchN++;
            else          cleanN++;
           }
         else        // resistance: price must stay at/below the line
           {
            if(dev>zone){hardV++; continue;}
            if(dev>=-zone) touchN++;
            else           cleanN++;
           }
        }
      double lc=(interiorN>0? 100.0*(double)MathMax(0,interiorN-hardV)/(double)interiorN : 60.0);
      double tq=(interiorN>0? MathMin(100.0,100.0*(double)touchN/(double)interiorN) : 40.0);

      // RC (0..100)
      datetime curT=iTime(m_symbol,(ENUM_TIMEFRAMES)_Period,0);
      double rcBars=(curT>a1.time? (double)(curT-a1.time)/(double)sec : 0.0);
      double rc=(m_cfg.lookback>0? 100.0*(1.0-MathMin(1.0,rcBars/(double)m_cfg.lookback)) : 50.0);

      double wsum=wMQ*mq+wSA*sa+wAS*as+wLC*lc+wTQ*tq+wRC*rc;
      double pen=MathMin(60.0,VP*(double)hardV);
      return MathMax(0.0,MathMin(100.0,wsum-pen));
     }

   // candidate generation: all same-polarity CONFIRMED+MAJOR anchor pairs with
   // meaningful separation; support = ascending lows, resistance = descending highs.
   // Never a blind last-two pick; best = highest Structural Score >= MIN_SCORE.
   bool SmartBestCandidate(const ACSS_Swing &sw[],const int n,
                           const double atrCur,const double zone,
                           ACSS_SmartTrend &out)
     {
      if(n<2) return false;
      double best=-1.0;
      for(int i1=1;i1<n;i1++)
        {
         if(!sw[i1].confirmed||!SmartIsMajor(sw,i1,atrCur)) continue;
         for(int i0=0;i0<i1;i0++)
           {
            if(!sw[i0].confirmed||!SmartIsMajor(sw,i0,atrCur)) continue;
            if(sw[i0].isHigh!=sw[i1].isHigh) continue;
            if(sw[i0].time>=sw[i1].time) continue;
            if(sw[i0].price==sw[i1].price) continue;
            if(MathAbs(sw[i1].price-sw[i0].price)<atrCur*0.5) continue;
            int dir=0;
            if(!sw[i1].isHigh && sw[i1].price>sw[i0].price) dir=1;   // ascending lows
            if( sw[i1].isHigh && sw[i1].price<sw[i0].price) dir=-1;  // descending highs
            if(dir==0) continue;
            double sc=SmartScore(sw,n,i0,i1,dir,atrCur,zone);
            if(sc>best)
              {
               best=sc;
               out.dir=dir;
               out.t0=sw[i0].time; out.p0=sw[i0].price;
               out.t1=sw[i1].time; out.p1=sw[i1].price;
               out.score=sc;
               out.validations=2;
               out.atrRef=atrCur;
              }
           }
        }
      if(best<ACSS_SMART_MIN_SCORE) return false;
      return true;
     }

   // first touch: price enters the ATR-normalized zone with structural validity
   // (close still on the valid side) and only AFTER the line is formed; not a
   // wick-only tick. LOCKED -> TOUCHED, STYLE_DOT, same object, anchors kept.
   void SmartCheckTouch(ACSS_SmartTrend &st,const double zone)
     {
      if(st.state!=ACSS_SMART_LOCKED) return;
      if(st.dir==0||st.t0<=0||st.t1<=0||st.p0<=0.0||st.p1<=0.0) return;
      MqlRates r[];
      if(!GetRates((int)_Period,MathMax(2,m_cfg.lookback),r)) return;
      int rn=ArraySize(r);
      for(int s=rn-1;s>=1;s--)      // oldest closed -> newest closed
        {
         if(r[s].time<=st.t1) break;
         double lp=SmartLinePrice(r[s].time,st.t0,st.p0,st.t1,st.p1);
         bool touched=false;
         if(st.dir>0) touched=(r[s].low<=lp+zone && r[s].close>lp-zone*0.5);
         else         touched=(r[s].high>=lp-zone && r[s].close<lp+zone*0.5);
         if(touched)
           {
            st.state=ACSS_SMART_TOUCHED;
            st.lastTouchTime=r[s].time;
            st.lastTouchPrice=lp;
            Print("ACSS_SMART_TREND|TOUCHED|time=",TimeToString(r[s].time,TIME_DATE|TIME_MINUTES),
                  "|line=",DoubleToString(lp,2),"|style=DOT");
            return;
           }
        }
     }

   // break: confirmed CLOSE crosses + minimum displacement (ATR-normalized) +
   // persistence (>=ACSS_SMART_BREAK_PERSIST consecutive closed bars) + direction
   // match. Wicks never count. Break time = first close of the qualifying run.
   void SmartCheckBreak(ACSS_SmartTrend &st,const double atrCur)
     {
      if(st.dir==0||st.t0<=0||st.t1<=0) return;
      if(st.state!=ACSS_SMART_LOCKED && st.state!=ACSS_SMART_TOUCHED) return;
      double disp=MathMax(0.25,MathMin(2.0,ACSS_SMART_BREAK_DISP_ATR))*atrCur;
      MqlRates r[];
      if(!GetRates((int)_Period,MathMax(2,m_cfg.lookback),r)) return;
      int rn=ArraySize(r);
      int run=0; int runFirst=-1;
      for(int s=rn-1;s>=1;s--)      // oldest -> newest closed bars
        {
         if(r[s].time<=st.t1) break;
         double lp=SmartLinePrice(r[s].time,st.t0,st.p0,st.t1,st.p1);
         bool beyond=false;
         if(st.dir>0) beyond=(r[s].close<lp-disp);
         else         beyond=(r[s].close>lp+disp);
         if(beyond)
           {
            if(run==0) runFirst=s;
            run++;
            if(run>=ACSS_SMART_BREAK_PERSIST)
              {
               datetime bt=r[runFirst].time;
               double bp=SmartLinePrice(bt,st.t0,st.p0,st.t1,st.p1);
               st.state=ACSS_SMART_BROKEN;
               st.breakTime=bt;
               st.breakPrice=bp;
               Print("ACSS_SMART_TREND|BREAK|time=",TimeToString(bt,TIME_DATE|TIME_MINUTES),
                     "|line=",DoubleToString(bp,2),
                     "|persist=",run,"|RAY_RIGHT=false");
               return;
              }
           }
         else run=0;
        }
     }

   // deterministic history name: ACSC_SMART_HIST_YYYYMMDD_HHMMSS
   string SmartHistName(const datetime t)
     {
      MqlDateTime dt; TimeToStruct(t,dt);
      return StringFormat("ACSC_SMART_HIST_%04d%02d%02d_%02d%02d%02d",
                          dt.year,dt.mon,dt.day,dt.hour,dt.min,dt.sec);
     }

   void SmartPushHistory(const ACSS_SmartTrend &st)
     {
      if(st.dir==0||st.breakTime<=0||st.breakPrice<=0.0) return;
      string name=SmartHistName(st.breakTime);
      ACSS_SmartHist h;
      h.name=name;
      h.t0=st.t0; h.p0=st.p0;
      h.endTime=st.breakTime; h.endPrice=st.breakPrice;
      h.dir=st.dir;
      h.state=ACSS_SMART_ENDED;
      int m=ArraySize(m_smartHist);
      ArrayResize(m_smartHist,m+1);
      m_smartHist[m]=h;
      Print("ACSS_SMART_TREND|HISTORY|name=",name,
            "|T0=",TimeToString(h.t0,TIME_DATE|TIME_MINUTES),
            "|P0=",DoubleToString(h.p0,2),
            "|END_TIME=",TimeToString(h.endTime,TIME_DATE|TIME_MINUTES),
            "|END_PRICE=",DoubleToString(h.endPrice,2),
            "|RAY_RIGHT=false|style=DOT|count=",ArraySize(m_smartHist));
      // retention: newest MAX kept; oldest chart objects + records removed
      int keep=ACSS_SMART_MAX_HISTORY;
      int hs=ArraySize(m_smartHist);
      if(hs>keep)
        {
         int del=hs-keep;
         for(int k=0;k<del;k++)
            ObjectDelete(0,m_smartHist[k].name);
         for(int k=0;k<hs-del;k++)
            m_smartHist[k]=m_smartHist[k+del];
         ArrayResize(m_smartHist,hs-del);
         Print("ACSS_SMART_TREND|HISTORY|pruned=",del,"|count=",ArraySize(m_smartHist));
        }
     }

   void SmartRenderHistory()
     {
      for(int i=0;i<ArraySize(m_smartHist);i++)
        {
         ACSS_SmartHist h=m_smartHist[i];
         if(h.endTime<=0||h.endPrice<=0.0) continue;
         if(ObjectFind(0,h.name)>=0) continue;
         if(ObjectCreate(0,h.name,OBJ_TREND,0,h.t0,h.p0,h.endTime,h.endPrice))
           {
            color clr=(h.dir>0?m_cfg.longColor:m_cfg.shortColor);
            ObjectSetInteger(0,h.name,OBJPROP_COLOR,clr);
            ObjectSetInteger(0,h.name,OBJPROP_WIDTH,1);
            ObjectSetInteger(0,h.name,OBJPROP_STYLE,STYLE_DOT);
            ObjectSetInteger(0,h.name,OBJPROP_RAY_RIGHT,false);
            ObjectSetInteger(0,h.name,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,h.name,OBJPROP_HIDDEN,false);
            ObjectSetInteger(0,h.name,OBJPROP_BACK,false);
            ObjectSetInteger(0,h.name,OBJPROP_ZORDER,0);
            m_objCount++;
           }
        }
     }

   string SmartStateName(const int st)
     {
      switch(st)
        {
         case ACSS_SMART_NONE:      return "NONE";
         case ACSS_SMART_CANDIDATE: return "CANDIDATE";
         case ACSS_SMART_VALIDATED: return "VALIDATED";
         case ACSS_SMART_LOCKED:    return "LOCKED";
         case ACSS_SMART_TOUCHED:   return "TOUCHED";
         case ACSS_SMART_BROKEN:    return "BROKEN";
         case ACSS_SMART_ENDED:     return "ENDED";
         default:                   return "UNKNOWN";
        }
     }

   void SmartDrawActive()
     {
      Print("ACSS_SMART_TREND|ACTIVE|state=",SmartStateName(m_smart.state),
            "|dir=",(m_smart.dir>0?"BULL":"BEAR"),
            "|T0=",TimeToString(m_smart.t0,TIME_DATE|TIME_MINUTES),
            "|P0=",DoubleToString(m_smart.p0,2),
            "|T1=",TimeToString(m_smart.t1,TIME_DATE|TIME_MINUTES),
            "|P1=",DoubleToString(m_smart.p1,2),
            "|score=",DoubleToString(m_smart.score,1),
            "|valid=",m_smart.validations,
            "|style=",(m_smart.state==ACSS_SMART_TOUCHED?"DOT":"SOLID"),
            "|width=2|ray=true|hidden=false|subwindow=0");
     }

   void RenderSmartTrendline()
     {
      ObjectDelete(0,"ACSC_SMART_TREND");   // delete-then-create: no duplicates
      if(!m_ready) return;
      ACSS_Swing sw[],prov[];
      BuildZigZagTF((int)_Period,sw,prov);  // ACTIVE chart context only (timeframe-independent)
      int n=ArraySize(sw);
      if(n<2)
        {
         Print("ACSS_SMART_TREND|SKIP|reason=confirmed_swings_lt_2");
         return;
        }
      double atrCur=SmartATRCur();
      if(atrCur<=0.0) atrCur=0.0001;
      double zone=MathMax(0.25,MathMin(1.5,ACSS_SMART_TOUCH_ZONE_ATR))*atrCur;

      //--- 1) manage the ACTIVE line first (closed bars only)
      if(m_smart.state==ACSS_SMART_LOCKED||m_smart.state==ACSS_SMART_TOUCHED)
        {
         SmartCheckTouch(m_smart,zone);      // LOCKED -> TOUCHED on first valid touch
         SmartCheckBreak(m_smart,atrCur);    // -> BROKEN on confirmed close run
        }

      //--- 2) confirmed break -> HISTORY (exactly once)
      if(m_smart.state==ACSS_SMART_BROKEN||m_smart.state==ACSS_SMART_ENDED)
        {
         m_smart.state=ACSS_SMART_BROKEN;
         m_smartLastBreak=m_smart.breakTime;
         SmartPushHistory(m_smart);
         ZeroMemory(m_smart);
         m_smart.state=ACSS_SMART_NONE;
        }

      //--- 3) best candidate from current CONFIRMED+MAJOR structure
      ACSS_SmartTrend best; ZeroMemory(best);
      bool hasBest=SmartBestCandidate(sw,n,atrCur,zone,best);
      int validInt=(hasBest? SmartValidInteractions(sw,n,best,zone):0);
      if(hasBest)
        {
         best.validations=2+(validInt>=1?1:0);        // 2 swings -> 3rd interaction -> VALIDATED
         best.state=(best.validations>=3? ACSS_SMART_VALIDATED : ACSS_SMART_CANDIDATE);
         if(best.state==ACSS_SMART_VALIDATED) best.state=ACSS_SMART_LOCKED;
        }

      //--- 4) arbitration / promotion / lock replacement (no flicker)
      if(m_smart.state==ACSS_SMART_NONE)
        {
         if(hasBest && best.t1>m_smartLastBreak)
           {
            m_smart=best;
            SmartDrawActive();
           }
         else if(hasBest)
            Print("ACSS_SMART_TREND|SKIP|reason=needs_fresh_structure_after_break");
         else
            Print("ACSS_SMART_TREND|SKIP|reason=no_structural_candidate");
        }
      else if(m_smart.state==ACSS_SMART_CANDIDATE || m_smart.state==ACSS_SMART_VALIDATED)
        {
         if(hasBest && best.score>m_smart.score)      // only highest score stays active
           {
            m_smart=best;
            if(m_smart.state==ACSS_SMART_VALIDATED) m_smart.state=ACSS_SMART_LOCKED;
            SmartDrawActive();
           }
         else
           {
            if(m_smart.state==ACSS_SMART_CANDIDATE && m_smart.validations>=3)
              {
               m_smart.state=ACSS_SMART_VALIDATED;
               Print("ACSS_SMART_TREND|VALIDATED|T1=",
                     TimeToString(m_smart.t1,TIME_DATE|TIME_MINUTES),
                     "|score=",DoubleToString(m_smart.score,1),
                     "|valid=",m_smart.validations);
              }
            if(m_smart.state==ACSS_SMART_VALIDATED)
              {
               m_smart.state=ACSS_SMART_LOCKED;
               Print("ACSS_SMART_TREND|LOCKED|T1=",
                     TimeToString(m_smart.t1,TIME_DATE|TIME_MINUTES),
                     "|score=",DoubleToString(m_smart.score,1));
              }
           }
        }
      else // LOCKED / TOUCHED — replacement only on meaningful improvement
        {
         if(hasBest && best.score>=m_smart.score+ACSS_SMART_REPLACE_DELTA)
           {
            Print("ACSS_SMART_TREND|REPLACE|old=",DoubleToString(m_smart.score,1),
                  "|new=",DoubleToString(best.score,1),
                  "|delta=",DoubleToString(best.score-m_smart.score,1));
            m_smart=best;
            if(m_smart.state==ACSS_SMART_VALIDATED) m_smart.state=ACSS_SMART_LOCKED;
            SmartDrawActive();
           }
        }

      //--- 5) draw the active line (1 OBJ_TREND; TOUCHED -> STYLE_DOT)
      if(m_smart.dir!=0 && m_smart.t0>0 && m_smart.t1>0 && m_smart.p0>0.0 && m_smart.p1>0.0)
        {
         if(ObjectCreate(0,"ACSC_SMART_TREND",OBJ_TREND,0,m_smart.t0,m_smart.p0,m_smart.t1,m_smart.p1))
           {
            color clr=(m_smart.dir>0?m_cfg.longColor:m_cfg.shortColor);
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_COLOR,clr);
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_WIDTH,2);
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_STYLE,
                            (m_smart.state==ACSS_SMART_TOUCHED?STYLE_DOT:STYLE_SOLID));
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_RAY_RIGHT,true);
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_HIDDEN,false);
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_BACK,false);
            // SUBWINDOW=0 by construction (ObjectCreate subwindow parameter above)
            ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_ZORDER,0);
            m_objCount++;
           }
        }

      //--- 6) broken-line history (never counted as ACTIVE, limited to MAX 20)
      SmartRenderHistory();
     }

   // PHASE 59: the PHASE 58G engine above is superseded by the stateful engine.
   // This legacy body (never invoked) is retained as a rollback-safe reference.
   void RenderSmartTrendlineLegacy()
     {
      ObjectDelete(0,"ACSC_SMART_TREND");   // delete-then-create: no duplicates
      if(!m_ready) return;
      ACSS_Swing sw[],prov[];
      BuildZigZagTF((int)_Period,sw,prov);  // active chart context, timeframe-independent
      int n=ArraySize(sw);
      if(n<2)
        {
         Print("ACSS_SMART_TREND|SKIP|reason=confirmed_swings_lt_2");
         return;
        }
      int lastLow=-1,lastHigh=-1;
      for(int i=0;i<n;i++)
        {
         if(sw[i].isHigh) lastHigh=i;
         else             lastLow=i;
        }
      datetime t0=0,t1=0;
      double   p0=0.0,p1=0.0;
      int      dir=0;
      // bullish structure: most recent confirmed LOW strictly above a prior confirmed LOW
      if(lastLow>=0)
        {
         for(int i=lastLow-1;i>=0;i--)
           {
            if(sw[i].isHigh) continue;
            if(sw[i].price<sw[lastLow].price)
              {
               t0=sw[i].time; p0=sw[i].price;
               t1=sw[lastLow].time; p1=sw[lastLow].price;
               dir=1;
               break;
              }
           }
        }
      // bearish structure: most recent confirmed HIGH strictly below a prior confirmed HIGH
      if(dir==0 && lastHigh>=0)
        {
         for(int i=lastHigh-1;i>=0;i--)
           {
            if(!sw[i].isHigh) continue;
            if(sw[i].price>sw[lastHigh].price)
              {
               t0=sw[i].time; p0=sw[i].price;
               t1=sw[lastHigh].time; p1=sw[lastHigh].price;
               dir=-1;
               break;
              }
           }
        }
      if(dir==0)
        {
         Print("ACSS_SMART_TREND|SKIP|reason=no_structural_anchor_pair");
         return;
        }
      if(t0<=0||t1<=0||p0<=0.0||p1<=0.0||t0==t1||MathAbs(p1-p0)<0.0001)
        {
         Print("ACSS_SMART_TREND|SKIP|reason=invalid_anchor");
         return;
        }
      color clr=(dir>0?m_cfg.longColor:m_cfg.shortColor);
      if(ObjectCreate(0,"ACSC_SMART_TREND",OBJ_TREND,0,t0,p0,t1,p1))
        {
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_COLOR,clr);
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_WIDTH,m_cfg.lineWidth);
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_STYLE,m_cfg.lineStyle);
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_RAY_RIGHT,true);
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_HIDDEN,false);
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_BACK,false);
         ObjectSetInteger(0,"ACSC_SMART_TREND",OBJPROP_ZORDER,0);
         m_objCount++;
         Print("ACSS_SMART_TREND|DRAWN|dir=",(dir>0?"BULL":"BEAR"),
               "|T0=",TimeToString(t0,TIME_DATE|TIME_MINUTES),
               "|P0=",DoubleToString(p0,2),
               "|T1=",TimeToString(t1,TIME_DATE|TIME_MINUTES),
               "|P1=",DoubleToString(p1,2));
        }
     }

   void RenderChannel(const int slot,ACSS_Channel &ch)
     {
      if(!ch.valid) return;
      string p=(slot==0?"ACSC_LT_":"ACSC_ST_");
      color clr=(slot==0?m_cfg.longColor:m_cfg.shortColor);
      int wd=m_cfg.lineWidth;
      int st=m_cfg.lineStyle;
      datetime t0=ch.anchorTime-(datetime)(ch.age*3600);
      if(t0<=0) t0=ch.anchorTime-(datetime)(3600*24);
      double dU=ch.slope*((double)(ch.anchorTime-t0));
      double u0=ch.upper-dU;
      double l0=ch.lower-dU;

      // PHASE: VISUAL RETENTION — one stable OBJ_TREND per channel (blue/yellow):
      double b0=(ch.slope>=0.0 ? l0 : u0);
      double b1=(ch.slope>=0.0 ? ch.lower : ch.upper);
      ObjTrendStable(p+"TREND",t0,b0,ch.anchorTime,b1,clr,wd,st);
        {
         // band line removed by PHASE visual retention limit 2
         // ObjTrend(p+"MID",...) removed by PHASE visual retention limit 2
                  // MathMax(1,wd-1),m_cfg.midStyle); (continuation removed)
        }
      bool showBrk=(slot==0?m_cfg.longShowBrk:m_cfg.shortShowBrk);
      if(showBrk&&ch.brokenUp&&ch.breakTime>0)
         ObjText(p+"BRK_UP",ch.breakTime,ch.upper,"BRK UP",
                 clr,m_cfg.labelSize,ANCHOR_BOTTOM);
      if(showBrk&&ch.brokenDown&&ch.breakTime>0)
         ObjText(p+"BRK_DN",ch.breakTime,ch.lower,"BRK DN",
                 clr,m_cfg.labelSize,ANCHOR_TOP);
      bool showRet=(slot==0?m_cfg.longShowRetest:m_cfg.shortShowRetest);
      if(showRet&&ch.brk==ACSS_BREAK_RETEST)
         ObjText(p+"RETEST",0,ch.mid,"RETEST",
                 clr,m_cfg.labelSize,ANCHOR_BOTTOM);
     }

   void RenderZigZag(const ACSS_Swing &sw[],const string prefix,const color clr)
     {
      int n=ArraySize(sw);
      int start=MathMax(1,n-m_cfg.visualLegs);   // PHASE 55: recent confirmed legs only
      for(int i=start;i<n;i++)
        {
         if(!sw[i-1].confirmed||!sw[i].confirmed) continue;
         int wd=MathMax(1,m_cfg.lineWidth-1);
         ObjTrend(prefix+"SEG"+(string)i,sw[i-1].time,sw[i-1].price,
                  sw[i].time,sw[i].price,clr,wd,STYLE_DASH);
        }
     }

   void RenderStructure(const ACSS_TFState &st,const ACSS_Swing &sw[],const string prefix)
     {
      // HH/HL/LH/LL from events (recompute minimal labels)
      int n=ArraySize(sw);
      int placed=0;
      for(int i=MathMax(3,n-12);i<n;i++)
        {
         if(!sw[i].confirmed) continue;
         if(placed>=6) break;
         string tag="";
         if(sw[i].isHigh&&i>=2)
           {
            if(sw[i].price>sw[i-2].price) tag="HH";
            else tag="LH";
           }
         if(!sw[i].isHigh&&i>=2)
           {
            if(sw[i].price<sw[i-2].price) tag="LL";
            else tag="HL";
           }
         if(tag!="")
           {
            ObjText(prefix+"LBL"+(string)i,sw[i].time,sw[i].price,
                    tag,clrGold,m_cfg.labelSize,
                    sw[i].isHigh?ANCHOR_BOTTOM:ANCHOR_TOP);
            placed++;
           }
        }
      // PHASE 57: closed-bar only (BOS/CHoCH now rendered via ACSS_STRUCT_ST_BK lines)
         //       ObjText(prefix+"BOS",st.lastBosTime,iClose(m_symbol,(ENUM_TIMEFRAMES)_Period,0),"BOS",clrLime,
                 //       m_cfg.labelSize,ANCHOR_LEFT);
      // PHASE 57: closed-bar only (CHoCH now rendered via ACSS_STRUCT_ST_BK lines)
         //       ObjText(prefix+"CHOCH",st.lastChochTime,iClose(m_symbol,(ENUM_TIMEFRAMES)_Period,0),"CHoCH",clrOrange,
                 //       m_cfg.labelSize,ANCHOR_LEFT);
     }

   void DeleteAllObjects()
     {
      ObjectsDeleteAll(0,"ACSS_");
      ObjectsDeleteAll(0,"ACSC_");   // PHASE 20: channel namespace ACSC_LT_/ACSC_ST_
      m_objCount=0;
     }

public:
   ACSS_Engine()
     {
      m_ready=false; m_ok=false;
      m_chartBarInit=false; m_lastChartBar=0;
      m_tick=0.0; m_objCount=0;
      m_mtf=ACSS_MTF_MIXED;
      m_regime=ACSS_REGIME_RANGING;
      m_confidence=0.0;
      m_floor=0.0; m_ceiling=0.0; m_lastBreakBar=0;   // PHASE 57
      ZeroMemory(m_smart); m_smartLastBreak=0;         // PHASE 59
      for(int i=0;i<2;i++) ZeroMemory(m_ch[i]);
      for(int i=0;i<3;i++) ZeroMemory(m_st[i]);
     }

   bool Init(const ACSS_Config &cfg)
     {
      m_cfg=cfg;
      m_symbol=_Symbol;
      m_tick=0.0;
      m_ok=false;
      m_ready=false;
      m_chartBarInit=false;

      if(!m_cfg.enabled) return true;
      if(m_cfg.lookback<120) m_cfg.lookback=120;
      if(m_cfg.zzDepth<1) m_cfg.zzDepth=1;
      if(m_cfg.zzBackstep<1) m_cfg.zzBackstep=1;
      if(m_cfg.visualLegs<2)  m_cfg.visualLegs=2;   // PHASE 55: bounded visual budget
      if(m_cfg.visualLegs>60) m_cfg.visualLegs=60;

      if(m_cfg.tfMode==ACSS_TF_AUTO)
        {
         ENUM_TIMEFRAMES ct=(ENUM_TIMEFRAMES)_Period;
         m_shortTF=(int)ct;
         m_interTF=(int)PERIOD_H1;
         m_longTF=(int)PERIOD_H4;
         if(PeriodSeconds(ct)>PeriodSeconds(PERIOD_H4))
           {
            m_longTF=(int)ct;
            m_interTF=(int)PERIOD_H4;
            m_shortTF=(int)PERIOD_M15;
           }
        }
      else
        {
         m_longTF=m_cfg.longTF;
         m_shortTF=m_cfg.shortTF;
         m_interTF=m_cfg.interTF;
        }
      // MANUAL validation: Long TF must be strictly higher than Short TF
      if(PeriodSeconds((ENUM_TIMEFRAMES)m_longTF)<=PeriodSeconds((ENUM_TIMEFRAMES)m_shortTF))
        {
         Print("ACSS CONFIG REJECT: LongTF(",EnumToString((ENUM_TIMEFRAMES)m_longTF),
               ") must be a higher timeframe than ShortTF(",
               EnumToString((ENUM_TIMEFRAMES)m_shortTF),") - module disabled.");
         return false;
        }

      m_ok=true;
      Rebuild();
      return true;
     }

   void Rebuild()
     {
      uint tR0=GetTickCount();
      m_objCount=0;
      //--- zigzag per timeframe (provisional + confirmed)
      BuildZigZagTF(m_longTF,m_longSw,m_longProv);
      BuildZigZagTF(m_interTF,m_interSw,m_interProv);
      BuildZigZagTF(m_shortTF,m_shortSw,m_shortProv);

      //--- legs + structure per timeframe
      ACSS_Leg legsTmp[];
      BuildLegs(m_shortTF,m_shortSw,legsTmp);
      ArrayCopy(m_legs,legsTmp);
      BuildStructure(m_longSw,m_events,m_st[0],m_longTF,
                     m_cfg.longATRPeriod,m_cfg.zzBackstep);
      BuildStructure(m_interSw,m_events,m_st[1],m_interTF,
                     m_cfg.longATRPeriod,m_cfg.zzBackstep);
      BuildStructure(m_shortSw,m_events,m_st[2],m_shortTF,
                     m_cfg.shortATRPeriod,m_cfg.zzBackstep);

      //--- channels (max 2; one per slot)
      if(m_cfg.longEnabled)  BuildChannelSlot(0,m_ch[0]); else ZeroMemory(m_ch[0]);
      if(m_cfg.shortEnabled) BuildChannelSlot(1,m_ch[1]); else ZeroMemory(m_ch[1]);
      if(m_ch[0].valid) UpdateChannelBreak(0,m_ch[0]);
      if(m_ch[1].valid) UpdateChannelBreak(1,m_ch[1]);

      ComputeMTF();
      ComputeRegime();
      ComputeConfidence();
      ComputeFloorCeiling();   // PHASE 57: structural floor/ceiling from confirmed swings
      AssertLimits();
      AssertLimits();
      if(m_cfg.showDebug) Print("ACSS PERF rebuildMs=",(int)(GetTickCount()-tR0));
      m_ready=true;
     }

   bool OnNewBar()
     {
      datetime cur=iTime(m_symbol,(ENUM_TIMEFRAMES)_Period,0);
      if(!m_chartBarInit)
        {
         m_lastChartBar=cur;
      // PHASE 57: first-init — no break detection (levels computed by Init)
      // PHASE 57: single rebuild per init
         m_chartBarInit=true;
         Rebuild();
         Render();
         return false;
        }
      if(cur==m_lastChartBar&&m_ready) return false;
      m_lastChartBar=cur;
      DetectBreak();   // PHASE 57: closed-bar floor/ceiling break -> BOS/CHoCH (before rebuild)
      // PHASE 57: single rebuild per new bar (DetectBreak -> Rebuild)
      Rebuild();
      Render();
      return true;
     }

   void Render()
     {
      uint tV0=GetTickCount();
      DeleteAllObjects();
      if(!m_ready) return;
      //--- PRIORITY 1: channels
      if(m_cfg.longEnabled&&m_cfg.longShow) RenderChannel(0,m_ch[0]);
      if(m_cfg.shortEnabled&&m_cfg.shortShow) RenderChannel(1,m_ch[1]);
      // PHASE 58G: single smart trendline; legacy channel trendlines removed from visual path
      ObjectDelete(0,"ACSC_LT_TREND");
      ObjectDelete(0,"ACSC_ST_TREND");
      RenderSmartTrendline();
      //--- PRIORITY 2: zigzag + structure
      if(m_cfg.showZigZag)
        {
         // RenderZigZag(m_longSw,...) removed by PHASE visual retention limit 2
         // RenderZigZag(m_shortSw,...) removed by PHASE visual retention limit 2
        }
      if(m_cfg.showSwings)
        {
         for(int i=0;i<ArraySize(m_longSw);i++)
            ObjMarker("ACSS_SW_LT_"+(string)i,m_longSw[i].time,m_longSw[i].price,
                      m_longSw[i].isHigh?233:234,m_cfg.longColor,MathMax(1,m_cfg.pivotSize/8));
         for(int i=0;i<ArraySize(m_shortSw);i++)
            ObjMarker("ACSS_SW_ST_"+(string)i,m_shortSw[i].time,m_shortSw[i].price,
                      m_shortSw[i].isHigh?233:234,m_cfg.shortColor,MathMax(1,m_cfg.pivotSize/8));
        }
      if(m_cfg.showHHLL) RenderStructure(m_st[2],m_shortSw,"ACSS_STRUCT_ST_");
      //--- PHASE 57: structural floor/ceiling (CONFIRMED swings only)
      if(m_cfg.showHHLL)
        {
         if(m_ceiling>0.0) ObjHLine("ACSS_STRUCT_ST_CEILING",m_ceiling,clrOrangeRed,1,STYLE_SOLID);
         if(m_floor>0.0)   ObjHLine("ACSS_STRUCT_ST_FLOOR",m_floor,clrDodgerBlue,1,STYLE_SOLID);
         //--- recent broken levels (MAX_BROKEN_LEVELS=4 visual; labels <=3 per class)
         int nb=ArraySize(m_broken);
         int stb=MathMax(0,nb-4);
         int cBOS=0,cCH=0;
         for(int i=stb;i<nb;i++)
           {
            ObjHLine("ACSS_STRUCT_ST_BK"+(string)i,m_broken[i].price,clrDimGray,1,STYLE_DOT);
            if(m_broken[i].cls==0){ if(cBOS>=3) continue; cBOS++; }
            else                  { if(cCH>=3)  continue; cCH++; }
            ObjText("ACSS_STRUCT_ST_BKN"+(string)i,m_broken[i].t,m_broken[i].price,
                    (m_broken[i].cls==0?"BOS":"CHoCH"),
                    (m_broken[i].cls==0?clrLime:clrOrange),
                    m_cfg.labelSize,ANCHOR_LEFT);
           }
        }
      //--- PRIORITY 3: confidence/regime HUD
      if(m_cfg.showConfidence||m_cfg.showRegime)
        {
         string hud=StringFormat("ACSS %s CONF %.0f",RegimeName(),
                                 m_confidence);
         ObjHud(hud);
        }
      //--- PRIORITY 4: provisional (only if enabled)
      if(m_cfg.zzShowProvisional)
        {
         for(int i=0;i<ArraySize(m_longProv);i++)
            ObjMarker("ACSS_PL_LT_"+(string)i,m_longProv[i].time,m_longProv[i].price,
                      m_longProv[i].isHigh?233:234,clrDimGray,1);
         for(int i=0;i<ArraySize(m_shortProv);i++)
            ObjMarker("ACSS_PL_ST_"+(string)i,m_shortProv[i].time,m_shortProv[i].price,
                      m_shortProv[i].isHigh?233:234,clrDimGray,1);
        }
      if(m_cfg.showDebug)
         Print("ACSS DEBUG objects=",m_objCount,
               " longSw=",ArraySize(m_longSw)," shortSw=",ArraySize(m_shortSw),
               " chL=",m_ch[0].valid," chS=",m_ch[1].valid);
      EnforceTrendlineRetention();   if(m_objCount>300)
         Print("ACSS WARN objectCount=",m_objCount);
      if(m_cfg.showDebug) Print("ACSS PERF renderMs=",(int)(GetTickCount()-tV0));
     }

   void Cleanup()
     {
      DeleteAllObjects();
      m_ready=false;
     }

   //--- hard assertion ---------------------------------------------
   void AssertLimits()
     {
      int aL=(m_ch[0].valid?1:0);
      int aS=(m_ch[1].valid?1:0);
      int tot=aL+aS;
      if(tot>2)
         Print("ACSS FAIL ACTIVE_CHANNEL_COUNT=",tot," (limit 2)");
      Print("ACSS ACTIVE_CHANNEL_COUNT=",tot,
            " LONG=",StateName(m_ch[0]),
            " SHORT=",StateName(m_ch[1]));
     }

   //--- read-only API ----------------------------------------------
   bool IsReady(){return m_ready&&m_ok;}
   int  GetSmartState(){return m_smart.state;}
   int  GetSmartDir(){return m_smart.dir;}
   double GetSmartScore(){return m_smart.score;}
   int  GetSmartHistoryCount(){return ArraySize(m_smartHist);}
   bool IsOk(){return m_ok;}
   int  GetLongTF(){return m_longTF;}
   int  GetShortTF(){return m_shortTF;}
   int  GetInterTF(){return m_interTF;}
   int  GetActiveChannelCount(){return (m_ch[0].valid?1:0)+(m_ch[1].valid?1:0);}
   int  GetConfirmedSwingCount(const int slot)
     {
      if(slot==0) return ArraySize(m_longSw);
      if(slot==1) return ArraySize(m_shortSw);
      return ArraySize(m_interSw);
     }
   int  GetLegCount(){return ArraySize(m_legs);}
   int  GetStructureState(){return m_mtf;}
   int  GetChannelState(const int slot){return m_ch[slot].valid?m_ch[slot].state:ACSS_STATE_INVALID;}
   int  GetChannelBreak(const int slot){return m_ch[slot].valid?m_ch[slot].brk:ACSS_BREAK_NONE;}
   double GetChannelConfidence(const int slot){return m_ch[slot].valid?m_ch[slot].confidence:0.0;}
   int  GetMTFAlignment(){return m_mtf;}
   int  GetMarketRegime(){return m_regime;}
   double GetConfidence(){return m_confidence;}
   datetime GetLastBOSTime(){return m_st[2].lastBosTime;}
   datetime GetLastCHoCHTime(){return m_st[2].lastChochTime;}
   int  GetObjectCount(){return m_objCount;}
   ACSS_Channel GetChannel(const int slot){return m_ch[slot];}
   ACSS_TFState GetTFState(const int slot){return m_st[slot];}

   string StateName(const ACSS_Channel &c)
     {
      if(!c.valid) return "INVALID";
      switch(c.state)
        {
         case ACSS_STATE_BULLISH:     return "BULLISH";
         case ACSS_STATE_BEARISH:     return "BEARISH";
         case ACSS_STATE_WEAKENING:   return "WEAKENING";
         case ACSS_STATE_BROKEN_UP:   return "BROKEN_UP";
         case ACSS_STATE_BROKEN_DOWN: return "BROKEN_DOWN";
         case ACSS_STATE_RETEST:      return "RETEST";
         case ACSS_STATE_NEUTRAL:     return "NEUTRAL";
         default:                     return "INVALID";
        }
     }

   string RegimeName()
     {
      switch(m_regime)
        {
         case ACSS_REGIME_TRENDING:     return "TRENDING";
         case ACSS_REGIME_RANGING:      return "RANGING";
         case ACSS_REGIME_TRANSITION:   return "TRANSITION";
         case ACSS_REGIME_EXPANSION:    return "EXPANSION";
         case ACSS_REGIME_CONTRACTION:  return "CONTRACTION";
         case ACSS_REGIME_BREAKOUT:     return "BREAKOUT";
         case ACSS_REGIME_PULLBACK:     return "PULLBACK";
         case ACSS_REGIME_REVERSAL_RISK:return "REVERSAL_RISK";
         default:                       return "RANGING";
        }
     }

   string MTFName()
     {
      switch(m_mtf)
        {
         case ACSS_MTF_BULLISH_ALIGNMENT:      return "BULLISH_ALIGNMENT";
         case ACSS_MTF_SHORT_TERM_PULLBACK:    return "SHORT_TERM_PULLBACK";
         case ACSS_MTF_INTERMEDIATE_CORRECTION:return "INTERMEDIATE_CORRECTION";
         case ACSS_MTF_COUNTER_TREND_RALLY:    return "COUNTER_TREND_RALLY";
         case ACSS_MTF_BEARISH_ALIGNMENT:      return "BEARISH_ALIGNMENT";
         default:                              return "MIXED";
        }
     }
  };

//--- global instance + wrappers --------------------------------------
ACSS_Engine g_acss;

bool ACSS_Init(const ACSS_Config &cfg)  { return g_acss.Init(cfg); }
bool ACSS_OnNewBar()                    { return g_acss.OnNewBar(); }
void ACSS_Cleanup()                     { g_acss.Cleanup(); }
//+------------------------------------------------------------------+