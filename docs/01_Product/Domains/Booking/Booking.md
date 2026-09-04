---
id: BOOKING-001
title: Booking
owner: Product Team
status: Approved
version: 1.0.0
---

# Booking

## Purpose

Booking merepresentasikan perjanjian layanan antara Customer dan Partner.

Booking menjadi sumber kebenaran (Source of Truth) bagi seluruh proses bisnis setelah Customer melakukan checkout.

---

# Definition

Booking adalah transaksi yang terdiri dari satu atau lebih layanan yang akan dijalankan oleh satu Partner pada waktu tertentu.

---

# Booking Composition

Booking terdiri dari:

- Customer
- Partner
- Booking Items
- Itinerary
- Pricing
- Payment
- Timeline
- Status
- Review

---

# Business Rules

## Rule 1

Booking harus memiliki Customer.

---

## Rule 2

Booking harus memiliki Partner.

---

## Rule 3

Booking minimal memiliki satu Booking Item.

---

## Rule 4

Booking maksimal menggunakan satu Partner.

---

## Rule 5

Booking hanya dapat memiliki satu pembayaran utama.

---

## Rule 6

Booking yang telah selesai tidak dapat diubah.

---

## Rule 7

Booking yang dibatalkan tidak dapat diaktifkan kembali.

---

# Booking Number

Format:

```
TA-YYYYMMDD-XXXXXX
```

Contoh

```
TA-20260719-000123
```

---

# Booking Ownership

Customer adalah pemilik booking.

Partner hanya menerima penugasan.

Admin memiliki hak administratif.

---

# Dependencies

- Partner
- Payment
- Pricing
- Notification