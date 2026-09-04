# Temenin Ajaa - Admin Web Dashboard

Aplikasi Web Dashboard Admin berbasis **React + Vite + Tailwind CSS** untuk mengontrol dan mengelola seluruh sistem ekosistem **Temenin Ajaa** (Client & Driver/Mitra).

---

## 🚀 Cara Menjalankan Admin Web Dashboard

### 1. Instalasi Dependensi
```bash
cd admin_temenin_ajaa
npm install
```

### 2. Jalankan Server Development (Vite)
```bash
npm run dev
```
Aplikasi akan secara otomatis dapat diakses di browser pada:
`http://localhost:3000`

### 3. Koneksi Backend Express.js
Pastikan backend Express running pada port 3002:
```bash
cd backend
npm run dev
```
*(Catatan: Web Admin dilengkapi mode fallback otomatis, sehingga jika backend tidak berjalan, dashboard tetap dapat dites dan diuji secara interaktif)*.

---

## 🛠️ Fitur & Modul Admin

1. **Dashboard Overview**: Ringkasan statistik (Total Client, Total Driver, Pending Driver, Transaksi Aktif, Omset Platform), Grafik Tren Mingguan (Recharts), dan List Antrean Pendaftar Mitra.
2. **Manajemen Client / Pengguna (`/clients`)**: Filter pencarian, detail akun, pengisian/top-up saldo manual admin, tambah poin, verifikasi centang hijau, dan hapus akun.
3. **Manajemen Driver / Mitra (`/drivers`)**: Monitoring mitra approved/pending/rejected, tipe kendaraan, plat nomor, tarif per jam, rating, dan status online/offline.
4. **Persetujuan Mitra Driver (`/driver-approvals`)**: Antrean khusus verifikasi kelengkapan berkas SIM, STNK, KTP, dan tombol persetujuan (*Approve*) atau penolakan (*Reject*).
5. **Pemesanan & Order (`/bookings`)**: Monitoring transaksi real-time (*pending, ongoing, completed, cancelled*), rute penjemputan/tujuan, durasi, total harga, serta kemampuan intervensi status oleh admin.
6. **Keuangan & Saldo (`/finance`)**: Laporan estimasi bagi hasil komisi platform 10%, total saldo beredar, dan form top up instan.
7. **Komunitas & Moderasi Konten (`/community`)**: Moderasi dan pembersihan foto/postingan publik yang melanggar aturan.
8. **Pengaturan Sistem (`/settings`)**: Konfigurasi persentase komisi, tarif minimal per jam, dan endpoint server.
