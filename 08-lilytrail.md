# LilyTrailEA — EMA Cross M1 + Trailing Stop (ARSIP — GAGAL)

**File:** `ea/LilyTrailEA.mq5` — **Versi:** 1.00 — **Magic Number:** 20261027
**Simbol:** XAUUSD (emas) — **Timeframe:** M1 (chart tempat ditempel)
**Status:** ❌ GAGAL di backtest — disimpan sebagai arsip pelajaran, JANGAN dipakai live

## Idenya (penjelasan sederhana)

Terinspirasi video TikTok @earazor_ (EA "RAZOR"): kalau EMA cepat (9) menyalip EMA lambat (21) ke atas, tren naik — ikut beli. Kalau menyalip ke bawah, tren turun — ikut jual. Kalau sinyal berbalik arah, posisi lama ditutup dan posisi baru dibuka ke arah sebaliknya (flip). Trailing stop menggeser SL mengikuti profit, supaya profit yang sudah didapat tidak balik jadi rugi.

## Cara kerja langkah demi langkah

1. **Tiap candle M1 baru tutup, EA mengecek persilangan EMA 9 dan EMA 21** (dari 2 candle terakhir yang sudah tutup).
2. **Sinyal BUY (cross naik):** EMA 9 kemarin di bawah/di EMA 21, sekarang di atas → BUY. Kalau ada posisi SELL lama, tutup dulu (flip).
3. **Sinyal SELL (cross turun):** sebaliknya → SELL, flip kalau ada posisi BUY.
4. **SL tetap 200 point, TP tetap 400 point** (di XAUUSD 2-digit: 100 point = $1,00, jadi SL $2,00 dan TP $4,00).
5. **Trailing stop:** mulai trail saat profit 150 point, SL digeser menjaga jarak 100 point dari harga. SL hanya digeser searah profit, tidak pernah digeser mundur.
6. **Satu posisi dalam satu waktu.** Filter spread maksimal 40 point.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari equity, lot dihitung dari jarak SL 200 point.
- Kalau lot hitungan di bawah minimum broker, dipakai lot minimum (risiko aktual lebih besar dari 2%).

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpEmaFast / InpEmaSlow | 9 / 21 | EMA cepat dan lambat |
| InpStopLoss / InpTakeProfit | 200 / 400 point | SL $2,00 / TP $4,00 |
| InpTrailTrigger / InpTrailDistance | 150 / 100 point | Mulai trail dan jarak trail |
| InpRiskPct | 2% | Risiko per trade |
| InpMaxSpreadPoints | 40 | Spread maksimal |
| InpMagic | 20261027 | Nomor identitas EA |

Catatan: laporan backtest lama sempat menulis magic 20261024 untuk EA ini — itu nomor lama sebelum diperbaiki. Nomor yang benar sekarang adalah 20261027 (diperbaiki 21 Oktober 2026 karena tabrakan dengan LilyGotobiEA yang juga 20261024). Semua 9 EA sekarang punya magic berbeda: 20261019–20261027.

## Hasil backtest (yang sudah ada — terverifikasi 2 implementasi)

- **XAUUSD M1, 22 Sep–19 Okt 2026 (27.450 bar, 27 hari): 1.268 trade, winrate 44,2%, Profit Factor 0,56, total −283,8R, max drawdown 285,3R — RUGI BESAR.**
- Kedua sub-periode rugi: 22 Sep–05 Okt (n=668, PF 0,55) dan 06–19 Okt (n=599, PF 0,58).
- Sweep 6 variasi parameter SEMUA rugi (PF 0,49–0,69). Varian terbaik (trail rapat 100/50) masih PF 0,69.
- Verifikasi: dua implementasi independen (pandas dan pure Python) awalnya selisih maxDD tepat 1,0 — diperlakukan sebagai bug, diperbaiki, lalu SEMUA metrik identik di 6/6 sweep.

## Kenapa backtest 5 tahun tidak feasible

- EA M1: 5 tahun = ~2,6 juta bar. Yahoo membatasi M1 maksimal 60 hari. Dukascopy M1 5 tahun secara teknis bisa diunduh, tapi itu ribuan file per jam dan jutaan bar — dan hasilnya sudah jelas dari 27 hari + 1.268 trade + sweep 6 varian: tidak ada varian yang profit. Trailing stop tidak menyelamatkan entry yang tidak punya edge.

## Pelajaran dari EA ini

- Trailing stop itu manajemen exit, BUKAN edge. Kalau sinyal entry-nya tidak punya keunggulan, trailing stop hanya mengubah cara kalahnya.
- EMA cross di M1 emas terlalu berisik: sinyal datang dan pergi sebelum harga sempat bergerak cukup jauh untuk menutup spread + SL.
- Video TikTok yang menunjukkan EA ini profit adalah cherry-picking (hanya menampilkan periode yang bagus).
