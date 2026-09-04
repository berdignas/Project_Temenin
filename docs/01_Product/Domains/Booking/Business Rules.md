---
id: BOOKING-014
title: Business Rules
owner: Product Team
status: Approved
version: 1.0.0
---

# Business Rules

## Purpose

Dokumen ini menjadi referensi utama seluruh aturan bisnis pada Booking Domain.

---

# Core Rules

## BR-001

Booking wajib memiliki Customer.

---

## BR-002

Booking wajib memiliki Partner.

---

## BR-003

Booking minimal memiliki satu Booking Item.

---

## BR-004

Satu Booking hanya memiliki satu Partner.

---

## BR-005

Booking dapat memiliki banyak layanan.

Contoh:

Ride

↓

Hangout

↓

Ride

---

## BR-006

Freedom Request menggunakan harga hasil negosiasi.

---

## BR-007

Ride menggunakan harga tetap.

---

## BR-008

Hangout menggunakan harga tetap.

---

## BR-009

Harga Booking merupakan snapshot saat Checkout.

Perubahan Pricing setelah Checkout tidak memengaruhi Booking.

---

## BR-010

Booking wajib memiliki Payment sebelum dikonfirmasi.

---

## BR-011

Booking selesai setelah seluruh Booking Item selesai.

---

## BR-012

Review hanya dapat diberikan setelah Booking Completed.

---

## BR-013

Partner tidak boleh mengubah harga setelah pembayaran berhasil.

---

## BR-014

Semua perubahan Booking menghasilkan Timeline Event.

---

## BR-015

Semua perubahan Booking menghasilkan Audit Log.

---

# Rule Priority

Jika terdapat konflik:

1. Security
2. Legal
3. Product Policy
4. Business Rule
5. User Preference