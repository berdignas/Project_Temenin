---
id: FOUNDATION-006
title: Domain Model
owner: Product Team
status: Approved
version: 1.0.0
---

# Domain Model

## Purpose

Dokumen ini mendefinisikan domain bisnis utama Temenin Ajaa beserta hubungan antar domain.

---

# Core Domains

## Customer

Mengelola data pelanggan, profil, riwayat transaksi, dan preferensi.

---

## Partner

Mengelola profil partner, kendaraan, verifikasi, ketersediaan, rating, dan performa.

---

## Booking

Mengelola seluruh proses pemesanan layanan.

Subdomain:

- Booking Draft
- Booking Item
- Itinerary
- Timeline
- Cancellation
- Reschedule
- Review

---

## Service

Jenis layanan yang tersedia:

- Ride
- Hangout
- Freedom Request

---

## Pricing

Mengelola tarif dasar, add-on, promo, dan total biaya.

---

## Payment

Mengelola invoice, pembayaran, refund, dan status pembayaran.

---

## Wallet

Mengelola saldo partner dan riwayat pencairan dana.

---

## Notification

Mengelola notifikasi push, email, dan in-app.

---

## Review

Mengelola rating dan ulasan setelah layanan selesai.

---

## Admin

Mengelola operasional platform melalui dashboard internal.

---

# Domain Relationships

```
Customer
    │
    ▼
Booking
    │
    ├── Service
    ├── Pricing
    ├── Payment
    ├── Notification
    └── Review
          │
          ▼
Partner
```

---

# Business Rules

- Booking selalu dimiliki oleh satu Customer.
- Booking dapat memiliki satu atau lebih Booking Item.
- Setiap Booking Item merepresentasikan satu layanan.
- Pricing dihitung berdasarkan Booking Item dan Add-on.
- Payment dilakukan untuk satu Booking.
- Review hanya dapat dibuat setelah Booking selesai.

---

# Future Domains

- Loyalty
- Membership
- Referral
- Subscription
- AI Recommendation
- Dynamic Pricing

---

# Document History

| Version | Date | Description |
|----------|------|-------------|
|1.0.0|2026-07-19|Initial Domain Model|