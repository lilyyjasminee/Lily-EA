# LilyDonchianEA — Donchian Breakout 20/10 + SL ATR (XAUUSD)

**File:** `ea/LilyDonchianEA.mq5` — **Versi:** 1.10 — **Magic Number:** 20261025
**Simbol:** XAUUSD (emas) — **Timeframe:** H1
**Status:** ✅ BERHASIL di backtest (versi 1.10 yang pakai SL)

## Idenya (penjelasan sederhana)

Donchian Channel itu seperti melihat harga tertinggi dan terendah 20 jam terakhir. Kalau harga hari ini menembus harga tertinggi 20 jam terakhir, artinya tren naik sedang kuat — ikut beli. Kalau harga menembus harga terendah 20 jam terakhir, artinya tren turun sedang kuat — ikut jual. Ini strategi ikut tren (trend following) yang sudah dipakai sejak era Turtle Traders tahun 1980-an.

## Cara kerja langkah demi langkah

1. **Tiap bar H1 baru tutup, EA mengecek harga penutupan (close).**
2. **Sinyal BUY:** close bar terakhir lebih tinggi dari harga tertinggi 20 bar sebelumnya → BUY market.
3. **Sinyal SELL:** close bar terakhir lebih rendah dari harga terendah 20 bar sebelumnya → SELL market.
4. **SL = 2 × ATR(14).** ATR itu ukuran "nafas" harga emas per jam. SL dipasang sejauh 2 kali nafas normal dari harga entry. SL median sekitar $37,56 per 0,01 lot.
5. **Exit (tutup posisi):** posisi BUY ditutup kalau close bar terakhir turun di bawah harga terendah 10 bar terakhir. Posisi SELL ditutup kalau close naik di atas harga tertinggi 10 bar terakhir. Atau kena SL duluan.
6. **Satu posisi dalam satu waktu.** EA tidak membuka posisi baru kalau masih ada posisi lama.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari equity (bisa diubah lewat `InpRiskPct`).
- Lot dihitung otomatis dari jarak SL (2× ATR).
- **PENTING — modal minimum:** karena SL emas besar ($37,56 per 0,01 lot), modal minimum di risiko 2% adalah sekitar Rp34 juta. Di modal Rp1,2 juta, lot hitungannya 0,0004 — jauh di bawah minimum broker 0,01. EA versi 1.10 akan MENOLAK entry dan menulis di log "Tambah modal dulu ya, Thalib!" daripada memaksa entry dengan risiko 56% per trade.
- **Versi 1.00 (tanpa SL) sudah tidak dipakai.** Versi lama tanpa SL margin call di modal Rp1,2 juta (trade ke-12). Jangan pakai versi lama.

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpEntryPeriod | 20 | Channel entry (tertinggi/terendah 20 bar) |
| InpExitPeriod | 10 | Channel exit (tertinggi/terendah 10 bar) |
| InpTF | H1 | Timeframe sinyal |
| InpAtrPeriod / InpAtrMult | 14 / 2,0 | SL = 2 × ATR(14) |
| InpRiskPct | 2% | Risiko per trade |
| InpMaxSpreadPts | 40 | Spread maksimal |
| InpMagic | 20261025 | Nomor identitas EA |

## Hasil backtest (terverifikasi 2 implementasi independen)

**Periode terpanjang yang berhasil diuji: 2 TAHUN (19 Nov 2024 – 18 Nov 2026), data GC=F H1 Yahoo Finance.**
Bukan 5 tahun — data H1 gratis dari Yahoo maksimal 729 hari.

| Periode | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|
| 2 tahun (Nov 2024–Nov 2026) | 312 | 35,9% | 1,23 | +39,04R | −14,44R |
| Tahun 1 (Nov 2024–Nov 2025) | 158 | 36,1% | 1,32 | +26,97R | −14,44R |
| Tahun 2 (Nov 2025–Nov 2026) | 154 | 35,7% | 1,14 | +12,07R | −11,47R |

Hasil 1 tahun yang lama (XAUUSD H1, data HistData M5): 153 trade, winrate 35%, PF 1,17, +14,4R.

**Yang harus dipahami:** Winrate-nya rendah (hanya 36% — kalah 2 dari 3 trade), tapi sekali menang, menangnya besar, sehingga total tetap profit. Strategi seperti ini berat secara mental: harus siap kalah beruntun. Di modal Rp50 juta dengan risiko 8%, Donchian+SL justru −4% (volatility drag) — risiko besar tidak selalu menambah profit.

## Cara pasang di MT5

1. Copy `LilyDonchianEA.mq5` ke folder `MQL5/Experts`, compile dengan F7.
2. Tempel di chart XAUUSD H1.
3. Pastikan modal cukup (minimal sekitar Rp34 juta di risiko 2%). Kalau modal kurang, EA akan menolak entry — itu fitur pengaman, bukan error.

## Peringatan jujur

- Backtest memakai spread tetap $0,20, tanpa komisi/swap. Live bisa lebih jelek.
- Di modal kecil (Rp1,2–10 juta), EA ini TIDAK LAYAK jalan karena lot minimum broker. Ini bukan salah EA-nya — tapi SL-nya yang besar.
