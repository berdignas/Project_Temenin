---
id: BOOKING-004
title: Booking Timeline
owner: Product Team
status: Approved
version: 1.0.0
---

# Booking Timeline

## Purpose

Booking Timeline mencatat seluruh aktivitas yang terjadi selama siklus hidup sebuah Booking. Timeline menjadi sumber informasi utama bagi Customer, Partner, Admin, serta berfungsi sebagai audit trail.

---

# Objectives

- Memberikan visibilitas terhadap progres booking.
- Menyimpan riwayat aktivitas secara kronologis.
- Mendukung investigasi dan penyelesaian sengketa.
- Menjadi sumber data notifikasi dan analitik.

---

# Timeline Event

| Event | Actor | Visible to Customer | Visible to Partner | Visible to Admin |
|--------|-------|---------------------|--------------------|------------------|
| Booking Created | Customer | ✅ | ❌ | ✅ |
| Payment Pending | System | ✅ | ❌ | ✅ |
| Payment Success | Payment Gateway | ✅ | ✅ | ✅ |
| Booking Confirmed | Customer / System | ✅ | ✅ | ✅ |
| Partner On The Way | Partner | ✅ | ✅ | ✅ |
| Service Started | Partner / Customer (PIN) | ✅ | ✅ | ✅ |
| Service Completed | System (Auto) / Customer & Partner | ✅ | ✅ | ✅ |
| Booking Cancelled | Customer / Partner / Admin | ✅ | ✅ | ✅ |
| Review Submitted | Customer | ✅ | ✅ | ✅ |

---

# Timeline Entry Structure

- Event ID
- Booking ID
- Event Type
- Description
- Actor
- Timestamp
- Metadata

---

# Business Rules

- Timeline tidak boleh dihapus.
- Timeline bersifat append-only.
- Timestamp menggunakan UTC.
- Seluruh perubahan status menghasilkan Timeline Event.
- Timeline dapat digunakan sebagai bukti operasional.

---

# Related Documents

- Booking.md
- Booking_Status.md
- State_Machine.md