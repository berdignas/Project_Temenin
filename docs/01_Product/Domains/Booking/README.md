---
id: BOOKING-000
title: Booking Domain
owner: Product Team
status: Approved
version: 1.0.0
---

# Booking Domain

## Purpose

Booking Domain merupakan inti (core domain) dari Temenin Ajaa. Seluruh transaksi antara Customer dan Partner dikelola melalui domain ini.

Booking tidak hanya berfungsi sebagai reservasi layanan, tetapi juga menjadi pusat koordinasi antara Customer, Partner, Payment, Pricing, Notification, Review, dan Operation.

---

# Scope

Booking Domain mencakup:

- Booking Lifecycle
- Ride Service
- Hangout Service
- Freedom Request
- Multi-Service Booking
- Itinerary
- Add-on
- Checkout
- Cancellation
- Reschedule
- Timeline
- Review Trigger
- Booking Analytics

---

# Core Principles

- Satu Booking dapat memiliki lebih dari satu layanan.
- Booking memiliki satu Partner.
- Booking memiliki satu Customer.
- Booking memiliki satu Payment.
- Booking memiliki satu Status aktif.
- Booking menghasilkan Timeline aktivitas.
- Seluruh perubahan status harus tercatat sebagai Audit Trail.

---

# Booking Architecture

Customer
↓
Create Booking
↓
Select Services
↓
Configure Itinerary
↓
Calculate Pricing
↓
Checkout
↓
Payment
↓
Partner Confirmation
↓
Service Execution
↓
Completion
↓
Review

---

# Aggregate Root

Booking merupakan Aggregate Root.

Entity lain tidak boleh mengubah Booking secara langsung.

Semua perubahan harus melalui Booking Service.

---

# Child Entities

- Booking Item
- Itinerary
- Add-on
- Timeline
- Status History

---

# Related Domains

- Partner
- Pricing
- Payment
- Wallet
- CRM
- Notification
- Review