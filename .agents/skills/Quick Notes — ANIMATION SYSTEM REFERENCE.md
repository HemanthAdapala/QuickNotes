Quick Notes App — ANIMATION SYSTEM REFERENCE

This Flutter app follows Apple-level subtle animation principles.
Every animation must feel physical, calm, and intentional.
Never use animations that call attention to themselves.

PHILOSOPHY
- Animations should feel like responses, not performances.
- The UI moves because physics demand it, not to impress the user.
- When in doubt, slower and subtler is always better.
- No bounces unless explicitly specified.
- No overshooting. No elastic effects.

GLOBAL ANIMATION CONSTANTS
Define these once in a file called animation_constants.dart
and import everywhere:

const Duration kDurationFast = Duration(milliseconds: 150);
const Duration kDurationNormal = Duration(milliseconds: 250);
const Duration kDurationSlow = Duration(milliseconds: 350);
const Duration kDurationPage = Duration(milliseconds: 400);

const Curve kCurveDefault = Curves.easeInOut;
const Curve kCurveEnter = Curves.easeOut;
const Curve kCurveExit = Curves.easeIn;
const Curve kCurvePage = Curves.easeInOutCubic;
const Curve kCurveSpring = Curves.elasticOut; // Use sparingly

RULES BY ANIMATION TYPE

Page transitions:
- Slide from right on push, slide back on pop
- Simultaneous fade: entering page fades in 0.0 → 1.0
- Duration: kDurationPage with kCurvePage
- Never use the default MaterialPageRoute. Always use
  PageRouteBuilder or go_router with custom transitions.

Modals and bottom sheets:
- Slide up from bottom + fade in simultaneously
- Duration: kDurationNormal
- Dismiss: slide down + fade out, kDurationFast
- Background overlay: fades in to 60% black opacity

Floating Action Button:
- On scroll down: FAB scales out (1.0 → 0.0) + fades
- On scroll up/stop: FAB scales in (0.0 → 1.0) + fades
- Duration: kDurationFast, Curves.easeOut

Cards (note cards on home feed / folder detail):
- On tap: scale down to 0.97, duration 100ms, Curves.easeIn
- On release: scale back to 1.0, duration 150ms, Curves.easeOut
- Use GestureDetector with onTapDown / onTapUp / onTapCancel

List items appearing (folder list, search results):
- Staggered fade + slide up on first load
- Each item: fade 0.0 → 1.0, translateY 12px → 0
- Stagger delay: 40ms per item
- Duration per item: kDurationNormal

Chips and filter tabs:
- Active state: background color animates in, duration 150ms
- Use AnimatedContainer for color transitions

Bottom navigation bar:
- Active dot indicator: slides horizontally to new position
- Duration: kDurationNormal, Curves.easeInOutCubic
- Icon: no scale change — dot movement is the only feedback

Search screen:
- Entry: search bar expands from icon position (scale + fade)
- Results: staggered fade-in list, same as list items above
- Keyboard push: content slides up with the keyboard naturally
  (use resizeToAvoidBottomInset: true)

Context menu (long-press):
- Appears: scale from 0.85 → 1.0 + fade, origin near pressed item
- Duration: kDurationFast
- Disappear: scale 1.0 → 0.9 + fade out

Delete confirmation alert:
- Scale in from 0.9 → 1.0 + fade
- Duration: kDurationNormal, Curves.easeOut

Color transitions (folder/category tint on nav bar):
- Animate with AnimatedContainer or ColorTween
- Duration: kDurationNormal

Skeleton loading states (before data loads):
- Shimmer effect: use shimmer package
- Animate left-to-right highlight, looping
- Match exact layout of loaded content

WHAT TO NEVER DO
- Never use Curves.bounceOut on UI elements
- Never animate font size
- Never use duration > 500ms for any UI response
- Never stack multiple animations that all start at once
  (use stagger instead)
- Never animate layout shifts (avoid AnimatedSize unless subtle)
- Never use rotation animations in a notes app context