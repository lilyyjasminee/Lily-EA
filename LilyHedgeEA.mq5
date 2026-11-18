//+------------------------------------------------------------------+
//| LilyHedgeEA.mq5                                                  |
//| Hedging EA ala video TikTok: BUY + SELL STOP berpasangan         |
//| Dibuat oleh Lily untuk Thalib                                    |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.31"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Input parameter
input double InpLot            = 0.01;      // Lot per posisi (dipakai bila hitung risiko = false)
input bool   InpUseRiskPercent = true;     // Hitung lot otomatis dari risiko %
input double InpRiskPercent    = 2.0;       // Risiko per flip (% dari equity)
input int    InpTakeProfit     = 300;       // Take Profit (point, cth: 300 = $3 di XAUUSD)
input int    InpHedgeDistance  = 100;       // Jarak pending order hedge (point, cth: 100 = $1 di XAUUSD)
input int    InpMagic          = 20261020;  // Magic Number
input int    InpSlippage       = 30;        // Slippage (point)
//--- Filter confluence: MA + Support/Resistance + Supply/Demand
input bool   InpUseMAFilter    = true;      // Filter Moving Average (EMA 9/21)
input int    InpEMAFast        = 9;         // EMA cepat
input int    InpEMASlow        = 21;        // EMA lambat
input bool   InpUseZoneFilter  = true;      // Filter zona Support/Resistance & Supply/Demand
input int    InpSwingLookback  = 50;        // Cari swing ke belakang (bar)
input int    InpSwingStrength  = 3;         // Kekuatan fractal swing (bar kiri-kanan)
input double InpZoneATRMult    = 0.5;       // Toleransi zona (× ATR)
input int    InpATRPeriod      = 14;        // Periode ATR
//--- Proteksi profit: breakeven + trailing stop (biar profit nggak balik jadi loss)
input bool   InpUseBreakEven   = true;      // Aktifkan Break-Even
input int    InpBETTrigger     = 150;       // Profit pemicu break-even (point, cth: 150 = $1.5 di XAUUSD)
input int    InpBETOffset      = 10;        // SL break-even di entry +/- offset (point)
input bool   InpUseTrailing    = true;      // Aktifkan Trailing Stop
input int    InpTrailTrigger   = 200;       // Profit pemicu trailing (point, cth: 200 = $2 di XAUUSD)
input int    InpTrailDistance  = 100;       // Jarak trailing dari harga (point, cth: 100 = $1 di XAUUSD)
//--- Filter tren & pengaman frekuensi loss (biar nggak lebih sering loss)
input bool   InpUseADXFilter   = true;      // Filter ADX: entry hanya saat market trending
input int    InpADXPeriod      = 14;        // Periode ADX
input double InpADXMin         = 20.0;      // ADX minimal = market trending (hindari sideways)
input int    InpMaxSpreadPoints= 40;        // Spread maksimal untuk entry baru (point)
input bool   InpUseCircuitBreaker= false;    // Circuit breaker: jeda otomatis setelah loss beruntun (default MATI)
input int    InpMaxConsecLosses= 3;         // Circuit breaker: max loss beruntun
input int    InpPauseMinutes   = 60;        // Jeda otomatis setelah circuit breaker (menit)

//--- Status kaki strategi: 0=flat, 1=kaki BUY (BUY+SELLSTOP), 2=kaki SELL (SELL+BUYSTOP)
int g_leg=0;
//--- Lot aktual siklus berjalan (dihitung dari risiko %)
double g_lot=0;
//--- Circuit breaker & hasil siklus
double   g_cycleStartEquity=0;
int      g_consecLosses=0;
datetime g_pauseStart=0;
bool     g_inCycle=false;

//+------------------------------------------------------------------+
//| Tandai siklus dimulai (catat equity awal)                         |
//+------------------------------------------------------------------+
void CycleStart()
  {
   g_cycleStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_inCycle=true;
  }

//+------------------------------------------------------------------+
//| Evaluasi siklus yang baru selesai (profit / loss)                |
//+------------------------------------------------------------------+
void CycleEnd()
  {
   if(!g_inCycle) return;
   g_inCycle=false;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_cycleStartEquity>0)
     {
      double pnl=eq-g_cycleStartEquity;
      if(pnl<-0.0001)
        {
         g_consecLosses++;
         Print("Siklus selesai: rugi $",DoubleToString(pnl,2),". Loss beruntun: ",g_consecLosses,"x");
         if(g_consecLosses>=InpMaxConsecLosses)
           {
            g_pauseStart=TimeCurrent();
            Print("Circuit breaker: istirahat ",InpPauseMinutes," menit setelah ",g_consecLosses," loss beruntun.");
           }
        }
      else if(pnl>0.0001)
        {
         if(g_consecLosses>0) Print("Siklus selesai: profit $",DoubleToString(pnl,2),". Loss beruntun direset.");
         g_consecLosses=0;
        }
     }
   g_cycleStartEquity=0;
  }

//+------------------------------------------------------------------+
//| Cek apakah circuit breaker sedang aktif (masa jeda)              |
//+------------------------------------------------------------------+
bool CircuitBreakerActive()
  {
   if(!InpUseCircuitBreaker) return false; // dimatikan: EA tetap trading aktif
   if(g_consecLosses<InpMaxConsecLosses) return false;
   if(TimeCurrent()-g_pauseStart>=InpPauseMinutes*60)
     {
      g_consecLosses=0;
      Print("Jeda circuit breaker selesai. Trading dilanjut.");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Normalisasi lot ke step broker                                   |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
  {
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step  =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=0.01;
   lots=MathFloor(lots/step)*step;
   if(lots<minLot) lots=minLot;
   if(lots>maxLot) lots=maxLot;
   return NormalizeDouble(lots,2);
  }

//+------------------------------------------------------------------+
//| Hitung lot dari risiko % (risiko per flip = jarak hedge)         |
//+------------------------------------------------------------------+
double CalcLotByRisk()
  {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0) equity=AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity<=0) return NormalizeLot(InpLot);
   double riskMoney =equity*InpRiskPercent/100.0;
   double distPrice =InpHedgeDistance*_Point;
   double contract  =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   if(distPrice<=0 || contract<=0) return NormalizeLot(InpLot);
   double lots  =riskMoney/(distPrice*contract);
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lots<minLot)
     {
      double actualRisk=minLot*distPrice*contract/equity*100.0;
      Print("Modal kecil: lot hitungan ",DoubleToString(lots,4),
            " -> dipakai lot minimal broker ",DoubleToString(minLot,2),
            ". Risiko aktual per flip: ",DoubleToString(actualRisk,2),
            "% (target ",DoubleToString(InpRiskPercent,2),"%)");
     }
   return NormalizeLot(lots);
  }

//+------------------------------------------------------------------+
//| Refresh lot di awal siklus                                       |
//+------------------------------------------------------------------+
void RefreshLot()
  {
   g_lot=InpUseRiskPercent ? CalcLotByRisk() : NormalizeLot(InpLot);
  }

//+------------------------------------------------------------------+
//| Filter confluence: MA + zona Support/Resistance & Supply/Demand  |
//+------------------------------------------------------------------+
int g_atrHandle=INVALID_HANDLE;
int g_emaFastHandle=INVALID_HANDLE;
int g_emaSlowHandle=INVALID_HANDLE;
int g_adxHandle=INVALID_HANDLE;

double IndValue(int handle,int shift)
  {
   double b[];
   if(handle==INVALID_HANDLE) return EMPTY_VALUE;
   if(CopyBuffer(handle,0,shift,1,b)<1) return EMPTY_VALUE;
   return b[0];
  }

// Swing low (demand) terakhir: fractal, bar kiri-kanan lebih tinggi
double RecentSwingLow(int lookback,int strength)
  {
   MqlRates r[];
   int n=lookback+2*strength+5;
   if(CopyRates(_Symbol,PERIOD_CURRENT,0,n,r)<n) return 0;
   ArraySetAsSeries(r,true);
   for(int i=strength+1;i<lookback+strength;i++)
     {
      bool isLow=true;
      for(int k=1;k<=strength;k++)
         if(r[i].low>r[i-k].low || r[i].low>r[i+k].low) { isLow=false; break; }
      if(isLow) return r[i].low;
     }
   return 0;
  }

// Swing high (supply) terakhir: fractal, bar kiri-kanan lebih rendah
double RecentSwingHigh(int lookback,int strength)
  {
   MqlRates r[];
   int n=lookback+2*strength+5;
   if(CopyRates(_Symbol,PERIOD_CURRENT,0,n,r)<n) return 0;
   ArraySetAsSeries(r,true);
   for(int i=strength+1;i<lookback+strength;i++)
     {
      bool isHigh=true;
      for(int k=1;k<=strength;k++)
         if(r[i].high<r[i-k].high || r[i].high<r[i+k].high) { isHigh=false; break; }
      if(isHigh) return r[i].high;
     }
   return 0;
  }

// Setup BULLISH: EMA cepat > EMA lambat DAN harga di zona demand (support) DAN market trending
bool BullishSetup()
  {
   if(!InpUseMAFilter && !InpUseZoneFilter && !InpUseADXFilter) return true;
   bool maOK=true, zoneOK=true, adxOK=true;
   if(InpUseADXFilter)
     {
      double adx=IndValue(g_adxHandle,1);
      if(adx==EMPTY_VALUE) return false;
      adxOK=(adx>=InpADXMin); // hanya entry saat trending, hindari sideways
     }
   if(InpUseMAFilter)
     {
      double ef=IndValue(g_emaFastHandle,1), es=IndValue(g_emaSlowHandle,1);
      if(ef==EMPTY_VALUE || es==EMPTY_VALUE) return false;
      maOK=(ef>es);
     }
   if(InpUseZoneFilter)
     {
      double sw =RecentSwingLow(InpSwingLookback,InpSwingStrength);
      double atr=IndValue(g_atrHandle,1);
      if(sw==0 || atr==EMPTY_VALUE || atr<=0) return false;
      double tol  =atr*InpZoneATRMult;
      double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      zoneOK=(price<=sw+tol);
     }
   return maOK && zoneOK && adxOK;
  }

// Setup BEARISH: EMA cepat < EMA lambat DAN harga di zona supply (resistance) DAN market trending
bool BearishSetup()
  {
   if(!InpUseMAFilter && !InpUseZoneFilter && !InpUseADXFilter) return true;
   bool maOK=true, zoneOK=true, adxOK=true;
   if(InpUseADXFilter)
     {
      double adx=IndValue(g_adxHandle,1);
      if(adx==EMPTY_VALUE) return false;
      adxOK=(adx>=InpADXMin); // hanya entry saat trending, hindari sideways
     }
   if(InpUseMAFilter)
     {
      double ef=IndValue(g_emaFastHandle,1), es=IndValue(g_emaSlowHandle,1);
      if(ef==EMPTY_VALUE || es==EMPTY_VALUE) return false;
      maOK=(ef<es);
     }
   if(InpUseZoneFilter)
     {
      double sw =RecentSwingHigh(InpSwingLookback,InpSwingStrength);
      double atr=IndValue(g_atrHandle,1);
      if(sw==0 || atr==EMPTY_VALUE || atr<=0) return false;
      double tol  =atr*InpZoneATRMult;
      double price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      zoneOK=(price>=sw-tol);
     }
   return maOK && zoneOK && adxOK;
  }

//+------------------------------------------------------------------+
//| Hitung posisi berdasarkan tipe                                   |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE type)
  {
   int c=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==type) c++;
     }
   return c;
  }

//+------------------------------------------------------------------+
//| Hitung pending order berdasarkan tipe                            |
//+------------------------------------------------------------------+
int CountPendings(ENUM_ORDER_TYPE type)
  {
   int c=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong t=OrderGetTicket(i);
      if(t==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=(long)InpMagic) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type) c++;
     }
   return c;
  }

//+------------------------------------------------------------------+
//| Hapus semua pending order milik EA ini                           |
//+------------------------------------------------------------------+
void DeleteAllPendings()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      ulong t=OrderGetTicket(i);
      if(t==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=(long)InpMagic) continue;
      trade.OrderDelete(t);
     }
  }

//+------------------------------------------------------------------+
//| Tutup posisi berdasarkan tipe                                    |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE type)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==type)
         trade.PositionClose(t);
     }
  }

//+------------------------------------------------------------------+
//| Tutup SEMUA posisi milik EA ini                                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      trade.PositionClose(t);
     }
  }

//+------------------------------------------------------------------+
//| Mulai siklus: BUY + SELL STOP di bawah (kaki 1)                  |
//+------------------------------------------------------------------+
void OpenBuyHedge()
  {
   RefreshLot(); // hitung lot dari risiko % di awal siklus
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double tp=NormalizeDouble(ask+InpTakeProfit*_Point,_Digits);
   double stopPrice=NormalizeDouble(ask-InpHedgeDistance*_Point,_Digits);
   double stopTP=NormalizeDouble(stopPrice-InpTakeProfit*_Point,_Digits);
   if(trade.Buy(g_lot,_Symbol,ask,0,tp,"LilyHedge BUY"))
     {
      trade.SellStop(g_lot,stopPrice,_Symbol,0,stopTP,ORDER_TIME_GTC,0,"LilyHedge SELLSTOP");
      g_leg=1;
      CycleStart();
     }
  }

//+------------------------------------------------------------------+
//| Pasang SELL STOP pengaman di bawah (untuk kaki BUY)              |
//+------------------------------------------------------------------+
void PlaceSellStop()
  {
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double stopPrice=NormalizeDouble(ask-InpHedgeDistance*_Point,_Digits);
   double stopTP=NormalizeDouble(stopPrice-InpTakeProfit*_Point,_Digits);
   if(trade.SellStop(g_lot,stopPrice,_Symbol,0,stopTP,ORDER_TIME_GTC,0,"LilyHedge SELLSTOP"))
      g_leg=1;
  }

//+------------------------------------------------------------------+
//| Mulai siklus: SELL + BUY STOP di atas (kaki 2)                   |
//+------------------------------------------------------------------+
void OpenSellHedge()
  {
   RefreshLot(); // hitung lot dari risiko % di awal siklus
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tp=NormalizeDouble(bid-InpTakeProfit*_Point,_Digits);
   double stopPrice=NormalizeDouble(bid+InpHedgeDistance*_Point,_Digits);
   double stopTP=NormalizeDouble(stopPrice+InpTakeProfit*_Point,_Digits);
   if(trade.Sell(g_lot,_Symbol,bid,0,tp,"LilyHedge SELL"))
     {
      trade.BuyStop(g_lot,stopPrice,_Symbol,0,stopTP,ORDER_TIME_GTC,0,"LilyHedge BUYSTOP");
      g_leg=2;
      CycleStart();
     }
  }

//+------------------------------------------------------------------+
//| Pasang BUY STOP pengaman di atas (untuk kaki SELL)               |
//+------------------------------------------------------------------+
void PlaceBuyStop()
  {
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double stopPrice=NormalizeDouble(bid+InpHedgeDistance*_Point,_Digits);
   double stopTP=NormalizeDouble(stopPrice+InpTakeProfit*_Point,_Digits);
   if(trade.BuyStop(g_lot,stopPrice,_Symbol,0,stopTP,ORDER_TIME_GTC,0,"LilyHedge BUYSTOP"))
      g_leg=2;
  }

//+------------------------------------------------------------------+
//| Proteksi profit: Break-Even + Trailing Stop                      |
//| Dipanggil tiap tick untuk semua posisi EA ini                     |
//+------------------------------------------------------------------+
void ManageProfit()
  {
   if(!InpUseBreakEven && !InpUseTrailing) return;
   long   stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  =(stopLevel+2)*_Point; // buffer dari stops level broker
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      ENUM_POSITION_TYPE ptype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice=PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL    =PositionGetDouble(POSITION_SL);
      double curTP    =PositionGetDouble(POSITION_TP);
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

      if(ptype==POSITION_TYPE_BUY)
        {
         double profitPts=(bid-openPrice)/_Point;
         double newSL=curSL;
         if(InpUseBreakEven && profitPts>=InpBETTrigger) // kunci di entry
           {
            double beSL=openPrice+InpBETOffset*_Point;
            if(beSL>newSL && bid-beSL>=minDist) newSL=beSL;
           }
         if(InpUseTrailing && profitPts>=InpTrailTrigger) // kunci profit berjalan
           {
            double trSL=bid-InpTrailDistance*_Point;
            if(trSL>newSL && bid-trSL>=minDist) newSL=trSL;
           }
         if(NormalizeDouble(newSL,_Digits)>NormalizeDouble(curSL,_Digits))
            trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),curTP);
        }
      else // POSITION_TYPE_SELL
        {
         double profitPts=(openPrice-ask)/_Point;
         double newSL=curSL;
         if(InpUseBreakEven && profitPts>=InpBETTrigger) // kunci di entry
           {
            double beSL=openPrice-InpBETOffset*_Point;
            if(beSL-ask>=minDist && (curSL==0 || beSL<newSL)) newSL=beSL;
           }
         if(InpUseTrailing && profitPts>=InpTrailTrigger) // kunci profit berjalan
           {
            double trSL=ask+InpTrailDistance*_Point;
            if(trSL-ask>=minDist && (curSL==0 || trSL<newSL)) newSL=trSL;
           }
         bool needModify=(curSL==0 && newSL>0) || (curSL>0 && newSL>0 && newSL<curSL);
         if(needModify)
            trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),curTP);
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);

//--- Handle indikator untuk filter confluence
   g_atrHandle    =iATR(_Symbol,PERIOD_CURRENT,InpATRPeriod);
   g_emaFastHandle=iMA(_Symbol,PERIOD_CURRENT,InpEMAFast,0,MODE_EMA,PRICE_CLOSE);
   g_emaSlowHandle=iMA(_Symbol,PERIOD_CURRENT,InpEMASlow,0,MODE_EMA,PRICE_CLOSE);
   g_adxHandle    =iADX(_Symbol,PERIOD_CURRENT,InpADXPeriod);
   if(g_atrHandle==INVALID_HANDLE || g_emaFastHandle==INVALID_HANDLE ||
      g_emaSlowHandle==INVALID_HANDLE || g_adxHandle==INVALID_HANDLE)
     {
      Print("Gagal membuat handle indikator (ATR/EMA/ADX)!");
      return(INIT_FAILED);
     }

//--- Peringatan mode akun: hedging butuh akun HEDGING
   ENUM_ACCOUNT_MARGIN_MODE mm=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mm!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("PERINGATAN: Akun ini mode NETTING. EA hedging butuh akun HEDGING supaya BUY dan SELL bisa terbuka bersamaan!");

//--- Peringatan stops level
   long stopsLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(InpHedgeDistance<=stopsLevel)
      Print("PERINGATAN: InpHedgeDistance (",InpHedgeDistance,") lebih kecil dari stops level broker (",stopsLevel,"). Naikkan nilainya!");

   Print("LilyHedgeEA jalan! Semangat Thalib!");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_atrHandle!=INVALID_HANDLE)     IndicatorRelease(g_atrHandle);
   if(g_emaFastHandle!=INVALID_HANDLE) IndicatorRelease(g_emaFastHandle);
   if(g_emaSlowHandle!=INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle);
   if(g_adxHandle!=INVALID_HANDLE)     IndicatorRelease(g_adxHandle);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageProfit(); // proteksi profit dulu: breakeven + trailing stop
   int buys      = CountPositions(POSITION_TYPE_BUY);
   int sells     = CountPositions(POSITION_TYPE_SELL);
   int buyStops  = CountPendings(ORDER_TYPE_BUY_STOP);
   int sellStops = CountPendings(ORDER_TYPE_SELL_STOP);

//--- 1. Flat total: evaluasi siklus lalu, circuit breaker, lalu mulai siklus baru HANYA bila filter selaras
   if(buys==0 && sells==0)
     {
      CycleEnd(); // catat profit/loss siklus yang baru selesai
      if(CircuitBreakerActive()) // jeda otomatis setelah loss beruntun
        {
         static datetime lastCBPrint=0;
         if(TimeCurrent()-lastCBPrint>300)
           {
            Print("Circuit breaker aktif: istirahat ",InpPauseMinutes," menit setelah ",g_consecLosses," loss beruntun.");
            lastCBPrint=TimeCurrent();
           }
         return;
        }
      DeleteAllPendings();
      g_leg=0;
      long spreadPts=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
      bool spreadOK=(spreadPts<=InpMaxSpreadPoints);
      if(spreadOK && BullishSetup())
         OpenBuyHedge();            // tren naik + harga di zona demand -> BUY + SELL STOP
      else if(spreadOK && BearishSetup())
         OpenSellHedge();           // tren turun + harga di zona supply -> SELL + BUY STOP
      else
        {
         static datetime lastWaitPrint=0;
         if(TimeCurrent()-lastWaitPrint>300)
           {
            Print("Menunggu setup confluence (MA + ADX + zona Support/Resistance & Supply/Demand). Tidak asal buka posisi.");
            lastWaitPrint=TimeCurrent();
           }
        }
      return;
     }

//--- 2. Pending ketrigger: sekarang BUY dan SELL terbuka bersamaan -> tutup yang kalah, lanjut kaki berikutnya
   if(buys>0 && sells>0)
     {
      if(g_leg==1)
        {
         // SELL STOP ketrigger: tutup BUY yang rugi, lanjut kaki SELL
         ClosePositions(POSITION_TYPE_BUY);
         DeleteAllPendings();
         if(CountPendings(ORDER_TYPE_BUY_STOP)==0)
            PlaceBuyStop(); // g_leg=2
        }
      else if(g_leg==2)
        {
         // BUY STOP ketrigger: tutup SELL yang rugi, lanjut kaki BUY
         ClosePositions(POSITION_TYPE_SELL);
         DeleteAllPendings();
         if(CountPendings(ORDER_TYPE_SELL_STOP)==0)
            PlaceSellStop(); // g_leg=1
        }
      else
        {
         // Status tidak dikenal (misal intervensi manual): reset aman
         CloseAllPositions();
         DeleteAllPendings();
         g_leg=0;
        }
      return;
     }

//--- 3. Pastikan pasangan pending selalu ada
   if(g_leg==1 && buys>0 && sellStops==0)
      PlaceSellStop();
   if(g_leg==2 && sells>0 && buyStops==0)
      PlaceBuyStop();

//--- 4. Koreksi status bila melenceng (misal pending kehapus manual)
   if(buys>0 && sells==0 && sellStops>0) g_leg=1;
   if(sells>0 && buys==0 && buyStops>0)  g_leg=2;
  }
//+------------------------------------------------------------------+
