---
id: BOOKING-011
title: Checkout
owner: Product Team
status: Approved
version: 1.0.0
---

# Checkout

## Purpose

Checkout merupakan proses finalisasi Booking sebelum pembayaran dilakukan.

---

# Objectives

- Memastikan seluruh data Booking valid.
- Menghitung total biaya.
- Menghasilkan Payment Request.

---

# Checkout Process

1. Validasi Booking.
2. Validasi Partner.
3. Validasi Itinerary.
4. Hitung harga layanan.
5. Hitung Add-On.
6. Hitung pajak dan biaya layanan.
7. Generate Invoice.
8. Generate Payment.

---

# Checkout Summary

Customer akan melihat:

- Partner
- Layanan
- Itinerary
- Add-On
- Subtotal
- Service Fee
- Tax (jika berlaku)
- Grand Total

---

# Business Rules

Checkout hanya dapat dilakukan apabila:

- Booking memiliki minimal satu layanan.
- Partner tersedia.
- Semua data wajib telah diisi.
- Harga berhasil dihitung.

---

# Failure Conditions

Checkout gagal apabila:

- Partner tidak tersedia.
- Harga tidak dapat dihitung.
- Payment Gateway tidak tersedia.
- Data Booking tidak valid.

---

# Dependencies

- Pricing
- Payment
- Booking