import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/controllers/editor_auto_scroll_controller.dart';
import 'package:quick_notes/views/widgets/editor_quick_scroll_pill.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EditorQuickScrollPill Regression Suite (SDE-005)', () {
    late ScrollController scrollController;
    late EditorAutoScrollController autoScrollController;

    setUp(() {
      scrollController = ScrollController();
      autoScrollController = EditorAutoScrollController(
        scrollController: scrollController,
        threshold: 100.0,
      );
    });

    tearDown(() {
      autoScrollController.dispose();
      scrollController.dispose();
    });

    Widget buildTestHarness() {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView.builder(
                controller: scrollController,
                itemCount: 100,
                itemBuilder: (context, index) => SizedBox(
                  height: 50.0,
                  child: Text('Item $index'),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: EditorQuickScrollPill(
                  controller: autoScrollController,
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets(
        '1. Both TactileButton instances in EditorQuickScrollPill use 220ms settleDuration',
        (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      final tactileButtons =
          tester.widgetList<TactileButton>(find.byType(TactileButton)).toList();
      expect(tactileButtons.length, equals(2));

      // Scroll to Beginning button
      expect(tactileButtons[0].settleDuration,
          equals(const Duration(milliseconds: 220)));
      expect(tactileButtons[0].useAppleSpring, isTrue);

      // Scroll to End button
      expect(tactileButtons[1].settleDuration,
          equals(const Duration(milliseconds: 220)));
      expect(tactileButtons[1].useAppleSpring, isTrue);
    });

    testWidgets(
        '2. Quick-scroll buttons trigger smooth scroll and settle promptly in 220ms',
        (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Scroll to middle so both canScrollToTop and canScrollToBottom are true
      scrollController.jumpTo(1000.0);
      await tester.pump();

      expect(autoScrollController.canScrollToTop, isTrue);
      expect(autoScrollController.canScrollToBottom, isTrue);
      expect(autoScrollController.isVisible, isTrue);

      final upButton = find.byIcon(Icons.keyboard_arrow_up_rounded);
      final downButton = find.byIcon(Icons.keyboard_arrow_down_rounded);

      expect(upButton, findsOneWidget);
      expect(downButton, findsOneWidget);

      // Tap up button to scroll to beginning
      await tester.tap(upButton);
      await tester.pump();
      // Within 220ms, the tactile button has settled
      await tester.pump(const Duration(milliseconds: 220));
      // Settle the scroll animation
      await tester.pumpAndSettle();

      expect(scrollController.offset, equals(0.0));

      // Now scroll back to middle and test down button
      scrollController.jumpTo(1000.0);
      await tester.pump();

      await tester.tap(downButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();

      expect(scrollController.offset,
          equals(scrollController.position.maxScrollExtent));

      // Allow autoHideDelay timer (1500ms) to resolve
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets(
        '3. Rapid repeated taps settle cleanly without stuck animation states',
        (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      scrollController.jumpTo(1000.0);
      await tester.pump();

      final upButton = find.byIcon(Icons.keyboard_arrow_up_rounded);

      // Perform 5 rapid taps
      for (int i = 0; i < 5; i++) {
        await tester.tap(upButton);
        await tester.pump(const Duration(milliseconds: 40));
      }

      // Settle responsive animation
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pumpAndSettle();

      expect(scrollController.offset, equals(0.0));

      // Allow autoHideDelay timer (1500ms) to resolve
      await tester.pump(const Duration(milliseconds: 1600));
    });
  });
}
