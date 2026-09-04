---
id: BOOKING-003
title: Booking Status
owner: Product Team
status: Approved
version: 1.0.0
---

# Booking Status

## Purpose

Menentukan status resmi sebuah Booking selama siklus hidupnya.

---

# Status Flow

Draft

↓

Pending Payment

↓

Paid

↓

Confirmed

↓

Partner On The Way

↓

In Progress

↓

Completed

atau

Cancelled

---

# Status Definitions

## Draft

Booking masih dibuat.

---

## Pending Payment

Menunggu pembayaran.

---

## Paid

Pembayaran berhasil diterima.

---

## Confirmed

Klien secara manual memilih driver dari radar (atau terkonfirmasi otomatis untuk pemesanan langsung dari profil).

---

## Partner On The Way

Partner sedang menuju lokasi awal.

---

## In Progress

Layanan sedang berlangsung setelah Driver memvalidasi 4-digit PIN Pertemuan fisik dari Klien.

---

## Completed

Seluruh layanan selesai. Sesi selesai otomatis ketika durasi habis, atau selesai awal jika disetujui bersama oleh Klien dan Partner.

---

## Cancelled

Booking dibatalkan.

---

# Status Rules

Status hanya boleh bergerak maju sesuai state machine, kecuali proses pembatalan sesuai kebijakan.

Setiap perubahan status wajib:

- Mencatat timestamp.
- Mencatat actor (Customer, Partner, Admin, atau System).
- Menghasilkan event untuk notifikasi dan audit.