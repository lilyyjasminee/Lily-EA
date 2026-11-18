//+------------------------------------------------------------------+
//| LilyMeanReversionEA.mq5                                          |
//| Mean Reversion: BUY di support / SELL di resistance saat sideways|
//| Dibuat oleh Lily untuk Thalib                                    |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Risiko & umum
input double InpRiskPercent    = 2.0;     // Risiko per trade (% dari equity)
input int    InpMagic          = 20261021; // Magic Number
input int    InpSlippage       = 30;        // Slippage (point)
input int    InpMaxSpreadPoints= 40;        // Spread maksimal untuk entry (point)
//--- Range (Support/Resistance dari swing)
input int    InpRangeLookback  = 50;        // Cari swing high/low ke belakang (bar)
input int    InpSwingStrength  = 3;         // Kekuatan fractal (bar kiri-kanan)
input int    InpMinRangePoints = 150;       // Tinggi range minimal (point)
input int    InpMaxRangePoints = 500;       // Tinggi range maksimal (point)
//--- Filter sideways (ADX) & momentum (RSI)
input bool   InpUseADXFilter   = true;      // Entry HANYA saat market sideways
input int    InpADXPeriod      = 14;        // Periode ADX
input double InpADXMax         = 20.0;      // ADX di bawah ini = sideways
input bool   InpUseRSI         = true;      // Filter RSI
input int    InpRSIPeriod      = 14;        // Periode RSI
input double InpRSIBuyMax      = 40.0;      // BUY hanya bila RSI < ini
input double InpRSISellMin     = 60.0;      // SELL hanya bila RSI > ini
//--- Zona entry
input int    InpATRPeriod      = 14;        // Periode ATR
input double InpZoneATRMult    = 0.3;       // Toleransi zona entry (x ATR)
//--- Exit (TP/SL otomatis dari boundary range)
input int    InpSLBufferPoints = 50;        // SL di luar boundary + buffer (point)
input int    InpTPBufferPoints = 30;        // TP di dalam boundary lawan - buffer (point)
//--- Proteksi profit
input bool   InpUseBreakEven   = true;      // Break-even
input int    InpBETTrigger     = 80;        // Pemicu break-even (point)
input int    InpBETOffset      = 10;        // Offset SL break-even (point)
input bool   InpUseTrailing    = true;      // Trailing stop
input int    InpTrailTrigger   = 120;       // Pemicu trailing (point)
input int    InpTrailDistance  = 60;        // Jarak trailing (point)

int g_rsiHandle=INVALID_HANDLE;
int g_adxHandle=INVALID_HANDLE;
int g_atrHandle=INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Baca nilai indikator                                             |
//+------------------------------------------------------------------+
double IndValue(int handle,int shift)
  {
   double b[];
   if(handle==INVALID_HANDLE) return EMPTY_VALUE;
   if(CopyBuffer(handle,0,shift,1,b)<1) return EMPTY_VALUE;
   return b[0];
  }

//+------------------------------------------------------------------+
//| Swing low terakhir (support / demand)                            |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Swing high terakhir (resistance / supply)                        |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Hitung posisi milik EA ini                                       |
//+------------------------------------------------------------------+
int CountMyPositions()
  {
   int c=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      c++;
     }
   return c;
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
//| Hitung lot dari risiko % berdasarkan jarak SL                    |
//+------------------------------------------------------------------+
double CalcLotBySL(double slPoints)
  {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0) equity=AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity<=0 || slPoints<=0) return NormalizeLot(0.01);
   double riskMoney=equity*InpRiskPercent/100.0;
   double slPrice  =slPoints*_Point;
   double contract =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   if(contract<=0) contract=100;
   double lots  =riskMoney/(slPrice*contract);
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lots<minLot)
     {
      double actualRisk=minLot*slPrice*contract/equity*100.0;
      Print("Lot hitungan ",DoubleToString(lots,4)," -> dipakai lot minimal ",
            DoubleToString(minLot,2),". Risiko aktual: ",DoubleToString(actualRisk,2),
            "% (target ",DoubleToString(InpRiskPercent,2),"%)");
     }
   return NormalizeLot(lots);
  }

//+------------------------------------------------------------------+
//| Proteksi profit: Break-Even + Trailing Stop                      |
//+------------------------------------------------------------------+
void ManageProfit()
  {
   if(!InpUseBreakEven && !InpUseTrailing) return;
   long   stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  =(stopLevel+2)*_Point;
   for(int i=PositionsTotal()-1;i>=0;i--)
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
         if(InpUseBreakEven && profitPts>=InpBETTrigger)
           {
            double beSL=openPrice+InpBETOffset*_Point;
            if(beSL>newSL && bid-beSL>=minDist) newSL=beSL;
           }
         if(InpUseTrailing && profitPts>=InpTrailTrigger)
           {
            double trSL=bid-InpTrailDistance*_Point;
            if(trSL>newSL && bid-trSL>=minDist) newSL=trSL;
           }
         if(NormalizeDouble(newSL,_Digits)>NormalizeDouble(curSL,_Digits))
            trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),curTP);
        }
      else
        {
         double profitPts=(openPrice-ask)/_Point;
         double newSL=curSL;
         if(InpUseBreakEven && profitPts>=InpBETTrigger)
           {
            double beSL=openPrice-InpBETOffset*_Point;
            if(beSL-ask>=minDist && (curSL==0 || beSL<newSL)) newSL=beSL;
           }
         if(InpUseTrailing && profitPts>=InpTrailTrigger)
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

   g_rsiHandle=iRSI(_Symbol,PERIOD_CURRENT,InpRSIPeriod,PRICE_CLOSE);
   g_adxHandle=iADX(_Symbol,PERIOD_CURRENT,InpADXPeriod);
   g_atrHandle=iATR(_Symbol,PERIOD_CURRENT,InpATRPeriod);
   if(g_rsiHandle==INVALID_HANDLE || g_adxHandle==INVALID_HANDLE || g_atrHandle==INVALID_HANDLE)
     {
      Print("Gagal membuat handle indikator (RSI/ADX/ATR)!");
      return(INIT_FAILED);
     }
   Print("LilyMeanReversionEA jalan! Semangat Thalib!");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_rsiHandle!=INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_adxHandle!=INVALID_HANDLE) IndicatorRelease(g_adxHandle);
   if(g_atrHandle!=INVALID_HANDLE) IndicatorRelease(g_atrHandle);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageProfit(); // proteksi profit dulu
   if(CountMyPositions()>0) return; // satu posisi dalam satu waktu

   long spr=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spr>InpMaxSpreadPoints) return; // spread kemahalan, skip

//--- Filter 1: hanya saat market SIDEWAYS (ADX rendah)
   if(InpUseADXFilter)
     {
      double adx=IndValue(g_adxHandle,1);
      if(adx==EMPTY_VALUE || adx>InpADXMax) return;
     }

//--- Cari boundary range: support (swing low) & resistance (swing high)
   double sup=RecentSwingLow(InpRangeLookback,InpSwingStrength);
   double res=RecentSwingHigh(InpRangeLookback,InpSwingStrength);
   if(sup==0 || res==0 || res<=sup) return;
   double rangePts=(res-sup)/_Point;
   if(rangePts<InpMinRangePoints || rangePts>InpMaxRangePoints) return; // range harus wajar

   double atr=IndValue(g_atrHandle,1);
   if(atr==EMPTY_VALUE || atr<=0) return;
   double tol=atr*InpZoneATRMult;

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   long   stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=(stopLevel+2)*_Point;

//--- Sinyal BUY: harga menyentuh zona SUPPORT (beli murah)
   if(bid<=sup+tol)
     {
      if(InpUseRSI)
        {
         double rsi=IndValue(g_rsiHandle,1);
         if(rsi==EMPTY_VALUE || rsi>=InpRSIBuyMax) return; // RSI harus rendah
        }
      double sl=sup-InpSLBufferPoints*_Point;   // SL di bawah support
      double tp=res-InpTPBufferPoints*_Point;   // TP di resistance
      if(ask-sl<minDist || tp-ask<minDist) return;
      double lots=CalcLotBySL((ask-sl)/_Point);
      if(lots<=0) return;
      if(trade.Buy(lots,_Symbol,ask,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),"LilyMR BUY"))
         Print("MeanReversion BUY @ ",ask," | SL ",sl," | TP ",tp," | lot ",lots);
      return;
     }

//--- Sinyal SELL: harga menyentuh zona RESISTANCE (jual mahal)
   if(ask>=res-tol)
     {
      if(InpUseRSI)
        {
         double rsi=IndValue(g_rsiHandle,1);
         if(rsi==EMPTY_VALUE || rsi<=InpRSISellMin) return; // RSI harus tinggi
        }
      double sl=res+InpSLBufferPoints*_Point;   // SL di atas resistance
      double tp=sup+InpTPBufferPoints*_Point;   // TP di support
      if(sl-bid<minDist || bid-tp<minDist) return;
      double lots=CalcLotBySL((sl-bid)/_Point);
      if(lots<=0) return;
      if(trade.Sell(lots,_Symbol,bid,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),"LilyMR SELL"))
         Print("MeanReversion SELL @ ",bid," | SL ",sl," | TP ",tp," | lot ",lots);
      return;
     }
  }
//+------------------------------------------------------------------+
