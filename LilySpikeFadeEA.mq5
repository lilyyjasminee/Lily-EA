//+------------------------------------------------------------------+
//| LilySpikeFadeEA.mq5                                              |
//| Fade spike: candle melonjak panjang -> entry BERLAWANAN di puncak|
//| TP kecil (profit langsung diamankan), SL kecil                   |
//| Dibuat oleh Lily untuk Thalib                                    |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.10"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Risiko & umum
input double InpRiskPercent    = 2.0;     // Risiko per trade (% dari equity)
input int    InpMagic          = 20261022; // Magic Number
input int    InpSlippage       = 30;        // Slippage (point)
input int    InpMaxSpreadPoints= 40;        // Spread maksimal untuk entry (point)
//--- Sinyal spike (candle yang baru tutup)
input int    InpSpikePoints    = 80;        // Panjang dorongan candle (point) untuk sinyal fade
//--- Exit cepat: TP kecil, SL kecil (TP diset 2x lipat dari spread agar ekspektasi sehat)
input int    InpTakeProfit     = 100;       // TP (point) = $1.00 di XAUUSD
input int    InpSLBuffer       = 30;        // SL di luar puncak spike + buffer (point)
//--- Proteksi profit
input bool   InpUseBreakEven   = true;      // Break-even
input int    InpBETTrigger     = 50;        // Pemicu break-even (point)
input int    InpBETOffset      = 5;         // Offset SL break-even (point)
input bool   InpUseTrailing    = true;      // Trailing stop
input int    InpTrailTrigger   = 70;        // Pemicu trailing (point)
input int    InpTrailDistance  = 35;        // Jarak trailing (point)

datetime g_lastBar=0; // bar terakhir yang sudah dievaluasi

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
   Print("LilySpikeFadeEA jalan! Semangat Thalib!");
   return(INIT_SUCCEEDED);
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

//--- Evaluasi hanya sekali per candle baru (pakai candle yang baru tutup)
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,0);
   if(bt==g_lastBar) return;
   g_lastBar=bt;

   double o=iOpen(_Symbol,PERIOD_CURRENT,1);
   double h=iHigh(_Symbol,PERIOD_CURRENT,1);
   double l=iLow(_Symbol,PERIOD_CURRENT,1);
   double c=iClose(_Symbol,PERIOD_CURRENT,1);
   if(o<=0 || h<=0 || l<=0 || c<=0) return;

   double pushUp=(h-o)/_Point; // dorongan ke atas
   double pushDn=(o-l)/_Point; // dorongan ke bawah

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   long   stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=(stopLevel+2)*_Point;

//--- Sinyal SELL: candle melonjak ke atas panjang -> jual di puncak
   if(pushUp>=InpSpikePoints && pushUp>=pushDn)
     {
      double sl=h+InpSLBuffer*_Point;      // SL kecil di atas puncak
      double tp=bid-InpTakeProfit*_Point;  // TP kecil, profit langsung diamankan
      if(sl-bid<minDist || bid-tp<minDist) return;
      double lots=CalcLotBySL((sl-bid)/_Point);
      if(lots<=0) return;
      if(trade.Sell(lots,_Symbol,bid,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),"LilyFade SELL"))
         Print("Fade SELL: spike +",DoubleToString(pushUp,0),"pt | entry ",bid," | SL ",sl," | TP ",tp);
      return;
     }

//--- Sinyal BUY: candle terjun ke bawah panjang -> beli di lembah
   if(pushDn>=InpSpikePoints && pushDn>pushUp)
     {
      double sl=l-InpSLBuffer*_Point;      // SL kecil di bawah lembah
      double tp=ask+InpTakeProfit*_Point;  // TP kecil, profit langsung diamankan
      if(ask-sl<minDist || tp-ask<minDist) return;
      double lots=CalcLotBySL((ask-sl)/_Point);
      if(lots<=0) return;
      if(trade.Buy(lots,_Symbol,ask,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),"LilyFade BUY"))
         Print("Fade BUY: spike -",DoubleToString(pushDn,0),"pt | entry ",ask," | SL ",sl," | TP ",tp);
      return;
     }
  }
//+------------------------------------------------------------------+
