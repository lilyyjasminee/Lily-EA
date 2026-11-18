# LilyConfluenceEA — MA Cross + Support/Resistance + Supply/Demand (ARSIP — GAGAL)

**File:** `ea/LilyConfluenceEA.mq5` — **Versi:** 1.00 — **Magic Number:** 20261019
**Simbol:** apa saja (EA memakai timeframe chart tempat ia ditempel — `PERIOD_CURRENT`)
**Status:** ❌ GAGAL di backtest — disimpan sebagai arsip pelajaran, JANGAN dipakai live

## Idenya (penjelasan sederhana)

EA ini menggabungkan tiga hal sekaligus (confluence = bertemunya banyak sinyal):
1. **Arah** dari persilangan EMA 9 dan EMA 21 (EMA cepat menyalip ke atas = tren naik).
2. **Lokasi** dari zona support/resistance dan supply/demand — dihitung otomatis dari titik-titik swing high/low 50 bar terakhir.
3. Hanya entry kalau arah DAN lokasi setuju: BUY hanya kalau bull cross DAN harga sedang dekat zona support/demand, SELL hanya kalau bear cross DAN harga dekat zona resistance/supply.

Idenya masuk akal: jangan beli di tengah jalan, belilah di "lantai" (support). Masalahnya, robot tidak bisa "membaca" chart seperti manusia — zonanya hanya perkiraan dari swing-swing lama.

## Cara kerja langkah demi langkah

1. **Tiap bar baru, EA mengecek persilangan EMA 9 dan EMA 21** pada bar yang sudah tutup.
2. **Hitung zona.** Cari semua swing high (resistance/supply) dan swing low (support/demand) dalam 50 bar terakhir, dengan kekuatan swing 3 bar kiri-kanan.
3. **Cek kedekatan zona.** Harga harus berada dalam jarak 0,5 × ATR dari salah satu zona. Kalau tidak dekat zona mana pun, sinyal dilewati.
4. **BUY:** bull cross + harga dekat support → BUY dengan SL = 1,5 × ATR, TP = 2 × SL (RR 1:2).
5. **SELL:** bear cross + harga dekat resistance → SELL dengan SL = 1,5 × ATR, TP = 2 × SL.
6. **Satu posisi dalam satu waktu.** Tidak ada trailing stop atau break-even.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari saldo.
- Lot dihitung otomatis dari jarak SL (1,5 × ATR).
- SL = 1,5 × ATR(14), TP = 2 × SL.

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpMAFast / InpMASlow | 9 / 21 | EMA cepat dan lambat |
| InpLookback / InpSwing | 50 / 3 | Cari zona 50 bar ke belakang |
| InpZoneTolATR | 0,5 | Toleransi jarak ke zona (× ATR) |
| InpATRPeriod / InpSL_ATR | 14 / 1,5 | SL = 1,5 × ATR |
| InpRR | 2,0 | TP = 2 × SL |
| InpRiskPct | 2% | Risiko per trade |
| InpMagic | 20261019 | Nomor identitas EA |

## Hasil backtest (yang sudah ada)

- **XAUUSD (periode pendek): 20 trade, winrate 25%, Profit Factor 0,67, total −5R — RUGI.**
- Tanpa filter zona (hanya MA cross saja): PF 0,96 — tetap di bawah 1.
- **Backtest 5 tahun TIDAK FEASIBLE.** EA ini memakai timeframe chart (M1 saat diuji) dan zona swing yang harus dihitung per bar. Data M1 gratis maksimal 60 hari (Yahoo) — 5 tahun M1 berarti sekitar 2,6 juta bar dan butuh unduhan HistData/Dukascopy bulanan yang sangat besar. Hasil pendek yang sudah ada (PF 0,67) sudah cukup untuk menyatakan EA ini tidak punya edge — tidak ada alasan menghabiskan waktu untuk backtest 5 tahun pada strategi yang sudah kalah di periode pendek.

## Pelajaran dari EA ini

- Menggabungkan banyak indikator tidak otomatis membuat strategi bagus. Tiga filter yang masing-masing lemah, digabung, tetap lemah.
- Zona support/resistance otomatis dari swing lama sering sudah tidak relevan saat harga sampai di sana.
- EA ini adalah EA pertama yang dibuat (magic 20261019, paling kecil) — wajar kalau belum bagus. Disimpan di repo sebagai bukti proses belajar, bukan untuk dipakai.
