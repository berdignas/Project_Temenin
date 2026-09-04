---
id: BOOKING-013
title: Reschedule
owner: Product Team
status: Approved
version: 1.0.0
---

# Reschedule

## Purpose

Mengatur perubahan jadwal Booking setelah Booking dibuat.

---

# Objectives

- Memberikan fleksibilitas.
- Menjaga kepastian jadwal Partner.
- Mengurangi pembatalan.

---

# Editable Fields

Customer dapat meminta perubahan:

- Date
- Start Time
- Pickup Time
- Itinerary
- Notes

---

# Non Editable

Tidak dapat diubah:

- Customer
- Partner
- Booking Number
- Payment ID

---

# Workflow

Customer

↓

Request Reschedule

↓

Partner Review

↓

Approve / Reject

↓

Update Booking

↓

Notification

---

# Validation

Reschedule hanya dapat dilakukan apabila:

- Booking belum In Progress
- Partner tersedia
- Jadwal baru valid

---

# Pricing Impact

Reschedule dapat menyebabkan:

- Perubahan tarif
- Perubahan add-on
- Tambahan biaya

Jika harga berubah, sistem menghasilkan Invoice Adjustment.

---

# Business Rules

- Semua perubahan disimpan pada Timeline.
- Reschedule harus disetujui Partner apabila memengaruhi jadwal.
- Admin dapat melakukan override dalam kondisi tertentu.

---

# Dependencies

- Booking
- Timeline
- Pricing
- Notification