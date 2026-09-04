---
id: BOOKING-017
title: API Mapping
owner: Product Team
status: Approved
version: 1.0.0
---

# API Mapping

## Purpose

Dokumen ini menjadi referensi endpoint utama Booking Domain. Detail implementasi terdapat pada dokumentasi Engineering.

---

# Customer APIs

## Create Booking

POST

/api/v1/bookings

---

## Get Booking

GET

/api/v1/bookings/{id}

---

## List Booking

GET

/api/v1/bookings

---

## Update Booking

PATCH

/api/v1/bookings/{id}

---

## Cancel Booking

POST

/api/v1/bookings/{id}/cancel

---

## Reschedule

POST

/api/v1/bookings/{id}/reschedule

---

## Checkout

POST

/api/v1/bookings/{id}/checkout

---

## Timeline

GET

/api/v1/bookings/{id}/timeline

---

## Review

POST

/api/v1/bookings/{id}/review

---

# Partner APIs

GET /partner/bookings

POST /partner/bookings/{id}/accept

POST /partner/bookings/{id}/reject

POST /partner/bookings/{id}/arrived

POST /partner/bookings/{id}/start

POST /partner/bookings/{id}/complete

---

# Admin APIs

GET /admin/bookings

PATCH /admin/bookings/{id}

POST /admin/bookings/{id}/cancel

GET /admin/bookings/report

---

# External APIs

## Payment

- Create Payment
- Payment Callback
- Refund

---

## Notification

- Push Notification
- Email
- SMS
- WhatsApp (Optional)

---

# Authentication

Semua endpoint menggunakan:

- OAuth2 / JWT
- HTTPS
- Role Based Access Control (RBAC)

---

# API Versioning

Versi API menggunakan URL versioning:

/api/v1/

/api/v2/