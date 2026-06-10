---
name: Gravity Playful
colors:
  background: '#FFFDF9'
  on-background: '#1E1B4B'
  surface: '#FFFFFF'
  surface-dim: '#F3F4F6'
  surface-bright: '#FFFDF9'
  surface-container-lowest: '#FFFFFF'
  surface-container-low: '#FAF8F5'
  surface-container: '#F5F3EF'
  surface-container-high: '#EDEBE7'
  surface-container-highest: '#E5E3DF'
  on-surface: '#1E1B4B'
  on-surface-variant: '#4B5563'
  inverse-surface: '#1E1B4B'
  inverse-on-surface: '#FAF8F5'
  outline: '#1E1B4B'
  outline-variant: '#E2E8F0'
  primary: '#6366F1'
  on-primary: '#FFFFFF'
  primary-container: '#EEF2FF'
  on-primary-container: '#4F46E5'
  secondary: '#14B8A6'
  on-secondary: '#FFFFFF'
  secondary-container: '#CCFBF1'
  on-secondary-container: '#0D9488'
  tertiary: '#F97316'
  on-tertiary: '#FFFFFF'
  tertiary-container: '#FFEDD5'
  on-tertiary-container: '#EA580C'
  error: '#EF4444'
  on-error: '#FFFFFF'
  error-container: '#FEE2E2'
  on-error-container: '#DC2626'
  coral: '#FFAAA6'
  peach: '#FFD3B6'
  lemon: '#FFFFA6'
  sage: '#D4ECDD'
  sky: '#A8DADC'
  lavender: '#D6C8FF'
  blush: '#FFC6FF'
  canvas-white: '#FFFDF9'
  canvas-dark: '#0B0D17'
typography:
  display-lg:
    fontFamily: Outfit
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 44px
    letterSpacing: -0.03em
  display-lg-mobile:
    fontFamily: Outfit
    fontSize: 30px
    fontWeight: '800'
    lineHeight: 36px
  headline-lg:
    fontFamily: Outfit
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
  headline-md:
    fontFamily: Outfit
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 22px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.05em
rounded:
  sm: 0.375rem
  DEFAULT: 0.75rem
  md: 1rem
  lg: 1.5rem
  xl: 2rem
  full: 9999px
spacing:
  unit: 8px
  margin-mobile: 24px
  margin-desktop: 64px
  gutter: 20px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style
The design system is centered on the concept of "Playful Tactility." It transforms note-taking from a sterile text editor into a colorful, sensory journey. The style borrows elements from retro-brutalism and pop-art, utilizing high-energy color blocking, chunky custom typography, and physical card shadows.

The visual mood is **Trendy & Playful** but remains highly usable. Generous spacing (density 5) allows the colorful components to sit side-by-side without feeling cluttered or overstimulating.

## Colors
The palette features high-contrast Indigo (#6366F1) as the primary base, accompanied by soft neon pastels (Coral, Peach, Lemon, Sage, Sky, Lavender, Blush) for note categorization.
- All structural boundaries use a solid dark stroke border (#1E1B4B) instead of light grays to emphasize the comic-style outline.
- Card elevations use a solid, hard shadow offset (#1E1B4B) to convey depth rather than smooth gradients.

## Typography
We pair **Outfit** (a warm, chunky, friendly geometric sans-serif) for all display text and titles with **Plus Jakarta Sans** (a modern, highly legible humanist sans) for reading content.
- Titles use negative letter-spacing (-0.02em) to look compact and punchy.
- Timestamps and tags use **JetBrains Mono** to create a technical, "sticker-label" aesthetic.

## Shapes
Shapes are extremely rounded to represent a friendly, approachable layout:
- Notes Cards: Use a 24px (1.5rem) border radius, giving them a soft, pillow-like silhouette.
- Borders: Solid 1.5px line strokes around cards and buttons to make them pop against the cream canvas.

## Components
- **Buttons:** Large, thick buttons with a solid offset shadow. Pressing down scales the button slightly (-2%) and collapses the shadow (active translation).
- **Note Cards:** Bordered with 1.5px outlines, filled with neon-pastels, and rendered in a staggered masonry grid.
- **Bottom Navigation:** A floating glassmorphic bar that sits above the viewport with a thick outline, containing cartoon-like icons.
