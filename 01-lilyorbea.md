# LilyORBEA — Opening Range Breakout Sesi Tokyo (JP225)

**File:** `ea/LilyORBEA.mq5` — **Versi:** 1.10 — **Magic Number:** 20261023
**Simbol:** JP225 (JPN225 / Nikkei 225 di broker) — **Timeframe:** M30 (EA selalu membaca M30 sendiri, jadi ditempel di chart mana saja boleh, disarankan M30)
**Status:** ✅ BERHASIL di backtest, forward-test demo sejak 22 Oktober 2026

## Idenya (penjelasan sederhana)

Bayangkan jam pertama bursa Tokyo buka, harga bergerak naik-turun membentuk sebuah "kotak" (range). Kotak ini menunjukkan seberapa besar tenaga pasar pagi ini. Kalau harga berhasil keluar dari kotak ke atas atau ke bawah dengan kuat, biasanya harga akan lanjut ke arah itu sampai siang. EA ini menunggu harga keluar dari kotak, lalu ikut ke arah tersebut.

## Cara kerja langkah demi langkah

1. **07:00–08:00 WIB — Bentuk kotak.** EA mencatat harga tertinggi (High) dan terendah (Low) dari 2 bar M30 pertama sesi Tokyo. Inilah kotaknya.
2. **Filter lebar kotak.** Kalau kotaknya terlalu sempit (lebar < 0,15% dari harga tengah), hari itu di-skip — tidak ada trade. Kotak sempit artinya pasar lemas, breakout-nya tidak bisa dipercaya.
3. **08:00–13:00 WIB — Pasang jebakan dua arah.** EA pasang BuyStop di atas kotak (di High kotak) dan SellStop di bawah kotak (di Low kotak). Mana yang kena duluan, itulah arah trade-nya. Order satunya langsung dihapus (OCO — One Cancels the Other).
4. **SL dan TP.** SL = sisi berlawanan kotak (misal Buy, SL-nya di Low kotak). TP = lebar kotak × 1,5. Jadi kalau lebar kotak 600 point, TP-nya 900 point dari level entry.
5. **Boleh entry lagi.** Kalau posisi sudah tutup kena SL atau TP, EA boleh pasang jebakan lagi selama jumlah trade hari itu masih di bawah 10.
6. **13:00 WIB — Flat.** Semua posisi ditutup dan semua pending order dihapus, apa pun hasilnya. EA tidak pernah membawa posisi sampai sore.

## Manajemen risiko dan lot

- Risiko per trade: 2% dari equity (bisa diubah lewat `InpRiskPct`).
- Lot dihitung otomatis dari jarak SL: makin lebar kotak (makin jauh SL), makin kecil lot-nya.
- Kalau lot hitungan di bawah minimum broker (0,01), EA tidak akan memaksa entry.
- Filter spread: kalau spread lebih dari 40 point saat mau pasang order, EA menunggu tick berikutnya.
- Jam dihitung dari `TimeGMT() + 7` (WIB), jadi tidak kena masalah daylight saving.

## Input penting

| Input | Nilai default | Arti |
|---|---|---|
| InpRangeStartH / InpRangeEndH | 7 / 8 | Jam bentuk kotak (WIB) |
| InpFlatH | 13 | Jam tutup semua (WIB) |
| InpMinRangePct | 0,15% | Lebar kotak minimal |
| InpRR | 1,5 | TP = lebar kotak × 1,5 |
| InpMaxSpreadPts | 40 | Spread maksimal |
| InpMaxTrades | 10 | Maksimal trade per hari |
| InpRiskPct | 2% | Risiko per trade |
| InpMagic | 20261023 | Nomor identitas EA |

## Hasil backtest (terverifikasi 2 implementasi independen)

**Periode terpanjang yang berhasil diuji: 2 TAHUN (19 Nov 2024 – 18 Nov 2026), data NIY=F H1 Yahoo Finance.**
Bukan 5 tahun — data H1 gratis dari Yahoo maksimal 729 hari. Lihat `LAPORAN-BACKTEST-5-TAHUN.md` untuk penjelasan lengkap.

| Periode | Trade | Winrate | Profit Factor | Total | Max Drawdown |
|---|---|---|---|---|---|
| 2 tahun (Nov 2024–Nov 2026) | 457 | 46,8% | 1,10 | +12,09R | −18,43R |
| Tahun 1 (Nov 2024–Nov 2025) | 226 | 43,4% | 0,94 | −3,58R | −18,43R |
| Tahun 2 (Nov 2025–Nov 2026) | 231 | 50,2% | 1,26 | +15,68R | −7,37R |

Hasil 1 tahun yang lama (20 Okt 2025–20 Okt 2026): 229 trade, winrate 47,6%, PF 1,19, +11,78R.

**Yang harus dipahami:** Tahun 1-nya RUGI (PF 0,94), Tahun 2-nya untung. Jadi edge EA ini tipis dan tidak stabil tiap tahun — jangan berharap profit tiap bulan. 71% trade berakhir FLAT jam 13:00 (hanya 50 TP dan 82 SL dari 457 trade). Ekuitas $1.000 dengan risiko 3% berakhir $1.291 (+29,1%), dengan risiko 2% (aturan Thalib) berakhir $1.214 (+21,4%). Max drawdown di risiko 3% mencapai −$539.

## Cara pasang di MT5

1. Copy `LilyORBEA.mq5` ke folder `MQL5/Experts` di MT5.
2. Buka MetaEditor, tekan F7 untuk compile (harus 0 error).
3. Tempel EA di chart JP225 M30, izinkan Algo Trading.
4. Cek log: EA menulis "Kotak hari ini: High=... Low=... Lebar=... point" tiap pagi.
5. Uji dulu di akun demo. Cek tick value JPN225 di MT5 (klik kanan simbol → Specification) — kalau lot hitungan di bawah 0,01, EA akan skip entry.

## Peringatan jujur

- Backtest memakai spread tetap 10 point, tanpa slippage dan tanpa gap. Hasil live bisa lebih jelek.
- Libur bursa Tokyo (misalnya 23 November) belum ada filter otomatis — EA tetap jalan, kotaknya bisa aneh. Perlu dicek manual.
- Ini BUKAN janji profit. Forward-test demo adalah bukti utama, bukan backtest.
