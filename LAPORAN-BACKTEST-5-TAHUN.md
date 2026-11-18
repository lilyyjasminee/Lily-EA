# Laporan Backtest EA Lily — "5 Tahun" yang Sebenarnya

**Tanggal laporan:** 18 November 2026
**Dibuat oleh:** Lily untuk Thalib
**Aturan yang dipakai:** setiap angka di bawah ini dihitung dengan 2 implementasi independen (skill `verify_simulation_results`). Kalau kedua implementasi tidak cocok persis, angkanya tidak dilaporkan.

## Jawaban singkat yang jujur

**Backtest 5 tahun penuh HANYA berhasil untuk 1 dari 9 EA: LilyGotobiEA.**
Untuk 3 EA lain (ORB, Donchian, MACD) periode maksimal yang berhasil adalah **2 tahun**, karena data 1 jam gratis dari Yahoo Finance dibatasi maksimal 729 hari. Untuk 5 EA sisanya (M1 dan hedging), backtest 5 tahun tidak feasible dan tidak dikerjakan — alasannya dijelaskan per EA di bawah.

Tidak ada angka di laporan ini yang dikarang. Kalau tertulis "tidak ada data", artinya memang tidak ada.

## 1. Batas data: apa yang bisa dan tidak bisa didapat gratis

Diuji langsung tanggal 18 November 2026:

| Sumber | Interval | Permintaan 5 tahun (Nov 2021–Nov 2026) | Hasil |
|---|---|---|---|
| Yahoo Finance chart API (`^N225`, `JPY=X`, `GC=F`) | 1 jam | HTTP 422: "1h data not available... requested range must be within the last 730 days" | ❌ Gagal |
| Yahoo Finance chart API | 1 jam, 730 hari persis | HTTP 422 | ❌ Gagal |
| Yahoo Finance chart API | 1 jam, 729 hari | Berhasil | ✅ Maksimal ~2 tahun |
| Yahoo Finance chart API | 1 hari | Berhasil (1.221–1.305 bar) | ✅ Tapi tidak berguna untuk strategi intraday |
| Dukascopy (datafeed publik, via `dukascopy-python`) | 5 menit | Berhasil per hari gotobi | ✅ Dipakai untuk Gotobi 5 tahun |
| Yahoo Finance | 1 menit | Maksimal 60 hari | ❌ Tidak cukup untuk 5 tahun |

**Kenapa data harian 5 tahun tidak dipakai untuk backtest?** Semua EA di repo ini butuh harga di dalam hari (jam 07:00, 07:55, penutupan bar H1/M1). Data harian hanya punya 1 harga open/high/low/close per hari — tidak bisa menjawab "apakah harga menyentuh SL jam 08:10?" Jadi data harian 5 tahun hanya disimpan sebagai referensi (`data/*_1d.csv`), bukan untuk backtest.

**Detail penting soal JP225:** data 1 jam simbol `^N225` (indeks Nikkei) hanya punya ~7 bar per hari — jam perdagangannya pendek dan ada jeda makan siang. File backtest 1 tahun yang lama (`jp225_h1.csv`, ~22 bar/hari, timezone Amerika/New_York) ternyata cocok dengan **NIY=F (Nikkei 225 futures)** yang diperdagangkan hampir 24 jam. Karena itu backtest 2 tahun ORB memakai NIY=F, bukan ^N225. Data `^N225` 1 jam tetap disimpan di `data/` sebagai pembanding.

**Bar kosong (NaN) di data Yahoo:** file NIY=F 1 jam 729 hari berisi 3.071 bar kosong dari 14.498 bar, dan GC=F berisi 3.059 bar kosong dari 14.498 bar (jam-jam bursa tutup / tidak ada data). Bar kosong ini dibuang sebelum backtest. Satu bar kosong sempat membuat implementasi pertama ORB menghasilkan NaN — diperlakukan sebagai bug, diperbaiki, lalu kedua implementasi cocok persis.

## 2. LilyGotobiEA — 5 TAHUN PENUH ✅

**Periode:** 18 November 2021 – 18 November 2026 (trade pertama 25 Nov 2021, terakhir 10 Nov 2026)
**Data:** Dukascopy USD-JPY M5 (BID + 1 pip = mid sintetis, spread 2 pip — sama seperti backtest 1 tahun yang memakai Yahoo mid + spread 1 pip/sisi)
**Aturan:** SELL 07:55 WIB tanggal 5/10/15/20/25/30 (hari kerja saja), SL 10 pip, tutup 08:30 WIB

| Periode | Trade | Winrate | Profit Factor | Total | Keterangan |
|---|---|---|---|---|---|
| **5 tahun (Nov 2021–Nov 2026)** | **252** | **51,2%** | **1,57** | **+57,64R** | **Max DD −11,12R** |
| Tahun 1 (Nov 2021–Nov 2022) | 49 | 51,0% | 1,49 | +9,18R | |
| Tahun 2 (Nov 2022–Nov 2023) | 50 | 54,0% | 1,59 | +11,00R | |
| Tahun 3 (Nov 2023–Nov 2024) | 51 | 43,1% | 1,10 | +2,28R | Tahun terlemah, hampir impas |
| Tahun 4 (Nov 2024–Nov 2025) | 51 | 56,9% | 2,47 | +30,83R | Tahun terbaik |
| Tahun 5 (Nov 2025–Nov 2026) | 51 | 51,0% | 1,23 | +4,35R | |

**Verifikasi:**
- Implementasi A (event loop per hari) dan Implementasi B (pandas, baca CSV tersimpan) menghasilkan **252/252 trade identik, 0 perbedaan R**.
- Validasi jalur Dukascopy pada periode 1 tahun yang sudah terverifikasi (10 Okt 2025–15 Okt 2026): Dukascopy memberi 53 trade, WR 52,8%, PF 1,43, +8,74R vs Yahoo 52 trade, WR 51,9%, PF 1,43, +8,63R. 46 dari 52 trade hasilnya identik sampai 0,001R; 6 trade beda tipis karena feed berbeda (terbesar: 10 Mar 2026, +0,64R vs −0,69R — perbedaan sentuhan SL). Satu hari ekstra (25 Sep 2026) ada di Dukascopy tapi datanya tidak lengkap di Yahoo. Agregatnya hampir sama — jalur Dukascopy bisa dipercaya.
- Backtest kontrol hari biasa (aturan sama di tanggal bukan gotobi): PF 0,36, −19,76R — efeknya memang khusus tanggal gotobi.

**File bukti:** `data/gotobi_dukas_m5_y5a.csv` … `y5e.csv` (6.046 bar M5), `gotobi_dukas_y5a.json` … `y5e.json`, `gotobi_dukas_y5_verify.json`, script `gotobi_dukas.py`, `gotobi_5y_chunk.py`, `gotobi_5y_verify.py`.

## 3. LilyORBEA — 2 TAHUN (maksimal Yahoo H1) ⚠️

**Periode:** 19 November 2024 – 18 November 2026 (729 hari, batas Yahoo)
**Data:** NIY=F H1 Yahoo Finance (11.427 bar valid setelah buang 3.071 bar kosong)
**Aturan:** kotak 07:00–08:00 WIB, min lebar 0,15%, BuyStop/SellStop OCO, SL sisi berlawanan, TP 1,5× lebar, flat 13:00, spread 10 point, 1 trade/hari

| Periode | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|
| **2 tahun (Nov 2024–Nov 2026)** | **457** | **46,8%** | **1,10** | **+12,09R** | **−18,43R** |
| Tahun 1 (Nov 2024–Nov 2025) | 226 | 43,4% | 0,94 | −3,58R | −18,43R |
| Tahun 2 (Nov 2025–Nov 2026) | 231 | 50,2% | 1,26 | +15,68R | −7,37R |

Hasil: TP 50, SL 82, FLAT 325 (71% trade berakhir flat jam 13:00). BUY 229, SELL 228.
Ekuitas $1.000: risiko 3% → $1.291,30 (+29,1%), max DD −$539,25. Risiko 2% (aturan Thalib) → $1.214,29 (+21,4%), max DD −$363,00.

**Verifikasi:**
- Sanity check: kedua implementasi dijalankan dulu pada file 1 tahun lama dan mereproduksi persis angka terverifikasi (229 trade, WR 47,6%, PF 1,19, +11,78R, $1.347,62, FLAT 163/SL 40/TP 26).
- Pada data 2 tahun, kedua implementasi menghasilkan **457/457 R identik**.
- **Peringatan terpenting:** Tahun 1 RUGI (PF 0,94). Edge ORB tipis dan tidak stabil tiap tahun. Total 2 tahun positif hanya karena Tahun 2 bagus.

**File bukti:** `orb_2y_trades_simA.csv`, `orb_2y_simA.py`, `orb_2y_simB.py`, `data/NIYF_1h_729d.csv`, `data/NIYF_1h_729d_et.csv`.

## 4. LilyDonchianEA v1.10 (+SL) — 2 TAHUN (maksimal Yahoo H1) ⚠️

**Periode:** 19 November 2024 – 18 November 2026 (data efektif 25 Nov 2024 setelah warmup 100 bar)
**Data:** GC=F H1 Yahoo Finance (11.339 bar valid setelah buang 3.059 bar kosong)
**Aturan:** Donchian 20/10 H1, SL 2× ATR(14), spread $0,20, sinyal bar tutup → entry open bar berikut, SL-first

| Periode | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|
| **2 tahun (Nov 2024–Nov 2026)** | **312** | **35,9%** | **1,23** | **+39,04R** | **−14,44R** |
| Tahun 1 | 158 | 36,1% | 1,32 | +26,97R | −14,44R |
| Tahun 2 | 154 | 35,7% | 1,14 | +12,07R | −11,47R |

ATR(14) H1 median $16,33 (SL 2× = $32,65). Bandingkan hasil 1 tahun lama (data HistData M5): 153 trade, WR 35%, PF 1,17, +14,4R — konsisten (winrate dan PF mirip, total R lebih besar karena periode 2× lipat).

**Verifikasi:** kedua implementasi menghasilkan **312/312 R identik** (termasuk median ATR $16,33 yang sama persis).

## 5. LilyMACDEA v1.10 (+SL) — 2 TAHUN (maksimal Yahoo H1) ⚠️

**Periode:** 19 November 2024 – 18 November 2026 (data efektif 25 Nov 2024)
**Data:** GC=F H1 Yahoo Finance (sama dengan Donchian)
**Aturan:** MACD(12,26,9) cross H1, SL 2× ATR(14), spread $0,20, selalu di pasar (flip saat cross berlawanan)

| Periode | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|
| **2 tahun (Nov 2024–Nov 2026)** | **476** | **35,3%** | **1,19** | **+36,51R** | **−16,34R** |
| Tahun 1 | 238 | 34,9% | 1,13 | +12,45R | −13,54R |
| Tahun 2 | 238 | 35,7% | 1,24 | +24,05R | −16,34R |

Bandingkan hasil 1 tahun lama: 223 trade, WR 38%, PF 1,34, +32,0R.

**Verifikasi:** kedua implementasi menghasilkan **476/476 R identik**.

**File bukti (Donchian + MACD):** `donch_macd_2y_simA.py`, `donch_macd_2y_simB.py`, `donch_macd_2y_simA.json`, `donch_macd_2y_simB.json`, `data/GCF_1h_729d.csv`.

## 6. Lima EA yang TIDAK di-backtest 5 tahun — dan alasannya

| EA | Alasan | Hasil yang sudah ada (dipakai sebagai ganti) |
|---|---|---|
| LilyConfluenceEA v1.00 | M1 + zona swing; data M1 gratis maks 60 hari; 5 thn M1 ≈ 2,6 juta bar | 20 trade, WR 25%, PF 0,67, −5R — rugi |
| LilySpikeFadeEA v1.10 | M1; alasan sama; 12 variasi parameter sudah semua rugi | PF 0,42–0,69 (sweep 12 varian) — rugi |
| LilyMeanReversionEA v1.00 | M1; alasan sama; 10 variasi sudah semua rugi | PF 0,39–0,62 (n=147) — rugi |
| LilyTrailEA v1.00 | M1; alasan sama; 1.268 trade 27 hari sudah cukup membuktikan | n=1.268, WR 44,2%, PF 0,56, −283,8R — rugi besar |
| LilyHedgeEA v1.31 | Belum pernah di-backtest sama sekali; logika hedging flip + pending order tidak bisa diuji dengan backtest bar sederhana | Tidak ada angka — jangan dipakai sebelum ada bukti |

Prinsipnya: kalau sebuah strategi sudah kalah di periode pendek DENGAN sweep parameter yang semuanya negatif, menghabiskan waktu mengunduh jutaan bar untuk menguji 5 tahun tidak akan mengubah kesimpulan — hanya menghabiskan waktu. Yang dibutuhkan strategi-strategi itu bukan data lebih panjang, tapi ide entry yang benar-benar berbeda.

## 7. Asumsi yang dipakai semua backtest (baca sebelum percaya angka)

1. **Spread tetap** (ORB 10 point, Gotobi 2 pip, Donchian/MACD $0,20). Spread live berubah-ubah dan biasanya melebar di jam sepi.
2. **Tanpa slippage, tanpa gap, tanpa komisi/swap.** Fill diasumsikan selalu dapat di harga yang dimodelkan.
3. **SL-first (konservatif):** kalau satu bar menyentuh SL dan TP sekaligus, dihitung kena SL dulu.
4. **Hasil dalam R** (kelipatan risiko per trade), bukan rupiah/dolar — supaya hasilnya tidak tergantung besar modal. Konversi ke uang memakai risiko 2% atau 3% per trade, compounding.
5. **Posisi yang masih terbuka di akhir data** (Donchian/MACD) tidak dihitung — sama seperti script 1 tahun yang lama.
6. **Data Yahoo dan Dukascopy adalah data feed publik, bukan data broker Exness Thalib.** Harga broker bisa sedikit berbeda, terutama spread dan jam perdagangan.
7. **Backtest bukan janji profit.** Forward-test demo tetap bukti utama. Tahun 1 ORB yang rugi adalah buktinya: strategi yang totalnya profit pun bisa rugi setahun penuh.

## 8. Tabel ringkasan semua EA

| EA | Versi | Periode teruji | Trade | Winrate | PF | Total | Status |
|---|---|---|---|---|---|---|---|
| LilyGotobiEA | 1.00 | **5 thn** | 252 | 51,2% | 1,57 | +57,64R | ✅ Berhasil |
| LilyORBEA | 1.10 | 2 thn | 457 | 46,8% | 1,10 | +12,09R | ✅ Berhasil (tipis) |
| LilyDonchianEA | 1.10 | 2 thn | 312 | 35,9% | 1,23 | +39,04R | ✅ Berhasil |
| LilyMACDEA | 1.10 | 2 thn | 476 | 35,3% | 1,19 | +36,51R | ✅ Berhasil |
| LilyConfluenceEA | 1.00 | pendek | 20 | 25% | 0,67 | −5R | ❌ Gagal |
| LilySpikeFadeEA | 1.10 | 27 hari | — | tidak tercatat | 0,42–0,69 | rugi | ❌ Gagal |
| LilyMeanReversionEA | 1.00 | 27 hari | 147 | tidak tercatat | 0,39–0,62 | rugi | ❌ Gagal |
| LilyTrailEA | 1.00 | 27 hari | 1.268 | 44,2% | 0,56 | −283,8R | ❌ Gagal |
| LilyHedgeEA | 1.31 | — | — | — | — | — | ⚠️ Belum diuji |

Juara winrate 5 tahun/2 tahun: 🥇 Gotobi 51,2% — 🥈 ORB 46,8% — 🥉 Donchian 35,9%.
