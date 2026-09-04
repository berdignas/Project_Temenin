---
id: BOOKING-016
title: Analytics
owner: Product Team
status: Approved
version: 1.0.0
---

# Analytics

## Metadata

| Item | Value |
|------|-------|
| Domain | Booking |
| Owner | Product |
| Status | Approved |

---

# Purpose

Mendefinisikan seluruh metrik, event, dan KPI yang dikumpulkan dari Booking Domain untuk kebutuhan monitoring operasional, analisis produk, dan pengambilan keputusan bisnis.

---

# Objectives

- Mengukur performa produk.
- Mengidentifikasi bottleneck pada booking flow.
- Mengukur kualitas layanan.
- Mendukung eksperimen produk (A/B Testing).
- Menjadi sumber data Business Intelligence.

---

# Business Metrics

## Booking

| Metric | Description |
|----------|-------------|
| Total Booking | Jumlah seluruh booking |
| Completed Booking | Booking selesai |
| Cancelled Booking | Booking dibatalkan |
| Active Booking | Booking aktif |
| Pending Booking | Menunggu pembayaran/konfirmasi |

---

## Conversion

| Metric | Description |
|----------|-------------|
| Booking Conversion Rate | Browse → Booking |
| Checkout Conversion | Checkout → Payment |
| Payment Success Rate | Payment berhasil |
| Completion Rate | Booking → Completed |

---

## Customer Metrics

- Repeat Booking Rate
- Average Booking Value
- Customer Lifetime Value (CLV)
- Customer Retention
- Review Rate
- Average Rating

---

## Partner Metrics

- Acceptance Rate
- Rejection Rate
- Cancellation Rate
- Response Time
- Utilization Rate
- Earnings

---

## Financial Metrics

- Gross Merchandise Value (GMV)
- Net Revenue
- Service Fee Revenue
- Add-on Revenue
- Refund Amount

---

# Event Tracking

## Customer Events

- booking_created
- booking_updated
- checkout_started
- payment_completed
- booking_cancelled
- booking_completed
- review_submitted

---

## Partner Events

- booking_received
- booking_accepted
- booking_rejected
- partner_arrived
- service_started
- service_completed

---

## System Events

- payment_timeout
- booking_expired
- notification_sent
- pricing_calculated

---

# Dashboard

Dashboard minimal menampilkan:

- Booking per Hari
- Booking per Kota
- Revenue
- Completion Rate
- Cancellation Rate
- Average Rating
- Active Partner
- Active Customer

---

# Data Retention

Analytics disimpan sesuai kebijakan Data Governance perusahaan.