import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/liquid_glass_morph_container.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_back_button.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildHeaderTestHarness({
    Widget? leftChild,
    VoidCallback? onLeftTap,
    double leftWidth = 44.0,
    String leftHeroTag = 'hero_test_leading',
    Widget? rightChild,
    double rightWidth = 44.0,
    String rightHeroTag = 'hero_test_trailing',
    String? title,
    Widget? titleWidget,
    Color? titleColor,
    bool isExpanded = false,
    double expandedWidth = 192.0,
    double expandedHeight = 100.0,
    Widget? expandedChild,
    bool disableAnimations = false,
    double viewportWidth = 402.0,
    bool useSelfContainedLeftControl = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(viewportWidth, 800),
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: viewportWidth,
              child: AppHeaderBar(
                leftChild: leftChild,
                onLeftTap: onLeftTap,
                leftWidth: leftWidth,
                leftHeroTag: leftHeroTag,
                rightChild: rightChild,
                rightWidth: rightWidth,
                rightHeroTag: rightHeroTag,
                title: title,
                titleWidget: titleWidget,
                titleColor: titleColor,
                isExpanded: isExpanded,
                expandedWidth: expandedWidth,
                expandedHeight: expandedHeight,
                expandedChild: expandedChild,
                useSelfContainedLeftControl: useSelfContainedLeftControl,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Group A — Geometry', () {
    testWidgets('header content height is exactly 44.0 in collapsed state', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        title: 'Title',
      ));

      final headerFinder = find.byType(AppHeaderBar);
      final size = tester.getSize(headerFinder);
      expect(size.height, 44.0);
    });

    testWidgets('standard leading and trailing buttons measure 44x44', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const Icon(Icons.arrow_back),
        rightChild: const Icon(Icons.more_horiz),
      ));

      // The left button is at Positioned(width: 44, height: 44)
      final leftPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(Positioned),
        ).first,
      );
      expect(leftPositioned.width, 44.0);
      expect(leftPositioned.height, 44.0);

      // The right button measures 44x44
      final rightGlassSize = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.more_horiz),
          matching: find.byType(BottomBarGlassSurface),
        ).first,
      );
      expect(rightGlassSize.width, 44.0);
      expect(rightGlassSize.height, 44.0);
    });
  });

  group('Group B — Typography', () {
    testWidgets('default title adheres to canonical Inter 18px w700 letterSpacing: -0.43', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        title: 'Standard Title',
      ));

      final textFinder = find.text('Standard Title');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.fontSize, 18.0);
      expect(textWidget.style?.fontWeight, FontWeight.w700);
      expect(textWidget.style?.letterSpacing, -0.43);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('custom titleWidget is preserved without being forced to default Text', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        titleWidget: const Text('Custom Widget', style: TextStyle(fontSize: 22.0)),
      ));

      expect(find.text('Custom Widget'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Custom Widget'));
      expect(textWidget.style?.fontSize, 22.0);
    });
  });

  group('Group C — Callbacks', () {
    testWidgets('leading callback fires exactly once on tap', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const Icon(Icons.arrow_back),
        onLeftTap: () => tapCount++,
      ));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });

    testWidgets('trailing action callback fires correctly', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(buildHeaderTestHarness(
        rightChild: TactileButton(
          onTap: () => tapCount++,
          child: const Icon(Icons.more_vert),
        ),
      ));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
    });
  });

  group('Group D — Expansion', () {
    testWidgets('header renders collapsed and expanded dimensions correctly', (tester) async {
      // Collapsed state
      await tester.pumpWidget(buildHeaderTestHarness(
        isExpanded: false,
        rightChild: const Icon(Icons.more_horiz),
        expandedChild: const Text('Menu Items'),
        expandedWidth: 192.0,
        expandedHeight: 120.0,
      ));

      expect(tester.getSize(find.byType(AppHeaderBar)).height, 44.0);

      // Transition to expanded state
      await tester.pumpWidget(buildHeaderTestHarness(
        isExpanded: true,
        rightChild: const Icon(Icons.more_horiz),
        expandedChild: const Text('Menu Items'),
        expandedWidth: 192.0,
        expandedHeight: 120.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppHeaderBar)).height, 120.0);
      final morphContainer = tester.widget<LiquidGlassMorphContainer>(
        find.ancestor(
          of: find.text('Menu Items'),
          matching: find.byType(LiquidGlassMorphContainer),
        ).first,
      );
      expect(morphContainer.expandedSize.width, 192.0);
      expect(morphContainer.expandedSize.height, 120.0);
      final expandedGlassSize = tester.getSize(
        find.ancestor(
          of: find.text('Menu Items'),
          matching: find.byType(BottomBarGlassSurface),
        ).first,
      );
      expect(expandedGlassSize.width, 192.0);
      expect(expandedGlassSize.height, 120.0);
    });

    testWidgets('header renders NoteEditorScreen full pill 192x44 and expands to 192x250', (tester) async {
      const fiveElementRow = Row(
        children: [
          Expanded(child: Icon(Icons.undo)),
          Expanded(child: Icon(Icons.redo)),
          SizedBox(width: 1.0, height: 18.0),
          Expanded(child: Icon(Icons.folder_open)),
          Expanded(child: Icon(Icons.more_horiz)),
        ],
      );

      // Collapsed state: 192x44
      await tester.pumpWidget(buildHeaderTestHarness(
        isExpanded: false,
        rightWidth: 192.0,
        rightChild: fiveElementRow,
        expandedChild: const Text('Note Options'),
        expandedWidth: 192.0,
        expandedHeight: 250.0,
      ));
      await tester.pumpAndSettle();

      final Size collapsedGlassSize = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.more_horiz),
          matching: find.byType(BottomBarGlassSurface),
        ).first,
      );
      expect(collapsedGlassSize.width, 192.0);
      expect(collapsedGlassSize.height, 44.0);

      // Transition to expanded state: 192x250
      await tester.pumpWidget(buildHeaderTestHarness(
        isExpanded: true,
        rightWidth: 192.0,
        rightChild: fiveElementRow,
        expandedChild: const Text('Note Options'),
        expandedWidth: 192.0,
        expandedHeight: 250.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppHeaderBar)).height, 250.0);
      final Size expandedGlassSize = tester.getSize(
        find.ancestor(
          of: find.text('Note Options'),
          matching: find.byType(BottomBarGlassSurface),
        ).first,
      );
      expect(expandedGlassSize.width, 192.0);
      expect(expandedGlassSize.height, 250.0);
    });
  });

  group('Group E — Reduced Motion', () {
    testWidgets('expansion renders immediately with zero duration when disableAnimations is true', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        isExpanded: false,
        disableAnimations: true,
        rightChild: const Icon(Icons.more_horiz),
        expandedChild: const Text('Menu Items'),
        expandedWidth: 192.0,
        expandedHeight: 120.0,
      ));

      expect(tester.getSize(find.byType(AppHeaderBar)).height, 44.0);

      // Expand under reduced motion
      await tester.pumpWidget(buildHeaderTestHarness(
        isExpanded: true,
        disableAnimations: true,
        rightChild: const Icon(Icons.more_horiz),
        expandedChild: const Text('Menu Items'),
        expandedWidth: 192.0,
        expandedHeight: 120.0,
      ));

      // With zero duration, pump(Duration.zero) should immediately have the final size without waiting for pumpAndSettle
      await tester.pump();
      expect(tester.getSize(find.byType(AppHeaderBar)).height, 120.0);
    });
  });

  group('Group F — Hero Identity', () {
    testWidgets('custom Hero tags are accepted and distinct', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const Icon(Icons.arrow_back),
        leftHeroTag: 'hero_custom_screen_back',
        rightChild: const Icon(Icons.search),
        rightHeroTag: 'hero_custom_screen_search',
      ));

      final heroFinders = find.byType(Hero);
      expect(heroFinders, findsNWidgets(2));

      final heroes = tester.widgetList<Hero>(heroFinders).toList();
      final tags = heroes.map((h) => h.tag).toList();
      expect(tags, contains('hero_custom_screen_back'));
      expect(tags, contains('hero_custom_screen_search'));
      expect(tags.toSet().length, 2, reason: 'Hero tags must be distinct');
    });
  });

  group('Group G — Responsive Layout', () {
    testWidgets('title is bounded between left and right slots and does not overflow on narrow viewports', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        viewportWidth: 320.0,
        leftChild: const Icon(Icons.arrow_back),
        leftWidth: 44.0,
        rightChild: const Icon(Icons.more_horiz),
        rightWidth: 88.0,
        title: 'Very Long Application Title That Might Overflow Narrow Viewports',
      ));

      expect(tester.takeException(), isNull);

      final titleFinder = find.text('Very Long Application Title That Might Overflow Narrow Viewports');
      expect(titleFinder, findsOneWidget);

      final titlePositioned = tester.widget<Positioned>(
        find.ancestor(
          of: titleFinder,
          matching: find.byType(Positioned),
        ).first,
      );

      expect(titlePositioned.left, 44.0);
      expect(titlePositioned.right, 88.0);
    });
  });

  group('Group H — Title Geometry Stability Across Expansion (Regression Defense)', () {
    testWidgets('title text geometry is strictly preserved when isExpanded toggles', (tester) async {
      // 1. Closed state (State A)
      await tester.pumpWidget(buildHeaderTestHarness(
        viewportWidth: 412.0,
        leftChild: const Icon(Icons.arrow_back),
        leftWidth: 44.0,
        rightChild: const Icon(Icons.more_horiz),
        rightWidth: 44.0,
        expandedWidth: 192.0,
        expandedHeight: 100.0,
        expandedChild: const Text('Popup Menu'),
        title: 'Settings',
        isExpanded: false,
      ));

      expect(tester.getSize(find.byType(AppHeaderBar)).height, 44.0);

      final titleFinder = find.text('Settings');
      expect(titleFinder, findsOneWidget);

      final closedPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: titleFinder,
          matching: find.byType(Positioned),
        ).first,
      );

      expect(closedPositioned.left, 44.0);
      expect(closedPositioned.right, 44.0);
      expect(closedPositioned.top, 0.0);
      expect(closedPositioned.height, 44.0);
      expect(closedPositioned.bottom, isNull);

      final closedCenter = tester.getCenter(titleFinder);
      final closedRect = tester.getRect(titleFinder);

      // Verify centered horizontally between left (44) and right (44) on 412 viewport: (412 - 44 + 44) / 2 = 206.0
      expect(closedCenter.dx, 206.0);
      // Vertical center within 44.0 bar is 22.0
      expect(closedCenter.dy, 22.0);

      // 2. Expanded state (State B)
      await tester.pumpWidget(buildHeaderTestHarness(
        viewportWidth: 412.0,
        leftChild: const Icon(Icons.arrow_back),
        leftWidth: 44.0,
        rightChild: const Icon(Icons.more_horiz),
        rightWidth: 44.0,
        expandedWidth: 192.0,
        expandedHeight: 100.0,
        expandedChild: const Text('Popup Menu'),
        title: 'Settings',
        isExpanded: true,
      ));
      await tester.pumpAndSettle();

      // Root header expands to 100.0
      expect(tester.getSize(find.byType(AppHeaderBar)).height, 100.0);

      final expandedPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: titleFinder,
          matching: find.byType(Positioned),
        ).first,
      );

      // REGRESSION DEFENSE: right constraint must remain 44.0 (NOT 192.0)
      expect(expandedPositioned.right, 44.0);
      // REGRESSION DEFENSE: height must remain 44.0 (NOT bottom: 0 spanning 100.0)
      expect(expandedPositioned.height, 44.0);
      expect(expandedPositioned.bottom, isNull);
      expect(expandedPositioned.top, 0.0);
      expect(expandedPositioned.left, 44.0);

      final expandedCenter = tester.getCenter(titleFinder);
      final expandedRect = tester.getRect(titleFinder);

      // REGRESSION DEFENSE: Title must NOT shift horizontally or vertically
      expect(expandedCenter.dx, equals(closedCenter.dx));
      expect(expandedCenter.dy, equals(closedCenter.dy));
      expect(expandedRect, equals(closedRect));

      // 3. Dismissed state (State C)
      await tester.pumpWidget(buildHeaderTestHarness(
        viewportWidth: 412.0,
        leftChild: const Icon(Icons.arrow_back),
        leftWidth: 44.0,
        rightChild: const Icon(Icons.more_horiz),
        rightWidth: 44.0,
        expandedWidth: 192.0,
        expandedHeight: 100.0,
        expandedChild: const Text('Popup Menu'),
        title: 'Settings',
        isExpanded: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppHeaderBar)).height, 44.0);

      final dismissedCenter = tester.getCenter(titleFinder);
      final dismissedRect = tester.getRect(titleFinder);

      expect(dismissedCenter.dx, equals(closedCenter.dx));
      expect(dismissedCenter.dy, equals(closedCenter.dy));
      expect(dismissedRect, equals(closedRect));
    });

    testWidgets('custom titleWidget geometry is strictly preserved when isExpanded toggles', (tester) async {
      // 1. Closed state
      await tester.pumpWidget(buildHeaderTestHarness(
        viewportWidth: 412.0,
        leftChild: const Icon(Icons.arrow_back),
        leftWidth: 44.0,
        rightChild: const Icon(Icons.more_horiz),
        rightWidth: 44.0,
        expandedWidth: 192.0,
        expandedHeight: 100.0,
        expandedChild: const Text('Popup Menu'),
        titleWidget: const Text('Custom Settings Widget'),
        isExpanded: false,
      ));

      final widgetFinder = find.text('Custom Settings Widget');
      expect(widgetFinder, findsOneWidget);

      final closedPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: widgetFinder,
          matching: find.byType(Positioned),
        ).first,
      );

      expect(closedPositioned.right, 44.0);
      expect(closedPositioned.height, 44.0);
      expect(closedPositioned.bottom, isNull);

      final closedCenter = tester.getCenter(widgetFinder);
      final closedRect = tester.getRect(widgetFinder);

      // 2. Expanded state
      await tester.pumpWidget(buildHeaderTestHarness(
        viewportWidth: 412.0,
        leftChild: const Icon(Icons.arrow_back),
        leftWidth: 44.0,
        rightChild: const Icon(Icons.more_horiz),
        rightWidth: 44.0,
        expandedWidth: 192.0,
        expandedHeight: 100.0,
        expandedChild: const Text('Popup Menu'),
        titleWidget: const Text('Custom Settings Widget'),
        isExpanded: true,
      ));
      await tester.pumpAndSettle();

      final expandedPositioned = tester.widget<Positioned>(
        find.ancestor(
          of: widgetFinder,
          matching: find.byType(Positioned),
        ).first,
      );

      expect(expandedPositioned.right, 44.0);
      expect(expandedPositioned.height, 44.0);
      expect(expandedPositioned.bottom, isNull);

      final expandedCenter = tester.getCenter(widgetFinder);
      final expandedRect = tester.getRect(widgetFinder);

      expect(expandedCenter.dx, equals(closedCenter.dx));
      expect(expandedCenter.dy, equals(closedCenter.dy));
      expect(expandedRect, equals(closedRect));

      // 3. Dismissed state
      await tester.pumpWidget(buildHeaderTestHarness(
        viewportWidth: 412.0,
        leftChild: const Icon(Icons.arrow_back),
        leftWidth: 44.0,
        rightChild: const Icon(Icons.more_horiz),
        rightWidth: 44.0,
        expandedWidth: 192.0,
        expandedHeight: 100.0,
        expandedChild: const Text('Popup Menu'),
        titleWidget: const Text('Custom Settings Widget'),
        isExpanded: false,
      ));
      await tester.pumpAndSettle();

      final dismissedCenter = tester.getCenter(widgetFinder);
      final dismissedRect = tester.getRect(widgetFinder);

      expect(dismissedCenter.dx, equals(closedCenter.dx));
      expect(dismissedCenter.dy, equals(closedCenter.dy));
      expect(dismissedRect, equals(closedRect));
    });
  });

  group('Group G — LB-R7 Escape Hatch & Self-Contained Left Control', () {
    testWidgets('1. Legacy default (useSelfContainedLeftControl: false) wraps leftChild in BottomBarGlassSurface and TactileButton', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const Icon(Icons.arrow_back),
        onLeftTap: () => tapCount++,
        useSelfContainedLeftControl: false,
      ));

      // Must be wrapped in TactileButton
      expect(find.byType(TactileButton), findsOneWidget);

      // Must be wrapped in BottomBarGlassSurface
      final glassAncestors = find.ancestor(
        of: find.byIcon(Icons.arrow_back),
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassAncestors, findsOneWidget);

      // Tapping invokes onLeftTap
      await tester.tap(find.byType(TactileButton));
      await tester.pumpAndSettle();
      expect(tapCount, 1);
    });

    testWidgets('2. Self-contained mode (useSelfContainedLeftControl: true) bypasses outer BottomBarGlassSurface and TactileButton', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const SizedBox(
          key: ValueKey('custom_left_control'),
          width: 44.0,
          height: 44.0,
        ),
        useSelfContainedLeftControl: true,
      ));

      // No TactileButton in the leading position
      expect(find.byType(TactileButton), findsNothing);

      // No outer BottomBarGlassSurface wrapping the custom control
      final glassAncestors = find.ancestor(
        of: find.byKey(const ValueKey('custom_left_control')),
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassAncestors, findsNothing);

      // Control is mounted directly inside the Hero and Positioned container
      expect(find.byKey(const ValueKey('custom_left_control')), findsOneWidget);
    });

    testWidgets('3. Hero wrapper is preserved in both legacy and self-contained modes', (tester) async {
      // Legacy mode
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const Icon(Icons.arrow_back),
        leftHeroTag: 'hero_test_leading_tag',
        useSelfContainedLeftControl: false,
      ));
      expect(find.byType(Hero), findsOneWidget);
      final legacyHero = tester.widget<Hero>(find.byType(Hero));
      expect(legacyHero.tag, 'hero_test_leading_tag');

      // Self-contained mode
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const SizedBox(key: ValueKey('self_contained_child')),
        leftHeroTag: 'hero_test_leading_tag',
        useSelfContainedLeftControl: true,
      ));
      expect(find.byType(Hero), findsOneWidget);
      final selfContainedHero = tester.widget<Hero>(find.byType(Hero));
      expect(selfContainedHero.tag, 'hero_test_leading_tag');
    });

    testWidgets('4. Dimensions are preserved at exactly 44.0 x 44.0 in self-contained mode', (tester) async {
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: const SizedBox(key: ValueKey('sized_left_child')),
        leftWidth: 44.0,
        useSelfContainedLeftControl: true,
      ));

      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byKey(const ValueKey('sized_left_child')),
          matching: find.byType(Positioned),
        ).first,
      );
      expect(positioned.left, 0.0);
      expect(positioned.top, 0.0);
      expect(positioned.width, 44.0);
      expect(positioned.height, 44.0);
    });

    testWidgets('5. QuickNotesLiquidGlassBackButton integration renders as sole glass surface and fires tap', (tester) async {
      int backTapped = 0;
      await tester.pumpWidget(buildHeaderTestHarness(
        leftChild: QuickNotesLiquidGlassBackButton(
          onPressed: () => backTapped++,
          isDark: true,
          enableFlex: false, // static test
        ),
        leftWidth: 44.0,
        useSelfContainedLeftControl: true,
      ));

      // Exactly ONE BottomBarGlassSurface (the one inside QuickNotesLiquidGlassBackButton)
      expect(find.byType(BottomBarGlassSurface), findsOneWidget);

      // ZERO TactileButtons
      expect(find.byType(TactileButton), findsNothing);

      // Tap executes callback
      await tester.tap(find.byType(QuickNotesLiquidGlassBackButton));
      await tester.pumpAndSettle();
      expect(backTapped, 1);
    });
  });
}
