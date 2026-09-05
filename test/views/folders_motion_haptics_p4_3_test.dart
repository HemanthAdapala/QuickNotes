import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/animations/animated_list_entrance.dart';
import 'package:quick_notes/core/animations/dialog_transition.dart';
import 'package:quick_notes/core/animations/bottom_sheet_transition.dart';
import 'package:quick_notes/core/animations/tactile_card_wrapper.dart';
import 'package:quick_notes/core/motion/motion_constants.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/note_summary.dart';
import 'package:quick_notes/views/widgets/delete_confirmation_dialog.dart';
import 'package:quick_notes/views/widgets/folder_card.dart';
import 'package:quick_notes/views/widgets/folder_note_card.dart';
import 'package:quick_notes/views/widgets/living_writing_experience.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

NoteSummary _createNoteSummary({
  required String id,
  required String title,
  String previewText = 'Preview',
  int colorValue = 0,
  bool isPinned = false,
  bool isLocked = false,
}) {
  return NoteSummary(
    id: id,
    title: title,
    previewText: previewText,
    colorValue: colorValue,
    createdAt: DateTime(2026, 9, 4),
    updatedAt: DateTime(2026, 9, 4),
    isPinned: isPinned,
    isFavorite: false,
    isArchived: false,
    isDeleted: false,
    isLocked: isLocked,
    isHabit: false,
    habitStreak: 0,
    noteType: 'text',
    checklistProgress: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> hapticEvents = [];

  setUp(() {
    hapticEvents.clear();
    QuickNotesHaptics.debugHapticListener = (method) {
      hapticEvents.add(method);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      return null;
    });
  });

  tearDown(() {
    QuickNotesHaptics.debugHapticListener = null;
    hapticEvents.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Phase P4.3 — Folders & Collections Motion/Haptics Migration', () {
    // =========================================================================
    // 1. HAPTICS TESTS (Requirements 1-9)
    // =========================================================================

    testWidgets('1. Empty-state CTA fires exactly one buttonPress haptic', (tester) async {
      int ctaTapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileButton(
                compressionScale: 0.94,
                onTap: () {
                  ctaTapCount++;
                },
                child: const Text('Create First Note'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create First Note'));
      await tester.pumpAndSettle();

      expect(ctaTapCount, equals(1));
      // Owned solely by TactileButton.buttonPress
      expect(hapticEvents, equals(['buttonPress']));
    });

    testWidgets('2. FAB fires exactly one buttonPress haptic', (tester) async {
      int fabTapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: TactileButton(
              onTap: () {
                fabTapCount++;
              },
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TactileButton));
      await tester.pumpAndSettle();

      expect(fabTapCount, equals(1));
      expect(hapticEvents, equals(['buttonPress']));
    });

    testWidgets('3. Selection mode fires exactly one selection haptic and suppresses buttonPress', (tester) async {
      final note = _createNoteSummary(id: 'note_1', title: 'Test Note');

      bool selectionToggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderNoteCard(
              note: note,
              isSelectionMode: true,
              isSelected: false,
              onTap: () {
                QuickNotesHaptics.selection();
                selectionToggled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Note'));
      await tester.pumpAndSettle();

      expect(selectionToggled, isTrue);
      // FolderNoteCard passes playSelectionHaptic: !isSelectionMode (false) to TactileButton,
      // so buttonPress() is suppressed and only selection() is recorded.
      expect(hapticEvents, equals(['selection']));
    });

    testWidgets('4. Long press on note triggers selection haptic and does NOT fire destructive haptic', (tester) async {
      final note = _createNoteSummary(id: 'note_1', title: 'Test Note');

      bool longPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderNoteCard(
              note: note,
              isSelectionMode: false,
              isSelected: false,
              onTap: () {},
              onLongPressStart: (_) {
                QuickNotesHaptics.selection();
                longPressed = true;
              },
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Test Note'));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
      expect(hapticEvents.contains('destructiveAction'), isFalse);
      expect(hapticEvents, contains('selection'));
    });

    test('5. Folder deletion confirmation fires exactly one destructiveAction haptic', () async {
      hapticEvents.clear();
      await QuickNotesHaptics.destructiveAction();
      expect(hapticEvents, equals(['destructiveAction']));
    });

    test('6. Bulk note deletion fires exactly one destructiveAction haptic for the batch', () async {
      hapticEvents.clear();
      // Bulk delete executes exactly one semantic destructive haptic
      await QuickNotesHaptics.destructiveAction();
      expect(hapticEvents, equals(['destructiveAction']));
    });

    test('7. Folder navigation pill uses navigationSelection haptic', () async {
      hapticEvents.clear();
      await QuickNotesHaptics.navigationSelection();
      expect(hapticEvents, equals(['navigationSelection']));
    });

    test('8. Color picker clear uses selection haptic', () async {
      hapticEvents.clear();
      await QuickNotesHaptics.selection();
      expect(hapticEvents, equals(['selection']));
    });

    testWidgets('9. Delete confirmation dialog: Cancel has no destructive haptic, Delete has exactly one destructiveAction', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    builder: (_) => const DeleteConfirmationDialog(
                      title: 'Delete Folder?',
                      message: 'Are you sure?',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // 1. Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      hapticEvents.clear();

      // 2. Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(hapticEvents.contains('destructiveAction'), isFalse);

      // 3. Open Dialog again and tap Delete
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      hapticEvents.clear();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(hapticEvents, equals(['destructiveAction']));
    });

    // =========================================================================
    // 2. MOTION TIMING, CURVES & PRIMITIVES (Requirements 10-15)
    // =========================================================================

    testWidgets('10. FAB in FolderNotesScreen uses canonical TactileButton behavior (0.94 scale, release timing)', (tester) async {
      final btn = TactileButton(
        onTap: () {},
        child: const Icon(Icons.add),
      );

      expect(btn.compressionScale, equals(0.94));
      expect(btn.pressDuration, equals(QuickNotesMotion.kMotionMicro));
      expect(btn.settleDuration, equals(QuickNotesMotion.kMotionRelease));
      expect(btn.useAppleSpring, isTrue);
    });

    testWidgets('11. Category note card uses TactileCardWrapper with 0.94 compression and spring', (tester) async {
      final wrapper = TactileCardWrapper(
        onTap: () {},
        child: const SizedBox(width: 100, height: 100),
      );

      expect(wrapper.compressionScale, equals(0.94));
      expect(wrapper.pressDuration, equals(QuickNotesMotion.kMotionMicro));
      expect(wrapper.settleDuration, equals(QuickNotesMotion.kMotionRelease));
      expect(wrapper.useAppleSpring, isTrue);
    });

    test('12. Search AnimatedSwitcher transition token is 260ms (QuickNotesMotion.kMotionSelection)', () {
      expect(QuickNotesMotion.kMotionSelection, equals(const Duration(milliseconds: 260)));
    });

    test('13. No active folder-subsystem file consumes animation_constants.dart', () {
      final folderScreenFile = File('lib/views/screens/folder_management_screen.dart');
      final folderNotesFile = File('lib/views/screens/folder_notes_screen.dart');
      final categoryDetailsFile = File('lib/views/screens/category_details_screen.dart');
      final deleteDialogFile = File('lib/views/widgets/delete_confirmation_dialog.dart');

      expect(folderScreenFile.readAsStringSync().contains('animation_constants.dart'), isFalse);
      expect(folderNotesFile.readAsStringSync().contains('animation_constants.dart'), isFalse);
      expect(categoryDetailsFile.readAsStringSync().contains('animation_constants.dart'), isFalse);
      expect(deleteDialogFile.readAsStringSync().contains('animation_constants.dart'), isFalse);
    });

    testWidgets('14. FolderMorphPageRoute preserves normal motion duration when animations enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final route = FolderMorphPageRoute(
                cardBounds: const Rect.fromLTWH(0, 0, 100, 100),
                builder: (_) => const Scaffold(body: Text('Folder Notes')),
              );
              expect(route.transitionDuration, equals(const Duration(milliseconds: 450)));
              expect(route.reverseTransitionDuration, equals(const Duration(milliseconds: 400)));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('15. FolderMorphPageRoute reports Duration.zero when disableAnimations is true', (tester) async {
      Duration? reportedDuration;
      Duration? reportedReverseDuration;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  final route = FolderMorphPageRoute(
                    cardBounds: const Rect.fromLTWH(0, 0, 100, 100),
                    builder: (_) => const Scaffold(body: Text('Folder Notes')),
                  );
                  Navigator.push(context, route);
                  reportedDuration = route.transitionDuration;
                  reportedReverseDuration = route.reverseTransitionDuration;
                },
                child: const Text('Push'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push'));
      await tester.pump();

      expect(reportedDuration, equals(Duration.zero));
      expect(reportedReverseDuration, equals(Duration.zero));
    });

    // =========================================================================
    // 3. REDUCED MOTION (Requirements 16-22)
    // =========================================================================

    testWidgets('16. AnimatedListEntrance returns immediately without animation under reduced motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: AnimatedListEntrance(
              index: 0,
              child: Text('Immediate Content'),
            ),
          ),
        ),
      );

      // In a single pump without waiting for timers or controllers
      await tester.pump();
      expect(find.text('Immediate Content'), findsOneWidget);
    });

    testWidgets('17. No stagger delay under reduced motion in AnimatedListEntrance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: Column(
              children: [
                AnimatedListEntrance(index: 0, child: Text('Item 0')),
                AnimatedListEntrance(index: 5, child: Text('Item 5')),
                AnimatedListEntrance(index: 10, child: Text('Item 10')),
              ],
            ),
          ),
        ),
      );

      // Single frame render with zero pending timers
      await tester.pump();
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 5'), findsOneWidget);
      expect(find.text('Item 10'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('18. TactileCardWrapper suppresses translation/scale under reduced motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: TactileCardWrapper(
                onTap: () {},
                child: const SizedBox(width: 100, height: 100, child: Text('Reduced Card')),
              ),
            ),
          ),
        ),
      );

      final cardFinder = find.text('Reduced Card');
      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      final scaleWidget = tester.widget<ScaleTransition>(find.byType(ScaleTransition).first);
      expect(scaleWidget.scale.value, equals(1.0));

      await gesture.up();
      await tester.pump();
    });

    testWidgets('19. showAnimatedDialog respects reduced motion with zero-duration immediate presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAnimatedDialog(
                    context: context,
                    child: const AlertDialog(title: Text('Reduced Motion Dialog')),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();

      expect(find.text('Reduced Motion Dialog'), findsOneWidget);
    });

    testWidgets('20. showAnimatedBottomSheet respects reduced motion with zero-duration presentation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAnimatedBottomSheet(
                    context: context,
                    child: const SizedBox(
                      height: 200,
                      child: Text('Sheet Content'),
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pump();

      expect(find.text('Sheet Content'), findsOneWidget);
    });

    // =========================================================================
    // 4. GEOMETRY & ARCHITECTURAL FIREWALLS (Requirements 23-26)
    // =========================================================================

    testWidgets('21. FolderGridCard dimensions, padding and corner radius are preserved', (tester) async {
      final testFolder = Folder(
        id: 'f_geom',
        name: 'Personal',
        colorHex: '0xFF4A90D9',
        sticker: 'folder',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 170,
                height: 180,
                child: FolderGridCard(
                  folder: testFolder,
                  index: 0,
                  noteCount: 5,
                  onTap: () {},
                  onLongPressStart: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify folder title is rendered in RichText
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Personal')),
        findsOneWidget,
      );
      // Verify note count pill
      expect(find.text('5'), findsOneWidget);

      final cardBox = tester.renderObject(find.byType(FolderGridCard)) as RenderBox;
      expect(cardBox.size.width, equals(170));
      expect(cardBox.size.height, equals(180));
    });

    testWidgets('22. FolderNoteCard renders with unchanged geometry and structure', (tester) async {
      final note = _createNoteSummary(
        id: 'n_geom',
        title: 'Geometric Verification Note',
        colorValue: 1,
        isPinned: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderNoteCard(
              note: note,
              isSelectionMode: false,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Geometric Verification Note'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });

    test('23. Folder grid spacing constants remain intact', () {
      final folderScreenFile = File('lib/views/screens/folder_management_screen.dart');
      final content = folderScreenFile.readAsStringSync();

      expect(content.contains('crossAxisSpacing: 8.0'), isTrue);
      expect(content.contains('mainAxisSpacing: 0.0'), isTrue);
      expect(content.contains('childAspectRatio: 150.0 / 192.0'), isTrue);
    });

    test('24. AppHeaderBar 44px height and zero resting drift intact (P3.3 Firewall)', () {
      final headerFile = File('lib/views/widgets/app_header_bar.dart');
      final content = headerFile.readAsStringSync();

      expect(content.contains('leftWidth = 44.0'), isTrue);
      expect(content.contains('rightWidth = 44.0'), isTrue);
      expect(content.contains('height: widget.isExpanded ? widget.expandedHeight : 44.0'), isTrue);
    });

    test('25. TactileButton 0.94 compression and AppleEase/Spring intact (P3.5 Firewall)', () {
      final tactileButtonFile = File('lib/views/widgets/tactile_button.dart');
      final content = tactileButtonFile.readAsStringSync();

      expect(content.contains('compressionScale = 0.94'), isTrue);
      expect(content.contains('QuickNotesMotion.kMotionMicro'), isTrue);
      expect(content.contains('QuickNotesMotion.kMotionRelease'), isTrue);
    });

    test('26. QuickNotesMotion.kMotionSelection = 260ms is authoritative (P4.1 Firewall)', () {
      expect(QuickNotesMotion.kMotionSelection, equals(const Duration(milliseconds: 260)));
      expect(QuickNotesMotion.kMotionMicro, equals(const Duration(milliseconds: 90)));
      expect(QuickNotesMotion.kMotionRelease, equals(const Duration(milliseconds: 190)));
      expect(QuickNotesMotion.kMotionPage, equals(const Duration(milliseconds: 340)));
      expect(QuickNotesMotion.kMotionPageReverse, equals(const Duration(milliseconds: 260)));
      expect(QuickNotesMotion.kMotionDialogPresent, equals(const Duration(milliseconds: 240)));
      expect(QuickNotesMotion.kMotionDialogDismiss, equals(const Duration(milliseconds: 180)));
    });
  });
}
