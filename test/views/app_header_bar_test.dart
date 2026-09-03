import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
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
          child: Center(
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

      // The right button is within AnimatedContainer(width: 44, height: 44)
      final rightContainer = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.byIcon(Icons.more_horiz),
          matching: find.byType(AnimatedContainer),
        ).first,
      );
      final constraints = rightContainer.constraints;
      expect(constraints?.minWidth, 44.0);
      expect(constraints?.maxWidth, 44.0);
      expect(constraints?.minHeight, 44.0);
      expect(constraints?.maxHeight, 44.0);
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
      final rightContainer = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Menu Items'),
          matching: find.byType(AnimatedContainer),
        ).first,
      );
      expect(rightContainer.constraints?.minWidth, 192.0);
      expect(rightContainer.constraints?.maxWidth, 192.0);
      expect(rightContainer.constraints?.minHeight, 120.0);
      expect(rightContainer.constraints?.maxHeight, 120.0);
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
}
