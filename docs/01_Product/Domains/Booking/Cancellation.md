---
id: BOOKING-012
title: Cancellation
owner: Product Team
status: Approved
version: 1.0.0
---

# Cancellation

## Metadata

| Item | Value |
|------|-------|
| Domain | Booking |
| Aggregate | Booking |
| Owner | Product |
| Status | Approved |

---

# Purpose

Mendefinisikan aturan pembatalan Booking secara konsisten, transparan, dan adil bagi Customer, Partner, maupun perusahaan.

---

# Overview

Booking dapat dibatalkan sebelum layanan selesai.

Pembatalan dapat dilakukan oleh:

- Customer
- Partner
- Admin
- System

Setiap pembatalan harus memiliki alasan (Cancellation Reason).

---

# Cancellation Actors

## Customer

Customer dapat membatalkan booking sesuai kebijakan.

Contoh:

- Berubah pikiran
- Salah memilih jadwal
- Partner terlalu lama

---

## Partner

Partner dapat membatalkan apabila:

- Kendaraan bermasalah
- Kondisi darurat
- Tidak dapat memenuhi booking

---

## Admin

Admin dapat membatalkan apabila:

- Fraud
- Pelanggaran kebijakan
- Permintaan Customer
- Force Majeure

---

## System

System dapat membatalkan apabila:

- Payment Timeout
- Booking Expired
- Partner tidak merespons
- Data tidak valid

---

# Cancellation Window

| Status | Can Cancel |
|----------|-----------|
| Draft | ✅ |
| Pending Payment | ✅ |
| Paid | ✅ |
| Confirmed | ✅ |
| Partner On The Way | Conditional |
| In Progress | ❌ |
| Completed | ❌ |

---

# Cancellation Reasons

- Customer Request
- Partner Request
- Payment Failed
- Payment Timeout
- Partner Unavailable
- Fraud
- Duplicate Booking
- Emergency
- System Failure

---

# Refund Policy

Refund mengikuti Domain Payment.

Booking hanya menyimpan status refund.

Contoh:

- No Refund
- Partial Refund
- Full Refund

---

# Effects

Cancellation menghasilkan:

- Timeline Event
- Notification
- Refund Request
- Audit Log

---

# Business Rules

- Booking Completed tidak dapat dibatalkan.
- Booking Cancelled tidak dapat diaktifkan kembali.
- Semua pembatalan wajib memiliki alasan.
- Semua pembatalan dicatat dalam Audit Trail.

---

# Dependencies

- Payment
- Timeline
- Notification
- Wallet