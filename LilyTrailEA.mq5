//+------------------------------------------------------------------+
//| LilyTrailEA.mq5                                                  |
//| Terinspirasi video TikTok @earazor_ (EA RAZOR):                   |
//| EMA cross M1 + Trailing Stop otomatis untuk XAUUSD                |
//| Sinyal berlawanan = tutup posisi lama, buka posisi baru (flip)   |
//| Dibuat oleh Lily untuk Thalib                                    |
//+------------------------------------------------------------------+
#property copyright "Lily untuk Thalib"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Risiko & umum
input double InpRiskPct        = 2.0;         // Risiko per trade (% dari equity)
input int    InpMagic          = 20261027;    // Magic Number
input int    InpSlippage       = 30;          // Slippage (point)
input int    InpMaxSpreadPoints= 40;          // Spread maksimal untuk entry (point)
input string InpTradeComment   = "LilyTrailEA";// Komentar order
//--- Sinyal EMA cross (dievaluasi tiap candle baru yang tutup)
input int    InpEmaFast        = 9;           // EMA cepat
input int    InpEmaSlow        = 21;          // EMA lambat
//--- SL / TP tetap (point). Di XAUUSD 2-digit: 100 point = $1.00
input int    InpStopLoss       = 200;         // SL tetap (point)
input int    InpTakeProfit     = 400;         // TP tetap (point)
//--- Trailing stop otomatis (seperti di video: SL digeser saat profit)
input bool   InpUseTrailing    = true;        // Trailing stop aktif
input int    InpTrailTrigger   = 150;         // Mulai trail saat profit (point)
input int    InpTrailDistance  = 100;         // Jarak trail dari harga (point)

int      g_emaFast=INVALID_HANDLE; // handle EMA cepat
int      g_emaSlow=INVALID_HANDLE; // handle EMA lambat
datetime g_lastBar=0;              // bar terakhir yang sudah dievaluasi

//+------------------------------------------------------------------+
//| Cari tiket posisi milik EA ini (satu posisi dalam satu waktu)    |
//+------------------------------------------------------------------+
ulong FindMyPosition()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      return t;
     }
   return 0;
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
double CalcLotByRisk(double slPoints)
  {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0) equity=AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity<=0 || slPoints<=0) return NormalizeLot(0.01);
   double riskMoney=equity*InpRiskPct/100.0;
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
            "% (target ",DoubleToString(InpRiskPct,2),"%)");
     }
   return NormalizeLot(lots);
  }

//+------------------------------------------------------------------+
//| Trailing stop: geser SL hanya searah profit (seperti di video)    |
//+------------------------------------------------------------------+
void ManageTrailing()
  {
   if(!InpUseTrailing) return;
   ulong ticket=FindMyPosition();
   if(ticket==0) return;
   if(!PositionSelectByTicket(ticket)) return;

   ENUM_POSITION_TYPE ptype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice=PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL    =PositionGetDouble(POSITION_SL);
   double curTP    =PositionGetDouble(POSITION_TP);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   long   stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  =(stopLevel+2)*_Point; // jarak aman minimal, konservatif

   if(ptype==POSITION_TYPE_BUY)
     {
      double profitPts=(bid-openPrice)/_Point;
      if(profitPts>=InpTrailTrigger)
        {
         double newSL=bid-InpTrailDistance*_Point; // SL di bawah harga
         // Hanya naikkan SL, tidak pernah turunkan; hormati jarak minimal
         if(newSL>curSL && bid-newSL>=minDist)
            trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),curTP);
        }
     }
   else // POSITION_TYPE_SELL
     {
      double profitPts=(openPrice-ask)/_Point;
      if(profitPts>=InpTrailTrigger)
        {
         double newSL=ask+InpTrailDistance*_Point; // SL di atas harga
         // Hanya turunkan SL, tidak pernah naikkan; hormati jarak minimal
         if((curSL==0 || newSL<curSL) && newSL-ask>=minDist)
            trade.PositionModify(ticket,NormalizeDouble(newSL,_Digits),curTP);
        }
     }
  }

//+------------------------------------------------------------------+
//| Sinyal EMA cross dari 2 candle terakhir yang sudah tutup         |
//| return: +1 = BUY (cross naik), -1 = SELL (cross turun), 0 = diam |
//+------------------------------------------------------------------+
int EmaCrossSignal()
  {
   double f[],s[];
   ArraySetAsSeries(f,true);
   ArraySetAsSeries(s,true);
   // Ambil 2 nilai terakhir dari candle yang SUDAH TUTUP (shift 1 dan 2)
   if(CopyBuffer(g_emaFast,0,1,2,f)<2) return 0;
   if(CopyBuffer(g_emaSlow,0,1,2,s)<2) return 0;
   bool wasBelow=(f[1]<=s[1]); // candle kemarin: EMA cepat di bawah/di EMA lambat
   bool isAbove =(f[0]> s[0]); // candle barusan tutup: EMA cepat di atas EMA lambat
   if(wasBelow && isAbove) return 1;   // cross naik -> BUY
   bool wasAbove=(f[1]>=s[1]);
   bool isBelow =(f[0]< s[0]);
   if(wasAbove && isBelow) return -1;   // cross turun -> SELL
   return 0;
  }

//+------------------------------------------------------------------+
//| Buka posisi dengan SL & TP tetap                                 |
//+------------------------------------------------------------------+
void OpenPosition(int signal)
  {
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   long   stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=(stopLevel+2)*_Point;
   double lots=CalcLotByRisk((double)InpStopLoss);
   if(lots<=0) return;

   if(signal>0) // BUY
     {
      double sl=ask-InpStopLoss*_Point;
      double tp=ask+InpTakeProfit*_Point;
      if(ask-sl<minDist || tp-ask<minDist) return; // jarak terlalu dekat, skip
      if(trade.Buy(lots,_Symbol,ask,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),InpTradeComment))
         Print("Trail BUY: entry ",ask," | SL ",sl," | TP ",tp," | lot ",lots);
     }
   else if(signal<0) // SELL
     {
      double sl=bid+InpStopLoss*_Point;
      double tp=bid-InpTakeProfit*_Point;
      if(sl-bid<minDist || bid-tp<minDist) return; // jarak terlalu dekat, skip
      if(trade.Sell(lots,_Symbol,bid,NormalizeDouble(sl,_Digits),NormalizeDouble(tp,_Digits),InpTradeComment))
         Print("Trail SELL: entry ",bid," | SL ",sl," | TP ",tp," | lot ",lots);
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   g_emaFast=iMA(_Symbol,PERIOD_CURRENT,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   g_emaSlow=iMA(_Symbol,PERIOD_CURRENT,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   if(g_emaFast==INVALID_HANDLE || g_emaSlow==INVALID_HANDLE)
     {
      Print("Gagal membuat handle EMA!");
      return(INIT_FAILED);
     }
   Print("LilyTrailEA jalan! Semangat Thalib!");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_emaFast!=INVALID_HANDLE) IndicatorRelease(g_emaFast);
   if(g_emaSlow!=INVALID_HANDLE) IndicatorRelease(g_emaSlow);
  }

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageTrailing(); // trailing stop jalan tiap tick, seperti di video

//--- Evaluasi sinyal hanya sekali per candle baru
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,0);
   if(bt==g_lastBar) return;
   g_lastBar=bt;

   long spr=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spr>InpMaxSpreadPoints) return; // spread kemahalan, skip entry

   int signal=EmaCrossSignal();
   if(signal==0) return; // tidak ada cross, diam

   ulong ticket=FindMyPosition();
   if(ticket!=0)
     {
      // Sinyal searah posisi yang ada -> diam (satu posisi dalam satu waktu)
      if(!PositionSelectByTicket(ticket)) return;
      ENUM_POSITION_TYPE ptype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((signal>0 && ptype==POSITION_TYPE_BUY) ||
         (signal<0 && ptype==POSITION_TYPE_SELL)) return;
      // Sinyal berlawanan -> tutup posisi lama dulu (flip, seperti di video)
      if(!trade.PositionClose(ticket))
        {
         Print("Gagal tutup posisi untuk flip!");
         return;
        }
      Print("Flip: posisi lama ditutup, buka posisi baru.");
     }

   OpenPosition(signal);
  }
//+------------------------------------------------------------------+
