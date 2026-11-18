//+------------------------------------------------------------------+
//|                                                     LilyORBEA.mq5|
//|                                    Dibuat Lily untuk Thalib      |
//|                                                                  |
//|  STRATEGI: Opening Range Breakout (ORB) sesi Tokyo               |
//|                                                                  |
//|  CARA KERJA (jam WIB — dihitung dari TimeGMT()+7, anti DST):     |
//|  1. 07:00-08:00 WIB : bentuk KOTAK (high/low 2 bar M30 pertama    |
//|     sesi Tokyo). Kotak terlalu sempit -> skip hari ini.          |
//|  2. 08:00-13:00 WIB : pasang BuyStop di atas kotak & SellStop    |
//|     di bawah kotak (salah satu kefill -> yang lain dihapus).     |
//|     SL = sisi berlawanan kotak, TP = lebar kotak x RR.           |
//|  3. Posisi tutup (SL/TP) -> boleh entry lagi selama jumlah       |
//|     trade hari ini < InpMaxTrades.                               |
//|  4. 13:00 WIB       : tutup semua posisi & hapus order (flat).   |
//|                                                                  |
//|  Hasil backtest 1 tahun (JP225 H1, tick-faithful):               |
//|  - Maks 1 trade/hari : 227 trade, PF 1.11, +7R, max DD -8R       |
//|  - Maks 10 trade/hari: 274 trade, PF 1.10, +7R, max DD -8R       |
//|    (trade tambahan hasilnya netral — tidak merusak strategi)     |
//|  BUKAN janji profit — forward test di demo dulu ya Thalib!       |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.10"

#include <Trade\Trade.mqh>
CTrade trade;

//================ INPUT ================
input group "Waktu (WIB)"
input int    InpRangeStartH = 7;     // Jam mulai kotak (WIB)
input int    InpRangeEndH   = 8;     // Jam selesai kotak (WIB)
input int    InpFlatH       = 13;    // Jam flat/tutup semua (WIB)

input group "Kotak & Entry"
input double InpMinRangePct = 0.15;  // Lebar kotak minimal (% harga)
input double InpRR          = 1.5;   // TP = lebar kotak x RR
input long   InpMaxSpreadPts= 40;    // Spread maksimal (point) saat pasang order
input int    InpMaxTrades   = 10;    // Maksimal trade per hari

input group "Risiko"
input double InpRiskPct  = 2.0;      // Risiko per trade (% equity)
input int    InpSlippage = 30;       // Slippage (point)
input int    InpMagic    = 20261023; // Magic Number

//================ STATE HARIAN ================
string   g_dayKey      = "";    // kunci hari (YYYY.MM.DD WIB)
double   g_rangeHigh   = 0;
double   g_rangeLow    = 0;
bool     g_rangeOK     = false;
bool     g_ordersIn    = false;   // pending order sedang terpasang
bool     g_doneToday   = false;   // selesai untuk hari ini
int      g_tradesToday = 0;       // jumlah posisi yang sudah kefill hari ini
bool     g_fillCounted = false;   // fill pada ronde order ini sudah dihitung?

//+------------------------------------------------------------------+
//| Jam WIB saat ini (dari TimeGMT + 7 jam; WIB tidak punya DST)     |
//+------------------------------------------------------------------+
datetime WibNow()
  {
   datetime gmt = TimeGMT();
   if(gmt == 0)
      gmt = TimeCurrent();   // fallback bila GMT belum sinkron
   return(gmt + 7*3600);
  }

//+------------------------------------------------------------------+
//| Ubah waktu bar (server) menjadi WIB                              |
//+------------------------------------------------------------------+
datetime BarToWib(datetime barTime)
  {
   datetime gmt = TimeGMT();
   if(gmt == 0)
      return(barTime);
   datetime serverOff = TimeTradeServer() - gmt;
   return(barTime - serverOff + 7*3600);
  }

//+------------------------------------------------------------------+
//| Kunci hari dari waktu WIB (untuk reset harian)                   |
//+------------------------------------------------------------------+
string DayKey(datetime wib)
  {
   MqlDateTime dt;
   TimeToStruct(wib, dt);
   return(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
  }

//+------------------------------------------------------------------+
//| Bentuk kotak dari bar M30 yang WIB-nya di dalam jendela range     |
//+------------------------------------------------------------------+
bool BuildRange()
  {
   g_rangeHigh = 0; g_rangeLow = 0;
   int bars = 60;
   datetime t[];
   double   hi[], lo[];
   if(CopyTime(_Symbol, PERIOD_M30, 0, bars, t) < bars) return(false);
   if(CopyHigh(_Symbol, PERIOD_M30, 0, bars, hi) < bars) return(false);
   if(CopyLow (_Symbol, PERIOD_M30, 0, bars, lo) < bars) return(false);

   string today = DayKey(WibNow());
   for(int i = 0; i < bars; i++)
     {
      datetime w = BarToWib(t[i]);
      if(DayKey(w) != today) continue;
      MqlDateTime dt; TimeToStruct(w, dt);
      if(dt.hour >= InpRangeStartH && dt.hour < InpRangeEndH)
        {
         if(g_rangeLow == 0 || lo[i] < g_rangeLow) g_rangeLow = lo[i];
         if(hi[i] > g_rangeHigh) g_rangeHigh = hi[i];
        }
     }
   if(g_rangeLow == 0 || g_rangeHigh <= g_rangeLow) return(false);

   double width = g_rangeHigh - g_rangeLow;
   double px    = (g_rangeHigh + g_rangeLow) / 2.0;
   if(width < px * InpMinRangePct / 100.0)
     {
      Print("Kotak terlalu sempit (", DoubleToString(width/_Point, 1),
            " point) -> skip hari ini.");
      return(false);
     }
   Print("Kotak hari ini: High=", DoubleToString(g_rangeHigh, _Digits),
         " Low=", DoubleToString(g_rangeLow, _Digits),
         " Lebar=", DoubleToString(width/_Point, 1), " point");
   return(true);
  }

//+------------------------------------------------------------------+
//| Hitung lot dari risiko % berdasarkan jarak SL                    |
//+------------------------------------------------------------------+
double CalcLot(double slPoints)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) equity = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double vMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vStep= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vStep <= 0) vStep = 0.01;
   if(tickVal <= 0 || tickSize <= 0 || slPoints <= 0 || equity <= 0) return(0);
   double lots = (equity * InpRiskPct / 100.0) / (slPoints * _Point / tickSize * tickVal);
   lots = MathFloor(lots / vStep) * vStep;
   lots = MathMax(vMin, MathMin(vMax, lots));
   return(NormalizeDouble(lots, 2));
  }

//+------------------------------------------------------------------+
//| Hapus pending order milik EA                                      |
//+------------------------------------------------------------------+
void DeletePendings()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagic) continue;
      trade.OrderDelete(tk);
     }
  }

//+------------------------------------------------------------------+
//| Tutup semua posisi milik EA                                      |
//+------------------------------------------------------------------+
void CloseAll()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic) continue;
      trade.PositionClose(tk);
     }
  }

//+------------------------------------------------------------------+
//| Apakah ada posisi terbuka milik EA?                              |
//+------------------------------------------------------------------+
bool HasPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Pasang sepasang pending order (BuyStop + SellStop)               |
//+------------------------------------------------------------------+
bool PlaceOrders()
  {
   long spr = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spr > InpMaxSpreadPts)
     {
      Print("Spread kemahalan (", spr, " point) -> tunggu tick berikutnya.");
      return(false);
     }
   double width = g_rangeHigh - g_rangeLow;
   double slPts = width / _Point;
   double lots  = CalcLot(slPts);
   if(lots <= 0)
     {
      Print("Lot tidak valid -> skip hari ini.");
      g_doneToday = true;
      return(true);
     }

   double tpDist = width * InpRR;
   double buySL  = NormalizeDouble(g_rangeLow, _Digits);
   double buyTP  = NormalizeDouble(g_rangeHigh + tpDist, _Digits);
   double sellSL = NormalizeDouble(g_rangeHigh, _Digits);
   double sellTP = NormalizeDouble(g_rangeLow - tpDist, _Digits);

   bool okB = trade.BuyStop(lots, NormalizeDouble(g_rangeHigh, _Digits), _Symbol,
                            buySL, buyTP, ORDER_TIME_GTC, 0, "LilyORB-BUYSTOP");
   bool okS = trade.SellStop(lots, NormalizeDouble(g_rangeLow, _Digits), _Symbol,
                             sellSL, sellTP, ORDER_TIME_GTC, 0, "LilyORB-SELLSTOP");
   if(okB || okS)
     {
      g_ordersIn = true;
      g_fillCounted = false;
      Print("Pending order dipasang (trade ke-", g_tradesToday + 1,
            "): BuyStop@", DoubleToString(g_rangeHigh, _Digits),
            " SellStop@", DoubleToString(g_rangeLow, _Digits), " lot=", lots);
      return(true);
     }
   Print("Gagal pasang pending order: ", trade.ResultRetcodeDescription());
   g_doneToday = true;
   return(true);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   Print("LilyORBEA jalan! Semangat Thalib!");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime wib = WibNow();
   string   key = DayKey(wib);
   MqlDateTime dt; TimeToStruct(wib, dt);
   int hour = dt.hour;

   //--- reset harian
   if(key != g_dayKey)
     {
      g_dayKey      = key;
      g_rangeOK     = false;
      g_ordersIn    = false;
      g_doneToday   = false;
      g_tradesToday = 0;
      g_fillCounted = false;
      DeletePendings();
     }

   //--- jam flat: tutup semua & selesai hari ini
   if(hour >= InpFlatH)
     {
      if(HasPosition()) CloseAll();
      DeletePendings();
      g_ordersIn = false;
      g_doneToday = true;
      return;
     }

   if(g_doneToday) return;

   //--- jendela bentuk kotak
   if(hour >= InpRangeStartH && hour < InpRangeEndH)
     {
      if(!g_rangeOK)
        {
         if(BuildRange()) g_rangeOK = true;
         else g_doneToday = true;   // kotak gagal/sempit -> skip
        }
      return;
     }

   //--- jendela trading: kotak harus sudah jadi
   if(hour < InpRangeEndH) return;  // belum waktunya
   if(!g_rangeOK)
     {
      if(!BuildRange()) { g_doneToday = true; return; }
      g_rangeOK = true;
     }

   //--- kelola posisi & fill
   if(HasPosition())
     {
      if(!g_fillCounted)
        {
         g_tradesToday++;
         g_fillCounted = true;
         DeletePendings();   // OCO: hapus order satunya
         g_ordersIn = false;
         Print("Posisi terbuka (trade ke-", g_tradesToday, " hari ini)! Semangat Thalib!");
        }
      return;   // tunggu posisi tutup (SL/TP)
     }

   //--- posisi barusan tutup? siapkan ronde berikutnya
   if(g_fillCounted)
     {
      g_fillCounted = false;
      g_ordersIn = false;
      if(g_tradesToday >= InpMaxTrades)
        {
         g_doneToday = true;
         Print("Sudah ", g_tradesToday, " trade hari ini (batas maksimum) -> selesai.");
         return;
        }
      Print("Posisi tutup. Boleh entry lagi (", g_tradesToday, "/", InpMaxTrades, ").");
     }

   //--- pasang pending order bila belum ada
   if(!g_ordersIn)
      PlaceOrders();
  }
//+------------------------------------------------------------------+
