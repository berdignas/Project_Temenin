---
id: BOOKING-010
title: Add-On
owner: Product Team
status: Approved
version: 1.0.0
---

# Add-On

## Purpose

Add-On adalah layanan tambahan yang dapat dipilih Customer untuk melengkapi Booking.

---

# Objectives

- Meningkatkan fleksibilitas layanan.
- Menambah nilai transaksi.
- Menjadi sumber pendapatan tambahan.

---

# Examples

- Waiting Time
- Extra Helmet
- Toll Fee
- Parking Fee
- Overtime
- Special Request

---

# Add-On Structure

Setiap Add-On memiliki:

- ID
- Name
- Description
- Price
- Unit
- Quantity

---

# Pricing

Harga Add-On ditentukan oleh Domain Pricing.

---

# Business Rules

- Add-On bersifat opsional.
- Satu Booking dapat memiliki banyak Add-On.
- Harga disimpan sebagai snapshot saat checkout.
- Add-On tidak dapat dihapus setelah Booking dimulai.

---

# Dependencies

- Booking
- Pricing