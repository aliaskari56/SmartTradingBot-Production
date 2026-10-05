#property strict
#property version   "1.120"
#property description "SmartTradingBot - H4 Trend + M15 CHoCH/BOS + Swing + FVG + OB + RSI/CCI + Adaptive Parameter Learning + Auto Pending + Manual Trade Manager"

#include <Trade/Trade.mqh>
#include <AC\AC_SmartStructure.mqh>
#include <AC\AC_ManualAnalysis.mqh>   // TASK37 ACSS (analysis + visualization only, read-only)


CTrade trade;

//==================================================================
// INPUTS
//==================================================================

input group "=== CORE ==="
input ulong   InpMagic                  = 26093001;
input bool    InpAutoTrading            = false;
input int     InpScanSeconds            = 10;
input bool    InpAllowUniversal         = true;
input bool    InpOneSetupPerSymbol      = true;
input string  InpScannerSymbols         = "";   // empty = selected Market Watch; comma/semicolon separated
input group "=== RSI + CCI COMPOSITE ==="
input bool    InpOscillatorConfirmation    = true;
input ENUM_TIMEFRAMES InpOscTF              = PERIOD_M15;
input int     InpRSIPeriod                  = 14;
input int     InpCCIPeriod                  = 20;
input double  InpRSIBuyLevel                = 55.0;
input double  InpRSISellLevel               = 45.0;
input double  InpCCIBuyLevel                = 50.0;
input double  InpCCISellLevel               = -50.0;
input double  InpRSIWeight                  = 7.0;
input double  InpCCIWeight                  = 8.0;
input bool    InpOscillatorHardFilter       = false;
input bool    InpDiagnosticM15Mode        = true;  // automated M15 diagnostic lock
input bool    InpDrawOscillatorPanel        = true;
input double  InpMaxSpreadPips         = 0.0;   // 0 = disabled; broker-symbol specific
input int     InpSetupCooldownMinutes  = 15;
input int     InpMaxSetupAgeBars       = 0;     // 0 = disabled; M15 bars
input bool    InpUseRiskSizing         = false; // false preserves fixed-lot mode
input double  InpRiskPercent           = 0.50;  // account equity risk per setup
input double  InpMaxRiskVolume         = 0.0;   // 0 = broker max only

input group "=== ADAPTIVE LEARNING ==="
input bool    InpAdaptiveLearning       = true;
input double  InpAdaptiveBaseScore      = 50.0;
input double  InpAdaptiveMinScore       = 45.0;
input double  InpAdaptiveMaxScore       = 75.0;
input double  InpAdaptiveStep           = 5.0;
input double  InpAdaptiveWeakWinRate    = 0.40;
input double  InpAdaptiveStrongWinRate  = 0.65;
input int     InpAdaptiveMinSamples     = 20;
input double  InpAdaptiveHalfLifeDays  = 30.0;
input string  InpAdaptiveLogFile        = "SmartTradingBot_Learning.csv";
input bool    InpAdaptiveParameterLearning = true;
input int     InpAdaptiveWarmupPerProfile  = 2;
input double  InpAdaptiveUCBExploration    = 0.35;

input group "=== LOOKBACK ==="
input int     InpLookbackH4             = 180;
input int     InpLookbackM15            = 240;

input group "=== SWING ==="
input int     InpSwingLeft              = 2;
input int     InpSwingRight             = 2;

input group "=== ENTRY ==="
input double  InpBaseLots               = 0.01;
input double  InpTrendLotMultiplier     = 2.0;
input double  InpUniversalLotMultiplier = 1.0;
input double  InpEntryBufferPips        = 1.0;
input double  InpPipPointsOverride      = 0.0;  // 0 = automatic; >0 = points per pip
input double  InpSLBufferPips           = 1.0;
input double  InpInitialSLBufferPips    = 2.0;  // automatic SL: distance beyond nearest confirmed swing
input double  InpMinimumRR              = 1.0;
input int     InpMaxPendingBars         = 4;

input group "=== FVG / OB ==="
input bool    InpRequireFVG             = true;
input bool    InpRequireOB              = true;
input bool    InpStrictPatternFilters   = false; // true = FVG/OB mandatory; false = quality score only
input int     InpPatternWindowBars      = 12;

input group "=== PROFIT PROTECTION ==="
input double  InpAutoTriggerPips        = 50.0;
input double  InpAutoLockPips           = 30.0;
input double  InpManualSaveStepPips     = 20.0;

input group "=== TRADE MANAGEMENT ==="
input bool    InpManageManualPositions  = true;   // global position-management enable
input bool    InpManageEAPositions      = true;   // ownership is not filtered
input bool    InpManageManualPending    = true;
input double  InpEmergencySLPips        = 30.0;  // emergency SL distance when structural SL is unavailable
input bool    InpManageEAPending        = true;
input bool    InpAllowOneClickHedge      = true;






input double  InpTrendlineTolerancePips = 10.0;

input group "=== TRAILING ==="
input ENUM_TIMEFRAMES InpTrailTF        = PERIOD_M15;
input double  InpTrailStartPips         = 150.0;
input int     InpTrailCandleShift       = 5;
input double  InpTrailBufferPips        = 1.0;

input group "=== PENDING TRAIL (SAFE INTEGRATION) ==="
input bool    InpPendingTrail           = true;  // STB_PendingTrail + STB_PendingDistanceResolver services

input group "=== SMART STRUCTURE (ACSS - ANALYSIS ONLY) ==="
input bool                InpSmartStructureEnabled      = true;  // Enable ACSS (read-only analysis+visualization)
input ENUM_ACSS_TF_MODE   InpSmartStructureTFMode       = ACSS_TF_AUTO;  // AUTO derive TFs from chart; MANUAL select
input ENUM_TIMEFRAMES     InpSmartStructureLongTF       = PERIOD_H4;   // Manual Long-Term TF
input ENUM_TIMEFRAMES     InpSmartStructureShortTF      = PERIOD_M15;  // Manual Short-Term TF
input ENUM_TIMEFRAMES     InpSmartStructureInterTF      = PERIOD_H1;   // Intermediate TF (NO channel allowed)
input int                 InpSmartStructureLookback     = 400;  // Analysis window (bars)
input bool                InpStructureShowZigZag        = true;  // Show confirmed zigzag
input bool                InpStructureShowConfirmedSwings = false; // Show confirmed swing markers (zigzag shows vertices by default)
input bool                InpStructureShowHHLL          = true;  // Show HH/HL/LH/LL labels
input bool                InpStructureShowBOS           = true;  // Show last BOS marker
input bool                InpStructureShowCHoCH         = true;  // Show last CHoCH marker
input bool                InpStructureShowConfidence    = true;  // Show confidence in HUD
input bool                InpStructureShowRegime        = true;  // Show market regime in HUD
input int                 InpStructureVisualLegs       = 12;   // Visible confirmed zigzag legs per TF (PHASE 55 visual budget 10..20)

input group "=== SMART ZIGZAG ==="
input bool                InpSmartZigZagEnabled         = true;
input ENUM_ACSS_ZZ_MODE   InpSmartZigZagMode            = ACSS_ZZ_NORMAL;
input int                 InpSmartZigZagSensitivity     = 100;  // 50..200 (% net threshold)
input int                 InpSmartZigZagDepth           = 3;    // pivot left/right bars
input int                 InpSmartZigZagDeviation       = 40;   // pivot threshold in % of ATR
input int                 InpSmartZigZagBackstep        = 4;    // confirmation/replacement window (bars)
input bool                InpSmartZigZagAdaptive        = true; // adaptive sensitivity (internal)
input int                 InpSmartZigZagATRPeriod       = 14;
input int                 InpSmartZigZagVolatilityMode  = 0;    // 0=ATR
input bool                InpSmartZigZagSwingQuality    = true; // compute swing quality score
input bool                InpSmartZigZagShowProvisional = false;// show provisional pivots (priority 4)

input group "=== LONG-TERM CHANNEL ==="
input bool                InpLongChannelEnabled    = true;
input bool                InpLongChannelShow       = true;
input ENUM_ACSS_CH_MODEL  InpLongChannelModel      = ACSS_CH_STRUCTURAL;
input int                 InpLongChannelMinTouches = 3;
input int                 InpLongChannelMaxBars    = 200;
input ENUM_ACSS_WIDTH_MODE InpLongChannelWidthMode = ACSS_WIDTH_ATR;
input int                 InpLongChannelATRPeriod  = 14;
input bool                InpLongChannelShowMidline  = true;
input bool                InpLongChannelShowBreakout = true;
input bool                InpLongChannelShowRetest   = true;

input group "=== SHORT-TERM CHANNEL ==="
input bool                InpShortChannelEnabled    = true;
input bool                InpShortChannelShow       = true;
input ENUM_ACSS_CH_MODEL  InpShortChannelModel      = ACSS_CH_STRUCTURAL;
input int                 InpShortChannelMinTouches = 3;
input int                 InpShortChannelMaxBars    = 200;
input ENUM_ACSS_WIDTH_MODE InpShortChannelWidthMode = ACSS_WIDTH_ATR;
input int                 InpShortChannelATRPeriod  = 14;
input bool                InpShortChannelShowMidline  = true;
input bool                InpShortChannelShowBreakout = true;
input bool                InpShortChannelShowRetest   = true;

input group "=== ACSS VISUAL STYLE ==="
input color               InpStructureLongColor    = C'52,110,200';
input color               InpStructureShortColor   = C'225,160,40';
input int                 InpStructureLineWidth    = 2;
input ENUM_LINE_STYLE     InpStructureLineStyle    = STYLE_SOLID;
input color               InpStructureMidColor     = C'120,120,120';
input ENUM_LINE_STYLE     InpStructureMidStyle     = STYLE_DOT;
input int                 InpStructureLabelSize    = 8;
input int                 InpStructurePivotSize    = 12;
input bool                InpStructureShowDebug    = false;

input group "=== DASHBOARD UI (LAYOUT ONLY) ==="
input bool              InpUiShowPanel    = true;               // Draw dashboard container panel
input ENUM_BASE_CORNER  InpUiCorner       = CORNER_RIGHT_UPPER; // PHASE 57: dashboard out of center (top-right)
input int               InpUiMarginX      = 62;                 // PHASE 57: margin from anchor corner (10..20)
input int               InpUiMarginY      = 12;                 // PHASE 57: margin from anchor corner (10..20)
input int               InpUiButtonWidth  = 190;                // Control width  (auto-fit may shrink)
input int               InpUiButtonHeight = 24;                 // Control height (auto-fit may shrink)
input int               InpUiGap          = 4;                  // Gap between controls
input int               InpUiPadding      = 10;                 // Internal dashboard padding
input int               InpUiFontSize     = 10;                 // Control font size
input bool              InpUiAutoFit      = true;               // Auto-fit controls to small charts
input bool              InpUiEditMode     = false;              // true = unlock dashboard: drag panel with mouse (UI only, default LOCKED)

//==================================================================
// STRUCTURES
//==================================================================

struct SwingPoint
{
   int      shift;
   datetime time;
   double   price;
   bool     isHigh;
};

struct TrendInfo
{
   string   bias;
   bool     valid;
   int      touches;
   datetime t1;
   datetime t2;
   double   p1;
   double   p2;
};

struct OscillatorState
{
   double rsi1;
   double rsi2;
   double cci1;
   double cci2;
   bool   buyConfirmed;
   bool   sellConfirmed;
   bool   valid;
};

struct STBIndicatorCache
{
   string symbol;
   int    rsiHandle;
   int    cciHandle;
};



struct Setup
{
   bool     valid;
   string   symbol;
   int      direction;
   bool     trendAligned;

   int      chochShift;
   int      bosShift;
   int      originShift;
   int      fvgShift;

   double   originHigh;
   double   originLow;

   double   swingHigh;
   double   swingLow;

   double   entry;
   double   sl;
   double   tp;
   double   rr;

   double   score;
   int      adaptiveProfile;

   // Immutable strategy-selected lifecycle parameters handed to Risk/Execution.
   // Risk must not reactivate or read Adaptive state during authorization.
   int      pendingMaxBars;
   double   entryBufferPips;
   double   slBufferPips;
   double   minimumRR;

   datetime setupTime;
};


/*==================================================================
  IN-EA ADAPTIVE PARAMETER LEARNING
  ---------------------------------------------------------------
  Five bounded strategy profiles are selected with a deterministic
  decayed UCB policy. Only closed trade outcomes update the profile
  statistics. No future-bar or future-trade information is used.
==================================================================*/

#define STB_ADAPTIVE_PROFILE_COUNT 5

struct STBAdaptiveProfile
{
   int    id;
   int    swingLeft;
   int    swingRight;
   int    maxSetupAgeBars;
   int    patternWindowBars;
   int    maxPendingBars;
   double entryBufferPips;
   double slBufferPips;
   double minimumRR;
   double rsiBuyLevel;
   double rsiSellLevel;
   double cciBuyLevel;
   double cciSellLevel;
   double rsiWeight;
   double cciWeight;
};

struct STBDiagnosticState
{
   string   symbol;
   int      direction;
   datetime lastBar;
   string   lastReason;
   datetime lastReadyBar;
};

STBAdaptiveProfile g_activeAdaptiveProfile;
bool               g_activeAdaptiveProfileValid=false;
int                g_activeAdaptiveProfileId=0;
string             g_lastBuildRejectReason="UNKNOWN";
STBDiagnosticState g_diagnosticStates[];

ulong STB_AP_Hash(const string raw)
{
   ulong h=1469598103934665603ULL;

   for(int i=0;i<StringLen(raw);i++)
   {
      h^=(ulong)StringGetCharacter(raw,i);
      h*=1099511628211ULL;
   }

   return h;
}

string STB_AP_Key(const string symbol,
                  const int direction,
                  const string scope,
                  const int profile=-1)
{
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP2|"+symbol+"|"+
              (direction>0 ? "B":"S")+"|"+
              scope+"|"+(string)profile;

   return "STB_AP2_"+(string)STB_AP_Hash(raw);
}

double STB_AP_Read(const string symbol,
                   const int direction,
                   const string scope,
                   const int profile,
                   const double fallback)
{
   string key=STB_AP_Key(symbol,direction,scope,profile);

   if(!GlobalVariableCheck(key))
      return fallback;

   double value=GlobalVariableGet(key);

   return MathIsValidNumber(value) ? value:fallback;
}

void STB_AP_Write(const string symbol,
                  const int direction,
                  const string scope,
                  const int profile,
                  const double value)
{
   GlobalVariableSet(STB_AP_Key(symbol,direction,scope,profile),value);
}

double STB_AP_Decay(const string symbol,
                    const int direction,
                    const int profile)
{
   double halfLife=MathMax(0.1,InpAdaptiveHalfLifeDays);
   datetime last=(datetime)STB_AP_Read(symbol,direction,"T",profile,0.0);

   if(last<=0)
      return 1.0;

   long elapsed=(long)MathMax(0.0,(double)(TimeCurrent()-last));

   if(elapsed<=0)
      return 1.0;

   return MathPow(0.5,(double)elapsed/(halfLife*86400.0));
}

void STB_AP_ReadProfileStats(const string symbol,
                             const int direction,
                             const int profile,
                             double &wins,
                             double &losses)
{
   double decay=STB_AP_Decay(symbol,direction,profile);

   wins=MathMax(0.0,STB_AP_Read(symbol,direction,"W",profile,0.0)*decay);
   losses=MathMax(0.0,STB_AP_Read(symbol,direction,"L",profile,0.0)*decay);
}

void STB_AP_LoadProfile(const int id,STBAdaptiveProfile &p)
{
   p.id=0;
   p.swingLeft=InpSwingLeft;
   p.swingRight=InpSwingRight;
   p.maxSetupAgeBars=InpMaxSetupAgeBars;
   p.patternWindowBars=InpPatternWindowBars;
   p.maxPendingBars=InpMaxPendingBars;
   p.entryBufferPips=InpEntryBufferPips;
   p.slBufferPips=InpSLBufferPips;
   p.minimumRR=InpMinimumRR;
   p.rsiBuyLevel=InpRSIBuyLevel;
   p.rsiSellLevel=InpRSISellLevel;
   p.cciBuyLevel=InpCCIBuyLevel;
   p.cciSellLevel=InpCCISellLevel;
   p.rsiWeight=InpRSIWeight;
   p.cciWeight=InpCCIWeight;

   int safeId=MathMax(0,MathMin(STB_ADAPTIVE_PROFILE_COUNT-1,id));

   switch(safeId)
   {
      case 0:
         break;

      case 1:
         p.id=1;
         p.maxSetupAgeBars=2;
         p.patternWindowBars=8;
         p.maxPendingBars=3;
         p.entryBufferPips=0.75;
         p.slBufferPips=1.00;
         p.minimumRR=1.20;
         p.rsiBuyLevel=56.0;
         p.rsiSellLevel=44.0;
         p.cciBuyLevel=60.0;
         p.cciSellLevel=-60.0;
         break;

      case 2:
         p.id=2;
         p.swingLeft=3;
         p.swingRight=3;
         p.maxSetupAgeBars=3;
         p.patternWindowBars=10;
         p.maxPendingBars=2;
         p.entryBufferPips=1.25;
         p.slBufferPips=1.50;
         p.minimumRR=1.50;
         p.rsiBuyLevel=57.0;
         p.rsiSellLevel=43.0;
         p.cciBuyLevel=75.0;
         p.cciSellLevel=-75.0;
         p.rsiWeight=6.0;
         p.cciWeight=9.0;
         break;

      case 3:
         p.id=3;
         p.swingLeft=1;
         p.swingRight=1;
         p.maxSetupAgeBars=1;
         p.patternWindowBars=8;
         p.maxPendingBars=2;
         p.entryBufferPips=0.50;
         p.slBufferPips=0.75;
         p.minimumRR=1.00;
         p.rsiBuyLevel=53.0;
         p.rsiSellLevel=47.0;
         p.cciBuyLevel=30.0;
         p.cciSellLevel=-30.0;
         p.rsiWeight=8.0;
         p.cciWeight=7.0;
         break;

      case 4:
         p.id=4;
         p.swingLeft=2;
         p.swingRight=2;
         p.maxSetupAgeBars=4;
         p.patternWindowBars=16;
         p.maxPendingBars=5;
         p.entryBufferPips=1.00;
         p.slBufferPips=1.25;
         p.minimumRR=1.30;
         p.rsiBuyLevel=54.0;
         p.rsiSellLevel=46.0;
         p.cciBuyLevel=40.0;
         p.cciSellLevel=-40.0;
         break;
   }

   p.swingLeft=MathMax(1,p.swingLeft);
   p.swingRight=MathMax(1,p.swingRight);
   p.maxSetupAgeBars=MathMax(0,p.maxSetupAgeBars);
   p.patternWindowBars=MathMax(1,p.patternWindowBars);
   p.maxPendingBars=MathMax(0,p.maxPendingBars);
   p.entryBufferPips=MathMax(0.0,p.entryBufferPips);
   p.slBufferPips=MathMax(0.0,p.slBufferPips);
   p.minimumRR=MathMax(0.10,p.minimumRR);
   p.rsiBuyLevel=MathMax(50.01,MathMin(100.0,p.rsiBuyLevel));
   p.rsiSellLevel=MathMax(0.0,MathMin(49.99,p.rsiSellLevel));
   p.cciBuyLevel=MathMax(0.01,p.cciBuyLevel);
   p.cciSellLevel=MathMin(-0.01,p.cciSellLevel);
   p.rsiWeight=MathMax(0.0,p.rsiWeight);
   p.cciWeight=MathMax(0.0,p.cciWeight);
}

int STB_AP_FindLeastSampled(const string symbol,
                            const int direction)
{
   int best=0;
   double bestSamples=DBL_MAX;

   ulong tieSeed=STB_AP_Hash(symbol+"|"+
                              (direction>0 ? "B":"S")+"|"+
                              (string)((long)(TimeCurrent()/900)));

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
   {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);

      double samples=wins+losses;

      if(samples+1e-9<bestSamples)
      {
         bestSamples=samples;
         best=p;
      }
      else if(MathAbs(samples-bestSamples)<=1e-9)
      {
         if((int)(tieSeed%STB_ADAPTIVE_PROFILE_COUNT)==p)
            best=p;
      }
   }

   return best;
}

int STB_AP_SelectProfile(const string symbol,
                         const int direction)
{
   if(!InpAdaptiveLearning || !InpAdaptiveParameterLearning)
      return 0;

   // Keep the first real strategy observation on the exact configured
   // baseline. Exploration begins only after that baseline observation.
   double totalStartupSamples=0.0;

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
   {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);
      totalStartupSamples+=wins+losses;
   }

   if(totalStartupSamples<=0.0)
      return 0;

   if(InpAdaptiveWarmupPerProfile>0)
   {
      for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
      {
         double wins=0.0;
         double losses=0.0;
         STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);

         if(wins+losses < InpAdaptiveWarmupPerProfile)
            return STB_AP_FindLeastSampled(symbol,direction);
      }
   }

   double totalSamples=0.0;
   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
   {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);
      totalSamples+=wins+losses;
   }

   int best=0;
   double bestValue=-DBL_MAX;
   double logTotal=MathLog(1.0+totalSamples);

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
   {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);

      double samples=wins+losses;
      double smoothedWinRate=(wins+1.0)/(samples+2.0);

      double observations=0.0;
      double averageR=STB_AdaptiveReadProfileR(symbol,direction,p,observations);
      double rSignal=MathMax(-1.0,MathMin(2.0,averageR));

      double exploration=
         MathMax(0.0,InpAdaptiveUCBExploration)*
         MathSqrt(logTotal/(samples+1.0));

      double value=
         0.55*smoothedWinRate+
         0.30*(rSignal/2.0+0.5)+
         0.15*exploration;

      if(value>bestValue)
      {
         bestValue=value;
         best=p;
      }
   }

   return best;
}

void STB_AP_SetActive(const int profileId)
{
   STB_AP_LoadProfile(profileId,g_activeAdaptiveProfile);
   g_activeAdaptiveProfileValid=true;
   g_activeAdaptiveProfileId=g_activeAdaptiveProfile.id;
}

void STB_AP_SelectActive(const string symbol,
                         const int direction)
{
   STB_AP_SetActive(STB_AP_SelectProfile(symbol,direction));
}

void STB_AP_ClearActive()
{
   g_activeAdaptiveProfileValid=false;
   g_activeAdaptiveProfileId=0;
}

int STB_EffectiveSwingLeft(const ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_M15 && g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.swingLeft;

   return InpSwingLeft;
}

int STB_EffectiveSwingRight(const ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_M15 && g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.swingRight;

   return InpSwingRight;
}

int STB_EffectivePatternWindow()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.patternWindowBars;

   return InpPatternWindowBars;
}

int STB_EffectiveMaxSetupAgeBars()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.maxSetupAgeBars;

   return InpMaxSetupAgeBars;
}

int STB_EffectiveMaxPendingBars()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.maxPendingBars;

   return InpMaxPendingBars;
}

double STB_EffectiveEntryBuffer()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.entryBufferPips;

   return InpEntryBufferPips;
}

double STB_EffectiveSLBuffer()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.slBufferPips;

   return InpSLBufferPips;
}

double STB_EffectiveMinimumRR()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.minimumRR;

   return InpMinimumRR;
}

double STB_EffectiveRSIBuy()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiBuyLevel;

   return InpRSIBuyLevel;
}

double STB_EffectiveRSISell()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiSellLevel;

   return InpRSISellLevel;
}

double STB_EffectiveCCIBuy()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciBuyLevel;

   return InpCCIBuyLevel;
}

double STB_EffectiveCCISell()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciSellLevel;

   return InpCCISellLevel;
}

double STB_EffectiveRSIWeight()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiWeight;

   return InpRSIWeight;
}

double STB_EffectiveCCIWeight()
{
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciWeight;

   return InpCCIWeight;
}

double STB_AdaptiveScoreFloor(const string symbol,
                              const int direction)
{
   if(!InpAdaptiveLearning)
      return InpAdaptiveBaseScore;

   double wins=0.0;
   double losses=0.0;

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
   {
      double pw=0.0;
      double pl=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,pw,pl);
      wins+=pw;
      losses+=pl;
   }

   double samples=wins+losses;

   if(samples<InpAdaptiveMinSamples)
      return MathMax(InpAdaptiveMinScore,
                     MathMin(InpAdaptiveMaxScore,
                             InpAdaptiveBaseScore));

   double winRate=wins/samples;
   double floor=InpAdaptiveBaseScore;

   if(winRate<InpAdaptiveWeakWinRate)
      floor+=MathAbs(InpAdaptiveStep);
   else if(winRate>InpAdaptiveStrongWinRate)
      floor-=MathAbs(InpAdaptiveStep);

   return MathMax(InpAdaptiveMinScore,
                  MathMin(InpAdaptiveMaxScore,floor));
}

void STB_AdaptiveLog(const string eventName,
                     const string symbol,
                     const int direction,
                     const double score,
                     const double rr,
                     const double outcome,
                     const int profileId)
{
   if(!InpAdaptiveLearning)
      return;

   int h=FileOpen(InpAdaptiveLogFile,
                  FILE_READ|FILE_WRITE|FILE_CSV|
                  FILE_SHARE_READ|FILE_SHARE_WRITE,
                  ',');

   if(h==INVALID_HANDLE)
   {
      Print("STB ADAPTIVE: FileOpen failed err=",GetLastError());
      return;
   }

   FileSeek(h,0,SEEK_END);

   if(FileTell(h)==0)
      FileWrite(h,"time","event","account","magic","symbol",
                "direction","profile","score","rr","outcome","scoreFloor");

   FileWrite(h,
             TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
             eventName,
             (string)AccountInfoInteger(ACCOUNT_LOGIN),
             (string)InpMagic,
             symbol,
             direction>0 ? "BUY":"SELL",
             (string)profileId,
             DoubleToString(score,2),
             DoubleToString(rr,3),
             DoubleToString(outcome,2),
             DoubleToString(STB_AdaptiveScoreFloor(symbol,direction),2));

   FileFlush(h);
   FileClose(h);
}

void STB_AdaptiveRecordSetup(const Setup &s,const bool accepted)
{
   if(!InpAdaptiveLearning ||
      s.setupTime<=0 ||
      s.adaptiveProfile<0 ||
      s.adaptiveProfile>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   string suffix=(accepted ? "DECISION_A":"DECISION_R");

   double lastLogged=STB_AP_Read(s.symbol,s.direction,
                                 suffix,s.adaptiveProfile,0.0);

   if((datetime)lastLogged==s.setupTime)
      return;

   STB_AP_Write(s.symbol,s.direction,
                suffix,s.adaptiveProfile,(double)s.setupTime);

   STB_AdaptiveLog(accepted ? "SETUP_PLACED":"SETUP_REJECTED",
                   s.symbol,s.direction,s.score,s.rr,
                   accepted ? 1.0:0.0,s.adaptiveProfile);
}

void STB_AdaptiveRememberPositionProfile(const ulong positionId,
                                         const int profileId)
{
   if(positionId==0 ||
      profileId<0 ||
      profileId>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   STB_AP_Write("POSITION",1,
                STB_AdaptivePositionRaw(positionId),
                0,profileId);
}

string STB_AdaptiveOrderRaw(const ulong orderTicket)
{
   return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
          (string)InpMagic+"|AP2|ORDER|"+(string)orderTicket;
}

void STB_AdaptiveRememberOrderProfile(const ulong orderTicket,
                                      const int profileId)
{
   if(orderTicket==0 ||
      profileId<0 ||
      profileId>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   STB_AP_Write("ORDER_PROFILE",1,
                STB_AdaptiveOrderRaw(orderTicket),
                0,profileId);
}

int STB_AdaptiveReadOrderProfile(const ulong orderTicket)
{
   if(orderTicket==0)
      return -1;

   int profile=(int)MathRound(
      STB_AP_Read("ORDER_PROFILE",1,
                  STB_AdaptiveOrderRaw(orderTicket),
                  0,-1.0));

   return (profile>=0 && profile<STB_ADAPTIVE_PROFILE_COUNT) ?
          profile:-1;
}

void STB_AdaptiveRememberOrderRisk(const ulong orderTicket,
                                   const double riskMoney)
{
   if(orderTicket==0 || riskMoney<=0.0 || !MathIsValidNumber(riskMoney))
      return;

   STB_AP_Write("ORDER_RISK",1,
                STB_AdaptiveOrderRaw(orderTicket),
                0,riskMoney);
}

double STB_AdaptiveReadOrderRisk(const ulong orderTicket)
{
   if(orderTicket==0)
      return 0.0;

   return MathMax(0.0,
                  STB_AP_Read("ORDER_RISK",1,
                              STB_AdaptiveOrderRaw(orderTicket),
                              0,0.0));
}

void STB_AdaptiveDeleteOrderState(const ulong orderTicket)
{
   if(orderTicket==0)
      return;

   GlobalVariableDel(STB_AP_Key("ORDER_PROFILE",1,
                                STB_AdaptiveOrderRaw(orderTicket),0));
   GlobalVariableDel(STB_AP_Key("ORDER_RISK",1,
                                STB_AdaptiveOrderRaw(orderTicket),0));
}

string STB_AdaptivePositionRaw(const ulong positionId)
{
   return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
          (string)InpMagic+"|AP2|POS|"+(string)positionId;
}

void STB_AdaptiveRememberPositionRisk(const ulong positionId,
                                      const double riskMoney)
{
   if(positionId==0 || riskMoney<=0.0 || !MathIsValidNumber(riskMoney))
      return;

   STB_AP_Write("POSITION_RISK",1,
                STB_AdaptivePositionRaw(positionId),
                0,riskMoney);
}

double STB_AdaptiveReadPositionRisk(const ulong positionId)
{
   if(positionId==0)
      return 0.0;

   return MathMax(0.0,
                  STB_AP_Read("POSITION_RISK",1,
                              STB_AdaptivePositionRaw(positionId),
                              0,0.0));
}

void STB_AdaptiveDeletePositionRisk(const ulong positionId)
{
   if(positionId==0)
      return;

   GlobalVariableDel(
      STB_AP_Key("POSITION_RISK",1,
                 STB_AdaptivePositionRaw(positionId),0));
}

double STB_AdaptiveReadProfileR(const string symbol,
                                const int direction,
                                const int profile,
                                double &observations)
{
   double decay=STB_AP_Decay(symbol,direction,profile);
   double sumR=STB_AP_Read(symbol,direction,"RSUM",profile,0.0)*decay;

   double wins=0.0;
   double losses=0.0;
   STB_AP_ReadProfileStats(symbol,direction,profile,wins,losses);

   observations=wins+losses;

   if(observations<=0.0)
      return 0.0;

   return sumR/observations;
}

int STB_AdaptiveReadPositionProfile(const ulong positionId)
{
   if(positionId==0)
      return -1;

   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP2|POS|"+(string)positionId;

   int profile=(int)MathRound(
      STB_AP_Read("POSITION",1,raw,0,-1.0));

   return (profile>=0 && profile<STB_ADAPTIVE_PROFILE_COUNT) ?
          profile:-1;
}

void STB_AdaptiveDeletePositionProfile(const ulong positionId)
{
   if(positionId==0)
      return;

   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP2|POS|"+(string)positionId;

   GlobalVariableDel(STB_AP_Key("POSITION",1,raw,0));
}

int STB_AdaptiveParseProfileFromComment(const string comment)
{
   int pos=StringFind(comment,"|P");
   if(pos<0)
      return -1;

   int id=(int)StringToInteger(StringSubstr(comment,pos+2));

   return (id>=0 && id<STB_ADAPTIVE_PROFILE_COUNT) ? id:-1;
}

bool STB_AdaptiveIsHedgeComment(const string comment)
{
   return StringFind(comment,"HEDGE")>=0;
}

void STB_AdaptiveRecordClosedDeal(const string symbol,
                                  const int direction,
                                  const double profit,
                                  const int profileId,
                                  const double rMultiple)
{
   if(!InpAdaptiveLearning ||
      direction==0 ||
      profileId<0 ||
      profileId>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
   {
      double wins=0.0;
      double losses=0.0;

      STB_AP_ReadProfileStats(symbol,direction,profileId,wins,losses);

      if(profit>0.0)
         wins+=1.0;
      else if(profit<0.0)
         losses+=1.0;

      if(profit!=0.0)
      {
         STB_AP_Write(symbol,direction,"W",profileId,wins);
         STB_AP_Write(symbol,direction,"L",profileId,losses);

         double oldRSum=STB_AP_Read(symbol,direction,
                                    "RSUM",profileId,0.0);

         if(MathIsValidNumber(rMultiple))
            oldRSum+=rMultiple;

         STB_AP_Write(symbol,direction,"RSUM",profileId,oldRSum);
         STB_AP_Write(symbol,direction,"T",profileId,(double)TimeCurrent());
      }
   }

   if(profit==0.0)
      return;

   Print("STB ADAPTIVE outcome symbol=",symbol,
         " dir=",(direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(profileId),
         " outcome=",DoubleToString(profit,2),
         " R=",DoubleToString(rMultiple,2),
         " floor=",DoubleToString(STB_AdaptiveScoreFloor(symbol,direction),1));

   STB_AdaptiveLog("TRADE_CLOSED",symbol,direction,
                   0.0,0.0,profit,profileId);

   GlobalVariablesFlush();
}

bool STB_BuildReject(const string symbol,
                     const int direction,
                     const string reason)
{
   g_lastBuildRejectReason=reason;
   STB_LogBuildReject(symbol,direction,reason);
   STB_AP_ClearActive();
   return false;
}

void STB_LogBuildReject(const string symbol,
                        const int direction,
                        const string reason)
{
   datetime bar=iTime(symbol,PERIOD_M15,0);
   if(bar<=0)
      bar=TimeCurrent();

   int idx=-1;

   for(int i=0;i<ArraySize(g_diagnosticStates);i++)
   {
      if(g_diagnosticStates[i].symbol==symbol &&
         g_diagnosticStates[i].direction==direction)
      {
         idx=i;
         break;
      }
   }

   if(idx<0)
   {
      idx=ArraySize(g_diagnosticStates);
      ArrayResize(g_diagnosticStates,idx+1);
      g_diagnosticStates[idx].symbol=symbol;
      g_diagnosticStates[idx].direction=direction;
      g_diagnosticStates[idx].lastBar=0;
      g_diagnosticStates[idx].lastReason="";
      g_diagnosticStates[idx].lastReadyBar=0;
   }

   if(bar!=g_diagnosticStates[idx].lastBar ||
      reason!=g_diagnosticStates[idx].lastReason)
   {
      Print("STB SETUP REJECT symbol=",symbol,
            " dir=",(direction>0 ? "BUY":"SELL"),
            " reason=",reason,
            " profile=",IntegerToString(g_activeAdaptiveProfileId));

      g_diagnosticStates[idx].lastBar=bar;
      g_diagnosticStates[idx].lastReason=reason;
   }
}

void STB_LogSetupReady(const Setup &s)
{
   if(!s.valid)
      return;

   int idx=-1;

   for(int i=0;i<ArraySize(g_diagnosticStates);i++)
   {
      if(g_diagnosticStates[i].symbol==s.symbol &&
         g_diagnosticStates[i].direction==s.direction)
      {
         idx=i;
         break;
      }
   }

   if(idx<0)
   {
      idx=ArraySize(g_diagnosticStates);
      ArrayResize(g_diagnosticStates,idx+1);
      g_diagnosticStates[idx].symbol=s.symbol;
      g_diagnosticStates[idx].direction=s.direction;
      g_diagnosticStates[idx].lastBar=0;
      g_diagnosticStates[idx].lastReason="";
      g_diagnosticStates[idx].lastReadyBar=0;
   }

   if(g_diagnosticStates[idx].lastReadyBar==s.setupTime)
      return;

   g_diagnosticStates[idx].lastReadyBar=s.setupTime;

   Print("STB SETUP READY symbol=",s.symbol,
         " dir=",(s.direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(s.adaptiveProfile),
         " score=",DoubleToString(s.score,1),
         " RR=",DoubleToString(s.rr,2),
         " trend=",s.trendAligned ? "ALIGNED":"UNIVERSAL");
}

double STB_AdaptiveTesterCriterion()
{
   if(!MQLInfoInteger(MQL_TESTER))
      return 0.0;

   double profit=TesterStatistics(STAT_PROFIT);
   double pf=TesterStatistics(STAT_PROFIT_FACTOR);
   double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double sharpe=TesterStatistics(STAT_SHARPE_RATIO);
   double trades=TesterStatistics(STAT_TRADES);
   double expected=TesterStatistics(STAT_EXPECTED_PAYOFF);
   double recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
   double deposit=TesterStatistics(STAT_INITIAL_DEPOSIT);

   if(!MathIsValidNumber(profit) || !MathIsValidNumber(pf) ||
      !MathIsValidNumber(dd) || !MathIsValidNumber(sharpe) ||
      !MathIsValidNumber(trades) || !MathIsValidNumber(expected) ||
      !MathIsValidNumber(recovery) || !MathIsValidNumber(deposit) ||
      deposit<=0.0)
      return -1.0e12;

   if(pf==DBL_MAX)
      pf=10.0;

   if(recovery==DBL_MAX)
      recovery=0.0;

   if(trades<10.0)
      return -1.0e9+trades;

   pf=MathMax(0.0,MathMin(5.0,pf));
   sharpe=MathMax(-5.0,MathMin(5.0,sharpe));
   dd=MathMax(0.0,dd);
   recovery=MathMax(-10.0,MathMin(10.0,recovery));

   // Normalize money-denominated metrics so the criterion remains
   // comparable across different tester deposit sizes.
   double returnPct=(profit/deposit)*100.0;
   double payoffPct=(expected/deposit)*100.0;

   returnPct=MathMax(-100.0,MathMin(100.0,returnPct));
   payoffPct=MathMax(-10.0,MathMin(10.0,payoffPct));

   double confidence=MathMin(1.0,trades/50.0);

   double stability=
      1.0+
      pf*0.12+
      sharpe*0.06+
      MathMax(-1.0,MathMin(1.0,payoffPct*0.10))*0.08+
      MathMax(-1.0,MathMin(1.0,recovery*0.10))*0.06;

   double score=
      returnPct*
      stability*
      confidence/
      (1.0+dd*0.10);

   return MathIsValidNumber(score) ? score:-1.0e12;
}



//==================================================================
// GLOBALS
//==================================================================

string g_prefix = "STB_";
string g_autoStateName = "";
bool   g_autoTrading = false;
datetime g_lastM15Bar = 0;
STBIndicatorCache g_indicatorCache[];
datetime g_lastChartBar = 0;

bool STB_GetMarketFilling(const string symbol,ENUM_ORDER_TYPE_FILLING &filling)
{
   int modes=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);

   if((modes & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
   {
      filling=ORDER_FILLING_FOK;
      return true;
   }

   if((modes & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
   {
      filling=ORDER_FILLING_IOC;
      return true;
   }

   long execution=SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE);
   if(execution!=SYMBOL_TRADE_EXECUTION_MARKET)
   {
      filling=ORDER_FILLING_RETURN;
      return true;
   }

   Print("STB filling rejected: no broker-supported FOK/IOC for market execution symbol=",symbol);
   return false;
}

bool STB_ConfigureMarketFilling(const string symbol)
{
   ENUM_ORDER_TYPE_FILLING filling=ORDER_FILLING_RETURN;
   if(!STB_GetMarketFilling(symbol,filling))
      return false;
   trade.SetTypeFilling(filling);
   return true;
}

int TrendlineLookback(const ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 800;
      case PERIOD_M2:  return 700;
      case PERIOD_M3:  return 650;
      case PERIOD_M4:  return 600;
      case PERIOD_M5:  return 600;
      case PERIOD_M6:  return 550;
      case PERIOD_M10: return 500;
      case PERIOD_M12: return 450;
      case PERIOD_M15: return 400;
      case PERIOD_M20: return 350;
      case PERIOD_M30: return 300;
      case PERIOD_H1:  return 240;
      case PERIOD_H2:  return 220;
      case PERIOD_H3:  return 200;
      case PERIOD_H4:  return InpLookbackH4;
      case PERIOD_H6:  return 160;
      case PERIOD_H8:  return 150;
      case PERIOD_H12: return 140;
      case PERIOD_D1:  return 120;
      case PERIOD_W1:  return 100;
      case PERIOD_MN1: return 80;
      default:         return InpLookbackM15;
   }
}

//==================================================================
// GENERAL UTILITY
//==================================================================

string Upper(const string value)
{
   string s = value;
   StringToUpper(s);
   return s;
}

double PipSize(const string symbol)
{
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   if(point<=0.0)
      return 0.0;

   if(InpPipPointsOverride>0.0)
      return point*InpPipPointsOverride;

   if(digits==3 || digits==5)
      return point*10.0;

   string s=Upper(symbol);
   if(StringFind(s,"XAU")>=0 ||
      StringFind(s,"GOLD")>=0 ||
      StringFind(s,"XAG")>=0 ||
      StringFind(s,"SILVER")>=0)
      return point*10.0;

   return point;
}

double NormalizePrice(const string symbol,const double price)
{
   if(price<=0.0)
      return 0.0;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);

   if(tickSize<=0.0)
      return NormalizeDouble(price,digits);

   double normalized=MathRound(price/tickSize)*tickSize;

   return NormalizeDouble(normalized,digits);
}

double NormalizeVolume(const string symbol,double volume)
{
   double minLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   if(step <= 0.0)
      return 0.0;

   volume = MathMax(minLot,MathMin(maxLot,volume));
   volume = MathFloor(volume / step + 1e-9) * step;

   // Flooring can push a value below the broker minimum when
   // minLot is not an exact multiple of step. Clamp again.
   if(volume < minLot)
      volume = minLot;

   int digits = 2;

   if(step < 0.01)
      digits = 3;

   if(step < 0.001)
      digits = 4;

   return NormalizeDouble(volume,digits);
}

bool GetRates(const string symbol,
              const ENUM_TIMEFRAMES tf,
              const int count,
              MqlRates &rates[])
{
   ArraySetAsSeries(rates,true);

   int copied = CopyRates(symbol,tf,0,count,rates);

   return copied >= count;
}

bool IsSymbolTradable(const string symbol)
{
   if(!SymbolInfoInteger(symbol,SYMBOL_SELECT))
      return false;

   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);

   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return false;

   if(tick.bid <= 0.0 || tick.ask <= 0.0)
      return false;

   return true;
}

// Check direction-specific symbol permissions before building or sending
// a setup. SYMBOL_TRADE_MODE and SYMBOL_ORDER_MODE are broker-side
// permissions and can change during the session.
bool IsDirectionTradable(const string symbol,const int direction)
{
   if(!IsSymbolTradable(symbol))
      return false;

   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   if(direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY)
      return false;

   long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);

   // This EA currently places BUY_STOP / SELL_STOP with SL + TP.
   if((orderMode & SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP)
      return false;
   if((orderMode & SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
      return false;
   if((orderMode & SYMBOL_ORDER_TP)!=SYMBOL_ORDER_TP)
      return false;

   return true;
}

bool STB_TradeEnvironmentAllowed()
{
   bool terminalAllowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   bool programAllowed=(MQLInfoInteger(MQL_TRADE_ALLOWED)!=0);
   bool accountAllowed=(AccountInfoInteger(ACCOUNT_TRADE_EXPERT)!=0);

   if(!terminalAllowed || !programAllowed || !accountAllowed)
   {
      Print("STB TRADE ENV REJECT",
            " terminal=",terminalAllowed ? "ON":"OFF",
            " program=",programAllowed ? "ON":"OFF",
            " account=",accountAllowed ? "ON":"OFF",
            " tester=",MQLInfoInteger(MQL_TESTER) ? "YES":"NO");
      return false;
   }

   return true;
}

bool IsSpreadAcceptable(const string symbol)
{
   if(InpMaxSpreadPips<=0.0)
      return true;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double pip=PipSize(symbol);
   if(pip<=0.0 || tick.ask<=tick.bid)
      return false;

   double spreadPips=(tick.ask-tick.bid)/pip;

   return spreadPips<=InpMaxSpreadPips+1e-9;
}

bool TradeRetcodeModifySucceeded()
{
   uint ret=trade.ResultRetcode();

   return ret==TRADE_RETCODE_DONE ||
          ret==TRADE_RETCODE_DONE_PARTIAL ||
          ret==TRADE_RETCODE_NO_CHANGES ||
          ret==TRADE_RETCODE_ORDER_CHANGED;
}

bool TradeRetcodePlacementSucceeded()
{
   uint ret=trade.ResultRetcode();

   return ret==TRADE_RETCODE_DONE ||
          ret==TRADE_RETCODE_DONE_PARTIAL ||
          ret==TRADE_RETCODE_PLACED;
}

bool TradeRetcodeDeleteSucceeded()
{
   return trade.ResultRetcode()==TRADE_RETCODE_DONE;
}

// Minimum distance required by the broker for pending price, SL and TP.
// Uses both STOP and FREEZE levels because some symbols expose a valid
// STOP level while still rejecting a pending order inside the FREEZE zone.
double TradeMinDistance(const string symbol)
{
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(point<=0.0)
      return 0.0;

   long stops=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freeze=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

   long level=MathMax(stops,freeze);

   // One extra point avoids equality/rounding rejection at the broker boundary.
   return ((double)level+1.0)*point;
}

// Normalize a pending setup against the live market and the broker's
// symbol-specific stop/freeze constraints. Returns false if the resulting
// geometry cannot satisfy the requested RR.
bool PreparePendingSetup(Setup &s)
{
   MqlTick tick;
   if(!SymbolInfoTick(s.symbol,tick))
      return false;

   double point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   int digits=(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS);
   double minDist=TradeMinDistance(s.symbol);

   if(point<=0.0 || minDist<=0.0)
      return false;

   double oldEntry=s.entry;
   double oldSL=s.sl;
   double oldTP=s.tp;

   if(s.direction>0)
   {
      double minEntry=tick.ask+minDist;
      if(s.entry<minEntry) s.entry=minEntry;

      double maxSL=tick.bid-minDist;
      double entrySL=s.entry-minDist;
      if(s.sl>maxSL) s.sl=maxSL;
      if(s.sl>entrySL) s.sl=entrySL;

      if(s.sl>=s.entry || s.tp<=s.entry)
         return false;
   }
   else if(s.direction<0)
   {
      double maxEntry=tick.bid-minDist;
      if(s.entry>maxEntry) s.entry=maxEntry;

      double minSL=tick.ask+minDist;
      double entrySL=s.entry+minDist;
      if(s.sl<minSL) s.sl=minSL;
      if(s.sl<entrySL) s.sl=entrySL;

      if(s.sl<=s.entry || s.tp>=s.entry)
         return false;
   }
   else
      return false;

   s.entry=NormalizePrice(s.symbol,s.entry);
   s.sl=NormalizePrice(s.symbol,s.sl);
   s.tp=NormalizePrice(s.symbol,s.tp);

   double risk=MathAbs(s.entry-s.sl);
   double reward=MathAbs(s.tp-s.entry);
   if(risk<=0.0 || reward<=0.0)
      return false;

   double minimumRR=MathMax(0.0,s.minimumRR);
   if(minimumRR<=0.0)
      minimumRR=InpMinimumRR;

   s.rr=reward/risk;
   if(s.rr+1e-9<minimumRR)
   {
      Print("STB setup rejected after broker normalization symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " RR=",DoubleToString(s.rr,2),
            " minRR=",DoubleToString(minimumRR,2),
            " entry=",DoubleToString(s.entry,digits),
            " sl=",DoubleToString(s.sl,digits),
            " tp=",DoubleToString(s.tp,digits));
      return false;
   }

   bool changed=
      MathAbs(oldEntry-s.entry)>point*0.5 ||
      MathAbs(oldSL-s.sl)>point*0.5 ||
      MathAbs(oldTP-s.tp)>point*0.5;

   if(changed)
   {
      Print("STB stops normalized symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " minDistPts=",DoubleToString(minDist/point,0),
            " entry ",DoubleToString(oldEntry,digits)," -> ",DoubleToString(s.entry,digits),
            " SL ",DoubleToString(oldSL,digits)," -> ",DoubleToString(s.sl,digits),
            " TP ",DoubleToString(oldTP,digits)," -> ",DoubleToString(s.tp,digits),
            " RR=",DoubleToString(s.rr,2),
            " owner=RISK");
   }

   return true;
}
//==================================================================
// RSI + CCI COMPOSITE
//==================================================================

int FindIndicatorCache(const string symbol)
{
   for(int i=0;i<ArraySize(g_indicatorCache);i++)
      if(g_indicatorCache[i].symbol==symbol)
         return i;

   return -1;
}

bool EnsureIndicatorHandles(const string symbol,int &rsiHandle,int &cciHandle)
{
   rsiHandle=INVALID_HANDLE;
   cciHandle=INVALID_HANDLE;

   int idx=FindIndicatorCache(symbol);
   if(idx>=0)
   {
      rsiHandle=g_indicatorCache[idx].rsiHandle;
      cciHandle=g_indicatorCache[idx].cciHandle;

      if(rsiHandle!=INVALID_HANDLE && cciHandle!=INVALID_HANDLE)
         return true;
   }
   ENUM_TIMEFRAMES effectiveOscTF=(InpDiagnosticM15Mode ? PERIOD_M15 : InpOscTF);
   int hRsi=iRSI(symbol,effectiveOscTF,InpRSIPeriod,PRICE_CLOSE);
   if(hRsi==INVALID_HANDLE)
   {
      Print("STB OSC: iRSI handle failed symbol=",symbol,
            " err=",GetLastError());
      return false;
   }
   int hCci=iCCI(symbol,effectiveOscTF,InpCCIPeriod,PRICE_TYPICAL);
   if(hCci==INVALID_HANDLE)
   {
      IndicatorRelease(hRsi);
      Print("STB OSC: iCCI handle failed symbol=",symbol,
            " err=",GetLastError());
      return false;
   }

   if(idx<0)
   {
      int n=ArraySize(g_indicatorCache);
      ArrayResize(g_indicatorCache,n+1);
      g_indicatorCache[n].symbol=symbol;
      g_indicatorCache[n].rsiHandle=hRsi;
      g_indicatorCache[n].cciHandle=hCci;
      idx=n;
   }
   else
   {
      if(g_indicatorCache[idx].rsiHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[idx].rsiHandle);
      if(g_indicatorCache[idx].cciHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[idx].cciHandle);

      g_indicatorCache[idx].rsiHandle=hRsi;
      g_indicatorCache[idx].cciHandle=hCci;
   }

   rsiHandle=hRsi;
   cciHandle=hCci;

   return true;
}

bool GetOscillatorState(const string symbol,OscillatorState &o)
{
   ZeroMemory(o);

   if(!InpOscillatorConfirmation)
   {
      o.valid=true;
      o.buyConfirmed=true;
      o.sellConfirmed=true;
      return true;
   }

   int rsiHandle=INVALID_HANDLE;
   int cciHandle=INVALID_HANDLE;

   if(!EnsureIndicatorHandles(symbol,rsiHandle,cciHandle))
      return false;

   // Copy closed-bar values only: start position 1 avoids the live bar.
   double rsiBuf[2];
   double cciBuf[2];

   ResetLastError();

   if(CopyBuffer(rsiHandle,0,1,2,rsiBuf)!=2)
   {
      Print("STB OSC: RSI CopyBuffer failed symbol=",symbol,
            " err=",GetLastError());
      return false;
   }

   ResetLastError();

   if(CopyBuffer(cciHandle,0,1,2,cciBuf)!=2)
   {
      Print("STB OSC: CCI CopyBuffer failed symbol=",symbol,
            " err=",GetLastError());
      return false;
   }

   // CopyBuffer stores the oldest copied value at index 0.
   // With start_pos=1,count=2:
   //   index 0 = shift 2 (previous closed bar)
   //   index 1 = shift 1 (latest closed bar)
   o.rsi2=rsiBuf[0];
   o.rsi1=rsiBuf[1];
   o.cci2=cciBuf[0];
   o.cci1=cciBuf[1];

   if(!MathIsValidNumber(o.rsi1) || !MathIsValidNumber(o.rsi2) ||
      !MathIsValidNumber(o.cci1) || !MathIsValidNumber(o.cci2))
      return false;

   bool rsiBuy=(o.rsi1>=STB_EffectiveRSIBuy());
   bool rsiSell=(o.rsi1<=STB_EffectiveRSISell());

   bool cciBuy=(o.cci1>=STB_EffectiveCCIBuy());
   bool cciSell=(o.cci1<=STB_EffectiveCCISell());

   bool rsiCrossBuy=(o.rsi2<50.0 && o.rsi1>=50.0);
   bool rsiCrossSell=(o.rsi2>50.0 && o.rsi1<=50.0);

   bool cciCrossBuy=(o.cci2<=0.0 && o.cci1>0.0);
   bool cciCrossSell=(o.cci2>=0.0 && o.cci1<0.0);

   // Strong confirmation = regime level + momentum confirmation,
   // while a zero-line/50 cross is accepted as a fresh transition.
   o.buyConfirmed=(rsiBuy && cciBuy) ||
                  (rsiCrossBuy && o.cci1>=0.0) ||
                  (cciCrossBuy && o.rsi1>=50.0);

   o.sellConfirmed=(rsiSell && cciSell) ||
                   (rsiCrossSell && o.cci1<=0.0) ||
                   (cciCrossSell && o.rsi1<=50.0);

   o.valid=true;
   return true;
}

void ReleaseIndicatorHandles()
{
   for(int i=0;i<ArraySize(g_indicatorCache);i++)
   {
      if(g_indicatorCache[i].rsiHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[i].rsiHandle);

      if(g_indicatorCache[i].cciHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[i].cciHandle);

      g_indicatorCache[i].rsiHandle=INVALID_HANDLE;
      g_indicatorCache[i].cciHandle=INVALID_HANDLE;
   }

   ArrayResize(g_indicatorCache,0);
}

void DrawOscillatorPanel(const OscillatorState &o)
{
   if(!InpDrawOscillatorPanel)
   {
      ObjectDelete(0,g_prefix+"OSC_PANEL");
      return;
   }

   string name=g_prefix+"OSC_PANEL";

   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
         return;

      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,20);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,20);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   }

   string rsiState="NEUTRAL";
   string cciState="NEUTRAL";

   if(o.rsi1>=STB_EffectiveRSIBuy())
      rsiState="BUY";
   else if(o.rsi1<=STB_EffectiveRSISell())
      rsiState="SELL";

   if(o.cci1>=STB_EffectiveCCIBuy())
      cciState="BUY";
   else if(o.cci1<=STB_EffectiveCCISell())
      cciState="SELL";

   string textValue=
      "STB OSC\n"+
      "RSI("+IntegerToString(InpRSIPeriod)+")  "+
      DoubleToString(o.rsi1,2)+"  "+rsiState+"\n"+
      "CCI("+IntegerToString(InpCCIPeriod)+")  "+
      DoubleToString(o.cci1,2)+"  "+cciState+"\n"+
      "COMPOSITE: "+
      (o.buyConfirmed ? "BUY" :
       (o.sellConfirmed ? "SELL":"NEUTRAL"));

   ObjectSetString(0,name,OBJPROP_TEXT,textValue);
}

void DrawOscillatorSignal(const Setup &s,const OscillatorState &o)
{
   if(!InpDrawOscillatorPanel || !s.valid || s.symbol!=_Symbol)
      return;

   string name=g_prefix+"OSC_SIG_"+(s.direction>0 ? "B":"S");
   ObjectDelete(0,name);

   datetime t=iTime(s.symbol,PERIOD_M15,1);
   if(t<=0)
      return;

   double price=(s.direction>0 ?
                 iLow(s.symbol,PERIOD_M15,1):
                 iHigh(s.symbol,PERIOD_M15,1));
   double pip=PipSize(s.symbol);

   if(price<=0.0 || pip<=0.0)
      return;

   price += (s.direction>0 ? -4.0*pip : 4.0*pip);

   ENUM_OBJECT obj=(s.direction>0 ? OBJ_ARROW_BUY:OBJ_ARROW_SELL);

   if(!ObjectCreate(0,name,obj,0,t,price))
      return;

   ObjectSetInteger(0,name,OBJPROP_COLOR,
                    s.direction>0 ? clrLimeGreen:clrTomato);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);

   Print("STB OSC SIGNAL symbol=",s.symbol,
         " dir=",(s.direction>0 ? "BUY":"SELL"),
         " RSI=",DoubleToString(o.rsi1,2),
         " CCI=",DoubleToString(o.cci1,2),
         " score=",DoubleToString(s.score,1));
}

//==================================================================
// SWING ENGINE
//==================================================================

int CollectSwings(const string symbol,
                  const ENUM_TIMEFRAMES tf,
                  const int maxBars,
                  SwingPoint &highs[],
                  SwingPoint &lows[])
{
   MqlRates r[];

   if(!GetRates(symbol,tf,maxBars,r))
      return 0;

   ArrayResize(highs,0);
   ArrayResize(lows,0);

   int left  = STB_EffectiveSwingLeft(tf);
   int right = STB_EffectiveSwingRight(tf);

   for(int s=maxBars-right-1; s>=left+1; --s)
   {
      bool isHigh=true;
      bool isLow=true;

      for(int k=1;k<=left;k++)
      {
         if(r[s].high <= r[s-k].high)
            isHigh=false;

         if(r[s].low >= r[s-k].low)
            isLow=false;
      }

      for(int k=1;k<=right;k++)
      {
         if(r[s].high <= r[s+k].high)
            isHigh=false;

         if(r[s].low >= r[s+k].low)
            isLow=false;
      }

      if(isHigh)
      {
         int n=ArraySize(highs);
         ArrayResize(highs,n+1);

         highs[n].shift=s;
         highs[n].time=r[s].time;
         highs[n].price=r[s].high;
         highs[n].isHigh=true;
      }

      if(isLow)
      {
         int n=ArraySize(lows);
         ArrayResize(lows,n+1);

         lows[n].shift=s;
         lows[n].time=r[s].time;
         lows[n].price=r[s].low;
         lows[n].isHigh=false;
      }
   }

   return ArraySize(highs)+ArraySize(lows);
}

//==================================================================
// H4 TREND
//==================================================================

TrendInfo GetH4Trend(const string symbol)
{
   TrendInfo result;

   result.bias="NEUTRAL";
   result.valid=false;
   result.touches=0;
   result.t1=0;
   result.t2=0;
   result.p1=0.0;
   result.p2=0.0;

   SwingPoint highs[];
   SwingPoint lows[];

   CollectSwings(symbol,PERIOD_H4,InpLookbackH4,highs,lows);

   int nh=ArraySize(highs);
   int nl=ArraySize(lows);

   if(nh<2 || nl<2)
      return result;

   // Determine H4 market structure from the two latest CONFIRMED
   // swing pairs. The line itself is then anchored to those exact
   // confirmed pivots, never to the current candle/price.
   bool bullish =
      highs[nh-1].price > highs[nh-2].price &&
      lows[nl-1].price  > lows[nl-2].price;

   bool bearish =
      highs[nh-1].price < highs[nh-2].price &&
      lows[nl-1].price  < lows[nl-2].price;

   double lastClose=iClose(symbol,PERIOD_H4,1);
   if(lastClose<=0.0)
      return result;

   double pip=PipSize(symbol);
   double tolerance=(pip>0.0 ? InpTrendlineTolerancePips*pip : 0.0);

   if(bullish)
   {
      // Bullish trendline = support line through the two latest
      // confirmed higher lows.
      SwingPoint a=lows[nl-2];
      SwingPoint b=lows[nl-1];

      if(b.time<=a.time || b.price<=a.price)
         return result;

      result.bias="BULLISH";
      result.t1=a.time;
      result.p1=a.price;
      result.t2=b.time;
      result.p2=b.price;
      result.touches=2;

      double slope=(b.price-a.price)/(double)(b.time-a.time);

      // A valid bullish line must not have a confirmed swing low
      // materially below the line after the first anchor.
      for(int i=nl-1;i>=0;i--)
      {
         if(lows[i].time<=a.time)
            continue;

         double line=lows[i].price;
         double expected=a.price+slope*(double)(lows[i].time-a.time);

         if(lows[i].price < expected-tolerance)
         {
            result.valid=false;
            return result;
         }
      }

      if(nl>=3)
      {
         SwingPoint c=lows[nl-3];

         if(c.time<a.time)
         {
            double lineAtC=a.price+slope*(double)(c.time-a.time);

            if(MathAbs(c.price-lineAtC)<=tolerance)
               result.touches=3;
         }
      }

      double lineNow=b.price+slope*(double)(TimeCurrent()-b.time);

      // The line is structurally valid when price has not decisively
      // broken below it. This check affects trading validity only.
      result.valid=(lastClose>=lineNow-tolerance);
   }

   if(bearish)
   {
      // Bearish trendline = resistance line through the two latest
      // confirmed lower highs.
      SwingPoint a=highs[nh-2];
      SwingPoint b=highs[nh-1];

      if(b.time<=a.time || b.price>=a.price)
         return result;

      result.bias="BEARISH";
      result.t1=a.time;
      result.p1=a.price;
      result.t2=b.time;
      result.p2=b.price;
      result.touches=2;

      double slope=(b.price-a.price)/(double)(b.time-a.time);

      // A valid bearish line must not have a confirmed swing high
      // materially above the line after the first anchor.
      for(int i=nh-1;i>=0;i--)
      {
         if(highs[i].time<=a.time)
            continue;

         double expected=a.price+slope*(double)(highs[i].time-a.time);

         if(highs[i].price > expected+tolerance)
         {
            result.valid=false;
            return result;
         }
      }

      if(nh>=3)
      {
         SwingPoint c=highs[nh-3];

         if(c.time<a.time)
         {
            double lineAtC=a.price+slope*(double)(c.time-a.time);

            if(MathAbs(c.price-lineAtC)<=tolerance)
               result.touches=3;
         }
      }

      double lineNow=b.price+slope*(double)(TimeCurrent()-b.time);

      // This affects trading validity only; the drawing still shows
      // the confirmed structural line.
      result.valid=(lastClose<=lineNow+tolerance);
   }

   return result;
}

//==================================================================
// TRENDLINE DRAWING
//==================================================================

void DrawSupportResistance()
{
   // Support/resistance is rendered by DrawStructureVisuals() as
   // confirmed ZigZag levels with a finite 30-candle extension.
   ObjectDelete(0,g_prefix+"VIS_RESISTANCE");
   ObjectDelete(0,g_prefix+"VIS_SUPPORT");
}


void BuildZigZagPoints(const string symbol,
                       const ENUM_TIMEFRAMES tf,
                       const int lookback,
                       SwingPoint &points[])
{
   ArrayResize(points,0);

   SwingPoint highs[];
   SwingPoint lows[];

   if(CollectSwings(symbol,tf,lookback,highs,lows)<=0)
      return;

   int nh=ArraySize(highs);
   int nl=ArraySize(lows);
   int total=nh+nl;

   if(total<2)
      return;

   SwingPoint raw[];
   ArrayResize(raw,total);

   int n=0;
   for(int i=0;i<nh;i++)
      raw[n++]=highs[i];

   for(int i=0;i<nl;i++)
      raw[n++]=lows[i];

   SortSwingsByTime(raw);

   // The trendline must use exactly the same confirmed ZigZag pivots
   // that are visible on the chart. Consecutive pivots of the same type
   // are compressed to the more extreme pivot.
   for(int i=0;i<n;i++)
   {
      int m=ArraySize(points);

      if(m==0)
      {
         ArrayResize(points,1);
         points[0]=raw[i];
         continue;
      }

      if(points[m-1].isHigh==raw[i].isHigh)
      {
         bool replace=
            (raw[i].isHigh && raw[i].price>points[m-1].price) ||
            (!raw[i].isHigh && raw[i].price<points[m-1].price);

         if(replace)
            points[m-1]=raw[i];
      }
      else
      {
         ArrayResize(points,m+1);
         points[m]=raw[i];
      }
   }
}

#ifdef STB_PH3_TRENDLINE_ARCHIVE
// PH3-ARCHIVE: automatic H4 trendline renderer REMOVED (MASTER Phase 3).
// No TF_TREND_* objects are created or drawn; the original body below is
// excluded from compilation and kept only as reversible archive text.
void DrawH4Trendline()
{
   string highBase=g_prefix+"TF_TREND_HIGH";
   string highExt =g_prefix+"TF_TREND_HIGH_EXT";
   string lowBase =g_prefix+"TF_TREND_LOW";
   string lowExt  =g_prefix+"TF_TREND_LOW_EXT";

   ObjectDelete(0,highBase);
   ObjectDelete(0,highExt);
   ObjectDelete(0,lowBase);
   ObjectDelete(0,lowExt);

   ENUM_TIMEFRAMES tf=PERIOD_H4;
   int lookback=InpLookbackH4;

   if(lookback<InpSwingLeft+InpSwingRight+10)
      lookback=InpSwingLeft+InpSwingRight+10;

   SwingPoint zz[];
   BuildZigZagPoints(_Symbol,tf,lookback,zz);

   int n=ArraySize(zz);
   if(n<4)
      return;

   SwingPoint highs[];
   SwingPoint lows[];

   for(int i=n-1;i>=0;i--)
   {
      if(zz[i].isHigh)
      {
         int h=ArraySize(highs);
         ArrayResize(highs,h+1);
         highs[h]=zz[i];
      }
      else
      {
         int l=ArraySize(lows);
         ArrayResize(lows,l+1);
         lows[l]=zz[i];
      }

      if(ArraySize(highs)>=2 && ArraySize(lows)>=2)
         break;
   }

   if(ArraySize(highs)<2 || ArraySize(lows)<2)
      return;

   SwingPoint hNew=highs[0], hOld=highs[1];
   SwingPoint lNew=lows[0],  lOld=lows[1];

   MqlRates rates[];
   if(!GetRates(_Symbol,tf,lookback,rates))
      return;

   const int extensionBars=30;
   double pip=PipSize(_Symbol);
   double tolerance=(pip>0.0 ? MathMax(0.0,InpTrendlineTolerancePips)*pip : 0.0);

   if(hOld.time>0 && hNew.time>hOld.time && hOld.price>0.0 && hNew.price>0.0 &&
      hOld.shift>hNew.shift)
   {
      double slope=(hNew.price-hOld.price)/(double)(hNew.time-hOld.time);

      if(ObjectCreate(0,highBase,OBJ_TREND,0,hOld.time,hOld.price,hNew.time,hNew.price))
      {
         ObjectSetInteger(0,highBase,OBJPROP_COLOR,InpBearTrendlineColor);
         ObjectSetInteger(0,highBase,OBJPROP_WIDTH,InpTrendlineWidth);
         ObjectSetInteger(0,highBase,OBJPROP_STYLE,InpTrendlineStyle);
         ObjectSetInteger(0,highBase,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,highBase,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,highBase,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
         ObjectSetInteger(0,highBase,OBJPROP_BACK,true);
         ObjectSetInteger(0,highBase,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,highBase,OBJPROP_HIDDEN,false);
      }

      int endShift=MathMax(1,hNew.shift-extensionBars);
      int breakShift=-1;

      for(int sh=hNew.shift-1;sh>=endShift;sh--)
      {
         double line=hNew.price+slope*(double)(rates[sh].time-hNew.time);
         if(rates[sh].close>line+tolerance)
         {
            breakShift=sh;
            break;
         }
      }

      int finalShift=(breakShift>0 ? breakShift : endShift);
      datetime endTime=rates[finalShift].time;
      double endPrice=hNew.price+slope*(double)(endTime-hNew.time);

      if(endTime>hNew.time &&
         ObjectCreate(0,highExt,OBJ_TREND,0,hNew.time,hNew.price,endTime,endPrice))
      {
         ObjectSetInteger(0,highExt,OBJPROP_COLOR,InpBearTrendlineColor);
         ObjectSetInteger(0,highExt,OBJPROP_WIDTH,InpTrendlineWidth);
         ObjectSetInteger(0,highExt,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,highExt,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,highExt,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,highExt,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
         ObjectSetInteger(0,highExt,OBJPROP_BACK,true);
         ObjectSetInteger(0,highExt,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,highExt,OBJPROP_HIDDEN,false);
      }

      if(breakShift>0)
         Print("STB TRENDLINE HIGH BREAK symbol=",_Symbol,
               " tf=",EnumToString(tf)," at=",TimeToString(endTime),
               " tolerancePips=",DoubleToString(InpTrendlineTolerancePips,1));
   }

   if(lOld.time>0 && lNew.time>lOld.time && lOld.price>0.0 && lNew.price>0.0 &&
      lOld.shift>lNew.shift)
   {
      double slope=(lNew.price-lOld.price)/(double)(lNew.time-lOld.time);

      if(ObjectCreate(0,lowBase,OBJ_TREND,0,lOld.time,lOld.price,lNew.time,lNew.price))
      {
         ObjectSetInteger(0,lowBase,OBJPROP_COLOR,InpBullTrendlineColor);
         ObjectSetInteger(0,lowBase,OBJPROP_WIDTH,InpTrendlineWidth);
         ObjectSetInteger(0,lowBase,OBJPROP_STYLE,InpTrendlineStyle);
         ObjectSetInteger(0,lowBase,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,lowBase,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,lowBase,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
         ObjectSetInteger(0,lowBase,OBJPROP_BACK,true);
         ObjectSetInteger(0,lowBase,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,lowBase,OBJPROP_HIDDEN,false);
      }

      int endShift=MathMax(1,lNew.shift-extensionBars);
      int breakShift=-1;

      for(int sh=lNew.shift-1;sh>=endShift;sh--)
      {
         double line=lNew.price+slope*(double)(rates[sh].time-lNew.time);
         if(rates[sh].close<line-tolerance)
         {
            breakShift=sh;
            break;
         }
      }

      int finalShift=(breakShift>0 ? breakShift : endShift);
      datetime endTime=rates[finalShift].time;
      double endPrice=lNew.price+slope*(double)(endTime-lNew.time);

      if(endTime>lNew.time &&
         ObjectCreate(0,lowExt,OBJ_TREND,0,lNew.time,lNew.price,endTime,endPrice))
      {
         ObjectSetInteger(0,lowExt,OBJPROP_COLOR,InpBullTrendlineColor);
         ObjectSetInteger(0,lowExt,OBJPROP_WIDTH,InpTrendlineWidth);
         ObjectSetInteger(0,lowExt,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,lowExt,OBJPROP_RAY_LEFT,false);
         ObjectSetInteger(0,lowExt,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,lowExt,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
         ObjectSetInteger(0,lowExt,OBJPROP_BACK,true);
         ObjectSetInteger(0,lowExt,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,lowExt,OBJPROP_HIDDEN,false);
      }

      if(breakShift>0)
         Print("STB TRENDLINE LOW BREAK symbol=",_Symbol,
               " tf=",EnumToString(tf)," at=",TimeToString(endTime),
               " tolerancePips=",DoubleToString(InpTrendlineTolerancePips,1));
   }

   ChartRedraw(0);
}
//==================================================================
#endif
// PH3-ARCHIVE-END: automatic trendline renderer excluded.
// M15 CHoCH + BOS
//==================================================================

void STB_LogStructureDebug(const string symbol,
                             const int direction,
                             const SwingPoint &latestHigh,
                             const SwingPoint &latestLow,
                             const MqlRates &rates[])
{
   // Diagnostic-only instrumentation. It does not change signal eligibility.
   // Restrict output to the chart symbol and one line per M15 bar/direction.
   if(symbol!=_Symbol)
      return;

   static datetime lastBuyBar=0;
   static datetime lastSellBar=0;

   datetime currentBar=iTime(symbol,PERIOD_M15,0);

   if(currentBar<=0)
      return;

   if(direction>0)
   {
      if(currentBar==lastBuyBar)
         return;
      lastBuyBar=currentBar;
   }
   else
   {
      if(currentBar==lastSellBar)
         return;
      lastSellBar=currentBar;
   }

   const int window=30;
   double extreme=(direction>0 ? -DBL_MAX:DBL_MAX);
   int extremeShift=-1;

   int size=ArraySize(rates);

   for(int s=1;s<=window && s<size;s++)
   {
      if(direction>0)
      {
         if(s<latestHigh.shift && rates[s].close>extreme)
         {
            extreme=rates[s].close;
            extremeShift=s;
         }
      }
      else
      {
         if(s<latestLow.shift && rates[s].close<extreme)
         {
            extreme=rates[s].close;
            extremeShift=s;
         }
      }
   }

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   if(direction>0)
   {
      double delta=(extreme>-DBL_MAX/2.0 ?
                    extreme-latestHigh.price:0.0);

      Print("STB STRUCTURE DEBUG symbol=",symbol,
            " dir=BUY",
            " latestHighShift=",latestHigh.shift,
            " latestHigh=",DoubleToString(latestHigh.price,digits),
            " maxRecentClose=",DoubleToString(
               extreme>-DBL_MAX/2.0 ? extreme:0.0,digits),
            " maxCloseShift=",extremeShift,
            " closeMinusHigh=",DoubleToString(delta,digits));
   }
   else
   {
      double delta=(extreme<DBL_MAX/2.0 ?
                    latestLow.price-extreme:0.0);

      Print("STB STRUCTURE DEBUG symbol=",symbol,
            " dir=SELL",
            " latestLowShift=",latestLow.shift,
            " latestLow=",DoubleToString(latestLow.price,digits),
            " minRecentClose=",DoubleToString(
               extreme<DBL_MAX/2.0 ? extreme:0.0,digits),
            " minCloseShift=",extremeShift,
            " lowMinusClose=",DoubleToString(delta,digits));
   }
}


bool DetectStructure(const string symbol,
                     const int direction,
                     int &chochShift,
                     int &bosShift,
                     SwingPoint &breakSwing)
{
   chochShift=-1;
   bosShift=-1;
   ZeroMemory(breakSwing);

   SwingPoint highs[];
   SwingPoint lows[];

   CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows);

   int nh=ArraySize(highs);
   int nl=ArraySize(lows);

   if(nh<2 || nl<2)
      return false;

   MqlRates r[];

   if(!GetRates(symbol,PERIOD_M15,InpLookbackM15,r))
      return false;

   const int structureWindowBars=30;
   const int rightBars=MathMax(1,STB_EffectiveSwingRight(PERIOD_M15));

   if(direction>0)
   {
      for(int s=1;s<=structureWindowBars && s<ArraySize(r);s++)
      {
         // Find the newest confirmed high that already existed before
         // this closed breakout candle. No same/younger pivot can be used.
         for(int i=nh-1;i>=0;i--)
         {
            int pivotShift=highs[i].shift;

            if(pivotShift<=s)
               continue;

            // The pivot must have been confirmed by its right-side bars.
            if(pivotShift<rightBars)
               continue;

            if(pivotShift-s>structureWindowBars)
               continue;

            if(r[s].close>highs[i].price)
            {
               chochShift=pivotShift;
               bosShift=s;
               breakSwing=highs[i];
               return true;
            }
         }
      }
   }
   else
   {
      for(int s=1;s<=structureWindowBars && s<ArraySize(r);s++)
      {
         for(int i=nl-1;i>=0;i--)
         {
            int pivotShift=lows[i].shift;

            if(pivotShift<=s)
               continue;

            if(pivotShift<rightBars)
               continue;

            if(pivotShift-s>structureWindowBars)
               continue;

            if(r[s].close<lows[i].price)
            {
               chochShift=pivotShift;
               bosShift=s;
               breakSwing=lows[i];
               return true;
            }
         }
      }
   }

   if(direction>0)
      STB_LogStructureDebug(symbol,direction,highs[nh-1],lows[nl-1],r);
   else
      STB_LogStructureDebug(symbol,direction,highs[nh-1],lows[nl-1],r);

   return false;
}
//==================================================================
// FVG / DISPLACEMENT ENGINE
//==================================================================

double LocalATR(const MqlRates &r[],const int shift,const int period)
{
   int size=ArraySize(r);
   if(size<=shift+1)
      return 0.0;

   int count=MathMin(period,size-shift-1);
   if(count<=0)
      return 0.0;

   double sum=0.0;
   for(int i=shift;i<shift+count;i++)
   {
      double prevClose=r[i+1].close;
      double tr1=r[i].high-r[i].low;
      double tr2=MathAbs(r[i].high-prevClose);
      double tr3=MathAbs(r[i].low-prevClose);
      sum+=MathMax(tr1,MathMax(tr2,tr3));
   }

   return sum/(double)count;
}

bool IsBullishDisplacement(const MqlRates &r[],const int shift)
{
   double atr=LocalATR(r,shift+1,20);
   if(atr<=0.0)
      return false;

   double range=r[shift].high-r[shift].low;
   double body=MathAbs(r[shift].close-r[shift].open);

   if(range<=0.0)
      return false;

   return r[shift].close>r[shift].open &&
          range>=atr*1.15 &&
          body/range>=0.55 &&
          (r[shift].close-r[shift].low)/range>=0.70;
}

bool IsBearishDisplacement(const MqlRates &r[],const int shift)
{
   double atr=LocalATR(r,shift+1,20);
   if(atr<=0.0)
      return false;

   double range=r[shift].high-r[shift].low;
   double body=MathAbs(r[shift].close-r[shift].open);

   if(range<=0.0)
      return false;

   return r[shift].close<r[shift].open &&
          range>=atr*1.15 &&
          body/range>=0.55 &&
          (r[shift].high-r[shift].close)/range>=0.70;
}

bool FindFVG(const string symbol,
             const int direction,
             const int bosShift,
             int &fvgShift)
{
   fvgShift=-1;

   MqlRates r[];
   if(!GetRates(symbol,PERIOD_M15,InpLookbackM15,r))
      return false;

   int maxScan=MathMin(STB_EffectivePatternWindow(),InpLookbackM15-4);

   for(int s=1;s<=maxScan;s++)
   {
      int impulse=s+1;

      // Tie the imbalance to the detected BOS/CHoCH instead of allowing
      // an unrelated gap anywhere in the scan window.
      if(MathAbs(impulse-bosShift)>2)
         continue;

      if(direction>0 &&
         r[s].low>r[s+2].high &&
         IsBullishDisplacement(r,impulse))
      {
         fvgShift=s;
         return true;
      }

      if(direction<0 &&
         r[s].high<r[s+2].low &&
         IsBearishDisplacement(r,impulse))
      {
         fvgShift=s;
         return true;
      }
   }

   return false;
}

//==================================================================
// ORDER BLOCK / DISPLACEMENT ORIGIN ENGINE
//==================================================================

bool FindOriginCandle(const string symbol,
                      const int direction,
                      const int bosShift,
                      int &originShift,
                      double &originHigh,
                      double &originLow)
{
   originShift=-1;
   originHigh=0.0;
   originLow=0.0;

   MqlRates r[];
   if(!GetRates(symbol,PERIOD_M15,InpLookbackM15,r))
      return false;

   int start=bosShift+1;
   int end=MathMin(bosShift+STB_EffectivePatternWindow(),
                   InpLookbackM15-3);

   // Professionalized OB definition:
   // 1) last opposite candle before the displacement,
   // 2) immediately followed by directional displacement,
   // 3) displacement body/range must be meaningful relative to local ATR,
   // 4) the subsequent structure break must be consistent with direction.
   for(int s=start;s<=end;s++)
   {
      int impulse=s-1;
      if(impulse<1)
         continue;

      bool opposite=(direction>0)
                     ? (r[s].close<r[s].open)
                     : (r[s].close>r[s].open);

      if(!opposite)
         continue;

      bool displacement=(direction>0)
                         ? IsBullishDisplacement(r,impulse)
                         : IsBearishDisplacement(r,impulse);

      if(!displacement)
         continue;

      bool broke=(direction>0)
                 ? (r[impulse].close>r[s].high)
                 : (r[impulse].close<r[s].low);

      if(!broke)
         continue;

      originShift=s;
      originHigh=r[s].high;
      originLow=r[s].low;
      return true;
   }

   return false;
}

//==================================================================
// SETUP BUILDER
//==================================================================

bool BuildSetup(const string symbol,
                const int direction,
                Setup &s)
{
   ZeroMemory(s);

   bool effectiveOscHardFilter=(InpDiagnosticM15Mode ? false : InpOscillatorHardFilter);
   bool effectiveStrictPatternFilters=(InpDiagnosticM15Mode ? false : InpStrictPatternFilters);
   bool effectiveAllowUniversal=(InpDiagnosticM15Mode ? true : InpAllowUniversal);

   s.symbol=symbol;
   s.direction=direction;
   s.adaptiveProfile=0;

   g_lastBuildRejectReason="UNKNOWN";
   STB_AP_SelectActive(symbol,direction);
   s.adaptiveProfile=g_activeAdaptiveProfileId;

   // Snapshot all execution-relevant profile parameters into the Setup contract.
   // From this point Risk/Execution must not re-read Adaptive state.
   s.pendingMaxBars=MathMax(0,STB_EffectiveMaxPendingBars());
   s.entryBufferPips=MathMax(0.0,STB_EffectiveEntryBuffer());
   s.slBufferPips=MathMax(0.0,STB_EffectiveSLBuffer());
   s.minimumRR=MathMax(0.0,STB_EffectiveMinimumRR());

   OscillatorState osc;
   ZeroMemory(osc);

   bool oscReady=GetOscillatorState(symbol,osc);

   if(!oscReady && InpOscillatorHardFilter && !InpDiagnosticM15Mode)
      return STB_BuildReject(symbol,direction,"OSCILLATOR_DATA_UNAVAILABLE");

   if(oscReady && InpOscillatorHardFilter && !InpDiagnosticM15Mode)
   {
      if(direction>0 && !osc.buyConfirmed)
         return STB_BuildReject(symbol,direction,"OSCILLATOR_BUY_NOT_CONFIRMED");

      if(direction<0 && !osc.sellConfirmed)
         return STB_BuildReject(symbol,direction,"OSCILLATOR_SELL_NOT_CONFIRMED");
   }

   TrendInfo ti=GetH4Trend(symbol);

   bool aligned=
      ti.valid &&
      ((direction>0 && ti.bias=="BULLISH") ||
       (direction<0 && ti.bias=="BEARISH"));

   if(!aligned && !InpAllowUniversal && !InpDiagnosticM15Mode)
      return STB_BuildReject(symbol,direction,"H4_ALIGNMENT_REQUIRED");

   int chochShift=-1;
   int bosShift=-1;
   SwingPoint breakSwing;

   if(!DetectStructure(symbol,direction,chochShift,bosShift,breakSwing))
      return STB_BuildReject(symbol,direction,"NO_VALID_CHOCH_BOS");

   int maxAge=STB_EffectiveMaxSetupAgeBars();

   if(maxAge>0 && bosShift>maxAge)
      return STB_BuildReject(symbol,direction,"BOS_TOO_OLD");

   int fvgShift=-1;
   bool hasFVG=FindFVG(symbol,direction,bosShift,fvgShift);

   if(InpStrictPatternFilters && !InpDiagnosticM15Mode && InpRequireFVG && !hasFVG)
      return STB_BuildReject(symbol,direction,"FVG_REQUIRED");

   int originShift=-1;
   double originHigh=0.0;
   double originLow=0.0;

   bool hasOB=FindOriginCandle(symbol,direction,
                               bosShift,originShift,
                               originHigh,originLow);

   if(InpStrictPatternFilters && !InpDiagnosticM15Mode && InpRequireOB && !hasOB)
      return STB_BuildReject(symbol,direction,"OB_REQUIRED");

   if(!hasOB && !InpStrictPatternFilters)
   {
      originShift=breakSwing.shift;
      originHigh=iHigh(symbol,PERIOD_M15,originShift);
      originLow=iLow(symbol,PERIOD_M15,originShift);

      if(originShift<0 || originHigh<=0.0 || originLow<=0.0)
         return STB_BuildReject(symbol,direction,"ORIGIN_FALLBACK_INVALID");
   }

   SwingPoint highs[];
   SwingPoint lows[];

   CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows);

   int nh=ArraySize(highs);
   int nl=ArraySize(lows);

   if(nh<2 || nl<2)
      return STB_BuildReject(symbol,direction,"INSUFFICIENT_SWINGS");

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return STB_BuildReject(symbol,direction,"NO_TICK");

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return STB_BuildReject(symbol,direction,"PIP_SIZE_INVALID");

   double entryBuffer=STB_EffectiveEntryBuffer();
   double slBuffer=STB_EffectiveSLBuffer();
   double minimumRR=STB_EffectiveMinimumRR();

   if(direction>0)
   {
      s.entry=NormalizePrice(symbol,originHigh + entryBuffer*pip);
      s.sl=NormalizePrice(symbol,breakSwing.price - slBuffer*pip);

      double risk=MathAbs(s.entry-s.sl);
      double target=DBL_MAX;

      if(risk<=0.0 || s.sl>=s.entry)
         return STB_BuildReject(symbol,direction,"BUY_GEOMETRY_INVALID");

      for(int i=0;i<nh;i++)
      {
         double candidate=highs[i].price;

         if(candidate<=s.entry)
            continue;

         double reward=candidate-s.entry;

         if(reward+1e-12 < risk*minimumRR)
            continue;

         if(candidate<target)
            target=candidate;
      }

      if(target==DBL_MAX)
         return STB_BuildReject(symbol,direction,"BUY_NO_RR_TARGET");

      s.tp=NormalizePrice(symbol,target);

      if(s.entry<=tick.ask)
         return STB_BuildReject(symbol,direction,"BUY_ENTRY_NOT_ABOVE_ASK");
   }
   else
   {
      s.entry=NormalizePrice(symbol,originLow - entryBuffer*pip);
      s.sl=NormalizePrice(symbol,breakSwing.price + slBuffer*pip);

      double risk=MathAbs(s.entry-s.sl);
      double target=-DBL_MAX;

      if(risk<=0.0 || s.sl<=s.entry)
         return STB_BuildReject(symbol,direction,"SELL_GEOMETRY_INVALID");

      for(int i=0;i<nl;i++)
      {
         double candidate=lows[i].price;

         if(candidate>=s.entry)
            continue;

         double reward=s.entry-candidate;

         if(reward+1e-12 < risk*minimumRR)
            continue;

         if(candidate>target)
            target=candidate;
      }

      if(target==-DBL_MAX)
         return STB_BuildReject(symbol,direction,"SELL_NO_RR_TARGET");

      s.tp=NormalizePrice(symbol,target);

      if(s.entry>=tick.bid)
         return STB_BuildReject(symbol,direction,"SELL_ENTRY_NOT_BELOW_BID");
   }

   double risk=MathAbs(s.entry-s.sl);
   double reward=MathAbs(s.tp-s.entry);

   if(risk<=0.0 || reward<=0.0)
      return STB_BuildReject(symbol,direction,"RR_GEOMETRY_INVALID");

   s.rr=reward/risk;

   if(s.rr+1e-9<minimumRR)
      return STB_BuildReject(symbol,direction,"RR_BELOW_PROFILE_MINIMUM");

   s.score=(aligned ? 40.0:25.0);

   if(bosShift<=2)
      s.score+=30.0;
   else if(bosShift<=4)
      s.score+=25.0;
   else
      s.score+=20.0;

   if(s.rr>=2.0)
      s.score+=15.0;
   else if(s.rr>=1.5)
      s.score+=10.0;
   else
      s.score+=5.0;

   if(hasFVG)
      s.score+=10.0;

   if(hasOB)
      s.score+=10.0;

   if(oscReady)
   {
      double rsiWeight=MathMax(0.0,STB_EffectiveRSIWeight());
      double cciWeight=MathMax(0.0,STB_EffectiveCCIWeight());

      if(direction>0 && osc.buyConfirmed)
         s.score+=rsiWeight*0.5+cciWeight*0.5;
      else if(direction<0 && osc.sellConfirmed)
         s.score+=rsiWeight*0.5+cciWeight*0.5;
      else if(direction>0)
      {
         if(osc.rsi1>=50.0) s.score+=rsiWeight*0.25;
         if(osc.cci1>=0.0) s.score+=cciWeight*0.25;
      }
      else
      {
         if(osc.rsi1<=50.0) s.score+=rsiWeight*0.25;
         if(osc.cci1<=0.0) s.score+=cciWeight*0.25;
      }
   }

   if(s.score>100.0)
      s.score=100.0;

   s.setupTime=iTime(symbol,PERIOD_M15,bosShift);

   if(s.setupTime<=0)
      return STB_BuildReject(symbol,direction,"BOS_TIME_INVALID");

   double adaptiveFloor=STB_AdaptiveScoreFloor(symbol,direction);

   if(s.score+1e-9<adaptiveFloor)
   {
      g_lastBuildRejectReason="ADAPTIVE_SCORE_FLOOR";

      Print("STB ADAPTIVE REJECT symbol=",symbol,
            " dir=",(direction>0 ? "BUY":"SELL"),
            " profile=",IntegerToString(s.adaptiveProfile),
            " score=",DoubleToString(s.score,1),
            " floor=",DoubleToString(adaptiveFloor,1),
            " RR=",DoubleToString(s.rr,2));

      STB_AdaptiveRecordSetup(s,false);
      STB_LogBuildReject(symbol,direction,g_lastBuildRejectReason);
      STB_AP_ClearActive();
      return false;
   }

   s.valid=true;
   s.trendAligned=aligned;
   s.chochShift=chochShift;
   s.bosShift=bosShift;
   s.originShift=originShift;
   s.fvgShift=fvgShift;

   s.originHigh=originHigh;
   s.originLow=originLow;

   s.swingHigh=(direction>0 ? s.tp : breakSwing.price);
   s.swingLow =(direction>0 ? breakSwing.price : s.tp);

   STB_LogSetupReady(s);
   STB_AP_ClearActive();

   return true;
}

//==================================================================
// GLOBAL VARIABLE IDENTIFIERS
//==================================================================

string TicketLockName(const ulong ticket)
{
   return ScopedStateName("LOCK_"+(string)ticket);
}

string PositionPnlName(const ulong positionId)
{
   return ScopedStateName("PNL_"+(string)positionId);
}

double GetAccumulatedPositionPnl(const ulong positionId)
{
   if(positionId==0)
      return 0.0;

   string name=PositionPnlName(positionId);
   if(!GlobalVariableCheck(name))
      return 0.0;

   return GlobalVariableGet(name);
}

void SetAccumulatedPositionPnl(const ulong positionId,const double value)
{
   if(positionId==0)
      return;

   GlobalVariableSet(PositionPnlName(positionId),value);
}

double TakeAccumulatedPositionPnl(const ulong positionId)
{
   double value=GetAccumulatedPositionPnl(positionId);

   if(positionId>0)
      GlobalVariableDel(PositionPnlName(positionId));

   return value;
}

bool IsPositionIdentifierOpen(const ulong positionId)
{
   if(positionId==0)
      return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(identifier==positionId)
         return true;
   }

   return false;
}

double GetLockedPips(const ulong ticket)
{
   string name=TicketLockName(ticket);

   if(!GlobalVariableCheck(name))
      return 0.0;

   return GlobalVariableGet(name);
}

void SetLockedPips(const ulong ticket,const double value)
{
   GlobalVariableSet(TicketLockName(ticket),value);
}

ulong SymbolHash(const string symbol)
{
   ulong h=1469598103934665603ULL;

   int len=StringLen(symbol);

   for(int i=0;i<len;i++)
   {
      ushort c=StringGetCharacter(symbol,i);
      h ^= (ulong)c;
      h *= 1099511628211ULL;
   }

   return h;
}

string ScopedStateName(const string purpose)
{
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|"+purpose;
   return g_prefix+(string)SymbolHash(raw);
}

string ScopedSymbolStateName(const string purpose,const string symbol)
{
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|"+purpose+"|"+symbol;
   return g_prefix+(string)SymbolHash(raw);
}

string LastSetupName(const string symbol,const int direction)
{
   return ScopedSymbolStateName("LAST_"+(direction>0 ? "B":"S"),symbol);
}

datetime GetLastSetupTime(const string symbol,const int direction)
{
   string name=LastSetupName(symbol,direction);

   if(!GlobalVariableCheck(name))
      return 0;

   return (datetime)GlobalVariableGet(name);
}

void SetLastSetupTime(const string symbol,const int direction,const datetime t)
{
   GlobalVariableSet(LastSetupName(symbol,direction),(double)t);
}

//==================================================================
// IMMUTABLE PENDING LIFECYCLE METADATA
//==================================================================

datetime STB_ParsePendingSetupTime(const string comment,
                                      const datetime fallback)
{
   int pos=StringFind(comment,"|T");
   if(pos<0)
      return fallback;

   int start=pos+2;
   int end=StringFind(comment,"|",start);
   string raw=(end>=0 ? StringSubstr(comment,start,end-start)
                       : StringSubstr(comment,start));

   long value=(long)StringToInteger(raw);
   return value>0 ? (datetime)value:fallback;
}

int STB_ParsePendingMaxBars(const string comment,const int fallback)
{
   int pos=StringFind(comment,"|L");
   if(pos<0) return fallback;
   int start=pos+2;
   int end=StringFind(comment,"|",start);
   string raw=(end>=0 ? StringSubstr(comment,start,end-start)
                      : StringSubstr(comment,start));
   int value=(int)StringToInteger(raw);
   return value>=0 ? value:fallback;
}

double STB_ParsePendingEntryBufferPips(const string comment,const double fallback)
{
   int pos=StringFind(comment,"|EB");
   if(pos<0) return fallback;
   int start=pos+3;
   int end=StringFind(comment,"|",start);
   string raw=(end>=0 ? StringSubstr(comment,start,end-start)
                      : StringSubstr(comment,start));
   double value=StringToDouble(raw);
   return (MathIsValidNumber(value) && value>=0.0) ? value:fallback;
}

double STB_ParsePendingSLBufferPips(const string comment,const double fallback)
{
   int pos=StringFind(comment,"|SB");
   if(pos<0) return fallback;
   int start=pos+3;
   int end=StringFind(comment,"|",start);
   string raw=(end>=0 ? StringSubstr(comment,start,end-start)
                      : StringSubstr(comment,start));
   double value=StringToDouble(raw);
   return (MathIsValidNumber(value) && value>=0.0) ? value:fallback;
}

//==================================================================
// EXPOSURE MANAGEMENT
//==================================================================

enum STB_OWNER_CLASS
{
   STB_OWNER_FOREIGN = 0,
   STB_OWNER_EA      = 1,
   STB_OWNER_MANUAL  = 2
};

STB_OWNER_CLASS STB_GetPositionOwner(const ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return STB_OWNER_FOREIGN;

   long magic=PositionGetInteger(POSITION_MAGIC);
   if(magic==(long)InpMagic) return STB_OWNER_EA;
   if(magic==0) return STB_OWNER_MANUAL;
   return STB_OWNER_FOREIGN;
}

STB_OWNER_CLASS STB_GetOrderOwner(const ulong ticket)
{
   if(ticket==0 || !OrderSelect(ticket))
      return STB_OWNER_FOREIGN;

   long magic=OrderGetInteger(ORDER_MAGIC);
   if(magic==(long)InpMagic) return STB_OWNER_EA;
   if(magic==0) return STB_OWNER_MANUAL;
   return STB_OWNER_FOREIGN;
}

bool IsManagedPosition(const ulong ticket)
{
   STB_OWNER_CLASS owner=STB_GetPositionOwner(ticket);
   if(owner==STB_OWNER_EA) return InpManageEAPositions;
   if(owner==STB_OWNER_MANUAL) return InpManageManualPositions;
   return false;
}

bool IsManagedOrder(const ulong ticket)
{
   STB_OWNER_CLASS owner=STB_GetOrderOwner(ticket);
   if(owner==STB_OWNER_EA) return InpManageEAPending;
   if(owner==STB_OWNER_MANUAL) return InpManageManualPending;
   return false;
}

// EXECUTION exposure predicate.
// Intentionally independent of Management enable/disable inputs.
// A position/order owned by this EA or explicitly manual-owned still blocks
// the one-setup-per-symbol execution invariant even when management is off.
bool STB_HasExecutionExposure(const string symbol)
{
   if(!InpOneSetupPerSymbol || symbol=="")
      return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      STB_OWNER_CLASS owner=STB_GetPositionOwner(ticket);

      if(owner==STB_OWNER_EA || owner==STB_OWNER_MANUAL)
         return true;
   }

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;

      STB_OWNER_CLASS owner=STB_GetOrderOwner(ticket);

      if(owner==STB_OWNER_EA || owner==STB_OWNER_MANUAL)
         return true;
   }

   return false;
}

//==================================================================
// ONE-CLICK HEDGE
//==================================================================

bool IsHedgingAccount()
{
   long mode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return (mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

bool HasManagedPositionDirection(const string symbol,const long positionType)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      if(PositionGetInteger(POSITION_TYPE)!=positionType)
         continue;

      if(IsManagedPosition(ticket))
         return true;
   }

   return false;
}

bool STB_ProtectionCalculateHedgeSL(const string symbol,
                                      const long positionType,
                                      double &sl)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double referencePrice=
      (positionType==POSITION_TYPE_BUY ? tick.ask :
       positionType==POSITION_TYPE_SELL ? tick.bid : 0.0);

   if(referencePrice<=0.0)
      return false;

   if(!STB_ProtectionCalculateNearestStructuralSL(
         symbol,positionType,referencePrice,sl))
      return false;

   sl=NormalizePrice(symbol,sl);
   return IsValidSLForPosition(symbol,positionType,sl);
}

bool STB_RiskAuthorizeMarketHedge(const string symbol,
                                      const int direction,
                                      double &volume,
                                      const double sl)
{
   if(symbol=="" || direction==0)
      return false;

   if(!STB_TradeEnvironmentAllowed() || !IsHedgingAccount())
      return false;
   if(!IsSymbolTradable(symbol))
      return false;

   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   if((direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY))
      return false;

   long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
   if((orderMode & SYMBOL_ORDER_MARKET)!=SYMBOL_ORDER_MARKET ||
      (orderMode & SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
      return false;

   if(!IsSpreadAcceptable(symbol))
      return false;

   volume=NormalizeVolume(symbol,volume);
   if(volume<=0.0)
      return false;

   long positionType=(direction>0 ? POSITION_TYPE_BUY:POSITION_TYPE_SELL);
   if(!IsValidSLForPosition(symbol,positionType,sl))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   ENUM_ORDER_TYPE_FILLING filling=ORDER_FILLING_RETURN;
   if(!STB_GetMarketFilling(symbol,filling))
      return false;

   MqlTradeRequest request={};
   MqlTradeCheckResult check={};

   request.action=TRADE_ACTION_DEAL;
   request.symbol=symbol;
   request.magic=InpMagic;
   request.volume=volume;
   request.type=(direction>0 ? ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   request.price=(direction>0 ? tick.ask:tick.bid);
   request.sl=sl;
   request.type_filling=filling;
   request.type_time=ORDER_TIME_GTC;
   request.comment="STB|HEDGE";

   ResetLastError();
   if(!OrderCheck(request,check))
      return false;

   if(check.retcode!=0 && check.retcode!=TRADE_RETCODE_DONE)
      return false;

   return true;
}

// EXECUTION OWNER CONTRACT:
// Creates a NEW market hedge position only. It receives an already-authorized
// request, submits the deal, verifies the server response, then verifies the
// resulting terminal position before reporting success.
struct STB_MarketHedgeRequest
{
   string symbol;
   int    direction;
   double volume;
   double sl;
};

bool STB_FindPositionTicketByIdentifier(const ulong positionId,
                                        const string symbol,
                                        const long positionType,
                                        const long magic,
                                        ulong &ticket)
{
   ticket=0;

   if(positionId==0)
      return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong candidate=PositionGetTicket(i);

      if(candidate==0 || !PositionSelectByTicket(candidate))
         continue;

      if((ulong)PositionGetInteger(POSITION_IDENTIFIER)!=positionId)
         continue;

      if(symbol!="" && PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      if(positionType>=0 &&
         PositionGetInteger(POSITION_TYPE)!=positionType)
         continue;

      if(magic>=0 &&
         PositionGetInteger(POSITION_MAGIC)!=magic)
         continue;

      ticket=candidate;
      return true;
   }

   return false;
}

enum STB_HEDGE_COMMAND_RESULT
{
   STB_HEDGE_REJECTED = 0,
   STB_HEDGE_EXECUTED = 1
};

bool STB_ExecuteMarketHedge(const STB_MarketHedgeRequest &request,
                            ulong &dealTicket,
                            ulong &positionTicket,
                            double &executedVolume)
{
   dealTicket=0;
   positionTicket=0;
   executedVolume=0.0;

   if(request.symbol=="" ||
      (request.direction!=1 && request.direction!=-1) ||
      request.volume<=0.0 ||
      request.sl<=0.0)
      return false;

   trade.SetExpertMagicNumber(InpMagic);
   if(!STB_ConfigureMarketFilling(request.symbol))
      return false;
   trade.SetAsyncMode(false);

   bool ok=(request.direction>0)
           ? trade.Buy(request.volume,
                       request.symbol,
                       0.0,
                       request.sl,
                       0.0,
                       "STB|HEDGE|BUY")
           : trade.Sell(request.volume,
                        request.symbol,
                        0.0,
                        request.sl,
                        0.0,
                        "STB|HEDGE|SELL");

   if(!ok)
   {
      Print("STB HEDGE EXECUTION request failed symbol=",request.symbol,
            " direction=",(request.direction>0 ? "BUY":"SELL"),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
   }

   if(!TradeRetcodePlacementSucceeded() || trade.ResultDeal()<=0)
   {
      Print("STB HEDGE EXECUTION server did not confirm market deal symbol=",
            request.symbol,
            " deal=",trade.ResultDeal(),
            " order=",trade.ResultOrder(),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
   }

   dealTicket=trade.ResultDeal();

   if(!HistoryDealSelect(dealTicket))
   {
      Print("STB HEDGE EXECUTION false-success guard symbol=",request.symbol,
            " deal=",dealTicket,
            " reason=DEAL_NOT_IN_HISTORY");
      return false;
   }

   string dealSymbol=HistoryDealGetString(dealTicket,DEAL_SYMBOL);
   long dealMagic=HistoryDealGetInteger(dealTicket,DEAL_MAGIC);
   long dealType=HistoryDealGetInteger(dealTicket,DEAL_TYPE);
   long dealEntry=HistoryDealGetInteger(dealTicket,DEAL_ENTRY);
   ulong positionId=(ulong)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   executedVolume=HistoryDealGetDouble(dealTicket,DEAL_VOLUME);

   long expectedPositionType=(request.direction>0 ?
                              POSITION_TYPE_BUY:
                              POSITION_TYPE_SELL);
   long expectedDealType=(request.direction>0 ?
                          DEAL_TYPE_BUY:
                          DEAL_TYPE_SELL);

   if(dealSymbol!=request.symbol ||
      dealMagic!=(long)InpMagic ||
      dealType!=expectedDealType ||
      (dealEntry!=DEAL_ENTRY_IN && dealEntry!=DEAL_ENTRY_INOUT) ||
      positionId==0 ||
      executedVolume<=0.0)
   {
      Print("STB HEDGE EXECUTION post-deal verification failed symbol=",
            request.symbol,
            " deal=",dealTicket,
            " magic=",dealMagic,
            " type=",dealType,
            " entry=",dealEntry,
            " positionId=",positionId,
            " volume=",DoubleToString(executedVolume,3));
      return false;
   }

   if(!STB_FindPositionTicketByIdentifier(positionId,
                                           request.symbol,
                                           expectedPositionType,
                                           (long)InpMagic,
                                           positionTicket))
   {
      Print("STB HEDGE EXECUTION false-success guard symbol=",request.symbol,
            " deal=",dealTicket,
            " positionId=",positionId,
            " reason=POSITION_NOT_VISIBLE");
      return false;
   }

   double actualVolume=PositionGetDouble(POSITION_VOLUME);

   double volumeTolerance=
      MathMax(SymbolInfoDouble(request.symbol,SYMBOL_VOLUME_MIN)*0.5,1e-9);

   if(actualVolume<=0.0 ||
      actualVolume+volumeTolerance<executedVolume)
   {
      Print("STB HEDGE EXECUTION post-position verification failed symbol=",
            request.symbol,
            " deal=",dealTicket,
            " position=",positionTicket,
            " expectedVolume=",DoubleToString(executedVolume,3),
            " actualVolume=",DoubleToString(actualVolume,3));
      return false;
   }

   Print("STB HEDGE EXECUTION CREATED symbol=",request.symbol,
         " deal=",dealTicket,
         " position=",positionTicket,
         " direction=",(request.direction>0 ? "BUY":"SELL"),
         " executedVolume=",DoubleToString(executedVolume,3));

   return true;
}

int STB_ExecutionHedgeCommand()
{
   if(!InpAllowOneClickHedge)
   {
      Print("STB HEDGE disabled by input.");
      return STB_HEDGE_REJECTED;
   }

   if(!IsHedgingAccount())
   {
      Print("STB HEDGE unavailable: account is not RETAIL_HEDGING. Current margin mode=",
            AccountInfoInteger(ACCOUNT_MARGIN_MODE));
      return STB_HEDGE_REJECTED;
   }

   string symbol=_Symbol;

   ulong sourceTicket=0;
   long sourceType=-1;
   double sourceVolume=0.0;

   // UI command may select an already-managed source position.
   // It never owns the actual market-entry operation.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      if(!IsManagedPosition(ticket))
         continue;

      sourceTicket=ticket;
      sourceType=PositionGetInteger(POSITION_TYPE);
      sourceVolume=PositionGetDouble(POSITION_VOLUME);
      break;
   }

   if(sourceTicket==0 || sourceVolume<=0.0)
   {
      Print("STB HEDGE: no managed position on ",symbol);
      return STB_HEDGE_REJECTED;
   }

   long hedgeType=(sourceType==POSITION_TYPE_BUY)
                  ? POSITION_TYPE_SELL
                  : POSITION_TYPE_BUY;

   // Prevent repeated clicks from stacking the same hedge direction.
   if(HasManagedPositionDirection(symbol,hedgeType))
   {
      Print("STB HEDGE: opposite managed position already exists on ",symbol);
      return STB_HEDGE_REJECTED;
   }

   double volume=NormalizeVolume(symbol,sourceVolume);

   if(volume<=0.0)
      return STB_HEDGE_REJECTED;

   double sl=0.0;

   if(!STB_ProtectionCalculateHedgeSL(symbol,hedgeType,sl))
   {
      Print("STB HEDGE: could not calculate a broker-valid SL on ",symbol);
      return STB_HEDGE_REJECTED;
   }

   int hedgeDirection=(hedgeType==POSITION_TYPE_BUY ? 1:-1);

   if(!STB_RiskAuthorizeMarketHedge(symbol,hedgeDirection,volume,sl))
   {
      Print("STB HEDGE rejected by centralized risk/safety gate symbol=",symbol);
      return STB_HEDGE_REJECTED;
   }

   STB_MarketHedgeRequest request;
   ZeroMemory(request);
   request.symbol=symbol;
   request.direction=hedgeDirection;
   request.volume=volume;
   request.sl=sl;

   ulong dealTicket=0;
   ulong positionTicket=0;
   double executedVolume=0.0;

   if(!STB_ExecuteMarketHedge(request,
                              dealTicket,
                              positionTicket,
                              executedVolume))
      return STB_HEDGE_REJECTED;

   // Execution ends after creation is terminal-confirmed.
   // TradeTransaction owns immediate protection and the management handoff.
   if(positionTicket==0)
      return STB_HEDGE_REJECTED;

   Print("STB HEDGE CREATED CONFIRMED symbol=",symbol,
         " sourceTicket=",sourceTicket,
         " hedgeDirection=",(hedgeType==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " requestedVolume=",DoubleToString(volume,3),
         " executedVolume=",DoubleToString(executedVolume,3),
         " deal=",dealTicket,
         " position=",positionTicket);

   return STB_HEDGE_EXECUTED;
}

//==================================================================
// STOP VALIDATION
//==================================================================

bool IsValidSLForPosition(const string symbol,
                          const long positionType,
                          const double sl)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);

   long stopsLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

   double minimumDistance=(MathMax((double)stopsLevel,(double)freezeLevel)+1.0)*point;
   if(minimumDistance<=0.0)
      minimumDistance=point;

   if(positionType==POSITION_TYPE_BUY)
   {
      if(sl<=0.0 || sl>=tick.bid)
         return false;

      if((tick.bid-sl)<minimumDistance)
         return false;

      return true;
   }

   if(positionType==POSITION_TYPE_SELL)
   {
      if(sl<=tick.ask)
         return false;

      if((sl-tick.ask)<minimumDistance)
         return false;

      return true;
   }

   return false;
}

//==================================================================
// POSITION PROFIT
//==================================================================

double PositionProfitPips(const string symbol,
                          const long positionType,
                          const double entry)
{
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return 0.0;

   if(positionType==POSITION_TYPE_BUY)
      return (tick.bid-entry)/pip;

   if(positionType==POSITION_TYPE_SELL)
      return (entry-tick.ask)/pip;

   return 0.0;
}

//==================================================================
// MODIFY POSITION
//==================================================================

bool ModifyPositionSL(const ulong ticket,const double newSL)
{
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;

   if(!IsManagedPosition(ticket))
   {
      Print("STB PositionModify owner reject ticket=",ticket);
      return false;
   }

   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double tp=PositionGetDouble(POSITION_TP);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);

   if(point<=0.0 || !IsValidSLForPosition(symbol,type,newSL))
      return false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);

   if(!trade.PositionModify(ticket,newSL,tp))
   {
      Print("STB PositionModify request failed ticket=",ticket,
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
   }

   uint ret=trade.ResultRetcode();

   if(ret!=TRADE_RETCODE_DONE &&
      ret!=TRADE_RETCODE_DONE_PARTIAL &&
      ret!=TRADE_RETCODE_NO_CHANGES &&
      ret!=TRADE_RETCODE_ORDER_CHANGED)
   {
      Print("STB PositionModify server rejected ticket=",ticket,
            " ret=",ret," ",
            trade.ResultRetcodeDescription());
      return false;
   }

   if(!PositionSelectByTicket(ticket))
   {
      Print("STB PositionModify verification failed ticket=",ticket);
      return false;
   }

   double actualSL=PositionGetDouble(POSITION_SL);
   double tolerance=MathMax(point*0.5,
                            tickSize>0.0 ? tickSize*0.5 : point*0.5);

   if(actualSL<=0.0 || MathAbs(actualSL-newSL)>tolerance)
   {
      Print("STB PositionModify NOT CONFIRMED ticket=",ticket,
            " requestedSL=",DoubleToString(newSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " actualSL=",DoubleToString(actualSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " ret=",ret);
      return false;
   }

   return true;
}

//==================================================================
// APPLY PROFIT LOCK
//==================================================================

bool ApplyProfitLock(const ulong ticket,const double lockPips)
{
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return false;

   double targetSL=0.0;

   if(type==POSITION_TYPE_BUY)
   {
      targetSL=NormalizePrice(symbol,entry+lockPips*pip);

      if(currentSL>0.0 && targetSL<=currentSL)
      {
         SetLockedPips(ticket,MathMax(GetLockedPips(ticket),lockPips));
         return true;
      }
   }

   if(type==POSITION_TYPE_SELL)
   {
      targetSL=NormalizePrice(symbol,entry-lockPips*pip);

      if(currentSL>0.0 && targetSL>=currentSL)
      {
         SetLockedPips(ticket,MathMax(GetLockedPips(ticket),lockPips));
         return true;
      }
   }

   if(!ModifyPositionSL(ticket,targetSL))
      return false;

   SetLockedPips(ticket,MathMax(GetLockedPips(ticket),lockPips));

   return true;
}

//==================================================================
// AUTO +50 -> +30
//==================================================================

void AutoProfitProtection()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !IsManagedPosition(ticket))
         continue;

      PositionSelectByTicket(ticket);

      string symbol=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);

      double profit=PositionProfitPips(symbol,type,entry);
      double locked=GetLockedPips(ticket);

      if(profit>=InpAutoTriggerPips && locked<InpAutoLockPips)
         ApplyProfitLock(ticket,InpAutoLockPips);
   }
}

//==================================================================
// MANUAL SAVE +20
//==================================================================

int STB_ManagementSavePlus20Command()
{
   int completed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !IsManagedPosition(ticket))
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);

      double profit=PositionProfitPips(symbol,type,entry);
      double currentLock=GetLockedPips(ticket);
      double requested=currentLock+InpManualSaveStepPips;

      if(profit>=requested &&
         ApplyProfitLock(ticket,requested))
         completed++;
   }

   Print("STB SAVE +20 completed positions=",
         IntegerToString(completed));

   return completed;
}


//==================================================================
// M15 CLOSED-CANDLE TRAILING
//==================================================================

bool TrailPositionOnClosedCandle(const ulong ticket)
{
   // Trailing is intentionally disabled until the position reaches
   // +InpTrailStartPips profit. Before that point the +50 -> +30
   // profit lock is the only automatic SL movement.
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   double profit=PositionProfitPips(symbol,type,entry);

   if(profit < InpTrailStartPips)
      return false;

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return false;

   // Use the 5th CLOSED candle on the configured trailing timeframe.
   // Shift 1 = latest closed candle, therefore shift 5 is the fifth
   // closed candle and never the still-forming candle.
   int shift=MathMax(1,InpTrailCandleShift);
   datetime closedBar=iTime(symbol,InpTrailTF,shift);

   if(closedBar==0)
      return false;

   string key=ScopedStateName("TRAIL_"+(string)ticket);
   datetime lastDone=0;

   if(GlobalVariableCheck(key))
      lastDone=(datetime)GlobalVariableGet(key);

   if(lastDone==closedBar)
      return false;

   double candidate=0.0;
   double buffer=InpTrailBufferPips*pip;
   double locked=GetLockedPips(ticket);

   if(type==POSITION_TYPE_BUY)
   {
      double candleLow=iLow(symbol,InpTrailTF,shift);

      if(candleLow<=0.0)
         return false;

      // BUY: SL goes immediately below the LOW of candle 5.
      candidate=NormalizePrice(symbol,candleLow-buffer);

      // Never give back an already locked profit level.
      if(locked>0.0)
      {
         double lockSL=entry+locked*pip;
         candidate=MathMax(candidate,NormalizePrice(symbol,lockSL));
      }

      // Trailing may only move the SL upward.
      if(currentSL>0.0 && candidate<=currentSL)
      {
         GlobalVariableSet(key,(double)closedBar);
         return false;
      }
   }
   else if(type==POSITION_TYPE_SELL)
   {
      double candleHigh=iHigh(symbol,InpTrailTF,shift);

      if(candleHigh<=0.0)
         return false;

      // SELL: SL goes immediately above the HIGH of candle 5.
      candidate=NormalizePrice(symbol,candleHigh+buffer);

      // Never give back an already locked profit level.
      if(locked>0.0)
      {
         double lockSL=entry-locked*pip;
         candidate=MathMin(candidate,NormalizePrice(symbol,lockSL));
      }

      // Trailing may only move the SL downward.
      if(currentSL>0.0 && candidate>=currentSL)
      {
         GlobalVariableSet(key,(double)closedBar);
         return false;
      }
   }
   else
      return false;

   if(!IsValidSLForPosition(symbol,type,candidate))
      return false;

   bool result=ModifyPositionSL(ticket,candidate);

   if(result)
   {
      GlobalVariableSet(key,(double)closedBar);

      Print("STB TRAILING updated ticket=",ticket,
            " symbol=",symbol,
            " type=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " profitPips=",DoubleToString(profit,1),
            " candleShift=",shift,
            " candleTime=",TimeToString(closedBar),
            " SL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   }

   return result;
}

//==================================================================
// PROTECTION SERVICE — structural/fallback SL calculation
//==================================================================

bool STB_ProtectionCalculateNearestStructuralSL(const string symbol,
                                  const long direction,
                                  const double referencePrice,
                                  double &sl)
{
   sl=0.0;

   SwingPoint highs[];
   SwingPoint lows[];

   if(CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double pip=PipSize(symbol);
   double minDist=TradeMinDistance(symbol);
   if(pip<=0.0 || minDist<=0.0 || referencePrice<=0.0)
      return false;

   double buffer=MathMax(0.0,InpInitialSLBufferPips)*pip;

   // Choose the CLOSEST confirmed swing on the correct side of entry.
   // If that swing is too close for the broker's stop/freeze rules,
   // continue to the next closest eligible swing rather than creating
   // an unnecessarily large SL.
   if(direction==POSITION_TYPE_BUY)
   {
      double best=-DBL_MAX;
      double maxAllowed=MathMin(referencePrice-minDist,tick.bid-minDist);

      for(int i=0;i<ArraySize(lows);i++)
      {
         double candidate=lows[i].price-buffer;
         if(lows[i].price>=referencePrice)
            continue;
         if(candidate>=maxAllowed)
            continue;

         if(lows[i].price>best)
         {
            best=lows[i].price;
            sl=candidate;
         }
      }
   }
   else if(direction==POSITION_TYPE_SELL)
   {
      double best=DBL_MAX;
      double minAllowed=MathMax(referencePrice+minDist,tick.ask+minDist);

      for(int i=0;i<ArraySize(highs);i++)
      {
         double candidate=highs[i].price+buffer;
         if(highs[i].price<=referencePrice)
            continue;
         if(candidate<=minAllowed)
            continue;

         if(highs[i].price<best)
         {
            best=highs[i].price;
            sl=candidate;
         }
      }
   }
   else
      return false;

   if(sl<=0.0)
      return false;

   sl=NormalizePrice(symbol,sl);
   return true;
}

double STB_ProtectionCalculateFallbackSL(const string symbol,
                          const long positionType,
                          const double entryPrice)
{
   if(symbol=="" || entryPrice<=0.0)
      return 0.0;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   double pip=PipSize(symbol);
   double minDist=TradeMinDistance(symbol);

   if(pip<=0.0 || minDist<=0.0)
      return 0.0;

   double emergencyPips=MathMax(1.0,InpEmergencySLPips);
   double sl=0.0;

   if(positionType==POSITION_TYPE_BUY)
      sl=MathMin(entryPrice-emergencyPips*pip,tick.bid-minDist);
   else if(positionType==POSITION_TYPE_SELL)
      sl=MathMax(entryPrice+emergencyPips*pip,tick.ask+minDist);
   else
      return 0.0;

   sl=NormalizePrice(symbol,sl);

   if(!IsValidSLForPosition(symbol,positionType,sl))
      return 0.0;

   return sl;
}

double STB_ProtectionCalculateInitialSL(const string symbol,
                         const long positionType,
                         const double entryPrice)
{
   double sl=0.0;

   if(STB_ProtectionCalculateNearestStructuralSL(symbol,positionType,entryPrice,sl) &&
      IsValidSLForPosition(symbol,positionType,sl))
      return sl;

   return STB_ProtectionCalculateFallbackSL(symbol,positionType,entryPrice);
}

bool EnsureInitialSL(const ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;

   if(!IsManagedPosition(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   if(currentSL>0.0)
      return true;

   double candidate=0.0;
   bool structuralOK=
      STB_ProtectionCalculateNearestStructuralSL(symbol,type,entry,candidate) &&
      IsValidSLForPosition(symbol,type,candidate);

   if(!structuralOK)
   {
      candidate=STB_ProtectionCalculateFallbackSL(symbol,type,entry);

      if(candidate<=0.0)
      {
         Print("STB initial SL FAILED: structural and fallback unavailable",
               " ticket=",ticket,
               " symbol=",symbol,
               " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"));
         return false;
      }

      Print("STB initial SL FALLBACK ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " fallbackPips=",DoubleToString(InpEmergencySLPips,1),
            " SL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   }

   if(!ModifyPositionSL(ticket,candidate))
   {
      Print("STB initial SL NOT CONFIRMED ticket=",ticket,
            " symbol=",symbol,
            " requested=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
   }

   Print("STB initial SL set and CONFIRMED ticket=",ticket,
         " symbol=",symbol,
         " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " source=",(structuralOK ? "STRUCTURAL":"FALLBACK"),
         " SL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));

   return true;
}

bool EnsureInitialSLForPendingOrder(const ulong ticket)
{
   if(ticket==0 || !OrderSelect(ticket))
      return false;

   if(!IsManagedOrder(ticket))
      return false;

   double currentSL=OrderGetDouble(ORDER_SL);
   if(currentSL>0.0)
      return true;

   string symbol=OrderGetString(ORDER_SYMBOL);
   long orderType=OrderGetInteger(ORDER_TYPE);
   double entry=OrderGetDouble(ORDER_PRICE_OPEN);

   long direction=-1;
   if(orderType==ORDER_TYPE_BUY_LIMIT || orderType==ORDER_TYPE_BUY_STOP ||
      orderType==ORDER_TYPE_BUY_STOP_LIMIT)
      direction=POSITION_TYPE_BUY;
   else if(orderType==ORDER_TYPE_SELL_LIMIT || orderType==ORDER_TYPE_SELL_STOP ||
           orderType==ORDER_TYPE_SELL_STOP_LIMIT)
      direction=POSITION_TYPE_SELL;
   else
      return false;

   double candidate=0.0;
   if(!STB_ProtectionCalculateNearestStructuralSL(symbol,direction,entry,candidate))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double minDist=TradeMinDistance(symbol);
   if(direction==POSITION_TYPE_BUY)
   {
      double maxSL=MathMin(entry-minDist,tick.bid-minDist);
      if(candidate>=maxSL)
         return false;
   }
   else
   {
      double minSL=MathMax(entry+minDist,tick.ask+minDist);
      if(candidate<=minSL)
         return false;
   }

   candidate=NormalizePrice(symbol,candidate);

   ENUM_ORDER_TYPE_TIME typeTime=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   double stopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);
   double price=OrderGetDouble(ORDER_PRICE_OPEN);
   double tp=OrderGetDouble(ORDER_TP);

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);

   if(!trade.OrderModify(ticket,price,candidate,tp,typeTime,expiration,stopLimit))
   {
      Print("STB pending initial SL request failed ticket=",ticket,
            " symbol=",symbol,
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
   }

   if(!TradeRetcodeModifySucceeded())
   {
      Print("STB pending initial SL server rejected ticket=",ticket,
            " symbol=",symbol,
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
   }

   if(!OrderSelect(ticket))
   {
      Print("STB pending initial SL verification failed ticket=",ticket,
            " symbol=",symbol,
            " reason=ORDER_NOT_VISIBLE");
      return false;
   }

   double actualSL=OrderGetDouble(ORDER_SL);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tolerance=MathMax(point*0.5,
                            tickSize>0.0 ? tickSize*0.5 : point*0.5);

   if(actualSL<=0.0 || MathAbs(actualSL-candidate)>tolerance)
   {
      Print("STB pending initial SL NOT CONFIRMED ticket=",ticket,
            " symbol=",symbol,
            " requested=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " actual=",DoubleToString(actualSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
   }

   Print("STB pending initial SL set and CONFIRMED ticket=",ticket,
         " symbol=",symbol,
         " side=",(direction==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " nearestSwingBufferPips=",DoubleToString(InpInitialSLBufferPips,1),
         " SL=",DoubleToString(actualSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));

   return true;
}


// MANAGEMENT OWNER CONTRACT:
// Existing positions only. No watchlist scanning or opportunity discovery.
// Structural SL calculation is delegated to STB_Protection* services.
void ManagePositions()
{
   // First pass: immediately protect every managed position that has no SL.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !IsManagedPosition(ticket))
         continue;

      EnsureInitialSL(ticket);
   }

   AutoProfitProtection();

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0)
         continue;

      if(!IsManagedPosition(ticket))
         continue;

      TrailPositionOnClosedCandle(ticket);
   }
}

//==================================================================
// PENDING ORDER MANAGEMENT
//==================================================================

// PENDING MANAGEMENT OWNER CONTRACT:
// Existing pending orders only. No scanner access and no fresh-entry discovery.
void ManagePendingOrders()
{
   datetime now=TimeCurrent();

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      // Manual/EA pending orders without SL are protected immediately.
      // The order remains unchanged except for the automatically selected SL.
      if(OrderGetDouble(ORDER_SL)<=0.0)
         EnsureInitialSLForPendingOrder(ticket);

      long magic=OrderGetInteger(ORDER_MAGIC);
      string symbol=OrderGetString(ORDER_SYMBOL);
      datetime setupTime=(datetime)OrderGetInteger(ORDER_TIME_SETUP);

      if(magic==(long)InpMagic)
      {
         int maxBars=STB_ParsePendingMaxBars(
            OrderGetString(ORDER_COMMENT),
            InpMaxPendingBars);

         bool expiredByServer=
            OrderGetInteger(ORDER_TYPE_TIME)==ORDER_TIME_SPECIFIED &&
            OrderGetInteger(ORDER_TIME_EXPIRATION)>0 &&
            now>=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);

         bool expiredByLocalAge=
            maxBars>0 &&
            setupTime>0 &&
            now-setupTime>=maxBars*15*60;

         if(expiredByServer || expiredByLocalAge)
         {
            Print("STB PENDING EXPIRE ticket=",ticket,
                  " symbol=",symbol,
                  " maxBars=",IntegerToString(maxBars),
                  " serverExpired=",expiredByServer ? "YES":"NO",
                  " localExpired=",expiredByLocalAge ? "YES":"NO");

            if(!trade.OrderDelete(ticket))
            {
               Print("STB pending delete failed ticket=",ticket,
                     " ret=",trade.ResultRetcode()," ",
                     trade.ResultRetcodeDescription());
            }
            else if(!TradeRetcodeDeleteSucceeded())
            {
               Print("STB pending delete server rejected ticket=",ticket,
                     " ret=",trade.ResultRetcode()," ",
                     trade.ResultRetcodeDescription());
            }
            else if(OrderSelect(ticket))
            {
               Print("STB pending delete NOT CONFIRMED ticket=",ticket,
                     " symbol=",symbol,
                     " ret=",trade.ResultRetcode(),
                     " reason=ORDER_STILL_VISIBLE");
            }
            else
            {
               Print("STB pending delete CONFIRMED ticket=",ticket,
                     " symbol=",symbol,
                     " ret=",trade.ResultRetcode());
               // TradeTransaction owns Adaptive order-state cleanup.
            }
         }
      }
   }
}

//==================================================================
// AUTO ORDER
//==================================================================

double DirectionExposureVolume(const string symbol,const int direction)
{
   double total=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      long type=PositionGetInteger(POSITION_TYPE);
      if((direction>0 && type==POSITION_TYPE_BUY) ||
         (direction<0 && type==POSITION_TYPE_SELL))
         total+=PositionGetDouble(POSITION_VOLUME);
   }

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;

      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      bool sameDirection=
         (direction>0 &&
          (type==ORDER_TYPE_BUY_LIMIT ||
           type==ORDER_TYPE_BUY_STOP ||
           type==ORDER_TYPE_BUY_STOP_LIMIT)) ||
         (direction<0 &&
          (type==ORDER_TYPE_SELL_LIMIT ||
           type==ORDER_TYPE_SELL_STOP ||
           type==ORDER_TYPE_SELL_STOP_LIMIT));

      if(sameDirection)
         total+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }

   return total;
}

// PENDING-GEOMETRY diagnostic (PHASE 13): logs the exact rejected
// condition with real values. Read-only; never changes behavior.
void STB_PendingGeometryDiagnose(const Setup &s)
{
   MqlTick tick;
   if(!SymbolInfoTick(s.symbol,tick))
      return;

   double point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   double minDist=TradeMinDistance(s.symbol);
   int digits=(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS);
   long stops=(long)SymbolInfoInteger(s.symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freeze=(long)SymbolInfoInteger(s.symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double tickSize=SymbolInfoDouble(s.symbol,SYMBOL_TRADE_TICK_SIZE);

   string reason="UNKNOWN";

   if(s.direction>0)
   {
      if(s.entry<tick.ask+minDist)      reason="GEOMETRY_ENTRY_DISTANCE";
      else if(s.sl>s.entry-minDist)     reason="GEOMETRY_SL_DISTANCE";
      else if(s.tp<s.entry+minDist)     reason="GEOMETRY_TP_DISTANCE";
      else reason="GEOMETRY_OK_STRICT_ONLY";
   }
   else
   {
      if(s.entry>tick.bid-minDist)      reason="GEOMETRY_ENTRY_DISTANCE";
      else if(s.sl<s.entry+minDist)     reason="GEOMETRY_SL_DISTANCE";
      else if(s.tp>s.entry-minDist)     reason="GEOMETRY_TP_DISTANCE";
      else reason="GEOMETRY_OK_STRICT_ONLY";
   }

   Print("STB_PENDING_GEOMETRY_CHECK symbol=",s.symbol,
         " direction=",(s.direction>0 ? "BUY_STOP":"SELL_STOP"),
         " bid=",DoubleToString(tick.bid,digits),
         " ask=",DoubleToString(tick.ask,digits),
         " entry=",DoubleToString(s.entry,digits),
         " sl=",DoubleToString(s.sl,digits),
         " tp=",DoubleToString(s.tp,digits),
         " stopsLevel=",IntegerToString((int)stops),
         " freezeLevel=",IntegerToString((int)freeze),
         " tickSize=",DoubleToString(tickSize,digits),
         " point=",DoubleToString(point,digits),
         " minDist=",DoubleToString(minDist,digits),
         " reason=",reason," RESULT=FAIL");
}

bool ValidatePendingSetup(const Setup &s)
{
   MqlTick tick;
   if(!SymbolInfoTick(s.symbol,tick))
      return false;

   double point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   double minDist=TradeMinDistance(s.symbol);

   if(point<=0.0 || minDist<=0.0)
      return false;

   // Sub-tick race slack. TradeMinDistance already adds a full +1 point
   // margin above the raw stops/freeze level, so a half-point tolerance
   // can never admit a price inside the broker zone.
   double tolerance=point*0.5;
      // (return handled above)

   if(s.direction>0)
      return s.entry>=tick.ask+minDist-tolerance &&
             s.sl<=s.entry-minDist+tolerance &&
             s.tp>=s.entry+minDist-tolerance;
   
   return s.entry<=tick.bid-minDist+tolerance &&
          s.sl>=s.entry+minDist-tolerance &&
          s.tp<=s.entry-minDist+tolerance;
}

bool CheckPendingOrder(const Setup &s,
                       const double volume,
                       const ENUM_ORDER_TYPE_TIME typeTime,
                       const datetime expiration)
{
   MqlTradeRequest request={};
   MqlTradeCheckResult check={};

   request.action=TRADE_ACTION_PENDING;
   request.symbol=s.symbol;
   request.magic=InpMagic;
   request.volume=volume;
   request.type=(s.direction>0 ? ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP);
   request.price=s.entry;
   request.sl=s.sl;
   request.tp=s.tp;
   request.type_filling=ORDER_FILLING_RETURN;
   request.type_time=typeTime;
   request.expiration=expiration;
   request.comment="STB";

   ResetLastError();

   if(!OrderCheck(request,check))
   {
      Print("STB OrderCheck call failed symbol=",s.symbol,
            " err=",GetLastError(),
            " ret=",check.retcode," ",check.comment);
      return false;
   }

   if(check.retcode!=TRADE_RETCODE_DONE &&
      check.retcode!=TRADE_RETCODE_NO_CHANGES &&
      check.retcode!=TRADE_RETCODE_PLACED &&
      !(check.retcode==0 && check.comment=="Done"))
   {
      Print("STB OrderCheck rejected symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " ret=",check.retcode,
            " comment=",check.comment);
      return false;
   }

   return true;
}

bool GetPendingLifetime(const string symbol,
                         const int maxPendingBars,
                         ENUM_ORDER_TYPE_TIME &typeTime,
                         datetime &expiration)
{
   typeTime=ORDER_TIME_GTC;
   expiration=0;

   int modes=(int)SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);

   int effectiveBars=MathMax(0,maxPendingBars);

   if(effectiveBars<=0)
   {
      if((modes & SYMBOL_EXPIRATION_GTC)==SYMBOL_EXPIRATION_GTC)
         return true;
      if((modes & SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
      {
         typeTime=ORDER_TIME_DAY;
         return true;
      }
      if((modes & SYMBOL_EXPIRATION_SPECIFIED_DAY)==SYMBOL_EXPIRATION_SPECIFIED_DAY)
      {
         typeTime=ORDER_TIME_SPECIFIED_DAY;
         MqlDateTime dt;
         TimeToStruct(TimeTradeServer(),dt);
         dt.hour=23; dt.min=59; dt.sec=59;
         expiration=StructToTime(dt);
         return expiration>TimeTradeServer();
      }
      return false;
   }

   datetime target=TimeTradeServer()+(datetime)effectiveBars*15*60;

   if((modes & SYMBOL_EXPIRATION_SPECIFIED)==SYMBOL_EXPIRATION_SPECIFIED)
   {
      typeTime=ORDER_TIME_SPECIFIED;
      expiration=target;
      return expiration>TimeTradeServer();
   }

   if((modes & SYMBOL_EXPIRATION_SPECIFIED_DAY)==SYMBOL_EXPIRATION_SPECIFIED_DAY)
   {
      typeTime=ORDER_TIME_SPECIFIED_DAY;

      MqlDateTime dt;
      TimeToStruct(target,dt);
      dt.hour=23; dt.min=59; dt.sec=59;
      expiration=StructToTime(dt);

      return expiration>TimeTradeServer();
   }

   if((modes & SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
   {
      typeTime=ORDER_TIME_DAY;
      expiration=0;
      return true;
   }

   if((modes & SYMBOL_EXPIRATION_GTC)==SYMBOL_EXPIRATION_GTC)
   {
      typeTime=ORDER_TIME_GTC;
      expiration=0;
      return true;
   }

   return false;
}

double CalculateOrderVolumeByRisk(const Setup &s)
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!InpUseRiskSizing || equity<=0.0 || InpRiskPercent<=0.0)
      return 0.0;

   ENUM_ORDER_TYPE orderType=(s.direction>0 ? ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double riskMoney=equity*(InpRiskPercent/100.0);

   double lossForOneLot=0.0;
   ResetLastError();

   if(!OrderCalcProfit(orderType,s.symbol,1.0,s.entry,s.sl,lossForOneLot))
   {
      Print("STB risk sizing failed OrderCalcProfit symbol=",s.symbol,
            " err=",GetLastError());
      return 0.0;
   }

   lossForOneLot=MathAbs(lossForOneLot);
   if(lossForOneLot<=0.0 || !MathIsValidNumber(lossForOneLot))
      return 0.0;

   double raw=riskMoney/lossForOneLot;
   double minLot=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_MIN);

   if(raw<minLot)
   {
      // The broker minimum would exceed the requested account risk.
      // Refuse the setup instead of silently oversizing the trade.
      return 0.0;
   }

   if(InpMaxRiskVolume>0.0)
      raw=MathMin(raw,InpMaxRiskVolume);

   double volume=NormalizeVolume(s.symbol,raw);

   if(volume<=0.0)
      return 0.0;

   return volume;
}

//==================================================================
// SAFE-INTEGRATION PENDING SERVICES (NOT EAs, NOT a 2nd adaptive engine)
//==================================================================
#include <STB\STB_OrderCheckDiagnose.mqh>
#include <STB\STB_PendingDistanceResolver.mqh>
#include <STB\STB_PendingTrail.mqh>

bool STB_LogPlaceReject(const Setup &s,const string reason)
{
   if(!s.valid)
      return false;

   Print("STB_PIPELINE_REJECT stage=PLACE symbol=",s.symbol,
         " direction=",(s.direction>0 ? "BUY":"SELL"),
         " reason=",reason,
         " profile=",IntegerToString(s.adaptiveProfile),
         " score=",DoubleToString(s.score,1),
         " rr=",DoubleToString(s.rr,2));

   Print("STB PLACE REJECT symbol=",s.symbol,
         " dir=",(s.direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(s.adaptiveProfile),
         " reason=",reason,
         " score=",DoubleToString(s.score,1),
         " RR=",DoubleToString(s.rr,2));

   return false;
}


bool STB_RiskAuthorizePending(Setup &s,
                               const bool manual,
                               double &volume,
                               ENUM_ORDER_TYPE_TIME &typeTime,
                               datetime &expiration,
                               int &pendingMaxBars,
                               double &entryBufferPips,
                               double &slBufferPips)
{
   volume=0.0;
   typeTime=ORDER_TIME_GTC;
   expiration=0;
   pendingMaxBars=MathMax(0,s.pendingMaxBars);
   entryBufferPips=MathMax(0.0,s.entryBufferPips);
   slBufferPips=MathMax(0.0,s.slBufferPips);

   if(!s.valid)
      return STB_LogPlaceReject(s,"INVALID_CANDIDATE");

   if(!manual &&
      (!InpAutoTrading || InpDiagnosticM15Mode || !g_autoTrading))
      return STB_LogPlaceReject(s,"AUTO_TRADING_LOCKED");
   if(!IsDirectionTradable(s.symbol,s.direction))
      return STB_LogPlaceReject(s,"DIRECTION_NOT_TRADABLE");
   if(!IsSpreadAcceptable(s.symbol))
      return STB_LogPlaceReject(s,"SPREAD_FILTER");
   if(STB_HasExecutionExposure(s.symbol))
      return STB_LogPlaceReject(s,"MANAGED_EXPOSURE_EXISTS");
   if(!STB_TradeEnvironmentAllowed())
      return STB_LogPlaceReject(s,"TRADE_PERMISSION");

   long maxOrders=AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   if(maxOrders>0 && OrdersTotal()>=maxOrders)
      return STB_LogPlaceReject(s,"ACCOUNT_ORDER_LIMIT");

   bool normalized=PreparePendingSetup(s);

   if(!normalized)
      return STB_LogPlaceReject(s,"BROKER_STOP_NORMALIZATION_FAILED");

   if(!ValidatePendingSetup(s))
   {
      STB_PendingGeometryDiagnose(s);
      return STB_LogPlaceReject(s,"PENDING_GEOMETRY_INVALID");
   }

   datetime lastSetup=GetLastSetupTime(s.symbol,s.direction);
   if(lastSetup==s.setupTime)
      return STB_LogPlaceReject(s,"SETUP_ALREADY_PLACED");

   if(InpSetupCooldownMinutes>0 && lastSetup>0 &&
      TimeCurrent()-(datetime)lastSetup<InpSetupCooldownMinutes*60)
      return STB_LogPlaceReject(s,"SETUP_COOLDOWN");

   if(InpUseRiskSizing)
      volume=CalculateOrderVolumeByRisk(s);
   else
      volume=NormalizeVolume(s.symbol,
                             InpBaseLots*(s.trendAligned ?
                             InpTrendLotMultiplier:
                             InpUniversalLotMultiplier));

   if(volume<=0.0)
      return STB_LogPlaceReject(s,
                                InpUseRiskSizing ?
                                "RISK_VOLUME_INVALID":
                                "FIXED_VOLUME_INVALID");

   double volumeLimit=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_LIMIT);
   if(volumeLimit>0.0 &&
      DirectionExposureVolume(s.symbol,s.direction)+volume>
      volumeLimit+1e-9)
      return STB_LogPlaceReject(s,"VOLUME_LIMIT");

   bool lifetimeOK=GetPendingLifetime(s.symbol,
                                   pendingMaxBars,
                                   typeTime,
                                   expiration);

   if(!lifetimeOK)
      return STB_LogPlaceReject(s,"PENDING_EXPIRATION_UNSUPPORTED");

   if(!STB_OrderCheckDiagnoseAndCheck(s,volume,typeTime,expiration))
      return STB_LogPlaceReject(s,"ORDERCHECK_REJECT");

   return true;
}

// EXECUTION OWNER CONTRACT:
// Creates NEW pending exposure only. It does not discover candidates.
bool ExecuteSetup(Setup &s,const bool manual)
{
   if(!s.valid)
      return false;

   double volume=0.0;
   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;
   int pendingMaxBars=MathMax(0,s.pendingMaxBars);
   double entryBufferPips=MathMax(0.0,s.entryBufferPips);
   double slBufferPips=MathMax(0.0,s.slBufferPips);

   if(!STB_RiskAuthorizePending(s,manual,volume,typeTime,expiration,
                                pendingMaxBars,entryBufferPips,slBufferPips))
      return false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(false);

   string comment="STB|"+(s.direction>0 ? "B":"S");
   if(s.adaptiveProfile>=0 &&
      s.adaptiveProfile<STB_ADAPTIVE_PROFILE_COUNT)
      comment+="|P"+IntegerToString(s.adaptiveProfile);
   else
      comment+="|M";

   comment+="|T"+(string)s.setupTime+
            "|L"+IntegerToString(pendingMaxBars)+
            "|EB"+DoubleToString(entryBufferPips,8)+
            "|SB"+DoubleToString(slBufferPips,8);

   bool ok=(s.direction>0)
           ? trade.BuyStop(volume,s.entry,s.symbol,s.sl,s.tp,typeTime,expiration,comment)
           : trade.SellStop(volume,s.entry,s.symbol,s.sl,s.tp,typeTime,expiration,comment);

   if(!ok)
   {
      Print("STB EXECUTION request failed symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY_STOP":"SELL_STOP"),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return STB_LogPlaceReject(s,"PLACEMENT_REQUEST_REJECTED");
   }

   if(!TradeRetcodePlacementSucceeded())
   {
      Print("STB EXECUTION server rejected symbol=",s.symbol,
            " order=",IntegerToString((int)trade.ResultOrder()),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return STB_LogPlaceReject(s,"PLACEMENT_RETCODE_REJECT");
   }

   ulong placedOrder=trade.ResultOrder();

   // A placement retcode alone is not enough: verify that the terminal
   // exposes the actual pending order with the expected ownership/geometry.
   if(placedOrder==0 || !OrderSelect(placedOrder))
   {
      Print("STB EXECUTION false-success guard symbol=",s.symbol,
            " resultOrder=",IntegerToString((int)placedOrder),
            " ret=",trade.ResultRetcode(),
            " reason=ORDER_NOT_VISIBLE");
      return STB_LogPlaceReject(s,"PLACEMENT_NO_CONFIRMED_ORDER");
   }

   long expectedType=(s.direction>0 ?
                      ORDER_TYPE_BUY_STOP:
                      ORDER_TYPE_SELL_STOP);

   if(OrderGetInteger(ORDER_MAGIC)!=(long)InpMagic ||
      OrderGetString(ORDER_SYMBOL)!=s.symbol ||
      OrderGetInteger(ORDER_TYPE)!=expectedType ||
      OrderGetDouble(ORDER_SL)<=0.0 ||
      OrderGetDouble(ORDER_TP)<=0.0)
   {
      Print("STB EXECUTION post-placement verification failed symbol=",s.symbol,
            " order=",IntegerToString((int)placedOrder),
            " magic=",OrderGetInteger(ORDER_MAGIC),
            " type=",OrderGetInteger(ORDER_TYPE),
            " sl=",DoubleToString(OrderGetDouble(ORDER_SL),
                                  (int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
            " tp=",DoubleToString(OrderGetDouble(ORDER_TP),
                                  (int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)));
      return STB_LogPlaceReject(s,"PLACEMENT_POST_VERIFY_FAILED");
   }

   // Execution has finished after terminal verification.
   // Persistence and PendingTrail registration are owned by TradeTransaction.

   Print("STB ORDER CREATED symbol=",s.symbol,
         " owner=EXECUTION order=",IntegerToString((int)placedOrder));
   return true;
}


//--- Manual BUY STOP / SELL STOP request -> Execution -------------
// UI provides only symbol + direction. Request construction belongs to the
// Execution request coordinator; actual creation remains ExecuteSetup().
bool STB_ExecutionManualPendingCommand(const string symbol,const int direction)
{
   if(symbol=="" || direction==0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double extreme=(direction>0)
                  ? iLow(symbol,PERIOD_M15,0)
                  : iHigh(symbol,PERIOD_M15,0);
   if(extreme<=0.0)
      return false;

   STBPendingResolution res;
   if(!STB_ResolvePendingDistance(symbol,
                                   direction,
                                   extreme,
                                   InpEntryBufferPips,
                                   res,
                                   InpSLBufferPips) ||
      !res.valid)
      return false;

   double risk=MathAbs(res.entry-res.sl);
   double reward=MathMax(risk*MathMax(0.10,InpMinimumRR),
                          TradeMinDistance(symbol));
   if(risk<=0.0 || reward<=0.0)
      return false;

   Setup s;
   ZeroMemory(s);
   s.valid=true;
   s.symbol=symbol;
   s.direction=direction;
   s.trendAligned=false;
   s.entry=res.entry;
   s.sl=res.sl;
   s.tp=NormalizePrice(symbol,
                       direction>0 ? res.entry+reward :
                                      res.entry-reward);
   s.rr=MathAbs(s.tp-s.entry)/risk;
   s.score=0.0;
   s.adaptiveProfile=-1;
   s.pendingMaxBars=MathMax(0,InpMaxPendingBars);
   s.entryBufferPips=MathMax(0.0,InpEntryBufferPips);
   s.slBufferPips=MathMax(0.0,InpSLBufferPips);
   s.minimumRR=MathMax(0.0,InpMinimumRR);
   s.setupTime=iTime(symbol,PERIOD_M15,0);

   return ExecuteSetup(s,true);
}

//==================================================================
// WATCHLIST SCANNER
//==================================================================



bool STB_IsDuplicateSymbol(const string &symbols[],
                           const int count,
                           const string symbol)
{
   for(int i=0;i<count;i++)
      if(symbols[i]==symbol)
         return true;

   return false;
}

int STB_BuildScannerUniverse(string &symbols[])
{
   ArrayResize(symbols,0);

   string configured=InpScannerSymbols;
   StringReplace(configured,";",",");

   if(StringLen(configured)>0)
   {
      string parts[];
      ushort separator=StringGetCharacter(",",0);
      int n=StringSplit(configured,separator,parts);

      if(n>0)
      {
         for(int i=0;i<n;i++)
         {
            string symbol=parts[i];
            StringTrimLeft(symbol);
            StringTrimRight(symbol);

            if(symbol=="" || STB_IsDuplicateSymbol(symbols,ArraySize(symbols),symbol))
               continue;

            bool isCustom=false;

            if(!SymbolExist(symbol,isCustom))
            {
               Print("STB SCANNER symbol not found on server: ",symbol);
               continue;
            }

            ResetLastError();

            if(!SymbolSelect(symbol,true))
            {
               Print("STB SCANNER SymbolSelect failed symbol=",symbol,
                     " err=",GetLastError());
               continue;
            }

            int m=ArraySize(symbols);
            ArrayResize(symbols,m+1);
            symbols[m]=symbol;
         }
      }
   }

   // Empty configuration keeps the EA aligned with the user's Market Watch.
   if(ArraySize(symbols)==0)
   {
      int total=SymbolsTotal(true);

      for(int i=0;i<total;i++)
      {
         string symbol=SymbolName(i,true);

         if(symbol=="" ||
            STB_IsDuplicateSymbol(symbols,ArraySize(symbols),symbol))
            continue;

         int m=ArraySize(symbols);
         ArrayResize(symbols,m+1);
         symbols[m]=symbol;
      }
   }

   // Defensive tester/live fallback: the chart symbol must always be scanned.
   if(_Symbol!="" &&
      !STB_IsDuplicateSymbol(symbols,ArraySize(symbols),_Symbol))
   {
      if(SymbolSelect(_Symbol,true))
      {
         int m=ArraySize(symbols);
         ArrayResize(symbols,m+1);
         symbols[m]=_Symbol;
      }
   }

   return ArraySize(symbols);
}


/* SCANNER OWNER CONTRACT:
   Candidate discovery only. No order creation or position management. */
int ScanWatchlist(Setup &candidates[])
{
   ArrayResize(candidates,0);

   string symbols[];
   int total=STB_BuildScannerUniverse(symbols);
   int tradable=0;
   int buyReady=0;
   int sellReady=0;

   for(int i=0;i<total;i++)
   {
      string symbol=symbols[i];
      if(symbol=="" || !IsSymbolTradable(symbol))
         continue;

      tradable++;

      Setup buySetup;
      Setup sellSetup;
      bool buyOK=BuildSetup(symbol,1,buySetup);
      bool sellOK=BuildSetup(symbol,-1,sellSetup);

      if(buyOK)
      {
         int n=ArraySize(candidates);
         ArrayResize(candidates,n+1);
         candidates[n]=buySetup;
         buyReady++;
      }

      if(sellOK)
      {
         int n=ArraySize(candidates);
         ArrayResize(candidates,n+1);
         candidates[n]=sellSetup;
         sellReady++;
      }
   }

   Print("STB SCAN SUMMARY symbols=",IntegerToString(total),
         " tradable=",IntegerToString(tradable),
         " buyReady=",IntegerToString(buyReady),
         " sellReady=",IntegerToString(sellReady),
         " candidates=",IntegerToString(ArraySize(candidates)),
         " owner=SCANNER execution=DEFERRED");

   return ArraySize(candidates);
}

int STB_FindCandidateIndex(const Setup &candidates[],
                           const int count,
                           const string symbol,
                           const int direction)
{
   int best=-1;
   for(int i=0;i<count;i++)
   {
      if(!candidates[i].valid ||
         candidates[i].symbol!=symbol ||
         candidates[i].direction!=direction)
         continue;

      if(best<0 || candidates[i].score>candidates[best].score)
         best=i;
   }
   return best;
}

bool STB_MarkExecutionSymbol(string &processedSymbols[],
                             const string symbol)
{
   for(int i=0;i<ArraySize(processedSymbols);i++)
      if(processedSymbols[i]==symbol)
         return false;

   int n=ArraySize(processedSymbols);
   ArrayResize(processedSymbols,n+1);
   processedSymbols[n]=symbol;
   return true;
}

int STB_ProcessExecutionCandidates(Setup &candidates[])
{
   if(!g_autoTrading || ArraySize(candidates)<=0)
      return 0;

   string processedSymbols[];
   int placements=0;

   for(int i=0;i<ArraySize(candidates);i++)
   {
      string symbol=candidates[i].symbol;

      if(symbol=="" ||
         !STB_MarkExecutionSymbol(processedSymbols,symbol))
         continue;

      if(STB_HasExecutionExposure(symbol))
         continue;

      int buyIndex=STB_FindCandidateIndex(candidates,ArraySize(candidates),symbol,1);
      int sellIndex=STB_FindCandidateIndex(candidates,ArraySize(candidates),symbol,-1);
      int chosen=-1;

      if(buyIndex>=0 && sellIndex>=0)
      {
         if(candidates[buyIndex].trendAligned &&
            !candidates[sellIndex].trendAligned)
            chosen=buyIndex;
         else if(candidates[sellIndex].trendAligned &&
                 !candidates[buyIndex].trendAligned)
            chosen=sellIndex;
         else
            chosen=(candidates[buyIndex].score>=candidates[sellIndex].score)
                   ? buyIndex:sellIndex;
      }
      else if(buyIndex>=0)
         chosen=buyIndex;
      else if(sellIndex>=0)
         chosen=sellIndex;

      if(chosen>=0 && ExecuteSetup(candidates[chosen],false))
         placements++;
   }

   return placements;
}

void STB_RunScanCycle()
{
   Setup candidates[];
   int candidateCount=ScanWatchlist(candidates);
   int placements=STB_ProcessExecutionCandidates(candidates);

   Print("STB EXECUTION COORDINATOR candidateCount=",
         IntegerToString(candidateCount),
         " placements=",IntegerToString(placements),
         " owner=EXECUTION");
}

//==================================================================
// PANEL
//==================================================================

void UpdatePanel()
{
   // Intentionally no Comment() panel: removes white text from the chart.
}

//==================================================================
// BUTTONS
//==================================================================

// Central UI sizing (layout-only change; trading logic untouched).
const int UI_BUTTON_WIDTH  = 400;
const int UI_BUTTON_HEIGHT = 30;

void CreateButton(const string name,
                  const string text,
                  const int x,
                  const int y,
                  const int width,
                  const int height,
                  const color bgColor)
{
   ObjectDelete(0,name);

   if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
      return;

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgColor);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
}

void CreateButtonCorner(const string name,
                        const string text,
                        const int x,
                        const int y,
                        const int width,
                        const int height,
                        const color bgColor,
                        const int corner)
{
   ObjectDelete(0,name);

   if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
      return;

   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgColor);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
}

void CreateLabel(const string name,
                 const string text,
                 const int x,
                 const int y,
                 const int fontSize)
{
   ObjectDelete(0,name);

   if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
      return;

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

//==================================================================
// DASHBOARD LAYOUT MANAGER (UI ONLY - NO TRADING SIDE EFFECTS)
//------------------------------------------------------------------
// Single source of truth for the on-chart command panel:
//   * one anchor corner + margins define the dashboard origin,
//   * one central set of size/gap/padding/font parameters,
//   * every control is placed by the same solver, so moving the
//     dashboard moves all controls together instead of editing
//     7 independent coordinate literals.
// The manager only creates/positions chart objects. It never calls
// trading, order, risk or strategy code.
//==================================================================

const string STB_DASH_KEYS[7]        = {"AUTO","CANDLE_TIME","BUYSTOP","SELLSTOP",
                                        "HEDGE","SAVE20","STATUS"};
const int    STB_DASH_KEY_MIN_WIDTH  = 78;
const int    STB_DASH_KEY_MIN_HEIGHT = 16;

// Professional dark palette, exactly one entry per dashboard row
// (single source of truth for the whole panel styling).
const color  STB_DASH_KEY_COLORS[7]  = {C'20,130,95',  C'98,76,145', C'30,115,62',
                                        C'155,48,52',  C'168,110,32', C'38,92,155',
                                        C'58,66,80'};

int g_dashLastClientW = -1;
int g_dashLastClientH = -1;
int g_dashLastCorner  = -1;
int g_dashFontPx      = 10;
int g_dashCountdownPx = 14;   // Phase 11: countdown row font (digits-only, 13..16)

// TASK36: manual dashboard placement + lock.
// A single dashboard origin (distance from the anchor corner) is stored,
// never per-control coordinates. g_dashHasOrigin = a user-locked origin
// is in effect, restored from GlobalVariables on every init.
bool   g_dashLocked    = true;   // position locked (default; false only in edit mode)
bool   g_dashHasOrigin = false;  // user-stored origin active
int    g_dashOriginX   = 0;      // panel distance from anchor corner (X)
int    g_dashOriginY   = 0;      // panel distance from anchor corner (Y)
string g_dashStateX    = "";     // GlobalVariable name (ScopedStateName)
string g_dashStateY    = "";     // GlobalVariable name (ScopedStateName)

// Number of controls managed by the dashboard.
int STB_DashKeyCount()
{
   return(ArraySize(STB_DASH_KEYS));
}

// Real chart object name of the control at dashboard row index (0 = top row).
string STB_DashKeyName(const int index)
{
   if(index<0 || index>=STB_DashKeyCount())
      return("");
   return(g_prefix+STB_DASH_KEYS[index]);
}

string STB_DashPanelName()
{
   return(g_prefix+"DASH_PANEL");
}

bool STB_DashIsUpperCorner(const int corner)
{
   return(corner==CORNER_LEFT_UPPER || corner==CORNER_RIGHT_UPPER);
}

// Central geometry solver. Everything the dashboard needs is derived
// here from the live chart client area, so a single configuration
// change re-lays out the whole dashboard.
// Content-driven button width (px): longest dashboard label + padding,
// rounded up to the 4px base grid, with a usable minimum. Read-only.
int STB_DashTextMetrics(const int fontPx,const int hPad)
{
   const string dashTexts[7]=
   {
      "AUTO",
      "00:00:00",
      "BUY",
      "SELL",
      "HEDGE",
      "SAVE+20",
      "TRAIL: 00"
   };
   int maxW=0;
   for(int i=0;i<7;i++)
   {
      int tl=0;
      int n=StringLen(dashTexts[i]);
      for(int j=0;j<n;j++)
      {
         ushort ch=StringGetCharacter(dashTexts[i],j);
         if(ch==' ')   tl+=fontPx*3/10;
         else if(ch==':'||ch=='.'||ch=='i'||ch=='l'||ch=='\'') tl+=fontPx*2/10;
         else if(ch>='A'&&ch<='Z') tl+=fontPx*75/100;
         else tl+=fontPx*55/100;
      }
      if(tl>maxW) maxW=tl;
   }
   return(MathMax(78,(maxW+hPad*2+3)/4*4));
}

void STB_DashComputeGeometry(int &count,
                             int &buttonWidth,
                             int &buttonHeight,
                             int &gap,
                             int &padding,
                             int &panelWidth,
                             int &panelHeight,
                             int &panelX,
                             int &panelY)
{
// Content-driven label width estimate (px) for the longest dashboard
// label at the given font size. Read-only text metrics; no trading.
// Uppercase latin ~0.75em, digits ~0.55em, narrow/space ~0.2-0.3em.
{
   int fontPx=g_dashFontPx;
{
   const string texts[7]=
   {
      "AUTO",
      "00:00:00",
      "BUY",
      "SELL",
      "HEDGE",
      "SAVE+20",
      "TRAIL: 00"
   };
   int maxW=0;
   for(int i=0;i<7;i++)
   {
      int w=0;
      int n=StringLen(texts[i]);
      for(int j=0;j<n;j++)
      {
         ushort ch=StringGetCharacter(texts[i],j);
         if(ch==' ')
            w+=fontPx*3/10;
         else if(ch==':'||ch=='.'||ch=='i'||ch=='l'||ch=='\'')
            w+=fontPx*2/10;
         else if(ch>='A'&&ch<='Z')
            w+=fontPx*75/100;
         else
            w+=fontPx*55/100;
      }
      if(w>maxW)
         maxW=w;
   }
   maxW=0; // text-metric exploration block (actual sizing below)
}
}

   count        = STB_DashKeyCount();
   int fontPx=(int)InpUiFontSize;
   int hPad  =8;   // 2 x 4px base grid
   int vPad  =5;
   int maxW  =0;
   if(fontPx<8)  fontPx=8;
   if(fontPx>12) fontPx=12;
   g_dashFontPx=fontPx;
   const string dashTexts[7]=
   {
      "AUTO",
      "00:00:00",
      "BUY",
      "SELL",
      "HEDGE",
      "SAVE+20",
      "TRAIL: 00"
   };
   for(int i=0;i<7;i++)
   {
      int tl=0;
      int n=StringLen(dashTexts[i]);
      for(int j=0;j<n;j++)
      {
         ushort ch=StringGetCharacter(dashTexts[i],j);
         if(ch==' ')   tl+=fontPx*3/10;
         else if(ch==':'||ch=='.'||ch=='i'||ch=='l'||ch=='\'') tl+=fontPx*2/10;
         else if(ch>='A'&&ch<='Z') tl+=fontPx*75/100;
         else tl+=fontPx*55/100;
      }
      if(tl>maxW) maxW=tl;
   }
   buttonWidth =MathMax(78,(maxW+hPad*2+3)/4*4);
   buttonHeight = fontPx+vPad*2;
   gap          = InpUiGap;
   padding      = InpUiPadding;
   panelX       = InpUiMarginX;
   panelY       = InpUiMarginY;

   if(InpUiAutoFit)
   {
      int clientW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
      int clientH=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
      if(clientW>0 && clientH>0)
      {
         int availW=clientW-2*InpUiMarginX;
         int availH=clientH-2*InpUiMarginY;
         if(availW<STB_DASH_KEY_MIN_WIDTH+2*padding)
            availW=STB_DASH_KEY_MIN_WIDTH+2*padding;
         if(availH<STB_DASH_KEY_MIN_HEIGHT+2*padding)
            availH=STB_DASH_KEY_MIN_HEIGHT+2*padding;

         // Horizontal fit: never let the dashboard leave the client area.
         if(buttonWidth+2*padding>availW && buttonWidth>STB_DASH_KEY_MIN_WIDTH)
         {
            buttonWidth=availW-2*padding;
            if(buttonWidth<STB_DASH_KEY_MIN_WIDTH)
               buttonWidth=STB_DASH_KEY_MIN_WIDTH;
         }

         // Vertical fit: give up gap first, then button height.
         while(gap>0 &&
               count*buttonHeight+(count-1)*gap+2*padding>availH)
            gap--;
         while(buttonHeight>STB_DASH_KEY_MIN_HEIGHT &&
               count*buttonHeight+(count-1)*gap+2*padding>availH)
            buttonHeight--;
         // Readability-first shrink: gap -> height -> font -> width.
         while(fontPx>8 && count*buttonHeight+(count-1)*gap+2*padding>availH)
         {
            fontPx--;
            g_dashFontPx=fontPx;
            buttonHeight=fontPx+vPad*2;
            buttonWidth=(STB_DashTextMetrics(fontPx,hPad)+3)/4*4;
         }
         while(hPad>4 && count*buttonHeight+(count-1)*gap+2*padding>availH)
         {
            hPad--;
            buttonWidth=(STB_DashTextMetrics(fontPx,hPad)+3)/4*4;
         }
      }
   }

   // TASK 32: align the panel right/bottom edge to the REAL price-area
   // boundary (RIGHT_OFFSET=0, BOTTOM_OFFSET=0). Only the panel origin
   // is adjusted; controls derive from it, so relative positions stay
   // unchanged. UI-only; no trading side effects.
   if(InpUiCorner==CORNER_RIGHT_LOWER)
   {
      int cw0=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
      int ch0=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
      int areaRight=cw0;
      int areaBottom=ch0;
      datetime mt0=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
      datetime mtN=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,10);
      if(mt0>0 && mtN>0)
      {
         double pxmin=ChartGetDouble(0,CHART_PRICE_MIN);
         int ax0=0,ay0=0,axN=0,ayN=0;
         if(ChartTimePriceToXY(0,0,mt0,pxmin,ax0,ay0) &&
            ChartTimePriceToXY(0,0,mtN,pxmin,axN,ayN) && ax0>axN)
         {
            int aspacing=(ax0-axN)/10;
            if(aspacing>0)
               areaRight=ax0+aspacing;
            if(ay0>0 && ay0<=ch0)
               areaBottom=ay0;
         }
      }
      if(cw0>0 && ch0>0)
      {
         if(areaRight>0 && areaRight<cw0)
            panelX=InpUiMarginX+(cw0-areaRight);
         if(areaBottom>0 && areaBottom<ch0)
            panelY=InpUiMarginY+(ch0-areaBottom);
      }
   }

   panelWidth  = buttonWidth+2*padding;
   panelHeight = count*buttonHeight+(count-1)*gap+2*padding;
}

// Creates the dashboard container first (so the controls are drawn on
// top of it) and then the 7 managed controls in dashboard row order.
void STB_DashCreate()
{
   string panel=STB_DashPanelName();
   ObjectDelete(0,panel);

   if(InpUiShowPanel)
   {
      if(ObjectCreate(0,panel,OBJ_RECTANGLE_LABEL,0,0,0))
      {
         ObjectSetInteger(0,panel,OBJPROP_CORNER,(int)InpUiCorner);
         ObjectSetInteger(0,panel,OBJPROP_XDISTANCE,InpUiMarginX);
         ObjectSetInteger(0,panel,OBJPROP_YDISTANCE,InpUiMarginY);
         ObjectSetInteger(0,panel,OBJPROP_XSIZE,10);
         ObjectSetInteger(0,panel,OBJPROP_YSIZE,10);
         ObjectSetInteger(0,panel,OBJPROP_BGCOLOR,C'22,26,33');
         ObjectSetInteger(0,panel,OBJPROP_BORDER_TYPE,BORDER_FLAT);
         ObjectSetInteger(0,panel,OBJPROP_COLOR,C'72,84,104');
         ObjectSetInteger(0,panel,OBJPROP_STYLE,STYLE_SOLID);
         ObjectSetInteger(0,panel,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,panel,OBJPROP_BACK,false);
         ObjectSetInteger(0,panel,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,panel,OBJPROP_HIDDEN,false);
         ObjectSetInteger(0,panel,OBJPROP_ZORDER,0);
      }
   }

   // Row order = dashboard order. STB_AUTO is the top row and
   // STB_CANDLE_TIME follows it directly (rows 1-2 of the panel).
   CreateButtonCorner(STB_DashKeyName(0),"AUTO",     InpUiMarginX,InpUiMarginY,InpUiButtonWidth,InpUiButtonHeight,clrLimeGreen,  (int)InpUiCorner);
   CreateButtonCorner(STB_DashKeyName(1),"00:00:00", InpUiMarginX,InpUiMarginY,InpUiButtonWidth,InpUiButtonHeight,clrGold,       (int)InpUiCorner);
   CreateButtonCorner(STB_DashKeyName(2),"BUY",       InpUiMarginX,InpUiMarginY,InpUiButtonWidth,InpUiButtonHeight,clrLimeGreen,  (int)InpUiCorner);
   CreateButtonCorner(STB_DashKeyName(3),"SELL",      InpUiMarginX,InpUiMarginY,InpUiButtonWidth,InpUiButtonHeight,clrTomato,     (int)InpUiCorner);
   CreateButtonCorner(STB_DashKeyName(4),"HEDGE",  InpUiMarginX,InpUiMarginY,InpUiButtonWidth,InpUiButtonHeight,clrOrange,     (int)InpUiCorner);
   CreateButtonCorner(STB_DashKeyName(5),"SAVE+20", InpUiMarginX,InpUiMarginY,InpUiButtonWidth,InpUiButtonHeight,clrDodgerBlue, (int)InpUiCorner);
   CreateButtonCorner(STB_DashKeyName(6),"TRAIL",                InpUiMarginX,InpUiMarginY,InpUiButtonWidth,InpUiButtonHeight,clrGray,       (int)InpUiCorner);

   STB_DashSyncLayout(true);
}

// Pushes the solved geometry into the container and every control.
void STB_DashApplyLayout()
{
   int count,buttonWidth,buttonHeight,gap,padding,panelWidth,panelHeight,panelX,panelY;
   STB_DashComputeGeometry(count,buttonWidth,buttonHeight,gap,padding,
                           panelWidth,panelHeight,panelX,panelY);

   // TASK36: a user-locked origin overrides the auto-alignment solved
   // above (panelX/panelY are distances from the anchor corner). Only in
   // locked mode a minimal clamp keeps the panel inside the client on a
   // real resize; the stored origin itself is never overwritten here.
   if(g_dashHasOrigin)
   {
      panelX=g_dashOriginX;
      panelY=g_dashOriginY;
      if(g_dashLocked)
      {
         int cwL=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
         int chL=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
         if(panelX+panelWidth>cwL) panelX=MathMax(0,cwL-panelWidth);
         if(panelY+panelHeight>chL) panelY=MathMax(0,chL-panelHeight);
      }
   }

   int  corner=(int)InpUiCorner;
   bool upper =STB_DashIsUpperCorner(corner);

   string panel=STB_DashPanelName();
   if(ObjectFind(0,panel)>=0)
   {
      ObjectSetInteger(0,panel,OBJPROP_CORNER,corner);
      ObjectSetInteger(0,panel,OBJPROP_XDISTANCE,panelX);
      ObjectSetInteger(0,panel,OBJPROP_YDISTANCE,panelY);
      ObjectSetInteger(0,panel,OBJPROP_XSIZE,panelWidth);
      ObjectSetInteger(0,panel,OBJPROP_YSIZE,panelHeight);
      // TASK36: drag-by-panel only. In edit mode the container becomes
      // selectable, which is enough to make it draggable with the mouse
      ObjectSetInteger(0,panel,OBJPROP_SELECTABLE,!g_dashLocked);
      // (OBJPROP_DRAGGABLE not declared in this compiler build: SELECTABLE alone enables drag)
      ObjectSetInteger(0,panel,OBJPROP_ZORDER,0);
   }

   int controlX=panelX+padding;
   for(int i=0;i<count;i++)
   {
      string name=STB_DashKeyName(i);
      if(name=="")
         continue;

      // Lower corners stack upward from the panel bottom, upper corners
      // stack downward from the panel top: row 0 is always the top row.
      int controlY = upper ? (panelY+padding+i*(buttonHeight+gap))
                           : (panelY+padding+(count-1-i)*(buttonHeight+gap));

      ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,controlX);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,controlY);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,buttonWidth);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,buttonHeight);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,(i==1 ? g_dashCountdownPx : g_dashFontPx));
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,STB_DASH_KEY_COLORS[i]);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,name,OBJPROP_STATE,false);
      // Keep every command button above the dashboard and other chart
      // objects so the button itself owns the mouse-click event.
      ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
   }
}

// Re-layout only when the chart client area (or the anchor) really
// changed, so the periodic call stays cheap.
void STB_DashSyncLayout(const bool force)
{
   int clientW=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int clientH=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   int corner =(int)InpUiCorner;

   if(!force && clientW==g_dashLastClientW && clientH==g_dashLastClientH
             && corner ==g_dashLastCorner)
      return;

   g_dashLastClientW=clientW;
   g_dashLastClientH=clientH;
   g_dashLastCorner =corner;
   STB_DashApplyLayout();
}

void UpdateButtons()
{
   string autoName=g_prefix+"AUTO";
   string saveName=g_prefix+"SAVE20";
   string hedgeName=g_prefix+"HEDGE";

   ObjectSetString(0,autoName,OBJPROP_TEXT,
                   "AUTO");
   ObjectSetInteger(0,autoName,OBJPROP_BGCOLOR,
                    g_autoTrading ? C'20,130,95' : C'140,45,50');
   ObjectSetInteger(0,autoName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,saveName,OBJPROP_TEXT,"SAVE+20");
   ObjectSetInteger(0,saveName,OBJPROP_BGCOLOR,STB_DASH_KEY_COLORS[5]);
   ObjectSetInteger(0,saveName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,hedgeName,OBJPROP_TEXT,"HEDGE");
   ObjectSetInteger(0,hedgeName,OBJPROP_BGCOLOR,STB_DASH_KEY_COLORS[4]);
   ObjectSetInteger(0,hedgeName,OBJPROP_COLOR,clrWhite);

   string statusName=g_prefix+"STATUS";
   string statusText=
      "TRAIL: "+IntegerToString(STB_PendingTrailActiveCount());
      // AUTO state is shown by the AUTO button background color.
   ObjectSetString(0,statusName,OBJPROP_TEXT,statusText);

   // Candle countdown (UI only; no trading side effects).
   string candleName=g_prefix+"CANDLE_TIME";
   datetime barOpen=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
   int periodSec=(int)PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   int remaining=0;
   if(barOpen>0 && periodSec>0)
   {
      remaining=(int)(barOpen+(datetime)periodSec-TimeCurrent());
      if(remaining<0)
         remaining=0;
   }
   int cTimeH=remaining/3600;
   int cTimeM=(remaining%3600)/60;
   int cTimeS=remaining%60;
   // Phase 11: digits-only countdown (MM:SS / HH:MM:SS) - remaining time
   // until the current chart-timeframe bar closes. No static caption.
   if(remaining>=3600)
      ObjectSetString(0,candleName,OBJPROP_TEXT,
                      StringFormat("%02d:%02d:%02d",cTimeH,cTimeM,cTimeS));
   else
      ObjectSetString(0,candleName,OBJPROP_TEXT,
                      StringFormat("%02d:%02d",cTimeM,cTimeS));

}

//==================================================================
// VISUAL MARKERS
//==================================================================

void DeleteVisuals()
{
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,g_prefix+"VIS_")==0 ||
         StringFind(name,g_prefix+"SIG_")==0)
         ObjectDelete(0,name);
   }
}

#ifdef STB_PH3_VIS_ARCHIVE
// PH4-ARCHIVE: legacy VIS marker helpers REMOVED (MASTER Phase 7-9).
void DrawHLine(const string name,const double price,const color clr)
{
   ObjectDelete(0,name);
   if(price<=0.0)
      return;

   if(!ObjectCreate(0,name,OBJ_HLINE,0,0,price))
      return;

   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
}

void DrawMarker(const string name,const datetime t,const double price,
                const color clr,const int arrowCode)
{
   ObjectDelete(0,name);
   if(t<=0 || price<=0.0)
      return;

   if(!ObjectCreate(0,name,OBJ_ARROW,0,t,price))
      return;

   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,arrowCode);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
}

void DrawTextMarker(const string name,const datetime t,const double price,
                    const string text,const color clr)
{
   ObjectDelete(0,name);
   if(t<=0 || price<=0.0)
      return;

   if(!ObjectCreate(0,name,OBJ_TEXT,0,t,price))
      return;

   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
}

void DrawZone(const string name,const datetime t1,const double p1,
              const datetime t2,const double p2,const color clr)
{
   ObjectDelete(0,name);

   if(t1<=0 || t2<=0 || p1<=0.0 || p2<=0.0)
      return;

   if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,p1,t2,p2))
      return;

   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
}

void DrawZigSegment(const string name,const SwingPoint &a,const SwingPoint &b)
{
   ObjectDelete(0,name);

   if(a.time<=0 || b.time<=0 || a.price<=0.0 || b.price<=0.0)
      return;

   if(!ObjectCreate(0,name,OBJ_TREND,0,a.time,a.price,b.time,b.price))
      return;

   // Neutral ZigZag line: no bright pivot colors and no chart clutter.
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrSilver);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
}

#endif
// PH4-ARCHIVE-END: legacy VIS marker helpers excluded.
void SortSwingsByTime(SwingPoint &points[])   // SHARED swing data - KEPT active
{
   int n=ArraySize(points);

   for(int i=1;i<n;i++)
   {
      SwingPoint key=points[i];
      int j=i-1;

      while(j>=0 && points[j].time>key.time)
      {
         points[j+1]=points[j];
         j--;
      }

      points[j+1]=key;
   }
}

#ifdef STB_PH3_VIS_ARCHIVE
// PH4-ARCHIVE: legacy VIS/STB structure renderers REMOVED (MASTER Phase 7-9).
// ACSS engine (AC_SmartStructure.mqh) now owns all zigzag/structure/channel
// visualization. These functions duplicated ACSS output and were a clutter
// root cause (VIS_ZZ_*, VIS_VALID_*, SIG_* BREAK markers).
void DrawZigZagVisual()
{
   SwingPoint points[];

   BuildZigZagPoints(_Symbol,PERIOD_M15,InpLookbackM15,points);

   int n=ArraySize(points);
   if(n<2)
      return;

   for(int i=1;i<n;i++)
      DrawZigSegment(g_prefix+"VIS_ZZ_"+(string)i,points[i-1],points[i]);
}


void DrawAllFVGVisuals()
{
   MqlRates r[];

   if(!GetRates(_Symbol,PERIOD_M15,InpLookbackM15,r))
      return;

   int maxScan=MathMin(InpPatternWindowBars,InpLookbackM15-3);

   for(int s=1;s<=maxScan;s++)
   {
      if(r[s].low>r[s+2].high)
      {
         DrawZone(g_prefix+"VIS_FVG_B_"+(string)s,
                  r[s+2].time,r[s+2].high,
                  r[s].time,r[s].low,
                  clrAqua);
         DrawTextMarker(g_prefix+"VIS_FVG_BT_"+(string)s,
                        r[s].time,r[s].low,"FVG",clrAqua);
      }

      if(r[s].high<r[s+2].low)
      {
         DrawZone(g_prefix+"VIS_FVG_S_"+(string)s,
                  r[s+2].time,r[s+2].low,
                  r[s].time,r[s].high,
                  clrYellow);
         DrawTextMarker(g_prefix+"VIS_FVG_ST_"+(string)s,
                        r[s].time,r[s].high,"FVG",clrYellow);
      }
   }
}

void DrawAllOBVisuals()
{
   MqlRates r[];

   if(!GetRates(_Symbol,PERIOD_M15,InpLookbackM15,r))
      return;

   int maxScan=MathMin(InpPatternWindowBars*2,InpLookbackM15-1);

   for(int s=1;s<=maxScan;s++)
   {
      if(r[s].close<r[s].open)
      {
         datetime t2=r[MathMax(1,s-2)].time;
         DrawZone(g_prefix+"VIS_OB_B_"+(string)s,
                  r[s].time,r[s].high,t2,r[s].low,
                  clrDodgerBlue);
      }

      if(r[s].close>r[s].open)
      {
         datetime t2=r[MathMax(1,s-2)].time;
         DrawZone(g_prefix+"VIS_OB_S_"+(string)s,
                  r[s].time,r[s].high,t2,r[s].low,
                  clrOrange);
      }
   }
}

void DrawStructureVisuals()
{
   // Draw the latest CONFIRMED ZigZag high and low as horizontal
   // structural levels. Each level extends exactly 30 candles to the
   // right, unless a CLOSED candle breaks it earlier.
   //
   // Break classification:
   //   resistance break in bullish context  -> BOS BUY
   //   resistance break in bearish context  -> CHoCH BUY
   //   support break in bearish context     -> BOS SELL
   //   support break in bullish context     -> CHoCH SELL
   //
   // This is deliberately independent from FVG/OB/entry filters.
   SwingPoint zz[];
   BuildZigZagPoints(_Symbol,PERIOD_M15,InpLookbackM15,zz);

   int n=ArraySize(zz);
   if(n<4)
      return;

   SwingPoint validHigh={0,0,0.0,false};
   SwingPoint validLow={0,0,0.0,false};
   bool haveHigh=false;
   bool haveLow=false;

   // Latest confirmed ZigZag high/low are the valid structural levels.
   for(int i=n-1;i>=0;i--)
   {
      if(!haveHigh && zz[i].isHigh)
      {
         validHigh=zz[i];
         haveHigh=true;
      }

      if(!haveLow && !zz[i].isHigh)
      {
         validLow=zz[i];
         haveLow=true;
      }

      if(haveHigh && haveLow)
         break;
   }

   if(!haveHigh || !haveLow)
      return;

   MqlRates rates[];
   if(!GetRates(_Symbol,PERIOD_M15,InpLookbackM15,rates))
      return;

   const int extensionBars=30;

   // Determine the structural context immediately BEFORE each level.
   // The previous opposite pivots provide the market-structure direction.
   string highContext="NEUTRAL";
   string lowContext ="NEUTRAL";

   for(int i=n-1;i>=0;i--)
   {
      if(zz[i].time>=validHigh.time)
         continue;

      if(zz[i].isHigh && zz[i].price<validHigh.price)
      {
         highContext="BULLISH";
         break;
      }
   }

   for(int i=n-1;i>=0;i--)
   {
      if(zz[i].time>=validLow.time)
         continue;

      if(!zz[i].isHigh && zz[i].price>validLow.price)
      {
         lowContext="BEARISH";
         break;
      }
   }

   // If the immediate prior structure is not obvious from the same type
   // of pivot, compare the latest two confirmed highs/lows.
   SwingPoint highs[];
   SwingPoint lows[];

   for(int i=n-1;i>=0;i--)
   {
      if(zz[i].isHigh)
      {
         int h=ArraySize(highs);
         ArrayResize(highs,h+1);
         highs[h]=zz[i];
      }
      else
      {
         int l=ArraySize(lows);
         ArrayResize(lows,l+1);
         lows[l]=zz[i];
      }
   }

   if(ArraySize(highs)>=2)
   {
      if(highs[0].price>highs[1].price)
         highContext="BULLISH";
      else if(highs[0].price<highs[1].price)
         highContext="BEARISH";
   }

   if(ArraySize(lows)>=2)
   {
      if(lows[0].price>lows[1].price)
         lowContext="BULLISH";
      else if(lows[0].price<lows[1].price)
         lowContext="BEARISH";
   }

   // ---------------------------------------------------------------
   // VALID HIGH / RESISTANCE
   // ---------------------------------------------------------------
   {
      string lineName=g_prefix+"VIS_VALID_HIGH";
      string textName=g_prefix+"SIG_VALID_HIGH";
      ObjectDelete(0,lineName);
      ObjectDelete(0,textName);

      int startShift=validHigh.shift;
      int breakShift=-1;
      int endShift=MathMax(1,startShift-extensionBars);

      // rates[] is series data. Search only CLOSED candles after the
      // confirmed pivot, up to exactly 30 candles.
      for(int sh=startShift-1;sh>=endShift;sh--)
      {
         if(rates[sh].close>validHigh.price)
         {
            breakShift=sh;
            break;
         }
      }

      int finalShift=(breakShift>0 ? breakShift : endShift);

      if(finalShift<1)
         finalShift=1;

      datetime t1=validHigh.time;
      datetime t2=rates[finalShift].time;

      if(t2>t1)
      {
         if(ObjectCreate(0,lineName,OBJ_TREND,0,t1,validHigh.price,t2,validHigh.price))
         {
            ObjectSetInteger(0,lineName,OBJPROP_COLOR,clrSlateGray);
            ObjectSetInteger(0,lineName,OBJPROP_WIDTH,2);
            ObjectSetInteger(0,lineName,OBJPROP_STYLE,STYLE_SOLID);
            ObjectSetInteger(0,lineName,OBJPROP_RAY_LEFT,false);
            ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,false);
            ObjectSetInteger(0,lineName,OBJPROP_BACK,false);
            ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,lineName,OBJPROP_HIDDEN,false);
         }
      }

      if(breakShift>0)
      {
         string eventText=(highContext=="BEARISH" ? "CHoCH BUY" : "BOS BUY");
         datetime bt=rates[breakShift].time;

         DrawTextMarker(textName,bt,validHigh.price,
                        eventText,clrSilver);

         DrawStructureLine(g_prefix+"SIG_HIGH_BREAK",
                           validHigh.time,validHigh.price,
                           bt,validHigh.price,clrSilver);

         Print("STB HIGH LEVEL BREAK symbol=",_Symbol,
               " event=",eventText,
               " price=",DoubleToString(validHigh.price,
               (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
               " time=",TimeToString(bt));
      }
   }

   // ---------------------------------------------------------------
   // VALID LOW / SUPPORT
   // ---------------------------------------------------------------
   {
      string lineName=g_prefix+"VIS_VALID_LOW";
      string textName=g_prefix+"SIG_VALID_LOW";
      ObjectDelete(0,lineName);
      ObjectDelete(0,textName);

      int startShift=validLow.shift;
      int breakShift=-1;
      int endShift=MathMax(1,startShift-extensionBars);

      for(int sh=startShift-1;sh>=endShift;sh--)
      {
         if(rates[sh].close<validLow.price)
         {
            breakShift=sh;
            break;
         }
      }

      int finalShift=(breakShift>0 ? breakShift : endShift);

      if(finalShift<1)
         finalShift=1;

      datetime t1=validLow.time;
      datetime t2=rates[finalShift].time;

      if(t2>t1)
      {
         if(ObjectCreate(0,lineName,OBJ_TREND,0,t1,validLow.price,t2,validLow.price))
         {
            ObjectSetInteger(0,lineName,OBJPROP_COLOR,clrSlateGray);
            ObjectSetInteger(0,lineName,OBJPROP_WIDTH,2);
            ObjectSetInteger(0,lineName,OBJPROP_STYLE,STYLE_SOLID);
            ObjectSetInteger(0,lineName,OBJPROP_RAY_LEFT,false);
            ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,false);
            ObjectSetInteger(0,lineName,OBJPROP_BACK,false);
            ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,lineName,OBJPROP_HIDDEN,false);
         }
      }

      if(breakShift>0)
      {
         string eventText=(lowContext=="BULLISH" ? "CHoCH SELL" : "BOS SELL");
         datetime bt=rates[breakShift].time;

         DrawTextMarker(textName,bt,validLow.price,
                        eventText,clrSilver);

         DrawStructureLine(g_prefix+"SIG_LOW_BREAK",
                           validLow.time,validLow.price,
                           bt,validLow.price,clrSilver);

         Print("STB LOW LEVEL BREAK symbol=",_Symbol,
               " event=",eventText,
               " price=",DoubleToString(validLow.price,
               (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
               " time=",TimeToString(bt));
      }
   }
}


void DrawStructureLine(const string name,
                       const datetime t1,const double p1,
                       const datetime t2,const double p2,
                       const color clr)
{
   ObjectDelete(0,name);
   if(t1<=0 || t2<=t1 || p1<=0.0 || p2<=0.0)
      return;

   if(!ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2))
      return;

   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
}

void DrawSetupLevels(const Setup &s,const string side)
{
   if(!s.valid)
      return;

   string tag=g_prefix+"SIG_"+side+"_";
   DrawHLine(tag+"ENTRY",s.entry,s.direction>0?clrLimeGreen:clrSilver);
   DrawHLine(tag+"SL",s.sl,clrSilver);
   DrawHLine(tag+"TP",s.tp,clrDeepSkyBlue);

   datetime t=iTime(_Symbol,PERIOD_M15,s.bosShift);
   if(t>0)
   {
      DrawTextMarker(tag+"ENTRY_TXT",t,s.entry,
                     side+" ENTRY",s.direction>0?clrLimeGreen:clrSilver);
      DrawTextMarker(tag+"SL_TXT",t,s.sl,"SL",clrSilver);
      DrawTextMarker(tag+"TP_TXT",t,s.tp,"TP",clrDeepSkyBlue);
   }

   if(s.originShift>=0)
   {
      datetime ot=iTime(_Symbol,PERIOD_M15,s.originShift);
      DrawZone(tag+"OB",ot,s.originHigh,
               iTime(_Symbol,PERIOD_M15,1),s.originLow,
               s.direction>0?clrDodgerBlue:clrOrange);
   }

   if(s.fvgShift>=0)
   {
      MqlRates r[];
      if(GetRates(_Symbol,PERIOD_M15,InpLookbackM15,r))
      {
         int f=s.fvgShift;
         if(f+2<InpLookbackM15)
         {
            if(s.direction>0)
               DrawZone(tag+"FVG",r[f+2].time,r[f+2].high,
                        r[f].time,r[f].low,clrAqua);
            else
               DrawZone(tag+"FVG",r[f+2].time,r[f+2].low,
                        r[f].time,r[f].high,clrYellow);
         }
      }
   }
}

void DrawSetupVisuals()
{
   // Clean structural chart:
   // H4 trendline is drawn separately.
   // Visible M15 structure = ZigZag + CHoCH/BOS + support/resistance.
   // FVG/OB rectangles and entry/SL/TP setup boxes remain hidden.
   DeleteVisuals();
   DrawZigZagVisual();
   DrawStructureVisuals();
   DrawSupportResistance();
   ChartRedraw(0);
}

//==================================================================
#endif
// PH4-ARCHIVE-END: legacy structure renderers excluded.
// BAR DETECTION
//==================================================================


bool NewM15Bar()
{
   datetime current=iTime(_Symbol,PERIOD_M15,0);

   if(current==0)
      return false;

   if(current!=g_lastM15Bar)
   {
      g_lastM15Bar=current;
      return true;
   }

   return false;
}

bool NewChartBar()
{
   datetime current=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);

   if(current==0)
      return false;

   if(current!=g_lastChartBar)
   {
      g_lastChartBar=current;
      return true;
   }

   return false;
}

//==================================================================
// INIT
//==================================================================

bool ValidateInputs()
{
   if(InpMagic==0)
      return false;
   if(StringLen(InpScannerSymbols)>1024)
      return false;
   if(InpScanSeconds<1)
      return false;
   if(InpAdaptiveMinScore<0.0 ||
      InpAdaptiveMaxScore>100.0 ||
      InpAdaptiveMinScore>InpAdaptiveMaxScore ||
      InpAdaptiveBaseScore<InpAdaptiveMinScore ||
      InpAdaptiveBaseScore>InpAdaptiveMaxScore ||
      InpAdaptiveStep<0.0 ||
      InpAdaptiveWeakWinRate<0.0 ||
      InpAdaptiveWeakWinRate>1.0 ||
      InpAdaptiveStrongWinRate<0.0 ||
      InpAdaptiveStrongWinRate>1.0 ||
      InpAdaptiveWeakWinRate>=InpAdaptiveStrongWinRate ||
      InpAdaptiveMinSamples<1 ||
      InpAdaptiveHalfLifeDays<=0.0 ||
      InpAdaptiveWarmupPerProfile<0 ||
      InpAdaptiveUCBExploration<0.0)
      return false;
   if(InpLookbackH4<30 || InpLookbackM15<30)
      return false;
   if(InpSwingLeft<1 || InpSwingRight<1)
      return false;
   if(InpBaseLots<=0.0 ||
      InpTrendLotMultiplier<0.0 ||
      InpUniversalLotMultiplier<0.0 ||
      InpEntryBufferPips<0.0 ||
      InpSLBufferPips<0.0 ||
      InpInitialSLBufferPips<0.0 ||
      InpMinimumRR<=0.0 ||
      InpMaxPendingBars<0)
      return false;
   if(InpPatternWindowBars<1)
      return false;
   if(InpAutoTriggerPips<0.0 ||
      InpAutoLockPips<0.0 ||
      InpManualSaveStepPips<0.0)
      return false;

   if(InpTrendlineTolerancePips<0.0 ||
      InpTrailStartPips<0.0 ||
      InpTrailCandleShift<1 ||
      InpTrailBufferPips<0.0)
      return false;
   if(InpMaxSpreadPips<0.0 ||
      InpSetupCooldownMinutes<0 ||
      InpMaxSetupAgeBars<0 ||
      InpPipPointsOverride<0.0 ||
      InpRiskPercent<0.0 ||
      InpMaxRiskVolume<0.0)
      return false;
   if(InpRSIPeriod<2 ||
      InpCCIPeriod<2 ||
      InpRSIBuyLevel<=50.0 ||
      InpRSIBuyLevel>100.0 ||
      InpRSISellLevel<0.0 ||
      InpRSISellLevel>=50.0 ||
      InpCCIBuyLevel<=0.0 ||
      InpCCISellLevel>=0.0 ||
      InpRSIWeight<0.0 ||
      InpCCIWeight<0.0 ||
      InpRSIWeight+InpCCIWeight>30.0)
      return false;

   return true;
}

int OnInit()
{
   g_autoStateName=ScopedStateName("AUTO");

   // TASK36: restore the user-locked dashboard origin so the panel does
   // not snap back to auto-alignment after a restart or re-applied inputs.
   // In Strategy Tester the default position stays authoritative.
   g_dashLocked=!InpUiEditMode;
   g_dashStateX=ScopedStateName("DASH_X");
   g_dashStateY=ScopedStateName("DASH_Y");
   g_dashHasOrigin=false;
   if(!MQLInfoInteger(MQL_TESTER) &&
      GlobalVariableCheck(g_dashStateX) &&
      GlobalVariableCheck(g_dashStateY))
   {
      g_dashOriginX=(int)MathRound(GlobalVariableGet(g_dashStateX));
      g_dashOriginY=(int)MathRound(GlobalVariableGet(g_dashStateY));
      g_dashHasOrigin=true;
   }

   if(!ValidateInputs())
   {
      Print("STB INIT FAILED: invalid input configuration.");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Keep AUTO TRADING state across chart timeframe/symbol reinitialization,
   // but isolate it by account + EA magic to avoid terminal-wide collisions.
   // In Strategy Tester, the input must be authoritative so a previous
   // emulated terminal-global state cannot silently disable trading.
   if(MQLInfoInteger(MQL_TESTER))
      g_autoTrading=(InpAutoTrading && !InpDiagnosticM15Mode);
   else if(InpDiagnosticM15Mode || !InpAutoTrading)
      g_autoTrading=false;
   else if(GlobalVariableCheck(g_autoStateName))
      g_autoTrading=(GlobalVariableGet(g_autoStateName)>0.5);
   else
      g_autoTrading=true;

   GlobalVariableSet(g_autoStateName,g_autoTrading ? 1.0 : 0.0);

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);

   if(!SymbolSelect(_Symbol,true))
      Print("STB INIT: current chart SymbolSelect failed symbol=",_Symbol,
            " err=",GetLastError());

   Print("STB TRADE ENV terminal=",
         TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "ON":"OFF",
         " program=",MQLInfoInteger(MQL_TRADE_ALLOWED) ? "ON":"OFF",
         " account=",AccountInfoInteger(ACCOUNT_TRADE_EXPERT) ? "ON":"OFF",
         " tester=",MQLInfoInteger(MQL_TESTER) ? "YES":"NO");

   Print("STB INIT symbol=",_Symbol,
         " chartTF=",EnumToString((ENUM_TIMEFRAMES)_Period),
         " magic=",IntegerToString((int)InpMagic),
         " auto=",g_autoTrading ? "ON":"OFF",
         " universal=",InpAllowUniversal ? "ON":"OFF",
         " strictFVGOB=",InpStrictPatternFilters ? "ON":"OFF",
         " requireFVG=",InpRequireFVG ? "ON":"OFF",
         " requireOB=",InpRequireOB ? "ON":"OFF",
         " maxSpreadPips=",DoubleToString(InpMaxSpreadPips,1),
         " adaptiveHalfLifeDays=",DoubleToString(InpAdaptiveHalfLifeDays,1),
         " RSIperiod=",IntegerToString(InpRSIPeriod),
         " CCIperiod=",IntegerToString(InpCCIPeriod),
         " oscHardFilter=",InpOscillatorHardFilter ? "ON":"OFF",
         " adaptiveParams=",InpAdaptiveParameterLearning ? "ON":"OFF",
         " warmup=",IntegerToString(InpAdaptiveWarmupPerProfile),
         " UCB=",DoubleToString(InpAdaptiveUCBExploration,2));

   // Bottom-right command panel: BUY STOP / SELL STOP, existing
   // controls (AUTO / SAVE20 / HEDGE), status label.
   // UI is not a state owner: it only issues commands and reads status.
   // Dashboard: container + all 7 controls are created and laid out by
   // the central layout manager (see DASHBOARD LAYOUT MANAGER below).
   STB_DashCreate();
   // Dashboard row order (top -> bottom): AUTO, CANDLE_TIME, BUYSTOP,
   // SELLSTOP, HEDGE, SAVE20, STATUS (CANDLE_TIME follows AUTO).
   // All rows are positioned by STB_DashApplyLayout() from the single
   // dashboard origin, so the whole panel moves together.
   // Tune position/size/gap/padding via the InpUi* inputs only.
   // (per-button X/Y literals are no longer edited by hand)

   UpdateButtons();

   EventSetTimer(MathMax(1,InpScanSeconds));

   // Pending Trail initialization + restart recovery (state rebuilt
   // from real terminal BUY_STOP / SELL_STOP orders).
   if(InpPendingTrail)
   {
      STB_PendingTrailInit();
      int recovered=STB_PendingTrailRebuildFromTerminal();
      Print("STB PENDING TRAIL INIT recovered=",IntegerToString(recovered));
   }

   // Immediately protect positions that already existed before this
   // EA instance/restart; do not wait for the first tick/timer cycle.
   ManagePositions();

   g_lastChartBar=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
   g_lastM15Bar=iTime(_Symbol,PERIOD_M15,0);




   OscillatorState osc;
   if(GetOscillatorState(_Symbol,osc))
      DrawOscillatorPanel(osc);

   // Restart/attach initializes state only; scheduler owns new exposure.
   UpdatePanel();

      //==================================================================
   // ACSS: Advanced Smart ZigZag + DUAL Smart Channel (TASK37).
   // ANALYSIS + VISUALIZATION ONLY. Read-only, never touches trading.
   //==================================================================
   if(InpSmartStructureEnabled)
     {
      ACSS_Config ac;
      ZeroMemory(ac);
      ac.enabled=InpSmartStructureEnabled;
      ac.tfMode=(int)InpSmartStructureTFMode;
      ac.longTF=(int)InpSmartStructureLongTF;
      ac.shortTF=(int)InpSmartStructureShortTF;
      ac.interTF=(int)InpSmartStructureInterTF;
      ac.lookback=InpSmartStructureLookback;
      ac.visualLegs=InpStructureVisualLegs;      // PHASE 55: bounded zigzag visual budget
      ac.showZigZag=InpStructureShowZigZag && InpSmartZigZagEnabled;
      ac.zzShowProvisional=InpSmartZigZagShowProvisional &&
                            InpSmartZigZagEnabled;
      ac.showSwings=InpStructureShowConfirmedSwings;
      ac.showHHLL=InpStructureShowHHLL;
      ac.showBOS=InpStructureShowBOS;
      ac.showCHoCH=InpStructureShowCHoCH;
      ac.showConfidence=InpStructureShowConfidence;
      ac.showRegime=InpStructureShowRegime;
      ac.zzMode=(int)InpSmartZigZagMode;
      ac.zzSensitivity=InpSmartZigZagSensitivity;
      ac.zzDepth=InpSmartZigZagDepth;
      ac.zzDeviation=InpSmartZigZagDeviation;
      ac.zzBackstep=InpSmartZigZagBackstep;
      ac.zzAdaptive=InpSmartZigZagAdaptive;
      ac.zzATRPeriod=InpSmartZigZagATRPeriod;
      ac.zzVolMode=InpSmartZigZagVolatilityMode;
      ac.zzSwingQuality=InpSmartZigZagSwingQuality;
      ac.zzShowProvisional=InpSmartZigZagShowProvisional;
      ac.longEnabled=InpLongChannelEnabled;
      ac.longShow=InpLongChannelShow;
      ac.longModel=(int)InpLongChannelModel;
      ac.longMinTouches=InpLongChannelMinTouches;
      ac.longMaxBars=InpLongChannelMaxBars;
      ac.longWidthMode=(int)InpLongChannelWidthMode;
      ac.longATRPeriod=InpLongChannelATRPeriod;
      ac.longShowMid=InpLongChannelShowMidline;
      ac.longShowBrk=InpLongChannelShowBreakout;
      ac.longShowRetest=InpLongChannelShowRetest;
      ac.shortEnabled=InpShortChannelEnabled;
      ac.shortShow=InpShortChannelShow;
      ac.shortModel=(int)InpShortChannelModel;
      ac.shortMinTouches=InpShortChannelMinTouches;
      ac.shortMaxBars=InpShortChannelMaxBars;
      ac.shortWidthMode=(int)InpShortChannelWidthMode;
      ac.shortATRPeriod=InpShortChannelATRPeriod;
      ac.shortShowMid=InpShortChannelShowMidline;
      ac.shortShowBrk=InpShortChannelShowBreakout;
      ac.shortShowRetest=InpShortChannelShowRetest;
      ac.longColor=InpStructureLongColor;
      ac.shortColor=InpStructureShortColor;
      ac.lineWidth=InpStructureLineWidth;
      ac.lineStyle=(int)InpStructureLineStyle;
      ac.midColor=InpStructureMidColor;
      ac.midStyle=(int)InpStructureMidStyle;
      ac.labelSize=InpStructureLabelSize;
      ac.pivotSize=InpStructurePivotSize;
      ac.showDebug=InpStructureShowDebug;
      ACSS_Init(ac);
      ACSS_OnNewBar();
     }
   else
      ACSS_Cleanup();

   return INIT_SUCCEEDED;
}

//==================================================================
// DEINIT
//==================================================================

double OnTester()
{
   double criterion=STB_AdaptiveTesterCriterion();
   Print("STB TESTER adaptive criterion=",DoubleToString(criterion,6));
   return criterion;
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   ObjectDelete(0,g_prefix+"AUTO");
   ObjectDelete(0,g_prefix+"SAVE20");
   ObjectDelete(0,g_prefix+"HEDGE");
   ObjectDelete(0,g_prefix+"BUYSTOP");
   ObjectDelete(0,g_prefix+"SELLSTOP");
   ObjectDelete(0,g_prefix+"STATUS");
   ObjectDelete(0,g_prefix+"CANDLE_TIME");
   ObjectDelete(0,g_prefix+"DASH_PANEL");








   DeleteVisuals();
   ObjectDelete(0,g_prefix+"OSC_PANEL");
   ObjectDelete(0,g_prefix+"OSC_SIG_B");
   ObjectDelete(0,g_prefix+"OSC_SIG_S");
   ReleaseIndicatorHandles();

   Comment("");

   ACSS_Cleanup();   // TASK37: remove all ACSS_* analysis objects
}

//==================================================================
// TICK
//==================================================================

void OnTick()
{
   ManagePositions();
   ManagePendingOrders();

   if(InpPendingTrail)
      STB_PendingTrailProcess();

   bool chartBar=NewChartBar();
   bool m15Bar=NewM15Bar();

   if(chartBar)
   {


   }

   if(m15Bar)
   {
      OscillatorState osc;
      if(GetOscillatorState(_Symbol,osc))
         DrawOscillatorPanel(osc);

      // Scan/execution scheduling has one owner: OnTimer.
      // OnTick handles market-state refresh only and never starts a second
      // opportunity-discovery/execution cycle at the M15 boundary.
      UpdatePanel();
   }
}

//==================================================================
// TIMER
//==================================================================

void OnTimer()
{
   ManagePositions();
   ManagePendingOrders();

   if(InpPendingTrail)
      STB_PendingTrailProcess();

   if(NewChartBar())
   {


   }

   // Fast scanner cadence is now real: the timer performs a bounded
   // full Market-Watch scan instead of pretending that 10 seconds means
   // an M15-only scan. Duplicate setup protection remains active.
   OscillatorState osc;
   if(GetOscillatorState(_Symbol,osc))
      DrawOscillatorPanel(osc);

   STB_RunScanCycle();
   UpdatePanel();

   UpdateButtons();

   // Dashboard responsiveness: re-layout only if the chart client area changed.
   STB_DashSyncLayout(false);

   // ACSS (TASK37): incremental on new chart bar only; zero per-tick cost.
   ACSS_OnNewBar();
}

//==================================================================
// CHART EVENTS
//==================================================================

string STB_LifecycleDealMarkerName(const ulong deal)
{
   return ScopedStateName("LIFECYCLE_DEAL_"+(string)deal);
}

bool STB_IsLifecycleDealProcessed(const ulong deal)
{
   if(deal==0)
      return false;

   return GlobalVariableCheck(STB_LifecycleDealMarkerName(deal));
}

void STB_MarkLifecycleDealProcessed(const ulong deal)
{
   if(deal==0)
      return;

   GlobalVariableSet(STB_LifecycleDealMarkerName(deal),1.0);
   GlobalVariablesFlush();
}

// Recover immutable strategy lifecycle state from terminal history when
// OnTradeTransaction delivery order did not allow the entry handler to
// persist it first. The history snapshot is the authoritative fallback.
bool STB_RecoverPositionAdaptiveState(const ulong positionId,
                                      int &profileId,
                                      double &riskMoney,
                                      int &direction)
{
   profileId=STB_AdaptiveReadPositionProfile(positionId);
   riskMoney=STB_AdaptiveReadPositionRisk(positionId);
   direction=0;

   if(positionId==0)
      return false;

   if((profileId>=0 && riskMoney>0.0 && direction!=0))
      return true;

   if(!HistorySelectByPosition(positionId))
      return (profileId>=0);

   int deals=HistoryDealsTotal();

   for(int i=0;i<deals;i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0)
         continue;

      long entryType=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entryType!=DEAL_ENTRY_IN)
         continue;

      string comment=HistoryDealGetString(deal,DEAL_COMMENT);
      if(STB_AdaptiveIsHedgeComment(comment))
         continue;

      long dealType=HistoryDealGetInteger(deal,DEAL_TYPE);
      int dealDirection=(dealType==DEAL_TYPE_BUY ? 1 :
                         dealType==DEAL_TYPE_SELL ? -1 : 0);

      if(dealDirection!=0 && direction==0)
         direction=dealDirection;

      ulong orderTicket=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);

      if(profileId<0 && orderTicket>0)
         profileId=STB_AdaptiveReadOrderProfile(orderTicket);

      if(profileId<0)
         profileId=STB_AdaptiveParseProfileFromComment(comment);

      if(riskMoney<=0.0)
      {
         double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
         double price=HistoryDealGetDouble(deal,DEAL_PRICE);
         double initialSL=HistoryDealGetDouble(deal,DEAL_SL);

         if(volume>0.0 && price>0.0 && initialSL>0.0)
         {
            ENUM_ORDER_TYPE calcType=
               (dealType==DEAL_TYPE_BUY ? ORDER_TYPE_BUY:
                dealType==DEAL_TYPE_SELL ? ORDER_TYPE_SELL:
                WRONG_VALUE);

            double loss=0.0;
            if(calcType!=WRONG_VALUE &&
               OrderCalcProfit(calcType,
                               HistoryDealGetString(deal,DEAL_SYMBOL),
                               volume,
                               price,
                               initialSL,
                               loss))
               riskMoney=MathAbs(loss);
         }
      }

      if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
      {
         STB_AdaptiveRememberPositionProfile(positionId,profileId);

         if(riskMoney>0.0)
            STB_AdaptiveRememberPositionRisk(positionId,riskMoney);

         if(orderTicket>0)
            STB_AdaptiveDeleteOrderState(orderTicket);

         return true;
      }

      // Keep searching in case the first entry was manual/legacy and a
      // later entry contains the strategy lifecycle metadata.
   }

   return profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                       const MqlTradeRequest &request,
                       const MqlTradeResult &result)
{
   if(trans.type==TRADE_TRANSACTION_ORDER_ADD)
   {
      if(trans.order>0)
      {
         EnsureInitialSLForPendingOrder(trans.order);

         if(InpPendingTrail)
            STB_PendingTrailRegister(trans.order,"TRADE_TRANSACTION");

         // TradeTransaction is the first state owner after terminal creation.
         // Adaptive/persistence lifecycle state belongs only to EA-owned orders.
         if(OrderSelect(trans.order))
         {
            STB_OWNER_CLASS orderOwner=STB_GetOrderOwner(trans.order);

            if(orderOwner==STB_OWNER_EA)
            {
               string orderComment=OrderGetString(ORDER_COMMENT);
               string orderSymbol=OrderGetString(ORDER_SYMBOL);
               int profileId=STB_AdaptiveParseProfileFromComment(orderComment);

               datetime setupTime=STB_ParsePendingSetupTime(
                  orderComment,0);

               if(setupTime>0)
               {
                  long orderTypeForState=OrderGetInteger(ORDER_TYPE);
                  int setupDirection=
                     (orderTypeForState==ORDER_TYPE_BUY_STOP ||
                      orderTypeForState==ORDER_TYPE_BUY_LIMIT ? 1 :
                      orderTypeForState==ORDER_TYPE_SELL_STOP ||
                      orderTypeForState==ORDER_TYPE_SELL_LIMIT ? -1 : 0);

                  if(setupDirection!=0)
                     SetLastSetupTime(orderSymbol,setupDirection,setupTime);
               }

               if(profileId>=0)
                  STB_AdaptiveRememberOrderProfile(trans.order,profileId);

               double orderRiskMoney=0.0;
               long orderType=OrderGetInteger(ORDER_TYPE);

               ENUM_ORDER_TYPE calcType=
                  (orderType==ORDER_TYPE_BUY_STOP ||
                   orderType==ORDER_TYPE_BUY_LIMIT ?
                   ORDER_TYPE_BUY :
                   orderType==ORDER_TYPE_SELL_STOP ||
                   orderType==ORDER_TYPE_SELL_LIMIT ?
                   ORDER_TYPE_SELL :
                   WRONG_VALUE);

               if(calcType!=WRONG_VALUE)
               {
                  double orderVolume=OrderGetDouble(ORDER_VOLUME_CURRENT);
                  double orderEntry=OrderGetDouble(ORDER_PRICE_OPEN);
                  double orderSL=OrderGetDouble(ORDER_SL);

                  if(orderVolume>0.0 &&
                     orderEntry>0.0 &&
                     orderSL>0.0 &&
                     OrderCalcProfit(calcType,
                                     orderSymbol,
                                     orderVolume,
                                     orderEntry,
                                     orderSL,
                                     orderRiskMoney))
                     STB_AdaptiveRememberOrderRisk(
                        trans.order,MathAbs(orderRiskMoney));
               }
            }
         }
      }

      return;
   }

   // Explicit lifecycle handoff: once a tracked pending order produces a
   // real deal, PendingTrail stops immediately and management owns the result.
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD &&
      trans.order>0)
   {
      STB_PendingTrailOnOrderFilled(trans.order);
   }

   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD ||
      trans.deal==0 ||
      !HistoryDealSelect(trans.deal))
      return;

   if(trans.position>0)
      EnsureInitialSL(trans.position);

   string comment=HistoryDealGetString(trans.deal,DEAL_COMMENT);
   long magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
   long entryType=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);

   if(magic!=(long)InpMagic)
      return;

   bool isHedge=STB_AdaptiveIsHedgeComment(comment);

   if(entryType==DEAL_ENTRY_IN)
   {
      int setupDirection=(HistoryDealGetInteger(trans.deal,DEAL_TYPE)==DEAL_TYPE_BUY ? 1 :
                          HistoryDealGetInteger(trans.deal,DEAL_TYPE)==DEAL_TYPE_SELL ? -1 : 0);
      datetime setupTime=STB_ParsePendingSetupTime(comment,0);

      if(setupDirection!=0 && setupTime>0)
         SetLastSetupTime(HistoryDealGetString(trans.deal,DEAL_SYMBOL),
                          setupDirection,
                          setupTime);
   }

   if(isHedge)
      return;

   bool closesLifecycle=
      entryType==DEAL_ENTRY_OUT ||
      entryType==DEAL_ENTRY_OUT_BY ||
      entryType==DEAL_ENTRY_INOUT;

   if(closesLifecycle && STB_IsLifecycleDealProcessed(trans.deal))
   {
      Print("STB LIFECYCLE duplicate deal ignored deal=",
            IntegerToString((int)trans.deal));
      return;
   }

   string symbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
   ulong positionId=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);

   if(entryType==DEAL_ENTRY_IN && positionId>0)
   {
      long dealType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);
      int direction=(dealType==DEAL_TYPE_BUY ? 1 :
                     dealType==DEAL_TYPE_SELL ? -1 : 0);

      if(direction!=0)
      {
         int profileId=STB_AdaptiveReadOrderProfile(trans.order);

         if(profileId<0)
            profileId=STB_AdaptiveParseProfileFromComment(comment);

         if(profileId<0)
         {
            Print("STB ADAPTIVE skip lifecycle without profile symbol=",
                  symbol," position=",positionId,
                  " order=",trans.order);
            return;
         }

         STB_AdaptiveRememberPositionProfile(positionId,profileId);

         double riskMoney=STB_AdaptiveReadOrderRisk(trans.order);

         if(riskMoney<=0.0 && PositionSelectByTicket(trans.position))
         {
            double positionVolume=PositionGetDouble(POSITION_VOLUME);
            double entryPrice=PositionGetDouble(POSITION_PRICE_OPEN);
            double initialSL=PositionGetDouble(POSITION_SL);
            long positionType=PositionGetInteger(POSITION_TYPE);

            if(positionVolume>0.0 && entryPrice>0.0 && initialSL>0.0)
            {
               ENUM_ORDER_TYPE calcType=
                  (positionType==POSITION_TYPE_BUY ?
                   ORDER_TYPE_BUY:ORDER_TYPE_SELL);

               double calculated=0.0;

               if(OrderCalcProfit(calcType,symbol,
                                  positionVolume,entryPrice,
                                  initialSL,calculated))
                  riskMoney=MathAbs(calculated);
            }
         }

         if(riskMoney>0.0)
            STB_AdaptiveRememberPositionRisk(positionId,riskMoney);

         STB_AdaptiveDeleteOrderState(trans.order);
      }

      return;
   }

   if(!closesLifecycle)
      return;

   double dealPnl=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+
                  HistoryDealGetDouble(trans.deal,DEAL_SWAP)+
                  HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+
                  HistoryDealGetDouble(trans.deal,DEAL_FEE);

   int originalDirection=0;
   int profileId=STB_AdaptiveReadPositionProfile(positionId);
   double riskMoney=STB_AdaptiveReadPositionRisk(positionId);

   int recoveredDirection=0;
   STB_RecoverPositionAdaptiveState(positionId,
                                     profileId,
                                     riskMoney,
                                     recoveredDirection);

   if(originalDirection==0)
      originalDirection=recoveredDirection;

   if(entryType==DEAL_ENTRY_INOUT)
   {
      long newType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);

      if(newType==DEAL_TYPE_BUY)
         originalDirection=-1;
      else if(newType==DEAL_TYPE_SELL)
         originalDirection=1;

      double priorPnl=GetAccumulatedPositionPnl(positionId);
      TakeAccumulatedPositionPnl(positionId);

      if(originalDirection!=0 &&
         profileId>=0 &&
         profileId<STB_ADAPTIVE_PROFILE_COUNT)
      {
         double lifecyclePnl=priorPnl+dealPnl;
         double rMultiple=(riskMoney>0.0 ?
                           lifecyclePnl/riskMoney:0.0);

         STB_AdaptiveRecordClosedDeal(symbol,
                                      originalDirection,
                                      lifecyclePnl,
                                      profileId,
                                      rMultiple);
      }
      else
      {
         Print("STB ADAPTIVE close skipped: lifecycle state unresolved",
               " position=",positionId,
               " profile=",profileId,
               " direction=",originalDirection);
      }

      STB_AdaptiveDeletePositionProfile(positionId);
      STB_AdaptiveDeletePositionRisk(positionId);
      STB_MarkLifecycleDealProcessed(trans.deal);
      return;
   }

   double cumulative=dealPnl;

   if(positionId>0)
      cumulative+=GetAccumulatedPositionPnl(positionId);

   if(positionId>0)
      SetAccumulatedPositionPnl(positionId,cumulative);

   bool positionStillOpen=IsPositionIdentifierOpen(positionId);

   if(positionStillOpen)
   {
      STB_MarkLifecycleDealProcessed(trans.deal);
      return;
   }

   cumulative=TakeAccumulatedPositionPnl(positionId);

   if(originalDirection==0)
   {
      if(positionId>0 && HistorySelectByPosition(positionId))
      {
         int deals=HistoryDealsTotal();

         for(int j=0;j<deals;j++)
         {
            ulong d=HistoryDealGetTicket(j);
            if(d==0)
               continue;

            if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN)
               continue;

            string entryComment=HistoryDealGetString(d,DEAL_COMMENT);
            if(STB_AdaptiveIsHedgeComment(entryComment))
               continue;

            long t=HistoryDealGetInteger(d,DEAL_TYPE);

            if(t==DEAL_TYPE_BUY)
            {
               originalDirection=1;
               break;
            }

            if(t==DEAL_TYPE_SELL)
            {
               originalDirection=-1;
               break;
            }
         }
      }
   }

   if(originalDirection==0)
   {
      long closedType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);
      originalDirection=(closedType==DEAL_TYPE_SELL ? 1:-1);
   }

   double rMultiple=(riskMoney>0.0 ?
                     cumulative/riskMoney:0.0);

   if(profileId>=0 &&
      profileId<STB_ADAPTIVE_PROFILE_COUNT)
   {
      STB_AdaptiveRecordClosedDeal(symbol,
                                   originalDirection,
                                   cumulative,
                                   profileId,
                                   rMultiple);
   }
   else
   {
      Print("STB ADAPTIVE close skipped: no recoverable strategy profile",
            " position=",positionId);
   }

   STB_AdaptiveDeletePositionProfile(positionId);
   STB_AdaptiveDeletePositionRisk(positionId);
   STB_MarkLifecycleDealProcessed(trans.deal);
}


void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Dashboard responsiveness: instant re-layout when the chart window
   // changes. UI-only and does not affect the click routing below.
   if(id==CHARTEVENT_CHART_CHANGE)
   {
      STB_DashSyncLayout(false);
      UpdateButtons();   // Phase 12: countdown recalculates immediately on TF/chart change
      return;
   }

   // TASK36: live group move while the user drags the panel background.
   // Only the container is draggable (buttons keep SELECTABLE=false);
   // the terminal has already moved the panel, so we adopt its new corner
   // distance as the dashboard origin, push it to all 7 controls and save.
   if(id==CHARTEVENT_OBJECT_DRAG)
   {
      if(sparam==STB_DashPanelName() && InpUiEditMode)
      {
         int nx=(int)ObjectGetInteger(0,sparam,OBJPROP_XDISTANCE);
         int ny=(int)ObjectGetInteger(0,sparam,OBJPROP_YDISTANCE);
         if(nx>=0 && ny>=0)
         {
            g_dashOriginX=nx;
            g_dashOriginY=ny;
            g_dashHasOrigin=true;
            GlobalVariableSet(g_dashStateX,g_dashOriginX);
            GlobalVariableSet(g_dashStateY,g_dashOriginY);
            STB_DashApplyLayout();
            ChartRedraw(0);
         }
      }
      return;
   }

   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   // Only our dashboard controls are actionable. Ignore all other chart
   // objects and explicitly release the OBJ_BUTTON latch after every click.
   string clicked=sparam;
   if(StringFind(clicked,g_prefix)!=0)
      return;

   bool known=(clicked==g_prefix+"AUTO" ||
               clicked==g_prefix+"BUYSTOP" ||
               clicked==g_prefix+"SELLSTOP" ||
               clicked==g_prefix+"HEDGE" ||
               clicked==g_prefix+"SAVE20");

   if(!known)
      return;

   ObjectSetInteger(0,clicked,OBJPROP_STATE,false);

   // TASK36 safety guard: while the dashboard is unlocked (edit mode) the
   // 7 trading controls are temporarily inert so a stray click during
   // placement can never fire a trade. UI-only; restored when locked.
   if(InpUiEditMode)
   {
      ChartRedraw(0);
      return;
   }

   Print("STB UI CLICK object=",clicked,
         " chart=",_Symbol,
         " tf=",EnumToString((ENUM_TIMEFRAMES)_Period));


   string autoName=g_prefix+"AUTO";
   string saveName=g_prefix+"SAVE20";
   string hedgeName=g_prefix+"HEDGE";

   if(sparam==g_prefix+"BUYSTOP")
   {
      bool ok=STB_ExecutionManualPendingCommand(_Symbol,1);
      Print("STB UI RESULT command=BUY_STOP status=",
            ok ? "EXECUTED":"REJECTED");
      return;
   }

   if(sparam==g_prefix+"SELLSTOP")
   {
      bool ok=STB_ExecutionManualPendingCommand(_Symbol,-1);
      Print("STB UI RESULT command=SELL_STOP status=",
            ok ? "EXECUTED":"REJECTED");
      return;
   }

   if(sparam==autoName)
   {
      if(InpDiagnosticM15Mode || !InpAutoTrading)
      {
         g_autoTrading=false;
         GlobalVariableSet(g_autoStateName,0.0);
         UpdateButtons();
         Print("STB AUTO TRADING LOCKED diagnostic=",
               InpDiagnosticM15Mode ? "ON":"OFF",
               " inputAuto=",InpAutoTrading ? "ON":"OFF");
         return;
      }

      g_autoTrading=!g_autoTrading;
      GlobalVariableSet(g_autoStateName,g_autoTrading ? 1.0 : 0.0);
      UpdateButtons();

      Print("STB AUTO TRADING = ",
            (g_autoTrading ? "ON":"OFF"));
      return;
   }

   if(sparam==saveName)
   {
      int completed=STB_ManagementSavePlus20Command();
      Print("STB UI RESULT command=SAVE20 status=",
            completed>0 ? "COMPLETED":"NO_ACTION",
            " positions=",IntegerToString(completed));
      return;
   }

   if(sparam==hedgeName)
   {
      int hedgeStatus=STB_ExecutionHedgeCommand();

      Print("STB UI RESULT command=HEDGE status=",
            hedgeStatus==STB_HEDGE_EXECUTED ? "EXECUTED":"REJECTED");
      return;
   }
}