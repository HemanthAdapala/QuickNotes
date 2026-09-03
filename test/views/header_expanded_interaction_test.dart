import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/core/motion/quick_notes_haptics.dart';
import 'package:quick_notes/views/widgets/app_header_bar.dart';
import 'package:quick_notes/views/widgets/header_expanded_interaction.dart';
import 'package:quick_notes/views/widgets/more_options_popup.dart';
import 'package:quick_notes/views/widgets/folder_options_popup.dart';
import 'package:quick_notes/views/widgets/note_editor_options_popup.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildInteractionTestHarness({
    required bool isExpanded,
    required VoidCallback onDismiss,
    VoidCallback? onUnderlyingTap,
    VoidCallback? onDeleteData,
    VoidCallback? onRefresh,
    VoidCallback? onLeadingBack,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: const Size(402.0, 800.0),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              // Underlying screen content with interactive button
              Positioned(
                top: 200.0,
                left: 50.0,
                child: FocusableActionDetector(
                  actions: <Type, Action<Intent>>{
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (intent) {
                        onUnderlyingTap?.call();
                        return null;
                      },
                    ),
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onUnderlyingTap,
                    child: Container(
                      width: 200.0,
                      height: 50.0,
                      color: Colors.blue,
                      child: const Text('Underlying Control'),
                    ),
                  ),
                ),
              ),

              // HeaderExpandedInteraction Barrier
              Positioned.fill(
                child: HeaderExpandedInteraction(
                  isExpanded: isExpanded,
                  onDismiss: onDismiss,
                ),
              ),

              // AppHeaderBar Overlay
              Positioned(
                top: 12.0,
                left: 24.0,
                right: 24.0,
                child: AppHeaderBar(
                  onCollapse: onDismiss,
                  onLeftTap: () {
                    if (isExpanded) {
                      onDismiss();
                    } else {
                      onLeadingBack?.call();
                    }
                  },
                  leftChild: const Icon(Icons.arrow_back),
                  isExpanded: isExpanded,
                  expandedWidth: 192.0,
                  expandedHeight: 100.0,
                  expandedChild: MoreOptionsPopup(
                    onDeleteData: onDeleteData,
                    onRefresh: onRefresh,
                  ),
                  rightChild: TactileButton(
                    onTap: () {},
                    child: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('TEST 1 — OUTSIDE TAP DISMISSAL', () {
    testWidgets('Tapping outside an expanded header triggers onDismiss', (tester) async {
      bool isExpanded = true;
      bool dismissed = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () {
              setState(() {
                isExpanded = false;
                dismissed = true;
              });
            },
          );
        },
      ));

      expect(find.byType(MoreOptionsPopup), findsOneWidget);

      // Tap outside the header pill (e.g. at y=400)
      await tester.tapAt(const Offset(200.0, 400.0));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(isExpanded, isFalse);
    });
  });

  group('TEST 2 — OUTSIDE TAP INTERCEPTION', () {
    testWidgets('Underlying interactive control does NOT receive tap while expanded', (tester) async {
      bool isExpanded = true;
      bool underlyingTapped = false;
      bool dismissed = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () {
              setState(() {
                isExpanded = false;
                dismissed = true;
              });
            },
            onUnderlyingTap: () {
              underlyingTapped = true;
            },
          );
        },
      ));

      // Tap directly on the location of the underlying control (y=220, x=100)
      await tester.tapAt(const Offset(100.0, 220.0));
      await tester.pumpAndSettle();

      // Outside tap barrier caught the tap -> menu collapsed
      expect(dismissed, isTrue);
      // Underlying control NEVER received the tap event
      expect(underlyingTapped, isFalse);
    });
  });

  group('TEST 3 — SYSTEM BACK', () {
    testWidgets('System back collapses expanded menu and does not pop route on first press', (tester) async {
      bool isExpanded = true;
      bool dismissed = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () {
              setState(() {
                isExpanded = false;
                dismissed = true;
              });
            },
          );
        },
      ));

      // Trigger system back
      final didPop = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // System back was intercepted: route was NOT popped, onDismiss was called
      expect(didPop, isTrue);
      expect(dismissed, isTrue);
      expect(isExpanded, isFalse);
    });
  });

  group('TEST 4 — ESCAPE KEY', () {
    testWidgets('Escape key collapses expanded menu and keeps route active', (tester) async {
      bool isExpanded = true;
      bool dismissed = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () {
              setState(() {
                isExpanded = false;
                dismissed = true;
              });
            },
          );
        },
      ));

      // Send Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(isExpanded, isFalse);
    });
  });

  group('TEST 5 — RAPID DOUBLE TAP SAFETY (DEF-07)', () {
    testWidgets('Second rapid tap at 3-dot location during expansion does NOT invoke top menu action', (tester) async {
      bool isExpanded = false;
      bool deleteDataFired = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () {
              setState(() => isExpanded = false);
            },
            onDeleteData: () {
              deleteDataFired = true;
            },
          );
        },
      ));

      // Find 3-dot button location (trailing button in header)
      final trailingFinder = find.byType(TactileButton).last;
      final triggerCenter = tester.getCenter(trailingFinder);

      // Tap 1: Start expansion
      final gesture1 = await tester.startGesture(triggerCenter);
      await tester.pump(const Duration(milliseconds: 100)); // press timeout
      await gesture1.up();

      // Set state to expanded
      final dynamic state = tester.state(find.byType(StatefulBuilder));
      state.setState(() {
        isExpanded = true;
      });
      await tester.pump(const Duration(milliseconds: 50)); // only 50ms into 340ms expansion

      // Tap 2: Rapid follow-up tap at the exact same location while expanding
      final gesture2 = await tester.startGesture(triggerCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture2.up();
      await tester.pumpAndSettle();

      // Destructive action ("Delete Data") MUST NOT have fired
      expect(deleteDataFired, isFalse);
    });
  });

  group('TEST 6 — REDUCED MOTION', () {
    testWidgets('Backdrop and header expansion snap instantaneously under disableAnimations', (tester) async {
      bool isExpanded = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () => setState(() => isExpanded = false),
            disableAnimations: true,
          );
        },
      ));

      // Expand under reduced motion
      final dynamic state = tester.state(find.byType(StatefulBuilder));
      state.setState(() {
        isExpanded = true;
      });
      await tester.pump(); // zero duration pump

      // Instantly visible without needing pumpAndSettle durations
      final opacityFinder = find.descendant(
        of: find.byType(HeaderExpandedInteraction),
        matching: find.byType(AnimatedOpacity),
      );
      final animOpacity = tester.widget<AnimatedOpacity>(opacityFinder);
      expect(animOpacity.duration, Duration.zero);
      expect(animOpacity.opacity, 1.0);
    });
  });

  group('TEST 7 — MENU ITEM HAPTIC (DEF-10)', () {
    testWidgets('Tapping menu item produces exactly ONE buttonPress semantic haptic event', (tester) async {
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      int deleteCalls = 0;
      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onDeleteData: () => deleteCalls++,
        disableAnimations: true, // fully interactive immediately
      ));

      await tester.tap(find.text('Delete Data'));
      await tester.pump();

      expect(deleteCalls, 1);
      expect(haptics, ['buttonPress']);
      expect(haptics.length, 1);

      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('FolderOptionsPopup items emit exactly ONE buttonPress haptic event', (tester) async {
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      int renameCalls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FolderOptionsPopup(
            onRenameFolder: () => renameCalls++,
          ),
        ),
      ));

      await tester.tap(find.text('Rename Folder'));
      await tester.pump();

      expect(renameCalls, 1);
      expect(haptics, ['buttonPress']);

      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('NoteEditorOptionsPopup items emit exactly ONE buttonPress haptic event', (tester) async {
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      int pinCalls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NoteEditorOptionsPopup(
            isPinned: false,
            isFavorite: false,
            onTogglePin: () => pinCalls++,
          ),
        ),
      ));

      await tester.tap(find.text('Pin Note'));
      await tester.pump();

      expect(pinCalls, 1);
      expect(haptics, ['buttonPress']);

      QuickNotesHaptics.debugHapticListener = null;
    });
  });

  group('TEST 8 — OUTSIDE DISMISSAL HAPTIC', () {
    testWidgets('Outside dismissal produces ZERO haptic events', (tester) async {
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      bool isExpanded = true;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () => setState(() => isExpanded = false),
          );
        },
      ));

      // Tap outside
      await tester.tapAt(const Offset(200.0, 500.0));
      await tester.pumpAndSettle();

      expect(isExpanded, isFalse);
      expect(haptics, isEmpty); // Exactly 0 haptics on passive outside dismissal

      QuickNotesHaptics.debugHapticListener = null;
    });
  });

  group('TEST 9 — SEMANTICS (DEF-11)', () {
    testWidgets('Menu items expose button semantics and descriptive labels', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MoreOptionsPopup(
                onDeleteData: () {},
                onRefresh: () {},
              ),
              NoteEditorOptionsPopup(
                isPinned: false,
                isFavorite: false,
                onTogglePin: () {},
              ),
            ],
          ),
        ),
      ));

      expect(
        tester.getSemantics(find.text('Delete Data')),
        matchesSemantics(
          label: 'Delete Data',
          isButton: true,
          isImage: true,
          hasTapAction: true,
        ),
      );

      expect(
        tester.getSemantics(find.text('Refresh')),
        matchesSemantics(
          label: 'Refresh',
          isButton: true,
          isImage: true,
          hasTapAction: true,
        ),
      );

      expect(
        tester.getSemantics(find.text('Pin Note')),
        matchesSemantics(
          label: 'Pin Note',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });
  });

  group('TEST 10 — FOCUS SAFETY', () {
    testWidgets('TEST 10A — Focus enters expanded menu', (tester) async {
      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
      ));
      await tester.pumpAndSettle();

      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus, isNotNull);
      expect(
        primaryFocus!.context!.findAncestorWidgetOfExactType<MoreOptionsPopup>(),
        isNotNull,
      );
    });

    testWidgets('TEST 10B — Tab moves between actionable menu items', (tester) async {
      int deleteCalls = 0;
      int refreshCalls = 0;

      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onDeleteData: () => deleteCalls++,
        onRefresh: () => refreshCalls++,
      ));
      await tester.pumpAndSettle();

      // Initial focus is on first item: "Delete Data"
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalls, 1);
      expect(refreshCalls, 0);

      // Press Tab -> focus moves to second item: "Refresh"
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalls, 1);
      expect(refreshCalls, 1);
    });

    testWidgets('TEST 10C — Repeated Tab wraps around using closedLoop', (tester) async {
      int deleteCalls = 0;
      int refreshCalls = 0;

      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onDeleteData: () => deleteCalls++,
        onRefresh: () => refreshCalls++,
      ));
      await tester.pumpAndSettle();

      // Tab 1: from Delete Data to Refresh
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Tab 2: from Refresh wraps back to Delete Data
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalls, 1);
      expect(refreshCalls, 0);

      // Tab 3: wraps back to Refresh
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalls, 1);
      expect(refreshCalls, 1);
    });

    testWidgets('TEST 10D — Shift+Tab wraps backwards', (tester) async {
      int deleteCalls = 0;
      int refreshCalls = 0;

      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onDeleteData: () => deleteCalls++,
        onRefresh: () => refreshCalls++,
      ));
      await tester.pumpAndSettle();

      // Initial focus is on Delete Data (first item).
      // Shift+Tab should wrap backwards to Refresh (last item).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalls, 0);
      expect(refreshCalls, 1);
    });

    testWidgets('TEST 10E — Underlying controls never receive focus while menu is expanded', (tester) async {
      bool underlyingActivated = false;

      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onUnderlyingTap: () => underlyingActivated = true,
      ));
      await tester.pumpAndSettle();

      // Press Tab 10 times
      for (int i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(underlyingActivated, isFalse);
      }
    });

    testWidgets('TEST 10F — Focused menu item can be activated with Enter', (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onDeleteData: () => deleteCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalled, isTrue);
    });

    testWidgets('TEST 10G — Focused menu item can be activated with Space', (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onDeleteData: () => deleteCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(deleteCalled, isTrue);
    });

    testWidgets('TEST 10H — Keyboard activation emits exactly one buttonPress haptic', (tester) async {
      final List<String> haptics = [];
      QuickNotesHaptics.debugHapticListener = (method) => haptics.add(method);

      await tester.pumpWidget(buildInteractionTestHarness(
        isExpanded: true,
        onDismiss: () {},
        onDeleteData: () {},
      ));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(haptics, ['buttonPress']);
      expect(haptics.length, 1);

      QuickNotesHaptics.debugHapticListener = null;
    });

    testWidgets('TEST 10I — Escape works while a menu item is focused', (tester) async {
      bool isExpanded = true;
      bool dismissed = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () {
              setState(() {
                isExpanded = false;
                dismissed = true;
              });
            },
          );
        },
      ));
      await tester.pumpAndSettle();

      // Ensure a menu item is focused
      expect(
        FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<MoreOptionsPopup>(),
        isNotNull,
      );

      // Send Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
      expect(isExpanded, isFalse);
    });

    testWidgets('TEST 10J — After collapse, underlying screen traversal becomes available again', (tester) async {
      bool isExpanded = true;
      bool underlyingTapped = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () {
              setState(() => isExpanded = false);
            },
            onUnderlyingTap: () => underlyingTapped = true,
          );
        },
      ));
      await tester.pumpAndSettle();

      // Dismiss menu via Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Now collapsed: Tab traverses into the underlying control
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(underlyingTapped, isTrue);
    });

    testWidgets('TEST 10K — During unsafe expansion (t < 340ms), menu items cannot receive keyboard focus or activate', (tester) async {
      bool isExpanded = false;
      bool deleteCalled = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () => setState(() => isExpanded = false),
            onDeleteData: () => deleteCalled = true,
          );
        },
      ));

      // Trigger expansion
      final dynamic state = tester.state(find.byType(StatefulBuilder));
      state.setState(() {
        isExpanded = true;
      });

      // Pump only 50ms into the 340ms expansion window
      await tester.pump(const Duration(milliseconds: 50));

      // Attempt keyboard activation during unsafe transition
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalled, isFalse); // Protected by isContentInteractive gating!

      // Settle the expansion
      await tester.pumpAndSettle();
      await tester.pump();

      // Now fully settled: keyboard activation succeeds
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalled, isTrue);
    });

    testWidgets('TEST 10L — Reduced-motion mode makes menu immediately focusable without waiting for duration', (tester) async {
      bool isExpanded = false;
      bool deleteCalled = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () => setState(() => isExpanded = false),
            onDeleteData: () => deleteCalled = true,
            disableAnimations: true,
          );
        },
      ));

      // Expand under reduced motion
      final dynamic state = tester.state(find.byType(StatefulBuilder));
      state.setState(() {
        isExpanded = true;
      });
      await tester.pump(); // frame 0 pump

      // Immediately focusable and actionable
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(deleteCalled, isTrue);
    });
  });

  group('TEST 11 — COLLAPSE THEN NAVIGATE', () {
    testWidgets('Action that triggers navigation resolves expanded state cleanly', (tester) async {
      bool isExpanded = true;
      bool navigated = false;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () => setState(() => isExpanded = false),
            onRefresh: () {
              setState(() => isExpanded = false);
              navigated = true;
            },
            disableAnimations: true,
          );
        },
      ));

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(isExpanded, isFalse);
      expect(navigated, isTrue);
    });
  });

  group('TEST 12 — LEADING BACK BUTTON COLLAPSE', () {
    testWidgets('Leading back collapses menu first, then navigates on second press', (tester) async {
      bool isExpanded = true;
      int leadingNavCalls = 0;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          return buildInteractionTestHarness(
            isExpanded: isExpanded,
            onDismiss: () => setState(() => isExpanded = false),
            onLeadingBack: () => leadingNavCalls++,
          );
        },
      ));

      // Press 1: When expanded, leading back collapses menu and does NOT navigate
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(isExpanded, isFalse);
      expect(leadingNavCalls, 0);

      // Press 2: When collapsed, leading back invokes normal navigation
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(leadingNavCalls, 1);
    });
  });
}
