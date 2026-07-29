---
name: QuickNotesProjectDesignArchitecture
description: QuickNotes design system and visual architecture guide containing exact color tokens, typography rules, glassmorphism parameters, component corner radii, and UI principles.
risk: safe
source: local
date_added: "2026-07-24"
---

# QuickNotes Project Design Architecture & System Reference

This document serves as the authoritative visual design and architectural reference for the **QuickNotes** Flutter codebase. All UI components, screens, dialogs, and widgets must adhere strictly to these specs.

---

## 1. Core Color System

> [!IMPORTANT]
> **Strict Black Rule**: Never use pure black (`#000000`) for standard body text, card borders, or UI icons. Use Ink (`#333333`) instead. Pure black is reserved strictly for specialized GlassMorphism icon depth treatments or high-contrast button foregrounds.

| Token | Hex / Value | Description & Usage |
| :--- | :--- | :--- |
| **Main Background Color** | `#FFFFFF` | Solid paper background (`#F2F2EE` warm stone for glass layouts, `#080808` dark mode surface). |
| **Ink (Primary Dark)** | `#333333` | Used for all primary text, titles, standard icons, hairlines, and structural dividers. |
| **Notes Accent Color** | `#FFCC00` | Bright Amber/Yellow — active note highlights, "Today" date tags, and note selection states (`#FFA322` fallback). |
| **Tasks Accent Color** | `#0088FF` | Electric Blue — standalone task checkboxes, due-date badges, and calendar task indicators. |
| **Placeholder / Muted** | `#73333333` | Ink at 45% opacity — muted body text, input placeholders, and secondary metadata. |
| **Glass Surface** | `rgba(255, 255, 255, 0.55)` | `Color(0x8CFFFFFF)` — Frosted cards, floating header pills, and floating action panels. |
| **Glass Border** | `rgba(255, 255, 255, 0.65)` | `Color(0xA6FFFFFF)` — Glass panel edge highlights and perimeter borders. |
| **Divider Hairline** | `rgba(51, 51, 51, 0.08)` | `Color(0x14333333)` — Layout separators and list item boundaries. |

### Soft Pastel Collection (Folders & Categories)
* **Coral**: `#FFAAA6`
* **Peach**: `#FFDAB6`
* **Lemon**: `#FFF3A6`
* **Sage**: `#D4ECDD`
* **Sky**: `#A8DADC`
* **Lavender**: `#D6C8FF`
* **Blush**: `#FFC6FF`

---

## 2. Corner Radii & Component Roundness

All containers and interactive elements follow standard rounding geometry to maintain an organic, premium feel inspired by Apple Human Interface Guidelines:

* **Main Card & Container Roundness**: `20px` (`BorderRadius.circular(20)`).
* **Glass Pill Buttons & Header Bar**: `22px` (`BorderRadius.circular(22)` for 44px tall header pills) or full circular caps.
* **Standard Buttons & Inputs**: `8px` – `12px`.
* **Bottom Sheets & Modals**: Top corners `16px` – `20px` (`BorderRadius.vertical(top: Radius.circular(20))`).

---

## 3. Typography System

QuickNotes employs a deliberate dual-font architecture: **Inter** (for UI, body text, inputs, and controls) and **Playfair Display** (for dates and editorial headers).

### Typography Specs
* **Primary Font Family**: `Inter` (via `GoogleFonts.inter`).
* **Serif Accent Font Family**: `Playfair Display` (for date titles: "Monday", "Apr 13", "Today").
* **Weight Mapping**: Adapts strictly to specific panel and screen hierarchies:
  - **Display / Headers**: `FontWeight.w700` (Bold) or `w600` (SemiBold)
  - **Date Headers**: `Playfair Display` `w500` (Medium) / `w600` (SemiBold)
  - **Subtitles & Section Titles**: `FontWeight.w500` (Medium)
  - **Body & Writing Surface**: `FontWeight.w400` (Regular)
* **Major Body Font Size**: `16px`
* **Standard Line Height**: `1.4` – `1.5` (e.g. `height: 1.4` for 16px body results in 22.4px height, line spacing `14` for compact labels).
* **Letter Spacing**: `-0.43px` (or `-0.01` to `-0.02` em) for crisp mobile rendering.
* **Placeholder Text Size**: `20px` (`Inter Regular`, `height: 1.4`).

---

## 4. Glassmorphism & Depth Parameters

Glass surfaces utilize `GlassmorphismPresets` to deliver realistic optical refraction and depth without overwhelming content:

```dart
// Glassmorphism Specifications
blurSigma       = 3.0;   // Frosted background blur strength
depthOpacity    = 0.30;  // 30% layer depth
outlineWidth    = 0.8;   // Sub-pixel sharp outline border
outlineOpacity  = 0.30;  // 30% border opacity
bevelIntensity  = 0.20;  // 20% top-down lighting bevel
```

* **Multi-Layer Drop Shadows**:
  - Soft diffuse shadow: `Offset(0, 8)`, `blurRadius: 15`, `spreadRadius: 0`, `color: Color(0x05000000)` (2% black opacity).
  - Ambient edge definition: Sub-pixel offsets `(1.25, 0)` with `#D0D0D0` color.

---

## 5. Motion & Micro-Interactions

* **Press Compression Scale**: `0.7` scale on touch press (`pressDuration: 80ms`).
* **Settle & Morph Duration**: `1000ms` with `Curves.elasticOut`.
* **Screen Easing**: Smooth spring transitions (250–350ms).
* **Progressive Disclosure**: Toolbar and formatting controls reveal dynamically when writing surface is active.
