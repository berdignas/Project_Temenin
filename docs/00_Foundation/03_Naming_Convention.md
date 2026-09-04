---
id: FOUNDATION-003
title: Naming Convention
owner: Product Team
status: Approved
version: 1.0.0
---

# Naming Convention

## Purpose

Dokumen ini menetapkan standar penamaan untuk seluruh artefak dalam proyek Temenin Ajaa, termasuk dokumentasi, desain, kode, API, database, analytics, dan Git. Tujuannya adalah menjaga konsistensi, mempermudah pencarian, dan mengurangi miskomunikasi antar tim.

---

# General Principles

- Gunakan nama yang jelas dan deskriptif.
- Hindari singkatan yang tidak umum.
- Gunakan bahasa Inggris untuk semua artefak teknis.
- Gunakan bahasa Indonesia hanya untuk konten yang ditampilkan kepada pengguna (UI Text, Marketing, FAQ, dll.).
- Satu istilah hanya memiliki satu nama resmi.

---

# Folder Naming

Gunakan PascalCase.

✅ Benar

```
Booking
Partner
Payment
Pricing
DesignSystem
```

❌ Salah

```
booking_data
Partner Folder
partner-folder
```

---

# Markdown File Naming

Gunakan PascalCase dengan underscore sebagai pemisah jika diperlukan.

Contoh:

```
Booking_Draft.md
Booking_Status.md
Partner_Profile.md
Freedom_Request.md
Payment_Invoice.md
```

---

# Document ID

Setiap dokumen wajib memiliki ID unik.

Format:

```
PREFIX-XXX
```

Contoh:

```
FOUNDATION-001
BOOK-001
PARTNER-001
PAYMENT-001
PRICE-001
DESIGN-001
API-001
QA-001
```

---

# Feature Naming

Gunakan format:

```
<Noun>_<Action>
```

Contoh:

```
Booking_Create
Booking_Cancel
Partner_Verification
Payment_Refund
```

---

# Screen Naming

Gunakan suffix **Screen**.

Contoh:

```
HomeScreen
BookingDetailScreen
PartnerDetailScreen
CheckoutScreen
PaymentScreen
ProfileScreen
```

---

# Component Naming

Gunakan suffix sesuai jenis komponen.

```
PartnerCard
BookingCard
PrimaryButton
PriceSummaryCard
RatingBadge
BookingTimeline
```

---

# Dialog Naming

```
CancelBookingDialog
LogoutDialog
PaymentSuccessDialog
```

---

# Bottom Sheet Naming

```
BookingActionBottomSheet
PartnerFilterBottomSheet
PaymentMethodBottomSheet
```

---

# API Endpoint Naming

Gunakan format REST.

```
GET    /bookings
POST   /bookings
GET    /bookings/{id}
PATCH  /bookings/{id}
DELETE /bookings/{id}
```

Sub-resource:

```
GET /partners
GET /partners/{id}
POST /payments
GET /pricing
```

---

# Database Table Naming

Gunakan huruf kecil dan snake_case.

```
customers
partners
bookings
booking_items
booking_itineraries
payments
payment_logs
reviews
notifications
```

---

# Database Column Naming

Gunakan snake_case.

```
booking_id
partner_id
customer_id
created_at
updated_at
deleted_at
start_time
end_time
total_price
```

---

# Enum Naming

Gunakan huruf besar dengan underscore.

```
BOOKING_DRAFT
WAITING_PAYMENT
WAITING_PARTNER
CONFIRMED
ON_GOING
COMPLETED
CANCELLED
REFUNDED
```

---

# Flutter Naming

## File

Gunakan snake_case.

```
booking_detail_screen.dart
partner_card.dart
price_summary_widget.dart
```

## Class

Gunakan PascalCase.

```
BookingDetailScreen
PartnerCard
PriceSummaryWidget
```

## Variable

Gunakan camelCase.

```
bookingId
partnerName
totalPrice
selectedService
```

## Constant

Gunakan lowerCamelCase untuk konstanta lokal dan `k` prefix untuk konstanta global bila dipakai di proyek.

```
kPrimaryRadius
kDefaultPadding
```

---

# Asset Naming

```
ic_booking.svg
ic_payment.svg
img_partner_placeholder.png
img_banner_home.webp
```

---

# Image Naming

```
partner_hero_01.webp
partner_gallery_01.webp
service_ride.webp
```

---

# Figma Naming

Gunakan format:

```
[Platform] Screen

Mobile - Home
Mobile - Booking Detail
Mobile - Checkout
Admin - Dashboard
```

Komponen:

```
Button / Primary
Button / Secondary
Card / Partner
Card / Booking
```

---

# Analytics Event Naming

Gunakan snake_case dengan awalan domain.

```
booking_created
booking_paid
booking_cancelled
partner_profile_opened
partner_selected
payment_success
payment_failed
```

---

# Git Branch Naming

Format:

```
feature/<name>
bugfix/<name>
hotfix/<name>
release/<version>
docs/<name>
```

Contoh:

```
feature/booking-checkout
feature/freedom-request
docs/booking-domain
bugfix/payment-timeout
```

---

# Git Commit Convention

Gunakan Conventional Commits.

```
feat:
fix:
docs:
style:
refactor:
test:
chore:
```

Contoh:

```
feat: add booking itinerary
fix: resolve payment callback issue
docs: update booking domain documentation
refactor: simplify pricing calculation
```

---

# Prompt Naming

```
PROMPT-001_Master_Prompt.md
PROMPT-002_Component_Generator.md
PROMPT-003_Screen_Generator.md
```

---

# Versioning

Gunakan Semantic Versioning.

```
1.0.0

Major.Minor.Patch
```

Contoh:

```
1.0.0
1.1.0
1.1.1
2.0.0
```

---

# Reserved Business Terms

Istilah berikut tidak boleh diganti tanpa persetujuan Product Team:

- Customer
- Partner
- Booking
- Booking Item
- Itinerary
- Ride
- Hangout
- Freedom Request
- Add-on
- Invoice
- Wallet
- Rating
- Review

---

# Validation Checklist

Sebelum membuat artefak baru, pastikan:

- Nama mengikuti konvensi.
- Tidak duplikat.
- Menggunakan bahasa Inggris.
- Konsisten dengan Glossary.
- Memiliki Document ID bila berupa dokumen.

---

# Document History

| Version | Date | Description |
|----------|------|-------------|
| 1.0.0 | 2026-07-19 | Initial Naming Convention |