# LilyMACDEA — MACD Cross (12,26,9) + SL ATR (XAUUSD)

**File:** `ea/LilyMACDEA.mq5` — **Versi:** 1.10 — **Magic Number:** 20261026
**Simbol:** XAUUSD (emas) — **Timeframe:** H1
**Status:** ✅ BERHASIL di backtest (versi 1.10 yang pakai SL)

## Idenya (penjelasan sederhana)

MACD itu indikator yang membandingkan dua rata-rata harga (EMA 12 dan EMA 26). Kalau garis MACD menyalip garis sinyalnya ke atas, artinya momentum naik — ikut beli. Kalau menyalip ke bawah, momentum turun — ikut jual. EA ini "selalu di pasar": begitu ada sinyal berlawanan, posisi lama langsung ditutup dan posisi baru dibuka ke arah sebaliknya.

## Cara kerja langkah demi langkah

1. **Tiap bar H1 baru tutup, EA mengecek MACD(12, 26, 9).**
2. **Sinyal BUY (bull cross):** garis MACD barusan menyalip ke ATAS garis sinyal → tutup posisi SELL kalau ada, lalu BUY market.
3. **Sinyal SELL (bear cross):** garis MACD barusan menyalip ke BAWAH garis sinyal → tutup posisi BUY kalau ada, lalu SELL market.
4. **SL = 2 × ATR(14).** Sama seperti Donchian, SL dipasang sejauh 2 kali nafas normal harga emas (median sekitar $37,56 per 0,01 lot).
5. **Tidak ada TP.** Posisi hanya keluar lewat SL atau sinyal berlawanan. Jadi satu trade bisa berjalan lama mengikuti tren.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari equity (bisa diubah lewat `InpRiskPct`).
- Lot dihitung otomatis dari jarak SL (2× ATR).
- **PENTING — modal minimum:** sama seperti Donchian, sekitar Rp34 juta di risiko 2%. Di modal Rp1,2 juta, lot hitungannya di bawah minimum broker 0,01. EA versi 1.10 akan MENOLAK entry ("Tambah modal dulu ya, Thalib!") daripada memaksa entry.
- **Versi 1.00 (tanpa SL) sudah tidak dipakai.** Versi lama tanpa SL margin call di modal Rp1,2 juta (trade ke-24) dan di modal Rp10 juta sempat drawdown −76% (nyaris margin call). Jangan pakai versi lama.

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpFastEMA / InpSlowEMA / InpSignal | 12 / 26 / 9 | Parameter MACD standar |
| InpTF | H1 | Timeframe sinyal |
| InpAtrPeriod / InpAtrMult | 14 / 2,0 | SL = 2 × ATR(14) |
| InpRiskPct | 2% | Risiko per trade |
| InpMaxSpreadPts | 40 | Spread maksimal |
| InpMagic | 20261026 | Nomor identitas EA |

## Hasil backtest (terverifikasi 2 implementasi independen)

**Periode terpanjang yang berhasil diuji: 2 TAHUN (19 Nov 2024 – 18 Nov 2026), data GC=F H1 Yahoo Finance.**
Bukan 5 tahun — data H1 gratis dari Yahoo maksimal 729 hari.

| Periode | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|
| 2 tahun (Nov 2024–Nov 2026) | 476 | 35,3% | 1,19 | +36,51R | −16,34R |
| Tahun 1 (Nov 2024–Nov 2025) | 238 | 34,9% | 1,13 | +12,45R | −13,54R |
| Tahun 2 (Nov 2025–Nov 2026) | 238 | 35,7% | 1,24 | +24,05R | −16,34R |

Hasil 1 tahun yang lama (XAUUSD H1, data HistData M5): 223 trade, winrate 38%, PF 1,34, +32,0R.

**Yang harus dipahami:** Sama seperti Donchian, winrate-nya rendah (35%) tapi total profit karena kemenangan rata-rata lebih besar dari kekalahan. Trade-nya paling banyak dari semua EA (476 trade dalam 2 tahun) karena MACD sering memberi sinyal. Di proyeksi modal Rp50 juta risiko 8%, MACD+SL memberi +294% tapi dengan max drawdown −69% — modal sempat tinggal 31% di tengah jalan. Return besar tidak gratis: drawdown-nya brutal.

## Cara pasang di MT5

1. Copy `LilyMACDEA.mq5` ke folder `MQL5/Experts`, compile dengan F7.
2. Tempel di chart XAUUSD H1.
3. Pastikan modal cukup (minimal sekitar Rp34 juta di risiko 2%). Kalau modal kurang, EA menolak entry — itu pengaman.

## Peringatan jujur

- MACD adalah indikator yang lambat (lagging) — sinyal muncul setelah harga sudah bergerak. Di market sideways, MACD sering memberi sinyal palsu beruntun.
- Backtest memakai spread tetap $0,20, tanpa komisi/swap.
- Di modal kecil (Rp1,2–10 juta), EA ini TIDAK LAYAK jalan karena lot minimum broker.
