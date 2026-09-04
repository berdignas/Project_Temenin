---
id: BOOKING-002
title: Booking Item
owner: Product Team
status: Approved
version: 1.0.0
---

# Booking Item

## Purpose

Booking Item merepresentasikan satu layanan individual di dalam sebuah Booking.

---

# Supported Types

- Ride
- Hangout
- Freedom Request

---

# Example

Booking

```
Ride
Hangout
Ride
```

memiliki tiga Booking Item.

---

# Attributes

- Service Type
- Duration
- Quantity
- Unit Price
- Notes
- Status

---

# Business Rules

- Minimal satu item.
- Item dapat memiliki add-on.
- Item dapat memiliki itinerary.
- Harga item bersifat snapshot saat checkout.
- Perubahan harga master tidak memengaruhi booking yang sudah dibuat.

---

# Lifecycle

Draft

↓

Confirmed

↓

In Progress

↓

Completed

atau

Cancelled