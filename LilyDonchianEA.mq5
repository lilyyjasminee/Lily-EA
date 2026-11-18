//+------------------------------------------------------------------+
//|                                              LilyDonchianEA.mq5  |
//|              Donchian Breakout 20/10 + SL ATR - untuk Thalib     |
//|  v1.10: tambah SL 2x ATR(14) + lot otomatis dari risiko %.       |
//|  BUY saat close > tertinggi 20 bar; SELL saat close < terendah   |
//|  20 bar. Keluar saat close < terendah 10 bar (long) / close >    |
//|  tertinggi 10 bar (short), atau kena SL.                         |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.10"
#property description "Donchian 20/10 + SL 2xATR, lot dari risiko %. Sinyal H1."

#include <Trade\Trade.mqh>
CTrade trade;

input group "Donchian"
input int      InpEntryPeriod = 20;        // Periode channel entry
input int      InpExitPeriod  = 10;        // Periode channel exit
input ENUM_TIMEFRAMES InpTF   = PERIOD_H1; // Timeframe sinyal
input group "Stop Loss ATR"
input int      InpAtrPeriod = 14;          // Periode ATR
input double   InpAtrMult   = 2.0;         // SL = mult x ATR
input group "Risiko & Order"
input double   InpRiskPct     = 2.0;       // Risiko per trade (% equity)
input long     InpMaxSpreadPts= 40;        // Spread maksimal (point)
input int      InpMagic       = 20261025;  // Magic number

int      gAtr = INVALID_HANDLE;
datetime gLastBar = 0;

//+------------------------------------------------------------------+
bool NewBar()
{
   datetime t = iTime(_Symbol, InpTF, 0);
   if(t != gLastBar) { gLastBar = t; return true; }
   return false;
}
//+------------------------------------------------------------------+
double ArrMax(const double &a[])
{
   double m = a[0];
   for(int i = 1; i < ArraySize(a); i++) if(a[i] > m) m = a[i];
   return m;
}
double ArrMin(const double &a[])
{
   double m = a[0];
   for(int i = 1; i < ArraySize(a); i++) if(a[i] < m) m = a[i];
   return m;
}
//+------------------------------------------------------------------+
double CalcLot(double slDistPrice)
{
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPct / 100.0;
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSize <= 0 || slDistPrice <= 0) return 0;
   double lossPerLot = slDistPrice / tickSize * tickVal;
   double lot = riskMoney / lossPerLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   if(lot < minLot)
   {
      Print("LilyDonchianEA: lot hitungan ", DoubleToString(lot, 4),
            " < lot minimum broker. Tambah modal dulu ya, Thalib!");
      return 0;
   }
   lot = MathFloor(lot / step) * step;
   return NormalizeDouble(MathMin(lot, maxLot), 2);
}
//+------------------------------------------------------------------+
bool HasPos(int &dir)
{
   dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
         return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
void CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic)
         trade.PositionClose(tk);
   }
}
//+------------------------------------------------------------------+
int OnInit()
{
   gAtr = iATR(_Symbol, InpTF, InpAtrPeriod);
   if(gAtr == INVALID_HANDLE) { Print("LilyDonchianEA: gagal buat handle ATR!"); return INIT_FAILED; }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   Print("LilyDonchianEA v1.10 jalan! Donchian+SL ", InpAtrMult, "xATR, risiko ",
         DoubleToString(InpRiskPct, 1), "%. Semangat Thalib!");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnTick()
{
   if(!NewBar()) return;

   double hhE[], llE[], hhX[], llX[], cc[], av[];
   ArraySetAsSeries(hhE, true); ArraySetAsSeries(llE, true);
   ArraySetAsSeries(hhX, true); ArraySetAsSeries(llX, true);
   ArraySetAsSeries(cc, true);  ArraySetAsSeries(av, true);
   if(CopyHigh(_Symbol, InpTF, 2, InpEntryPeriod, hhE) < InpEntryPeriod) return;
   if(CopyLow (_Symbol, InpTF, 2, InpEntryPeriod, llE) < InpEntryPeriod) return;
   if(CopyHigh(_Symbol, InpTF, 2, InpExitPeriod, hhX)  < InpExitPeriod)  return;
   if(CopyLow (_Symbol, InpTF, 2, InpExitPeriod, llX)  < InpExitPeriod)  return;
   if(CopyClose(_Symbol, InpTF, 1, 1, cc) < 1) return;
   if(CopyBuffer(gAtr, 0, 1, 1, av) < 1) return;

   double hi20 = ArrMax(hhE), lo20 = ArrMin(llE);
   double hi10 = ArrMax(hhX), lo10 = ArrMin(llX);
   double close1 = cc[0];
   double slDist  = InpAtrMult * av[0];
   if(slDist <= 0) return;

   if((long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPts) return;

   int dir = 0;
   bool have = HasPos(dir);

   //--- exit sinyal dulu
   if(have && dir == 1 && close1 < lo10)
   {
      CloseAll();
      Print("LilyDonchianEA: tutup BUY (close < terendah 10 bar).");
      have = false;
   }
   else if(have && dir == -1 && close1 > hi10)
   {
      CloseAll();
      Print("LilyDonchianEA: tutup SELL (close > tertinggi 10 bar).");
      have = false;
   }

   //--- entry dengan SL ATR
   if(!have)
   {
      double lot = CalcLot(slDist);
      if(lot <= 0) return;  // sudah ada pesan (mis. modal kurang)
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(close1 > hi20)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl  = NormalizeDouble(ask - slDist, digits);
         if(trade.Buy(lot, _Symbol, 0, sl, 0, "Donchian+SL BUY"))
            Print("LilyDonchianEA: BUY ", DoubleToString(lot, 2), " lot, SL=",
                  DoubleToString(sl, digits), ". Semangat Thalib!");
      }
      else if(close1 < lo20)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl  = NormalizeDouble(bid + slDist, digits);
         if(trade.Sell(lot, _Symbol, 0, sl, 0, "Donchian+SL SELL"))
            Print("LilyDonchianEA: SELL ", DoubleToString(lot, 2), " lot, SL=",
                  DoubleToString(sl, digits), ". Semangat Thalib!");
      }
   }
}
//+------------------------------------------------------------------+
