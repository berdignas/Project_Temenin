---
id: BOOKING-015
title: Validation Rules
owner: Product Team
status: Approved
version: 1.0.0
---

# Validation Rules

## Purpose

Menentukan seluruh validasi sebelum Booking diproses.

---

# Customer Validation

- Customer aktif.
- Customer tidak diblokir.
- Nomor telepon terverifikasi.

---

# Partner Validation

- Partner aktif.
- Partner online.
- Partner telah diverifikasi.
- Partner tersedia pada jadwal tersebut.

---

# Booking Validation

- Memiliki minimal satu layanan.
- Tanggal valid.
- Jam valid.
- Itinerary valid.
- Total harga berhasil dihitung.

---

# Payment Validation

- Payment Method tersedia.
- Nominal sesuai.
- Mata uang sesuai.

---

# Service Validation

## Ride

- Pickup wajib.
- Destination wajib.

---

## Hangout

- Meeting Point wajib.
- Duration wajib.

---

## Freedom Request

- Judul wajib.
- Deskripsi wajib.
- Harga hasil negosiasi wajib tersedia.

---

# Validation Response

Semua error mengikuti format:

- Error Code
- Error Message
- Field
- Suggested Action