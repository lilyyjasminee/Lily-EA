# LilySpikeFadeEA — Fade Spike: Lawan Lonjakan Candle (ARSIP — GAGAL)

**File:** `ea/LilySpikeFadeEA.mq5` — **Versi:** 1.10 — **Magic Number:** 20261022
**Simbol:** XAUUSD (emas) — **Timeframe:** M1 (chart tempat ditempel)
**Status:** ❌ GAGAL di backtest — disimpan sebagai arsip pelajaran, JANGAN dipakai live

## Idenya (penjelasan sederhana)

Kalau satu candle emas melonjak panjang ke atas dalam 1 menit, mungkin harga sudah "kepanasan" dan akan balik turun sebentar — jadi JUAL di puncak. Sebaliknya, kalau candle terjun panjang ke bawah, mungkin akan balik naik sebentar — jadi BELI di lembah. Profit diambil kecil-kecil dan cepat ("profit langsung diamankan"), SL juga kecil. Ini idenya Thalib sendiri: "profit langsung diclose, SL kecil".

## Cara kerja langkah demi langkah

1. **Tiap candle M1 baru tutup, EA mengukur dorongannya.** Dorongan ke atas = High − Open, dorongan ke bawah = Open − Low.
2. **Sinyal SELL:** dorongan ke atas ≥ 80 point dan lebih besar dari dorongan ke bawah → SELL market di harga bid. SL di atas puncak candle + 30 point. TP 100 point di bawah entry.
3. **Sinyal BUY:** dorongan ke bawah ≥ 80 point dan lebih besar dari dorongan ke atas → BUY market. SL di bawah lembah candle + 30 point. TP 100 point di atas entry.
4. **Break-even:** kalau profit sudah 50 point, SL digeser ke harga entry + 5 point.
5. **Trailing stop:** kalau profit sudah 70 point, SL mengikuti harga dengan jarak 35 point.
6. **Satu posisi dalam satu waktu.** Filter spread maksimal 40 point.

## Perbaikan v1.00 → v1.10 (20 Oktober 2026)

Versi 1.00 punya TP 50 point ($0,50) sedangkan spread emas sekitar $0,20–0,35 — profit bersih hanya sekitar $0,25 melawan SL $0,60+. Butuh winrate 64% hanya untuk impas. Itu tidak sehat, jadi di v1.10 TP dinaikkan ke 100 point ($1,00), pemicu break-even 30 → 50 point, trailing 40/25 → 70/35 point.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari equity, lot dihitung dari jarak SL.
- Kalau lot hitungan di bawah minimum broker, dipakai lot minimum (risiko aktual jadi lebih besar dari 2% — hati-hati).

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpSpikePoints | 80 | Panjang dorongan minimal (point) |
| InpTakeProfit | 100 point | TP ($1,00 di XAUUSD) |
| InpSLBuffer | 30 point | SL di luar puncak/lembah + buffer |
| InpBETTrigger / InpBETOffset | 50 / 5 | Pemicu dan offset break-even |
| InpTrailTrigger / InpTrailDistance | 70 / 35 | Pemicu dan jarak trailing |
| InpRiskPercent | 2% | Risiko per trade |
| InpMagic | 20261022 | Nomor identitas EA |

## Hasil backtest (yang sudah ada)

- **XAUUSD M1, 22 Sep–19 Okt 2026 (27 hari): Profit Factor 0,42–0,69 di 12 kombinasi parameter (sweep) — SEMUA rugi.** Tidak ada satu pun varian yang profit.
- Winrate pastinya TIDAK tercatat — datanya hilang saat VM di-redeploy. Yang tercatat hanya rentang PF-nya.
- Thalib sendiri yang menjalankan EA ini di awal dan melaporkan loss lebih sering dari profit — cocok dengan hasil backtest.

## Kenapa backtest 5 tahun tidak feasible

- EA ini M1: 5 tahun data M1 emas berarti sekitar 2,6 juta bar. Yahoo Finance membatasi M1 maksimal 60 hari per unduhan. Dukascopy/HistData memang punya M1 bertahun-tahun, tapi mengunduh dan mengolah 2,6 juta bar hanya untuk menguji ulang strategi yang sudah kalah di 12 variasi parameter adalah buang waktu. Kesimpulan "tidak punya edge" sudah kuat dari data 27 hari + sweep 12 varian.

## Pelajaran dari EA ini

- Melawan arah (fade) di timeframe 1 menit itu seperti menangkap pisau jatuh — harga yang melonjak sering lanjut melonjak.
- TP kecil melawan spread besar adalah matematika yang kalah sebelum mulai: biaya spread memakan sebagian besar profit.
