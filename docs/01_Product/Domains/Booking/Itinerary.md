---
id: BOOKING-006
title: Itinerary
owner: Product Team
status: Approved
version: 1.0.0
---

# Itinerary

## Purpose

Itinerary mendefinisikan urutan aktivitas dan lokasi yang akan dijalankan selama Booking.

---

# Objectives

- Memberikan rencana perjalanan yang jelas.
- Menjadi dasar perhitungan harga layanan Ride.
- Membantu Partner memahami urutan aktivitas.

---

# Itinerary Components

- Pickup Location
- Destination
- Intermediate Stops
- Estimated Arrival
- Estimated Duration
- Notes

---

# Example

Booking:

Ride → Hangout → Ride

Itinerary:

1. Customer Pickup
2. Café ABC
3. Mall XYZ
4. Customer Home

---

# Business Rules

- Minimal memiliki satu lokasi.
- Urutan lokasi dapat diubah sebelum Booking dikonfirmasi.
- Setelah status "In Progress", perubahan itinerary memerlukan persetujuan Partner.
- Perubahan itinerary dapat memengaruhi harga.

---

# Dependencies

- Pricing
- Ride
- Booking