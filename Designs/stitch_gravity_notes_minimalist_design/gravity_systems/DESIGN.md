---
name: Gravity Systems
colors:
  surface: '#faf9f7'
  surface-dim: '#dadad8'
  surface-bright: '#faf9f7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f1'
  surface-container: '#eeeeec'
  surface-container-high: '#e9e8e6'
  surface-container-highest: '#e3e2e0'
  on-surface: '#1a1c1b'
  on-surface-variant: '#444748'
  inverse-surface: '#2f3130'
  inverse-on-surface: '#f1f1ef'
  outline: '#747878'
  outline-variant: '#c4c7c7'
  surface-tint: '#5f5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1c1b1b'
  on-primary-container: '#858383'
  inverse-primary: '#c9c6c5'
  secondary: '#005fad'
  on-secondary: '#ffffff'
  secondary-container: '#499dfe'
  on-secondary-container: '#003462'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1c1b1b'
  on-tertiary-container: '#858383'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e5e2e1'
  primary-fixed-dim: '#c9c6c5'
  on-primary-fixed: '#1c1b1b'
  on-primary-fixed-variant: '#474646'
  secondary-fixed: '#d4e3ff'
  secondary-fixed-dim: '#a4c9ff'
  on-secondary-fixed: '#001c39'
  on-secondary-fixed-variant: '#004884'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c9c6c5'
  on-tertiary-fixed: '#1c1b1b'
  on-tertiary-fixed-variant: '#474646'
  background: '#faf9f7'
  on-background: '#1a1c1b'
  surface-variant: '#e3e2e0'
  canvas-off-white: '#FFFEFC'
  border-subtle: '#EBEBE8'
  text-secondary: '#91918E'
  surface-taupe: '#F5F5F7'
typography:
  display-xl:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 34px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 30px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  caption:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  margin-mobile: 20px
  margin-desktop: 80px
  gutter: 24px
  max-width-content: 720px
  unit-xs: 4px
  unit-sm: 8px
  unit-md: 16px
  unit-lg: 32px
---

## Brand & Style

The design system is anchored in the concept of "Digital Weightlessness." It prioritizes the writer's focus by stripping away the chrome of traditional productivity software, leaving only essential tools that emerge when needed. The target audience includes writers, researchers, and thinkers who find current tools overstimulating.

The visual style is **High-End Minimalism** with a **Tactile** nuance. It borrows the structural precision of Linear, the layout clarity of Apple, and the content-first hierarchy of Notion. The interface is designed to feel like a premium physical notebook: quiet, high-quality, and responsive to the touch. It avoids standard dashboard tropes in favor of an expansive, "Zen" workspace where whitespace is treated as a functional element rather than empty space.

## Colors

The palette is intentionally restrained to prevent cognitive load. 

- **Primary:** A deep, ink-like black (#040404) used for maximum legibility in typography and primary icons.
- **Neutral/Canvas:** An ultra-soft off-white (#FFFEFC) that reduces the harsh glare of pure #FFFFFF, mimicking high-grade paper.
- **Secondary/Accent:** A precise, intellectual blue (#2383E2) used exclusively for interactive states or highlighting critical paths.
- **Named Colors:** `text-secondary` is a muted grey for metadata and placeholder text, while `surface-taupe` is used for low-contrast backgrounds like sidebars or secondary panels to distinguish them from the main writing canvas.

## Typography

Typography is the primary vehicle for visual hierarchy. **Inter** is used for all functional and reading text due to its exceptional legibility and neutral character. **JetBrains Mono** is introduced sparingly for labels, metadata, and technical indicators to provide a subtle "pro-tool" aesthetic.

The type scale features generous line-heights (1.6x for body text) to ensure a comfortable, airy reading experience. Paragraph spacing should be expansive. Headlines use tighter letter-spacing for a sophisticated, editorial feel.

## Layout & Spacing

This design system employs a **Fixed Content Grid** for the writing experience and a **Fluid Utility Grid** for the workspace.

1. **Writing Canvas:** To maintain focus, the main text area is capped at a `max-width-content` of 720px and centered. This prevents line lengths from becoming too long for comfortable scanning.
2. **Workspace:** Surrounding utilities use a fluid layout with wide margins (`margin-desktop`) to create a sense of openness.
3. **Responsive Flow:** 
   - **Mobile:** Margins shrink to 20px. Navigation collapses into a bottom-bar or a minimalist gesture-based overlay.
   - **Desktop:** The sidebar is collapsible (Arc-style) to enter "Zen Mode," where only the 720px content column remains.

## Elevation & Depth

Depth is conveyed through **Tonal Layers** and **Low-Contrast Outlines** rather than traditional shadows. 

- **Level 0 (Canvas):** The base writing layer (#FFFEFC).
- **Level 1 (Panels):** Sidebars and bottom bars use a subtle fill (#F5F5F7) and a 1px border (#EBEBE8) to separate from the canvas. 
- **Floating States:** Modals and context menus use a very soft, high-diffusion shadow (Color: #000000, Opacity: 4%, Blur: 20px) and a solid 1px border to ensure they "pop" without feeling heavy.
- **Glassmorphism:** Use backdrop blurs (20px) for navigation bars when scrolling content underneath, maintaining a sense of spatial awareness.

## Shapes

The shape language is precise and disciplined. A "Soft" roundedness (0.25rem) is applied to primary UI elements like buttons and inputs to keep the interface approachable but professional. Larger containers, such as cards or modals, may use `rounded-lg` (0.5rem) to emphasize their role as distinct surfaces. Circle shapes are reserved exclusively for avatars.

## Components

- **Buttons:** Primary buttons use a solid black (#040404) fill with white text. Ghost buttons (border-only or text-only) are preferred for secondary actions to keep the UI light.
- **Inputs:** Writing inputs are invisible by default (no borders), appearing as simple text. Functional inputs (search, settings) use a subtle `surface-taupe` background that highlights on focus.
- **Chips:** Used for tagging. They should be rectangular with `rounded-sm`, using a light grey background and `label-sm` typography.
- **Progressive Disclosure:** Action menus (formatting, file settings) remain hidden until a user hovers over a specific block or selects text, following the "Disappearing Interface" philosophy.
- **The "Command Bar":** A central floating component (Linear-style) triggered by Cmd+K, acting as the primary navigation and action hub to keep the main canvas clear of buttons.