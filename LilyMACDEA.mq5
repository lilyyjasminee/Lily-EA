//+------------------------------------------------------------------+
//|                                                LilyMACDEA.mq5    |
//|                   MACD Cross (12,26,9) + SL ATR - untuk Thalib   |
//|  v1.10: tambah SL 2x ATR(14) + lot otomatis dari risiko %.       |
//|  Selalu di pasar: BUY saat MACD nyalip ke ATAS; SELL saat       |
//|  nyalip ke BAWAH.                                              |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.10"
#property description "MACD(12,26,9) cross + SL 2xATR, lot dari risiko %. Sinyal H1."

#include <Trade\Trade.mqh>
CTrade trade;

input group "MACD"
input int      InpFastEMA = 12;            // EMA cepat
input int      InpSlowEMA = 26;            // EMA lambat
input int      InpSignal  = 9;             // Periode sinyal
input ENUM_TIMEFRAMES InpTF = PERIOD_H1;   // Timeframe sinyal
input group "Stop Loss ATR"
input int      InpAtrPeriod = 14;          // Periode ATR
input double   InpAtrMult   = 2.0;         // SL = mult x ATR
input group "Risiko & Order"
input double   InpRiskPct     = 2.0;       // Risiko per trade (% equity)
input long     InpMaxSpreadPts= 40;        // Spread maksimal (point)
input int      InpMagic       = 20261026;  // Magic number

int      gMacd = INVALID_HANDLE;
int      gAtr  = INVALID_HANDLE;
datetime gLastBar = 0;

//+------------------------------------------------------------------+
bool NewBar()
{
   datetime t = iTime(_Symbol, InpTF, 0);
   if(t != gLastBar) { gLastBar = t; return true; }
   return false;
}
//+------------------------------------------------------------------+
double CalcLot(double slDistPrice)
{
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPct / 100.0;
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSize <= 0 || slDistPrice <= 0) return 0;
   double lossPerLot = slDistPrice / tickSize * tickVal; // rugi per 1.0 lot
   double lot = riskMoney / lossPerLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;
   if(lot < minLot)
   {
      Print("LilyMACDEA: lot hitungan ", DoubleToString(lot, 4),
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
   gMacd = iMACD(_Symbol, InpTF, InpFastEMA, InpSlowEMA, InpSignal, PRICE_CLOSE);
   gAtr  = iATR(_Symbol, InpTF, InpAtrPeriod);
   if(gMacd == INVALID_HANDLE || gAtr == INVALID_HANDLE)
   {
      Print("LilyMACDEA: gagal buat handle indikator!");
      return INIT_FAILED;
   }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(30);
   Print("LilyMACDEA v1.10 jalan! MACD+SL ", InpAtrMult, "xATR, risiko ",
         DoubleToString(InpRiskPct, 1), "%. Semangat Thalib!");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnTick()
{
   if(!NewBar()) return;

   double main[], sigl[], av[];
   ArraySetAsSeries(main, true); ArraySetAsSeries(sigl, true); ArraySetAsSeries(av, true);
   if(CopyBuffer(gMacd, 0, 1, 3, main) < 3) return;
   if(CopyBuffer(gMacd, 1, 1, 3, sigl) < 3) return;
   if(CopyBuffer(gAtr, 0, 1, 1, av) < 1)    return;

   bool bullCross = (main[0] > sigl[0]) && (main[1] <= sigl[1]);
   bool bearCross = (main[0] < sigl[0]) && (main[1] >= sigl[1]);
   if(!bullCross && !bearCross) return;
   if((long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPts) return;

   double slDist = InpAtrMult * av[0];
   if(slDist <= 0) return;
   double lot = CalcLot(slDist);
   if(lot <= 0) return;  // sudah ada pesan (mis. modal kurang)

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int dir = 0;
   bool have = HasPos(dir);

   if(bullCross && dir != 1)
   {
      if(have) CloseAll();
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = NormalizeDouble(ask - slDist, digits);
      if(trade.Buy(lot, _Symbol, 0, sl, 0, "MACD+SL bull"))
         Print("LilyMACDEA: BUY ", DoubleToString(lot, 2), " lot, SL=", DoubleToString(sl, digits),
               ". Semangat Thalib!");
   }
   else if(bearCross && dir != -1)
   {
      if(have) CloseAll();
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = NormalizeDouble(bid + slDist, digits);
      if(trade.Sell(lot, _Symbol, 0, sl, 0, "MACD+SL bear"))
         Print("LilyMACDEA: SELL ", DoubleToString(lot, 2), " lot, SL=", DoubleToString(sl, digits),
               ". Semangat Thalib!");
   }
}
//+------------------------------------------------------------------+
