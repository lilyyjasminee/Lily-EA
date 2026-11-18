# LilyMeanReversionEA — Beli di Support, Jual di Resistance saat Sideways (ARSIP — GAGAL)

**File:** `ea/LilyMeanReversionEA.mq5` — **Versi:** 1.00 — **Magic Number:** 20261021
**Simbol:** XAUUSD (emas) — **Timeframe:** M1 (chart tempat ditempel)
**Status:** ❌ GAGAL di backtest — disimpan sebagai arsip pelajaran, JANGAN dipakai live

## Idenya (penjelasan sederhana)

Harga itu seperti karet gelang: kalau ditarik terlalu jauh ke satu arah, dia cenderung balik ke tengah. Saat market sideways (datar, tidak trending), harga memantul di antara "lantai" (support) dan "plafon" (resistance). EA ini beli murah di lantai dan jual mahal di plafon, lalu ulangi.

## Cara kerja langkah demi langkah

1. **Filter sideways dulu.** EA hanya trading kalau ADX(14) di bawah 20 — artinya market sedang datar, bukan trending. Kalau ADX tinggi (trending), EA diam.
2. **Cari boundary range.** Cari swing low terakhir (support) dan swing high terakhir (resistance) dalam 50 bar terakhir (fractal, kekuatan 3 bar). Tinggi range harus wajar: 150–500 point. Kalau range terlalu sempit atau terlalu lebar, skip.
3. **Sinyal BUY:** harga menyentuh zona support (bid ≤ support + 0,3 × ATR) DAN RSI(14) di bawah 40 (harga sudah "murah"/oversold) → BUY. SL di bawah support + 50 point. TP di resistance − 30 point.
4. **Sinyal SELL:** harga menyentuh zona resistance (ask ≥ resistance − 0,3 × ATR) DAN RSI(14) di atas 60 (harga sudah "mahal"/overbought) → SELL. SL di atas resistance + 50 point. TP di support + 30 point.
5. **Break-even** saat profit 80 point, **trailing stop** saat profit 120 point (jarak 60 point).
6. **Satu posisi dalam satu waktu.** Filter spread maksimal 40 point.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari equity, lot dihitung dari jarak SL.
- Kalau lot hitungan di bawah minimum broker, dipakai lot minimum (risiko aktual lebih besar dari 2%).

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpRangeLookback / InpSwingStrength | 50 / 3 | Cari swing 50 bar ke belakang |
| InpMinRangePoints / InpMaxRangePoints | 150 / 500 | Tinggi range yang diterima |
| InpADXMax | 20 | ADX di bawah ini = sideways |
| InpRSIBuyMax / InpRSISellMin | 40 / 60 | Filter RSI |
| InpZoneATRMult | 0,3 | Toleransi zona entry (× ATR) |
| InpSLBufferPoints / InpTPBufferPoints | 50 / 30 | Buffer SL dan TP dari boundary |
| InpRiskPercent | 2% | Risiko per trade |
| InpMagic | 20261021 | Nomor identitas EA |

## Hasil backtest (yang sudah ada — dan ada koreksi penting)

- **XAUUSD M1, 22 Sep–19 Okt 2026: Profit Factor 0,39–0,62 (n=147), sweep 10 variasi SEMUA rugi.**
- **Koreksi jujur (20 Oktober 2026):** hasil awal simulasi sempat menunjukkan PF 1,22 (kelihatan profit) — ternyata itu BUG di simulasinya sendiri: entry diisi di harga open di bawah zona (harga terlalu bagus), tanpa cek jarak minimum EA, dan tanpa mengelola posisi di bar entry. Setelah bug diperbaiki, hasilnya rugi. Lily mengakui bug ini ke Thalib secara terbuka. Pelajaran: inilah gunanya backtest dengan 2 implementasi — bug ketahuan dalam hitungan jam, bukan setelah rugi berminggu-minggu.
- Winrate pastinya TIDAK tercatat (data hilang saat VM di-redeploy).
- Di JP225 M30 juga diuji: PF 0,29–0,46 — rugi juga.

## Kenapa backtest 5 tahun tidak feasible

- Sama seperti SpikeFade: EA M1, data 5 tahun berarti ~2,6 juta bar, sumber gratis membatasi M1 maksimal 60 hari. Hasil pendek + sweep 10 variasi yang semuanya rugi sudah cukup untuk menyatakan tidak ada edge.

## Pelajaran dari EA ini

- Support/resistance yang terlihat jelas di chart sering jebol tepat saat kita entry — "lantai" ternyata bukan lantai.
- Bug simulasi bisa membuat strategi rugi terlihat profit. Selalu verifikasi dengan implementasi kedua sebelum percaya pada angka backtest.
