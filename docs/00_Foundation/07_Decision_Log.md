---
id: FOUNDATION-007
title: Decision Log
owner: Product Team
status: Approved
version: 1.0.0
---

# Decision Log

## Purpose

Decision Log mencatat seluruh keputusan penting yang memengaruhi produk, desain, teknologi, dan operasional. Dokumen ini menjadi referensi historis agar alasan di balik suatu keputusan tidak hilang seiring perkembangan proyek.

---

# Decision Format

Setiap keputusan harus menggunakan format berikut:

- Decision ID
- Date
- Category
- Status
- Decision
- Reason
- Impact
- Related Documents

---

# Status

- Proposed
- Approved
- Rejected
- Superseded

---

# Decisions

## DEC-001

**Date:** 2026-07-19

**Category:** Product

**Status:** Approved

**Decision**

Temenin Ajaa menggunakan **Hybrid Booking Model**.

**Reason**

Customer dapat menggabungkan beberapa layanan dalam satu transaksi sehingga pengalaman booking lebih fleksibel.

**Impact**

- Mendukung Multi Service Booking.
- Memerlukan Booking Item dan Itinerary.
- Checkout harus mendukung lebih dari satu layanan.

**Related**

- BOOK-001
- BOOK-002

---

## DEC-002

**Category:** Product

**Status:** Approved

**Decision**

Freedom Request menggunakan sistem negosiasi harga antara Customer dan Partner.

**Reason**

Jenis layanan bersifat sangat bervariasi dan tidak dapat ditentukan dengan tarif tetap.

**Impact**

- Tidak menggunakan pricing table.
- Memerlukan proses penawaran dan persetujuan.
- Harga akhir harus disimpan sebagai bagian dari Booking.

---

## DEC-003

**Category:** Product

**Status:** Approved

**Decision**

Ride dan Hangout menggunakan tarif tetap berdasarkan tabel harga resmi.

**Reason**

Memudahkan customer mengetahui estimasi biaya sejak awal dan menyederhanakan proses checkout.

---

## DEC-004

**Category:** UX

**Status:** Approved

**Decision**

Partner Detail menggunakan Hero Photo yang menampilkan partner bersama kendaraan sport.

**Reason**

Foto menjadi faktor utama dalam membangun kepercayaan dan diferensiasi layanan.

---

## DEC-005

**Category:** Branding

**Status:** Approved

**Decision**

Temenin Ajaa diposisikan sebagai **Premium Companion & Lifestyle Platform**, bukan aplikasi dating.

**Reason**

Menjaga persepsi merek dan membedakan layanan dari platform transportasi maupun aplikasi kencan.

---

## DEC-006

**Category:** Design

**Status:** Approved

**Decision**

Aplikasi menggunakan tema gelap dengan aksen pink dan rose gold.

**Reason**

Menciptakan identitas visual yang premium, modern, dan mudah dikenali.

---

# Decision Rules

- Semua keputusan strategis harus dicatat di dokumen ini.
- Keputusan lama tidak dihapus, tetapi diberi status **Superseded** jika sudah digantikan.
- Setiap keputusan harus memiliki alasan dan dampak yang jelas.
- Dokumen terkait harus diperbarui apabila keputusan memengaruhi aturan bisnis atau desain.

---

# Document History

| Version | Date | Description |
|----------|------|-------------|
|1.0.0|2026-07-19|Initial Decision Log|