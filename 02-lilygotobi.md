# LilyGotobiEA — Strategi Gotobi USDJPY (SELL jam 07:55 WIB)

**File:** `ea/LilyGotobiEA.mq5` — **Versi:** 1.00 — **Magic Number:** 20261024
**Simbol:** USDJPY — **Timeframe:** tidak peduli timeframe chart (murni berdasarkan jam)
**Status:** ✅ BERHASIL di backtest — juara winrate dari semua EA

## Idenya (penjelasan sederhana)

Di Jepang ada kebiasaan: tanggal 5, 10, 15, 20, 25, dan 30 setiap bulan disebut "tanggal gotobi" — hari ketika banyak perusahaan Jepang membayar tagihan, sehingga permintaan dolar naik dan yen biasanya melemah sebentar di pagi hari (harga USDJPY naik sebentar lalu balik turun). Video TikTok "TRADE BY DATA" mengklaim ada pola: SELL USDJPY tepat jam 07:55 WIB di tanggal gotobi cenderung profit kalau ditutup cepat jam 08:30. EA ini mengeksekusi pola itu secara otomatis, karena telat 1 menit saja katanya profitnya bisa turun 80%.

## Cara kerja langkah demi langkah

1. **Cek tanggal.** EA hanya trading di tanggal 5, 10, 15, 20, 25, 30 (WIB). Hari lain: diam.
2. **Cek hari.** Sabtu/Minggu pasar forex tutup, jadi tidak ada trade (tidak dihitung sebagai trade).
3. **Tepat 07:55 WIB — SELL.** EA jual market (SELL) USDJPY, 1 trade per hari. Ada toleransi telat 60 detik — kalau tick pertama datang setelah 07:55 tapi masih dalam 60 detik, tetap entry.
4. **Filter spread.** Kalau spread saat itu lebih dari 3,0 pip, hari itu di-skip (tidak entry).
5. **SL 10 pip.** Stop Loss dipasang 10 pip di atas harga entry.
6. **Time stop 08:30 WIB.** Kalau sampai 08:30 belum kena SL, posisi ditutup apa pun hasilnya (profit kecil atau rugi kecil). Tidak pernah dibiarkan jalan lebih lama.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari equity (bisa diubah lewat `InpRiskPct`).
- Lot dihitung otomatis dari jarak SL 10 pip. Karena SL-nya kecil, modal minimum EA ini paling kecil dari semua EA: sekitar Rp575 ribu di risiko 2% (SL 10 pip = $0,64 per 0,01 lot).
- Modal Rp1,2 juta sudah kelebihan untuk EA ini; modal ideal yang santai sekitar Rp2 juta.
- Jam dihitung dari `TimeGMT() + 7` (WIB), tanpa DST.

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpRiskPct | 2% | Risiko per trade |
| InpSLPips | 10 pip | Stop Loss |
| InpMaxSpreadPips | 3,0 pip | Spread maksimal saat entry |
| InpMaxLateSec | 60 detik | Toleransi telat entry |
| InpMagic | 20261024 | Nomor identitas EA |

## Hasil backtest (terverifikasi 2 implementasi independen)

**Periode terpanjang yang berhasil diuji: 5 TAHUN PENUH (18 Nov 2021 – 18 Nov 2026), data Dukascopy USD-JPY M5 (BID + 1 pip = mid sintetis, spread 2 pip).**
Ini satu-satunya EA yang berhasil di-backtest 5 tahun, karena data M5-nya bisa diunduh dari Dukascopy per hari gotobi saja.

| Periode | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|
| 5 tahun (Nov 2021–Nov 2026) | 252 | 51,2% | 1,57 | +57,64R | −11,12R |
| Tahun 1 (Nov 2021–Nov 2022) | 49 | 51,0% | 1,49 | +9,18R | — |
| Tahun 2 (Nov 2022–Nov 2023) | 50 | 54,0% | 1,59 | +11,00R | — |
| Tahun 3 (Nov 2023–Nov 2024) | 51 | 43,1% | 1,10 | +2,28R | — |
| Tahun 4 (Nov 2024–Nov 2025) | 51 | 56,9% | 2,47 | +30,83R | — |
| Tahun 5 (Nov 2025–Nov 2026) | 51 | 51,0% | 1,23 | +4,35R | — |

Hasil 1 tahun yang lama (10 Okt 2025–15 Okt 2026, data Yahoo M5): 52 trade, winrate 52%, PF 1,43, +8,63R. Jalur Dukascopy pada periode yang sama memberi 53 trade (ada 1 hari ekstra 25 Sep 2026 yang datanya tidak lengkap di Yahoo), winrate 52,8%, PF 1,43, +8,74R — 46 dari 52 trade hasilnya identik, 6 trade beda tipis karena feed berbeda. Ini validasi bahwa jalur Dukascopy bisa dipercaya.

**Yang harus dipahami:** Semua 5 tahunnya positif (tidak ada tahun yang rugi), tapi Tahun 3 hampir impas (+2,28R, PF 1,10) dan Tahun 4 sangat bagus (+30,83R). Rata-rata sekitar +11,5R per tahun. Backtest kontrol di hari biasa (bukan tanggal gotobi, aturan sama): PF 0,36, total −19,76R — RUGI. Jadi efeknya memang khusus tanggal gotobi, bukan sekadar "SELL pagi selalu profit".

## Cara pasang di MT5

1. Copy `LilyGotobiEA.mq5` ke folder `MQL5/Experts`, compile dengan F7.
2. Tempel di chart USDJPY (timeframe berapa saja, EA tidak peduli TF).
3. Pastikan jam di MT5 benar dan EA jalan sebelum 07:55 WIB — VPS atau laptop harus menyala.
4. Berikutnya (Jumat, 20 November 2026, 07:55 WIB) adalah tanggal gotobi berikutnya.

## Peringatan jujur

- Pola ini berdasarkan kebiasaan pembayaran perusahaan Jepang. Kalau kebiasaan itu berubah, edge-nya bisa hilang.
- Backtest memakai spread tetap 2 pip. Kalau spread broker melebar pagi-pagi, hasilnya bisa lebih jelek.
- SL 10 pip itu kecil — harga USDJPY bisa menyentuh SL hanya karena lonjakan sesaat.
