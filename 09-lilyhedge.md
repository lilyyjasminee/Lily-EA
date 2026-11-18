# LilyHedgeEA — Hedging Berpasangan + Filter Confluence (BELUM PERNAH DI-BACKTEST)

**File:** `ea/LilyHedgeEA.mq5` — **Versi:** 1.31 — **Magic Number:** 20261020
**Simbol:** XAUUSD (emas, awalnya) — **Timeframe:** chart tempat ditempel (`PERIOD_CURRENT`)
**Status:** ⚠️ BELUM PERNAH DI-BACKTEST — tidak ada winrate. JANGAN dipakai live.

## Idenya (penjelasan sederhana)

Terinspirasi video TikTok zupper.fx: buka BUY, lalu pasang SELL STOP di bawahnya sebagai "pengaman". Kalau harga turun dan SELL STOP kena, posisi BUY yang rugi ditutup, dan EA lanjut dengan kaki SELL. Kalau harga naik dan kena TP, siklus selesai dan mulai lagi. Idenya: salah satu kaki pasti kena TP, jadi "tidak mungkin rugi" — klaim ini SALAH, dan EA ini dibuat untuk menguji klaim itu.

## Cara kerja langkah demi langkah

1. **Mulai siklus (hanya kalau filter confluence selaras).** Filter: EMA 9 di atas EMA 21 DAN harga di zona demand DAN ADX ≥ 20 (trending) → buka BUY + pasang SELL STOP 100 point di bawahnya. Kalau kondisi bearish (kebalikan) → buka SELL + BUY STOP 100 point di atasnya.
2. **TP 300 point** untuk tiap posisi. Tidak ada SL tetap — "SL"-nya adalah pending order hedge di sisi berlawanan.
3. **Pending ketrigger → flip kaki.** Kalau SELL STOP kena (harga turun), BUY yang rugi ditutup, dan EA lanjut sebagai kaki SELL (lalu pasang BUY STOP baru di atas). Begitu seterusnya, bolak-balik, sampai salah satu kaki kena TP 300 point.
4. **Break-even** saat profit 150 point, **trailing stop** saat profit 200 point (jarak 100 point).
5. **Circuit breaker (default MATI).** Kalau diaktifkan: setelah 3 loss beruntun, EA istirahat 60 menit.
6. **Butuh akun HEDGING.** Akun netting tidak bisa membuka BUY dan SELL bersamaan — EA akan memberi peringatan di log kalau akunnya netting.

## Manajemen risiko dan lot

- Lot dihitung dari risiko 2% per flip (jarak hedge 100 point sebagai dasar hitungan), atau lot tetap 0,01 kalau `InpUseRiskPercent = false`.
- Risiko sebenarnya TIDAK terbatas seperti EA ber-SL: satu siklus bisa flip berkali-kali, dan setiap flip menutup posisi yang rugi. Kerugian siklus = jumlah flip × jarak hedge (belum termasuk spread tiap flip).

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpTakeProfit | 300 point | TP tiap kaki ($3,00 di XAUUSD) |
| InpHedgeDistance | 100 point | Jarak pending order hedge |
| InpRiskPercent | 2% | Risiko per flip |
| InpEMAFast / InpEMASlow | 9 / 21 | Filter MA |
| InpADXMin | 20 | Hanya entry saat trending |
| InpUseCircuitBreaker | false | Circuit breaker (default mati) |
| InpMaxConsecLosses / InpPauseMinutes | 3 / 60 | Aturan circuit breaker |
| InpMagic | 20261020 | Nomor identitas EA |

## Hasil backtest

- **TIDAK ADA. EA ini belum pernah di-backtest sama sekali.** Tidak ada winrate, tidak ada Profit Factor, tidak ada total R.
- Yang ada hanya laporan Thalib dari live/demo: loss lebih sering dari profit (19–20 Oktober 2026, bersamaan dengan SpikeFade dan MeanReversion).
- **Kenapa belum di-backtest:** logika hedging dengan flip berantai dan pending order sangat sulit disimulasikan dengan benar (butuh data tick dan aturan eksekusi pending yang tepat). Backtest asal-asalan akan memberi angka palsu. Lebih jujur mengakui belum diuji daripada mengarang angka.
- **Backtest 5 tahun TIDAK FEASIBLE** untuk alasan yang sama, ditambah EA ini memakai timeframe chart dan logika stateful (kaki 1/kaki 2, circuit breaker) yang tidak bisa diuji dengan backtest bar sederhana.

## Pelajaran dari EA ini

- Hedging BUKAN penghilang risiko. BUY + SELL bersamaan itu sama dengan tidak punya posisi, dikurangi spread dua kali. Yang "dijual" video TikTok sebagai strategi anti-rugi sebenarnya adalah sistem yang membayar spread berkali-kali.
- Kalau sebuah strategi mengklaim "tidak mungkin rugi", itu tanda bahaya — bukan tanda bagus.
- EA ini disimpan di repo sebagai arsip: bukti bahwa Lily dan Thalib pernah menguji ide hedging dan memutuskan untuk tidak memakainya sebelum ada bukti backtest.
