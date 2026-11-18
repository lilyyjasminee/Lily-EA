//+------------------------------------------------------------------+
//|                                                 LilyGotobiEA.mq5 |
//|                        Strategi Gotobi USDJPY - untuk Thalib     |
//|  SELL tepat 07:55 WIB hanya di tanggal 5/10/15/20/25/30,         |
//|  SL 10 pip, tutup otomatis 08:30 WIB (time stop)                  |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.00"
#property description "EA Gotobi: SELL 07:55 WIB di tgl 5/10/15/20/25/30, SL 10 pip, close 08:30 WIB"

#include <Trade\Trade.mqh>
CTrade trade;

//--- input
input double InpRiskPct       = 2.0;      // Risiko per trade (% dari equity)
input double InpSLPips        = 10.0;     // Stop Loss (pip)
input double InpMaxSpreadPips = 3.0;      // Spread maksimal saat entry (pip)
input int    InpMaxLateSec    = 60;       // Toleransi telat entry (detik)
input int    InpMagic         = 20261024; // Magic number

//--- jam WIB (broker GMT+0 -> WIB = GMT+7, tanpa DST)
int    gEntryHour = 7;
int    gEntryMin  = 55;   // 07:55 WIB
int    gExitHour  = 8;
int    gExitMin   = 30;   // 08:30 WIB
string gLastTradeDay = ""; // tanggal WIB terakhir entry (YYYYMMDD)

//+------------------------------------------------------------------+
double PipSize()
{
   int    d  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (d == 3 || d == 5) ? pt * 10.0 : pt;
}
//+------------------------------------------------------------------+
datetime WIBNow()
{
   return TimeGMT() + 7 * 3600;
}
//+------------------------------------------------------------------+
string WIBDayStr(datetime t)
{
   MqlDateTime s;
   TimeToStruct(t, s);
   return StringFormat("%04d%02d%02d", s.year, s.mon, s.day);
}
//+------------------------------------------------------------------+
bool IsGotobiDay(datetime t)
{
   MqlDateTime s;
   TimeToStruct(t, s);
   int d = s.day;
   return (d == 5 || d == 10 || d == 15 || d == 20 || d == 25 || d == 30);
}
//+------------------------------------------------------------------+
int SecsSinceMidnight(datetime t)
{
   MqlDateTime s;
   TimeToStruct(t, s);
   return s.hour * 3600 + s.min * 60 + s.sec;
}
//+------------------------------------------------------------------+
double CalcLot(double slPriceDist)
{
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPct / 100.0;
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0 || tickSize <= 0 || slPriceDist <= 0)
      return 0;

   double lossPerLot = slPriceDist / tickSize * tickVal;
   if(lossPerLot <= 0)
      return 0;

   double lot    = riskMoney / lossPerLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0)
      step = 0.01;
   lot = MathFloor(lot / step) * step;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return NormalizeDouble(lot, 2);
}
//+------------------------------------------------------------------+
bool HasOurPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return true;
   }
   return false;
}
//+------------------------------------------------------------------+
void CloseOurPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic)
         trade.PositionClose(tk);
   }
}
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(10);
   Print("LilyGotobiEA v1.00 jalan! SELL 07:55 WIB di tgl gotobi. Semangat Thalib!");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnTick()
{
   datetime wib    = WIBNow();
   int      nowSec = SecsSinceMidnight(wib);
   int      entrySec = gEntryHour * 3600 + gEntryMin * 60;
   int      exitSec  = gExitHour * 3600 + gExitMin * 60;
   string   dayStr   = WIBDayStr(wib);

   bool havePos = HasOurPosition();

   //--- 1) TIME STOP: tutup posisi jam 08:30 WIB
   if(havePos && nowSec >= exitSec)
   {
      CloseOurPositions();
      Print("LilyGotobiEA: time stop 08:30 WIB, posisi ditutup. Semangat Thalib!");
      return;
   }

   //--- 2) ENTRY: hanya tanggal gotobi, tepat 07:55 WIB (+toleransi)
   if(!havePos && IsGotobiDay(wib) && dayStr != gLastTradeDay &&
      nowSec >= entrySec && nowSec <= entrySec + InpMaxLateSec)
   {
      double pip        = PipSize();
      double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      long   spreadPts  = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double spreadPips = (point > 0 && pip > 0) ? spreadPts * point / pip : 99.0;

      if(spreadPips > InpMaxSpreadPips)
      {
         Print("LilyGotobiEA: spread ", DoubleToString(spreadPips, 1),
               " pip > batas ", DoubleToString(InpMaxSpreadPips, 1),
               ", skip hari ini biar aman.");
         gLastTradeDay = dayStr;
         return;
      }

      double slDist = InpSLPips * pip;
      double lot    = CalcLot(slDist);
      if(lot <= 0)
      {
         Print("LilyGotobiEA: hitungan lot tidak valid, skip.");
         gLastTradeDay = dayStr;
         return;
      }

      int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = NormalizeDouble(bid + slDist, dg);

      if(trade.Sell(lot, _Symbol, 0, sl, 0, "Gotobi 07:55 WIB"))
      {
         gLastTradeDay = dayStr;
         Print("LilyGotobiEA: SELL ", DoubleToString(lot, 2), " lot @ ",
               DoubleToString(bid, dg), " SL=", DoubleToString(sl, dg),
               ". Semangat Thalib!");
      }
      else
         Print("LilyGotobiEA: order gagal, retcode=", trade.ResultRetcode(),
               " (", trade.ResultRetcodeDescription(), ")");
   }
}
//+------------------------------------------------------------------+
