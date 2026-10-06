import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_fidelity_lab_screen.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_morph_mechanics_lab_screen.dart';

void main() {
  const Size fieldSize = Size(340, 280);

  Rect computeRect(Alignment placement, Size size) {
    const EdgeInsets stagePadding =
        EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0);
    final Rect bounds = Rect.fromLTWH(
      stagePadding.left,
      stagePadding.top,
      math.max(0.0, fieldSize.width - stagePadding.horizontal),
      math.max(0.0, fieldSize.height - stagePadding.vertical),
    );
    return placement.inscribe(size, bounds);
  }

  test('Verify geometry settling and anchor coincidence for Center, Top-Left, Top-Right, Bottom-Right, Bottom-Left', () {
    final Map<String, Alignment> testCases = <String, Alignment>{
      'Center (Case A)': Alignment.center,
      'Top-Left (Case B)': Alignment.topLeft,
      'Top-Right (Case C)': Alignment.topRight,
      'Bottom-Right (Case D & E)': Alignment.bottomRight,
      'Bottom-Left': Alignment.bottomLeft,
    };

    for (final String name in testCases.keys) {
      final Alignment anchorAlign = testCases[name]!;

      // In native liquid_glass_easy 4.3.1 semantics, both source and destination
      // are placed using widget.alignment:
      // Rect _place(Size s) => widget.alignment.inscribe(s, field)
      final Rect srcCircle = computeRect(anchorAlign, const Size(56, 56));
      final Rect destSquare = computeRect(anchorAlign, const Size(224, 184));

      // 1. Verify anchor point coincidence (the held edge/corner does not shift)
      final Offset srcAnchorPt = anchorAlign.withinRect(srcCircle);
      final Offset destAnchorPt = anchorAlign.withinRect(destSquare);
      expect(
        (destAnchorPt - srcAnchorPt).distance,
        lessThan(0.001),
        reason: '$name: held anchor point must be identical between source and destination',
      );

      // 2. Verify center translation behavior
      final double translationDistance = (destSquare.center - srcCircle.center).distance;
      if (anchorAlign == Alignment.center) {
        expect(translationDistance, lessThan(0.001), reason: 'Center anchor expands symmetrically in place');
      } else {
        // Corner translation vector: delta = -(destSize - srcSize)/2 * alignment
        // deltaX = 84, deltaY = 64 -> length ~105.6px
        expect(translationDistance, closeTo(105.60, 0.05), reason: '$name corner center translation distance');
      }

      final QuickNotesMorphGeometryController controller =
          QuickNotesMorphGeometryController(initialRect: srcCircle);

      // LOCKED parameters: stretch=0.75, leadBounce=0.10, followDelay=40ms
      const QuickNotesMorphGeometryConfig config = QuickNotesMorphGeometryConfig(
        stiffness: 195.0,
        damping: 19.5,
        stretch: 0.75,
        leadBounce: 0.10,
        followDelaySeconds: 0.04,
        anchor: Alignment.center,
      );

      controller.transitionToRect(destSquare, config: config);

      double time = 0.0;
      while (controller.isAnimating && time < 5.0) {
        controller.step(1.0 / 60.0, config);
        time += 1.0 / 60.0;
      }

      final Rect settled = controller.currentRect;
      expect(settled.left, closeTo(destSquare.left, 0.001), reason: '$name settled left');
      expect(settled.top, closeTo(destSquare.top, 0.001), reason: '$name settled top');
      expect(settled.width, closeTo(destSquare.width, 0.001), reason: '$name settled width');
      expect(settled.height, closeTo(destSquare.height, 0.001), reason: '$name settled height');

      // 3. Verify held anchor point on the settled rect matches initial source anchor point
      final Offset settledAnchorPt = anchorAlign.withinRect(settled);
      expect((settledAnchorPt - srcAnchorPt).distance, lessThan(0.001), reason: '$name settled anchor coincidence');
    }
  });

  test('Verify Square -> Circle reverse settling under native anchor semantics', () {
    final Rect srcCircle = computeRect(Alignment.center, const Size(56, 56));
    final Rect destSquare = computeRect(Alignment.center, const Size(224, 184));

    final QuickNotesMorphGeometryController controller =
        QuickNotesMorphGeometryController(initialRect: destSquare);

    const QuickNotesMorphGeometryConfig config = QuickNotesMorphGeometryConfig(
      stiffness: 195.0,
      damping: 19.5,
      stretch: 0.75,
      leadBounce: 0.10,
      followDelaySeconds: 0.04,
      anchor: Alignment.center,
    );

    controller.transitionToRect(srcCircle, config: config);

    double time = 0.0;
    while (controller.isAnimating && time < 5.0) {
      controller.step(1.0 / 60.0, config);
      time += 1.0 / 60.0;
    }

    final Rect settled = controller.currentRect;
    expect(settled.left, closeTo(srcCircle.left, 0.001));
    expect(settled.top, closeTo(srcCircle.top, 0.001));
    expect(settled.width, closeTo(srcCircle.width, 0.001));
    expect(settled.height, closeTo(srcCircle.height, 0.001));
  });

  test('Verify Interrupted C -> S -> C and Retarget C -> S -> Alt under native anchor semantics', () {
    final Rect srcCircle = computeRect(Alignment.center, const Size(56, 56));
    final Rect destSquare = computeRect(Alignment.center, const Size(224, 184));
    final Rect altCard = computeRect(Alignment.center, const Size(168, 112));

    const QuickNotesMorphGeometryConfig config = QuickNotesMorphGeometryConfig(
      stiffness: 195.0,
      damping: 19.5,
      stretch: 0.75,
      leadBounce: 0.10,
      followDelaySeconds: 0.04,
      anchor: Alignment.center,
    );

    // 1. Interrupted: start towards Square, interrupt at 150ms back to Circle
    final QuickNotesMorphGeometryController ctrl1 =
        QuickNotesMorphGeometryController(initialRect: srcCircle);
    ctrl1.transitionToRect(destSquare, config: config);
    for (int i = 0; i < 9; i++) {
      ctrl1.step(1.0 / 60.0, config); // ~150ms
    }
    expect(ctrl1.isAnimating, isTrue);
    final Rect interruptedRect = ctrl1.currentRect;
    expect(interruptedRect.width, isNot(closeTo(srcCircle.width, 0.1)));

    // Reverse to Circle
    ctrl1.transitionToRect(srcCircle, config: config);
    double time = 0.0;
    while (ctrl1.isAnimating && time < 5.0) {
      ctrl1.step(1.0 / 60.0, config);
      time += 1.0 / 60.0;
    }
    expect(ctrl1.currentRect.left, closeTo(srcCircle.left, 0.001));
    expect(ctrl1.currentRect.top, closeTo(srcCircle.top, 0.001));
    expect(ctrl1.currentRect.width, closeTo(srcCircle.width, 0.001));
    expect(ctrl1.currentRect.height, closeTo(srcCircle.height, 0.001));

    // 2. Retarget: start towards Square, retarget at 160ms to Alt
    final QuickNotesMorphGeometryController ctrl2 =
        QuickNotesMorphGeometryController(initialRect: srcCircle);
    ctrl2.transitionToRect(destSquare, config: config);
    for (int i = 0; i < 10; i++) {
      ctrl2.step(1.0 / 60.0, config); // ~166ms
    }
    expect(ctrl2.isAnimating, isTrue);

    ctrl2.transitionToRect(altCard, config: config);
    time = 0.0;
    while (ctrl2.isAnimating && time < 5.0) {
      ctrl2.step(1.0 / 60.0, config);
      time += 1.0 / 60.0;
    }
    expect(ctrl2.currentRect.left, closeTo(altCard.left, 0.001));
    expect(ctrl2.currentRect.top, closeTo(altCard.top, 0.001));
    expect(ctrl2.currentRect.width, closeTo(altCard.width, 0.001));
    expect(ctrl2.currentRect.height, closeTo(altCard.height, 0.001));
  });

  testWidgets(
    'Verify live layout RenderBox destination geometry conversion and exact settling',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: LiquidGlassMorphFidelityLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify destination slot widget exists and has a valid RenderBox
      final Finder squareSlot = find.byKey(const ValueKey<String>('fidelity_slot_square'));
      expect(squareSlot, findsOneWidget);
      final RenderBox squareBox = tester.renderObject<RenderBox>(squareSlot);
      expect(squareBox.hasSize, isTrue);
      expect(squareBox.size, equals(const Size(224, 184)));

      // 2. Measure destination geometry in preview stack space
      final Finder stackFinder = find.byKey(const ValueKey<String>('fidelity_preview_stack'));
      expect(stackFinder, findsOneWidget);
      final RenderBox stackBox = tester.renderObject<RenderBox>(stackFinder);
      final Offset expectedTopLeft = squareBox.localToGlobal(Offset.zero, ancestor: stackBox);
      final Rect expectedDestRect = expectedTopLeft & squareBox.size;

      // 3. Trigger Mode A: Circle -> Square
      final Finder modeABtn = find.byKey(const ValueKey<String>('fidelity_mode_a_circle_to_square'));
      await tester.tap(modeABtn);
      await tester.pump();
      await tester.pumpAndSettle();

      // 4. Read settled morph position
      final Positioned pos = tester.widget<Positioned>(
        find.byKey(const ValueKey<String>('fidelity_glass_positioned')),
      );
      final Rect actualSettledRect = Rect.fromLTWH(
        pos.left ?? 0.0,
        pos.top ?? 0.0,
        pos.width ?? 0.0,
        pos.height ?? 0.0,
      );

      // Verify all 6 geometric quantities match the measured destination RenderBox
      expect(actualSettledRect.left, closeTo(expectedDestRect.left, 0.01));
      expect(actualSettledRect.top, closeTo(expectedDestRect.top, 0.01));
      expect(actualSettledRect.right, closeTo(expectedDestRect.right, 0.01));
      expect(actualSettledRect.bottom, closeTo(expectedDestRect.bottom, 0.01));
      expect(actualSettledRect.width, closeTo(expectedDestRect.width, 0.01));
      expect(actualSettledRect.height, closeTo(expectedDestRect.height, 0.01));
    },
  );
}
