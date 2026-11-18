//+------------------------------------------------------------------+
//|                                              LilyConfluenceEA.mq5|
//|                                          Dibuat Lily untuk Thalib|
//|                                                                  |
//|  STRATEGI GABUNGAN:                                              |
//|  1. MA Crossover (EMA 9 x EMA 21) = penentu ARAH & sinyal entry   |
//|  2. Support/Resistance + Supply/Demand = penentu LOKASI entry     |
//|     Zona dihitung otomatis dari swing high/low N bar terakhir.    |
//|     (Catatan jujur: ini versi sederhananya SnR/SnD — robot tidak |
//|      bisa "membaca" chart seperti manusia, jadi dipakai pendekatan|
//|      zona dari titik-titik swing yang terkonfirmasi.)             |
//|                                                                  |
//|  ATURAN ENTRY:                                                   |
//|  - BELI  : bull cross + harga dekat zona support/demand          |
//|  - JUAL  : bear cross + harga dekat zona resistance/supply        |
//|  - Satu posisi dalam satu waktu, risiko 2% per trade             |
//|  - SL = 1.5 x ATR, TP = 2 x SL                                   |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//================ INPUT: Moving Average ================
input group "Moving Average (Arah & Sinyal)"
input int           InpMAFast   = 9;           // MA Cepat
input int           InpMASlow   = 21;          // MA Lambat
input ENUM_MA_METHOD InpMAMethod = MODE_EMA;   // Metode MA

//================ INPUT: Zona SnR / SnD ================
input group "Support Resistance & Supply Demand (Lokasi)"
input int    InpLookback   = 50;    // Bar untuk mencari zona
input int    InpSwing      = 3;     // Kekuatan swing (bar kiri-kanan)
input double InpZoneTolATR = 0.5;   // Toleransi zona (x ATR)

//================ INPUT: Risiko ================
input group "Manajemen Risiko"
input int    InpATRPeriod = 14;     // Periode ATR
input double InpSL_ATR    = 1.5;    // SL = x ATR
input double InpRiskPct   = 2.0;    // Risiko per trade (% saldo)
input double InpRR        = 2.0;    // Risk:Reward -> TP = RR x SL

//================ INPUT: Umum ================
input group "Umum"
input int InpMagic = 20261019;      // Magic Number

//================ GLOBAL ================
int      hMAFast, hMASlow, hATR;
datetime g_lastBar = 0;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   hMAFast = iMA(_Symbol, PERIOD_CURRENT, InpMAFast, 0, InpMAMethod, PRICE_CLOSE);
   hMASlow = iMA(_Symbol, PERIOD_CURRENT, InpMASlow, 0, InpMAMethod, PRICE_CLOSE);
   hATR    = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(hMAFast == INVALID_HANDLE || hMASlow == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      Print("Gagal membuat indicator handle!");
      return INIT_FAILED;
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(10);
   Print("LilyConfluenceEA jalan! Semangat Thalib!");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Ambil 1 nilai indicator pada bar tertentu                        |
//+------------------------------------------------------------------+
bool GetInd(int handle, int shift, double &val)
  {
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1)
      return false;
   val = buf[0];
   return true;
  }

//+------------------------------------------------------------------+
//| Cek apakah ini bar baru (EA hanya proses tiap bar baru)          |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t != g_lastBar)
     {
      g_lastBar = t;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Hitung zona support (demand) & resistance (supply) dari swing    |
//+------------------------------------------------------------------+
void GetZones(double &supports[], double &resists[])
  {
   ArrayResize(supports, 0);
   ArrayResize(resists, 0);

   int need = InpLookback + InpSwing + 2;
   double high[], low[];
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, need, high) < need)
      return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 1, need, low) < need)
      return;

   // high[0] = bar 1 (bar closed terbaru). Cari swing terkonfirmasi.
   for(int i = InpSwing; i < InpLookback; i++)
     {
      bool isHigh = true, isLow = true;
      for(int k = 1; k <= InpSwing; k++)
        {
         if(high[i] < high[i - k] || high[i] < high[i + k])
            isHigh = false;
         if(low[i] > low[i - k] || low[i] > low[i + k])
            isLow = false;
        }
      if(isHigh)
        {
         int s = ArraySize(resists);
         ArrayResize(resists, s + 1);
         resists[s] = high[i];   // resistance = zona supply
        }
      if(isLow)
        {
         int s = ArraySize(supports);
         ArrayResize(supports, s + 1);
         supports[s] = low[i];   // support = zona demand
        }
     }
  }

//+------------------------------------------------------------------+
//| Apakah harga dekat salah satu zona?                              |
//+------------------------------------------------------------------+
bool NearZone(const double &zones[], double price, double tol)
  {
   for(int i = 0; i < ArraySize(zones); i++)
      if(MathAbs(price - zones[i]) <= tol)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
//| Hitung volume dari risiko % saldo                                |
//+------------------------------------------------------------------+
double CalcVolume(double slPoints)
  {
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double volMin   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volMax   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickVal <= 0 || tickSize <= 0 || slPoints <= 0 || balance <= 0)
      return 0;

   double riskMoney = balance * InpRiskPct / 100.0;
   double vol = riskMoney / (slPoints * _Point / tickSize * tickVal);
   vol = MathFloor(vol / volStep) * volStep;
   vol = MathMax(volMin, MathMin(volMax, vol));
   return NormalizeDouble(vol, 2);
  }

//+------------------------------------------------------------------+
//| Apakah ada posisi terbuka milik EA ini?                          |
//+------------------------------------------------------------------+
bool HasPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!IsNewBar())
      return;                 // proses hanya tiap bar baru
   if(HasPosition())
      return;                 // satu posisi dalam satu waktu

   double f1, f2, s1, s2, atr;
   if(!GetInd(hMAFast, 1, f1) || !GetInd(hMAFast, 2, f2))
      return;
   if(!GetInd(hMASlow, 1, s1) || !GetInd(hMASlow, 2, s2))
      return;
   if(!GetInd(hATR, 1, atr) || atr <= 0)
      return;

   // Sinyal crossover pada bar yang sudah close
   bool bullCross = (f2 <= s2 && f1 > s1);
   bool bearCross = (f2 >= s2 && f1 < s1);
   if(!bullCross && !bearCross)
      return;

   // Zona support/demand & resistance/supply
   double supports[], resists[];
   GetZones(supports, resists);
   double tol = atr * InpZoneTolATR;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDist = atr * InpSL_ATR;
   double slPts  = slDist / _Point;
   double vol    = CalcVolume(slPts);
   if(vol <= 0)
     {
      Print("Volume tidak valid, trade dibatalkan.");
      return;
     }

   if(bullCross)
     {
      // BELI: tren naik (bull cross) + harga dekat zona demand/support
      if(!NearZone(supports, ask, tol))
         return;   // lokasi tidak bagus -> lewati
      double sl = NormalizeDouble(ask - slDist, _Digits);
      double tp = NormalizeDouble(ask + slDist * InpRR, _Digits);
      if(!trade.Buy(vol, _Symbol, ask, sl, tp, "LilyEA-BUY"))
         Print("Buy gagal: ", trade.ResultRetcodeDescription());
      else
         Print("BUY dibuka @ ", ask, " | SL ", sl, " | TP ", tp);
     }
   else if(bearCross)
     {
      // JUAL: tren turun (bear cross) + harga dekat zona supply/resistance
      if(!NearZone(resists, bid, tol))
         return;   // lokasi tidak bagus -> lewati
      double sl = NormalizeDouble(bid + slDist, _Digits);
      double tp = NormalizeDouble(bid - slDist * InpRR, _Digits);
      if(!trade.Sell(vol, _Symbol, bid, sl, tp, "LilyEA-SELL"))
         Print("Sell gagal: ", trade.ResultRetcodeDescription());
      else
         Print("SELL dibuka @ ", bid, " | SL ", sl, " | TP ", tp);
     }
  }
//+------------------------------------------------------------------+
