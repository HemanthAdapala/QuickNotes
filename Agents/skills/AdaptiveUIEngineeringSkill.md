# Quick Notes — Adaptive UI Engineering

## ROLE

You are responsible for implementing and maintaining responsive, adaptive, and visually faithful UI across the entire Quick Notes Flutter project.

This skill governs ALL Quick Notes UI work involving:

- Figma → Flutter implementation
- New screens
- Existing screen modifications
- Responsive layout fixes
- Device-specific visual discrepancies
- Component resizing
- Spacing/layout refactors
- Safe-area handling
- Tablet/foldable support
- Orientation changes
- Bottom navigation
- Bottom sheets
- Modals
- Overlays
- Glass/Liquid Glass UI
- Cards
- Forms
- Lists
- Calendar
- Editor
- Gesture-driven components
- Animation-driven components
- Future screens/components

This is a PROJECT-WIDE responsive UI system.

Do NOT treat this as a Home Screen-specific solution.


# CORE PHILOSOPHY

The fundamental rule of this skill is:

> Figma is the visual target.
> Available device space is the physical constraint.

DO NOT reproduce the Figma canvas as a rigid coordinate system.

Instead:

> Reproduce the design intent of the Figma design under the actual constraints of the device/window.

The objective is for Quick Notes to feel like the same product across devices even when:

- spacing changes slightly;
- content becomes scrollable;
- components adapt their width;
- additional space is available;
- the composition changes on tablets/foldables;
- safe areas differ;
- screen aspect ratios differ.

The user should recognize:

> "This is still Quick Notes."

Responsive behavior must preserve the product's visual identity.


# 1. DESIGN INTENT OVER RAW COORDINATES

When translating Figma into Flutter, never assume that an absolute Figma coordinate should become an absolute Flutter coordinate.

For example:

Figma:

    top: 172px

does NOT automatically mean:

    Positioned(top: 172)

First determine what the coordinate represents.

Ask:

- Is this a relationship?
- Is this intentional spacing?
- Is this an anchor?
- Is this a fixed component dimension?
- Is this simply the result of the reference viewport?

Prefer expressing:

    Header
      ↓
    flexible spacing
      ↓
    Content

rather than:

    Content starts at Y = 172


PRIORITY ORDER:

1. Usability
2. Interaction correctness
3. Design intent
4. Visual hierarchy
5. Relationships between elements
6. Safe-area/system constraints
7. Interaction-critical geometry
8. Responsive adaptation
9. Exact reference-device coordinates


# 2. REFERENCE DEVICE ≠ UNIVERSAL CANVAS

A Figma design may have been created using a particular iPhone or Android viewport.

Treat that viewport as:

    REFERENCE COMPOSITION

NOT:

    UNIVERSAL SCREEN SIZE

The reference device establishes:

- visual proportions;
- spacing rhythm;
- hierarchy;
- intended composition;
- component relationships.

It does NOT establish:

- universal screen coordinates;
- universal screen height;
- universal available content height;
- universal safe-area dimensions.

The reference viewport is used for calibration and visual comparison.


# 3. THINK IN RELATIONSHIPS

Whenever possible, express layout relationships rather than screen coordinates.

Examples:

BAD:

    top = 172

BETTER:

    content appears below the header with intentional spacing.

BAD:

    bottom = 58

BETTER:

    bottom navigation is anchored to the usable bottom region.

BAD:

    panel height = screenHeight - 172

BETTER:

    panel occupies the available space between the upper content and bottom navigation.

BAD:

    card X position = screenWidth / 2 - 161

BETTER:

    card is centered within the available content region.

Relationships should drive the layout.


# 4. DIMENSION CLASSIFICATION

Before implementing or significantly modifying a screen, classify important dimensions.

Every major dimension should be considered one of:

## FIXED

Used when a value represents intentional visual identity or interaction requirements.

Examples:

- icon size;
- minimum touch target;
- button height;
- corner radius;
- specific typography size;
- interaction-critical component geometry.

A fixed value is acceptable when it is intentionally fixed.

A fixed value is suspicious when it is being used to define the entire screen's geometry.

---

## FLUID

Changes naturally according to available space.

Examples:

- main content area;
- large panels;
- flexible columns;
- available-width containers.

---

## CONSTRAINED

Can adapt but should remain within useful limits.

Examples:

- card width;
- readable text width;
- large content surfaces;
- tablet content regions.

---

## INTRINSIC

Size should primarily be determined by content.

Examples:

- text;
- labels;
- list rows;
- content-driven sections.

---

## ANCHORED

Position is determined relative to a meaningful boundary.

Examples:

- header → top safe area;
- navigation → bottom usable region;
- floating action → content boundary.

---

## SCROLLABLE

Content may exceed the viewport and should scroll instead of being clipped.

Examples:

- long settings;
- forms;
- editor;
- notes;
- lists.

---

## ADAPTIVE

Composition changes when available space becomes fundamentally different.

Examples:

- single-column → two-column;
- stacked → inline;
- phone composition → tablet composition.


# 5. THREE-LEVEL RESPONSIVE MODEL

Always reason about UI at three levels.

## LEVEL 1 — MACRO LAYOUT

The structure of the screen.

Examples:

- safe area;
- header;
- content region;
- bottom navigation;
- major panels;
- major sections.

Macro layout should generally be constraint-driven.

---

## LEVEL 2 — COMPONENT LAYOUT

Individual UI components.

Examples:

- cards;
- buttons;
- rows;
- forms;
- calendar;
- lists;
- toolbars.

Components may be fluid, constrained, intrinsic, or fixed depending on their design contract.

---

## LEVEL 3 — INTERACTION GEOMETRY

Geometry required for behavior.

Examples:

- swipe thresholds;
- drag distances;
- slider ranges;
- gesture regions;
- animation bounds;
- selection handles;
- custom painting;
- coordinate transforms.

Interaction geometry must be investigated before dimensions are changed.

IMPORTANT:

> A responsive parent does NOT mean every child should become fluid.


# 6. SHORT SCREEN BEHAVIOR

When the available vertical space is smaller than the reference design:

Use this order:

    1. Preserve important composition
    2. Reduce optional/flexible spacing
    3. Preserve minimum usable dimensions
    4. Allow appropriate content to scroll
    5. Adapt composition if necessary

DO NOT:

- clip content;
- overlap elements;
- hide required controls;
- make typography unreasonably small;
- destroy touch targets;
- squash interaction-critical components;
- add device-specific offsets.

Quick Notes prefers:

> controlled compression first, scrolling second.

Scrolling is NOT considered a failure.


# 7. TALL SCREEN BEHAVIOR

When additional vertical space exists:

Do NOT automatically stretch every component.

Instead:

- allow flexible regions to breathe;
- preserve important proportions;
- increase controlled spacing;
- expand appropriate content regions;
- maintain visual hierarchy;
- use sensible maximum dimensions where appropriate.

Quick Notes prefers:

> controlled expansion.

Extra space should feel intentional, not empty because a hardcoded height prevented the layout from using it.


# 8. WIDTH BEHAVIOR

Horizontal layouts must adapt to available width while preserving required design padding.

The design must NEVER solve narrow screens by destroying its intended padding.

Example:

    Screen
    ├── required outer padding
    └── flexible content

Do NOT allow:

    24px padding
        ↓
    8px
        ↓
    2px

simply to force content to fit.

If a component becomes wider on a larger screen, it should only expand when doing so preserves the design intent.

Do not stretch components indefinitely.


# 9. COMPONENT WIDTH

Components may be:

- fixed;
- fluid;
- constrained;
- centered;
- adaptive.

Choose based on the component's actual design and interaction contract.

Do NOT automatically make every component:

    width: double.infinity

and do NOT automatically make every component:

    fixed width = Figma width

Determine which behavior is correct.


# 10. DESIGN PADDING IS A CONTRACT

Required visual padding must be preserved.

If the Figma design establishes meaningful outer padding, that padding should remain unless the screen genuinely cannot accommodate it.

When space becomes limited:

    reduce optional spacing
    before
    destroying required padding.

When space increases:

    allow breathing room
    without creating excessive empty areas.


# 11. SAFE AREA IS SYSTEM GEOMETRY

Never assume all devices have the same usable top/bottom space.

Account for:

- status bar;
- notch;
- Dynamic Island;
- punch-hole camera areas;
- gesture navigation;
- Android navigation areas;
- keyboard;
- viewInsets;
- orientation;
- split-screen;
- multi-window;
- foldable configurations.

Prefer structural safe-area handling over manually adding MediaQuery values into many independent absolute coordinates.

Avoid patterns like:

    top = MediaQuery.padding.top + arbitrary Figma coordinate

when the same relationship can be expressed structurally.

System insets belong to the system layout.

Do not confuse them with design spacing.


# 12. STACK AND POSITIONED ARE ALLOWED

DO NOT ban:

- Stack
- Positioned
- Align
- absolute positioning

These are legitimate tools for:

- overlays;
- floating controls;
- decorative layers;
- glass effects;
- image composition;
- drag surfaces;
- visual effects;
- intentional anchoring.

However:

> Do not use Stack + Positioned as the default mechanism for expressing the entire structural layout when a constraint-based layout better expresses the relationship.

Ask:

> Is this coordinate expressing visual composition, or compensating for a missing layout relationship?

If visual composition:

    Stack may be correct.

If structural layout:

    Prefer constraint-based relationships.


# 13. FLEXIBLE MACRO LAYOUT

When a screen contains:

    top region
    content region
    bottom region

prefer a structure that allows the content region to negotiate available space.

Conceptually:

    Safe area
        ↓
    Top content
        ↓
    Flexible/scrollable content region
        ↓
    Bottom navigation

Do not calculate major screen regions from fixed pixel coordinates unless there is a documented reason.

Use appropriate Flutter constraint mechanisms such as:

- Column;
- Row;
- Expanded;
- Flexible;
- LayoutBuilder;
- ConstrainedBox;
- Align;
- Center;
- SafeArea;
- scrolling widgets;
- FractionallySizedBox;

when they correctly represent the intended relationship.

Do not use these widgets mechanically.

The layout relationship comes first.


# 14. SCROLL OWNERSHIP

When content does not fit, determine exactly which region should scroll.

Examples:

    stable header
    ↓
    scrollable content
    ↓
    stable bottom navigation

Do not automatically make the entire screen scroll.

Avoid nested scrolling unless there is a deliberate UX reason.

Scrolling should belong to the region whose content can legitimately exceed the available space.


# 15. INTERACTION GEOMETRY PROTECTION

Before changing a component's dimensions, inspect whether its behavior depends on geometry.

Inspect:

- drag thresholds;
- swipe thresholds;
- animation target positions;
- rotation calculations;
- slider ranges;
- hit testing;
- RenderBox size;
- coordinate transforms;
- custom painting;
- gesture detection;
- selection handles;
- scroll calculations.

If interaction behavior depends on fixed geometry:

DO NOT blindly make the component fluid.

Instead determine whether:

1. the component already adapts safely;
2. the component should remain constrained while its parent adapts;
3. an adaptation layer is required;
4. the interaction system itself must be redesigned.

Never silently break interaction physics in the name of responsiveness.


# 16. QUICK NOTES EXAMPLE — NOTES AND TASKS

Quick Notes currently contains interaction-heavy components such as:

- NotesStackWidget
- TaskWidget
- SingleDocumentDragOverlay

If their internal animation/gesture mathematics depend on their geometry:

The parent layout may become responsive.

The internal geometry must not be arbitrarily stretched.

Think:

    responsive environment
            ↓
    constrained interactive component

NOT:

    responsive environment
            ↓
    stretch every internal dimension

If true fluid geometry is eventually required, redesign the interaction math intentionally rather than applying scaling as a shortcut.


# 17. TOUCH TARGET PROTECTION

Visual size and interaction size are separate.

Do not shrink:

- buttons;
- navigation items;
- sliders;
- toolbar controls;
- gesture targets

below usable dimensions simply because the viewport is narrow.

An icon can visually be smaller than its hit target.

Never solve layout problems by making controls unusably small.


# 18. TYPOGRAPHY

Do not resize typography simply to force the layout to fit.

Preserve:

- font family;
- hierarchy;
- weight;
- readability;
- line-height;
- intended visual character.

If content does not fit:

    adjust flexible layout
    ↓
    reduce optional spacing
    ↓
    scroll
    ↓
    adapt composition

Do not turn a layout problem into a typography problem.


# 19. BOTTOM NAVIGATION

Bottom navigation must be anchored relative to the actual usable bottom region.

Distinguish:

- visual navigation height;
- touch target;
- safe-area occupancy;
- external spacing.

Do not assume:

    screen bottom = navigation bottom

Do not use arbitrary device-specific bottom offsets.

Do not shrink navigation controls merely because the screen is narrow.

If the navigation has a fixed visual height, keep that identity while allowing the surrounding system geometry to adapt.


# 20. DECORATIVE UI

Decorative UI may use more flexible positioning than functional UI.

Examples:

- ambient glows;
- gradients;
- glass surfaces;
- decorative circles;
- background imagery;
- visual effects.

These may legitimately use:

- proportional positioning;
- Stack;
- Positioned;
- visual scaling.

But functional layout should not depend on decorative coordinate systems.

Separate:

    visual geometry

from:

    functional layout geometry.


# 21. TABLETS AND FOLDABLES

Do not create a new layout merely because the device is called:

- tablet;
- foldable;
- large phone.

Instead inspect actual available window constraints.

If the phone composition still works:

    preserve it.

If available space is fundamentally different:

    adapt the composition.

Examples of legitimate adaptation:

    single column
        ↓
    two columns

    narrow content
        ↓
    constrained wide content

    stacked controls
        ↓
    inline controls

Do not create unnecessary platform-specific layouts.


# 22. BREAKPOINTS

Breakpoints must represent meaningful behavioral transitions.

GOOD:

    narrow layout
        ↓
    compact layout

or:

    single column
        ↓
    two columns

BAD:

    if screenHeight < 780

when the only purpose is to fix a particular device.

Avoid binary device-size patches.

If a breakpoint is introduced, document:

- what behavior changes;
- why it changes;
- what constraint makes the change necessary.


# 23. DEVICE-SPECIFIC PATCHES ARE FORBIDDEN BY DEFAULT

Do not write:

    if Samsung...
    if OnePlus...
    if iPhone...
    if Galaxy Fold...

Do not add:

    +12px
    -18px
    special bottom offset

to fix one device without identifying the underlying layout problem.

If one device breaks:

> Investigate the constraint relationship first.

A device-specific fix requires a genuine platform/system reason and must be documented.


# 24. HARD-CODED VALUES

Hardcoded values are NOT automatically forbidden.

Good hardcoded values may represent:

- design tokens;
- icon sizes;
- corner radii;
- minimum touch targets;
- interaction thresholds;
- component identity;
- controlled maximum dimensions.

Suspicious hardcoded values include:

- full-screen heights;
- arbitrary screen Y coordinates;
- device-specific offsets;
- duplicated safe-area calculations;
- fixed panel heights;
- coordinate math replacing parent constraints.

Ask:

> Is this value describing the component, or describing the entire device?

Component → may be valid.

Device layout → investigate.


# 25. CLAMP RULE

clamp() is allowed.

Use it for values that legitimately need bounds.

Examples:

- interaction ranges;
- controlled spacing;
- component dimensions;
- maximum readable width.

But be suspicious when clamp() prevents a major layout region from negotiating available space.

For example:

    mainPanelHeight.clamp(0, 658)

requires investigation if the panel is supposed to occupy available screen space.

Do not use clamp() to hide a layout architecture problem.


# 26. NO GLOBAL UI SCALING

Do not solve responsiveness by applying one global scale factor to the entire screen.

Avoid:

    screenScale = availableWidth / figmaWidth

followed by scaling every element.

Global scaling can:

- shrink touch targets;
- shrink typography;
- distort spacing;
- break interaction physics;
- make large devices look artificially enlarged;
- make narrow devices unusably small.

Use responsive constraints at the appropriate layout level instead.


# 27. FIGMA FIDELITY

Figma remains the visual source of truth for:

- hierarchy;
- typography;
- colors;
- spacing rhythm;
- component character;
- visual proportions;
- alignment;
- overall composition.

But exact coordinates are subordinate to actual device constraints.

The goal is:

> visual fidelity without coordinate dependency.


# 28. DESIGN IDENTITY VS LAYOUT GEOMETRY

Always distinguish:

## DESIGN IDENTITY

Examples:

- colors;
- typography;
- corner radius;
- card character;
- glass effects;
- icon language;
- visual hierarchy.

## LAYOUT GEOMETRY

Examples:

- available width;
- available height;
- safe-area insets;
- parent constraints;
- flexible regions;
- scroll regions.

Responsive behavior should primarily alter layout geometry while protecting design identity.


# 29. DIAGNOSING A DEVICE DIFFERENCE

When UI looks different on two devices:

DO NOT immediately change coordinates.

Follow this process.

## STEP 1 — REPRODUCE

Record:

- available width;
- available height;
- orientation;
- safe-area insets;
- keyboard/viewInsets if relevant.

## STEP 2 — IDENTIFY THE EXACT DIFFERENCE

Determine whether the problem is:

- position;
- size;
- clipping;
- overlap;
- spacing;
- safe area;
- scrolling;
- touch area;
- animation;
- navigation placement.

## STEP 3 — TRACE THE CONSTRAINT CHAIN

Inspect:

    screen
      ↓
    parent
      ↓
    intermediate containers
      ↓
    affected component

Determine where the incorrect constraint originates.

## STEP 4 — CLASSIFY THE CAUSE

Possible causes:

- incorrect macro layout;
- fixed screen-level dimension;
- incorrect parent constraint;
- unnecessary clamp;
- manual safe-area math;
- wrong scroll ownership;
- interaction geometry conflict;
- missing adaptive behavior;
- legitimate platform/system behavior.

## STEP 5 — FIX THE ARCHITECTURE

Prefer:

    fix relationship

over:

    move element until it looks right.

## STEP 6 — REGRESSION TEST

Verify the fix against other viewport conditions.


# 30. VALIDATION REQUIREMENT

A screen is NOT considered responsive merely because:

- it matches Figma;
- it works on one phone;
- Flutter reports no overflow.

Validate the screen against appropriate variations.

At minimum consider:

1. Figma/reference viewport
2. shorter viewport
3. taller viewport
4. narrower viewport
5. wider viewport
6. different safe-area conditions
7. relevant landscape orientation
8. relevant tablet/large-window configuration
9. relevant foldable configuration
10. keyboard-open state for input-heavy screens

Not every screen requires every case.

Choose the cases relevant to that screen.


# 31. VISUAL VALIDATION

Inspect:

- clipping;
- overlap;
- spacing;
- alignment;
- padding;
- typography;
- navigation placement;
- safe areas;
- touch targets;
- scrolling;
- proportions;
- interaction behavior;
- visual hierarchy;
- Figma fidelity.

Do not use only automated overflow checks.

A screen can have zero RenderFlex overflow and still be visually broken.


# 32. EXISTING RESPONSIVE PATTERNS

If an existing Quick Notes screen already uses a strong responsive architecture:

    preserve it where possible.

For example, an existing screen using:

    LayoutBuilder
    ConstrainedBox
    scrolling
    SafeArea

may already demonstrate a good project pattern.

Do not rewrite working responsive architecture merely to make code look different.

Prefer proven project patterns when they satisfy this contract.


# 33. EXISTING COMPONENT CONTRACTS

Before changing a reusable component's dimensions, investigate:

- all callers;
- parent constraints;
- child assumptions;
- animation dependencies;
- gesture dependencies;
- rendering dependencies;
- scrolling;
- hit testing;
- custom layout;
- coordinate calculations.

A component's visual appearance alone is NOT enough to determine whether it can safely become fluid.


# 34. RESPONSIVE CHANGE BOUNDARIES

When a component cannot safely become fluid, choose one:

## OPTION A — CONSTRAIN THE COMPONENT

Keep its internal geometry stable while adapting its parent.

## OPTION B — ADAPT AROUND THE COMPONENT

Give the component an adaptive surrounding layout without changing its internal interaction contract.

## OPTION C — REDESIGN THE COMPONENT

Only when true fluid geometry is actually required.

If Option C is necessary, explicitly state that the component's interaction/layout architecture must be redesigned.


# 35. INVESTIGATION BEFORE MAJOR RESPONSIVE REFACTOR

Before a major responsive refactor, inspect:

- widget tree;
- layout hierarchy;
- fixed dimensions;
- Positioned usage;
- Stack usage;
- clamp usage;
- MediaQuery usage;
- SafeArea usage;
- scroll ownership;
- component geometry;
- gesture logic;
- animation logic;
- custom rendering;
- existing responsive implementations.

Do not perform a major responsive rewrite from visual inspection alone.


# 36. ANTI-SYMPTOM RULE

Never fix a responsive problem by accumulating local patches.

If a device looks wrong:

BAD:

    move component 12px upward.

BETTER:

    determine why the parent gave it the wrong available space.

If the bottom navigation is too low:

BAD:

    bottom -= 16

BETTER:

    inspect the relationship between:
    screen
    safe area
    content
    navigation.


# 37. REGRESSION PROTECTION

Responsive work must not silently break:

- existing screens;
- navigation;
- gestures;
- animations;
- scrolling;
- accessibility;
- touch behavior;
- visual identity.

After changes:

- run relevant tests;
- inspect affected screens;
- validate relevant viewport conditions;
- check shared components used elsewhere.


# 38. STOP CONDITIONS

STOP implementation and investigate further when:

- changing dimensions affects gesture physics;
- Figma coordinates conflict with safe-area requirements;
- a fixed height appears to compensate for missing constraints;
- a breakpoint exists only to fix one device;
- a device-specific condition is proposed;
- fluid resizing invalidates animation math;
- content must be clipped to preserve the design;
- touch targets must become unusably small;
- a responsive change causes another screen to break;
- the correct composition cannot physically fit.

Do not silently choose a fragile workaround.

Report the conflict and identify the architectural options.


# 39. IMPLEMENTATION WORKFLOW

For every significant Figma/UI task follow:

    INVESTIGATE
        ↓
    IDENTIFY DESIGN INTENT
        ↓
    IDENTIFY RELATIONSHIPS
        ↓
    CLASSIFY DIMENSIONS
        ↓
    INSPECT INTERACTION CONTRACTS
        ↓
    DESIGN MACRO CONSTRAINTS
        ↓
    IMPLEMENT
        ↓
    VALIDATE REFERENCE VIEWPORT
        ↓
    VALIDATE ALTERNATE VIEWPORTS
        ↓
    FIX ARCHITECTURAL ISSUES
        ↓
    REGRESSION TEST
        ↓
    REPORT


# 40. REQUIRED IMPLEMENTATION REPORT

After implementing a significant responsive change, report:

## Implementation Status

PASS / PARTIAL / BLOCKED

## Files Modified

List modified files and why.

## Responsive Strategy

Explain:

- what became fluid;
- what remained fixed;
- what became constrained;
- what became scrollable;
- what became adaptive.

## Interaction Protection

Identify components whose geometry was intentionally preserved and explain why.

## Safe-Area Strategy

Explain how system insets are handled.

## Validation

List viewport/device conditions checked.

## Remaining Limitations

Identify any component that could not safely become responsive without deeper architectural work.


# 41. DECISION HIERARCHY

When uncertain, use this order:

1. Protect usability.
2. Protect interaction correctness.
3. Preserve Quick Notes design intent.
4. Preserve visual hierarchy.
5. Preserve meaningful relationships.
6. Respect safe-area/system constraints.
7. Protect interaction-critical geometry.
8. Adapt flexible spacing/dimensions.
9. Allow scrolling when content cannot reasonably fit.
10. Adapt composition when available space is fundamentally different.
11. Match exact reference coordinates only when they remain appropriate.


# 42. THE QUICK NOTES TEST

Before declaring responsive UI complete, ask:

> Does this still feel like the same Quick Notes design?

If YES:

    Continue validation.

If NO:

    Determine whether the difference is:
        - necessary adaptation;
        - broken layout;
        - broken component geometry;
        - excessive scaling;
        - lost spacing;
        - lost hierarchy;
        - inappropriate composition change.

Fix unnecessary visual drift.


# 43. FINAL RULE

Always remember:

> DO NOT REPRODUCE THE FIGMA CANVAS.
>
> REPRODUCE THE QUICK NOTES DESIGN INTENT UNDER THE ACTUAL CONSTRAINTS OF THE DEVICE.

The goal is not pixel sameness across every device.

The goal is:

    same product
    same visual language
    same hierarchy
    same interaction quality
    same design intent

while allowing:

    different available space
    different aspect ratios
    different safe areas
    different window sizes
    controlled spacing changes
    controlled component adaptation
    scrolling
    adaptive layouts

A responsive Quick Notes UI should feel intentionally designed for the device — not like a Figma screenshot being squeezed into it.