---
id: BOOKING-005
title: State Machine
owner: Product Team
status: Approved
version: 1.0.0
---

# State Machine

## Purpose

Menentukan transisi status yang valid dalam lifecycle Booking.

---

# State Diagram

Draft
↓
Pending Payment
↓
Paid
↓
Confirmed
↓
Partner On The Way
↓
In Progress
↓
Completed

State "Cancelled" dapat dicapai dari Draft, Pending Payment, Paid, atau Confirmed sesuai kebijakan pembatalan.

---

# Allowed Transitions

| Current State | Next State |
|---------------|------------|
| Draft | Pending Payment |
| Pending Payment | Paid |
| Pending Payment | Cancelled |
| Paid | Confirmed |
| Paid | Cancelled |
| Confirmed | Partner On The Way |
| Confirmed | Cancelled |
| Partner On The Way | In Progress |
| In Progress | Completed |

---

# Invalid Transitions

- Completed → In Progress
- Completed → Paid
- Cancelled → Draft
- Cancelled → Confirmed
- Paid → Draft

---

# Business Rules

- Tidak boleh melewati state.
- Semua transisi harus tervalidasi.
- Semua transisi menghasilkan Timeline Event.
- Semua transisi menghasilkan Audit Log.