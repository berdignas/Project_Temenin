---
id: FOUNDATION-004
title: Documentation Standard
owner: Product Team
status: Approved
version: 1.0.0
---

# Documentation Standard

## Purpose

Dokumen ini menetapkan standar penulisan seluruh dokumentasi Temenin Ajaa agar konsisten, mudah dipahami, mudah dipelihara, dan menjadi Single Source of Truth (SSOT).

---

# Documentation Principles

Seluruh dokumentasi harus memenuhi prinsip berikut:

- Accurate (Akurat)
- Complete (Lengkap)
- Consistent (Konsisten)
- Traceable (Dapat ditelusuri)
- Maintainable (Mudah diperbarui)

---

# Single Source of Truth

Setiap informasi hanya memiliki satu dokumen utama.

Contoh:

Booking Status → docs/01_Product/Domains/Booking/Booking_Status.md

Dokumen lain hanya boleh memberikan referensi, bukan menyalin isi.

---

# Required Metadata

Semua dokumen wajib memiliki metadata berikut.

```yaml
---
id:
title:
owner:
status:
version:
---
```

Status yang diperbolehkan:

- Draft
- Review
- Approved
- Deprecated

---

# Standard Structure

Setiap dokumen domain minimal memiliki bagian berikut:

- Purpose
- Business Goal
- Scope
- Business Rules
- User Flow
- Validation Rules
- Dependencies
- Related Documents
- Revision History

---

# Writing Rules

Gunakan:

- Bahasa Inggris untuk istilah teknis.
- Bahasa Indonesia untuk penjelasan bisnis (selama fase dokumentasi internal).
- Kalimat singkat dan jelas.
- Hindari paragraf yang terlalu panjang.
- Gunakan heading yang konsisten.

---

# Business Rules

Semua aturan bisnis harus ditulis menggunakan kata:

- MUST
- MUST NOT
- SHOULD
- MAY

Contoh:

Customer MUST complete payment before partner confirmation.

---

# Cross Reference

Gunakan referensi dokumen.

Contoh:

Related:

- BOOK-003 Ride Service
- PAY-002 Invoice
- PARTNER-004 Verification

---

# Images

Semua diagram disimpan pada:

```
assets/diagrams/
```

Gunakan format:

- PNG
- SVG
- Draw.io

---

# Versioning

Gunakan Semantic Versioning.

```
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

# Changelog

Setiap perubahan wajib dicatat.

| Version | Date | Description |
|----------|------|-------------|

---

# Review Process

Flow review:

Author

↓

Product Review

↓

Engineering Review

↓

QA Review

↓

Approved

---

# Document Lifecycle

Draft

↓

Review

↓

Approved

↓

Deprecated

↓

Archived

---

# Folder Rules

Satu dokumen hanya berada pada satu folder.

Tidak boleh diduplikasi.

---

# File Naming

Mengikuti:

FOUNDATION-003 Naming Convention

---

# Document History

| Version | Date | Description |
|----------|------|-------------|
|1.0.0|2026-07-19|Initial Documentation Standard|