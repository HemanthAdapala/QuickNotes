HOMESCREEN REDESIGN — QUICK NOTES APP

CONTEXT
Redesign the existing Home Screen with these specific improvements:
1. Empty state with abstract shape illustration
2. Contextual line under the greeting
3. Active tab indicator on bottom nav bar
4. Bottom nav bar tap animations — morphing and satisfying
5. Witty/playful rotating messages

Do NOT change anything else on the screen.
The design system stays exactly the same:
- Cream background #F5F0E8
- Playfair Display for headings
- Inter for body text
- Amber accent #F5A623
- Dark pill bottom nav bar
Everything else is preserved as-is.

---

CHANGE 1 — ABSTRACT SHAPE EMPTY STATE

When the user has zero notes, show an abstract illustration
in the center of the screen.

Illustration rules:
- Build using Flutter CustomPainter — no external assets
- Use soft abstract shapes: overlapping rounded rectangles,
  circles, and organic blobs
- Colors must come from the existing note card palette:
  soft pink, soft yellow, soft blue, soft green, soft purple
  All at 40–50% opacity so they feel airy and light
- Shapes should be 3–5 overlapping elements, not more
- Total illustration size: 180x180px
- No icons, no outlines, no text inside the illustration
- The illustration should feel like scattered note cards
  viewed from above — abstract but recognizable
- Animate on first appearance:
  Each shape fades in and scales from 0.8 → 1.0
  Stagger: 80ms per shape
  Duration per shape: kDurationSlow
  Curve: Curves.easeOut

Below the illustration:
- "No notes yet" in Playfair Display, 20px, charcoal
- Rotating witty message below it (see Change 5)
- Soft amber pill button: "Write your first note →"
  Tapping it opens the Note Editor directly

---

CHANGE 2 — CONTEXTUAL LINE UNDER GREETING

The greeting block currently shows:
  Good Afternoon
  Wednesday
  JUN 24 • TODAY
  [count or "No notes yet"]

Add one contextual line below the date row.
This line is dynamic based on app state:

State A — No notes exist:
  Show nothing here. The empty state handles it.

State B — Notes exist, none edited today:
  "Last edited: [Note Title]" 
  Tappable — opens that note directly
  Font: Inter 400, 13px, muted warm gray

State C — Notes edited today:
  "3 notes today" (already exists, keep as-is)

State D — Streak (user has noted for 3+ consecutive days):
  "🔥 [X] day streak" 
  Font: Inter 400, 13px, amber color for the number
  No other changes — keep it subtle

The contextual line animates in:
  Fade + translateY 6px → 0
  Duration: kDurationNormal
  Triggers whenever the value changes

---

CHANGE 3 — ACTIVE TAB INDICATOR

The bottom nav bar currently has no active state indicator.

Add an active indicator with these exact specs:
- Style: a soft amber pill that slides behind the active icon
- Pill size: 48x32px, border radius 16px
- Pill color: amber #F5A623 at 20% opacity
- The pill slides horizontally to the new tab position
- Slide animation: kDurationNormal, Curves.easeInOutCubic
- Use an AnimatedPositioned or implicit animation
- The active icon itself changes to amber color
- Inactive icons remain white at 60% opacity
- The center FAB button is excluded from this indicator —
  it always stays as the dark circle with + icon

---

CHANGE 4 — BOTTOM NAV BAR TAP ANIMATIONS

This is the most important change. Every tab tap must feel
premium, satisfying, and make the user want to tap again.

Use this exact animation sequence on every tab tap:

STEP 1 — ON TAP DOWN (immediate, 0ms delay)
The icon scales down: 1.0 → 0.85
Duration: 80ms, Curves.easeIn

STEP 2 — ON TAP UP (fires on release)
The icon springs back and overshoots: 0.85 → 1.2 → 1.0
Use TweenSequence for this:
  0%–60%: scale 0.85 → 1.2, Curves.easeOut
  60%–100%: scale 1.2 → 1.0, Curves.elasticOut
Total duration: 400ms

STEP 3 — SIMULTANEOUSLY WITH STEP 2
Emit a burst of 4–5 small dots from the icon center
Each dot:
  - Size: 4px circle
  - Color: amber #F5A623
  - Animates outward in random directions (pre-seeded, not random)
    spread within a 40px radius
  - Fades from opacity 1.0 → 0.0
  - Duration: 350ms, Curves.easeOut
Use a CustomPainter overlay on the nav bar for the dots
Dots must not overflow outside the nav bar pill shape

STEP 4 — ICON MORPH (active icon only)
When a tab becomes active, the icon morphs:
  If using Icon widget: crossfade between inactive and
  active version of the icon (filled vs outlined)
  Duration: kDurationNormal
  Use AnimatedSwitcher with a scale + fade transition:
    transitionBuilder: (child, animation) {
      return ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      );
    }

STEP 5 — AMBER PILL SLIDES
Simultaneously with all above, the amber indicator pill
slides to the new position using AnimatedPositioned
Duration: kDurationNormal, Curves.easeInOutCubic

IMPLEMENTATION NOTE:
Use GestureDetector with onTapDown and onTapUp on each tab.
Use AnimationController for the spring sequence.
Use TickerProviderStateMixin on the nav bar widget.
All durations and curves from animation_constants.dart.

---

CHANGE 5 — WITTY ROTATING MESSAGES

Below "No notes yet" on the empty state, show a rotating
witty message. These are playful, specific to note-taking.

Use exactly these messages, rotating in order:
1. "Your future self will thank you for this."
2. "Great ideas don't remember themselves."
3. "One note today beats ten regrets tomorrow."
4. "Even grocery lists deserve a great app."
5. "Somewhere between shower thoughts and genius."
6. "The best note is the one you actually write."
7. "Your brain called. It wants a backup."
8. "Notes: cheaper than therapy, equally effective."

Rotation behavior:
- Changes every 3 seconds
- Never repeats the same message twice in a row
- Transition: current message fades out (150ms) + 
  new message fades in and slides up 8px → 0 (250ms)
- The transition feels like a gentle card flip upward
- Use a StatefulWidget with a Timer

---

DO NOT CHANGE
- Screen background color
- Greeting text style ("Good Afternoon", day name)
- Date and TODAY label style
- Note count display when notes exist
- Note cards layout and style
- FAB button style and position
- Any other screen in the app
- Navigation behavior

---

ANIMATIONS REMINDER
All Duration and Curve values must reference 
animation_constants.dart constants.
The only exception is the dot burst (350ms) and 
icon press down (80ms) which can be defined as 
local const values inside the nav bar widget since 
they are interaction-specific and not page-level.

---

VALIDATION BEFORE SUBMITTING
□ Abstract shapes render correctly using CustomPainter
□ Shapes animate in on first load with stagger
□ Contextual line shows correct state for each scenario
□ Rotating messages cycle every 3 seconds with transition
□ Active tab pill slides smoothly between all 4 tabs
□ Icon press animation: compress → overshoot → settle
□ Dot burst emits on every tap
□ Icon morphs between inactive and active state
□ Zero hardcoded Duration or Curve values
□ No visual regressions on any existing element
□ All changes work correctly on a physical Android device