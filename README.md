# LilyEA — Kumpulan EA Trading Lily untuk Thalib

Repo ini berisi **9 Expert Advisor (EA) MetaTrader 5** yang dibuat Lily untuk Thalib, lengkap dengan penjelasan tiap EA dan laporan backtest-nya.

> ⚠️ **PENTING — BACA DULU:** Ini BUKAN janji profit. 4 EA berhasil di backtest, 4 EA terbukti rugi, 1 EA belum pernah diuji. Semua EA di repo ini pernah atau sedang diuji di **akun demo**. Jangan pakai uang sungguhan sebelum paham risikonya dan sudah forward-test sendiri. Trading adalah edukasi, bukan saran finansial.

## Daftar EA

### ✅ Berhasil di backtest (4 EA — layak forward-test demo)

| # | EA | Versi | Magic | Simbol / TF | Penjelasan |
|---|---|---|---|---|---|
| 1 | LilyORBEA | 1.10 | 20261023 | JP225 / M30 | Opening Range Breakout sesi Tokyo 07:00–08:00 WIB ([detail](01-lilyorbea.md)) |
| 2 | LilyGotobiEA | 1.00 | 20261024 | USDJPY / jam | SELL 07:55 WIB tanggal gotobi 5/10/15/20/25/30 ([detail](02-lilygotobi.md)) |
| 3 | LilyDonchianEA | 1.10 | 20261025 | XAUUSD / H1 | Donchian 20/10 + SL 2× ATR ([detail](03-lilydonchian.md)) |
| 4 | LilyMACDEA | 1.10 | 20261026 | XAUUSD / H1 | MACD cross + SL 2× ATR ([detail](04-lilymacd.md)) |

### ❌ Gagal di backtest (4 EA — arsip pelajaran, JANGAN dipakai live)

| # | EA | Versi | Magic | Simbol / TF | Penjelasan |
|---|---|---|---|---|---|
| 5 | LilyConfluenceEA | 1.00 | 20261019 | bebas / chart | MA cross + zona Support/Resistance ([detail](05-lilyconfluence.md)) |
| 6 | LilySpikeFadeEA | 1.10 | 20261022 | XAUUSD / M1 | Fade spike candle (lawan lonjakan) ([detail](06-lilyspikefade.md)) |
| 7 | LilyMeanReversionEA | 1.00 | 20261021 | XAUUSD / M1 | Beli support / jual resistance saat sideways ([detail](07-lilymeanreversion.md)) |
| 8 | LilyTrailEA | 1.00 | 20261027 | XAUUSD / M1 | EMA cross + trailing stop ([detail](08-lilytrail.md)) |

### ⚠️ Belum pernah di-backtest (1 EA)

| # | EA | Versi | Magic | Simbol / TF | Penjelasan |
|---|---|---|---|---|---|
| 9 | LilyHedgeEA | 1.31 | 20261020 | XAUUSD / chart | Hedging berpasangan + filter confluence ([detail](09-lilyhedge.md)) |

Semua magic number berbeda (20261019–20261027) — tidak ada tabrakan antar EA.

## Hasil backtest — tabel ringkasan

Detail lengkap + bukti verifikasi ada di [`LAPORAN-BACKTEST-5-TAHUN.md`](LAPORAN-BACKTEST-5-TAHUN.md). Semua angka dihitung dengan **2 implementasi independen** — kalau keduanya tidak cocok persis, angkanya tidak dilaporkan.

| EA | Periode teruji | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|---|
| LilyGotobiEA | **5 tahun** (Nov 2021–Nov 2026) | 252 | **51,2%** | 1,57 | +57,64R | −11,12R |
| LilyORBEA | 2 tahun (Nov 2024–Nov 2026) | 457 | 46,8% | 1,10 | +12,09R | −18,43R |
| LilyDonchianEA | 2 tahun (Nov 2024–Nov 2026) | 312 | 35,9% | 1,23 | +39,04R | −14,44R |
| LilyMACDEA | 2 tahun (Nov 2024–Nov 2026) | 476 | 35,3% | 1,19 | +36,51R | −16,34R |
| LilyConfluenceEA | pendek | 20 | 25% | 0,67 | −5R | — |
| LilySpikeFadeEA | 27 hari | — | tidak tercatat | 0,42–0,69 | rugi | — |
| LilyMeanReversionEA | 27 hari | 147 | tidak tercatat | 0,39–0,62 | rugi | — |
| LilyTrailEA | 27 hari | 1.268 | 44,2% | 0,56 | −283,8R | −285,3R |
| LilyHedgeEA | — | — | — | — | — | — |

**Kenapa bukan semua 5 tahun?** Data 1 jam gratis dari Yahoo Finance dibatasi maksimal 729 hari — 5 tahun H1 tidak bisa diunduh. Hanya Gotobi yang berhasil 5 tahun penuh, karena datanya M5 dari Dukascopy yang bisa diunduh per hari gotobi saja. Penjelasan lengkap ada di laporan backtest.

**Yang paling penting dari laporan ini:** Tahun 1 ORB RUGI (PF 0,94, −3,58R) dan baru Tahun 2 untung. Strategi yang totalnya profit pun bisa rugi setahun penuh. Jangan berharap profit tiap bulan.

## Modal minimum (risiko 2% per trade)

| EA | Modal minimum | Keterangan |
|---|---|---|
| LilyGotobiEA | ±Rp575 ribu | SL kecil (10 pip) — modal Rp1,2 jt sudah kelebihan |
| LilyORBEA | Tergantung tick value broker | SL = lebar kotak (median ~535 point); cek tick value di MT5 → Specification |
| LilyDonchianEA v1.10 | ±Rp34 juta | SL 2× ATR emas besar ($37,56 per 0,01 lot) |
| LilyMACDEA v1.10 | ±Rp34 juta | Sama seperti Donchian |

Prinsipnya: bukan EA-nya yang butuh modal besar — tapi SL-nya. EA Donchian/MACD v1.10 akan MENOLAK entry kalau modal kurang (lot hitungan di bawah minimum broker), daripada memaksa entry dengan risiko puluhan persen.

## Cara pasang EA di MT5

1. Download file `.mq5` dari folder `ea/`.
2. Copy ke folder `MQL5/Experts` di MT5.
3. Buka MetaEditor, tekan **F7** untuk compile (harus 0 error).
4. Tempel EA di chart sesuai simbol dan timeframe di tabel.
5. Aktifkan **Algo Trading**, dan uji dulu di **akun demo**.

## Struktur repo

```
LilyEA/
├── README-UTAMA.md                  ← file ini (jadikan README.md repo)
├── LAPORAN-BACKTEST-5-TAHUN.md      ← laporan backtest lengkap
├── 01-lilyorbea.md                  ← penjelasan tiap EA
├── 02-lilygotobi.md
├── 03-lilydonchian.md
├── 04-lilymacd.md
├── 05-lilyconfluence.md
├── 06-lilyspikefade.md
├── 07-lilymeanreversion.md
├── 08-lilytrail.md
├── 09-lilyhedge.md
├── ea/
│   ├── LilyORBEA.mq5
│   ├── LilyGotobiEA.mq5
│   ├── LilyDonchianEA.mq5
│   ├── LilyMACDEA.mq5
│   ├── LilyConfluenceEA.mq5
│   ├── LilySpikeFadeEA.mq5
│   ├── LilyMeanReversionEA.mq5
│   ├── LilyTrailEA.mq5
│   └── LilyHedgeEA.mq5
├── data/                            ← data backtest (Yahoo + Dukascopy)
│   ├── NIYF_1h_729d.csv            ← JP225 futures H1 2 tahun
│   ├── GCF_1h_729d.csv              ← emas H1 2 tahun
│   ├── JPYX_1h_729d.csv             ← USDJPY H1 2 tahun
│   ├── *_1d.csv                     ← data harian 5 tahun (referensi)
│   └── gotobi_dukas_m5_y5*.csv      ← USDJPY M5 hari gotobi 5 tahun
└── (script backtest: orb_2y_*.py, donch_macd_2y_*.py, gotobi_*.py)
```

## Aturan main Thalib (dipegang sejak 19 Oktober 2026)

- Risiko maksimal 2% per trade.
- Sebelum mengambil keputusan risiko trading sendiri, tanya Lily dulu.
- EA baru hanya dibangun kalau ada komponen yang sudah terbukti punya edge — EA gabungan ditolak selama semua komponennya rugi.
- Backtest dulu sebelum live. Angka backtest harus diverifikasi 2 implementasi independen sebelum dilaporkan.
