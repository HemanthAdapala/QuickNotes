---
name: Luminous Velocity
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#484831'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#79785f'
  outline-variant: '#c9c8aa'
  surface-tint: '#606200'
  primary: '#606200'
  on-primary: '#ffffff'
  primary-container: '#faff04'
  on-primary-container: '#727500'
  inverse-primary: '#cace00'
  secondary: '#5e5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2e2e2'
  on-secondary-container: '#646464'
  tertiary: '#5e5e5e'
  on-tertiary: '#ffffff'
  tertiary-container: '#f7f5f5'
  on-tertiary-container: '#707070'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e6eb00'
  primary-fixed-dim: '#cace00'
  on-primary-fixed: '#1c1d00'
  on-primary-fixed-variant: '#484a00'
  secondary-fixed: '#e2e2e2'
  secondary-fixed-dim: '#c6c6c6'
  on-secondary-fixed: '#1b1b1b'
  on-secondary-fixed-variant: '#474747'
  tertiary-fixed: '#e4e2e2'
  tertiary-fixed-dim: '#c7c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#464747'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  headline-xl:
    fontFamily: Sora
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Sora
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: '0'
  body-md:
    fontFamily: Sora
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: '0'
  label-bold:
    fontFamily: Sora
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Sora
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.2'
    letterSpacing: '0'
  headline-lg-mobile:
    fontFamily: Sora
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
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
  margin-desktop: 48px
  max-width: 1280px
---

## Brand & Style

This design system embodies "High-Velocity Performance" through a lens of extreme clarity and precision. The brand personality is technical, fast-paced, and unapologetically modern, targeting power users and developers who value efficiency and high-contrast signaling.

The aesthetic follows a **Modern-Minimalist** approach with a **Neon-Accented** twist. By utilizing a pure white environment, the interface feels expansive and lightweight, while the sharp neon accents provide "velocity" by immediately drawing the eye to primary conversion points and status indicators. The emotional response is one of surgical focus—stripping away visual noise to highlight data and action.

## Colors

The palette is anchored by a high-luminance primary accent against a stark, clinical background.

*   **Surface:** Pure White (#FFFFFF) serves as the primary canvas to maximize the "clean" feel and enhance the glow of the accent color.
*   **Primary (Neon):** #FAFF04 is the core highlight color. Because it is highly luminous, it is used for primary action backgrounds and status indicators.
*   **Contrast / Type:** Headlines and body text use a deep charcoal or pure black (#111111) to ensure WCAG-compliant readability against the light surfaces.
*   **Action Text:** When #FAFF04 is used as a background for buttons, the text label must be pure black (#000000) for maximum legibility.
*   **Neutral:** Soft greys (#F8F9FA) are reserved for secondary containers and input fields to provide subtle structural definition without breaking the white-space harmony.

## Typography

The design system exclusively utilizes **Sora** to maintain its geometric, technical character. 

The typographic hierarchy is built on extreme weight contrast. Headlines are heavy and tight (Bold/Semi-Bold with negative letter spacing), creating a "brutalist-light" feel that suggests stability and strength. Body text is kept at a comfortable 16px to 18px range with generous line heights to ensure the information-dense layout remains breathable. Labels use uppercase tracking to add a sense of utility and "dashboard-like" precision.

## Layout & Spacing

The layout is governed by a **Fluid 12-column grid** on desktop and a **4-column grid** on mobile.

*   **Rhythm:** A 4px baseline grid ensures technical alignment across all components.
*   **Margins:** Generous outer margins (48px+) on desktop prevent the high-contrast elements from feeling cluttered. 
*   **Density:** While the outer margins are wide, internal component spacing is tight (8px or 16px) to reinforce the high-velocity, high-efficiency nature of the tool.
*   **Breakpoints:** 
    *   Mobile: 0 - 599px
    *   Tablet: 600px - 1023px
    *   Desktop: 1024px+

## Elevation & Depth

To maintain the clean, "velocity" aesthetic, this design system avoids heavy shadows or complex gradients. 

*   **Tonal Layers:** Depth is created through surface contrast rather than elevation. Backgrounds are #FFFFFF, while "containers" or secondary cards use a subtle #F8F9FA fill.
*   **Ghost Borders:** Instead of shadows, use 1px solid borders in a very light grey (#EEEEEE) to define container boundaries.
*   **High-Contrast Selection:** Active or selected states are indicated by a 2px solid neon (#FAFF04) border or a pure black fill, creating a "stamped" or "indented" feel without physical skeuomorphism.

## Shapes

The shape language is strictly geometric and disciplined. A corner radius of **4px** (Round Four) is applied universally to buttons, input fields, and cards. This small radius softens the "harshness" of the high-contrast palette just enough to feel modern and accessible while retaining a technical, sharp edge. Icons should follow a 2px stroke weight to match the precision of the typography.

## Components

*   **Buttons:** Primary buttons use the #FAFF04 background with #000000 Bold text. Hover states should darken the neon slightly. Secondary buttons use a black border with black text.
*   **Input Fields:** Use a 4px radius, a #F8F9FA background, and a 1px border that turns black on focus. Placeholder text is a soft grey.
*   **Chips/Tags:** Small, rectangular shapes (4px radius) with #FAFF04 background for "Active/Success" statuses and #000000 for "Inactive/Neutral" statuses.
*   **Cards:** Pure white background with a 1px #EEEEEE border. No shadows. Header areas within cards should be separated by a thin horizontal rule.
*   **Lists:** High-density rows with a 1px bottom border. Hover states for list items should use a subtle #F8F9FA background change.
*   **Progress Bars:** The track is a light grey (#EEEEEE) while the indicator is the sharp neon (#FAFF04), creating a high-visibility status update.