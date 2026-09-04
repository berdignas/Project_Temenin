---
id: BOOKING-018
title: Database Model
owner: Product Team
status: Approved
version: 1.0.0
---

# Database Model

## Purpose

Mendefinisikan model data konseptual Booking Domain sebagai acuan implementasi database.

---

# Aggregate Root

Booking

---

# Main Entities

## Booking

| Field | Type |
|---------|------|
| id | UUID |
| booking_number | String |
| customer_id | UUID |
| partner_id | UUID |
| status | Enum |
| total_amount | Decimal |
| currency | String |
| payment_status | Enum |
| created_at | Timestamp |
| updated_at | Timestamp |

---

## Booking Item

| Field | Type |
|---------|------|
| id | UUID |
| booking_id | UUID |
| service_type | Enum |
| quantity | Integer |
| unit_price | Decimal |
| subtotal | Decimal |

---

## Itinerary

| Field | Type |
|---------|------|
| id | UUID |
| booking_id | UUID |
| sequence | Integer |
| location_name | String |
| latitude | Decimal |
| longitude | Decimal |
| arrival_time | Timestamp |

---

## Add-On

| Field | Type |
|---------|------|
| id | UUID |
| booking_item_id | UUID |
| addon_code | String |
| quantity | Integer |
| price | Decimal |

---

## Timeline

| Field | Type |
|---------|------|
| id | UUID |
| booking_id | UUID |
| event | String |
| actor | Enum |
| description | Text |
| created_at | Timestamp |

---

# Relationships

Booking

├── Booking Item (1..N)

├── Itinerary (1..N)

├── Timeline (1..N)

├── Payment (1..1)

├── Customer (N..1)

├── Partner (N..1)

└── Review (0..1)

---

# Constraints

- booking_number harus unik.
- Foreign key wajib menggunakan UUID.
- Soft delete diterapkan pada entitas operasional sesuai kebijakan.
- Seluruh timestamp menggunakan UTC.

---

# Index Recommendation

## Booking

- booking_number
- customer_id
- partner_id
- status
- created_at

---

## Timeline

- booking_id
- created_at

---

## Booking Item

- booking_id
- service_type

---

# Future Considerations

- Booking Version (Optimistic Locking)
- Event Store untuk Audit Trail
- Partitioning berdasarkan tanggal jika volume data tinggi
- Read Replica untuk kebutuhan reporting dan analytics