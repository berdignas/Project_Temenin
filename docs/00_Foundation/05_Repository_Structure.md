---
id: FOUNDATION-005
title: Repository Structure
owner: Product Team
status: Approved
version: 1.0.0
---

# Repository Structure

## Purpose

Dokumen ini menjelaskan struktur repository Temenin OS agar seluruh tim menggunakan struktur yang sama.

---

# Root Structure

```
temenin-os/

docs/
assets/
figma/
prompts/
archive/
README.md
```

---

# docs/

```
00_Foundation/
01_Product/
02_Design/
03_Engineering/
04_QA/
05_Operation/
06_API/
07_Admin/
08_Partner/
09_AI/
```

---

# 00_Foundation

Berisi standar proyek.

- Constitution
- Glossary
- Naming Convention
- Documentation Standard
- Repository Structure
- Domain Model
- Decision Log

---

# 01_Product

Berisi seluruh dokumentasi bisnis.

```
Business/
Domains/
Roadmap/
Research/
```

---

# Business

Contoh:

```
Vision.md
Mission.md
Business_Model.md
USP.md
Revenue_Model.md
```

---

# Domains

Contoh:

```
Booking/
Partner/
Customer/
Pricing/
Payment/
Wallet/
Review/
Notification/
```

---

# 02_Design

```
DesignSystem/
Components/
Screens/
Assets/
Icons/
Motion/
Accessibility/
```

---

# 03_Engineering

```
Architecture/
Backend/
Flutter/
Database/
Infrastructure/
Deployment/
```

---

# 04_QA

```
Test Cases/
Regression/
Bug Reports/
Release Checklist/
```

---

# 05_Operation

```
Customer Service/
Finance/
CRM/
Support/
SOP/
```

---

# 06_API

```
Authentication/
Booking/
Partner/
Payment/
Customer/
Webhook/
```

---

# 07_Admin

```
Dashboard/
Booking/
Partner/
Finance/
Reports/
CMS/
```

---

# 08_Partner

```
Mobile App/
Verification/
Wallet/
Performance/
```

---

# 09_AI

```
Prompt Library/
Automation/
Knowledge Base/
Stitch/
```

---

# Assets

```
images/
icons/
logos/
diagrams/
wireframes/
```

---

# Prompt Library

```
Master Prompt

Component Prompt

Screen Prompt

Engineering Prompt

QA Prompt
```

---

# Repository Principles

- Semua artefak memiliki tempat yang jelas.
- Tidak ada duplikasi.
- Selalu gunakan Single Source of Truth.

---

# Document History

| Version | Date | Description |
|----------|------|-------------|
|1.0.0|2026-07-19|Initial Repository Structure|