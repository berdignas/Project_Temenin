---
id: BOOKING-007
title: Ride Service
owner: Product Team
status: Approved
version: 1.0.0
---

# Ride Service

## Purpose

Ride adalah layanan transportasi yang disediakan Partner menggunakan kendaraan yang telah terdaftar dan lolos verifikasi.

---

# Scope

Layanan Ride meliputi:

- Penjemputan Customer.
- Perjalanan ke satu atau beberapa tujuan.
- Pengantaran kembali (opsional).

---

# Service Configuration

- Pickup Location
- Destination
- Vehicle
- Estimated Distance
- Estimated Duration

---

# Pricing

Ride menggunakan **fixed pricing** berdasarkan aturan pada domain Pricing.

Harga dihitung saat checkout dan disimpan sebagai snapshot pada Booking.

---

# Business Rules

- Partner wajib menggunakan kendaraan yang terdaftar.
- Ride dapat berdiri sendiri atau menjadi bagian dari Multi-Service Booking.
- Ride dapat muncul lebih dari satu kali dalam satu Booking.

---

# Success Criteria

- Partner tiba sesuai estimasi.
- Seluruh titik itinerary terselesaikan.
- Booking selesai tanpa sengketa.