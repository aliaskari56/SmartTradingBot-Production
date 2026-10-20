//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict
#property version   "1.126"
#property description "SmartTradingBot - H4 Trend + M15 CHoCH/BOS + Swing + FVG + OB + RSI/CCI + Adaptive Parameter Learning + Auto Pending + Manual Trade Manager + Advanced Dashboard + Execution Hardening"
#include <Trade/Trade.mqh>

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
input string  InpScannerSymbols         = "";   // empty = universal exposure management; explicit list scopes managed symbols   // empty = selected Market Watch; comma/semicolon separated

input group "=== ADVANCED SCANNER / ARCHITECTURE ==="
input double  InpScannerMinQuality        = 45.0;
input double  InpScannerMinScore          = 55.0;
input double  InpScannerMinTopGap         = 3.0;
input int     InpScannerMaxWatchlist      = 50;
input int     InpScannerTopN              = 10;
input int     InpScannerMaxQuoteAgeSec    = 300;
input double  InpManualPendingGapPips     = 5.0;

input group "=== TESTER REPRODUCIBILITY ==="
input bool    InpTesterForceAutoTrading  = true;  // tester only; prevents stale/missing .set state from disabling order placement
input bool    InpTesterChartSymbolOnly   = true;  // tester only; isolates the test universe to _Symbol

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
input double  InpMaxSpreadPips         = 0.0;   // 0 = disabled; optional absolute symbol-specific cap
input double  InpMaxRelativeSpreadPct   = 10.0;  // hard scanner gate: spread as % of M15 ATR; 0 disables
input int     InpSetupCooldownMinutes  = 15;
input int     InpMaxSetupAgeBars       = 4;     // maximum age of the M15 structure break before entry; 0 disables
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
input int     InpStructureWindowBars    = 30;

input group "=== SWING ==="
input int     InpSwingLeft              = 2;
input int     InpSwingRight             = 2;

input group "=== ENTRY ==="
input double  InpBaseLots               = 0.01;
input double  InpTrendLotMultiplier     = 2.0;
input double  InpUniversalLotMultiplier = 1.0;
input double  InpEntryBufferPips        = 1.0;
input double  InpPendingTrailMaxRiskExpansion = 1.0;  // Pending-trail risk ratio; hard-capped at 1.0 (no risk expansion)
input double  InpPipPointsOverride      = 0.0;  // 0 = automatic; >0 = points per pip
input double  InpSLBufferPips           = 1.0;
input double  InpInitialSLBufferPips    = 2.0;  // automatic SL: distance beyond nearest confirmed swing
input double  InpMaxInitialSLPips        = 0.0;  // 0 = disabled; strategy cap on Entry->SL distance (scalping)
input double  InpMinimumRR              = 1.0;
input int     InpMaxPendingBars         = 4;

input group "=== FVG / OB ==="
input bool    InpRequireFVG             = true;   // hard gate: missing local M15 FVG rejects the setup
input bool    InpRequireOB              = true;   // hard gate: missing local M15 Order Block rejects the setup
input bool    InpStrictPatternFilters   = false;  // legacy compatibility; true forces both local pattern gates
input int     InpPatternWindowBars      = 12;
input bool    InpRequireH4TrendAlignment = true;  // reject missing/contrary H4 directional context
input bool    InpRequireHTFConfluence   = true;   // require valid higher-timeframe FVG + Order Block confluence
input ENUM_TIMEFRAMES InpHTFPatternTF   = PERIOD_H1;
input int     InpHTFLookbackBars        = 120;
input int     InpHTFMaxZoneAgeBars      = 48;
input double  InpHTFZoneMaxGapATR       = 0.50;   // allowed zone gap as a multiple of HTF ATR
input double  InpHTFMinFVGWidthATR      = 0.05;   // reject near-zero-width HTF imbalances

input group "=== PROFIT PROTECTION ==="
input double  InpManualSaveStepPips     = 20.0;

input group "=== TRADE MANAGEMENT ==="
// SIMPLIFIED: per-magic / per-origin management flags removed (ownership scope = allowed symbol only).




input bool    InpAllowOneClickHedge      = true;

input group "=== TRENDLINE ==="
input double  InpTrendlineTolerancePips = 10.0;

input group "=== TRAILING ==="
input ENUM_TIMEFRAMES InpTrailTF        = PERIOD_M15;
input bool    InpUseStructuralTrailing  = true;  // use confirmed swing structure instead of live-price distance
input double  InpStructuralTrailStartATR = 1.0;  // favorable move required before structural trailing starts
input double  InpStructuralTrailBufferATR = 0.15; // SL buffer outside a confirmed swing
input double  InpTrailStartPips         = 150.0;  // used only when structural trailing is disabled
input double  InpLiveTrailDistancePips   = 30.0;  // legacy live-distance trail when structural mode is disabled
input double  InpTrailStepPips             = 5.0;   // minimum SL improvement before a new trailing modification

bool g_modifyWasNoChanges=false;

//==================================================================
// UNIVERSAL PROFIT LOCK POLICY
// Mandatory and identical for EVERY managed position regardless of origin:
// EA / manual / mobile / magic==InpMagic / magic==0 / foreign magic /
// chart-key / HEDGE / pending-trigger / pre-existing / restart-recovered.
//
//   profit <  +50 pip  ->  no auto profit lock
//   profit >= +50 pip  ->  lock at least +20 pip
//        BUY : Locked SL = Entry + 20 pip
//        SELL: Locked SL = Entry - 20 pip
//
// Single central chain (no side paths):
//   Universal Position Intake -> STB_ProfitProtectionOne -> ApplyProfitLock
//   -> STB_SubmitPositionSL -> STB_ResolvePositionSL -> ModifyPositionSL
//==================================================================
#define STB_PROFIT_LOCK_TRIGGER_PIPS 50.0   // mandatory trigger: profit below this -> no lock
#define STB_PROFIT_LOCK_MIN_PIPS     20.0   // mandatory minimum lock once triggered

double STB_ProfitLockTriggerPips()
  {
   return STB_PROFIT_LOCK_TRIGGER_PIPS;
  }

double STB_ProfitLockLockPips()
  {
   // Mandatory policy value; stray .set / chart inputs must never change it.
   double configured=STB_PROFIT_LOCK_MIN_PIPS;
   if(configured<STB_PROFIT_LOCK_MIN_PIPS)
      configured=STB_PROFIT_LOCK_MIN_PIPS;
   return configured;
  }

//==================================================================
// STRUCTURES
//==================================================================

struct SwingPoint
  {
   int               shift;
   datetime          time;
   double            price;
   bool              isHigh;
  };

struct TrendInfo
  {
   string            bias;
   bool              valid;
   int               touches;
   datetime          t1;
   datetime          t2;
   double            p1;
   double            p2;
  };

struct OscillatorState
  {
   double            rsi1;
   double            rsi2;
   double            cci1;
   double            cci2;
   bool              buyConfirmed;
   bool              sellConfirmed;
   bool              valid;
  };

struct STBIndicatorCache
  {
   string            symbol;
   int               rsiHandle;
   int               cciHandle;
  };



struct Setup
  {
   bool              valid;
   string            symbol;
   int               direction;
   bool              trendAligned;

   int               chochShift;
   int               bosShift;
   int               originShift;
   int               fvgShift;

   double            originHigh;
   double            originLow;

   double            swingHigh;
   double            swingLow;

   double            entry;
   double            sl;
   double            tp;
   double            rr;

   double            score;
   int               adaptiveProfile;

   double            entryBufferPips;

   datetime          setupTime;
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
   int               id;
   int               swingLeft;
   int               swingRight;
   int               maxSetupAgeBars;
   int               patternWindowBars;
   int               maxPendingBars;
   double            entryBufferPips;
   double            slBufferPips;
   double            minimumRR;
   double            rsiBuyLevel;
   double            rsiSellLevel;
   double            cciBuyLevel;
   double            cciSellLevel;
   double            rsiWeight;
   double            cciWeight;
  };

struct STBDiagnosticState
  {
   string            symbol;
   int               direction;
   datetime          lastBar;
   string            lastReason;
   datetime          lastReadyBar;
  };

STBAdaptiveProfile g_activeAdaptiveProfile;
bool               g_activeAdaptiveProfileValid=false;
int                g_activeAdaptiveProfileId=0;
string             g_lastBuildRejectReason="UNKNOWN";
STBDiagnosticState g_diagnosticStates[];
string             g_dashboardLastAction="EA INITIALIZED";
bool               g_dashHidden=false;
datetime           g_lastSignalScanBar=0;
int                g_panelScanSymbols=0;
int                g_panelScanTradable=0;
int                g_panelScanBuyReady=0;
int                g_panelScanSellReady=0;
int                g_panelScanPlacements=0;
datetime           g_panelLastScanTime=0;
bool               g_panelChartBuyReady=false;
bool               g_panelChartSellReady=false;
double             g_panelChartBuyScore=0.0;
double             g_panelChartSellScore=0.0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string STB_AP_Key(const string symbol,
                  const int direction,
                  const string scope,
                  const int profile=-1)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP3|"+symbol+"|"+
              (direction>0 ? "B":"S")+"|"+
              scope+"|"+(string)profile;

   // Do not read or mutate live adaptive statistics from Strategy Tester.
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER";

   return "STB_AP3_"+(string)STB_AP_Hash(raw);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_Write(const string symbol,
                  const int direction,
                  const string scope,
                  const int profile,
                  const double value)
  {
   GlobalVariableSet(STB_AP_Key(symbol,direction,scope,profile),value);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

// Profile attempts are tracked separately from closed-trade outcomes.
// This prevents a parameter profile that produces no executable setup
// from remaining the least-sampled arm forever.
double STB_AP_ReadAttempts(const string symbol,
                           const int direction,
                           const int profile)
  {
   return MathMax(0.0,
                  STB_AP_Read(symbol,direction,"A",profile,0.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_RecordAttempt(const string symbol,
                          const int direction,
                          const int profile)
  {
   if(profile<0 || profile>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

// Scanner calls can happen repeatedly during one M15 bar. Count a
// profile probe at most once per closed signal bar so the learner
// measures genuine exploration rather than timer frequency.
   datetime closedBar=iTime(symbol,PERIOD_M15,1);

   if(closedBar<=0)
      return;

   datetime lastProbe=(datetime)STB_AP_Read(
                         symbol,direction,"ABAR",profile,0.0);

   if(lastProbe==closedBar)
      return;

   STB_AP_Write(symbol,direction,"ABAR",profile,(double)closedBar);

   double attempts=STB_AP_ReadAttempts(symbol,direction,profile);
   STB_AP_Write(symbol,direction,"A",profile,attempts+1.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AP_FindLeastSampled(const string symbol,
                            const int direction)
  {
   int best=0;
   double bestAttempts=DBL_MAX;

   ulong tieSeed=STB_AP_Hash(symbol+"|"+
                             (direction>0 ? "B":"S")+"|"+
                             (string)((long)(TimeCurrent()/900)));

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
     {
      double attempts=STB_AP_ReadAttempts(symbol,direction,p);

      if(attempts+1e-9<bestAttempts)
        {
         bestAttempts=attempts;
         best=p;
        }
      else
         if(MathAbs(attempts-bestAttempts)<=1e-9)
           {
            if((int)(tieSeed%STB_ADAPTIVE_PROFILE_COUNT)==p)
               best=p;
           }
     }

   return best;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AP_SelectProfile(const string symbol,
                         const int direction)
  {
   if(!InpAdaptiveLearning || !InpAdaptiveParameterLearning)
      return 0;

// The first exploration gate is based on profile probes, not closed
// trades. A fresh tester/account must be able to leave Profile 0 even
// before the first position has closed.
   double totalStartupAttempts=0.0;

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
      totalStartupAttempts+=STB_AP_ReadAttempts(symbol,direction,p);

   if(totalStartupAttempts<=0.0)
      return 0;

   if(InpAdaptiveWarmupPerProfile>0)
     {
      for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
        {
         double attempts=STB_AP_ReadAttempts(symbol,direction,p);

         if(attempts+1e-9 < (double)InpAdaptiveWarmupPerProfile)
            return STB_AP_FindLeastSampled(symbol,direction);
        }
     }

   double totalOutcomeSamples=0.0;
   double totalAttempts=0.0;

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
     {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);
      totalOutcomeSamples+=wins+losses;
      totalAttempts+=STB_AP_ReadAttempts(symbol,direction,p);
     }

   int best=0;
   double bestValue=-DBL_MAX;
   double logOutcome=MathLog(1.0+totalOutcomeSamples);
   double logAttempts=MathLog(1.0+totalAttempts);

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
     {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);

      double outcomeSamples=wins+losses;
      double attempts=STB_AP_ReadAttempts(symbol,direction,p);

      double smoothedWinRate=(wins+1.0)/(outcomeSamples+2.0);

      double observations=0.0;
      double averageR=STB_AdaptiveReadProfileR(symbol,direction,p,observations);
      double rSignal=MathMax(-1.0,MathMin(2.0,averageR));

      // Two uncertainty channels are kept separate:
      // 1) trade-outcome uncertainty, based only on closed trades;
      // 2) exploration scarcity, based on profile probes.
      // Thus rejected/non-executable profiles are still explored, while
      // their lack of a trade is never misclassified as a win or loss.
      double outcomeExploration=
         MathMax(0.0,InpAdaptiveUCBExploration)*
         MathSqrt(logOutcome/(outcomeSamples+1.0));

      double probeExploration=
         0.50*MathMax(0.0,InpAdaptiveUCBExploration)*
         MathSqrt(logAttempts/(attempts+1.0));

      double value=
         0.45*smoothedWinRate+
         0.25*(rSignal/2.0+0.5)+
         0.15*outcomeExploration+
         0.15*probeExploration;

      if(value>bestValue)
        {
         bestValue=value;
         best=p;
        }
     }

   return best;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_SetActive(const int profileId)
  {
   STB_AP_LoadProfile(profileId,g_activeAdaptiveProfile);
   g_activeAdaptiveProfileValid=true;
   g_activeAdaptiveProfileId=g_activeAdaptiveProfile.id;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_SelectActive(const string symbol,
                         const int direction)
  {
   STB_AP_SetActive(STB_AP_SelectProfile(symbol,direction));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_ClearActive()
  {
   g_activeAdaptiveProfileValid=false;
   g_activeAdaptiveProfileId=0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveSwingLeft(const ENUM_TIMEFRAMES tf)
  {
   if(tf==PERIOD_M15 && g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.swingLeft;

   return InpSwingLeft;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveSwingRight(const ENUM_TIMEFRAMES tf)
  {
   if(tf==PERIOD_M15 && g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.swingRight;

   return InpSwingRight;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectivePatternWindow()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.patternWindowBars;

   return InpPatternWindowBars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveMaxSetupAgeBars()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.maxSetupAgeBars;

   return InpMaxSetupAgeBars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveMaxPendingBars()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.maxPendingBars;

   return InpMaxPendingBars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveEntryBuffer()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.entryBufferPips;

   return InpEntryBufferPips;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveSLBuffer()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.slBufferPips;

   return InpSLBufferPips;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveMinimumRR()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.minimumRR;

   return InpMinimumRR;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveRSIBuy()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiBuyLevel;

   return InpRSIBuyLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveRSISell()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiSellLevel;

   return InpRSISellLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveCCIBuy()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciBuyLevel;

   return InpCCIBuyLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveCCISell()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciSellLevel;

   return InpCCISellLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveRSIWeight()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiWeight;

   return InpRSIWeight;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveCCIWeight()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciWeight;

   return InpCCIWeight;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   else
      if(winRate>InpAdaptiveStrongWinRate)
         floor-=MathAbs(InpAdaptiveStep);

   return MathMax(InpAdaptiveMinScore,
                  MathMin(InpAdaptiveMaxScore,floor));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRecordSetup(const Setup &s,const bool accepted)
  {
   if(!InpAdaptiveLearning || s.setupTime<=0)
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberLastProfile(const string symbol,
                                     const int direction,
                                     const int profileId)
  {
   if(profileId<0 || profileId>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   STB_AP_Write(symbol,direction,"LASTP",0,profileId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string STB_AdaptiveOrderRaw(const ulong orderTicket)
  {
   return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
          (string)InpMagic+"|AP3|ORDER|"+(string)orderTicket;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberOrderRisk(const ulong orderTicket,
                                   const double riskMoney)
  {
   if(orderTicket==0 || riskMoney<=0.0 || !MathIsValidNumber(riskMoney))
      return;

   STB_AP_Write("ORDER_RISK",1,
                STB_AdaptiveOrderRaw(orderTicket),
                0,riskMoney);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveReadOrderRisk(const ulong orderTicket)
  {
   if(orderTicket==0)
      return 0.0;

   return MathMax(0.0,
                  STB_AP_Read("ORDER_RISK",1,
                              STB_AdaptiveOrderRaw(orderTicket),
                              0,0.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveDeleteOrderState(const ulong orderTicket)
  {
   if(orderTicket==0)
      return;

   GlobalVariableDel(STB_AP_Key("ORDER_PROFILE",1,
                                STB_AdaptiveOrderRaw(orderTicket),0));
   GlobalVariableDel(STB_AP_Key("ORDER_RISK",1,
                                STB_AdaptiveOrderRaw(orderTicket),0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string STB_AdaptivePositionRaw(const ulong positionId)
  {
   return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
          (string)InpMagic+"|AP3|POS|"+(string)positionId;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberPositionRisk(const ulong positionId,
                                      const double riskMoney)
  {
   if(positionId==0 || riskMoney<=0.0 || !MathIsValidNumber(riskMoney))
      return;

   STB_AP_Write("POSITION_RISK",1,
                STB_AdaptivePositionRaw(positionId),
                0,riskMoney);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveReadPositionRisk(const ulong positionId)
  {
   if(positionId==0)
      return 0.0;

   return MathMax(0.0,
                  STB_AP_Read("POSITION_RISK",1,
                              STB_AdaptivePositionRaw(positionId),
                              0,0.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveDeletePositionRisk(const ulong positionId)
  {
   if(positionId==0)
      return;

   GlobalVariableDel(
      STB_AP_Key("POSITION_RISK",1,
                 STB_AdaptivePositionRaw(positionId),0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveReadProfileR(const string symbol,
                                const int direction,
                                const int profile,
                                double &observations)
  {
   double decay=STB_AP_Decay(symbol,direction,profile);
   double sumR=STB_AP_Read(symbol,direction,"RSUM",profile,0.0)*decay;
   double rObservations=STB_AP_Read(symbol,direction,"RCOUNT",profile,0.0)*decay;

   // R expectancy is averaged only over closed trades whose initial
   // monetary risk was captured reliably. Missing risk must not dilute the
   // average toward zero through the win/loss denominator.
   observations=MathMax(0.0,rObservations);
   if(observations<=0.0)
      return 0.0;

   return sumR/observations;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AdaptiveReadPositionProfile(const ulong positionId)
  {
   if(positionId==0)
      return -1;

   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP3|POS|"+(string)positionId;

   int profile=(int)MathRound(
                  STB_AP_Read("POSITION",1,raw,0,-1.0));

   return (profile>=0 && profile<STB_ADAPTIVE_PROFILE_COUNT) ?
          profile:-1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveDeletePositionProfile(const ulong positionId)
  {
   if(positionId==0)
      return;

   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP3|POS|"+(string)positionId;

   GlobalVariableDel(STB_AP_Key("POSITION",1,raw,0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AdaptiveParseProfileFromComment(const string comment)
  {
   int pos=StringFind(comment,"|P");
   if(pos<0)
      return -1;

   int id=(int)StringToInteger(StringSubstr(comment,pos+2));

   return (id>=0 && id<STB_ADAPTIVE_PROFILE_COUNT) ? id:-1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_AdaptiveIsHedgeComment(const string comment)
  {
   return StringFind(comment,"HEDGE")>=0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRecordClosedDeal(const string symbol,
                                  const int direction,
                                  const double profit,
                                  const int profileId,
                                  const double rMultiple,
                                  const bool hasValidRiskSample)
  {
   if(!InpAdaptiveLearning || direction==0 ||
      !MathIsValidNumber(profit))
      return;

   if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
     {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,profileId,wins,losses);

      // A genuine break-even lifecycle is one neutral observation, not a
      // missing sample: split it equally between wins and losses so it moves
      // the smoothed win rate toward 50% without inventing an edge.
      if(profit>0.0)
         wins+=1.0;
      else if(profit<0.0)
         losses+=1.0;
      else
        {
         wins+=0.5;
         losses+=0.5;
        }

      STB_AP_Write(symbol,direction,"W",profileId,wins);
      STB_AP_Write(symbol,direction,"L",profileId,losses);

      double decay=STB_AP_Decay(symbol,direction,profileId);
      double oldRSum=STB_AP_Read(symbol,direction,
                                 "RSUM",profileId,0.0)*decay;
      double oldRCount=STB_AP_Read(symbol,direction,
                                   "RCOUNT",profileId,0.0)*decay;

      // Keep expectancy in R separate from the win/loss sample count. Only
      // trades with a known positive initial-risk denominator enter this mean.
      if(hasValidRiskSample && MathIsValidNumber(rMultiple))
        {
         oldRSum+=rMultiple;
         oldRCount+=1.0;
        }

      STB_AP_Write(symbol,direction,"RSUM",profileId,oldRSum);
      STB_AP_Write(symbol,direction,"RCOUNT",profileId,oldRCount);
      STB_AP_Write(symbol,direction,"T",profileId,(double)TimeCurrent());
     }

   Print("STB ADAPTIVE outcome symbol=",symbol,
         " dir=",(direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(profileId),
         " outcome=",DoubleToString(profit,2),
         " R=",hasValidRiskSample ? DoubleToString(rMultiple,2):"UNAVAILABLE",
         " floor=",DoubleToString(STB_AdaptiveScoreFloor(symbol,direction),1));

   STB_AdaptiveLog("TRADE_CLOSED",symbol,direction,
                   0.0,0.0,profit,profileId);

   GlobalVariablesFlush();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_BuildReject(const string symbol,
                     const int direction,
                     const string reason)
  {
   g_lastBuildRejectReason=reason;
   STB_LogBuildReject(symbol,direction,reason);
   STB_AP_ClearActive();
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
      if(ArrayResize(g_diagnosticStates,idx+1)!=idx+1)
        {
         Print("STB diagnostic state allocation failed symbol=",symbol,
               " direction=",direction);
         return;
        }
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
      if(ArrayResize(g_diagnosticStates,idx+1)!=idx+1)
        {
         Print("STB ready-state diagnostic allocation failed symbol=",s.symbol,
               " direction=",s.direction);
         return;
        }
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
bool g_stbManagementCycleActive = false;
bool g_stbManagementCyclePending = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// GENERAL UTILITY
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Upper(const string value)
  {
   string s = value;
   StringToUpper(s);
   return s;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(const string symbol,double volume)
  {
   double minLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   // Never turn a disabled/zero-volume request or an undersized request into
   // the broker minimum. That can silently turn a 0x multiplier into a trade
   // or increase the exposure beyond the configured fixed/risk volume.
   if(!MathIsValidNumber(volume) || volume<=0.0 ||
      minLot<=0.0 || maxLot<minLot || step<=0.0)
      return 0.0;

   if(volume+1e-9<minLot)
      return 0.0;

   volume=MathMin(maxLot,volume);
   volume=MathFloor(volume/step+1e-9)*step;

   // Floating point flooring can dip just below a valid minimum. Use the
   // broker minimum only when the original request already met that minimum.
   if(volume<minLot)
      volume=minLot;

   int digits=2;
   if(step<0.01)
      digits=3;
   if(step<0.001)
      digits=4;

   double normalized=NormalizeDouble(volume,digits);
   if(normalized<minLot-1e-9 || normalized>maxLot+1e-9)
      return 0.0;

   return normalized;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetRates(const string symbol,
              const ENUM_TIMEFRAMES tf,
              const int count,
              MqlRates &rates[])
  {
   if(count<=0 || !SymbolSelect(symbol,true))
      return false;

   if(!SymbolIsSynchronized(symbol))
      return false;

   ArraySetAsSeries(rates,true);

   int copied=CopyRates(symbol,tf,0,count,rates);

   return copied>=count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_TradeEnvironmentAllowed()
  {
   bool terminalAllowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   bool programAllowed=(MQLInfoInteger(MQL_TRADE_ALLOWED)!=0);
   bool accountAllowed=(AccountInfoInteger(ACCOUNT_TRADE_EXPERT)!=0);
   bool accountTradeAllowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);

   if(!terminalAllowed || !programAllowed ||
      !accountAllowed || !accountTradeAllowed)
     {
      Print("STB TRADE ENV REJECT",
            " terminal=",terminalAllowed ? "ON":"OFF",
            " program=",programAllowed ? "ON":"OFF",
            " expert=",accountAllowed ? "ON":"OFF",
            " accountTrade=",accountTradeAllowed ? "ON":"OFF",
            " tester=",MQLInfoInteger(MQL_TESTER) ? "YES":"NO");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeRetcodeModifySucceeded()
  {
   uint ret=trade.ResultRetcode();

   return ret==TRADE_RETCODE_DONE ||
          ret==TRADE_RETCODE_DONE_PARTIAL ||
          ret==TRADE_RETCODE_NO_CHANGES ||
          ret==TRADE_RETCODE_ORDER_CHANGED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeRetcodePlacementSucceeded()
  {
   uint ret=trade.ResultRetcode();

   return ret==TRADE_RETCODE_DONE ||
          ret==TRADE_RETCODE_DONE_PARTIAL ||
          ret==TRADE_RETCODE_PLACED ||
          ret==TRADE_RETCODE_NO_CHANGES;
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
//==================================================================
// CENTRALIZED PENDING GEOMETRY CONTRACT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ValidatePendingGeometry(const string symbol,
                                 const int direction,
                                 const double entry,
                                 const double sl,
                                 const double tp,
                                 const bool requireTP,
                                 const double minimumRR,
                                 string &reason)
  {
   reason="OK";

   if(direction!=1 && direction!=-1)
     {
      reason="INVALID_DIRECTION";
      return false;
     }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
     {
      reason="NO_TICK";
      return false;
     }

   double minDist=TradeMinDistance(symbol);
   if(minDist<=0.0 || entry<=0.0 || sl<=0.0)
     {
      reason="INVALID_GEOMETRY";
      return false;
     }

   double risk=0.0;

   if(direction>0)
     {
      if(entry<=tick.ask+minDist)
        {
         reason="BUY_ENTRY_TOO_CLOSE";
         return false;
        }

      if(sl>=entry || tick.bid-sl<minDist)
        {
         reason="BUY_SL_INVALID";
         return false;
        }

      risk=entry-sl;

      if(requireTP && (tp<=entry || tp-entry<minDist))
        {
         reason="BUY_TP_INVALID";
         return false;
        }
     }
   else
     {
      if(entry>=tick.bid-minDist)
        {
         reason="SELL_ENTRY_TOO_CLOSE";
         return false;
        }

      if(sl<=entry || sl-tick.ask<minDist)
        {
         reason="SELL_SL_INVALID";
         return false;
        }

      risk=sl-entry;

      if(requireTP && (tp>=entry || entry-tp<minDist))
        {
         reason="SELL_TP_INVALID";
         return false;
        }
     }

   if(risk<=0.0)
     {
      reason="RISK_INVALID";
      return false;
     }

   if(requireTP)
     {
      double reward=MathAbs(tp-entry);
      double rr=reward/risk;

      if(reward<=0.0 || rr+1e-9<MathMax(0.0,minimumRR))
        {
         reason="RR_BELOW_MINIMUM";
         return false;
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- P4: pending geometry policy helpers (single source of truth) ---
// Entry direction per pending type: never one generic rule for all types.
int STB_PendingEntryImproveSign(const long orderType)
  {
   if(STB_PendingIsBuySide((ENUM_ORDER_TYPE)orderType))
      return 1;
   if(STB_PendingIsSellSide((ENUM_ORDER_TYPE)orderType))
      return -1;
   return 0;
  }

bool STB_PendingEntryDirectionOK(const long orderType,const double curEntry,
                                 const double newEntry,const double tolerance)
  {
   if(curEntry<=0.0 || newEntry<=0.0)
      return false;

   int sign=STB_PendingEntryImproveSign(orderType);

   if(sign>0)
      return (newEntry<=curEntry+tolerance);   // BUY_* : entry may only move down
   if(sign<0)
      return (newEntry>=curEntry-tolerance);   // SELL_*: entry may only move up

   return false;
  }

bool STB_PendingRiskFloorOK(const long orderType,const double curEntry,
                            const double curSL,const double newEntry,
                            const double newSL)
  {
   if(curSL<=0.0 || curEntry<=0.0)
      return true;   // no current SL -> initial structural SL may be created

   double origRisk=MathAbs(curEntry-curSL);
   double newRisk=MathAbs(newEntry-newSL);

   if(origRisk<=0.0)
      return true;

   double cap=MathMin(1.0,(InpPendingTrailMaxRiskExpansion>0.0 ? InpPendingTrailMaxRiskExpansion : 1.0)); // P9 HARD CAP: pending-trail risk can never expand beyond 1.0

   return (newRisk<=origRisk*cap);
  }

bool STB_ModifyPendingOrderGeometry(const ulong ticket,
                                    const double newEntry,
                                    const double newSL,
                                    const double newTP,
                                    const bool isUserAction=false)
  {
   if(ticket==0 || !OrderSelect(ticket))
      return false;

   string symbol=OrderGetString(ORDER_SYMBOL); if(!IsManagedOrder(ticket)) return false; // P1 writer safety barrier
   if(STB_ExposureEnsure(ticket,false)<0)
     {
      Print("STB PENDING MODIFY DEFERRED ticket=",ticket,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return false;
     }
   if(!STB_SymbolManagementOwnedVerified(symbol)) return false; // P6/P10 cross-instance single pending writer

   //--- P4 central writer: verify symbol, re-read geometry, validate
   //--- broker constraints, monotonic entry direction and risk floor.
   long stbOt=OrderGetInteger(ORDER_TYPE);
   // Manual/mobile/foreign pending orders remain under the universal manager.
   // Override metadata may control local expiry policy, never SL/trailing protection.
   double stbCurEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double stbCurSL=OrderGetDouble(ORDER_SL);
   double stbCurTP=OrderGetDouble(ORDER_TP);
   double stbPoint=SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(!IsValidSLForPendingOrder(symbol,(ENUM_ORDER_TYPE)stbOt,newEntry,newSL))
      return false;

   if(!STB_PendingEntryDirectionOK(stbOt,stbCurEntry,newEntry,stbPoint*0.5))
      return false;

   if(!STB_PendingRiskFloorOK(stbOt,stbCurEntry,stbCurSL,newEntry,newSL))
      return false;


   if(newEntry<=0.0)
      return false;

   ENUM_ORDER_TYPE_TIME typeTime=
      (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   double stopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);

   // Keep a Stop-Limit's trigger-to-limit offset when trailing its trigger.
   // Leaving stoplimit unchanged would detach the child limit price from the
   // moved stop price and can make a valid order invalid or behave differently.
   if(stbOt==ORDER_TYPE_BUY_STOP_LIMIT ||
      stbOt==ORDER_TYPE_SELL_STOP_LIMIT)
     {
      if(stbCurEntry<=0.0 || stopLimit<=0.0)
         return false;

      double stopLimitOffset=stopLimit-stbCurEntry;
      stopLimit=NormalizePrice(symbol,newEntry+stopLimitOffset);

      bool offsetValid=(stopLimit>0.0 &&
                        ((stbOt==ORDER_TYPE_BUY_STOP_LIMIT && stopLimit<newEntry) ||
                         (stbOt==ORDER_TYPE_SELL_STOP_LIMIT && stopLimit>newEntry)));

      if(!offsetValid)
        {
         Print("STB STOP-LIMIT MODIFY REJECT ticket=",ticket,
               " symbol=",symbol,
               " oldEntry=",DoubleToString(stbCurEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " newEntry=",DoubleToString(newEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " newStopLimit=",DoubleToString(stopLimit,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
         return false;
        }
     }

   // One broker geometry write per ticket per management cycle. This also
   // prevents ManagePendingOrders' initial-SL repair and the trailing engine
   // from both modifying the same pending ticket in one cycle.
   if(STB_CycleWriteAlreadyDone(ticket))
      return false;

   MqlTradeRequest req={};
   MqlTradeCheckResult check={};

   req.action=TRADE_ACTION_MODIFY;
   req.order=ticket;
   req.symbol=symbol;
   req.price=newEntry;
   req.sl=newSL;
   req.tp=newTP;
   req.type_time=typeTime;
   req.expiration=expiration;
   req.stoplimit=stopLimit;

   ResetLastError();

   if(!OrderCheck(req,check))
      return false;

   // OrderCheck success is retcode=0 in this terminal/broker path.
   if(check.retcode!=0)
     {
      Print("STB PENDING MODIFY ORDERCHECK REJECT ticket=",ticket,
            " symbol=",symbol,
            " ret=",IntegerToString((int)check.retcode),
            " comment=",check.comment);
      return false;
     }

   // OrderCheck can take time. Re-read the ticket and verify that both the
   // symbol-writer lease and the geometry snapshot are still ours to modify.
   if(!OrderSelect(ticket) || !IsManagedOrder(ticket))
      return false;
   if(OrderGetString(ORDER_SYMBOL)!=symbol ||
      OrderGetInteger(ORDER_TYPE)!=stbOt)
      return false;
   // Do not re-enable a manual-override pause after OrderCheck: every
   // managed pending order remains eligible for automatic protection/trailing.
   double latestEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double latestSL=OrderGetDouble(ORDER_SL);
   double latestTP=OrderGetDouble(ORDER_TP);
   double latestPoint=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double latestTickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double latestTolerance=MathMax(latestPoint*0.5,
                                  latestTickSize>0.0 ? latestTickSize*0.5:latestPoint*0.5);
   if(MathAbs(latestEntry-stbCurEntry)>latestTolerance ||
      MathAbs(latestSL-stbCurSL)>latestTolerance ||
      MathAbs(latestTP-stbCurTP)>latestTolerance)
      return false;

   if(!STB_SymbolManagementOwnedVerified(symbol) ||
      !IsValidSLForPendingOrder(symbol,(ENUM_ORDER_TYPE)stbOt,newEntry,newSL) ||
      !STB_PendingEntryDirectionOK(stbOt,latestEntry,newEntry,latestTolerance) ||
      !STB_PendingRiskFloorOK(stbOt,latestEntry,latestSL,newEntry,newSL))
      return false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   // Consume the ticket's one-write budget before the broker request. A
   // timeout or ambiguous response may still have changed server state; do not
   // issue a second geometry write for this ticket in the same cycle.
   STB_CycleMarkWritten(ticket);

   if(!trade.OrderModify(ticket,newEntry,newSL,newTP,
                         typeTime,expiration,stopLimit))
     {
      if(OrderSelect(ticket))
         STB_GeomStore(ticket,false,
                       OrderGetDouble(ORDER_PRICE_OPEN),
                       OrderGetDouble(ORDER_SL),
                       OrderGetDouble(ORDER_TP));
      return false;
     }

   if(!TradeRetcodeModifySucceeded())
     {
      if(OrderSelect(ticket))
         STB_GeomStore(ticket,false,
                       OrderGetDouble(ORDER_PRICE_OPEN),
                       OrderGetDouble(ORDER_SL),
                       OrderGetDouble(ORDER_TP));
      return false;
     }

   if(!OrderSelect(ticket))
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tolerance=MathMax(point*0.5,
                            tickSize>0.0 ? tickSize*0.5:point*0.5);

   long verifiedType=OrderGetInteger(ORDER_TYPE);
   double ve=OrderGetDouble(ORDER_PRICE_OPEN);
   double vs=OrderGetDouble(ORDER_SL);
   double vt=OrderGetDouble(ORDER_TP);
   double verifiedStopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);
   bool isStopLimit=(stbOt==ORDER_TYPE_BUY_STOP_LIMIT ||
                     stbOt==ORDER_TYPE_SELL_STOP_LIMIT);

   if(verifiedType!=stbOt ||
      MathAbs(ve-newEntry)>tolerance ||
      MathAbs(vs-newSL)>tolerance ||
      MathAbs(vt-newTP)>tolerance ||
      (isStopLimit && MathAbs(verifiedStopLimit-stopLimit)>tolerance))
     {
      // Cache the actual server geometry, never an unconfirmed proposal.
      // Stop-limit tickets also verify the child limit price, not just the
      // trigger Entry/SL/TP. A broker-side mismatch is not a committed trail.
      STB_GeomStore(ticket,false,ve,vs,vt);
      Print("STB PENDING MODIFY POSTCHECK FAILED ticket=",ticket,
            " symbol=",symbol,
            " expectedType=",EnumToString((ENUM_ORDER_TYPE)stbOt),
            " actualType=",EnumToString((ENUM_ORDER_TYPE)verifiedType),
            " entryExpected=",DoubleToString(newEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " entryActual=",DoubleToString(ve,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopLimitExpected=",DoubleToString(stopLimit,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopLimitActual=",DoubleToString(verifiedStopLimit,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
     }

   STB_GeomStore(ticket,false,ve,vs,vt); // MANUAL_OVERRIDE: verified own write only
   STB_CycleMarkWritten(ticket); // one pending geometry write per cycle
   return true;
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

   if(point<=0.0)
      return false;

   if(minDist<=0.0)
      minDist=point;

   double oldEntry=s.entry;
   double oldSL=s.sl;
   double oldTP=s.tp;

   if(s.direction>0)
     {
      // A BUY STOP whose planned trigger is already at/below the live Ask
      // is stale, not merely too close to the broker's stop distance. Reject
      // it instead of chasing price upward and manufacturing a late entry.
      if(s.entry<=tick.ask)
        {
         Print("STB setup rejected: BUY STOP trigger already crossed symbol=",
               s.symbol,
               " planned=",DoubleToString(s.entry,digits),
               " ask=",DoubleToString(tick.ask,digits));
         return false;
        }

      double minEntry=tick.ask+minDist;
      if(s.entry<minEntry)
         s.entry=minEntry;

      double maxSL=tick.bid-minDist;
      double entrySL=s.entry-minDist;

      // If the pattern-derived SL is too close to the live market, do not
      // replace it with a broker-minimum-distance stop. Rebuild from confirmed
      // structure; reject the setup if no valid structural stop exists.
      if(s.sl>maxSL)
        {
         double structuralSL=0.0;

         if(!CalculateInitialProtectionSL(s.symbol,
                                           POSITION_TYPE_BUY,
                                           s.entry,
                                           structuralSL) ||
            structuralSL>maxSL ||
            structuralSL>=entrySL)
           {
            Print("STB setup rejected: BUY structural SL unresolved symbol=",s.symbol);
            return false;
           }

         s.sl=structuralSL;
        }

      if(s.sl>=s.entry)
        {
         Print("STB setup rejected: BUY SL is not structurally below entry symbol=",s.symbol);
         return false;
        }

      SwingPoint highs[];
      SwingPoint lows[];
      if(CollectSwings(s.symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
         return false;

      double risk=s.entry-s.sl;
      double target=DBL_MAX;

      for(int i=0;i<ArraySize(highs);i++)
        {
         double candidate=highs[i].price;
         if(candidate<=s.entry)
            continue;

         if(candidate-s.entry+1e-12 < risk*STB_EffectiveMinimumRR())
            continue;

         if(candidate<target)
            target=candidate;
        }

      if(target==DBL_MAX || target<=s.entry+minDist)
        {
         Print("STB setup rejected after broker normalization: BUY TP is too close or no RR target symbol=",s.symbol,
               " entry=",DoubleToString(s.entry,digits),
               " sl=",DoubleToString(s.sl,digits),
               " minRR=",DoubleToString(STB_EffectiveMinimumRR(),2));
         return false;
        }

      s.tp=NormalizePrice(s.symbol,target);
     }
   else
     {
      // A SELL STOP whose planned trigger is already at/above the live Bid
      // has already been crossed. Reject rather than pushing it lower and
      // entering after the original breakdown level has passed.
      if(s.entry>=tick.bid)
        {
         Print("STB setup rejected: SELL STOP trigger already crossed symbol=",
               s.symbol,
               " planned=",DoubleToString(s.entry,digits),
               " bid=",DoubleToString(tick.bid,digits));
         return false;
        }

      double maxEntry=tick.bid-minDist;
      if(s.entry>maxEntry)
         s.entry=maxEntry;

      double minSL=tick.ask+minDist;
      double entrySL=s.entry+minDist;

      // If the pattern-derived SL is too close to the live market, do not
      // replace it with a broker-minimum-distance stop. Rebuild from confirmed
      // structure; reject the setup if no valid structural stop exists.
      if(s.sl<minSL)
        {
         double structuralSL=0.0;

         if(!CalculateInitialProtectionSL(s.symbol,
                                           POSITION_TYPE_SELL,
                                           s.entry,
                                           structuralSL) ||
            structuralSL<minSL ||
            structuralSL<=entrySL)
           {
            Print("STB setup rejected: SELL structural SL unresolved symbol=",s.symbol);
            return false;
           }

         s.sl=structuralSL;
        }

      if(s.sl<=s.entry)
        {
         Print("STB setup rejected: SELL SL is not structurally above entry symbol=",s.symbol);
         return false;
        }

      SwingPoint highs[];
      SwingPoint lows[];
      if(CollectSwings(s.symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
         return false;

      double risk=s.sl-s.entry;
      double target=-DBL_MAX;

      for(int i=0;i<ArraySize(lows);i++)
        {
         double candidate=lows[i].price;
         if(candidate>=s.entry)
            continue;

         if(s.entry-candidate+1e-12 < risk*STB_EffectiveMinimumRR())
            continue;

         if(candidate>target)
            target=candidate;
        }

      if(target==-DBL_MAX || target>=s.entry-minDist)
        {
         Print("STB setup rejected after broker normalization: SELL TP is too close or no RR target symbol=",s.symbol,
               " entry=",DoubleToString(s.entry,digits),
               " sl=",DoubleToString(s.sl,digits),
               " minRR=",DoubleToString(STB_EffectiveMinimumRR(),2));
         return false;
        }

      s.tp=NormalizePrice(s.symbol,target);
     }

   s.entry=NormalizePrice(s.symbol,s.entry);
   s.sl=NormalizePrice(s.symbol,s.sl);
   s.tp=NormalizePrice(s.symbol,s.tp);

   double risk=MathAbs(s.entry-s.sl);
   double reward=MathAbs(s.tp-s.entry);

   if(risk<=0.0 || reward<=0.0)
      return false;

   if(InpMaxInitialSLPips>0.0 &&
      risk>InpMaxInitialSLPips*PipSize(s.symbol))
     {
      Print("STB setup rejected: structural risk exceeds InpMaxInitialSLPips symbol=",
            s.symbol,
            " riskPips=",DoubleToString(risk/PipSize(s.symbol),1),
            " capPips=",DoubleToString(InpMaxInitialSLPips,1));
      return false;
     }

   s.rr=reward/risk;

   string geometryReason="OK";
   if(!STB_ValidatePendingGeometry(s.symbol,s.direction,s.entry,s.sl,s.tp,true,STB_EffectiveMinimumRR(),geometryReason))
     {
      Print("STB pending geometry contract rejected symbol=",s.symbol," dir=",(s.direction>0 ? "BUY":"SELL")," reason=",geometryReason);
      return false;
     }

   if(s.rr+1e-9<STB_EffectiveMinimumRR())
     {
      Print("STB setup rejected after broker-stop normalization symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " RR=",DoubleToString(s.rr,2),
            " minRR=",DoubleToString(STB_EffectiveMinimumRR(),2),
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
            " profile=",IntegerToString(s.adaptiveProfile));
     }

   return true;
  }

//==================================================================
// RSI + CCI COMPOSITE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int FindIndicatorCache(const string symbol)
  {
   for(int i=0;i<ArraySize(g_indicatorCache);i++)
      if(g_indicatorCache[i].symbol==symbol)
         return i;

   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

   int hRsi=iRSI(symbol,InpOscTF,InpRSIPeriod,PRICE_CLOSE);
   if(hRsi==INVALID_HANDLE)
     {
      Print("STB OSC: iRSI handle failed symbol=",symbol,
            " err=",GetLastError());
      return false;
     }

   int hCci=iCCI(symbol,InpOscTF,InpCCIPeriod,PRICE_TYPICAL);
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
      if(ArrayResize(g_indicatorCache,n+1)!=n+1)
        {
         IndicatorRelease(hRsi);
         IndicatorRelease(hCci);
         Print("STB indicator cache allocation failed symbol=",symbol,
               " reason=HANDLE_CACHE_UNAVAILABLE");
         return false;
        }
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// SWING ENGINE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CollectSwings(const string symbol,
                  const ENUM_TIMEFRAMES tf,
                  const int maxBars,
                  SwingPoint &highs[],
                  SwingPoint &lows[])
  {
   MqlRates r[];

   if(!GetRates(symbol,tf,maxBars,r))
      return 0;

   if(ArrayResize(highs,0)<0 || ArrayResize(lows,0)<0)
     {
      Print("STB swing buffers reset failed symbol=",symbol,
            " timeframe=",EnumToString(tf));
      return 0;
     }

   int left  = STB_EffectiveSwingLeft(tf);
   int right = STB_EffectiveSwingRight(tf);
   int maxShift=maxBars-left-1;
   int minShift=right+1;

   if(maxShift<minShift)
      return 0;

   for(int s=maxShift; s>=minShift; --s)
     {
      bool isHigh=true;
      bool isLow=true;

      // CopyRates + ArraySetAsSeries(true) means:
      // shift 0 = newest bar, larger shift = older bar.
      // Therefore "left" (older bars) is s+k and
      // "right" (newer bars) is s-k.
      for(int k=1;k<=left;k++)
        {
         if(r[s].high <= r[s+k].high)
            isHigh=false;

         if(r[s].low >= r[s+k].low)
            isLow=false;
        }

      for(int k=1;k<=right;k++)
        {
         if(r[s].high <= r[s-k].high)
            isHigh=false;

         if(r[s].low >= r[s-k].low)
            isLow=false;
        }

      if(isHigh)
        {
         int n=ArraySize(highs);
         if(ArrayResize(highs,n+1)!=n+1)
           {
            Print("STB swing-high allocation failed symbol=",symbol,
                  " timeframe=",EnumToString(tf));
            ArrayFree(highs);
            ArrayFree(lows);
            return 0;
           }

         highs[n].shift=s;
         highs[n].time=r[s].time;
         highs[n].price=r[s].high;
         highs[n].isHigh=true;
        }

      if(isLow)
        {
         int n=ArraySize(lows);
         if(ArrayResize(lows,n+1)!=n+1)
           {
            Print("STB swing-low allocation failed symbol=",symbol,
                  " timeframe=",EnumToString(tf));
            ArrayFree(highs);
            ArrayFree(lows);
            return 0;
           }

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   datetime lastClosedBar=iTime(symbol,PERIOD_H4,1);
   if(lastClose<=0.0 || lastClosedBar<=0)
      return result;

   // Compare the last closed candle with the trendline at that candle's
   // close time. TimeCurrent() projects the line beyond the candle being
   // tested and can create a time mismatch late in the next H4 bar.
   int h4Seconds=PeriodSeconds(PERIOD_H4);
   if(h4Seconds<=0)
      return result;
   datetime evaluationTime=lastClosedBar+h4Seconds;

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

         // c is the older confirmed pivot before anchor a. Test it against
         // the backward extension of the same line to count a third touch.
         if(c.time<a.time)
           {
            double lineAtC=a.price+slope*(double)(c.time-a.time);

            if(MathAbs(c.price-lineAtC)<=tolerance)
               result.touches=3;
           }
        }

      double lineNow=b.price+slope*(double)(evaluationTime-b.time);

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

         // c is the older confirmed pivot before anchor a. Test it against
         // the backward extension of the same line to count a third touch.
         if(c.time<a.time)
           {
            double lineAtC=a.price+slope*(double)(c.time-a.time);

            if(MathAbs(c.price-lineAtC)<=tolerance)
               result.touches=3;
           }
        }

      double lineNow=b.price+slope*(double)(evaluationTime-b.time);

      // This affects trading validity only; the drawing still shows
      // the confirmed structural line.
      result.valid=(lastClose<=lineNow+tolerance);
     }

   return result;
  }

//==================================================================
// TRENDLINE DRAWING
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//==================================================================
// M15 CHoCH + BOS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

   const int structureWindowBars=MathMax(5,InpStructureWindowBars);
   const int rightBars=MathMax(1,STB_EffectiveSwingRight(PERIOD_M15));

   if(direction>0)
     {
      for(int s=1;s<=structureWindowBars && s+1<ArraySize(r);s++)
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

            if(r[s].close>highs[i].price && r[s+1].close<=highs[i].price)
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
      for(int s=1;s<=structureWindowBars && s+1<ArraySize(r);s++)
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

            if(r[s].close<lows[i].price && r[s+1].close>=lows[i].price)
              {
               chochShift=pivotShift;
               bosShift=s;
               breakSwing=lows[i];
               return true;
              }
           }
        }
     }





   return false;
  }
//==================================================================
// FVG / DISPLACEMENT ENGINE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
// HIGHER-TIMEFRAME FVG + ORDER-BLOCK CONFLUENCE
// All pattern decisions use closed candles and enforce confirmation time
// against the latest closed M15 decision candle. No forming/future candle
// is allowed to confirm a zone.
//==================================================================

bool STB_HTFPivotAtImpulse(const MqlRates &rates[],
                           const int pivotShift,
                           const bool wantHigh,
                           const int leftBars,
                           const int rightBars,
                           const int impulseShift)
  {
   int n=ArraySize(rates);
   if(pivotShift<1 || leftBars<1 || rightBars<1 ||
      pivotShift+leftBars>=n ||
      pivotShift-rightBars<=impulseShift)
      return false; // pivot confirmation must predate the impulse candle

   double pivot=(wantHigh ? rates[pivotShift].high:rates[pivotShift].low);
   if(pivot<=0.0)
      return false;

   for(int k=1;k<=leftBars;k++)
     {
      if(wantHigh && pivot<=rates[pivotShift+k].high)
         return false;
      if(!wantHigh && pivot>=rates[pivotShift+k].low)
         return false;
     }
   for(int k=1;k<=rightBars;k++)
     {
      if(wantHigh && pivot<=rates[pivotShift-k].high)
         return false;
      if(!wantHigh && pivot>=rates[pivotShift-k].low)
         return false;
     }
   return true;
  }

bool STB_HTFImpulseBrokePriorSwing(const MqlRates &rates[],
                                  const int impulseShift,
                                  const int direction,
                                  const int leftBars,
                                  const int rightBars)
  {
   int n=ArraySize(rates);
   if(impulseShift<1 || (direction!=1 && direction!=-1))
      return false;

   // Smallest eligible shift = most recent prior swing whose right-side
   // confirmation candles had all closed before this impulse opened.
   for(int p=impulseShift+rightBars+1;p+leftBars<n;p++)
     {
      if(direction>0 && STB_HTFPivotAtImpulse(rates,p,true,leftBars,rightBars,impulseShift))
         return rates[impulseShift].close>rates[p].high;
      if(direction<0 && STB_HTFPivotAtImpulse(rates,p,false,leftBars,rightBars,impulseShift))
         return rates[impulseShift].close<rates[p].low;
     }
   return false;
  }

double STB_RangeGap(const double lowA,const double highA,
                    const double lowB,const double highB)
  {
   if(lowA<=0.0 || highA<lowA || lowB<=0.0 || highB<lowB)
      return DBL_MAX;
   if(highA<lowB)
      return lowB-highA;
   if(highB<lowA)
      return lowA-highB;
   return 0.0;
  }

bool STB_CheckHTFConfluence(const string symbol,
                            const int direction,
                            const datetime decisionTime,
                            const double m15OriginLow,
                            const double m15OriginHigh,
                            string &reason)
  {
   reason="HTF_CONFLUENCE_UNAVAILABLE";
   if(symbol=="" || (direction!=1 && direction!=-1) ||
      decisionTime<=0 || m15OriginLow<=0.0 ||
      m15OriginHigh<m15OriginLow)
     {
      reason="HTF_INPUT_INVALID";
      return false;
     }

   int tfSeconds=PeriodSeconds(InpHTFPatternTF);
   if(tfSeconds<PeriodSeconds(PERIOD_H1))
     {
      reason="HTF_TIMEFRAME_MUST_BE_H1_OR_HIGHER";
      return false;
     }

   int requestedBars=(int)MathMax(64,InpHTFLookbackBars+32);
   MqlRates r[];
   if(!GetRates(symbol,InpHTFPatternTF,requestedBars,r))
     {
      reason="HTF_DATA_UNAVAILABLE";
      return false;
     }

   double currentATR=LocalATR(r,1,14);
   if(currentATR<=0.0 || !MathIsValidNumber(currentATR))
     {
      reason="HTF_ATR_UNAVAILABLE";
      return false;
     }

   int maxShift=(int)MathMin(InpHTFLookbackBars,ArraySize(r)-3);
   if(maxShift<3)
     {
      reason="HTF_LOOKBACK_UNAVAILABLE";
      return false;
     }

   double fvgLow=0.0,fvgHigh=0.0;
   datetime fvgConfirmedAt=0;
   bool haveFVG=false;

   // Three-candle FVG: the middle candle must show displacement and the
   // newest candle must be fully closed by decisionTime.
   for(int s=1;s<=maxShift;s++)
     {
      int impulse=s+1;
      datetime confirmedAt=r[s].time+tfSeconds;
      if(r[s].time<=0 || confirmedAt>decisionTime)
         continue;

      int ageBars=(int)((decisionTime-confirmedAt)/tfSeconds);
      if(ageBars<0 || ageBars>InpHTFMaxZoneAgeBars)
         continue;

      double zoneLow=0.0,zoneHigh=0.0,zoneATR=LocalATR(r,s+1,20);
      if(zoneATR<=0.0)
         continue;

      if(direction>0)
        {
         zoneLow=r[s+2].high;
         zoneHigh=r[s].low;
         if(zoneHigh<=zoneLow ||
            zoneHigh-zoneLow+1e-9<zoneATR*InpHTFMinFVGWidthATR ||
            !IsBullishDisplacement(r,impulse))
            continue;
        }
      else
        {
         zoneLow=r[s].high;
         zoneHigh=r[s+2].low;
         if(zoneHigh<=zoneLow ||
            zoneHigh-zoneLow+1e-9<zoneATR*InpHTFMinFVGWidthATR ||
            !IsBearishDisplacement(r,impulse))
            continue;
        }

      bool fullyMitigated=false;
      for(int j=s-1;j>=1;j--)
        {
         if(r[j].time+tfSeconds>decisionTime)
            continue;
         if(direction>0 && r[j].low<=zoneLow)
           {
            fullyMitigated=true;
            break;
           }
         if(direction<0 && r[j].high>=zoneHigh)
           {
            fullyMitigated=true;
            break;
           }
        }
      if(fullyMitigated)
         continue;

      fvgLow=zoneLow;
      fvgHigh=zoneHigh;
      fvgConfirmedAt=confirmedAt;
      haveFVG=true;
      break; // latest valid, unmitigated FVG first
     }

   if(!haveFVG)
     {
      reason="HTF_FVG_MISSING_STALE_OR_MITIGATED";
      return false;
     }

   double obLow=0.0,obHigh=0.0;
   datetime obConfirmedAt=0;
   bool haveOB=false;
   int leftBars=(int)MathMax(1,InpSwingLeft);
   int rightBars=(int)MathMax(1,InpSwingRight);
   int maxOBShift=(int)MathMin(InpHTFLookbackBars,ArraySize(r)-2);

   // Order Block: most recent opposite candle immediately preceding a
   // directional displacement that closes beyond both the block and the
   // most recent *already confirmed* prior swing.
   for(int s=2;s<=maxOBShift;s++)
     {
      int impulse=s-1;
      datetime confirmedAt=r[impulse].time+tfSeconds;
      if(r[s].time<=0 || confirmedAt>decisionTime)
         continue;

      int ageBars=(int)((decisionTime-confirmedAt)/tfSeconds);
      if(ageBars<0 || ageBars>InpHTFMaxZoneAgeBars)
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

      bool closesBeyondBlock=(direction>0)
                             ? (r[impulse].close>r[s].high)
                             : (r[impulse].close<r[s].low);
      if(!closesBeyondBlock ||
         !STB_HTFImpulseBrokePriorSwing(r,impulse,direction,leftBars,rightBars))
         continue;

      double zoneLow=r[s].low;
      double zoneHigh=r[s].high;
      bool invalidated=false;
      for(int j=impulse-1;j>=1;j--)
        {
         if(r[j].time+tfSeconds>decisionTime)
            continue;
         if(direction>0 && r[j].close<zoneLow)
           {
            invalidated=true;
            break;
           }
         if(direction<0 && r[j].close>zoneHigh)
           {
            invalidated=true;
            break;
           }
        }
      if(invalidated)
         continue;

      obLow=zoneLow;
      obHigh=zoneHigh;
      obConfirmedAt=confirmedAt;
      haveOB=true;
      break; // latest valid, non-invalidated OB first
     }

   if(!haveOB)
     {
      reason="HTF_ORDER_BLOCK_MISSING_STALE_OR_INVALIDATED";
      return false;
     }

   // The local M15 OB origin must be near both independently validated H1
   // zones; simple score bonuses cannot compensate for absent confluence.
   double allowedGap=currentATR*InpHTFZoneMaxGapATR;
   double fvgGap=STB_RangeGap(m15OriginLow,m15OriginHigh,fvgLow,fvgHigh);
   double obGap=STB_RangeGap(m15OriginLow,m15OriginHigh,obLow,obHigh);
   double zoneGap=STB_RangeGap(fvgLow,fvgHigh,obLow,obHigh);
   if(fvgGap>allowedGap || obGap>allowedGap || zoneGap>allowedGap)
     {
      reason="HTF_FVG_OB_M15_ORIGIN_NOT_CONFLUENT";
      return false;
     }

   // Times are retained in diagnostics so future refinements can inspect
   // the age relationship without relying on chart screenshots.
   Print("STB HTF CONFLUENCE PASS symbol=",symbol,
         " direction=",(direction>0 ? "BUY":"SELL"),
         " tf=",EnumToString(InpHTFPatternTF),
         " fvgFrom=",TimeToString(fvgConfirmedAt,TIME_DATE|TIME_MINUTES),
         " obFrom=",TimeToString(obConfirmedAt,TIME_DATE|TIME_MINUTES),
         " fvgGapATR=",DoubleToString(fvgGap/currentATR,3),
         " obGapATR=",DoubleToString(obGap/currentATR,3),
         " zonesGapATR=",DoubleToString(zoneGap/currentATR,3));
   reason="";
   return true;
  }

//==================================================================
// SETUP BUILDER
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Find the nearest already-confirmed opposite-side swing that predates the
// structure-break candle. This is the fallback stop anchor when no valid OB
// exists; the broken pivot itself is an entry trigger, not a protective stop.
bool FindStructuralStopAnchor(const string symbol,
                              const int direction,
                              const int bosShift,
                              double &anchorPrice)
  {
   anchorPrice=0.0;

   SwingPoint highs[];
   SwingPoint lows[];
   if(CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
      return false;

   int bestShift=2147483647;

   if(direction>0)
     {
      for(int i=0;i<ArraySize(lows);i++)
        {
         if(lows[i].shift<=bosShift || lows[i].price<=0.0)
            continue;

         if(lows[i].shift<bestShift)
           {
            bestShift=lows[i].shift;
            anchorPrice=lows[i].price;
           }
        }
     }
   else
     if(direction<0)
       {
        for(int i=0;i<ArraySize(highs);i++)
          {
           if(highs[i].shift<=bosShift || highs[i].price<=0.0)
              continue;

           if(highs[i].shift<bestShift)
             {
              bestShift=highs[i].shift;
              anchorPrice=highs[i].price;
             }
          }
       }

   return (anchorPrice>0.0 && bestShift<2147483647);
  }

bool BuildSetup(const string symbol,
                const int direction,
                Setup &s,
                const bool countAdaptiveAttempt)
  {
   ZeroMemory(s);

   s.symbol=symbol;
   s.direction=direction;
   s.adaptiveProfile=0;

   g_lastBuildRejectReason="UNKNOWN";
   STB_AP_SelectActive(symbol,direction);
   s.adaptiveProfile=g_activeAdaptiveProfileId;

// Count a strategy probe only during the scanner's first-pass discovery.
// Candidate revalidation rebuilds the same setup several times; those checks
// must not inflate adaptive sample counts or make profiles appear warmed up.
   if(countAdaptiveAttempt)
      STB_AP_RecordAttempt(symbol,direction,s.adaptiveProfile);

   if(!IsDirectionTradable(symbol,direction))
     {
      long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
      long stops=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
      long freeze=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
      long expiration=SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);

      Print("STB CONTRACT REJECT symbol=",symbol,
            " dir=",(direction>0 ? "BUY":"SELL"),
            " tradeMode=",tradeMode,
            " orderMode=",orderMode,
            " stopsPts=",stops,
            " freezePts=",freeze,
            " expirationMode=",expiration);

      return STB_BuildReject(symbol,direction,"DIRECTION_NOT_TRADABLE");
     }

   if(!IsSpreadAcceptable(symbol))
      return STB_BuildReject(symbol,direction,"SPREAD_FILTER");

   OscillatorState osc;
   ZeroMemory(osc);

   bool oscReady=GetOscillatorState(symbol,osc);

   if(!oscReady && InpOscillatorHardFilter)
      return STB_BuildReject(symbol,direction,"OSCILLATOR_DATA_UNAVAILABLE");

   if(oscReady && InpOscillatorHardFilter)
     {
      if(direction>0 && !osc.buyConfirmed)
         return STB_BuildReject(symbol,direction,"OSCILLATOR_BUY_NOT_CONFIRMED");

      if(direction<0 && !osc.sellConfirmed)
         return STB_BuildReject(symbol,direction,"OSCILLATOR_SELL_NOT_CONFIRMED");
     }

   datetime lastSetup=GetLastSetupTime(symbol,direction);

   if(InpSetupCooldownMinutes>0 &&
      lastSetup>0 &&
      TimeCurrent()-(datetime)lastSetup<InpSetupCooldownMinutes*60)
      return STB_BuildReject(symbol,direction,"SETUP_COOLDOWN");

   TrendInfo ti=GetH4Trend(symbol);

   bool aligned=
      ti.valid &&
      ((direction>0 && ti.bias=="BULLISH") ||
       (direction<0 && ti.bias=="BEARISH"));

   if(InpRequireH4TrendAlignment && (!ti.valid || !aligned))
      return STB_BuildReject(symbol,direction,
                             ti.valid ? "H4_DIRECTION_MISMATCH" : "H4_TREND_UNAVAILABLE");

   if(!aligned && !InpAllowUniversal)
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

   if((InpRequireFVG || InpStrictPatternFilters) && !hasFVG)
      return STB_BuildReject(symbol,direction,"M15_FVG_REQUIRED");

   int originShift=-1;
   double originHigh=0.0;
   double originLow=0.0;

   bool hasOB=FindOriginCandle(symbol,direction,
                               bosShift,originShift,
                               originHigh,originLow);

   if((InpRequireOB || InpStrictPatternFilters || InpRequireHTFConfluence) && !hasOB)
      return STB_BuildReject(symbol,direction,"M15_ORDER_BLOCK_REQUIRED");

   if(InpRequireHTFConfluence)
     {
      datetime latestClosedM15=iTime(symbol,PERIOD_M15,1);
      int m15Seconds=PeriodSeconds(PERIOD_M15);
      if(latestClosedM15<=0 || m15Seconds<=0)
         return STB_BuildReject(symbol,direction,"M15_DECISION_TIME_UNAVAILABLE");

      datetime decisionTime=latestClosedM15+m15Seconds;
      string htfReason="";
      if(!STB_CheckHTFConfluence(symbol,direction,decisionTime,
                                  originLow,originHigh,htfReason))
         return STB_BuildReject(symbol,direction,htfReason);
     }

   // If local OBs are explicitly optional and HTF confluence is disabled,
   // retain the historical structural fallback for compatibility.
   if(!hasOB)
     {
      originShift=breakSwing.shift;
      originHigh=iHigh(symbol,PERIOD_M15,originShift);
      originLow=iLow(symbol,PERIOD_M15,originShift);

      if(originShift<0 || originHigh<=0.0 || originLow<=0.0)
         return STB_BuildReject(symbol,direction,"ORIGIN_FALLBACK_INVALID");
     }

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return STB_BuildReject(symbol,direction,"PIP_SIZE_INVALID");

   // Risk belongs beyond the opposite side of the actual Order Block when
   // one is found. If OB is optional and absent, use the nearest confirmed
   // pre-BOS swing on the risk side. Do not place SL just beyond the broken
   // swing that defines the entry trigger; that artificially compresses risk.
   double stopAnchor=(direction>0 ? originLow:originHigh);
   if(!hasOB &&
      !FindStructuralStopAnchor(symbol,direction,bosShift,stopAnchor))
      return STB_BuildReject(symbol,direction,"STRUCTURAL_STOP_ANCHOR_MISSING");

   if(stopAnchor<=0.0 ||
      (direction>0 && stopAnchor>=originHigh) ||
      (direction<0 && stopAnchor<=originLow))
      return STB_BuildReject(symbol,direction,"STRUCTURAL_STOP_ANCHOR_INVALID");

   double entryBuffer=STB_EffectiveEntryBuffer();
   s.entryBufferPips=MathMax(0.0,entryBuffer); // P4 EB contract source
   double slBuffer=STB_EffectiveSLBuffer();
   double minimumRR=STB_EffectiveMinimumRR();

   // Raw structural geometry only.
   // Final broker alignment and Entry/SL/TP/RR validation are centralized
   // in PreparePendingSetup().
   if(direction>0)
     {
      // A BUY STOP is a breakout order, so its trigger must stay above the
      // confirmed swing-high broken by BOS. The OB high can be below that
      // swing; basing a STOP only on the OB may let it trigger prematurely.
      double buyTriggerBase=MathMax(originHigh,breakSwing.price);
      s.entry=NormalizePrice(symbol,buyTriggerBase + entryBuffer*pip);
      s.sl=NormalizePrice(symbol,stopAnchor - slBuffer*pip);
     }
   else
     {
      // Symmetric rule for SELL STOP: trigger below both the OB low and the
      // confirmed broken swing-low. If valid RR no longer exists, reject it.
      double sellTriggerBase=MathMin(originLow,breakSwing.price);
      s.entry=NormalizePrice(symbol,sellTriggerBase - entryBuffer*pip);
      s.sl=NormalizePrice(symbol,stopAnchor + slBuffer*pip);
     }

   if(!PreparePendingSetup(s))
      return STB_BuildReject(symbol,direction,"BROKER_STOP_NORMALIZATION_FAILED");

   if(s.rr+1e-9<minimumRR)
      return STB_BuildReject(symbol,direction,"RR_BELOW_PROFILE_MINIMUM");


   s.score=(aligned ? 40.0:25.0);

   if(bosShift<=2)
      s.score+=30.0;
   else
      if(bosShift<=4)
         s.score+=25.0;
      else
         s.score+=20.0;

   if(s.rr>=2.0)
      s.score+=15.0;
   else
      if(s.rr>=1.5)
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
      else
         if(direction<0 && osc.sellConfirmed)
            s.score+=rsiWeight*0.5+cciWeight*0.5;
         else
            if(direction>0)
              {
               if(osc.rsi1>=50.0)
                  s.score+=rsiWeight*0.25;
               if(osc.cci1>=0.0)
                  s.score+=cciWeight*0.25;
              }
            else
              {
               if(osc.rsi1<=50.0)
                  s.score+=rsiWeight*0.25;
               if(osc.cci1<=0.0)
                  s.score+=cciWeight*0.25;
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

// A successfully built setup is still only a probe; profile quality is
// learned from the eventual closed-trade outcome below.
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TicketLockName(const ulong ticket)
  {
   return ScopedStateName("LOCK_"+(string)ticket);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string PositionPnlName(const ulong positionId)
  {
   return ScopedStateName("PNL_"+(string)positionId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetAccumulatedPositionPnl(const ulong positionId)
  {
   if(positionId==0)
      return 0.0;

   string name=PositionPnlName(positionId);
   if(!GlobalVariableCheck(name))
      return 0.0;

   return GlobalVariableGet(name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetAccumulatedPositionPnl(const ulong positionId,const double value)
  {
   if(positionId==0)
      return;

   GlobalVariableSet(PositionPnlName(positionId),value);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double TakeAccumulatedPositionPnl(const ulong positionId)
  {
   double value=GetAccumulatedPositionPnl(positionId);

   if(positionId>0)
      GlobalVariableDel(PositionPnlName(positionId));

   return value;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLockedPips(const ulong ticket)
  {
   string name=TicketLockName(ticket);

   if(!GlobalVariableCheck(name))
      return 0.0;

   return GlobalVariableGet(name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetLockedPips(const ulong ticket,const double value)
  {
   GlobalVariableSet(TicketLockName(ticket),value);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ScopedStateName(const string purpose)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|"+purpose;
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER";
   return g_prefix+(string)SymbolHash(raw);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ScopedSymbolStateName(const string purpose,const string symbol)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|"+purpose+"|"+symbol;
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER";
   return g_prefix+(string)SymbolHash(raw);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string LastSetupName(const string symbol,const int direction)
  {
   return ScopedSymbolStateName("LAST_"+(direction>0 ? "B":"S"),symbol);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime GetLastSetupTime(const string symbol,const int direction)
  {
   string name=LastSetupName(symbol,direction);

   if(!GlobalVariableCheck(name))
      return 0;

   return (datetime)GlobalVariableGet(name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetLastSetupTime(const string symbol,const int direction,const datetime t)
  {
   GlobalVariableSet(LastSetupName(symbol,direction),(double)t);
  }

//==================================================================
// OWNERSHIP / ORIGIN + TRADE REGISTRY
//==================================================================


void STB_ReconcileTradeRegistry()
  {


   STB_GeomPrune(); STB_OverridePersistPrune(false); // MANUAL_OVERRIDE: drop geometry memory for closed tickets + purge persisted overrides for tickets that no longer exist

   for(int i=0;i<PositionsTotal();i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(!STB_IsProtectionPosition(ticket))
         continue;

      // Seed recovery state from the actual terminal geometry. Otherwise the
      // registry's initial zero values can misclassify the next routine server
      // POSITION update as an external/manual geometry edit.
      int exposureIdx=STB_ExposureEnsure(ticket,true); // MANUAL_OVERRIDE: restore persisted override on reconcile (no broker write)
      // Reconcile may run before a delayed POSITION transaction is consumed.
      // Seed only an unknown baseline; do not overwrite a known snapshot, or a
      // later intake callback may miss an external/manual geometry change.
      if(exposureIdx>=0 && g_stbExposure[exposureIdx].entry<=0.0)
         STB_GeomStore(ticket,true,
                       PositionGetDouble(POSITION_PRICE_OPEN),
                       PositionGetDouble(POSITION_SL),
                       PositionGetDouble(POSITION_TP));
     }

   for(int i=0;i<OrdersTotal();i++)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(!IsManagedOrder(ticket))
         continue;

      // Ensure the exposure baseline registry before registering trail state.
      // If allocation fails, defer this order's reconciliation as a unit so
      // trail processing cannot proceed from a partially initialized intake.
      int exposureIdx=STB_ExposureEnsure(ticket,false); // MANUAL_OVERRIDE: restore persisted override on reconcile (no broker write)
      if(exposureIdx<0)
        {
         Print("STB ORDER RECONCILE DEFERRED ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         continue;
        }

      // Seed recovery state from the actual pending-order geometry only after
      // the exposure registry is available.
      STB_PendingTrailRegister(ticket,"RECONCILE");

      // Preserve a known intake/own-write baseline across periodic Reconcile.
      // This lets ORDER_UPDATE compare the new server geometry with the last
      // observed baseline instead of a snapshot already overwritten here.
      if(g_stbExposure[exposureIdx].entry<=0.0)
         STB_GeomStore(ticket,false,
                       OrderGetDouble(ORDER_PRICE_OPEN),
                       OrderGetDouble(ORDER_SL),
                       OrderGetDouble(ORDER_TP));
     }

   // SIMPLIFIED: origin registry prune loop removed.




  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ManagePositionImmediately(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return;
   string symbol=PositionGetString(POSITION_SYMBOL);
   int exposureIdx=STB_ExposureEnsure(ticket,true);
   if(exposureIdx<0)
     {
      Print("STB POSITION HANDOFF DEFERRED ticket=",ticket,
            " symbol=",symbol,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return;
     }
   STB_GeomStore(ticket,true,
                 PositionGetDouble(POSITION_PRICE_OPEN),
                 PositionGetDouble(POSITION_SL),
                 PositionGetDouble(POSITION_TP));
   Print("STB POSITION HANDOFF ACTIVE ticket=",ticket,
         " symbol=",symbol,
         " side=",(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " action=IMMEDIATE_MANAGEMENT_CYCLE");
   STB_RunManagementCycle();
  }

void STB_TradeIntakeFromTransaction(const MqlTradeTransaction &trans)
  {
   STB_ManualOverrideIntake(trans); // MANUAL_OVERRIDE: user SL/TP/entry/pending detection
   if(trans.type==TRADE_TRANSACTION_ORDER_ADD && trans.order>0)
     {
      // SIMPLIFIED: origin registry call removed.

      if(OrderSelect(trans.order))
        {
         ENUM_ORDER_TYPE orderType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

         // Capture terminal-confirmed geometry at first discovery. Without this
         // baseline, an immediate manual entry/SL/TP edit on a newly created
         // pending order could be mistaken for an unknown geometry snapshot.
         if(IsManagedOrder(trans.order))
           {
            int exposureIdx=STB_ExposureEnsure(trans.order,false);
            if(exposureIdx<0)
              {
               Print("STB ORDER INTAKE DEFERRED ticket=",trans.order,
                     " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
               return;
              }
            STB_GeomStore(trans.order,false,
                          OrderGetDouble(ORDER_PRICE_OPEN),
                          OrderGetDouble(ORDER_SL),
                          OrderGetDouble(ORDER_TP));

            if(STB_IsManagedPendingType((long)orderType))
               STB_PendingTrailRegister(trans.order,"TRADE_TRANSACTION");
           }
        }

      return;
     }

   if(trans.type==TRADE_TRANSACTION_DEAL_ADD &&
      trans.deal>0 &&
      HistoryDealSelect(trans.deal))
     {
      // Pending-order override applies only while the order is pending.
// The resulting open position always enters the protection manager.
      if(trans.order>0)
         STB_PendingTrailOnOrderFilled(trans.order);

      if(trans.position>0 && PositionSelectByTicket(trans.position))
        {
         if(STB_IsProtectionPosition(trans.position))
           {
            string positionSymbol=PositionGetString(POSITION_SYMBOL);
            double positionEntry=PositionGetDouble(POSITION_PRICE_OPEN);
            double positionSL=PositionGetDouble(POSITION_SL);
            double positionTP=PositionGetDouble(POSITION_TP);

            int exposureIdx=STB_ExposureEnsure(trans.position,true);
            if(exposureIdx>=0)
              {
               STB_GeomStore(trans.position,true,
                             positionEntry,positionSL,positionTP);

               Print("STB POSITION PROTECTION ACTIVE after fill ticket=",
                      IntegerToString((int)trans.position),
                      " symbol=",positionSymbol,
                      " SL=",DoubleToString(positionSL,(int)SymbolInfoInteger(positionSymbol,SYMBOL_DIGITS)),
                      " TP=",DoubleToString(positionTP,(int)SymbolInfoInteger(positionSymbol,SYMBOL_DIGITS)));
              }
            else
              {
               Print("STB POSITION BASELINE DEFERRED after fill ticket=",
                     trans.position,
                     " symbol=",positionSymbol,
                     " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
              }
           }

         // SIMPLIFIED: origin registry call removed.
         STB_ManagePositionImmediately(trans.position);
        }
     }
  }

//==================================================================
// EXPOSURE MANAGEMENT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_IsSymbolAllowed(const string s)
  {
   if(s=="")
      return false;

   // Strategy Tester isolation is a hard scope boundary when enabled.
   if(MQLInfoInteger(MQL_TESTER) && InpTesterChartSymbolOnly)
      return s==_Symbol;

   // The chart symbol remains manageable even when the scanner is configured
   // to explore a different explicit symbol universe (manual controls operate
   // on _Symbol). Additional symbols follow the configured universe.
   if(s==_Symbol)
      return true;

   // Universal management scope: an empty list means every symbol that has
   // an account position or pending order, not only selected Market Watch symbols.
   if(StringLen(InpScannerSymbols)==0)
      return true;

   string parts[];
   string cfg=InpScannerSymbols;
   StringReplace(cfg,";",",");
   ushort sep=StringGetCharacter(",",0);
   int n=StringSplit(cfg,sep,parts);

   for(int i=0;i<n;i++)
     {
      string it=parts[i];
      StringTrimLeft(it);
      StringTrimRight(it);
      if(it!="" && it==s)
         return true;
     }

   return false;
  } bool STB_IsManagedPendingType(const long t){ return t==(long)ORDER_TYPE_BUY_STOP||t==(long)ORDER_TYPE_SELL_STOP||t==(long)ORDER_TYPE_BUY_LIMIT||t==(long)ORDER_TYPE_SELL_LIMIT||t==(long)ORDER_TYPE_BUY_STOP_LIMIT||t==(long)ORDER_TYPE_SELL_STOP_LIMIT; } bool STB_IsProtectionPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;
   // Live protection covers all account positions regardless of origin/symbol.
   // Respect the explicit chart-only isolation setting in Strategy Tester.
   if(MQLInfoInteger(MQL_TESTER) && InpTesterChartSymbolOnly)
      return PositionGetString(POSITION_SYMBOL)==_Symbol;
   return true;
  }

bool IsManagedPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   return STB_IsSymbolAllowed(PositionGetString(POSITION_SYMBOL)); // SIMPLIFIED: allowed symbol is the only management scope



  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsManagedOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket)) return false;
   return STB_IsSymbolAllowed(OrderGetString(ORDER_SYMBOL)); // SIMPLIFIED: allowed symbol is the only management scope



  }

// Exposure deduplication is scoped to this EA instance by Magic Number.
// Keep these helpers separate from IsManagedPosition/IsManagedOrder because those
// functions also define the broader scope used by management and trailing code.
bool STB_IsOwnedPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;
   return (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic;
  }

bool STB_IsOwnedPendingOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket))
      return false;
   if(!STB_IsManagedPendingType(OrderGetInteger(ORDER_TYPE)))
      return false;
   return (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Entry-policy gate: only this EA's own exposure blocks a new setup.
bool HasManagedExposure(const string symbol)
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
      if(STB_IsOwnedPosition(ticket))
         return true;
     }

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;
      if(STB_IsOwnedPendingOrder(ticket))
         return true;
     }

   return false;
  }

// Lifecycle gate: preserve quote subscription while any exposure on this
// symbol remains inside the EA's management scope, independent of entry policy.
bool STB_HasSymbolExposureForManagement(const string symbol)
  {
   if(symbol=="")
      return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;
      if(IsManagedPosition(ticket))
         return true;
     }

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;
      if(IsManagedOrder(ticket))
         return true;
     }

   return false;
  }

//==================================================================
// ONE-CLICK HEDGE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHedgingAccount()
  {
   long mode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return (mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_HasManagedPendingDirection(const string symbol,
                                    const long positionType)
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(positionType==POSITION_TYPE_BUY &&
         STB_PendingIsBuySide(type))
         return true;

      if(positionType==POSITION_TYPE_SELL &&
         !STB_PendingIsBuySide(type) && STB_PendingIsSellSide(type))
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ResolveManualPendingEntry(const string symbol,
                                     const ENUM_ORDER_TYPE orderType,
                                     const double requestedEntry,
                                     const MqlTick &tick,
                                     double &entry)
  {
   entry=0.0;
   if(symbol=="" || requestedEntry<=0.0 ||
      tick.bid<=0.0 || tick.ask<=0.0)
      return false;

   double minDist=TradeMinDistance(symbol);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(minDist<=0.0 || point<=0.0)
      return false;

   // Keep one full tradable price increment beyond the broker boundary so
   // tick rounding cannot place the manual order exactly on the rejection edge.
   double safety=MathMax(point,tickSize>0.0 ? tickSize:point);
   double candidate=requestedEntry;

   switch(orderType)
     {
      case ORDER_TYPE_BUY_STOP:
         candidate=MathMax(candidate,tick.ask+minDist+safety);
         break;
      case ORDER_TYPE_SELL_STOP:
         candidate=MathMin(candidate,tick.bid-minDist-safety);
         break;
      case ORDER_TYPE_BUY_LIMIT:
         candidate=MathMin(candidate,tick.bid-minDist-safety);
         break;
      case ORDER_TYPE_SELL_LIMIT:
         candidate=MathMax(candidate,tick.ask+minDist+safety);
         break;
      default:
         return false;
     }

   entry=NormalizePrice(symbol,candidate);
   if(entry<=0.0)
      return false;

   if(orderType==ORDER_TYPE_BUY_STOP)
      return entry>tick.ask+minDist;
   if(orderType==ORDER_TYPE_SELL_STOP)
      return entry<tick.bid-minDist;
   if(orderType==ORDER_TYPE_BUY_LIMIT)
      return entry<tick.bid-minDist;
   if(orderType==ORDER_TYPE_SELL_LIMIT)
      return entry>tick.ask+minDist;

   return false;
  }

bool OneClickHedge()
  {
   if(!InpAllowOneClickHedge || !IsHedgingAccount() ||
      !STB_TradeEnvironmentAllowed())
      return false;

   string symbol=_Symbol;
   if(!STB_SymbolManagementOwnedVerified(symbol))
     {
      Print("STB HEDGE REJECTED: symbol writer lease not owned symbol=",symbol);
      return false;
     }
   ulong sourceTicket=0;
   long sourceType=-1;
   double sourceVolume=0.0;

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
      return false;

   long hedgeType=(sourceType==POSITION_TYPE_BUY) ? POSITION_TYPE_SELL
                                                  : POSITION_TYPE_BUY;

   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY ||
      (hedgeType==POSITION_TYPE_BUY && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (hedgeType==POSITION_TYPE_SELL && tradeMode==SYMBOL_TRADE_MODE_LONGONLY))
      return false;

   if(HasManagedPositionDirection(symbol,hedgeType) ||
      STB_HasManagedPendingDirection(symbol,hedgeType))
      return false;

   double volume=NormalizeVolume(symbol,sourceVolume);
   if(volume<=0.0 || volume+1e-9<sourceVolume)
     {
      // Do not silently label a max-volume-capped order as a full hedge.
      // One click represents the entire source exposure; otherwise reject.
      Print("STB HEDGE REJECTED: requested hedge exceeds one-order volume capacity",
            " symbol=",symbol,
            " sourceVolume=",DoubleToString(sourceVolume,4),
            " allowedSingleOrderVolume=",DoubleToString(volume,4));
      return false;
     }

   int hedgeDirection=(hedgeType==POSITION_TYPE_BUY ? 1:-1);
   if(!STB_DirectionVolumeWithinLimit(symbol,hedgeDirection,volume,"OneClickHedge"))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double pip=PipSize(symbol);
   double minDist=TradeMinDistance(symbol);
   if(pip<=0.0 || minDist<=0.0)
      return false;

   long orderModes=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
   if((orderModes&SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP ||
      (orderModes&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
      return false;

   ENUM_ORDER_TYPE orderType=(hedgeType==POSITION_TYPE_BUY)
                              ? ORDER_TYPE_BUY_STOP
                              : ORDER_TYPE_SELL_STOP;
   double requestedEntry=(hedgeType==POSITION_TYPE_BUY)
                         ? tick.ask+InpManualPendingGapPips*pip
                         : tick.bid-InpManualPendingGapPips*pip;
   double entry=0.0;
   if(!STB_ResolveManualPendingEntry(symbol,orderType,requestedEntry,tick,entry))
      return false;
   double sl=0.0;

   if(!CalculateInitialPendingProtectionSL(symbol,orderType,entry,sl))
      return false;

   int expirationModes=(int)SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);
   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

   if((expirationModes&SYMBOL_EXPIRATION_GTC)!=SYMBOL_EXPIRATION_GTC)
     {
      if((expirationModes&SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
         typeTime=ORDER_TIME_DAY;
      else
         return false;
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double hedgeEntryOffset=MathAbs(entry-(hedgeType==POSITION_TYPE_BUY
                                          ? tick.bid:tick.ask))/pip;
   string comment="STB|HEDGE|"+
                  (hedgeType==POSITION_TYPE_BUY ? "BUY":"SELL")+
                  "|EB"+DoubleToString(hedgeEntryOffset,8);

   // Recheck writer authority and exposure immediately before broker submission.
   if(!STB_SymbolManagementOwnedVerified(symbol) ||
      HasManagedPositionDirection(symbol,hedgeType) ||
      STB_HasManagedPendingDirection(symbol,hedgeType))
     {
      Print("STB HEDGE REJECTED: writer/exposure changed before submit symbol=",symbol);
      return false;
     }

   bool ok=(hedgeType==POSITION_TYPE_BUY)
           ? trade.BuyStop(volume,entry,symbol,sl,0.0,typeTime,expiration,comment)
           : trade.SellStop(volume,entry,symbol,sl,0.0,typeTime,expiration,comment);

   if(!ok || !TradeRetcodePlacementSucceeded())
      return false;

   ulong hedgeOrder=trade.ResultOrder();
   if(hedgeOrder==0 || !VerifyPendingInitialSL(hedgeOrder))
     {
      Print("STB HEDGE REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            symbol," order=",IntegerToString((int)hedgeOrder));
      if(hedgeOrder>0 && OrderSelect(hedgeOrder))
         STB_RequestOrderDelete(hedgeOrder,STB_DEL_AUTO_ROLLBACK,"OneClickHedge");
      return false;
     }

   // SIMPLIFIED: origin registry call removed.
   STB_AfterExposureCreated(hedgeOrder,"HEDGE"); // Blueprint 10/11
   Print("STB HEDGE PENDING CREATED symbol=",symbol,
         " sourceTicket=",sourceTicket,
         " direction=",(hedgeType==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " volume=",DoubleToString(volume,3),
         " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(sl,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " order=",IntegerToString((int)hedgeOrder));
   return true;
  }


//==================================================================
// STOP VALIDATION
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
// NET PROFIT PIPS
//==================================================================

double PositionPipValue(const string symbol,
                        const long positionType,
                        const double volume,
                        const double entry)
  {
   if(volume<=0.0 || entry<=0.0)
      return 0.0;

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return 0.0;

   double money=0.0;
   ENUM_ORDER_TYPE orderType=(positionType==POSITION_TYPE_BUY ?
                              ORDER_TYPE_BUY:ORDER_TYPE_SELL);

   double price2=(positionType==POSITION_TYPE_BUY ?
                  entry+pip:entry-pip);

   if(!OrderCalcProfit(orderType,symbol,volume,entry,price2,money))
      return 0.0;

   return MathAbs(money);
  }

double PositionCommissionMoney(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return 0.0;

   ulong positionId=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(positionId==0)
      return 0.0;

   double commission=0.0;

   if(!HistorySelectByPosition(positionId))
      return 0.0;

   int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0)
         continue;

      long entryType=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entryType==DEAL_ENTRY_IN)
         commission+=HistoryDealGetDouble(deal,DEAL_COMMISSION)+
                     HistoryDealGetDouble(deal,DEAL_FEE);
     }

   return commission;
  }

double STB_PositionPriceMovePips(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return 0.0;
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double pip=PipSize(symbol);
   if(entry<=0.0 || pip<=0.0)
      return 0.0;
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return 0.0;
   // Executable close-side quote: Bid for BUY, Ask for SELL.
   double closePrice=(type==POSITION_TYPE_BUY ? tick.bid : tick.ask);
   if(closePrice<=0.0)
      return 0.0;
   if(type==POSITION_TYPE_BUY)
      return (closePrice-entry)/pip;
   if(type==POSITION_TYPE_SELL)
      return (entry-closePrice)/pip;
   return 0.0;
  }

double PositionNetProfitPips(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return 0.0;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double volume=PositionGetDouble(POSITION_VOLUME);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   double pipValue=PositionPipValue(symbol,type,volume,entry);
   // Fail closed if the cash value of one pip cannot be computed. Falling back
   // to gross quote movement can trigger an automatic profit lock while the
   // actual position is still net negative after commission/swap.
   if(pipValue<=0.0 || !MathIsValidNumber(pipValue))
      return 0.0;

   double netMoney=PositionGetDouble(POSITION_PROFIT)+
                   PositionGetDouble(POSITION_SWAP)+
                   PositionCommissionMoney(ticket);

   if(!MathIsValidNumber(netMoney))
      return 0.0;

   double netPips=netMoney/pipValue;
   return MathIsValidNumber(netPips) ? netPips:0.0;
  }

//==================================================================
// MODIFY POSITION
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//==================================================================
// MANUAL_OVERRIDE (minimal per-ticket user authority)
//==================================================================
// Position protection remains active, including after manual SL/TP edits.
// MANUAL_OVERRIDE is retained only for pending-order lifecycle/trailing behavior.
// It never suppresses an open position's initial SL, profit lock, or live trail.
// User-issued modify actions still pass through the same broker validation.


//==================================================================
// UNIFIED EXPOSURE REGISTRY (MASTER BLUEPRINT 14) - ONE STATE PER TICKET
//==================================================================
// Single owner of per-ticket management state for BOTH positions and
// pendings. Specialized modules (Pending Trail, Adaptive, Lease) keep their
// own storage but never override this state and are keyed by the same ticket.
// Blueprint 14/15: no ticket is controlled by two independent registries.
struct STBExposureState
  {
   ulong    ticket;
   bool     isPosition;
   double   entry;
   double   sl;
   double   tp;
   bool     manualOverride;
   string   symbol;
   long     lastWriteCycle;
   datetime lastSeen;
  };

STBExposureState g_stbExposure[];

//--- persistent manual-override storage (Terminal Global Variables) -----
// Storage backing ONLY. The single Runtime owner stays STBExposureState /
// g_stbExposure; this is a key-value mirror of the manualOverride field.
// Scope = EA magic + account + symbol + ticket (one key per ticket).
string STB_ExposureSymbolOf(const ulong ticket)
  {
   if(PositionSelectByTicket(ticket))
      return PositionGetString(POSITION_SYMBOL);
   if(OrderSelect(ticket))
      return OrderGetString(ORDER_SYMBOL);
   return "";
  }

string STB_OverrideLegacyKey(const ulong ticket,const string symbol)
  {
   if(ticket==0 || symbol=="" || MQLInfoInteger(MQL_TESTER))
      return "";
   // Legacy key format retained only for safe migration from older builds.
   return g_prefix+"OVR_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+
          (string)InpMagic+"_"+symbol+"_"+IntegerToString((int)ticket);
  }

string STB_OverrideKey(const ulong ticket,const string symbol)
  {
   if(ticket==0 || symbol=="")
      return "";

   // Compact account+magic scope keeps the key safely under MT5's 63-char
   // terminal-global-variable limit even with long broker symbols/tickets.
   return ScopedStateName("OVR")+"_"+(string)ticket;
  }

void STB_OverridePersistSet(const ulong ticket,const string symbol)
  {
   string key=STB_OverrideKey(ticket,symbol);
   if(key=="")
      return;

   if(GlobalVariableSet(key,1.0)!=0)
     {
      string legacy=STB_OverrideLegacyKey(ticket,symbol);
      if(legacy!="")
         GlobalVariableDel(legacy);
     }
  }

void STB_OverridePersistDel(const ulong ticket,const string symbol)
  {
   string key=STB_OverrideKey(ticket,symbol);
   if(key!="")
      GlobalVariableDel(key);

   string legacy=STB_OverrideLegacyKey(ticket,symbol);
   if(legacy!="")
      GlobalVariableDel(legacy);
  }

bool STB_OverridePersistOn(const ulong ticket,const string symbol)
  {
   string key=STB_OverrideKey(ticket,symbol);
   if(key=="" )
      return false;

   if(GlobalVariableCheck(key))
      return GlobalVariableGet(key)>0.5;

   // Lazy migration keeps manual authority across an update/recompile.
   string legacy=STB_OverrideLegacyKey(ticket,symbol);
   if(legacy!="" && GlobalVariableCheck(legacy) &&
      GlobalVariableGet(legacy)>0.5)
     {
      if(GlobalVariableSet(key,1.0)!=0)
         GlobalVariableDel(legacy);
      return true;
     }

   return false;
  }

// Keep an absent ticket's state briefly so a delayed DEAL_ADD transaction
// can transfer manual authority from a filled pending ticket to its position.
// Cancelled/orphaned tickets are still pruned once this bounded grace expires.
#define STB_EXPOSURE_ORPHAN_GRACE_SEC 120
bool STB_ExposureOrphanGraceActive(const ulong ticket,const datetime now)
  {
   for(int i=0;i<ArraySize(g_stbExposure);i++)
     {
      if(g_stbExposure[i].ticket!=ticket)
         continue;

      datetime seen=g_stbExposure[i].lastSeen;
      if(seen<=0)
         return false;

      long age=(long)(now-seen);
      return (age>=0 && age<STB_EXPOSURE_ORPHAN_GRACE_SEC);
     }

   return false;
  }

// Purge persisted overrides. all=true removes every stored key (AUTO clear);
// all=false removes only tickets that no longer exist in the terminal.
void STB_OverridePersistPrune(const bool all)
  {
   // Scope cleanup to this account + magic, covering the compact current key
   // and the legacy human-readable key. Other EA-instance records are untouched.
   string compactPref=ScopedStateName("OVR")+"_";
   string legacyPref=g_prefix+"OVR_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+
                     (string)InpMagic+"_";

   for(int i=GlobalVariablesTotal()-1;i>=0;i--)
     {
      string name=GlobalVariableName(i);
      bool compact=(StringFind(name,compactPref)==0);
      // Tester may prune its scoped records but never LIVE legacy keys.
      bool legacy=(!MQLInfoInteger(MQL_TESTER) &&
                   StringFind(name,legacyPref)==0);
      if(!compact && !legacy)
         continue;

      if(all)
        {
         GlobalVariableDel(name);
         continue;
        }

      int p=-1;
      for(int k=StringLen(name)-1;k>=0;k--)
         if(StringGetCharacter(name,k)=='_')
           {
            p=k;
            break;
           }

      if(p<0)
         continue;

      ulong ticket=(ulong)StringToInteger(StringSubstr(name,p+1));
      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket) && !OrderSelect(ticket) &&
         !STB_ExposureOrphanGraceActive(ticket,TimeCurrent()))
         GlobalVariableDel(name);
     }
  }

int STB_ExposureFind(const ulong ticket)
  {
   for(int i=0;i<ArraySize(g_stbExposure);i++)
      if(g_stbExposure[i].ticket==ticket)
         return i;
   return -1;
  }

int STB_ExposureEnsure(const ulong ticket,const bool isPosition)
  {
   if(ticket==0)
      return -1;
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
     {
      idx=ArraySize(g_stbExposure);
      if(ArrayResize(g_stbExposure,idx+1)!=idx+1)
        {
         Print("STB exposure registry allocation failed ticket=",ticket,
               " requestedSize=",idx+1);
         return -1;
        }
      g_stbExposure[idx].ticket=ticket;
      g_stbExposure[idx].manualOverride=false;
      g_stbExposure[idx].lastWriteCycle=0;
      g_stbExposure[idx].entry=0.0;
      g_stbExposure[idx].sl=0.0;
      g_stbExposure[idx].tp=0.0;
      g_stbExposure[idx].symbol=STB_ExposureSymbolOf(ticket);
      if(g_stbExposure[idx].symbol!="" &&
         STB_OverridePersistOn(ticket,g_stbExposure[idx].symbol))
        {
         g_stbExposure[idx].manualOverride=true; // MANUAL_OVERRIDE: restored from persistent storage
         Print("STB MANUAL_OVERRIDE RESTORED ticket=",IntegerToString((int)ticket));
        }
     }
   g_stbExposure[idx].isPosition=isPosition;
   g_stbExposure[idx].lastSeen=TimeCurrent();
   return idx;
  }

//--- manual override (Blueprint 15) ---------------------------------
bool STB_ManualOverrideIs(const ulong ticket)
  {
   int idx=STB_ExposureFind(ticket);
   if(idx>=0)
      return g_stbExposure[idx].manualOverride;
   // Persistent override is consulted by pending-order managers only;
   // open-position protection deliberately ignores this flag.
   return STB_OverridePersistOn(ticket,STB_ExposureSymbolOf(ticket));
  }

void STB_ManualOverrideSet(const ulong ticket)
  {
   if(ticket==0)
      return;
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
     {
      bool isPos=PositionSelectByTicket(ticket);
      idx=STB_ExposureEnsure(ticket,isPos);
     }
   if(idx<0 || g_stbExposure[idx].manualOverride)
      return;
   g_stbExposure[idx].manualOverride=true;
   STB_OverridePersistSet(ticket,STB_ExposureSymbolOf(ticket)); // MANUAL_OVERRIDE persistence (storage only)
   Print("STB MANUAL_OVERRIDE ON ticket=",IntegerToString((int)ticket));
  }


void STB_ManualOverrideClearAll()
  {
   for(int i=0;i<ArraySize(g_stbExposure);i++)
      g_stbExposure[i].manualOverride=false;
   STB_OverridePersistPrune(true); // MANUAL_OVERRIDE: AUTO clears the persistent mirror too
   Print("STB MANUAL_OVERRIDE CLEARED (AUTO) - auto management re-enabled");
  }

//--- geometry memory (owns-write baseline + intake baseline) --------
double STB_GeomTolerance(const string symbol)
  {
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double t=MathMax(point*0.5,(tickSize>0.0 ? tickSize*0.5 : point*0.5));
   return (t>0.0 ? t : point);
  }

void STB_GeomStore(const ulong ticket,const bool isPosition,
                   const double entry,const double sl,const double tp)
  {
   int idx=STB_ExposureEnsure(ticket,isPosition);
   if(idx<0)
      return;
   g_stbExposure[idx].entry=entry;
   g_stbExposure[idx].sl=sl;
   g_stbExposure[idx].tp=tp;
  }

bool STB_GeomIsKnown(const ulong ticket,const bool isPosition,
                     const double entry,const double sl,const double tp,
                     const string symbol)
  {
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
     {
      // Do not report geometry as known unless a registry row was actually
      // allocated and seeded. Allocation failure must remain distinguishable
      // from a successful baseline initialization.
      idx=STB_ExposureEnsure(ticket,isPosition);
      if(idx<0)
        {
         Print("STB geometry baseline unavailable ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         return false;
        }
      g_stbExposure[idx].entry=entry;
      g_stbExposure[idx].sl=sl;
      g_stbExposure[idx].tp=tp;
      return true;
     }

   // A registry row may have been allocated by ExposureEnsure before this
   // first geometry comparison. Its zero entry is an unseeded sentinel, not
   // evidence that the current terminal geometry is a manual edit.
   // Seed the first observed snapshot and report it as known; subsequent
   // changes are compared against this baseline normally.
   if(g_stbExposure[idx].entry<=0.0 && entry>0.0)
     {
      g_stbExposure[idx].entry=entry;
      g_stbExposure[idx].sl=sl;
      g_stbExposure[idx].tp=tp;
      Print("STB geometry baseline seeded ticket=",ticket,
            " reason=FIRST_VALID_SNAPSHOT");
      return true;
     }

   double tol=STB_GeomTolerance(symbol);
   return (MathAbs(g_stbExposure[idx].entry-entry)<=tol &&
           MathAbs(g_stbExposure[idx].sl-sl)<=tol &&
           MathAbs(g_stbExposure[idx].tp-tp)<=tol);
  }

void STB_GeomPrune()
  {
   for(int i=ArraySize(g_stbExposure)-1;i>=0;i--)
     {
      bool alive=(g_stbExposure[i].isPosition
                  ? PositionSelectByTicket(g_stbExposure[i].ticket)
                  : OrderSelect(g_stbExposure[i].ticket));
      if(!alive)
        {
         // A pending order may have filled just before its DEAL_ADD callback.
         // Preserve its override record long enough for intake to transfer it.
         if(STB_ExposureOrphanGraceActive(g_stbExposure[i].ticket,TimeCurrent()))
            continue;

         STB_OverridePersistDel(g_stbExposure[i].ticket,g_stbExposure[i].symbol);
         ArrayRemove(g_stbExposure,i,1);
        }
     }
  }

//--- transaction intake (Blueprint 10/28, H-11 safe direction) ------
void STB_ManualOverrideIntake(const MqlTradeTransaction &trans)
  {
   if(trans.type==TRADE_TRANSACTION_POSITION && trans.position>0)
     {
      ulong ticket=trans.position;
      if( !STB_IsProtectionPosition(ticket))
         return;
      string symbol=PositionGetString(POSITION_SYMBOL);
      double e=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      if(STB_ExposureEnsure(ticket,true)<0)
        {
         Print("STB POSITION GEOMETRY INTAKE DEFERRED ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         return;
        }
      if(!STB_GeomIsKnown(ticket,true,e,sl,tp,symbol))
         Print("STB POSITION GEOMETRY UPDATED ticket=",ticket,
               " symbol=",symbol,
               " SL=",DoubleToString(sl,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " TP=",DoubleToString(tp,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " automaticProtection=ACTIVE");
      STB_GeomStore(ticket,true,e,sl,tp);
      return;
     }

   if(trans.type==TRADE_TRANSACTION_ORDER_UPDATE && trans.order>0)
     {
      ulong ticket=trans.order;
      if(!OrderSelect(ticket) || !IsManagedOrder(ticket))
         return;
      string symbol=OrderGetString(ORDER_SYMBOL);
      double e=OrderGetDouble(ORDER_PRICE_OPEN);
      double sl=OrderGetDouble(ORDER_SL);
      double tp=OrderGetDouble(ORDER_TP);
      if(STB_ExposureEnsure(ticket,false)<0)
        {
         Print("STB ORDER GEOMETRY INTAKE DEFERRED ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         return;
        }

      if(!STB_GeomIsKnown(ticket,false,e,sl,tp,symbol))
        {
         STB_ManualOverrideSet(ticket);

         // A manual geometry edit becomes the new explicit trail baseline.
         // Otherwise the old EB / SL distance could make the next user-issued
         // PEND TRAIL snap this order back toward its pre-edit geometry.
         long updatedType=OrderGetInteger(ORDER_TYPE);
         if(STB_PendingTrailIsManagedType(updatedType))
           {
            int trailIdx=STB_PendingTrailFind(ticket);
            if(trailIdx<0)
              {
               STB_PendingTrailRegister(ticket,"MANUAL_UPDATE");
               trailIdx=STB_PendingTrailFind(ticket);
              }

            MqlTick updateTick;
            double pip=PipSize(symbol);
            if(trailIdx>=0 && pip>0.0 &&
               SymbolInfoTick(symbol,updateTick))
              {
               int direction=STB_PendingTrailDirection(updatedType);
               int offsetSign=STB_PendingEntryOffsetSign((ENUM_ORDER_TYPE)updatedType);
               double anchor=(direction>0 ? updateTick.bid:updateTick.ask);

               if(anchor>0.0 && offsetSign!=0)
                 {
                  g_stbPendingTrail[trailIdx].entryBufferPips=
                     MathAbs(e-anchor)/pip;
                  g_stbPendingTrail[trailIdx].trackedExtreme=
                     e-offsetSign*g_stbPendingTrail[trailIdx].entryBufferPips*pip;
                  g_stbPendingTrail[trailIdx].lastEntry=e;
                  g_stbPendingTrail[trailIdx].lastSL=sl;

                  if(sl>0.0)
                     g_stbPendingTrail[trailIdx].slBufferPips=
                        MathAbs(e-sl)/pip;

                  g_stbPendingTrail[trailIdx].failureCount=0;
                  g_stbPendingTrail[trailIdx].nextRetryTime=0;
                  g_stbPendingTrail[trailIdx].lastModifyTime=TimeCurrent();
                 }
              }
           }
        }

      STB_GeomStore(ticket,false,e,sl,tp);
      return;
     }
  }

//==================================================================
// ONE MODIFY PER TICKET PER CYCLE + SAME-CYCLE SL ARBITRATION
//==================================================================
enum ENUM_STB_SL_SOURCE{ STB_SL_SRC_INITIAL=0, STB_SL_SRC_PROFIT_PROTECTION=1, STB_SL_SRC_TRAIL=2 };
struct STBSLProposal{ bool valid; bool hasSL; double sl; int source; string reason; };
struct STBQueuedSLProposal
  {
   ulong ticket;
   long cycle;
   bool valid;
   bool hasSL;
   double sl;
   int source;
   string reason;
  };
STBQueuedSLProposal g_stbSLQueue[];
bool g_stbCollectingSLProposals=false;
// Any queue allocation failure makes the automatic SL batch incomplete.
// Fail closed rather than silently resolving a subset of intended candidates.
bool g_stbSLCollectionFaulted=false;
long g_stbCycleId=0;

void STB_BeginCycle()
  {
   g_stbCycleId++;
   ArrayResize(g_stbSLQueue,0);
   g_stbCollectingSLProposals=false;
   g_stbSLCollectionFaulted=false;
  }

bool STB_QueuePositionSL(const ulong ticket,const double candidateSL,const int source,const string reason)
  {
   if(!g_stbCollectingSLProposals || ticket==0 || candidateSL<=0.0 ||
       !STB_IsProtectionPosition(ticket))
      return false;
   int n=ArraySize(g_stbSLQueue);
   if(ArrayResize(g_stbSLQueue,n+1)!=n+1)
     {
      g_stbSLCollectionFaulted=true;
      Print("STB SL arbitration collection failure: queue allocation failed cycle=",
            g_stbCycleId," ticket=",ticket," source=",source," reason=",reason);
      return false;
     }
   g_stbSLQueue[n].ticket=ticket;
   g_stbSLQueue[n].cycle=g_stbCycleId;
   g_stbSLQueue[n].valid=true;
   g_stbSLQueue[n].hasSL=true;
   g_stbSLQueue[n].sl=candidateSL;
   g_stbSLQueue[n].source=source;
   g_stbSLQueue[n].reason=reason;
   return true;
  }

bool STB_CycleWriteAlreadyDone(const ulong ticket)
  {
   if(g_stbCycleId==0)
      return false;
   int idx=STB_ExposureFind(ticket);
   return (idx>=0 && g_stbExposure[idx].lastWriteCycle==g_stbCycleId);
  }

void STB_CycleMarkWritten(const ulong ticket)
  {
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
      idx=STB_ExposureEnsure(ticket,false);
   if(idx>=0)
      g_stbExposure[idx].lastWriteCycle=g_stbCycleId;
  }

// Validate every proposal against one shared price/constraint snapshot.
// IsValidSLForPosition() is still used on the chosen candidate and again by
// the central modify bridge immediately before broker submission.
bool STB_IsValidSLForDecisionSnapshot(const long side,
                                      const double sl,
                                      const MqlTick &tick,
                                      const double point,
                                      const long stopsLevel,
                                      const long freezeLevel)
  {
   if(sl<=0.0 || point<=0.0 || tick.bid<=0.0 || tick.ask<=0.0)
      return false;
   double minimumDistance=(MathMax((double)stopsLevel,(double)freezeLevel)+1.0)*point;
   if(minimumDistance<=0.0)
      minimumDistance=point;
   if(side==POSITION_TYPE_BUY)
      return sl<tick.bid && (tick.bid-sl)>=minimumDistance;
   if(side==POSITION_TYPE_SELL)
      return sl>tick.ask && (sl-tick.ask)>=minimumDistance;
   return false;
  }

bool STB_ResolvePositionSL(const ulong ticket,STBSLProposal &props[],const int count,double &finalSL,int &finalSource)
  {
   finalSL=0.0; finalSource=-1;
   if(ticket==0 || count<=0 || !PositionSelectByTicket(ticket)) return false;
   string symbol=PositionGetString(POSITION_SYMBOL);
   long side=PositionGetInteger(POSITION_TYPE);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   // If net profit has crossed the universal lock trigger, a competing
   // automatic proposal may not replace the required lock with a weaker SL.
   // When the existing position has no SL at all, retain the strongest valid
   // non-profit-lock candidate as a last-resort protection fallback if broker
   // geometry makes the profit-lock target impossible this cycle.
   double decisionPriceMovePips=STB_PositionPriceMovePips(ticket);
   double pip=PipSize(symbol);
   bool enforceProfitLockFloor=
      (decisionPriceMovePips>=STB_ProfitLockTriggerPips() && pip>0.0);
   double profitLockTarget=0.0;
   if(enforceProfitLockFloor)
     {
      profitLockTarget=NormalizePrice(symbol,
         side==POSITION_TYPE_BUY
         ? entry+STB_ProfitLockLockPips()*pip
         : entry-STB_ProfitLockLockPips()*pip);
      if(profitLockTarget<=0.0)
         enforceProfitLockFloor=false;
     }

   // Use one tick and one broker-constraint snapshot for all proposals so
   // array arrival order cannot change which candidates pass geometry checks.
   MqlTick decisionTick;
   if(!SymbolInfoTick(symbol,decisionTick)) return false;
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   long stopsLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tieTolerance=(tickSize>0.0 ? tickSize*0.25:0.0);
   bool found=false;
   bool unprotectedFallbackFound=false;
   double unprotectedFallbackSL=0.0;
   int unprotectedFallbackSource=-1;
   for(int i=0;i<count;i++)
     {
      if(!props[i].valid || !props[i].hasSL || props[i].sl<=0.0) continue;
      double c=NormalizePrice(symbol,props[i].sl);
      if(c<=0.0 ||
         !STB_IsValidSLForDecisionSnapshot(side,c,decisionTick,point,stopsLevel,freezeLevel))
         continue;

      if(side==POSITION_TYPE_BUY)
        {
         if(currentSL>0.0 && c<=currentSL) continue;
        }
      else if(side==POSITION_TYPE_SELL)
        {
         if(currentSL>0.0 && c>=currentSL) continue;
        }
      else
         continue;

      bool meetsProfitLockFloor=!enforceProfitLockFloor ||
         (side==POSITION_TYPE_BUY ? c>=profitLockTarget:c<=profitLockTarget);
      if(!meetsProfitLockFloor)
        {
         // Never downgrade an installed SL below the active lock target.
         // Only a position with no existing SL may use the INITIAL candidate
         // as a fail-safe stop while the broker rejects the requested lock.
         if(currentSL<=0.0 && props[i].source!=STB_SL_SRC_PROFIT_PROTECTION)
           {
            bool strongerFallback=!unprotectedFallbackFound;
            if(unprotectedFallbackFound)
              {
               if(side==POSITION_TYPE_BUY && c>unprotectedFallbackSL)
                  strongerFallback=true;
               else if(side==POSITION_TYPE_SELL && c<unprotectedFallbackSL)
                  strongerFallback=true;
               else if(MathAbs(c-unprotectedFallbackSL)<=tieTolerance &&
                       props[i].source<unprotectedFallbackSource)
                  strongerFallback=true;
              }
            if(strongerFallback)
              {
               unprotectedFallbackSL=c;
               unprotectedFallbackSource=props[i].source;
               unprotectedFallbackFound=true;
              }
           }
         continue;
        }

      if(side==POSITION_TYPE_BUY)
        {
         if(!found || c>finalSL || (MathAbs(c-finalSL)<=tieTolerance && props[i].source<finalSource))
           { finalSL=c; finalSource=props[i].source; found=true; }
        }
      else if(side==POSITION_TYPE_SELL)
        {
         if(!found || c<finalSL || (MathAbs(c-finalSL)<=tieTolerance && props[i].source<finalSource))
           { finalSL=c; finalSource=props[i].source; found=true; }
        }
     }

   // With no installed SL, use the strongest valid non-lock stop if broker
   // geometry prevents the minimum profit-lock target from being placed.
   // This emergency fallback is never used to loosen an existing position.
   if(!found && unprotectedFallbackFound)
     {
      finalSL=unprotectedFallbackSL;
      finalSource=unprotectedFallbackSource;
      found=true;
     }

   // The chosen candidate must still satisfy the live broker constraint check.
   // If the market moved since the decision snapshot, fail closed this cycle.
   if(!found || !IsValidSLForPosition(symbol,side,finalSL))
      return false;
   return true;
  }

bool STB_SubmitPositionSL(const ulong ticket,const double candidateSL,const int source,const string reason,const bool isUserAction=false)
  {
   if(ticket==0 ||  !STB_IsProtectionPosition(ticket))
      return false;

   // Explicit user SAVE remains synchronous and isolated from automatic batches.
   if(isUserAction)
      return ModifyPositionSL(ticket,candidateSL,true);

   if(g_stbCollectingSLProposals)
      return STB_QueuePositionSL(ticket,candidateSL,source,reason);

   // Lifecycle exception: a newly-created position may need its initial
   // protective stop before the next scheduled management cycle. Do not let
   // trailing/profit-protection silently bypass same-cycle arbitration.
   if(source!=STB_SL_SRC_INITIAL)
     {
      Print("STB SL request blocked outside arbitration cycle ticket=",ticket,
            " source=",source," reason=",reason);
      return false;
     }

   return ModifyPositionSL(ticket,candidateSL,false);
  }

void STB_ProfitProtectionOne(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return;
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double priceMovePips=STB_PositionPriceMovePips(ticket);
   double locked=GetLockedPips(ticket);
   double triggerPips=STB_ProfitLockTriggerPips();
   double lockPips=STB_ProfitLockLockPips();
   double pip=PipSize(symbol);

   // Trigger from executable price movement, not cash PnL divided by pip value.
   // Net pips are diagnostic because commission and swap can differ.
   bool liveStopSatisfiesPolicy=false;
   if(pip>0.0 && entry>0.0 && currentSL>0.0)
     {
      double policySL=NormalizePrice(symbol,
         type==POSITION_TYPE_BUY ? entry+lockPips*pip : entry-lockPips*pip);
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double tolerance=MathMax(point*0.5,
                               tickSize>0.0 ? tickSize*0.5:point*0.5);
      if(type==POSITION_TYPE_BUY)
         liveStopSatisfiesPolicy=(policySL>0.0 && currentSL+tolerance>=policySL);
      else if(type==POSITION_TYPE_SELL)
         liveStopSatisfiesPolicy=(policySL>0.0 && currentSL-tolerance<=policySL);
     }
   if(priceMovePips>=triggerPips && (locked<lockPips || !liveStopSatisfiesPolicy))
     {
      double netProfitPips=PositionNetProfitPips(ticket);
      Print("STB AUTO PROFIT LOCK TRIGGER ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " priceMovePips=",DoubleToString(priceMovePips,1),
            " netProfitPips=",DoubleToString(netProfitPips,1),
            " pipSize=",DoubleToString(pip,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " triggerPips=",DoubleToString(triggerPips,1),
            " lockPips=",DoubleToString(lockPips,1),
            " lockedPips=",DoubleToString(locked,1),
            " liveSL=",DoubleToString(currentSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " liveStopSatisfiesPolicy=",liveStopSatisfiesPolicy);
      ApplyProfitLock(ticket,lockPips);
     }
  }

// The single broker-facing position modification writer for SL and TP.
// Callers validate their own intent; this bridge enforces snapshot ownership,
// single-write-per-cycle, server retcodes, and terminal-state verification.
bool STB_PositionModifyBrokerVerified(const ulong ticket,
                                      const double expectedEntry,
                                      const double expectedSL,
                                      const double expectedTP,
                                      const double newSL,
                                      const double newTP,
                                      const string failureKey,
                                      const string operation)
  {
   g_modifyWasNoChanges=false;
   if(ticket==0 || !PositionSelectByTicket(ticket) ||
      !STB_IsProtectionPosition(ticket))
      return false;

   if(STB_ExposureEnsure(ticket,true)<0)
     {
      Print("STB POSITION MODIFY DEFERRED ticket=",ticket,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return false;
     }

   string symbol=PositionGetString(POSITION_SYMBOL);
   if(symbol=="" || !STB_SymbolManagementOwnedVerified(symbol))
      return false;

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(point<=0.0)
      return false;
   double tolerance=MathMax(point*0.5,
                            tickSize>0.0 ? tickSize*0.5:point*0.5);

   double liveEntry=PositionGetDouble(POSITION_PRICE_OPEN);
   double liveSL=PositionGetDouble(POSITION_SL);
   double liveTP=PositionGetDouble(POSITION_TP);
   long side=PositionGetInteger(POSITION_TYPE);
   if(MathAbs(liveEntry-expectedEntry)>tolerance ||
      MathAbs(liveSL-expectedSL)>tolerance ||
      MathAbs(liveTP-expectedTP)>tolerance)
     {
      Print("STB POSITION MODIFY ABORTED: snapshot changed ticket=",ticket,
            " operation=",operation,
            " entryExpected=",DoubleToString(expectedEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " entryLive=",DoubleToString(liveEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " slExpected=",DoubleToString(expectedSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " slLive=",DoubleToString(liveSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpExpected=",DoubleToString(expectedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpLive=",DoubleToString(liveTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
     }

   if(newSL<=0.0 || newTP<0.0)
      return false;

   // For a SL change, validate the new level immediately before the request.
   // For a TP-only change, the existing SL is preserved exactly.
   if(MathAbs(newSL-liveSL)>tolerance &&
      !IsValidSLForPosition(symbol,side,newSL))
      return false;

   if(STB_CycleWriteAlreadyDone(ticket))
      return false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);
   trade.SetTypeFillingBySymbol(symbol);

   // Cache the intended geometry before submitting so our own transaction is
   // not misclassified as a manual override. Failure paths restore actual state.
   STB_GeomStore(ticket,true,liveEntry,newSL,newTP);

   // Consume the ticket's single-write budget on the attempt, not only on
   // success. An immediate TP fallback must not retry a failed SL+TP request
   // a second time in the same management cycle.
   STB_CycleMarkWritten(ticket);

   ResetLastError();
   bool requestOK=trade.PositionModify(ticket,newSL,newTP);
   uint ret=trade.ResultRetcode();
   if(!requestOK || (ret!=TRADE_RETCODE_NO_CHANGES &&
                     !TradeRetcodeModifySucceeded()))
     {
      if(PositionSelectByTicket(ticket))
         STB_GeomStore(ticket,true,
                       PositionGetDouble(POSITION_PRICE_OPEN),
                       PositionGetDouble(POSITION_SL),
                       PositionGetDouble(POSITION_TP));
      if(failureKey!="")
         GlobalVariableSet(failureKey,(double)TimeCurrent());
      Print("STB POSITION MODIFY FAILED ticket=",ticket,
            " symbol=",symbol,
            " operation=",operation,
            " requestOK=",requestOK,
            " ret=",IntegerToString((int)ret),
            " desc=",trade.ResultRetcodeDescription(),
            " err=",IntegerToString(GetLastError()));
      return false;
     }

   if(!PositionSelectByTicket(ticket))
     {
      if(failureKey!="")
         GlobalVariableSet(failureKey,(double)TimeCurrent());
      return false;
     }

   double verifiedEntry=PositionGetDouble(POSITION_PRICE_OPEN);
   double verifiedSL=PositionGetDouble(POSITION_SL);
   double verifiedTP=PositionGetDouble(POSITION_TP);
   bool verified=(MathAbs(verifiedEntry-expectedEntry)<=tolerance &&
                  MathAbs(verifiedSL-newSL)<=tolerance &&
                  MathAbs(verifiedTP-newTP)<=tolerance);
   if(!verified)
     {
      STB_GeomStore(ticket,true,verifiedEntry,verifiedSL,verifiedTP);
      if(failureKey!="")
         GlobalVariableSet(failureKey,(double)TimeCurrent());
      Print("STB POSITION MODIFY CONFIRM MISMATCH ticket=",ticket,
            " symbol=",symbol,
            " operation=",operation,
            " slExpected=",DoubleToString(newSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " slActual=",DoubleToString(verifiedSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpExpected=",DoubleToString(newTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpActual=",DoubleToString(verifiedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
     }

   STB_GeomStore(ticket,true,verifiedEntry,verifiedSL,verifiedTP);
   STB_CycleMarkWritten(ticket);
   if(failureKey!="")
      GlobalVariableDel(failureKey);
   if(ret==TRADE_RETCODE_NO_CHANGES)
      g_modifyWasNoChanges=true;
   Print("STB POSITION MODIFY CONFIRMED ticket=",ticket,
         " symbol=",symbol,
         " operation=",operation,
         " SL=",DoubleToString(verifiedSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " TP=",DoubleToString(verifiedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " ret=",IntegerToString((int)ret));
   return true;
  }

/* P2 single-writer bridge */ bool ModifyPositionSL(const ulong ticket,
                      const double newSL,
                      const bool isUserAction=false,
                      const double requestedTP=-1.0)
  {
   g_modifyWasNoChanges=false;
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(symbol))
     {
      Print("STB MODIFY WAIT: symbol-management lease not owned ticket=",ticket,
            " symbol=",symbol," chart=",ChartID());
      return false;
     }

   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double currentTP=PositionGetDouble(POSITION_TP);

   if(currentSL>0.0)
     {
      if(type==POSITION_TYPE_BUY && newSL<=currentSL)
         return true;
      if(type==POSITION_TYPE_SELL && newSL>=currentSL)
         return true;
     }

   if(!IsValidSLForPosition(symbol,type,newSL))
     {
      MqlTick invalidTick;
      SymbolInfoTick(symbol,invalidTick);
      Print("STB MODIFY WAIT: invalid SL geometry ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " candidateSL=",DoubleToString(newSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " bid=",DoubleToString(invalidTick.bid,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " ask=",DoubleToString(invalidTick.ask,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL),
            " freezeLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL));
      return false;
     }

   if(STB_CycleWriteAlreadyDone(ticket))
      return false;

   string gv=ScopedStateName("MODFAIL_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(gv))
     {
      double lastFail=GlobalVariableGet(gv);
      if(lastFail>0.0 && (TimeCurrent()-lastFail)<2)
         return false;
     }

   // Snapshot is checked twice: here and again at the shared broker writer.
   if(!PositionSelectByTicket(ticket))
      return false;
   double latestEntry=PositionGetDouble(POSITION_PRICE_OPEN);
   double latestSL=PositionGetDouble(POSITION_SL);
   double latestTP=PositionGetDouble(POSITION_TP);
   long latestType=PositionGetInteger(POSITION_TYPE);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tol=MathMax(point*0.5,
                      tickSize>0.0 ? tickSize*0.5:point*0.5);

   if(latestType!=type ||
      MathAbs(latestEntry-entry)>tol ||
      MathAbs(latestSL-currentSL)>tol ||
      MathAbs(latestTP-currentTP)>tol)
     {
      Print("STB MODIFY ABORTED: position state changed before request ticket=",ticket,
            " symbol=",symbol);
      return false;
     }

   if(latestSL>0.0 &&
      ((latestType==POSITION_TYPE_BUY && newSL<=latestSL) ||
       (latestType==POSITION_TYPE_SELL && newSL>=latestSL)))
      return true;
   if(!IsValidSLForPosition(symbol,latestType,newSL) ||
      !STB_SymbolManagementOwnedVerified(symbol))
      return false;

   double targetTP=latestTP;
   if(latestTP<=0.0 && requestedTP>=0.0)
      targetTP=requestedTP; // only fill an absent TP; never replace an explicit one

   return STB_PositionModifyBrokerVerified(ticket,
                                           latestEntry,
                                           latestSL,
                                           latestTP,
                                           newSL,
                                           targetTP,
                                           gv,
                                           (targetTP!=latestTP ? "SL+TP":"SL"));
  }

// Resolve all automatic candidates after the three managers have run.
// The selected write is revalidated by ModifyPositionSL against live terminal state.
bool STB_CalculatePositionTPFromStructure(const string symbol,
                                          const long positionType,
                                          const double entry,
                                          const double sl,
                                          const double minimumRR,
                                          double &tp,
                                          string &source);

void STB_FlushPositionSLProposals()
  {
   g_stbCollectingSLProposals=false;
   bool collectionFault=g_stbSLCollectionFaulted;
   g_stbSLCollectionFaulted=false;
   if(collectionFault)
     {
      Print("STB SL arbitration ABORTED: incomplete proposal queue; no automatic SL writes this cycle=",
            g_stbCycleId," queued=",ArraySize(g_stbSLQueue));
      ArrayResize(g_stbSLQueue,0);
      return;
     }
   for(int i=0;i<ArraySize(g_stbSLQueue);i++)
     {
      ulong ticket=g_stbSLQueue[i].ticket;
      if(ticket==0 || g_stbSLQueue[i].cycle!=g_stbCycleId) continue;
      bool seen=false;
      for(int j=0;j<i;j++)
         if(g_stbSLQueue[j].ticket==ticket && g_stbSLQueue[j].cycle==g_stbCycleId) { seen=true; break; }
      if(seen ||  !STB_IsProtectionPosition(ticket)) continue;
      STBSLProposal props[];
      int count=0;
      for(int j=i;j<ArraySize(g_stbSLQueue);j++)
         if(g_stbSLQueue[j].ticket==ticket && g_stbSLQueue[j].cycle==g_stbCycleId)
            count++;
      if(count<=0) continue;
      if(ArrayResize(props,count)!=count)
        {
         Print("STB SL arbitration ABORTED for ticket=",ticket,
               ": cannot allocate full candidate set cycle=",g_stbCycleId,
               " candidates=",count);
         continue; // never arbitrate a silently truncated candidate set
        }
      int propIndex=0;
      for(int j=i;j<ArraySize(g_stbSLQueue);j++)
        {
         if(g_stbSLQueue[j].ticket!=ticket || g_stbSLQueue[j].cycle!=g_stbCycleId) continue;
         props[propIndex].valid=g_stbSLQueue[j].valid; props[propIndex].hasSL=g_stbSLQueue[j].hasSL;
         props[propIndex].sl=g_stbSLQueue[j].sl; props[propIndex].source=g_stbSLQueue[j].source;
         props[propIndex].reason=g_stbSLQueue[j].reason; propIndex++;
        }
      double chosenSL=0.0; int chosenSource=-1;
      if(count<=0 || !STB_ResolvePositionSL(ticket,props,count,chosenSL,chosenSource))
        {
         Print("STB SL arbitration WAIT: no valid candidate ticket=",ticket,
               " cycle=",g_stbCycleId,
               " candidates=",count);
         continue;
        }
      string symbol=PositionGetString(POSITION_SYMBOL);
      long side=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      bool hasProfitCandidate=false;
      for(int j=0;j<count;j++)
         if(props[j].valid && props[j].hasSL && props[j].source==STB_SL_SRC_PROFIT_PROTECTION)
            hasProfitCandidate=true;
      // If no TP exists, calculate a target from the same chosen SL and attach
      // it to this single verified modify request. This prevents a continuously
      // improving trail from starving the missing-TP manager every cycle.
      double currentTP=PositionGetDouble(POSITION_TP);
      double tpForRequest=-1.0; // negative sentinel = preserve the live TP
      if(currentTP<=0.0)
        {
         tpForRequest=0.0;
         double proposedTP=0.0;
         string tpSource="";
         if(STB_CalculatePositionTPFromStructure(symbol,side,entry,chosenSL,
                                                  InpMinimumRR,proposedTP,tpSource))
           {
            tpForRequest=proposedTP;
            Print("STB SL+TP ARBITRATION target ticket=",ticket,
                  " source=",tpSource,
                  " TP=",DoubleToString(proposedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
           }
        }
      if(!ModifyPositionSL(ticket,chosenSL,false,tpForRequest) ||
         !PositionSelectByTicket(ticket)) continue;
      double actualSL=PositionGetDouble(POSITION_SL);
      // A missing SL must never be treated as a confirmed protective stop;
      // this is especially important for SELL-side lock-pips bookkeeping.
      if(actualSL<=0.0)
        {
         Print("STB SL arbitration verification failed: position has no SL ticket=",ticket,
               " cycle=",g_stbCycleId);
         continue;
        }
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double tolerance=MathMax(point*0.5,tickSize>0.0 ? tickSize*0.5:point*0.5);
      if(side==POSITION_TYPE_BUY && actualSL+tolerance<chosenSL) continue;
      if(side==POSITION_TYPE_SELL && actualSL-tolerance>chosenSL) continue;
      if(hasProfitCandidate)
        {
         double pip=PipSize(symbol);
         double lockTargetSL=(pip>0.0 ?
            NormalizePrice(symbol,
               side==POSITION_TYPE_BUY
               ? entry+STB_ProfitLockLockPips()*pip
               : entry-STB_ProfitLockLockPips()*pip):0.0);
         bool lockTargetConfirmed=
            (lockTargetSL>0.0 && pip>0.0 &&
             (side==POSITION_TYPE_BUY
              ? actualSL+tolerance>=lockTargetSL
              : actualSL-tolerance<=lockTargetSL));
         // Do not persist a partial/sub-minimum lock merely because some
         // profit-protection proposal was queued but lost live validation.
         if(lockTargetConfirmed)
           {
            double achieved=(side==POSITION_TYPE_BUY
                             ? (actualSL-entry)/pip
                             : (entry-actualSL)/pip);
            if(achieved>0.0)
               SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));
           }
        }
      Print("STB SL arbitration confirmed ticket=",ticket," source=",chosenSource,
            " SL=",DoubleToString(actualSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " candidates=",count);
     }
   ArrayResize(g_stbSLQueue,0);
  }

//==================================================================
// APPLY PROFIT LOCK//==================================================================
// APPLY PROFIT LOCK
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApplyProfitLock(const ulong ticket,const double lockPips,const bool isUserAction=false)
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
         // The observed SL may change outside this EA between the initial read
         // and the bookkeeping update. Re-read terminal state before crediting
         // a lock that is already satisfied without a broker write.
         if(!PositionSelectByTicket(ticket))
            return false;
         long liveType=PositionGetInteger(POSITION_TYPE);
         double liveSL=PositionGetDouble(POSITION_SL);
         double liveEntry=PositionGetDouble(POSITION_PRICE_OPEN);
         double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
         double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
         double tolerance=MathMax(point*0.5,
                                  tickSize>0.0 ? tickSize*0.5:point*0.5);
         if(liveType!=POSITION_TYPE_BUY || liveSL<=0.0 ||
            liveSL+tolerance<targetSL)
            return false;
         double achieved=(liveSL-liveEntry)/pip;
         if(achieved<=0.0)
            return false;
         SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));
         return true;
      }
   }

   if(type==POSITION_TYPE_SELL)
   {
      targetSL=NormalizePrice(symbol,entry-lockPips*pip);

      if(currentSL>0.0 && targetSL>=currentSL)
      {
         // Confirm the live SELL stop still protects at least the requested
         // lock before persisting lock bookkeeping.
         if(!PositionSelectByTicket(ticket))
            return false;
         long liveType=PositionGetInteger(POSITION_TYPE);
         double liveSL=PositionGetDouble(POSITION_SL);
         double liveEntry=PositionGetDouble(POSITION_PRICE_OPEN);
         double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
         double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
         double tolerance=MathMax(point*0.5,
                                  tickSize>0.0 ? tickSize*0.5:point*0.5);
         if(liveType!=POSITION_TYPE_SELL || liveSL<=0.0 ||
            liveSL-tolerance>targetSL)
            return false;
         double achieved=(liveEntry-liveSL)/pip;
         if(achieved<=0.0)
            return false;
         SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));
         return true;
      }
   }

   if(!IsValidSLForPosition(symbol,type,targetSL))
   {
      MqlTick tick;
      SymbolInfoTick(symbol,tick);

      Print("STB PROFIT LOCK WAIT/REJECT ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " profitPips=",DoubleToString(PositionProfitPips(symbol,type,entry),1),
            " requestedLockPips=",DoubleToString(lockPips,1),
            " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " currentSL=",DoubleToString(currentSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " targetSL=",DoubleToString(targetSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " bid=",DoubleToString(tick.bid,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " ask=",DoubleToString(tick.ask,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",IntegerToString((int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)),
            " freezeLevel=",IntegerToString((int)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL)));
      return false;
   }

   if(!STB_SubmitPositionSL(ticket,targetSL,STB_SL_SRC_PROFIT_PROTECTION,"PROFIT_PROTECTION",isUserAction))
      return false;

   if(!g_stbCollectingSLProposals || isUserAction)
      SetLockedPips(ticket,MathMax(GetLockedPips(ticket),lockPips));

   return true;
}

//==================================================================
// AUTO +50 -> +20 (UNIVERSAL PROFIT LOCK POLICY, all managed positions)
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AutoProfitProtection()
{
   // One implementation owns the universal trigger and lock policy.
   // Open-position management remains active regardless of manual SL/TP edits.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;

      STB_ProfitProtectionOne(ticket);
   }
}

//==================================================================
// MANUAL SAVE +20
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManualSavePlus20()
  {
   STB_BeginCycle(); // Blueprint 26: user SAVE command gets its own decision cycle
   int managed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !IsManagedPosition(ticket))
         continue;

      managed++;

      string symbol=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double profit=PositionNetProfitPips(ticket);
      double currentLock=GetLockedPips(ticket);
      double requested=currentLock+InpManualSaveStepPips;

      if(profit>=requested)
          ApplyProfitLock(ticket,requested,true);
     }

   Print("STB SAVE +20 executed for managed positions count=",managed);
  }

// Rate-limit structural-trailing WAIT messages per position.
void STB_StructuralTrailWaitLog(const ulong ticket,
                                const string reason,
                                const double movePips,
                                const double atr)
  {
   if(ticket==0 || reason=="")
      return;
   string key=ScopedStateName("STRUCTTRAIL_WAIT_"+(string)ticket);
   datetime now=TimeCurrent();
   if(GlobalVariableCheck(key) &&
      now-(datetime)GlobalVariableGet(key)<60)
      return;
   GlobalVariableSet(key,(double)now);
   string symbol="";
   long side=-1;
   if(PositionSelectByTicket(ticket))
     {
      symbol=PositionGetString(POSITION_SYMBOL);
      side=PositionGetInteger(POSITION_TYPE);
     }
   Print("STB STRUCTURAL TRAIL WAIT ticket=",ticket,
         " symbol=",symbol,
         " side=",(side==POSITION_TYPE_BUY ? "BUY":
                   side==POSITION_TYPE_SELL ? "SELL":"UNKNOWN"),
         " reason=",reason,
         " movePips=",DoubleToString(movePips,1),
         " atr=",DoubleToString(atr,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " tf=",EnumToString(InpTrailTF));
  }

bool STB_CalculateStructuralTrailSL(const ulong ticket,
                                    double &candidate,
                                    string &reason,
                                    double &atrOut)
  {
   candidate=0.0;
   atrOut=0.0;
   reason="STRUCTURAL_TRAIL_UNAVAILABLE";
   if(ticket==0 || !STB_IsProtectionPosition(ticket) ||
      !PositionSelectByTicket(ticket))
     {
      reason="POSITION_NOT_AVAILABLE";
      return false;
     }

   string symbol=PositionGetString(POSITION_SYMBOL);
   long side=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   if(entry<=0.0 || currentSL<=0.0)
     {
      reason="NO_INITIAL_SL";
      return false; // initial SL must be confirmed before trailing can run
     }

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);
   double minDist=TradeMinDistance(symbol);
   if(point<=0.0 || pip<=0.0 || minDist<=0.0)
     {
      reason="BROKER_GEOMETRY_UNAVAILABLE";
      return false;
     }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
     {
      reason="LIVE_QUOTE_UNAVAILABLE";
      return false;
     }

   int lookback=(int)MathMax(80,InpLookbackM15);
   MqlRates rates[];
   if(!GetRates(symbol,InpTrailTF,lookback,rates))
     {
      reason="TRAIL_TIMEFRAME_DATA_UNAVAILABLE";
      return false;
     }

   double atr=LocalATR(rates,1,14);
   atrOut=atr;
   if(atr<=0.0 || !MathIsValidNumber(atr))
     {
      reason="TRAIL_ATR_UNAVAILABLE";
      return false;
     }

   double movePips=STB_PositionPriceMovePips(ticket);
   double movePrice=movePips*pip;
   if(movePrice<atr*InpStructuralTrailStartATR)
     {
      reason="ATR_ACTIVATION_NOT_REACHED";
      return false;
     }

   SwingPoint highs[];
   SwingPoint lows[];
   if(CollectSwings(symbol,InpTrailTF,lookback,highs,lows)<=0)
     {
      reason="CONFIRMED_SWINGS_UNAVAILABLE";
      return false;
     }

   double buffer=MathMax(InpInitialSLBufferPips*pip,
                         atr*InpStructuralTrailBufferATR);
   double step=MathMax(0.0,InpTrailStepPips)*pip;
   double locked=GetLockedPips(ticket);

   if(side==POSITION_TYPE_BUY)
     {
      // CollectSwings returns older-to-newer pivots; inspect newest first.
      for(int i=ArraySize(lows)-1;i>=0;i--)
        {
         double swing=lows[i].price;
         if(swing<=0.0 || swing>=tick.bid)
            continue;
         double next=NormalizePrice(symbol,swing-buffer);
         if(next<=0.0 || next>=tick.bid-minDist)
            continue;
         if(locked>0.0)
            next=MathMax(next,NormalizePrice(symbol,entry+locked*pip));
         if(next<=entry || (currentSL>0.0 && next<=currentSL))
            continue;
         if(currentSL>0.0 && next-currentSL+point*0.1<step)
            continue;
         if(!IsValidSLForPosition(symbol,side,next))
            continue;
         candidate=next;
         reason="";
         return true;
        }
     }
   else if(side==POSITION_TYPE_SELL)
     {
      for(int i=ArraySize(highs)-1;i>=0;i--)
        {
         double swing=highs[i].price;
         if(swing<=tick.ask)
            continue;
         double next=NormalizePrice(symbol,swing+buffer);
         if(next<=tick.ask+minDist)
            continue;
         if(locked>0.0)
            next=MathMin(next,NormalizePrice(symbol,entry-locked*pip));
         if(next>=entry || (currentSL>0.0 && next>=currentSL))
            continue;
         if(currentSL>0.0 && currentSL-next+point*0.1<step)
            continue;
         if(!IsValidSLForPosition(symbol,side,next))
            continue;
         candidate=next;
         reason="";
         return true;
        }
     }
   else
     {
      reason="UNSUPPORTED_POSITION_SIDE";
      return false;
     }

   reason="NO_CONFIRMED_SWING_CAN_IMPROVE_VALID_SL";
   return false;
  }

//==================================================================
// M15 CLOSED-CANDLE / STRUCTURAL TRAILING
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TrailPositionByLivePrice(const ulong ticket)
{
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return false;
   // Manual SL/TP edits do not disable automated protection/trailing.
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double profit=STB_PositionPriceMovePips(ticket);

   if(InpUseStructuralTrailing)
     {
      double structuralSL=0.0;
      double trailATR=0.0;
      string waitReason="";
      if(!STB_CalculateStructuralTrailSL(ticket,structuralSL,waitReason,trailATR))
        {
         STB_StructuralTrailWaitLog(ticket,waitReason,profit,trailATR);
         return false;
        }

      // All automatic stop candidates still go through the existing shared
      // proposal queue/resolver; never bypass SL arbitration or its broker checks.
      bool submitted=STB_SubmitPositionSL(ticket,structuralSL,
                                          STB_SL_SRC_TRAIL,"STRUCTURAL_TRAIL");
      if(submitted && !g_stbCollectingSLProposals)
         Print("STB STRUCTURAL TRAIL submitted ticket=",ticket,
               " symbol=",symbol,
               " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
               " movePips=",DoubleToString(profit,1),
               " atr=",DoubleToString(trailATR,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " SL=",DoubleToString(structuralSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return submitted;
     }

   if(profit < InpTrailStartPips)
      return false;

   double distancePips=MathMax(0.0,InpLiveTrailDistancePips);
   double distance=distancePips*pip;
   double minDist=TradeMinDistance(symbol);

   if(distance<=0.0)
      return false;

   double candidate=0.0;

   if(type==POSITION_TYPE_BUY)
   {
      candidate=MathMin(tick.bid-distance,
                        tick.bid-minDist);
      candidate=NormalizePrice(symbol,candidate);

      // Never loosen the existing SL.
      if(currentSL>0.0 && candidate<=currentSL)
         return false;

      // Preserve the already-earned automatic lock.
      double locked=GetLockedPips(ticket);
      if(locked<=0.0 && candidate<=entry)
         return false;
      if(locked>0.0)
      {
         double lockSL=NormalizePrice(symbol,entry+locked*pip);
         candidate=MathMax(candidate,lockSL);
      }
   }
   else if(type==POSITION_TYPE_SELL)
   {
      candidate=MathMax(tick.ask+distance,
                        tick.ask+minDist);
      candidate=NormalizePrice(symbol,candidate);

      // Never loosen the existing SL.
      if(currentSL>0.0 && candidate>=currentSL)
         return false;

      // Preserve the already-earned automatic lock.
      double locked=GetLockedPips(ticket);
      if(locked<=0.0 && candidate>=entry)
         return false;
      if(locked>0.0)
      {
         double lockSL=NormalizePrice(symbol,entry-locked*pip);
         candidate=MathMin(candidate,lockSL);
      }
   }
   else
      return false;

   if(candidate<=0.0)
      return false;

   double step=MathMax(0.0,InpTrailStepPips)*pip;
   if(currentSL>0.0)
     {
      if(type==POSITION_TYPE_BUY && candidate-currentSL<step)
         return false;
      if(type==POSITION_TYPE_SELL && currentSL-candidate<step)
         return false;
     }

   if(!IsValidSLForPosition(symbol,type,candidate))
   {
      long stopsLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
      long freezeLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

      Print("STB LIVE TRAIL WAIT/REJECT ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " profitPips=",DoubleToString(profit,1),
            " startPips=",DoubleToString(InpTrailStartPips,1),
            " distancePips=",DoubleToString(distancePips,1),
            " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " bid=",DoubleToString(tick.bid,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " ask=",DoubleToString(tick.ask,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " currentSL=",DoubleToString(currentSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " candidateSL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",IntegerToString((int)stopsLevel),
            " freezeLevel=",IntegerToString((int)freezeLevel));
      return false;
   }

   bool result=STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_TRAIL,"TRAIL");

   if(result && !g_stbCollectingSLProposals)
   {
      Print("STB LIVE TRAIL updated ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " profitPips=",DoubleToString(profit,1),
            " distancePips=",DoubleToString(distancePips,1),
            " price=",DoubleToString(type==POSITION_TYPE_BUY ? tick.bid:tick.ask,
                                     (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " SL=",DoubleToString(candidate,
                                  (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   }

   return result;
}

//==================================================================
// MANAGE POSITIONS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CalculateNearestStructuralSL(const string symbol,
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
   double strategyCap=(InpMaxInitialSLPips>0.0 ?
                       InpMaxInitialSLPips*pip : DBL_MAX);

   if(direction==POSITION_TYPE_BUY)
     {
      double maxAllowed=MathMin(referencePrice-minDist,
                                tick.bid-minDist);
      double bestLow=-DBL_MAX;
      double bestSL=0.0;

      for(int i=0;i<ArraySize(lows);i++)
        {
         double swingLow=lows[i].price;
         if(swingLow<=0.0 || swingLow>=referencePrice)
            continue;
         if(referencePrice-swingLow>strategyCap)
            continue;

         double candidate=NormalizePrice(symbol,swingLow-buffer);
         if(candidate<=0.0 || candidate>=maxAllowed)
            continue;

         // Cap the final Entry-to-SL distance, including the structural buffer.
         if(strategyCap<DBL_MAX && referencePrice-candidate>strategyCap)
            continue;

         if(swingLow>bestLow)
           {
            bestLow=swingLow;
            bestSL=candidate;
           }
        }

      if(bestSL<=0.0)
         return false;

      sl=bestSL;
      return true;
     }

   if(direction==POSITION_TYPE_SELL)
     {
      double minAllowed=MathMax(referencePrice+minDist,
                                tick.ask+minDist);
      double bestHigh=DBL_MAX;
      double bestSL=0.0;

      for(int i=0;i<ArraySize(highs);i++)
        {
         double swingHigh=highs[i].price;
         if(swingHigh<=referencePrice)
            continue;
         if(swingHigh-referencePrice>strategyCap)
            continue;

         double candidate=NormalizePrice(symbol,swingHigh+buffer);
         if(candidate<=minAllowed)
            continue;

         // Cap the final Entry-to-SL distance, including the structural buffer.
         if(strategyCap<DBL_MAX && candidate-referencePrice>strategyCap)
            continue;

         if(swingHigh<bestHigh)
           {
            bestHigh=swingHigh;
            bestSL=candidate;
           }
        }

      if(bestSL<=0.0)
         return false;

      sl=bestSL;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CalculateReferenceCandleSL(const string symbol,
                                   const long positionType,
                                   const double referencePrice,
                                   double &sl)
  {
   sl=0.0;
   if(symbol=="" || referencePrice<=0.0)
      return false;

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return false;

   double buffer=MathMax(0.0,InpInitialSLBufferPips)*pip;

   for(int shift=1;shift<=5;shift++)
     {
      double anchor=(positionType==POSITION_TYPE_BUY)
                    ? iLow(symbol,InpTrailTF,shift)
                    : iHigh(symbol,InpTrailTF,shift);

      if(anchor<=0.0)
         continue;

      double candidate=(positionType==POSITION_TYPE_BUY)
                       ? anchor-buffer
                       : anchor+buffer;

      candidate=NormalizePrice(symbol,candidate);

      bool withinStrategyCap=(InpMaxInitialSLPips<=0.0 ||
                              MathAbs(referencePrice-candidate)<=InpMaxInitialSLPips*pip);

      if(candidate>0.0 && withinStrategyCap &&
         IsValidSLForPosition(symbol,positionType,candidate))
        {
         sl=candidate;
         return true;
        }
     }

   return false;
  }

bool IsValidSLForPendingOrder(const string symbol,
                              const ENUM_ORDER_TYPE orderType,
                              const double entry,
                              const double sl)
  {
   if(symbol=="" || entry<=0.0 || sl<=0.0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double minDist=TradeMinDistance(symbol);
   if(minDist<=0.0)
      return false;

   bool buyOrder=(orderType==ORDER_TYPE_BUY_STOP ||
                  orderType==ORDER_TYPE_BUY_LIMIT ||
                  orderType==ORDER_TYPE_BUY_STOP_LIMIT);

   bool sellOrder=(orderType==ORDER_TYPE_SELL_STOP ||
                   orderType==ORDER_TYPE_SELL_LIMIT ||
                   orderType==ORDER_TYPE_SELL_STOP_LIMIT);

   if(buyOrder)
      return (sl<=entry-minDist && sl<=tick.bid-minDist);

   if(sellOrder)
      return (sl>=entry+minDist && sl>=tick.ask+minDist);

   return false;
  }

bool CalculateInitialPendingProtectionSL(const string symbol,
                                         const ENUM_ORDER_TYPE orderType,
                                         const double entryPrice,
                                         double &sl)
  {
   sl=0.0;

   long direction=(orderType==ORDER_TYPE_BUY_STOP ||
                   orderType==ORDER_TYPE_BUY_LIMIT ||
                   orderType==ORDER_TYPE_BUY_STOP_LIMIT)
                  ? POSITION_TYPE_BUY
                  : (orderType==ORDER_TYPE_SELL_STOP ||
                     orderType==ORDER_TYPE_SELL_LIMIT ||
                     orderType==ORDER_TYPE_SELL_STOP_LIMIT)
                  ? POSITION_TYPE_SELL
                  : -1;

   if(direction<0)
      return false;

   // BUY STOP / SELL STOP initial protection is anchored to the latest CLOSED
   // M5 candle, as requested. If that structural SL cannot satisfy broker
   // constraints, reject the pending order rather than silently substituting
   // a different timeframe/structure.
   if(orderType==ORDER_TYPE_BUY_STOP || orderType==ORDER_TYPE_SELL_STOP)
     {
      double pip=PipSize(symbol);
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double minDistance=TradeMinDistance(symbol);
      if(pip<=0.0 || point<=0.0 || minDistance<=0.0)
         return false;

      bool buyStop=(orderType==ORDER_TYPE_BUY_STOP);
      double anchor=(buyStop ? iLow(symbol,PERIOD_M5,1)
                             : iHigh(symbol,PERIOD_M5,1));
      if(anchor<=0.0)
         return false;

      double buffer=MathMax(MathMax(0.0,InpInitialSLBufferPips)*pip,
                            minDistance+point);
      double candleSL=NormalizePrice(symbol,
                                     buyStop ? anchor-buffer:anchor+buffer);
      if(candleSL<=0.0 ||
         !IsValidSLForPendingOrder(symbol,orderType,entryPrice,candleSL))
         return false;

      sl=candleSL;
      return true;
     }

   // Same protection source as market positions.
   double candidate=0.0;

   if(CalculateInitialProtectionSL(symbol,direction,entryPrice,candidate) &&
      IsValidSLForPendingOrder(symbol,orderType,entryPrice,candidate))
     {
      sl=candidate;
      return true;
     }

   // Last-resort broker fallback; never intentionally use raw minDist.
   if(CalculateBrokerFallbackSL(symbol,direction,entryPrice,candidate) &&
      IsValidSLForPendingOrder(symbol,orderType,entryPrice,candidate))
     {
      sl=candidate;
      return true;
     }

   sl=0.0;
   return false;
  }

bool VerifyPendingInitialSL(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket))
      return false;

   ENUM_ORDER_TYPE orderType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

   return IsValidSLForPendingOrder(
      OrderGetString(ORDER_SYMBOL),
      orderType,
      OrderGetDouble(ORDER_PRICE_OPEN),
      OrderGetDouble(ORDER_SL));
  }

bool CalculateInitialProtectionSL(const string symbol,
                                  const long positionType,
                                  const double entryPrice,
                                  double &sl)
  {
   sl=0.0;

   // Unified protection policy for every managed exposure:
   // confirmed structural swing first, recent candle second, broker fallback last.
   // Broker distance is only a validity floor, never the strategy SL target.
   if(CalculateNearestStructuralSL(symbol,positionType,entryPrice,sl) &&
      IsValidSLForPosition(symbol,positionType,sl))
      return true;

   if(CalculateReferenceCandleSL(symbol,positionType,entryPrice,sl))
      return true;

   if(CalculateBrokerFallbackSL(symbol,positionType,entryPrice,sl) &&
      IsValidSLForPosition(symbol,positionType,sl))
      return true;

   sl=0.0;
   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CalculateBrokerFallbackSL(const string symbol,
                               const long positionType,
                               const double entryPrice,
                               double &sl)
  {
   sl=0.0;
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || entryPrice<=0.0)
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);
   long stopsLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

   double minimumDistance=(MathMax((double)stopsLevel,
                                   (double)freezeLevel)+1.0)*point;
   if(minimumDistance<=0.0)
      minimumDistance=point;

   double configuredDistance=
      MathMax(3.0,MathMax(1.0,InpInitialSLBufferPips)*2.0)*pip;
   double preferredDistance=MathMax(minimumDistance*3.0,
                                    configuredDistance);

   if(positionType==POSITION_TYPE_BUY)
      sl=MathMin(entryPrice-preferredDistance,
                 tick.bid-minimumDistance);
   else
      if(positionType==POSITION_TYPE_SELL)
         sl=MathMax(entryPrice+preferredDistance,
                    tick.ask+minimumDistance);
      else
         return false;

   sl=NormalizePrice(symbol,sl);

   if(InpMaxInitialSLPips>0.0 &&
      MathAbs(entryPrice-sl)>InpMaxInitialSLPips*pip)
      return false;

   return IsValidSLForPosition(symbol,positionType,sl);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EnsureInitialSL(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return false;
   if(PositionGetDouble(POSITION_SL)>0.0)
      return true;
   // A live position without SL is automatically repaired; manual edits never
   // silently opt an open position out of protection.
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double candidate=0.0;
   if(!CalculateInitialProtectionSL(symbol,type,entry,candidate))
     {
      Print("STB INITIAL SL WAIT: unable to calculate valid stop ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " pipSize=",DoubleToString(PipSize(symbol),(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL),
            " freezeLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL));
      return false;
     }
   if(!STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_INITIAL,"INITIAL"))
      return false;
   if(!PositionSelectByTicket(ticket) || PositionGetDouble(POSITION_SL)<=0.0)
      return false;
   Print("STB initial SL active ticket=",ticket,
         " symbol=",symbol,
         " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " SL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return true;
  }

void STB_RecordPendingInitialSLFailure(const int stateIdx);

bool EnsureInitialSLForPendingOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket) || !IsManagedOrder(ticket))
      return false;

   ENUM_ORDER_TYPE orderType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

   bool supported=(orderType==ORDER_TYPE_BUY_STOP ||
                   orderType==ORDER_TYPE_SELL_STOP ||
                   orderType==ORDER_TYPE_BUY_LIMIT ||
                   orderType==ORDER_TYPE_SELL_LIMIT ||
                   orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
                   orderType==ORDER_TYPE_SELL_STOP_LIMIT);

   if(!supported)
      return false;

   double currentSL=OrderGetDouble(ORDER_SL);

   if(currentSL>0.0)
      return VerifyPendingInitialSL(ticket);

   string symbol=OrderGetString(ORDER_SYMBOL);

   // Register missing-SL orders so failed protection attempts share the
   // pending engine's bounded 5/15/60-second retry policy.
   int stateIdx=STB_PendingTrailFind(ticket);
   if(stateIdx<0)
     {
      STB_PendingTrailRegister(ticket,"INITIAL_PROTECTION");
      stateIdx=STB_PendingTrailFind(ticket);
     }

   datetime now=TimeCurrent();
   if(stateIdx>=0 &&
      g_stbPendingTrail[stateIdx].nextRetryTime>now)
      return false;

   double entry=OrderGetDouble(ORDER_PRICE_OPEN);
   double candidate=0.0;

   if(!CalculateInitialPendingProtectionSL(symbol,orderType,entry,candidate))
     {
      Print("STB pending initial SL unavailable ticket=",ticket,
            " symbol=",symbol,
            " type=",EnumToString(orderType));
      STB_RecordPendingInitialSLFailure(stateIdx);
      return false;
     }

   if(!STB_ModifyPendingOrderGeometry(ticket,
                                      entry,
                                      candidate,
                                      OrderGetDouble(ORDER_TP)) ||
      !VerifyPendingInitialSL(ticket))
     {
      STB_RecordPendingInitialSLFailure(stateIdx);
      return false;
     }

   if(stateIdx>=0 && OrderSelect(ticket))
     {
      double verifiedEntry=OrderGetDouble(ORDER_PRICE_OPEN);
      double verifiedSL=OrderGetDouble(ORDER_SL);
      double pip=PipSize(symbol);

      g_stbPendingTrail[stateIdx].lastEntry=verifiedEntry;
      g_stbPendingTrail[stateIdx].lastSL=verifiedSL;
      if(pip>0.0)
         g_stbPendingTrail[stateIdx].slBufferPips=
            MathAbs(verifiedEntry-verifiedSL)/pip;
      g_stbPendingTrail[stateIdx].failureCount=0;
      g_stbPendingTrail[stateIdx].nextRetryTime=0;
      g_stbPendingTrail[stateIdx].lastModifyTime=TimeCurrent();
     }

   return true;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//==================================================================
// P6 CROSS-INSTANCE MANAGEMENT ARBITRATION (ONE SYMBOL = ONE WRITER)
//==================================================================
#define STB_MGMT_LEASE_SEC 90

// P10: management lease scope is account + symbol ONLY (never magic). Under
// Universal Management every exposure on an allowed symbol has exactly one
// broker writer, regardless of which magic/EA created it.
string g_stbLeaseSymbols[];

bool STB_LeaseTrackSymbol(const string symbol)
  {
   if(symbol=="")
      return false;

   for(int i=0;i<ArraySize(g_stbLeaseSymbols);i++)
      if(g_stbLeaseSymbols[i]==symbol)
         return true;

   int n=ArraySize(g_stbLeaseSymbols);
   if(ArrayResize(g_stbLeaseSymbols,n+1)==n+1)
     {
      g_stbLeaseSymbols[n]=symbol;
      return true;
     }

   Print("STB management lease tracking allocation failed symbol=",symbol,
         " reason=LEASE_CLAIM_WILL_BE_RELEASED");
   return false;
  }

string STB_MgmtScopeKey(const string purpose,const string symbol)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|MGMT|"+purpose+"|"+symbol;
   // A tester must not claim or release a live chart's per-symbol lease.
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER";
   return g_prefix+(string)SymbolHash(raw);
  }

string STB_MgmtOwnerKey(const string symbol)
  {
   return STB_MgmtScopeKey("OWNER",symbol);
  }

string STB_MgmtLeaseKey(const string symbol)
  {
   return STB_MgmtScopeKey("LEASE",symbol);
  }

// Central per-symbol management lease. The first instance to reach a symbol
// claims it; the live owner keeps it; a stale owner (no refresh within
// STB_MGMT_LEASE_SEC) may lose it. Only the current owner should pass the
// broker-writer guards. GlobalVariableSetOnCondition provides atomic CAS for
// claiming/reclaiming the lease within this terminal, but the lease check and
// broker request are not one atomic operation. Final pre-submit rechecks reduce
// the race window; this is not a cross-terminal mutex.
bool STB_SymbolManagementOwnedVerified(const string symbol)
  {
   if(!STB_SymbolManagementOwned(symbol))
      return false;

   double me=(double)((long)ChartID());
   string ownerKey=STB_MgmtOwnerKey(symbol);

   return (GlobalVariableCheck(ownerKey) &&
           GlobalVariableGet(ownerKey)==me);
  }

bool STB_SymbolManagementOwned(const string symbol)
  {
   if(symbol=="")
      return false;

   double me=(double)((long)ChartID());
   string ownerKey=STB_MgmtOwnerKey(symbol);
   string leaseKey=STB_MgmtLeaseKey(symbol);
   // Use terminal-local wall-clock time for the lease TTL. Server time may
   // stop advancing when quotes are absent, which can otherwise delay stale
   // owner reclamation or make the TTL measure market-time rather than elapsed time.
   datetime now=TimeLocal();

   // Create the sentinel without overwriting a concurrent claimant. A plain
   // GlobalVariableSet(ownerKey,0) after a missing-key check can race and erase
   // another chart's successful claim. GlobalVariableTemp creates only-if-absent.
   if(!GlobalVariableCheck(ownerKey))
     {
      ResetLastError();
      if(!GlobalVariableTemp(ownerKey) && !GlobalVariableCheck(ownerKey))
        {
         Print("STB lease owner-key creation failed symbol=",symbol,
               " err=",GetLastError());
         return false;
        }
     }

   if(!GlobalVariableCheck(ownerKey))
      return false;

   if(GlobalVariableGet(ownerKey)==0.0)
     {
      if(!GlobalVariableSetOnCondition(ownerKey,me,0.0))
         return false; // P11 atomic claim (CAS 0 -> me)
      GlobalVariableSet(leaseKey,(double)now);
      if(!STB_LeaseTrackSymbol(symbol))
        {
         // Do not keep a writer lease that this instance cannot release
         // promptly during deinitialization. The owner sentinel is authoritative;
         // leave the old lease timestamp untouched to avoid clobbering a new
         // owner's timestamp in a concurrent takeover race.
         GlobalVariableSetOnCondition(ownerKey,0.0,me);
         return false;
        }
      return true;
     }

   double owner=GlobalVariableGet(ownerKey);
   double lease=GlobalVariableCheck(leaseKey) ? GlobalVariableGet(leaseKey) : 0.0;

   if(owner==me)
     {
      GlobalVariableSet(leaseKey,(double)now);
      if(!STB_LeaseTrackSymbol(symbol))
        {
         // Do not keep a writer lease that this instance cannot release
         // promptly during deinitialization. The owner sentinel is authoritative;
         // leave the old lease timestamp untouched to avoid clobbering a new
         // owner's timestamp in a concurrent takeover race.
         GlobalVariableSetOnCondition(ownerKey,0.0,me);
         return false;
        }
      return true;
     }

   if(lease<=0.0 || (now-(datetime)lease)>STB_MGMT_LEASE_SEC)
     {
      if(!GlobalVariableSetOnCondition(ownerKey,me,owner))
         return false; // P11 atomic stale takeover (CAS)
      GlobalVariableSet(leaseKey,(double)now);
      if(!STB_LeaseTrackSymbol(symbol))
        {
         // Do not keep a writer lease that this instance cannot release
         // promptly during deinitialization. The owner sentinel is authoritative;
         // leave the old lease timestamp untouched to avoid clobbering a new
         // owner's timestamp in a concurrent takeover race.
         GlobalVariableSetOnCondition(ownerKey,0.0,me);
         return false;
        }
      return true;
     }

   return false;
  }

// P10: voluntary release so a removed chart does not hold the symbol lease
// until the TTL expires and another instance can take over immediately.
void STB_ReleaseSymbolManagement(const string symbol)
  {
   if(symbol=="")
      return;

   double me=(double)((long)ChartID());
   string ownerKey=STB_MgmtOwnerKey(symbol);

   // Release through CAS. Deleting the key after a separate owner check can
   // erase a new chart's claim in the race window. Zero is an unowned sentinel.
   if(GlobalVariableCheck(ownerKey))
      GlobalVariableSetOnCondition(ownerKey,0.0,me);
  }

void STB_ReleaseAllSymbolManagement()
  {
   for(int i=ArraySize(g_stbLeaseSymbols)-1;i>=0;i--)
      STB_ReleaseSymbolManagement(g_stbLeaseSymbols[i]);

   ArrayResize(g_stbLeaseSymbols,0);
  }

//==================================================================
// STRUCTURAL INITIAL TAKE-PROFIT FOR POSITIONS AND PENDING ORDERS
// Existing user-supplied TP is never overwritten. If TP is absent, choose
// the nearest confirmed M15 swing that satisfies min-RR and broker distance;
// if no such swing exists, use an explicitly logged RR fallback.
//==================================================================

bool STB_CalculatePendingTPFromStructure(const string symbol,
                                         const ENUM_ORDER_TYPE orderType,
                                         const double entry,
                                         const double sl,
                                         const double minimumRR,
                                         double &tp,
                                         string &source)
  {
   tp=0.0;
   source="UNAVAILABLE";
   bool isBuy=(orderType==ORDER_TYPE_BUY_STOP ||
               orderType==ORDER_TYPE_BUY_LIMIT ||
               orderType==ORDER_TYPE_BUY_STOP_LIMIT);
   bool isSell=(orderType==ORDER_TYPE_SELL_STOP ||
                orderType==ORDER_TYPE_SELL_LIMIT ||
                orderType==ORDER_TYPE_SELL_STOP_LIMIT);
   if(symbol=="" || entry<=0.0 || sl<=0.0 || (!isBuy && !isSell))
      return false;

   double risk=MathAbs(entry-sl);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0.0) tickSize=point;
   double minDist=TradeMinDistance(symbol);
   if(risk<=0.0 || point<=0.0 || tickSize<=0.0 || minDist<=0.0)
      return false;

   double requiredReward=MathMax(risk*MathMax(0.1,minimumRR),
                                 minDist+tickSize);
   SwingPoint highs[];
   SwingPoint lows[];
   int swingCount=CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows);

   if(isBuy)
     {
      double floorTP=entry+requiredReward;
      double best=DBL_MAX;
      for(int i=0;i<ArraySize(highs);i++)
        {
         double candidate=NormalizePrice(symbol,highs[i].price);
         if(candidate<=entry || candidate-entry+point*0.1<risk*minimumRR ||
            candidate-entry<minDist)
            continue;
         if(candidate>=floorTP-point*0.1 && candidate<best)
            best=candidate;
        }
      if(swingCount>0 && best<DBL_MAX)
        {
         tp=best; source="STRUCTURE_SWING"; return true;
        }
      tp=NormalizePrice(symbol,floorTP+tickSize);
      if(tp>entry && tp-entry>=minDist && tp-entry+point*0.1>=risk*minimumRR)
        { source="RR_FALLBACK"; return true; }
     }
   else
     {
      double ceilingTP=entry-requiredReward;
      double best=-DBL_MAX;
      for(int i=0;i<ArraySize(lows);i++)
        {
         double candidate=NormalizePrice(symbol,lows[i].price);
         if(candidate<=0.0 || candidate>=entry ||
            entry-candidate+point*0.1<risk*minimumRR ||
            entry-candidate<minDist)
            continue;
         if(candidate<=ceilingTP+point*0.1 && candidate>best)
            best=candidate;
        }
      if(swingCount>0 && best>0.0)
        { tp=best; source="STRUCTURE_SWING"; return true; }
      tp=NormalizePrice(symbol,ceilingTP-tickSize);
      if(tp>0.0 && tp<entry && entry-tp>=minDist &&
         entry-tp+point*0.1>=risk*minimumRR)
        { source="RR_FALLBACK"; return true; }
     }

   tp=0.0;
   source="NO_VALID_TARGET";
   return false;
  }

bool STB_CalculatePositionTPFromStructure(const string symbol,
                                          const long positionType,
                                          const double entry,
                                          const double sl,
                                          const double minimumRR,
                                          double &tp,
                                          string &source)
  {
   tp=0.0;
   source="UNAVAILABLE";
   bool isBuy=(positionType==POSITION_TYPE_BUY);
   bool isSell=(positionType==POSITION_TYPE_SELL);
   if(symbol=="" || entry<=0.0 || sl<=0.0 || (!isBuy && !isSell))
      return false;

   // A stop that has moved through entry is a profit lock, not a negative risk.
   // Use absolute entry-to-current-stop geometry for a conservative fallback.
   double risk=MathAbs(entry-sl);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0.0) tickSize=point;
   double minDist=TradeMinDistance(symbol);
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || risk<=0.0 ||
      point<=0.0 || tickSize<=0.0 || minDist<=0.0)
      return false;

   double requiredReward=MathMax(risk*MathMax(0.1,minimumRR),
                                 minDist+tickSize);
   double marketBuffer=minDist+MathMax(tickSize,risk*0.25);
   SwingPoint highs[];
   SwingPoint lows[];
   int swingCount=CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows);

   if(isBuy)
     {
      double floorTP=MathMax(entry+requiredReward,tick.bid+marketBuffer);
      double best=DBL_MAX;
      for(int i=0;i<ArraySize(highs);i++)
        {
         double candidate=NormalizePrice(symbol,highs[i].price);
         if(candidate<=entry || candidate<=tick.bid+minDist ||
            candidate-entry+point*0.1<risk*MathMax(0.1,minimumRR))
            continue;
         if(candidate>=floorTP-point*0.1 && candidate<best)
            best=candidate;
        }
      if(swingCount>0 && best<DBL_MAX)
        { tp=best; source="STRUCTURE_SWING"; return true; }
      tp=NormalizePrice(symbol,floorTP+tickSize);
      if(tp>entry && tp>tick.bid+minDist &&
         tp-entry+point*0.1>=risk*MathMax(0.1,minimumRR))
        { source="RR_FALLBACK"; return true; }
     }
   else
     {
      double ceilingTP=MathMin(entry-requiredReward,tick.ask-marketBuffer);
      double best=-DBL_MAX;
      for(int i=0;i<ArraySize(lows);i++)
        {
         double candidate=NormalizePrice(symbol,lows[i].price);
         if(candidate<=0.0 || candidate>=entry || candidate>=tick.ask-minDist ||
            entry-candidate+point*0.1<risk*MathMax(0.1,minimumRR))
            continue;
         if(candidate<=ceilingTP+point*0.1 && candidate>best)
            best=candidate;
        }
      if(swingCount>0 && best>0.0)
        { tp=best; source="STRUCTURE_SWING"; return true; }
      tp=NormalizePrice(symbol,ceilingTP-tickSize);
      if(tp>0.0 && tp<entry && tp<tick.ask-minDist &&
         entry-tp+point*0.1>=risk*MathMax(0.1,minimumRR))
        { source="RR_FALLBACK"; return true; }
     }

   tp=0.0;
   source="NO_VALID_TARGET";
   return false;
  }

bool STB_ModifyPositionTP(const ulong ticket,const double newTP)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket) ||
      !STB_IsProtectionPosition(ticket))
      return false;
   string symbol=PositionGetString(POSITION_SYMBOL);
   if(symbol=="" || !STB_SymbolManagementOwnedVerified(symbol))
      return false;

   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double currentTP=PositionGetDouble(POSITION_TP);
   long side=PositionGetInteger(POSITION_TYPE);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0.0) tickSize=point;
   if(sl<=0.0 || point<=0.0 || tickSize<=0.0 || newTP<=0.0)
      return false;
   if(currentTP>0.0)
      return true; // never overwrite explicit user TP
   if(STB_CycleWriteAlreadyDone(ticket))
      return false;

   MqlTick tick;
   double minDist=TradeMinDistance(symbol);
   if(!SymbolInfoTick(symbol,tick) || minDist<=0.0)
      return false;
   if((side==POSITION_TYPE_BUY &&
       (newTP<=entry || newTP<=tick.bid+minDist)) ||
      (side==POSITION_TYPE_SELL &&
       (newTP>=entry || newTP>=tick.ask-minDist)))
      return false;

   string failKey=ScopedStateName("AUTOTP_MODFAIL_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(failKey))
     {
      double lastFail=GlobalVariableGet(failKey);
      if(lastFail>0.0 && TimeCurrent()-lastFail<30)
         return false;
     }

   bool modified=STB_PositionModifyBrokerVerified(ticket,entry,sl,currentTP,
                                                  sl,newTP,failKey,"TP");
   if(!modified)
      return false;
   return true;
  }

bool EnsureInitialTPForPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket) ||
      !STB_IsProtectionPosition(ticket))
      return false;
   if(PositionGetDouble(POSITION_TP)>0.0)
      return true;
   string symbol=PositionGetString(POSITION_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(symbol))
      return false;
   if(PositionGetDouble(POSITION_SL)<=0.0)
      return false;
   if(STB_CycleWriteAlreadyDone(ticket))
      return false; // avoid throttling a TP because this cycle already wrote its SL

   string retryKey=ScopedStateName("AUTOTP_INITPOS_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(retryKey))
     {
      double lastFail=GlobalVariableGet(retryKey);
      if(lastFail>0.0 && TimeCurrent()-lastFail<30)
         return false;
     }

   long side=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=0.0;
   string source="";
   if(!STB_CalculatePositionTPFromStructure(symbol,side,entry,sl,
                                             InpMinimumRR,tp,source))
     {
      GlobalVariableSet(retryKey,(double)TimeCurrent());
      Print("STB AUTO TP UNAVAILABLE ticket=",ticket,
            " symbol=",symbol," reason=",source);
      return false;
     }
   if(!STB_ModifyPositionTP(ticket,tp))
     {
      if(!STB_CycleWriteAlreadyDone(ticket))
         GlobalVariableSet(retryKey,(double)TimeCurrent());
      return false;
     }

   GlobalVariableDel(retryKey);
   Print("STB AUTO TP SET ticket=",ticket,
         " symbol=",symbol," side=",(side==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " source=",source,
         " TP=",DoubleToString(tp,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return true;
  }

bool EnsureInitialTPForPendingOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket) || !IsManagedOrder(ticket))
      return false;
   if(OrderGetDouble(ORDER_TP)>0.0)
      return true; // do not replace any explicit TP
   if(STB_CycleWriteAlreadyDone(ticket))
      return false; // initial SL used this ticket's single-write budget this cycle

   string symbol=OrderGetString(ORDER_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(symbol) ||
      OrderGetDouble(ORDER_SL)<=0.0)
      return false;

   string retryKey=ScopedStateName("AUTOTP_INITPEND_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(retryKey))
     {
      double lastFail=GlobalVariableGet(retryKey);
      if(lastFail>0.0 && TimeCurrent()-lastFail<30)
         return false;
     }

   ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   double entry=OrderGetDouble(ORDER_PRICE_OPEN);
   double sl=OrderGetDouble(ORDER_SL);
   double tp=0.0;
   string source="";
   if(!STB_CalculatePendingTPFromStructure(symbol,type,entry,sl,
                                            InpMinimumRR,tp,source))
     {
      GlobalVariableSet(retryKey,(double)TimeCurrent());
      Print("STB PENDING TP UNAVAILABLE ticket=",ticket,
            " symbol=",symbol," reason=",source);
      return false;
     }

   if(!STB_ModifyPendingOrderGeometry(ticket,entry,sl,tp,false))
     {
      if(!STB_CycleWriteAlreadyDone(ticket))
         GlobalVariableSet(retryKey,(double)TimeCurrent());
      return false;
     }
   if(!OrderSelect(ticket) || OrderGetDouble(ORDER_TP)<=0.0)
     {
      GlobalVariableSet(retryKey,(double)TimeCurrent());
      return false;
     }

   GlobalVariableDel(retryKey);
   Print("STB PENDING TP SET ticket=",ticket,
         " symbol=",symbol," type=",EnumToString(type),
         " source=",source,
         " TP=",DoubleToString(OrderGetDouble(ORDER_TP),(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return true;
  }

void ManagePositions()
  {
   // Collect all automatic SL candidates before any broker write.
   g_stbCollectingSLProposals=true;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true) ||
         !STB_SymbolManagementOwnedVerified(symbol))
         continue;
      EnsureInitialSL(ticket);
     }

   AutoProfitProtection();

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true) ||
         !STB_SymbolManagementOwnedVerified(symbol))
         continue;
      TrailPositionByLivePrice(ticket);
     }

   // Flush SL arbitration first. A newly repaired SL then becomes visible to
   // the TP manager. If this cycle already changed the position, TP is deferred
   // without failure backoff and retried next management cycle.
   STB_FlushPositionSLProposals();

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true) ||
         !STB_SymbolManagementOwnedVerified(symbol))
         continue;
      if(PositionGetDouble(POSITION_SL)>0.0 &&
         PositionGetDouble(POSITION_TP)<=0.0)
         EnsureInitialTPForPosition(ticket);
     }
  }

//==================================================================
// PENDING ORDER MANAGEMENT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManagePendingOrders()
  {
   datetime now=TimeCurrent();

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(!IsManagedOrder(ticket))
         continue;

      string symbol=OrderGetString(ORDER_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true))
         continue; // subscribe non-Watch symbols before reading their history/quotes
      if(!STB_SymbolManagementOwnedVerified(symbol)) continue; // P6/P10 cross-instance single pending lifecycle owner

      // Protect every managed pending order with no SL, not only orders created
      // by this EA. The helper respects manual overrides and throttles failures.
      if(OrderGetDouble(ORDER_SL)<=0.0)
        {
         EnsureInitialSLForPendingOrder(ticket);
         if(!OrderSelect(ticket))
            continue;
         symbol=OrderGetString(ORDER_SYMBOL);
        }

      // Add TP only when absent. Explicit manual/mobile TP is preserved.
      if(OrderSelect(ticket) &&
         OrderGetDouble(ORDER_SL)>0.0 &&
         OrderGetDouble(ORDER_TP)<=0.0)
        {
         EnsureInitialTPForPendingOrder(ticket);
         if(!OrderSelect(ticket))
            continue;
         symbol=OrderGetString(ORDER_SYMBOL);
        }

      datetime setupTime=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int profileId=STB_AdaptiveParseProfileFromComment(OrderGetString(ORDER_COMMENT));
      int maxBars=InpMaxPendingBars;

      if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
        {
         STB_AP_SetActive(profileId);
         maxBars=STB_EffectiveMaxPendingBars();
         STB_AP_ClearActive();
        }

      bool expiredByServer=
         OrderGetInteger(ORDER_TYPE_TIME)==ORDER_TIME_SPECIFIED &&
         OrderGetInteger(ORDER_TIME_EXPIRATION)>0 &&
         now>=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);

      // Blueprint 35: only EA-created pendings may expire by local age.
      // Manual / mobile / foreign / user-overridden pendings are never
      // deleted by local age (server-side explicit expiration is honored).
      bool autoCreated=(StringFind(OrderGetString(ORDER_COMMENT),"STB|B|")==0 ||
                        StringFind(OrderGetString(ORDER_COMMENT),"STB|S|")==0);
      bool expiredByLocalAge=
         autoCreated && !STB_ManualOverrideIs(ticket) &&
         maxBars>0 && setupTime>0 &&
         now-setupTime>=maxBars*15*60;

      if(expiredByServer || expiredByLocalAge)
        {
         Print("STB PENDING EXPIRE ticket=",ticket,
               " symbol=",symbol,
               " profile=",IntegerToString(profileId));

         if(!STB_RequestOrderDelete(ticket,STB_DEL_SERVER_EXPIRATION,"ManagePendingOrders"))
      Print("STB pending delete failed ticket=",ticket,
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
   else
      STB_AdaptiveDeleteOrderState(ticket);
        }
     }
  }

//==================================================================
// AUTO ORDER
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double DirectionExposureVolume(const string symbol,const int direction);

// Shared preflight for every EA order-creation path. This is a local
// snapshot check, not an account-wide atomic reservation; OrderCheck and the
// server response remain authoritative if exposure changes concurrently.
bool STB_DirectionVolumeWithinLimit(const string symbol,
                                    const int direction,
                                    const double requestedVolume,
                                    const string source)
  {
   if((direction!=1 && direction!=-1) || requestedVolume<=0.0)
      return false;

   double volumeLimit=SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT);
   if(volumeLimit<=0.0)
      return true;

   double currentVolume=DirectionExposureVolume(symbol,direction);
   if(currentVolume+requestedVolume>volumeLimit+1e-9)
     {
      Print("STB VOLUME LIMIT REJECT source=",source,
            " symbol=",symbol,
            " direction=",(direction>0 ? "BUY":"SELL"),
            " requested=",DoubleToString(requestedVolume,3),
            " currentDirectionVolume=",DoubleToString(currentVolume,3),
            " limit=",DoubleToString(volumeLimit,3));
      return false;
     }
   return true;
  }

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ValidatePendingSetup(const Setup &s)
  {
   MqlTick tick;
   if(!SymbolInfoTick(s.symbol,tick))
      return false;

   double point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   double minDist=TradeMinDistance(s.symbol);

   if(point<=0.0 || minDist<=0.0)
      return false;

   if(s.direction>0)
      return s.entry>tick.ask+minDist &&
             s.sl<s.entry-minDist &&
             s.tp>s.entry+minDist;

   return s.entry<tick.bid-minDist &&
          s.sl>s.entry+minDist &&
          s.tp<s.entry-minDist;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckPendingOrder(const Setup &s,
                       const double volume,
                       const ENUM_ORDER_TYPE_TIME typeTime,
                       const datetime expiration)
  {
   MqlTradeRequest request= {};
   MqlTradeCheckResult check= {};

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

// OrderCheck() success is represented by retcode=0.
// TRADE_RETCODE_* values such as DONE/PLACED belong to the
// subsequent trade-server execution result, not this check result.
   if(check.retcode!=0)
     {
      Print("STB OrderCheck rejected symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " ret=",check.retcode,
            " comment=",check.comment);
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetPendingLifetime(const string symbol,
                        ENUM_ORDER_TYPE_TIME &typeTime,
                        datetime &expiration)
  {
   typeTime=ORDER_TIME_GTC;
   expiration=0;

   int modes=(int)SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);

   if(STB_EffectiveMaxPendingBars()<=0)
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
         dt.hour=23;
         dt.min=59;
         dt.sec=59;
         expiration=StructToTime(dt);
         return expiration>TimeTradeServer();
        }
      return false;
     }

   datetime target=TimeTradeServer()+(datetime)STB_EffectiveMaxPendingBars()*15*60;

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
      dt.hour=23;
      dt.min=59;
      dt.sec=59;
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

   if(InpMaxRiskVolume>0.0)
      raw=MathMin(raw,InpMaxRiskVolume);

   if(raw+1e-9<minLot)
     {
      // The broker minimum OR the configured volume cap would exceed the
      // requested risk/volume limit. Never clamp upward into an unsafe lot.
      return 0.0;
     }

   double volume=NormalizeVolume(s.symbol,raw);

   if(volume<=0.0 || !MathIsValidNumber(volume))
      return 0.0;

   if(InpMaxRiskVolume>0.0 && volume>InpMaxRiskVolume+1e-9)
      return 0.0;

   return volume;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_LogPlaceReject(const Setup &s,const string reason)
  {
   if(!s.valid)
      return false;

   Print("STB PLACE REJECT symbol=",s.symbol,
         " dir=",(s.direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(s.adaptiveProfile),
         " reason=",reason,
         " score=",DoubleToString(s.score,1),
         " RR=",DoubleToString(s.rr,2));

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PlaceSetup(Setup &s,const double entryLockToken)
  {
   if(!s.valid)
      return false;

   if(!STB_EntryLockStillOwned(s.symbol,entryLockToken))
      return STB_LogPlaceReject(s,"ENTRY_LOCK_NOT_OWNED");

   if(!STB_SymbolManagementOwnedVerified(s.symbol))
      return STB_LogPlaceReject(s,"SYMBOL_WRITER_LEASE_NOT_OWNED");

   if(!g_autoTrading)
      return STB_LogPlaceReject(s,"AUTO_TRADING_OFF");

   if(!IsDirectionTradable(s.symbol,s.direction))
      return STB_LogPlaceReject(s,"DIRECTION_NOT_TRADABLE");

   if(!IsSpreadAcceptable(s.symbol))
      return STB_LogPlaceReject(s,"SPREAD_FILTER");

   if(HasManagedExposure(s.symbol))
      return STB_LogPlaceReject(s,"MANAGED_EXPOSURE_EXISTS");

   if(!STB_TradeEnvironmentAllowed())
      return STB_LogPlaceReject(s,"TRADE_PERMISSION");

   long maxOrders=AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);

   if(maxOrders>0 && OrdersTotal()>=maxOrders)
      return STB_LogPlaceReject(s,"ACCOUNT_ORDER_LIMIT");

   if(!ValidatePendingSetup(s))
      return STB_LogPlaceReject(s,"PENDING_GEOMETRY_INVALID");

   datetime lastSetup=GetLastSetupTime(s.symbol,s.direction);

   if(lastSetup==s.setupTime)
      return STB_LogPlaceReject(s,"SETUP_ALREADY_PLACED");

   if(InpSetupCooldownMinutes>0 &&
      lastSetup>0 &&
      TimeCurrent()-(datetime)lastSetup<InpSetupCooldownMinutes*60)
      return STB_LogPlaceReject(s,"SETUP_COOLDOWN");

   double volume=0.0;

   if(InpUseRiskSizing)
     {
      volume=CalculateOrderVolumeByRisk(s);

      if(volume<=0.0)
        {
         return STB_LogPlaceReject(s,"RISK_VOLUME_INVALID");
        }
     }
   else
     {
      double multiplier=s.trendAligned ? InpTrendLotMultiplier : InpUniversalLotMultiplier;
      volume=NormalizeVolume(s.symbol,InpBaseLots*multiplier);

      if(volume<=0.0)
         return STB_LogPlaceReject(s,"FIXED_VOLUME_INVALID");
     }

   if(!STB_DirectionVolumeWithinLimit(s.symbol,s.direction,volume,"PlaceSetup"))
      return STB_LogPlaceReject(s,"VOLUME_LIMIT");

   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

// The pending lifetime is a learned strategy parameter, so activate
// the exact profile that produced this immutable setup.
   STB_AP_SetActive(s.adaptiveProfile);
   bool lifetimeOK=GetPendingLifetime(s.symbol,typeTime,expiration);
   STB_AP_ClearActive();

   if(!lifetimeOK)
     {
      Print("STB order rejected: symbol has no supported pending expiration mode symbol=",s.symbol,
            " profile=",IntegerToString(s.adaptiveProfile));
      return STB_LogPlaceReject(s,"PENDING_EXPIRATION_UNSUPPORTED");
     }

   if(!CheckPendingOrder(s,volume,typeTime,expiration))
     {
      Print("STB ORDERCHECK REJECT symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " profile=",IntegerToString(s.adaptiveProfile),
            " score=",DoubleToString(s.score,1),
            " RR=",DoubleToString(s.rr,2));
      return false;
     }

   trade.SetExpertMagicNumber(InpMagic);
// Pending orders use RETURN filling regardless of execution mode.
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(false);

   double commentPip=PipSize(s.symbol);
   MqlTick commentTick;
   if(!SymbolInfoTick(s.symbol,commentTick) || commentPip<=0.0)
      return STB_LogPlaceReject(s,"NO_TICK_BEFORE_PLACEMENT");

   // EB is the distance from the pending entry to the pending-trail's live
   // anchor at registration: Bid for BUY-side orders, Ask for SELL-side.
   // Storing the pattern-zone distance here can make restart recovery infer an
   // old extreme and cause an immediate unintended entry jump.
   double commentAnchor=(s.direction>0 ? commentTick.bid:commentTick.ask);
   double effectiveEntryBuffer=MathAbs(s.entry-commentAnchor)/commentPip;
   string comment="STB|"+(s.direction>0 ? "B":"S")+"|P"+
                  IntegerToString(s.adaptiveProfile)+"|EB"+
                  DoubleToString(effectiveEntryBuffer,8);

   // Final pre-submit gate: a second instance may have changed exposure while
   // this setup was being validated and sized.
   if(!STB_EntryLockStillOwned(s.symbol,entryLockToken))
      return STB_LogPlaceReject(s,"ENTRY_LOCK_LOST_BEFORE_SUBMIT");
   if(!STB_SymbolManagementOwnedVerified(s.symbol))
      return STB_LogPlaceReject(s,"SYMBOL_WRITER_LEASE_LOST");
   if(HasManagedExposure(s.symbol))
      return STB_LogPlaceReject(s,"MANAGED_EXPOSURE_CHANGED_BEFORE_SUBMIT");

   bool ok=false;

   if(s.direction>0)
      ok=trade.BuyStop(volume,s.entry,s.symbol,s.sl,s.tp,typeTime,expiration,comment);
   else
      ok=trade.SellStop(volume,s.entry,s.symbol,s.sl,s.tp,typeTime,expiration,comment);

   if(!ok)
     {
      Print("STB order request failed symbol=",s.symbol,
            " magic=",IntegerToString((int)InpMagic),
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " lots=",DoubleToString(volume,3),
            " entry=",DoubleToString(s.entry,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
            " SL=",DoubleToString(s.sl,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
            " TP=",DoubleToString(s.tp,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
     }

   if(!TradeRetcodePlacementSucceeded())
     {
      Print("STB order server rejected symbol=",s.symbol,
            " magic=",IntegerToString((int)InpMagic),
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " order=",IntegerToString((int)trade.ResultOrder()),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
     }

   ulong placedOrder=trade.ResultOrder();

   if(placedOrder==0 || !VerifyPendingInitialSL(placedOrder))
     {
      Print("STB AUTO PENDING REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            s.symbol,
            " order=",IntegerToString((int)placedOrder));
      if(placedOrder>0 && OrderSelect(placedOrder))
         STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK,"PlaceSetup");
      return STB_LogPlaceReject(s,"INITIAL_SL_NOT_CONFIRMED");
     }

   // Commit the setup cooldown only after the accepted order's initial SL
   // has been verified. A failed protection check triggers rollback and must
   // not poison this valid setup with a false "already placed" timestamp.
   SetLastSetupTime(s.symbol,s.direction,s.setupTime);
   STB_AdaptiveRememberLastProfile(s.symbol,s.direction,s.adaptiveProfile);

   if(placedOrder>0)
     {
      STB_AdaptiveRememberOrderProfile(placedOrder,s.adaptiveProfile);
      STB_AfterExposureCreated(placedOrder,"AUTO"); // Blueprint 10/11

      double orderRiskMoney=0.0;
      ENUM_ORDER_TYPE calcType=
         (s.direction>0 ? ORDER_TYPE_BUY:ORDER_TYPE_SELL);

      if(OrderCalcProfit(calcType,s.symbol,volume,
                         s.entry,s.sl,orderRiskMoney))
        {
         orderRiskMoney=MathAbs(orderRiskMoney);
         STB_AdaptiveRememberOrderRisk(placedOrder,orderRiskMoney);
        }
     }

   STB_AdaptiveRecordSetup(s,true);

// Re-activate the same learned profile around order creation;
// immediately after order creation; the setup itself remains immutable.
   STB_AP_SetActive(s.adaptiveProfile);





   STB_AP_ClearActive();

   Print("STB AUTO PENDING CREATED ",s.symbol," ",
         (s.direction>0 ? "BUY":"SELL"),
         " magic=",IntegerToString((int)InpMagic),
         " order=",IntegerToString((int)trade.ResultOrder()),
         " lots=",DoubleToString(volume,3),
         " entry=",DoubleToString(s.entry,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(s.sl,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
         " TP=",DoubleToString(s.tp,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
         " RR=",DoubleToString(s.rr,2));

   return true;
  }

// Scanner data types declared before first use (Build 6238 compatibility).

enum ENUM_STB_REGIME
  {
   STB_REGIME_TRENDING=0,
   STB_REGIME_RANGING=1,
   STB_REGIME_TRANSITION=2,
   STB_REGIME_HIGH_VOLATILITY=3,
   STB_REGIME_LOW_VOLATILITY=4,
   STB_REGIME_UNSTABLE=5
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

struct STBMarketQuality
  {
   bool              valid;
   double            spreadPips;
   double            relativeSpread;
   double            volatility;
   double            volatilityRatio;
   double            activityRatio;
   double            freshnessScore;
   double            score;
   string            reason;
  };

struct STBRegimeState
  {
   ENUM_STB_REGIME   regime;
   double            strength;
   int               bias;
   double            volatilityRatio;
   double            efficiency;
   string            reason;
  };

struct STBCandidate
  {
   bool              valid;
   string            symbol;
   int               direction;
   datetime          setupTime;
   Setup             setup;
   double            strategyScore;
   double            marketQualityScore;
   double            regimeScore;
   double            stabilityScore;
   double            opportunityScore;
   ENUM_STB_REGIME   regime;
   double            regimeStrength;
   int               setupAgeBars;
   double            previousScore;
   int               previousRank;
   int               currentRank;
   datetime          lastValidationTime;
   string            rejectReason;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_FinalCandidateRevalidation(STBCandidate &c,Setup &validated)
  {
   if(!c.valid)
      return false;

   string reason="";
   if(!STB_ScannerDataEligible(c.symbol,reason))
     {
      c.rejectReason=reason;
      return false;
     }

   STBMarketQuality q;
   if(!STB_CalcMarketQuality(c.symbol,q))
     {
      c.rejectReason=q.reason;
      return false;
     }

   if(!STB_ScannerDirectionAllowed(c.symbol,c.direction))
     {
      c.rejectReason="REJECT_DIRECTION_NOT_ALLOWED";
      return false;
     }

   if(q.score+1e-9<InpScannerMinQuality)
     {
      c.rejectReason="REJECT_QUALITY_SCORE_BELOW_MINIMUM";
      return false;
     }

   Setup refreshed;
   if(!BuildSetup(c.symbol,c.direction,refreshed,false))
     {
      c.rejectReason=(g_lastBuildRejectReason=="" ?
                      "REJECT_NO_STRATEGY":g_lastBuildRejectReason);
      return false;
     }

   if(refreshed.setupTime!=c.setupTime)
     {
      c.rejectReason="REJECT_STALE_SETUP";
      return false;
     }

   // Re-check setup age at the final scanner-to-execution handoff. The
   // candidate may have aged after discovery/watchlist construction, so the
   // discovery-stage age check alone is not a sufficient execution gate.
   int setupBarShift=iBarShift(c.symbol,PERIOD_M15,refreshed.setupTime,true);
   if(setupBarShift<1)
     {
      c.rejectReason="REJECT_SETUP_AGE_UNAVAILABLE";
      return false;
     }

   c.setupAgeBars=(int)MathMax(0,setupBarShift-1);
   int effectiveMaxAge=STB_EffectiveMaxSetupAgeBars();
   if(effectiveMaxAge>0 && c.setupAgeBars>effectiveMaxAge)
     {
      c.rejectReason="REJECT_SETUP_TOO_OLD";
      return false;
     }

   if(!ValidatePendingSetup(refreshed))
     {
      c.rejectReason="REJECT_INVALID_PENDING_GEOMETRY";
      return false;
     }

   validated=refreshed;
   c.lastValidationTime=TimeCurrent();
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Serialize final scanner revalidation/submission across chart instances.
// The lock is terminal-local and expires automatically if an instance disappears.
string STB_EntryLockKey(const string symbol)
  {
   return STB_MgmtScopeKey("ENTRY_"+(string)InpMagic,symbol);
  }

bool STB_EntryLockAcquire(const string symbol,double &token)
  {
   token=0.0;
   if(symbol=="")
      return false;

   string key=STB_EntryLockKey(symbol);
   if(!GlobalVariableCheck(key))
     {
      ResetLastError();
      if(!GlobalVariableTemp(key) && !GlobalVariableCheck(key))
        {
         Print("STB entry lock creation failed symbol=",symbol,
               " err=",GetLastError());
         return false;
        }
     }

   if(!GlobalVariableCheck(key))
      return false;

   // Use local wall-clock time so a quiet server market does not freeze the
   // lease expiry while other chart instances remain active.
   datetime now=TimeLocal();
   double current=GlobalVariableGet(key);
   if(current!=0.0 && MathFloor(current)>(double)now)
      return false;

   // Integer part is a 120-second lease expiry; fractional part tags the chart.
   token=(double)(now+120)+
         (double)((long)ChartID()%1000000)/1000000.0;
   if(!GlobalVariableSetOnCondition(key,token,current))
     {
      token=0.0;
      return false;
     }

   return true;
  }

bool STB_EntryLockStillOwned(const string symbol,const double token)
  {
   if(symbol=="" || token==0.0)
      return false;

   string key=STB_EntryLockKey(symbol);
   if(!GlobalVariableCheck(key))
      return false;

   return (GlobalVariableGet(key)==token &&
           MathFloor(token)>(double)TimeLocal());
  }

void STB_EntryLockRelease(const string symbol,const double token)
  {
   if(symbol=="" || token==0.0)
      return;

   string key=STB_EntryLockKey(symbol);
   if(GlobalVariableCheck(key))
      GlobalVariableSetOnCondition(key,0.0,token);
  }

bool STB_ExposureAllowsExecution(const Setup &s,string &reason)
  {
   reason="";
   if(HasManagedExposure(s.symbol))
     {
      reason="MANAGED_EXPOSURE_EXISTS";
      return false;
     }
   long maxOrders=AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   if(maxOrders>0 && OrdersTotal()>=maxOrders)
     {
      reason="ACCOUNT_ORDER_LIMIT";
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_FinalAutoGate(const Setup &s,string &reason)
  {
   reason="";
   if(!g_autoTrading)
     {
      reason="AUTO_TRADING_OFF";
      return false;
     }
   if(!STB_TradeEnvironmentAllowed())
     {
      reason="TRADE_ENVIRONMENT_REJECT";
      return false;
     }
   if(!STB_ExposureAllowsExecution(s,reason))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ExecuteTopCandidate()
  {
   if(g_scannerTop10Count<=0)
      {
       Print("STB EXECUTION SKIP reason=NO_TOP_CANDIDATE",
             " confidence=",g_scannerConfidence,
             " universe=",IntegerToString(g_scannerUniverseCount),
             " eligible=",IntegerToString(g_scannerEligibleCount),
             " quality=",IntegerToString(g_scannerQualityCount),
             " regime=",IntegerToString(g_scannerRegimeCount),
             " candidates=",IntegerToString(g_scannerCandidateCount));
       return;
      }
    if(g_scannerConfidence!="CLEAR")
      {
       double topScore=g_scannerTop10[0].opportunityScore;
       double secondScore=(g_scannerTop10Count>1 ?
                           g_scannerTop10[1].opportunityScore:0.0);
       Print("STB EXECUTION SKIP reason=CONFIDENCE_NOT_CLEAR",
             " confidence=",g_scannerConfidence,
             " top=",g_scannerTop10[0].symbol,
             " direction=",(g_scannerTop10[0].direction>0 ? "BUY":"SELL"),
             " topScore=",DoubleToString(topScore,1),
             " secondScore=",DoubleToString(secondScore,1),
             " requiredGap=",DoubleToString(InpScannerMinTopGap,1),
             " topCount=",IntegerToString(g_scannerTop10Count));
       return;
      }

   if(!g_autoTrading)
     {
      Print("STB SCANNER SHADOW: Order=BLOCKED_BY_AUTO_OFF",
            " top=",g_scannerTop10[0].symbol,
            " dir=",(g_scannerTop10[0].direction>0 ? "BUY":"SELL"),
            " score=",DoubleToString(g_scannerTop10[0].opportunityScore,1));
      return;
     }

   for(int i=0;i<g_scannerTop10Count;i++)
     {
      STBCandidate c=g_scannerTop10[i];

      // Confidence must remain valid for the candidate actually being tried.
      // If an earlier candidate fails final validation, do not automatically
      // promote a fallback whose own gap to the next valid watchlist entry
      // is below the configured threshold.
      if(i>0)
        {
         int watchRank=-1;
         for(int w=0;w<g_scannerWatchlistCount;w++)
           {
            if(g_scannerWatchlist[w].symbol==c.symbol &&
               g_scannerWatchlist[w].direction==c.direction &&
               g_scannerWatchlist[w].setupTime==c.setupTime)
              {
               watchRank=w;
               break;
              }
           }

         if(watchRank<0)
           {
            Print("STB CANDIDATE REJECT stage=FALLBACK_CONFIDENCE",
                  " symbol=",c.symbol,
                  " reason=CANDIDATE_NOT_IN_REVALIDATED_WATCHLIST");
            break;
           }

         double fallbackScore=g_scannerWatchlist[watchRank].opportunityScore;
         double nextScore=(watchRank+1<g_scannerWatchlistCount ?
                           g_scannerWatchlist[watchRank+1].opportunityScore:0.0);
         bool fallbackClear=(fallbackScore>=InpScannerMinScore);
         if(fallbackClear && watchRank+1<g_scannerWatchlistCount)
            fallbackClear=(fallbackScore-nextScore)>=InpScannerMinTopGap;

         if(!fallbackClear)
           {
            Print("STB EXECUTION SKIP reason=FALLBACK_CONFIDENCE_NOT_CLEAR",
                  " symbol=",c.symbol,
                  " direction=",(c.direction>0 ? "BUY":"SELL"),
                  " score=",DoubleToString(fallbackScore,1),
                  " nextScore=",DoubleToString(nextScore,1),
                  " requiredGap=",DoubleToString(InpScannerMinTopGap,1),
                  " watchRank=",IntegerToString(watchRank+1));
            break;
           }
        }

      string symbol=c.symbol;
      bool wasSelected=(bool)SymbolInfoInteger(symbol,SYMBOL_SELECT);

      // Keep the candidate symbol subscribed through final revalidation and
      // order placement. Retain it afterward only while a managed exposure
      // needs live quotes for stop management/trailing.
      if(!wasSelected && !SymbolSelect(symbol,true))
         {
          Print("STB CANDIDATE REJECT",
                " stage=SYMBOL_SELECT",
                " symbol=",symbol,
                " reason=SYMBOL_SELECT_FAILED",
                " error=",IntegerToString(GetLastError()));
          continue;
         }

      // The lock spans exposure recheck through broker submission so two
      // chart instances cannot both pass the same-symbol gate concurrently.
      double entryLockToken=0.0;
      if(!STB_EntryLockAcquire(symbol,entryLockToken))
        {
         if(!wasSelected && !STB_HasSymbolExposureForManagement(symbol))
            SymbolSelect(symbol,false);
         continue;
        }

      Setup validated;
       bool revalidated=STB_FinalCandidateRevalidation(c,validated);
       bool placed=false;
       if(!revalidated)
         {
          Print("STB CANDIDATE REJECT",
                " stage=FINAL_REVALIDATION",
                " symbol=",c.symbol,
                " direction=",(c.direction>0 ? "BUY":"SELL"),
                " reason=",(c.rejectReason=="" ? "UNSPECIFIED":c.rejectReason),
                " rank=",IntegerToString(c.currentRank),
                " score=",DoubleToString(c.opportunityScore,1));
         }
       else
         {
          string finalGateReason="";
          if(!STB_FinalAutoGate(validated,finalGateReason))
            {
             Print("STB CANDIDATE REJECT",
                   " stage=FINAL_AUTO_GATE",
                   " symbol=",c.symbol,
                   " direction=",(c.direction>0 ? "BUY":"SELL"),
                   " reason=",(finalGateReason=="" ? "UNSPECIFIED":finalGateReason),
                   " rank=",IntegerToString(c.currentRank),
                   " score=",DoubleToString(c.opportunityScore,1));
            }
          else
             placed=PlaceSetup(validated,entryLockToken);
         }
       STB_EntryLockRelease(symbol,entryLockToken);

      if(!wasSelected && !STB_HasSymbolExposureForManagement(symbol))
         SymbolSelect(symbol,false);

      if(placed)
        {
         g_panelScanPlacements++;
         return;
        }
     }
  }

//==================================================================
// MANUAL PENDING COMMANDS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PlaceManualPendingDirection(const int direction)
  {
   if((direction!=1 && direction!=-1) ||
      !STB_TradeEnvironmentAllowed())
      return false;

   if(!STB_SymbolManagementOwnedVerified(_Symbol))
     {
      Print("STB MANUAL PENDING REJECTED: symbol writer lease not owned symbol=",_Symbol);
      return false;
     }

   long tradeMode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY ||
      (direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   double pip=PipSize(_Symbol);
   double volume=NormalizeVolume(_Symbol,InpBaseLots);
   if(pip<=0.0 || volume<=0.0)
      return false;
   if(!STB_DirectionVolumeWithinLimit(_Symbol,direction,volume,"PlaceManualPendingDirection"))
      return false;

   int orderModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
   if((orderModes&SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP ||
      (orderModes&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
      return false;

   int expirationModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

   if((expirationModes&SYMBOL_EXPIRATION_GTC)!=SYMBOL_EXPIRATION_GTC)
     {
      if((expirationModes&SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
         typeTime=ORDER_TIME_DAY;
      else
         return false;
     }

   ENUM_ORDER_TYPE orderType=(direction>0 ? ORDER_TYPE_BUY_STOP
                                          : ORDER_TYPE_SELL_STOP);
   double requestedEntry=(direction>0 ? tick.ask+InpManualPendingGapPips*pip
                                      : tick.bid-InpManualPendingGapPips*pip);
   double entry=0.0;
   if(!STB_ResolveManualPendingEntry(_Symbol,orderType,requestedEntry,tick,entry))
      return false;

   double sl=0.0;
   if(!CalculateInitialPendingProtectionSL(_Symbol,orderType,entry,sl))
      return false;

   trade.SetExpertMagicNumber(0);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double effectiveManualOffset=MathAbs(entry-(direction>0 ? tick.bid:tick.ask))/pip;
   string comment="STB|M|"+(direction>0 ? "BUY":"SELL")+"|EB"+DoubleToString(effectiveManualOffset,8);
   if(!STB_SymbolManagementOwnedVerified(_Symbol))
      return false;
   bool ok=(direction>0)
           ? trade.BuyStop(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment)
           : trade.SellStop(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment);

   if(!ok || !TradeRetcodePlacementSucceeded())
      return false;

   ulong ticket=trade.ResultOrder();
   if(ticket==0 || !VerifyPendingInitialSL(ticket))
     {
      Print("STB MANUAL PENDING REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            _Symbol," order=",IntegerToString((int)ticket));
      if(ticket>0 && OrderSelect(ticket))
         STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK,"PlaceManual");
      return false;
     }

   // SIMPLIFIED: origin registry call removed.
   STB_AfterExposureCreated(ticket,"UI_MANUAL"); // Blueprint 10/11
   STB_ManualOverrideSet(ticket); // MANUAL_OVERRIDE: user-placed pending is final

   Print("STB MANUAL PENDING ",
         (direction>0 ? "BUY_STOP":"SELL_STOP"),
         " SUCCESS symbol=",_Symbol,
         " entry=",DoubleToString(entry,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " order=",IntegerToString((int)ticket));
   return true;
  }


//==================================================================
// SCANNER ARCHITECTURE — UNIVERSE -> TOP10 CANDIDATES
//==================================================================



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PlaceManualLimitDirection(const int direction)
  {
   if((direction!=1 && direction!=-1) ||
      !STB_TradeEnvironmentAllowed())
      return false;

   if(!STB_SymbolManagementOwnedVerified(_Symbol))
     {
      Print("STB MANUAL LIMIT REJECTED: symbol writer lease not owned symbol=",_Symbol);
      return false;
     }

   long tradeMode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY ||
      (direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   double pip=PipSize(_Symbol);
   double volume=NormalizeVolume(_Symbol,InpBaseLots);
   if(pip<=0.0 || volume<=0.0)
      return false;
   if(!STB_DirectionVolumeWithinLimit(_Symbol,direction,volume,"PlaceManualLimitDirection"))
      return false;

   int orderModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
   if((orderModes&SYMBOL_ORDER_LIMIT)!=SYMBOL_ORDER_LIMIT ||
      (orderModes&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
      return false;

   int expirationModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

   if((expirationModes&SYMBOL_EXPIRATION_GTC)!=SYMBOL_EXPIRATION_GTC)
     {
      if((expirationModes&SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
         typeTime=ORDER_TIME_DAY;
      else
         return false;
     }

   ENUM_ORDER_TYPE orderType=(direction>0 ? ORDER_TYPE_BUY_LIMIT
                                          : ORDER_TYPE_SELL_LIMIT);
   double requestedEntry=(direction>0 ? tick.bid-InpManualPendingGapPips*pip
                                      : tick.ask+InpManualPendingGapPips*pip);
   double entry=0.0;
   if(!STB_ResolveManualPendingEntry(_Symbol,orderType,requestedEntry,tick,entry))
      return false;
   double sl=0.0;

   if(!CalculateInitialPendingProtectionSL(_Symbol,orderType,entry,sl))
      return false;

   trade.SetExpertMagicNumber(0);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double effectiveManualOffset=MathAbs(entry-(direction>0 ? tick.bid:tick.ask))/pip;
   string comment="STB|M|"+(direction>0 ? "BUY_LIMIT":"SELL_LIMIT")+
                  "|EB"+DoubleToString(effectiveManualOffset,8);
   if(!STB_SymbolManagementOwnedVerified(_Symbol))
      return false;
   bool ok=(direction>0)
           ? trade.BuyLimit(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment)
           : trade.SellLimit(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment);

   if(!ok || !TradeRetcodePlacementSucceeded())
      return false;

   ulong ticket=trade.ResultOrder();
   if(ticket==0 || !VerifyPendingInitialSL(ticket))
     {
      Print("STB MANUAL LIMIT REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            _Symbol," order=",IntegerToString((int)ticket));
      if(ticket>0 && OrderSelect(ticket))
         STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK,"PlaceManual");
      return false;
     }

   // SIMPLIFIED: origin registry call removed.
   STB_AfterExposureCreated(ticket,"UI_MANUAL"); // Blueprint 10/11
   STB_ManualOverrideSet(ticket); // MANUAL_OVERRIDE: user-placed pending is final

   Print("STB MANUAL PENDING ",
         (direction>0 ? "BUY_LIMIT":"SELL_LIMIT"),
         " SUCCESS symbol=",_Symbol,
         " entry=",DoubleToString(entry,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " order=",IntegerToString((int)ticket));
   return true;
  }

STBCandidate g_scannerCurrent[];
STBCandidate g_scannerPrevious[];
STBCandidate g_scannerWatchlist[];
STBCandidate g_scannerTop10[];

datetime g_scannerLastCycleBar=0;
datetime g_scannerLastRun=0;
ulong    g_scannerCycle=0;

string g_scannerStatus="NOT_RUN";
string g_scannerConfidence="NO_CLEAR_WINNER";

int g_scannerUniverseCount=0;
int g_scannerEligibleCount=0;
int g_scannerQualityCount=0;
int g_scannerRegimeCount=0;
int g_scannerBuyCount=0;
int g_scannerSellCount=0;
int g_scannerCandidateCount=0;
int g_scannerWatchlistCount=0;
int g_scannerTop10Count=0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ScannerSessionOpen(const string symbol)
  {
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(),dt);

   int nowSec=dt.hour*3600+dt.min*60+dt.sec;

   for(uint session=0;session<32;session++)
     {
      datetime from=0;
      datetime to=0;

      if(!SymbolInfoSessionTrade(symbol,
                                 (ENUM_DAY_OF_WEEK)dt.day_of_week,
                                 session,
                                 from,to))
         break;

      MqlDateTime fd,td;
      TimeToStruct(from,fd);
      TimeToStruct(to,td);

      int fromSec=fd.hour*3600+fd.min*60+fd.sec;
      int toSec=td.hour*3600+td.min*60+td.sec;

      if(fromSec==toSec)
         return true;

      if(fromSec<toSec)
        {
         if(nowSec>=fromSec && nowSec<=toSec)
            return true;
        }
      else
         if(nowSec>=fromSec || nowSec<=toSec)
            return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Reject invalid market quotes before they can influence scanner eligibility or ranking.
bool STB_ScannerQuoteValid(const MqlTick &tick,string &reason)
  {
   reason="";

   if(tick.time<=0 ||
      !MathIsValidNumber(tick.bid) ||
      !MathIsValidNumber(tick.ask) ||
      tick.bid<=0.0 ||
      tick.ask<=0.0 ||
      tick.ask<tick.bid)
     {
      reason="REJECT_INVALID_QUOTE";
      return false;
     }

   // TimeTradeServer is a server-time estimate in live operation and follows
   // simulated time in Strategy Tester. Permit only a tiny timestamp skew;
   // never turn a materially future-dated quote into a fresh quote via clamping.
   datetime clockNow=TimeTradeServer();
   if(clockNow<=0)
      clockNow=TimeCurrent();

   if(clockNow<=0)
     {
      reason="REJECT_CLOCK_UNAVAILABLE";
      return false;
     }

   long ageSeconds=(long)clockNow-(long)tick.time;
   if(ageSeconds < -2)
     {
      reason="REJECT_FUTURE_QUOTE";
      return false;
     }

   if(ageSeconds<0)
      ageSeconds=0;

   if(ageSeconds>(long)MathMax(30,InpScannerMaxQuoteAgeSec))
     {
      reason="REJECT_STALE_DATA";
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ScannerDataEligible(const string symbol,string &reason)
  {
   reason="";

   bool custom=false;
   if(symbol=="" || !SymbolExist(symbol,custom))
     {
      reason="REJECT_SYMBOL_NOT_FOUND";
      return false;
     }

   bool selected=(bool)SymbolInfoInteger(symbol,SYMBOL_SELECT);
   if(!selected && !SymbolSelect(symbol,true))
     {
      reason="REJECT_SYMBOL_SELECT_FAILED";
      return false;
     }

   if(!SymbolIsSynchronized(symbol))
     {
      reason="REJECT_DATA_UNAVAILABLE";
      return false;
     }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
     {
      reason="REJECT_DATA_UNAVAILABLE";
      return false;
     }

   if(!STB_ScannerQuoteValid(tick,reason))
      return false;

   if(Bars(symbol,PERIOD_M15)<MathMax(InpLookbackM15,40) ||
      Bars(symbol,PERIOD_H4)<MathMax(InpLookbackH4,40))
     {
      reason="REJECT_DATA_UNAVAILABLE";
      return false;
     }

   if(!STB_ScannerSessionOpen(symbol))
     {
      reason="REJECT_SESSION";
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ScannerDirectionAllowed(const string symbol,const int direction)
  {
   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);

   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;

   if((orderMode&SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP ||
      (orderMode&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL ||
      (orderMode&SYMBOL_ORDER_TP)!=SYMBOL_ORDER_TP)
      return false;

   if(direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY)
      return false;

   if(direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_CalcMarketQuality(const string symbol,STBMarketQuality &q)
  {
   q.valid=false;
   q.spreadPips=0.0;
   q.relativeSpread=0.0;
   q.volatility=0.0;
   q.volatilityRatio=1.0;
   q.activityRatio=1.0;
   q.freshnessScore=0.0;
   q.score=0.0;
   q.reason="REJECT_DATA_UNAVAILABLE";

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   string quoteReason="";
   if(!STB_ScannerQuoteValid(tick,quoteReason))
     {
      q.reason=quoteReason;
      return false;
     }
   q.reason="REJECT_DATA_UNAVAILABLE";

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return false;

   MqlRates rates[];
   if(!GetRates(symbol,PERIOD_M15,48,rates))
      return false;

   double atrNow=LocalATR(rates,1,14);
   double atrBase=LocalATR(rates,20,14);

   if(!MathIsValidNumber(atrNow) ||
      !MathIsValidNumber(atrBase) ||
      atrNow<=0.0 || atrBase<=0.0)
     {
      q.reason="REJECT_INVALID_MARKET_DATA";
      return false;
     }

   q.spreadPips=(tick.ask-tick.bid)/pip;
   q.relativeSpread=(tick.ask-tick.bid)/atrNow*100.0;
   q.volatility=atrNow;
   q.volatilityRatio=atrNow/atrBase;

   double avgVol=0.0;
   int volCount=0;

   for(int i=5;i<25 && i<ArraySize(rates);i++)
     {
      avgVol+=(double)rates[i].tick_volume;
      volCount++;
     }

   if(volCount<=0)
      return false;

   avgVol/=volCount;
   q.activityRatio=(avgVol>0.0 ?
                    (double)rates[1].tick_volume/avgVol : 0.0);

   datetime qualityClock=TimeTradeServer();
   if(qualityClock<=0)
      qualityClock=TimeCurrent();
   if(qualityClock<=0)
     {
      q.reason="REJECT_CLOCK_UNAVAILABLE";
      return false;
     }

   long age=(long)qualityClock-(long)tick.time;
   if(age<0)
      age=0; // The shared validator already rejected future skew beyond two seconds.
   if(age>(long)MathMax(30,InpScannerMaxQuoteAgeSec))
     {
      q.reason="REJECT_STALE_DATA";
      return false;
     }

   q.freshnessScore=100.0-
                    MathMin(100.0,
                            (double)age/(double)MathMax(30,InpScannerMaxQuoteAgeSec)*100.0);

   if(!MathIsValidNumber(q.spreadPips) ||
      !MathIsValidNumber(q.relativeSpread) ||
      !MathIsValidNumber(q.volatilityRatio) ||
      !MathIsValidNumber(q.activityRatio) ||
      !MathIsValidNumber(q.freshnessScore) ||
      q.spreadPips<0.0 ||
      q.relativeSpread<0.0 ||
      q.volatilityRatio<=0.0 ||
      q.activityRatio<0.0 ||
      q.freshnessScore<0.0 || q.freshnessScore>100.0)
     {
      q.reason="REJECT_INVALID_MARKET_METRICS";
      return false;
     }

   double score=100.0;
   score-=MathMin(35.0,q.relativeSpread*3.0);

   if(q.volatilityRatio>3.0)
      score-=25.0;
   else
      if(q.volatilityRatio<0.35)
         score-=20.0;

   if(q.activityRatio<0.20)
      score-=25.0;
   else
      if(q.activityRatio<0.40)
         score-=12.0;

   score*=MathMax(0.0,q.freshnessScore)/100.0;
   q.score=MathMax(0.0,MathMin(100.0,score));

   if(InpMaxSpreadPips>0.0 && q.spreadPips>InpMaxSpreadPips)
     {
      q.reason="REJECT_SPREAD";
      return false;
     }

   // High technical scores do not override excessive transaction friction.
   // The ATR-relative cap adapts to each symbol's current M15 volatility.
   if(InpMaxRelativeSpreadPct>0.0 &&
      q.relativeSpread>InpMaxRelativeSpreadPct)
     {
      q.reason="REJECT_RELATIVE_SPREAD";
      return false;
     }

   if(q.activityRatio<0.10)
     {
      q.reason="REJECT_ACTIVITY";
      return false;
     }

   if(q.volatilityRatio>4.0)
     {
      q.reason="REJECT_VOLATILITY";
      return false;
     }

   if(q.score+1e-9<InpScannerMinQuality)
     {
      q.reason="REJECT_QUALITY_SCORE";
      return false;
     }

   q.valid=true;
   q.reason="";
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_EvaluateRegime(const string symbol,STBRegimeState &r)
  {
   r.regime=STB_REGIME_UNSTABLE;
   r.strength=0.0;
   r.bias=0;
   r.volatilityRatio=1.0;
   r.efficiency=0.0;
   r.reason="REJECT_UNSTABLE_REGIME";

   TrendInfo trend=GetH4Trend(symbol);

   MqlRates m15[];
   if(!GetRates(symbol,PERIOD_M15,64,m15))
      return false;

   double atrNow=LocalATR(m15,1,14);
   double atrBase=LocalATR(m15,30,14);

   if(atrNow<=0.0 || atrBase<=0.0)
      return false;

   r.volatilityRatio=atrNow/atrBase;

   double net=MathAbs(m15[1].close-m15[21].close);
   double path=0.0;

   for(int i=1;i<21;i++)
      path+=MathAbs(m15[i].close-m15[i+1].close);

   r.efficiency=(path>0.0 ? net/path:0.0);

   if(trend.valid)
      r.bias=(trend.bias=="BULLISH" ? 1 :
              trend.bias=="BEARISH" ? -1 : 0);

   if(r.volatilityRatio>=2.50)
     {
      r.regime=STB_REGIME_HIGH_VOLATILITY;
      r.strength=MathMin(100.0,50.0+(r.volatilityRatio-2.50)*25.0);
      r.reason="HIGH_RELATIVE_VOLATILITY";
      return true;
     }

   if(r.volatilityRatio<=0.40)
     {
      r.regime=STB_REGIME_LOW_VOLATILITY;
      r.strength=MathMin(100.0,50.0+(0.40-r.volatilityRatio)*100.0);
      r.reason="LOW_RELATIVE_VOLATILITY";
      return true;
     }

   if(trend.valid && r.efficiency>=0.55)
     {
      r.regime=STB_REGIME_TRENDING;
      r.strength=MathMin(100.0,55.0+r.efficiency*45.0);
      r.reason="H4_TREND_PLUS_M15_EFFICIENCY";
      return true;
     }

   if(!trend.valid && r.efficiency<=0.25)
     {
      r.regime=STB_REGIME_RANGING;
      r.strength=MathMin(100.0,55.0+(0.25-r.efficiency)*180.0);
      r.reason="LOW_DIRECTIONAL_EFFICIENCY";
      return true;
     }

   if(r.efficiency>=0.20)
     {
      r.regime=STB_REGIME_TRANSITION;
      r.strength=55.0;
      r.reason="MIXED_STRUCTURE";
      return true;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_RegimeFitScore(const STBCandidate &c,const STBRegimeState &r)
  {
   if(r.regime==STB_REGIME_UNSTABLE)
      return 0.0;

   if(r.regime==STB_REGIME_TRENDING)
     {
      if((c.direction>0 && r.bias>0) ||
         (c.direction<0 && r.bias<0))
         return 100.0;
      return 35.0;
     }

   if(r.regime==STB_REGIME_RANGING)
      return 45.0;

   if(r.regime==STB_REGIME_TRANSITION)
      return 65.0;

   if(r.regime==STB_REGIME_HIGH_VOLATILITY)
      return 45.0;

   if(r.regime==STB_REGIME_LOW_VOLATILITY)
      return 60.0;

   return 0.0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_FindPreviousCandidate(const string symbol,
                              const int direction,
                              const datetime setupTime)
  {
   for(int i=0;i<ArraySize(g_scannerPrevious);i++)
      if(g_scannerPrevious[i].symbol==symbol &&
         g_scannerPrevious[i].direction==direction &&
         g_scannerPrevious[i].setupTime==setupTime)
         return i;

   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_CandidateStability(const string symbol,
                              const int direction,
                              const datetime setupTime,
                              const double score,
                              double &previousScore,
                              int &previousRank)
  {
   previousScore=0.0;
   previousRank=0;

   int idx=STB_FindPreviousCandidate(symbol,direction,setupTime);

   if(idx<0)
      return 55.0;

   previousScore=g_scannerPrevious[idx].opportunityScore;
   previousRank=g_scannerPrevious[idx].currentRank;

   double delta=MathAbs(score-previousScore);
   return MathMax(0.0,100.0-MathMin(100.0,delta*4.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_CandidateGreater(const STBCandidate &a,
                          const STBCandidate &b)
  {
   if(MathAbs(a.opportunityScore-b.opportunityScore)>1e-9)
      return a.opportunityScore>b.opportunityScore;

   if(MathAbs(a.marketQualityScore-b.marketQualityScore)>1e-9)
      return a.marketQualityScore>b.marketQualityScore;

   if(MathAbs(a.strategyScore-b.strategyScore)>1e-9)
      return a.strategyScore>b.strategyScore;

   if(MathAbs(a.setup.rr-b.setup.rr)>1e-9)
      return a.setup.rr>b.setup.rr;

   if(a.setupTime!=b.setupTime)
      return a.setupTime>b.setupTime;

   if(a.symbol!=b.symbol)
      return a.symbol<b.symbol;

   return a.direction>b.direction;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_SortCandidates(STBCandidate &arr[])
  {
   int n=ArraySize(arr);

   for(int i=0;i<n-1;i++)
     {
      int best=i;

      for(int j=i+1;j<n;j++)
         if(STB_CandidateGreater(arr[j],arr[best]))
            best=j;

      if(best!=i)
        {
         STBCandidate tmp=arr[i];
         arr[i]=arr[best];
         arr[best]=tmp;
        }
     }

   for(int i=0;i<n;i++)
      arr[i].currentRank=i+1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ScannerAllocationAbort(const string stage,string &symbols[],bool &wasSelected[])
  {
   Print("STB SCANNER ABORT stage=",stage,
         " reason=ARRAY_ALLOCATION_FAILED; no candidate may be executed");

   for(int i=0;i<ArraySize(symbols) && i<ArraySize(wasSelected);i++)
      if(!wasSelected[i] && !STB_HasSymbolExposureForManagement(symbols[i]))
         SymbolSelect(symbols[i],false);

   ArrayFree(g_scannerCurrent);
   ArrayFree(g_scannerWatchlist);
   ArrayFree(g_scannerTop10);

   g_scannerUniverseCount=0;
   g_scannerEligibleCount=0;
   g_scannerQualityCount=0;
   g_scannerRegimeCount=0;
   g_scannerBuyCount=0;
   g_scannerSellCount=0;
   g_scannerCandidateCount=0;
   g_scannerWatchlistCount=0;
   g_scannerTop10Count=0;
   g_scannerConfidence="NO_CLEAR_WINNER";
   g_scannerStatus="ALLOCATION_FAILED";
   g_panelScanSymbols=0;
   g_panelScanTradable=0;
   g_panelScanBuyReady=0;
   g_panelScanSellReady=0;
   g_panelScanPlacements=0;
   g_panelLastScanTime=TimeCurrent();
   g_panelChartBuyReady=false;
   g_panelChartSellReady=false;
   g_panelChartBuyScore=0.0;
   g_panelChartSellScore=0.0;
   g_scannerLastRun=TimeCurrent();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ScannerRun()
  {
   datetime cycleBar=iTime(_Symbol,PERIOD_M15,1);
   bool newChartBar=(cycleBar>0 && cycleBar!=g_scannerLastCycleBar);
   int scanInterval=MathMax(1,InpScanSeconds);
   bool intervalElapsed=(g_scannerLastRun<=0 ||
                         TimeCurrent()-g_scannerLastRun>=scanInterval);
   if(!newChartBar && !intervalElapsed)
      return;

   ulong started=(ulong)GetTickCount();

   string symbols[];
   bool wasSelected[];

   ArrayFree(g_scannerPrevious);
   int prevCount=ArraySize(g_scannerCurrent);

   if(prevCount>0)
     {
      if(ArrayResize(g_scannerPrevious,prevCount)!=prevCount)
        {
         STB_ScannerAllocationAbort("PREVIOUS_SNAPSHOT",symbols,wasSelected);
         return;
        }
      for(int p=0;p<prevCount;p++)
         g_scannerPrevious[p]=g_scannerCurrent[p];
     }

   ArrayFree(g_scannerCurrent);
   ArrayFree(g_scannerWatchlist);
   ArrayFree(g_scannerTop10);

   g_scannerUniverseCount=0;
   g_scannerEligibleCount=0;
   g_scannerQualityCount=0;
   g_scannerRegimeCount=0;
   g_scannerBuyCount=0;
   g_scannerSellCount=0;
   g_scannerCandidateCount=0;
   g_scannerWatchlistCount=0;
   g_scannerTop10Count=0;
   g_scannerConfidence="NO_CLEAR_WINNER";
   g_scannerStatus="RUNNING";

   ArrayResize(symbols,0);
   bool universeAllocationFailed=false;

   if(MQLInfoInteger(MQL_TESTER) && InpTesterChartSymbolOnly)
     {
      if(ArrayResize(symbols,1)!=1)
        {
         STB_ScannerAllocationAbort("TESTER_UNIVERSE",symbols,wasSelected);
         return;
        }
      symbols[0]=_Symbol;
     }
   else if(StringLen(InpScannerSymbols)>0)
     {
      // Parse only configured symbols instead of iterating the broker's full
      // symbol catalog. This keeps explicit-universe scans bounded and fast.
      string configured=InpScannerSymbols;
      StringReplace(configured,";",",");
      string parts[];
      ushort separator=StringGetCharacter(",",0);
      int count=StringSplit(configured,separator,parts);

      for(int i=0;i<count;i++)
        {
         string symbol=parts[i];
         StringTrimLeft(symbol);
         StringTrimRight(symbol);
         if(symbol=="")
            continue;

         bool duplicate=false;
         for(int j=0;j<ArraySize(symbols);j++)
            if(symbols[j]==symbol)
              {
               duplicate=true;
               break;
              }

         if(duplicate)
            continue;

         int n=ArraySize(symbols);
         if(ArrayResize(symbols,n+1)!=n+1)
           {
            Print("STB SCANNER UNIVERSE ALLOCATION FAILED symbol=",symbol);
            universeAllocationFailed=true;
            break;
           }
         symbols[n]=symbol;
        }
     }
   else
     {
      // Empty InpScannerSymbols means selected Market Watch symbols only.
      int total=SymbolsTotal(true);

      for(int i=0;i<total;i++)
        {
         string symbol=SymbolName(i,true);
         if(symbol=="")
            continue;

         int n=ArraySize(symbols);
         if(ArrayResize(symbols,n+1)!=n+1)
           {
            Print("STB SCANNER UNIVERSE ALLOCATION FAILED symbol=",symbol);
            universeAllocationFailed=true;
            break;
           }
         symbols[n]=symbol;
        }
     }

   if(universeAllocationFailed)
     {
      STB_ScannerAllocationAbort("UNIVERSE_LIST",symbols,wasSelected);
      return;
     }

   g_scannerUniverseCount=ArraySize(symbols);

   if(ArrayResize(wasSelected,g_scannerUniverseCount)!=g_scannerUniverseCount)
     {
      // Symbol selection has not started yet; discard any partial snapshot so
      // the abort handler cannot mistake default-false entries for symbols
      // that were originally unselected and deselect user-selected symbols.
      ArrayFree(wasSelected);
      STB_ScannerAllocationAbort("SYMBOL_SELECTION_SNAPSHOT",symbols,wasSelected);
      return;
     }

   for(int i=0;i<g_scannerUniverseCount;i++)
     {
      wasSelected[i]=(bool)SymbolInfoInteger(symbols[i],SYMBOL_SELECT);
      if(!wasSelected[i])
         SymbolSelect(symbols[i],true);
     }

   bool candidateAllocationFailed=false;

   for(int i=0;i<ArraySize(symbols);i++)
     {
      string symbol=symbols[i];

      string reason="";
      if(!STB_ScannerDataEligible(symbol,reason))
        {
         Print("STB SCANNER REJECT stage=DATA_ELIGIBILITY symbol=",symbol,
               " reason=",(reason=="" ? "UNSPECIFIED":reason));
         continue;
        }
      g_scannerEligibleCount++;
      STBMarketQuality quality;
      if(!STB_CalcMarketQuality(symbol,quality))
        {
         Print("STB SCANNER REJECT stage=MARKET_QUALITY symbol=",symbol,
               " reason=",(quality.reason=="" ? "UNSPECIFIED":quality.reason),
               " score=",DoubleToString(quality.score,1),
               " spreadPips=",DoubleToString(quality.spreadPips,2),
               " activityRatio=",DoubleToString(quality.activityRatio,2),
               " volatilityRatio=",DoubleToString(quality.volatilityRatio,2));
         continue;
        }
      g_scannerQualityCount++;
      STBRegimeState regime;
      if(!STB_EvaluateRegime(symbol,regime))
        {
         Print("STB SCANNER REJECT stage=REGIME_EVALUATION symbol=",symbol,
               " reason=",(regime.reason=="" ? "UNSPECIFIED":regime.reason));
         continue;
        }
      if(regime.regime==STB_REGIME_UNSTABLE)
        {
         Print("STB SCANNER REJECT stage=REGIME_FILTER symbol=",symbol,
               " reason=",(regime.reason=="" ? "UNSTABLE_REGIME":regime.reason),
               " volatilityRatio=",DoubleToString(regime.volatilityRatio,2),
               " efficiency=",DoubleToString(regime.efficiency,2));
         continue;
        }

      g_scannerRegimeCount++;

      for(int direction=1;direction>=-1;direction-=2)
        {
         if(!STB_ScannerDirectionAllowed(symbol,direction))
            continue;

         Setup setup;
         if(!BuildSetup(symbol,direction,setup,true))
            continue;

         STBCandidate candidate;
         ZeroMemory(candidate);

         candidate.valid=true;
         candidate.symbol=symbol;
         candidate.direction=direction;
         candidate.setupTime=setup.setupTime;
         candidate.setup=setup;
         candidate.strategyScore=MathMax(0.0,MathMin(100.0,setup.score));
         candidate.marketQualityScore=quality.score;
         candidate.regime=regime.regime;
         candidate.regimeStrength=regime.strength;
         candidate.regimeScore=STB_RegimeFitScore(candidate,regime);
         int setupBarShift=iBarShift(symbol,PERIOD_M15,setup.setupTime,true);
         if(setupBarShift<1)
           {
            Print("STB SCANNER REJECT stage=DISCOVERY_AGE symbol=",symbol,
                  " reason=SETUP_BAR_SHIFT_UNAVAILABLE",
                  " setupTime=",(string)setup.setupTime);
            continue;
           }

         // Count actual M15 bars, not elapsed wall-clock seconds. A BOS on
         // the most recently closed bar has age 0; weekends/session gaps do
         // not artificially age a setup.
         candidate.setupAgeBars=(int)MathMax(0,setupBarShift-1);

         double preliminary=0.65*candidate.strategyScore+
                            0.20*candidate.marketQualityScore+
                            0.10*candidate.regimeScore+
                            0.05*55.0;

         candidate.stabilityScore=
            STB_CandidateStability(symbol,direction,setup.setupTime,
                                   preliminary,
                                   candidate.previousScore,
                                   candidate.previousRank);

         candidate.opportunityScore=
            0.65*candidate.strategyScore+
            0.20*candidate.marketQualityScore+
            0.10*candidate.regimeScore+
            0.05*candidate.stabilityScore;

         candidate.opportunityScore=
            MathMax(0.0,MathMin(100.0,candidate.opportunityScore));

         if(candidate.opportunityScore+1e-9<InpScannerMinScore)
            continue;

         int idx=ArraySize(g_scannerCurrent);
         if(ArrayResize(g_scannerCurrent,idx+1)!=idx+1)
           {
            Print("STB SCANNER CANDIDATE ALLOCATION FAILED symbol=",symbol,
                  " direction=",direction);
            candidateAllocationFailed=true;
            break;
           }
         g_scannerCurrent[idx]=candidate;

         if(direction>0)
            g_scannerBuyCount++;
         else
            g_scannerSellCount++;
        }

      if(candidateAllocationFailed)
         break;
     }

   if(candidateAllocationFailed)
     {
      STB_ScannerAllocationAbort("CANDIDATE_LIST",symbols,wasSelected);
      return;
     }

   g_scannerCandidateCount=ArraySize(g_scannerCurrent);
   STB_SortCandidates(g_scannerCurrent);

   int watchLimit=MathMax(1,MathMin(InpScannerMaxWatchlist,50));
   int watchCount=MathMin(watchLimit,ArraySize(g_scannerCurrent));

   if(ArrayResize(g_scannerWatchlist,watchCount)!=watchCount)
     {
      STB_ScannerAllocationAbort("INITIAL_WATCHLIST",symbols,wasSelected);
      return;
     }

   for(int i=0;i<watchCount;i++)
      g_scannerWatchlist[i]=g_scannerCurrent[i];

   int validWatch=0;

   for(int i=0;i<watchCount;i++)
     {
      STBCandidate c=g_scannerWatchlist[i];

      Setup validated;
      if(!STB_FinalCandidateRevalidation(c,validated))
         continue;

      c.setup=validated;

      STBMarketQuality q;
       if(!STB_CalcMarketQuality(c.symbol,q))
         {
          Print("STB SCANNER REJECT stage=WATCHLIST_QUALITY symbol=",c.symbol,
                " reason=",(q.reason=="" ? "UNSPECIFIED":q.reason));
          continue;
         }
       c.marketQualityScore=q.score;
       STBRegimeState rr;
       if(!STB_EvaluateRegime(c.symbol,rr))
         {
          Print("STB SCANNER REJECT stage=WATCHLIST_REGIME symbol=",c.symbol,
                " reason=",(rr.reason=="" ? "UNSPECIFIED":rr.reason));
          continue;
         }
       if(rr.regime==STB_REGIME_UNSTABLE)
         {
          Print("STB SCANNER REJECT stage=WATCHLIST_REGIME symbol=",c.symbol,
                " reason=",(rr.reason=="" ? "UNSTABLE_REGIME":rr.reason));
          continue;
         }

      c.regime=rr.regime;
      c.regimeStrength=rr.strength;
      c.regimeScore=STB_RegimeFitScore(c,rr);

      int setupBarShift=iBarShift(c.symbol,PERIOD_M15,c.setup.setupTime,true);
      if(setupBarShift<1)
        {
         Print("STB SCANNER REJECT stage=WATCHLIST_AGE symbol=",c.symbol,
               " reason=SETUP_BAR_SHIFT_UNAVAILABLE",
               " setupTime=",(string)c.setup.setupTime);
         continue;
        }

      // Use the same bar-based age contract during final watchlist ranking.
      c.setupAgeBars=(int)MathMax(0,setupBarShift-1);

      if(InpMaxSetupAgeBars>0 &&
         c.setupAgeBars>InpMaxSetupAgeBars)
         continue;

      // Recompute stability from the refreshed watchlist inputs. The
      // stability component compares the current preliminary score with the
      // previous scan's score for this exact symbol/direction/setup identity.
      // Carrying the discovery-stage value here would mix stale and refreshed
      // market/regime components in the final ranking.
      double refreshedStrategyScore=
         MathMax(0.0,MathMin(100.0,c.setup.score));
      double refreshedPreliminary=
         0.65*refreshedStrategyScore+
         0.20*c.marketQualityScore+
         0.10*c.regimeScore+
         0.05*55.0;

      c.stabilityScore=
         STB_CandidateStability(c.symbol,c.direction,c.setup.setupTime,
                                refreshedPreliminary,
                                c.previousScore,c.previousRank);

      c.strategyScore=refreshedStrategyScore;

      c.opportunityScore=
         0.65*c.strategyScore+
         0.20*c.marketQualityScore+
         0.10*c.regimeScore+
         0.05*c.stabilityScore;

      c.opportunityScore=
         MathMax(0.0,MathMin(100.0,c.opportunityScore));

      if(c.opportunityScore+1e-9<InpScannerMinScore)
         continue;

      g_scannerWatchlist[validWatch]=c;
      validWatch++;
     }

   if(ArrayResize(g_scannerWatchlist,validWatch)!=validWatch)
     {
      STB_ScannerAllocationAbort("FINAL_WATCHLIST",symbols,wasSelected);
      return;
     }
   STB_SortCandidates(g_scannerWatchlist);
   g_scannerWatchlistCount=ArraySize(g_scannerWatchlist);

   int topCount=MathMin(MathMax(1,InpScannerTopN),10);
   topCount=MathMin(topCount,g_scannerWatchlistCount);

   if(ArrayResize(g_scannerTop10,topCount)!=topCount)
     {
      STB_ScannerAllocationAbort("EXECUTION_TOPN",symbols,wasSelected);
      return;
     }

   for(int i=0;i<topCount;i++)
      g_scannerTop10[i]=g_scannerWatchlist[i];

   STB_SortCandidates(g_scannerTop10);
   g_scannerTop10Count=ArraySize(g_scannerTop10);

   // Confidence is based on the complete revalidated/reranked watchlist, not
   // the truncated execution Top-N. In particular, TopN=1 must not bypass
   // the configured runner-up gap when a second valid candidate exists.
   if(g_scannerWatchlistCount<=0)
      g_scannerConfidence="NO_CLEAR_WINNER";
   else
     {
      double topScore=g_scannerWatchlist[0].opportunityScore;
      bool clear=(topScore>=InpScannerMinScore);

      if(clear && g_scannerWatchlistCount>1)
         clear=(topScore-g_scannerWatchlist[1].opportunityScore)>=InpScannerMinTopGap;

      g_scannerConfidence=(clear ? "CLEAR":"WEAK");
     }

   // Dashboard "ready" counts must reflect the final revalidated watchlist,
   // not discovery-stage candidates that may have become stale or failed a
   // final quality/regime/age gate.
   int finalBuyReady=0;
   int finalSellReady=0;
   for(int i=0;i<g_scannerWatchlistCount;i++)
     {
      if(g_scannerWatchlist[i].direction>0)
         finalBuyReady++;
      else if(g_scannerWatchlist[i].direction<0)
         finalSellReady++;
     }

   g_panelScanSymbols=g_scannerUniverseCount;
   g_panelScanTradable=g_scannerEligibleCount;
   g_panelScanBuyReady=finalBuyReady;
   g_panelScanSellReady=finalSellReady;
   g_panelScanPlacements=0;
   g_panelLastScanTime=TimeCurrent();

   g_panelChartBuyReady=false;
   g_panelChartSellReady=false;
   g_panelChartBuyScore=0.0;
   g_panelChartSellScore=0.0;

   for(int i=0;i<g_scannerWatchlistCount;i++)
     {
      if(g_scannerWatchlist[i].symbol!=_Symbol)
         continue;

      if(g_scannerWatchlist[i].direction>0)
        {
         g_panelChartBuyReady=true;
         g_panelChartBuyScore=g_scannerWatchlist[i].opportunityScore;
        }
      else
        {
         g_panelChartSellReady=true;
         g_panelChartSellScore=g_scannerWatchlist[i].opportunityScore;
        }
     }

   for(int i=0;i<ArraySize(symbols) && i<ArraySize(wasSelected);i++)
      if(!wasSelected[i] && !STB_HasSymbolExposureForManagement(symbols[i]))
         SymbolSelect(symbols[i],false);

   if(cycleBar>0)

      g_scannerLastCycleBar=cycleBar;

   g_scannerLastRun=TimeCurrent();
   g_scannerCycle++;
   g_scannerStatus="PASS";

   ulong elapsed=(ulong)GetTickCount()-(ulong)started;

   Print("STB SCANNER SUMMARY",
         " universe=",IntegerToString(g_scannerUniverseCount),
         " eligible=",IntegerToString(g_scannerEligibleCount),
         " quality=",IntegerToString(g_scannerQualityCount),
         " regime=",IntegerToString(g_scannerRegimeCount),
         " buyCandidates=",IntegerToString(g_scannerBuyCount),
         " sellCandidates=",IntegerToString(g_scannerSellCount),
         " candidates=",IntegerToString(g_scannerCandidateCount),
         " watchlist=",IntegerToString(g_scannerWatchlistCount),
         " top10=",IntegerToString(g_scannerTop10Count),
         " confidence=",g_scannerConfidence,
         " durationMs=",IntegerToString((int)elapsed));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// PANEL
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_DashDeleteAll()
  {
   int total=ObjectsTotal(0,-1,-1);

   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);

      if(StringFind(name,g_prefix+"DASH_")==0)
         ObjectDelete(0,name);
     }
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- P19 lightweight TRADING-SIGNAL markers (managed exposure levels) ------
// Marker taxonomy in FINAL:
//   TRADING SIGNAL : entry / SL / TP lines for the chart symbol's MANAGED
//                    exposures -> restored here (this function).
//   DECORATIVE     : oscillator panel / dashboard -> intentionally disabled.
//   DEBUG          : none active.
//   LEGACY         : the old professional visual engine has 0 callers.
// Only this EA's own objects (prefix TM_) are touched. This is a handful of
// HLINEs, refreshed on the panel cadence (timer / new bar / button) and is
// NEVER invoked from CHARTEVENT_CHART_CHANGE. No forced ChartRedraw.
void STB_DrawTradingLevels()
  {
   string pref=g_prefix+"TM_";

   // Remove only previously drawn STB trading markers.
   for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,pref)==0)
         ObjectDelete(0,name);
     }

   string sym=_Symbol;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=sym || !IsManagedPosition(ticket))
         continue;

      string tag=pref+"POS_"+(string)ticket+"_";
      DrawHLine(tag+"E",PositionGetDouble(POSITION_PRICE_OPEN),clrGray);
      DrawHLine(tag+"S",PositionGetDouble(POSITION_SL),clrSilver);
      DrawHLine(tag+"T",PositionGetDouble(POSITION_TP),clrDeepSkyBlue);
     }

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL)!=sym || !IsManagedOrder(ticket))
         continue;

      string tag=pref+"PND_"+(string)ticket+"_";
      DrawHLine(tag+"E",OrderGetDouble(ORDER_PRICE_OPEN),clrGray);
      DrawHLine(tag+"S",OrderGetDouble(ORDER_SL),clrSilver);
      DrawHLine(tag+"T",OrderGetDouble(ORDER_TP),clrDeepSkyBlue);
     }
  }

void UpdatePanel()
  {
// Large dashboard intentionally disabled.
// Dashboard objects are removed, while the bottom controls
// continue to operate independently.
   STB_DashDeleteAll();
   STB_DrawTradingLevels();
  }

//==================================================================
// BUTTONS
//==================================================================



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,text);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgColor);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100000);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountManagedPendingOrders()
  {
   int count=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(STB_IsManagedPendingType((long)type))
         count++;
     }

   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TrailAllPendingOrdersNow()
  {
   STB_BeginCycle(); // Blueprint 26: user PEND_TRAIL command gets its own decision cycle
   return STB_PendingTrailProcess(true); // count only confirmed broker geometry changes
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_UpdateControlBarLayout()
  {
// EA control keys.
// bottom-left anchored vertical stack.
// Order from bottom to top.
   const int left=7;
   const int bottom=28;
   const int width=82;
   const int height=19;
   const int gap=2;

   string names[8]=
     {
      g_prefix+"SAVE20",
      g_prefix+"SELL_STOP",
      g_prefix+"BUY_STOP",
      g_prefix+"PEND_TRAIL",
      g_prefix+"HEDGE",
      g_prefix+"SELL_LIMIT",
      g_prefix+"BUY_LIMIT",
      g_prefix+"AUTO"
     };

   for(int i=0;i<8;i++)
     {
      if(ObjectFind(0,names[i])<0)
         continue;

      ObjectSetInteger(0,names[i],OBJPROP_CORNER,CORNER_LEFT_LOWER);
      ObjectSetInteger(0,names[i],OBJPROP_XDISTANCE,left);
      ObjectSetInteger(0,names[i],OBJPROP_YDISTANCE,bottom+i*(height+gap));
      ObjectSetInteger(0,names[i],OBJPROP_XSIZE,width);
      ObjectSetInteger(0,names[i],OBJPROP_YSIZE,height);
      ObjectSetInteger(0,names[i],OBJPROP_FONTSIZE,7);
      ObjectSetInteger(0,names[i],OBJPROP_ZORDER,100000);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateButtons()
  {
   STB_UpdateControlBarLayout();

   string buyName=g_prefix+"BUY_STOP";
   string sellName=g_prefix+"SELL_STOP";
   string autoName=g_prefix+"AUTO";
   string saveName=g_prefix+"SAVE20";
   string hedgeName=g_prefix+"HEDGE";
   string trailName=g_prefix+"PEND_TRAIL";

   ObjectSetString(0,buyName,OBJPROP_TEXT,"BUY STOP");
   ObjectSetInteger(0,buyName,OBJPROP_BGCOLOR,clrSeaGreen);
   ObjectSetInteger(0,buyName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,sellName,OBJPROP_TEXT,"SELL STOP");
   ObjectSetInteger(0,sellName,OBJPROP_BGCOLOR,clrTomato);
   ObjectSetInteger(0,sellName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,autoName,OBJPROP_TEXT,g_autoTrading ? "AUTO  ON":"AUTO  OFF");
   ObjectSetInteger(0,autoName,OBJPROP_BGCOLOR,
                    g_autoTrading ? clrSeaGreen : clrFireBrick);
   ObjectSetInteger(0,autoName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,saveName,OBJPROP_TEXT,"SAVE +20");
   ObjectSetInteger(0,saveName,OBJPROP_BGCOLOR,clrRoyalBlue);
   ObjectSetInteger(0,saveName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,hedgeName,OBJPROP_TEXT,"HEDGE");
   ObjectSetInteger(0,hedgeName,OBJPROP_BGCOLOR,clrDarkOrange);
   ObjectSetInteger(0,hedgeName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,trailName,OBJPROP_TEXT,
                   "PEND TRAIL "+
                   IntegerToString(CountManagedPendingOrders()));
   ObjectSetInteger(0,trailName,OBJPROP_BGCOLOR,clrSlateBlue);
   ObjectSetInteger(0,trailName,OBJPROP_COLOR,clrWhite);
  }

//==================================================================
// VISUAL MARKERS
//==================================================================



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteVisuals()
  {
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,g_prefix+"VIS_")==0 ||
         StringFind(name,g_prefix+"SIG_")==0 ||
         StringFind(name,g_prefix+"TM_")==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+





//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// BAR DETECTION
//==================================================================


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// INIT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   if(InpLookbackH4<30 || InpLookbackM15<30 ||
      InpStructureWindowBars<5)
      return false;
   if(InpSwingLeft<1 || InpSwingRight<1)
      return false;
   if(InpBaseLots<=0.0 ||
      InpTrendLotMultiplier<0.0 ||
      InpUniversalLotMultiplier<0.0 ||
      InpEntryBufferPips<0.0 ||
      InpSLBufferPips<0.0 ||
      InpInitialSLBufferPips<0.0 || InpMaxInitialSLPips<0.0 ||
      InpMinimumRR<=0.0 ||
      InpMaxPendingBars<0)
      return false;
   if(InpPatternWindowBars<1 ||
      InpHTFLookbackBars<60 || InpHTFLookbackBars>1000 ||
      InpHTFMaxZoneAgeBars<1 ||
      InpHTFMaxZoneAgeBars>InpHTFLookbackBars ||
      PeriodSeconds(InpHTFPatternTF)<PeriodSeconds(PERIOD_H1) ||
      InpHTFZoneMaxGapATR<0.0 || InpHTFZoneMaxGapATR>3.0 ||
      InpHTFMinFVGWidthATR<0.0 || InpHTFMinFVGWidthATR>1.0)
      return false;
   if(InpManualSaveStepPips<0.0)
      return false;
   if(InpTrendlineTolerancePips<0.0 ||
       InpTrailStartPips<0.0 ||
       InpLiveTrailDistancePips<0.0 ||
       InpTrailStepPips<0.0 ||
       InpStructuralTrailStartATR<=0.0 ||
       InpStructuralTrailStartATR>10.0 ||
       InpStructuralTrailBufferATR<0.0 ||
       InpStructuralTrailBufferATR>2.0)
      return false;
   if(InpMaxSpreadPips<0.0 ||
      InpMaxRelativeSpreadPct<0.0 ||
      InpMaxRelativeSpreadPct>100.0 ||
      InpSetupCooldownMinutes<0 ||
      InpMaxSetupAgeBars<0 ||
      InpPipPointsOverride<0.0 ||
      InpRiskPercent<0.0 ||
      InpMaxRiskVolume<0.0)
      return false;

   // Risk-sizing mode must not silently become a no-trade mode because a
   // stale .set file supplies zero risk.
   if(InpUseRiskSizing && (InpRiskPercent<=0.0 || InpRiskPercent>100.0))
      return false;

   // Reject NaN/Infinity for every floating-point input before range checks.
   if(
      !MathIsValidNumber(InpScannerMinQuality) ||
      !MathIsValidNumber(InpScannerMinScore) ||
      !MathIsValidNumber(InpScannerMinTopGap) ||
      !MathIsValidNumber(InpManualPendingGapPips) ||
      !MathIsValidNumber(InpRSIBuyLevel) ||
      !MathIsValidNumber(InpRSISellLevel) ||
      !MathIsValidNumber(InpCCIBuyLevel) ||
      !MathIsValidNumber(InpCCISellLevel) ||
      !MathIsValidNumber(InpRSIWeight) ||
      !MathIsValidNumber(InpCCIWeight) ||
      !MathIsValidNumber(InpMaxSpreadPips) ||
      !MathIsValidNumber(InpMaxRelativeSpreadPct) ||
      !MathIsValidNumber(InpAdaptiveBaseScore) ||
      !MathIsValidNumber(InpAdaptiveMinScore) ||
      !MathIsValidNumber(InpAdaptiveMaxScore) ||
      !MathIsValidNumber(InpAdaptiveStep) ||
      !MathIsValidNumber(InpAdaptiveWeakWinRate) ||
      !MathIsValidNumber(InpAdaptiveStrongWinRate) ||
      !MathIsValidNumber(InpAdaptiveHalfLifeDays) ||
      !MathIsValidNumber(InpAdaptiveUCBExploration) ||
      !MathIsValidNumber(InpEntryBufferPips) ||
      !MathIsValidNumber(InpPendingTrailMaxRiskExpansion) ||
      !MathIsValidNumber(InpPipPointsOverride) ||
      !MathIsValidNumber(InpSLBufferPips) ||
      !MathIsValidNumber(InpInitialSLBufferPips) ||
      !MathIsValidNumber(InpMaxInitialSLPips) ||
      !MathIsValidNumber(InpMinimumRR) ||
      !MathIsValidNumber(InpManualSaveStepPips) ||
      !MathIsValidNumber(InpTrendlineTolerancePips) ||
      !MathIsValidNumber(InpHTFZoneMaxGapATR) ||
      !MathIsValidNumber(InpHTFMinFVGWidthATR) ||
      !MathIsValidNumber(InpTrailStartPips) ||
      !MathIsValidNumber(InpLiveTrailDistancePips) ||
      !MathIsValidNumber(InpTrailStepPips) ||
      !MathIsValidNumber(InpStructuralTrailStartATR) ||
      !MathIsValidNumber(InpStructuralTrailBufferATR) ||
      !MathIsValidNumber(InpRiskPercent) ||
      !MathIsValidNumber(InpMaxRiskVolume) ||
      !MathIsValidNumber(InpBaseLots) ||
      !MathIsValidNumber(InpTrendLotMultiplier) ||
      !MathIsValidNumber(InpUniversalLotMultiplier)
     )
      return false;

   if(InpScannerMinQuality<0.0 ||
      InpScannerMinQuality>100.0 ||
      InpScannerMinScore<0.0 ||
      InpScannerMinScore>100.0 ||
      InpScannerMinTopGap<0.0 ||
      InpScannerMaxWatchlist<1 ||
      InpScannerTopN<1 ||
      InpScannerTopN>10 ||
      InpScannerMaxQuoteAgeSec<30 ||
      InpManualPendingGapPips<=0.0)
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


int OnInit()
  {
   g_autoStateName=ScopedStateName("AUTO");

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
     {
      // Tester runs must never depend on stale terminal GlobalVariables or
      // on a missing/malformed .set toggle. The explicit tester override is
      // deterministic and applies only inside Strategy Tester.
      g_autoTrading=(InpAutoTrading ||
                     InpTesterForceAutoTrading);
      GlobalVariableSet(g_autoStateName,g_autoTrading ? 1.0 : 0.0);
      STB_ManualOverrideClearAll(); // MANUAL_OVERRIDE: AUTO re-enables auto management
     }
   else
      if(!InpAutoTrading)
        {
         // Input=false forces AUTO OFF at initialization. The chart's
         // explicit AUTO button remains a deliberate runtime override.
         g_autoTrading=false;
         GlobalVariableSet(g_autoStateName,0.0);
        }
      else
         if(GlobalVariableCheck(g_autoStateName))
            g_autoTrading=(GlobalVariableGet(g_autoStateName)>0.5);
         else
           {
            g_autoTrading=true;
            GlobalVariableSet(g_autoStateName,1.0);
           }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);

   if(!SymbolSelect(_Symbol,true))
      Print("STB INIT: current chart SymbolSelect failed symbol=",_Symbol,
            " err=",GetLastError());

   Print("STB TRADE ENV terminal=",
         TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "ON":"OFF",
         " program=",MQLInfoInteger(MQL_TRADE_ALLOWED) ? "ON":"OFF",
         " accountExpert=",AccountInfoInteger(ACCOUNT_TRADE_EXPERT) ? "ON":"OFF",
          " accountTrade=",AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "ON":"OFF",
         " tester=",MQLInfoInteger(MQL_TESTER) ? "YES":"NO");

   Print("STB INIT symbol=",_Symbol,
         " chartTF=",EnumToString((ENUM_TIMEFRAMES)_Period),
         " magic=",IntegerToString((int)InpMagic),
         " auto=",g_autoTrading ? "ON":"OFF",
         " autoInput=",InpAutoTrading ? "ON":"OFF",
         " testerForceAuto=",InpTesterForceAutoTrading ? "ON":"OFF",
         " testerSymbolOnly=",InpTesterChartSymbolOnly ? "ON":"OFF",
         " universal=",InpAllowUniversal ? "ON":"OFF",
         " strictFVGOB=",InpStrictPatternFilters ? "ON":"OFF",
         " requireFVG=",InpRequireFVG ? "ON":"OFF",
         " requireOB=",InpRequireOB ? "ON":"OFF",
         " requireH4Align=",InpRequireH4TrendAlignment ? "ON":"OFF",
         " requireHTFConfluence=",InpRequireHTFConfluence ? "ON":"OFF",
         " htfTF=",EnumToString(InpHTFPatternTF),
         " htfLookback=",IntegerToString(InpHTFLookbackBars),
         " htfMaxAge=",IntegerToString(InpHTFMaxZoneAgeBars),
         " structuralTrail=",InpUseStructuralTrailing ? "ON":"OFF",
         " structuralTrailStartATR=",DoubleToString(InpStructuralTrailStartATR,2),
         " structuralTrailBufferATR=",DoubleToString(InpStructuralTrailBufferATR,2),
         " maxSpreadPips=",DoubleToString(InpMaxSpreadPips,1),
         " maxRelativeSpreadPct=",DoubleToString(InpMaxRelativeSpreadPct,1),
         " adaptiveHalfLifeDays=",DoubleToString(InpAdaptiveHalfLifeDays,1),
         " RSIperiod=",IntegerToString(InpRSIPeriod),
         " CCIperiod=",IntegerToString(InpCCIPeriod),
         " oscHardFilter=",InpOscillatorHardFilter ? "ON":"OFF",
         " adaptiveParams=",InpAdaptiveParameterLearning ? "ON":"OFF",
         " warmup=",IntegerToString(InpAdaptiveWarmupPerProfile),
         " UCB=",DoubleToString(InpAdaptiveUCBExploration,2)); Print("STB UNIVERSAL PROFIT LOCK POLICY ENFORCED: triggerPips=",DoubleToString(STB_ProfitLockTriggerPips(),1)," lockPips=",DoubleToString(STB_ProfitLockLockPips(),1));

// Keep the six dedicated EA controls in the upper-right, away from
// the native MT5 one-click panel. Button handlers only dispatch to
// dedicated strategy/trade-management functions.
   CreateButton(g_prefix+"BUY_STOP","BUY STOP",8,8,88,26,clrSeaGreen);
   CreateButton(g_prefix+"SELL_STOP","SELL STOP",8,8,88,26,clrTomato);
   CreateButton(g_prefix+"AUTO","AUTO",8,8,80,26,clrFireBrick);
   CreateButton(g_prefix+"SAVE20","SAVE +20",8,8,88,26,clrRoyalBlue);
   CreateButton(g_prefix+"HEDGE","HEDGE",8,8,84,26,clrDarkOrange);
   CreateButton(g_prefix+"SELL_LIMIT","SELL LIMIT",8,8,88,26,clrTomato);
   CreateButton(g_prefix+"BUY_LIMIT","BUY LIMIT",8,8,88,26,clrSeaGreen);
   CreateButton(g_prefix+"PEND_TRAIL","PEND TRAIL",8,8,96,26,clrSlateBlue);

   UpdateButtons();
    ResetLastError();
    if(!EventSetTimer(MathMax(1,InpScanSeconds)))
      {
       Print("STB INIT FAILED: EventSetTimer failed err=",GetLastError());
       return INIT_FAILED;
      }
   g_lastChartBar=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
   g_lastM15Bar=iTime(_Symbol,PERIOD_M15,0);








// P9 restart/reinitialize recovery: rebuild pending-trail state for EVERY
// managed pending type before the first management cycle. This prevents the
// first cycle from registering/trailing recovered orders before a clean rebuild.
   STB_PendingTrailRebuildFromTerminal();

// Seed the per-ticket geometry/override registry before any write is attempted.
// This closes the attach/restart window in which a manual SL/TP edit could be
// mistaken for an unknown baseline because the first timer reconciliation had
// not yet run.
   STB_ReconcileTradeRegistry();

// Harden restart/reattach protection: do not wait for the first Tick/Timer.
// Every currently open position is checked immediately through the one cycle.
   STB_RunManagementCycle(); // Protection takes priority during startup/recovery.

   // Scanner discovery is independent of account-wide exposure. Execution
   // still checks managed exposure for the candidate's own symbol.
   STB_ScannerRun();
   g_lastSignalScanBar=iTime(_Symbol,PERIOD_M15,1);

   UpdatePanel();
   return INIT_SUCCEEDED;
  }

//==================================================================
// DEINIT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
   double profit=TesterStatistics(STAT_PROFIT);
   double pf=TesterStatistics(STAT_PROFIT_FACTOR);
   double expected=TesterStatistics(STAT_EXPECTED_PAYOFF);
   double trades=TesterStatistics(STAT_TRADES);
   double ddAbs=TesterStatistics(STAT_EQUITY_DD);
   double ddMax=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double sharpe=TesterStatistics(STAT_SHARPE_RATIO);
   double recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
   double initial=TesterStatistics(STAT_INITIAL_DEPOSIT);

// Persist the final tester statistics in the terminal-wide Common\\Files
// directory. The baseline runner reads this machine-readable snapshot,
// avoiding dependence on the presentation/HTML template.
   int mh=FileOpen("SmartTradingBot_TesterMetrics.csv",
                   FILE_WRITE|FILE_CSV|FILE_COMMON,
                   ',');
   if(mh!=INVALID_HANDLE)
     {
      FileWrite(mh,
                "profit","trades","profit_factor","expected_payoff",
                "equity_dd","equity_dd_percent","sharpe",
                "recovery_factor","initial_deposit");
      FileWrite(mh,
                DoubleToString(profit,10),
                DoubleToString(trades,0),
                DoubleToString(pf,10),
                DoubleToString(expected,10),
                DoubleToString(ddAbs,10),
                DoubleToString(ddMax,10),
                DoubleToString(sharpe,10),
                DoubleToString(recovery,10),
                DoubleToString(initial,10));
      FileFlush(mh);
      FileClose(mh);
     }
   else
     {
      Print("STB TESTER METRICS CSV OPEN FAILED err=",GetLastError());
     }

   Print("STB TESTER METRICS",
         " profit=",DoubleToString(profit,2),
         " trades=",DoubleToString(trades,0),
         " pf=",DoubleToString(pf,4),
         " expected=",DoubleToString(expected,4),
         " equityDD=",DoubleToString(ddAbs,2),
         " equityDDPct=",DoubleToString(ddMax,4),
         " sharpe=",DoubleToString(sharpe,4),
         " recovery=",DoubleToString(recovery,4),
         " initial=",DoubleToString(initial,2));

   double criterion=STB_AdaptiveTesterCriterion();
   Print("STB TESTER adaptive criterion=",DoubleToString(criterion,6));
   return criterion;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   STB_ReleaseAllSymbolManagement(); // P10 release every symbol lease owned by this chart

   ObjectDelete(0,g_prefix+"BUY_STOP");
   ObjectDelete(0,g_prefix+"SELL_STOP");
   ObjectDelete(0,g_prefix+"AUTO");
   ObjectDelete(0,g_prefix+"SAVE20");
   ObjectDelete(0,g_prefix+"HEDGE");
   ObjectDelete(0,g_prefix+"SELL_LIMIT");
   ObjectDelete(0,g_prefix+"BUY_LIMIT");
   ObjectDelete(0,g_prefix+"PEND_TRAIL");
   ObjectDelete(0,g_prefix+"H4_TRENDLINE");
   ObjectDelete(0,g_prefix+"TF_TREND_BASE");
   ObjectDelete(0,g_prefix+"TF_TREND_EXT");
   ObjectDelete(0,g_prefix+"TF_TREND_HIGH");
   ObjectDelete(0,g_prefix+"TF_TREND_HIGH_EXT");
   ObjectDelete(0,g_prefix+"TF_TREND_LOW");
   ObjectDelete(0,g_prefix+"TF_TREND_LOW_EXT");

   STB_DashDeleteAll();
   DeleteVisuals();
   ObjectDelete(0,g_prefix+"OSC_PANEL");
   ObjectDelete(0,g_prefix+"OSC_SIG_B");
   ObjectDelete(0,g_prefix+"OSC_SIG_S");
   ReleaseIndicatorHandles();

   Comment("");
  }

//==================================================================
// TICK
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/* ==============================================================
   STB PENDING TRAIL SERVICES
   Included after the EA's global declarations and before events.
   ============================================================== */
#include <STB\STB_PendingDistanceResolver.mqh>
#include <STB\STB_PendingTrail.mqh>
void STB_RecordPendingInitialSLFailure(const int stateIdx)
  {
   if(stateIdx<0 || stateIdx>=ArraySize(g_stbPendingTrail))
      return;

   g_stbPendingTrail[stateIdx].failureCount++;

   int fc=g_stbPendingTrail[stateIdx].failureCount;
   int backoffSec=(fc<=1 ? STB_PEND_BACKOFF_1_SEC
                         : (fc==2 ? STB_PEND_BACKOFF_2_SEC
                                  : STB_PEND_BACKOFF_3_SEC));

   g_stbPendingTrail[stateIdx].nextRetryTime=TimeCurrent()+backoffSec;
  }

//==================================================================
// COMMON POST-CREATION POINT (MASTER BLUEPRINT 10/11)
//==================================================================
// Every creator calls this exactly once after the broker confirmed the
// ticket: Register + Initial Protection. Trade management itself runs ONLY
// inside STB_RunManagementCycle().
//==================================================================
// CENTRAL DELETE PATH (MASTER BLUEPRINT 34) - the ONLY OrderDelete writer
//==================================================================
enum ENUM_STB_DELETE_REASON
  {
   STB_DEL_AUTO_ROLLBACK=0,          // creator rollback (server accept but invalid)
   STB_DEL_SERVER_ACCEPT_INVALID=1,  // accepted then rejected geometry
   STB_DEL_EXPLICIT_USER_COMMAND=2,  // user-issued delete
   STB_DEL_SERVER_EXPIRATION=3,      // server-side explicit expiration
   STB_DEL_EXPLICIT_CLEANUP=4        // housekeeping cleanup
  };

bool STB_ExecuteOrderDelete(const ulong ticket,
                            const ENUM_STB_DELETE_REASON reason,
                            const string source)
  {
   if(ticket==0 || !OrderSelect(ticket))
      return false;

   ENUM_ORDER_TYPE deleteType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   bool isPending=(deleteType==ORDER_TYPE_BUY_LIMIT ||
                   deleteType==ORDER_TYPE_SELL_LIMIT ||
                   deleteType==ORDER_TYPE_BUY_STOP ||
                   deleteType==ORDER_TYPE_SELL_STOP ||
                   deleteType==ORDER_TYPE_BUY_STOP_LIMIT ||
                   deleteType==ORDER_TYPE_SELL_STOP_LIMIT);
   if(!isPending)
      return false;

   string orderComment=OrderGetString(ORDER_COMMENT);
   datetime setupTime=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
   ENUM_ORDER_TYPE_TIME timeType=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiry=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   bool stbComment=(StringFind(orderComment,"STB|")==0);
   bool hedgeCreated=(StringFind(orderComment,"STB|HEDGE|")==0);
   bool autoCreated=(StringFind(orderComment,"STB|B|")==0 ||
                     StringFind(orderComment,"STB|S|")==0);
   bool authorized=false;

   if(reason==STB_DEL_AUTO_ROLLBACK || reason==STB_DEL_SERVER_ACCEPT_INVALID)
     {
      bool knownCreator=(source=="OneClickHedge" ||
                         source=="PlaceSetup" ||
                         source=="PlaceManual");
      // Rollback is narrowly scoped to a fresh STB order. Manual orders may
      // use magic 0, so the explicit STB comment + exact creator source is
      // the authorization signal rather than magic number alone.
      bool creatorCommentMatches=
         (source=="OneClickHedge" && hedgeCreated) ||
         (source=="PlaceSetup" && autoCreated) ||
         (source=="PlaceManual" &&
          StringFind(orderComment,"STB|M|")==0);
      authorized=knownCreator && stbComment && creatorCommentMatches &&
                 setupTime>0 && setupTime<=TimeCurrent()+5 &&
                 TimeCurrent()-setupTime<=120;
     }
   else if(reason==STB_DEL_SERVER_EXPIRATION)
     {
      // Expiry deletion is only valid through the owned pending manager.
      // Recheck scope and lease at the final writer boundary, not only in
      // ManagePendingOrders before it calls this function.
      string symbol=OrderGetString(ORDER_SYMBOL);
      bool expiryAuthority=(source=="ManagePendingOrders" &&
                           IsManagedOrder(ticket) &&
                           STB_SymbolManagementOwnedVerified(symbol));
      if(expiryAuthority)
        {
         bool serverExpired=(timeType==ORDER_TIME_SPECIFIED &&
                             expiry>0 && TimeCurrent()>=expiry);
         bool localAgeExpired=false;
         if(autoCreated && !STB_ManualOverrideIs(ticket) && setupTime>0)
           {
            int maxBars=InpMaxPendingBars;
            int profileId=STB_AdaptiveParseProfileFromComment(orderComment);
            if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
              {
               STB_AP_SetActive(profileId);
               maxBars=STB_EffectiveMaxPendingBars();
               STB_AP_ClearActive();
              }
            localAgeExpired=(maxBars>0 &&
                             TimeCurrent()-setupTime>=maxBars*15*60);
           }
         // Server expiry remains honored for allowed managed orders;
         // local-age expiry remains restricted to unoverridden EA creations.
         authorized=serverExpired || localAgeExpired;
        }
     }

   if(!authorized)
     {
      Print("STB DELETE BLOCKED ticket=",IntegerToString((int)ticket),
            " reason=",IntegerToString((int)reason),
            " source=",source,
            " comment=",orderComment,
            " reason=UNAUTHORIZED_OR_UNVERIFIED");
      return false;
     }

   trade.SetAsyncMode(false);
   trade.SetExpertMagicNumber(InpMagic);

   bool requestOK=trade.OrderDelete(ticket);
   uint ret=trade.ResultRetcode();
   string retText=trade.ResultRetcodeDescription();

   // CTrade::OrderDelete returning true only confirms the local request
   // structure. Require both a server-success retcode and disappearance of
   // this active ticket before treating deletion as complete.
   if(!requestOK ||
      (ret!=TRADE_RETCODE_DONE && ret!=TRADE_RETCODE_DONE_PARTIAL))
     {
      Print("STB DELETE REJECTED ticket=",IntegerToString((int)ticket),
            " reason=",IntegerToString((int)reason),
            " source=",source,
            " ret=",ret," ",retText,
            " requestOK=",requestOK ? "YES":"NO");
      return false;
     }

   if(OrderSelect(ticket))
     {
      Print("STB DELETE NOT CONFIRMED ticket=",IntegerToString((int)ticket),
            " reason=",IntegerToString((int)reason),
            " source=",source,
            " ret=",ret," ",retText,
            " reason=ORDER_STILL_ACTIVE");
      return false;
     }

   Print("STB DELETE CONFIRMED ticket=",IntegerToString((int)ticket),
         " reason=",IntegerToString((int)reason),
         " source=",source,
         " ret=",ret);
   return true;
  }

// Single controlled entry used by every permitted pending delete.
bool STB_RequestOrderDelete(const ulong ticket,
                            const ENUM_STB_DELETE_REASON reason,
                            const string source)
  {
   return STB_ExecuteOrderDelete(ticket,reason,source);
  }

void STB_AfterExposureCreated(const ulong ticket,const string source)
  {
   if(ticket==0)
      return;

   if(OrderSelect(ticket) && IsManagedOrder(ticket))
     {
      string symbol=OrderGetString(ORDER_SYMBOL);
      if(symbol=="")
         return;
      SymbolSelect(symbol,true);
      if(!STB_SymbolManagementOwnedVerified(symbol))
         return;
      STB_PendingTrailRegister(ticket,source);
      EnsureInitialSLForPendingOrder(ticket);
      if(OrderSelect(ticket) &&
         OrderGetDouble(ORDER_SL)>0.0 &&
         OrderGetDouble(ORDER_TP)<=0.0)
         EnsureInitialTPForPendingOrder(ticket);
      return;
     }

   if(PositionSelectByTicket(ticket) && STB_IsProtectionPosition(ticket))
     {
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="")
         return;
      SymbolSelect(symbol,true);
      if(!STB_SymbolManagementOwnedVerified(symbol))
         return;
      EnsureInitialSL(ticket);
      if(PositionSelectByTicket(ticket) &&
         PositionGetDouble(POSITION_SL)>0.0 &&
         PositionGetDouble(POSITION_TP)<=0.0)
         EnsureInitialTPForPosition(ticket);
      return;
     }
  }

//==================================================================
// SINGLE MANAGEMENT CYCLE (MASTER BLUEPRINT 31/32/33)
//==================================================================
// The ONLY management decision path. OnTick / OnTimer / OnInit must call
// this and never run a management engine directly.
void STB_RunManagementCycle()
  {
   if(g_stbManagementCycleActive)
     {
      g_stbManagementCyclePending=true;
      return;
     }
   g_stbManagementCycleActive=true;
   int pass=0;
   do
     {
      g_stbManagementCyclePending=false;
      STB_BeginCycle();
      ManagePositions();
      ManagePendingOrders();
      STB_PendingTrailProcess();
      pass++;
     }
   while(g_stbManagementCyclePending && pass<2);
   g_stbManagementCycleActive=false;
  }

void OnTick()
  {
   STB_RunManagementCycle();
   bool m15Bar=NewM15Bar();
   if(m15Bar)
      STB_ReconcileTradeRegistry();
   ulong cycleBefore=g_scannerCycle;
   STB_ScannerRun();
   if(g_scannerCycle!=cycleBefore)
     {
      STB_ExecuteTopCandidate();
      g_lastSignalScanBar=iTime(_Symbol,PERIOD_M15,1);
      UpdatePanel();
     }
  }

//==================================================================
// TIMER
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   STB_RunManagementCycle();
   STB_ReconcileTradeRegistry();
   ulong cycleBefore=g_scannerCycle;
   STB_ScannerRun();
   if(g_scannerCycle!=cycleBefore)
     {
      STB_ExecuteTopCandidate();
      g_lastSignalScanBar=iTime(_Symbol,PERIOD_M15,1);
     }
   UpdatePanel();
   UpdateButtons();
  }

//==================================================================
// CHART EVENTS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
// Trade transaction intake is the single transaction-level protection owner.
   STB_TradeIntakeFromTransaction(trans);

   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD ||
      trans.deal==0 ||
      !HistoryDealSelect(trans.deal))
      return;

   string comment=HistoryDealGetString(trans.deal,DEAL_COMMENT);
   long magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
   long entryType=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   string symbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
   ulong positionId=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);

   // Reconcile per-ticket protection state before filtering by deal magic:
   // a manual/foreign-magic deal can partially or fully close a managed
   // netting position. Preserve state after partial OUT/OUT_BY while the
   // position still exists; clear it on full close or direction reversal.
   if(entryType==DEAL_ENTRY_OUT ||
      entryType==DEAL_ENTRY_OUT_BY ||
      entryType==DEAL_ENTRY_INOUT)
     {
      ulong closedTicket=trans.position;
      if(closedTicket>0)
        {
         bool positionRemains=PositionSelectByTicket(closedTicket);
         bool exposureReversed=(entryType==DEAL_ENTRY_INOUT);
         if(exposureReversed || !positionRemains)
           {
            GlobalVariableDel(TicketLockName(closedTicket));
            GlobalVariableDel(ScopedStateName("MODFAIL_"+(string)closedTicket));
           }
        }
     }

   if(magic!=(long)InpMagic)
      return;

// Hedges use the same magic but are not strategy-profile observations.
   bool isHedge=STB_AdaptiveIsHedgeComment(comment);

   if(entryType==DEAL_ENTRY_IN && !isHedge && positionId>0)
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
            // Legacy/manual trades without an explicit strategy profile
            // must not contaminate the adaptive learner.
            Print("STB ADAPTIVE skip lifecycle without profile symbol=",
                  symbol," position=",positionId,
                  " order=",trans.order);
            return;
           }

         STB_AdaptiveRememberPositionProfile(positionId,profileId);

         // Start with the planned risk captured when the pending order was
         // created, then prefer risk recalculated from the actual filled position
         // (fill price, filled volume and active initial SL) when it is available.
         double riskMoney=STB_AdaptiveReadOrderRisk(trans.order);
         if(PositionSelectByTicket(trans.position))
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
               double actualRiskMoney=0.0;

               if(OrderCalcProfit(calcType,symbol,positionVolume,
                                  entryPrice,initialSL,actualRiskMoney))
                 {
                  actualRiskMoney=MathAbs(actualRiskMoney);
                  if(actualRiskMoney>0.0 &&
                     MathIsValidNumber(actualRiskMoney))
                     riskMoney=actualRiskMoney;
                 }
              }
           }

         if(riskMoney>0.0)
            STB_AdaptiveRememberPositionRisk(positionId,riskMoney);

         STB_AdaptiveDeleteOrderState(trans.order);
        }
     }

   if(isHedge)
      return;

   if(entryType!=DEAL_ENTRY_OUT &&
      entryType!=DEAL_ENTRY_OUT_BY &&
      entryType!=DEAL_ENTRY_INOUT)
      return;

   double dealPnl=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+
                  HistoryDealGetDouble(trans.deal,DEAL_SWAP)+
                  HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+
                  HistoryDealGetDouble(trans.deal,DEAL_FEE);

   int originalDirection=0;
   int profileId=STB_AdaptiveReadPositionProfile(positionId);

   if(entryType==DEAL_ENTRY_INOUT)
     {
      long newType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);

      if(newType==DEAL_TYPE_BUY)
         originalDirection=-1;
      else
         if(newType==DEAL_TYPE_SELL)
            originalDirection=1;

      double priorPnl=GetAccumulatedPositionPnl(positionId);
      TakeAccumulatedPositionPnl(positionId);

      if(originalDirection!=0)
        {
         double lifecyclePnl=priorPnl+dealPnl;
         double riskMoney=STB_AdaptiveReadPositionRisk(positionId);
         double rMultiple=(riskMoney>0.0 ? lifecyclePnl/riskMoney:0.0);

         STB_AdaptiveRecordClosedDeal(symbol,
                                      originalDirection,
                                      lifecyclePnl,
                                      profileId,
                                      rMultiple,
                                      riskMoney>0.0 && MathIsValidNumber(riskMoney));
        }

      STB_AdaptiveDeletePositionProfile(positionId);
      STB_AdaptiveDeletePositionRisk(positionId);
      return;
     }

   double cumulative=dealPnl;

   if(positionId>0)
      cumulative+=GetAccumulatedPositionPnl(positionId);

   if(positionId>0)
      SetAccumulatedPositionPnl(positionId,cumulative);

   bool positionStillOpen=IsPositionIdentifierOpen(positionId);

   if(positionStillOpen)
      return;

   cumulative=TakeAccumulatedPositionPnl(positionId);

   if(positionId>0 && HistorySelectByPosition(positionId))
     {
      int deals=HistoryDealsTotal();

      for(int j=0;j<deals;j++)
        {
         ulong d=HistoryDealGetTicket(j);

         if(d==0)
            continue;

         long e=HistoryDealGetInteger(d,DEAL_ENTRY);

         if(e!=DEAL_ENTRY_IN)
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

   if(originalDirection==0)
     {
      long closedType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);
      originalDirection=(closedType==DEAL_TYPE_SELL ? 1:-1);
     }

   double riskMoney=STB_AdaptiveReadPositionRisk(positionId);
   double rMultiple=(riskMoney>0.0 ? cumulative/riskMoney:0.0);

   STB_AdaptiveRecordClosedDeal(symbol,
                                originalDirection,
                                cumulative,
                                profileId,
                                rMultiple,
                                riskMoney>0.0 && MathIsValidNumber(riskMoney));

   STB_AdaptiveDeletePositionProfile(positionId);
   STB_AdaptiveDeletePositionRisk(positionId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ToggleDashboard()
  {
   g_dashHidden=!g_dashHidden;

   if(g_dashHidden)
     {
      g_dashboardLastAction="DASHBOARD HIDDEN";
      STB_DashDeleteAll();
     }
   else
     {
      g_dashboardLastAction="DASHBOARD SHOWN";
      UpdatePanel();
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id==CHARTEVENT_KEYDOWN)
     {
      if(lparam==68 || lparam==100)
        {
         STB_ToggleDashboard();
         return;
        }
     }

   if(id==CHARTEVENT_CHART_CHANGE) return; // P6 STB-CLEANUP: no rebuild/redraw on chart change










   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   string buyName=g_prefix+"BUY_STOP";
   string sellName=g_prefix+"SELL_STOP";
   string autoName=g_prefix+"AUTO";
   string saveName=g_prefix+"SAVE20";
   string hedgeName=g_prefix+"HEDGE";
   string sellLimitName=g_prefix+"SELL_LIMIT";
   string buyLimitName=g_prefix+"BUY_LIMIT";
   string trailName=g_prefix+"PEND_TRAIL";

   if(sparam==buyName)
     {
      bool ok=PlaceManualPendingDirection(1);
      g_dashboardLastAction=(ok ? "BUY STOP ACCEPTED" :
                             "BUY STOP REJECTED");
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }

   if(sparam==sellName)
     {
      bool ok=PlaceManualPendingDirection(-1);
      g_dashboardLastAction=(ok ? "SELL STOP ACCEPTED" :
                             "SELL STOP REJECTED");
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }

   if(sparam==autoName)
     {
      g_autoTrading=!g_autoTrading;
      GlobalVariableSet(g_autoStateName,g_autoTrading ? 1.0 : 0.0);

      // Manual overrides are released ONLY when AUTO is explicitly enabled.
      // Turning AUTO OFF must not erase a user's persisted per-ticket authority.
      if(g_autoTrading)
         STB_ManualOverrideClearAll();

      g_dashboardLastAction=(g_autoTrading ?
                             "AUTO TRADING ENABLED" :
                             "AUTO TRADING DISABLED");

      UpdateButtons();
      UpdatePanel();

      Print("STB AUTO TRADING = ",
            (g_autoTrading ? "ON":"OFF"));
      return;
     }

   if(sparam==saveName)
     {
      ManualSavePlus20();
      g_dashboardLastAction="SAVE +20 PIPS COMMAND SENT";
      UpdateButtons();
      UpdatePanel();
      return;
     }

   if(sparam==hedgeName)
     {
      bool ok=OneClickHedge();
      g_dashboardLastAction=(ok ? "HEDGE ACCEPTED" :
                             "HEDGE REJECTED");
      UpdateButtons();
      UpdatePanel();
      return;
     }

   if(sparam==sellLimitName)
     {
      bool ok=PlaceManualLimitDirection(-1);
      g_dashboardLastAction=(ok ? "SELL LIMIT ACCEPTED" :
                             "SELL LIMIT REJECTED");
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }

   if(sparam==buyLimitName)
     {
      bool ok=PlaceManualLimitDirection(1);
      g_dashboardLastAction=(ok ? "BUY LIMIT ACCEPTED" :
                             "BUY LIMIT REJECTED");
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }
   if(sparam==trailName)
     {
      int moved=TrailAllPendingOrdersNow();
      g_dashboardLastAction="PENDING TRAIL MOVED "+
                            IntegerToString(moved)+" ORDER(S)";
      Print("STB PEND TRAIL button moved=",IntegerToString(moved),
            " pending=",IntegerToString(CountManagedPendingOrders()));
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }
  }
//+------------------------------------------------------------------+
