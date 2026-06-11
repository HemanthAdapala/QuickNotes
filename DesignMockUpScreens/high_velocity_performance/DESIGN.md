---
name: High-Velocity Performance
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1b1b1b'
  surface-container: '#1f1f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353535'
  on-surface: '#e2e2e2'
  on-surface-variant: '#c9c8aa'
  inverse-surface: '#e2e2e2'
  inverse-on-surface: '#303030'
  outline: '#939277'
  outline-variant: '#484831'
  surface-tint: '#cace00'
  primary: '#ffffff'
  on-primary: '#313300'
  primary-container: '#e6eb00'
  on-primary-container: '#666800'
  inverse-primary: '#606200'
  secondary: '#a1c9ff'
  on-secondary: '#00325a'
  secondary-container: '#3094f1'
  on-secondary-container: '#002b4f'
  tertiary: '#ffffff'
  on-tertiary: '#0d3638'
  tertiary-container: '#c2eaec'
  on-tertiary-container: '#466b6d'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e6eb00'
  primary-fixed-dim: '#cace00'
  on-primary-fixed: '#1c1d00'
  on-primary-fixed-variant: '#484a00'
  secondary-fixed: '#d2e4ff'
  secondary-fixed-dim: '#a1c9ff'
  on-secondary-fixed: '#001c37'
  on-secondary-fixed-variant: '#004880'
  tertiary-fixed: '#c2eaec'
  tertiary-fixed-dim: '#a7ced0'
  on-tertiary-fixed: '#002021'
  on-tertiary-fixed-variant: '#274d4f'
  background: '#131313'
  on-background: '#e2e2e2'
  surface-variant: '#353535'
  high-vis-neon: '#FAFF04'
  performance-blue: '#43A1FF'
  surface-base: '#000000'
  surface-elevated: '#121212'
  surface-stroke: '#262626'
  text-primary: '#FFFFFF'
  text-secondary: '#A1A1A1'
typography:
  display-lg:
    fontFamily: Sora
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '1.2'
  title-md:
    fontFamily: Sora
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Sora
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  body-sm:
    fontFamily: Sora
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.5'
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1'
    letterSpacing: 0.1em
  mono-data:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: '1.4'
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
  container-max: 1200px
---

## Brand & Style

This design system is engineered for high-velocity performance, capturing the essence of technical precision and rapid cognitive flow. It is designed for users who treat note-taking and knowledge management as a high-stakes performance activity. 

The aesthetic sits at the intersection of **High-Contrast Bold** and **Modern Technical** styles. It utilizes a deep black environment to eliminate distractions, punctuated by high-frequency neon accents that draw immediate attention to critical actions and active states. The visual language is unapologetically digital, favoring raw efficiency and structural clarity over decorative softness. It evokes a feeling of being "in the zone"—focused, fast, and frictionless.

## Colors

The palette is anchored in a pure "Ink Black" (`#000000`) background to maximize contrast and reduce eye strain during deep work sessions. The primary driver is **High-Vis Neon** (`#FAFF04`), a sharp yellow-green used exclusively for primary calls-to-action, active indicators, and critical highlights. 

**Performance Blue** (`#43A1FF`) serves as a secondary accent, providing a cooler alternative for informational states, secondary links, or categorization without the aggressive urgency of the neon. Neutral tones are strictly tiered: white for primary data, and mid-range grays for secondary metadata and borders. Avoid gradients; use flat, solid fills to maintain the technical, high-precision aesthetic.

## Typography

Typography in this design system is built on **Sora**, a typeface that balances geometric tech-influences with high legibility. Headlines should be bold and tightly tracked to feel impactful and "heavy." 

To enhance the technical feel, **JetBrains Mono** is introduced for metadata, labels, and timestamps. This monospaced secondary font reinforces the "high-velocity" performance narrative, suggesting a system that is data-driven and precise. Use uppercase styling for labels to create a clear visual distinction between content and UI chrome.

## Layout & Spacing

This design system utilizes a **Fixed Grid** model on desktop and a **Fluid Grid** on mobile. The rhythm is based on a strict 4px baseline, ensuring all elements align with mathematical precision.

- **Desktop:** 12-column grid with a 1200px max-width. Gutters are kept tight (16px) to maintain a dense, information-rich environment.
- **Mobile:** Single column with 16px side margins. 
- **Reflow:** Components should stack vertically on mobile, but maintain horizontal density on desktop to minimize vertical scrolling. Use "Space-Between" logic for headers to keep actions at the edges of the screen, maximizing the central workspace.

## Elevation & Depth

Depth is conveyed through **Tonal Layers** and **Low-Contrast Outlines** rather than traditional shadows. Shadows are largely avoided to maintain the "flat-tech" aesthetic.

1.  **Base Layer:** Pure black (`#000000`) for the main canvas.
2.  **Surface Layer:** A dark charcoal (`#121212`) for cards, sidebars, and modals to create subtle separation.
3.  **Stroke:** Every interactive container must have a 1px solid border (`#262626`).
4.  **Active State:** When an element is focused or active, the stroke shifts to the **High-Vis Neon** or **Performance Blue**, creating a "glow" effect via color rather than blur.

This approach ensures the UI feels like a single, solid piece of hardware.

## Shapes

The shape language is defined by **Low-Radius Geometry**. Roundedness is kept to a minimum (4px) to ensure the UI feels sharp, professional, and aggressive. 

Avoid circles for everything except user avatars. Buttons, input fields, and card containers should all use the consistent 4px radius. This "softened square" look maintains the technical integrity of the grid while preventing the UI from feeling dated or overly "brutalist."

## Components

### Buttons
Primary buttons use a solid **High-Vis Neon** fill with black text. Secondary buttons use a transparent background with a 1px white or blue stroke. All buttons feature a 4px corner radius. On hover, primary buttons should have a slight "glitch" or immediate color shift rather than a slow fade.

### Chips & Tags
Metadata tags use **JetBrains Mono** in all-caps. They should have a subtle dark gray background with a 1px border. For "Active" or "Critical" tags, use the neon accent for the text color.

### Input Fields
Inputs are bottom-bordered only or fully outlined with a `#262626` stroke. When active, the stroke turns **Performance Blue**. Placeholder text should be a dimmed gray, shifting to white upon entry.

### Cards
Cards are containers for notes and data. They should not have shadows. Separation is achieved through a `#121212` background and a `#262626` border. 

### Lists & Navigation
Navigation items should be lean. Use the neon accent for the "active indicator"—usually a vertical 2px bar on the left side of the list item. Text remains white for high legibility.

### Additional Components: Performance HUD
A "Performance HUD" (Heads-Up Display) component is recommended for the Gravity Notes app. This is a small, sticky overlay showing note count, word count, or sync status using monospaced type and neon green indicators, mimicking a command-line or telemetry interface.