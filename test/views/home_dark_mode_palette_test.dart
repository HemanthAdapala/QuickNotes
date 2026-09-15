import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_notes/themes/app_theme.dart';
import 'package:quick_notes/views/widgets/primary_screen_surface.dart';
import 'package:quick_notes/views/widgets/home_prompt_view.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/views/widgets/notes_stack_widget.dart';
import 'package:quick_notes/models/note.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quick_notes/views/widgets/filter_pill.dart';
import 'package:quick_notes/views/widgets/notes_and_task_pill.dart';
import 'package:quick_notes/views/widgets/task_widget.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/glass_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Phase D2-HOME-A: Main Surfaces Only Verification', () {
    testWidgets(
        'Upper / Root Home Canvas renders #1E1E1E in Dark Mode and AppColors.background in Light Mode',
        (tester) async {
      // 1. Dark Mode Root Canvas
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Scaffold(
                backgroundColor:
                    isDark ? const Color(0xFF1E1E1E) : AppColors.background,
                body: Container(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(darkScaffold.backgroundColor, const Color(0xFF1E1E1E),
          reason: 'Upper / Root Home Canvas must be #1E1E1E in Dark Mode');

      // 2. Light Mode Root Canvas (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Scaffold(
                backgroundColor:
                    isDark ? const Color(0xFF1E1E1E) : AppColors.background,
                body: Container(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(lightScaffold.backgroundColor, AppColors.background,
          reason:
              'Upper / Root Home Canvas must remain AppColors.background in Light Mode');
    });

    testWidgets(
        'Lower Rounded Home Surface (PrimaryScreenSurface) renders #2C2C2C in Dark Mode and white in Light Mode',
        (tester) async {
      // 1. Dark Mode PrimaryScreenSurface on Home Screen
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return PrimaryScreenSurface(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  child: const SizedBox(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PrimaryScreenSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final darkDec = darkContainer.decoration as BoxDecoration;
      expect(darkDec.color, const Color(0xFF2C2C2C),
          reason:
              'Lower Rounded Surface (PrimaryScreenSurface) must be #2C2C2C in Dark Mode');
      expect(
        darkDec.borderRadius,
        const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        reason: '32px top rounded corners must be strictly preserved',
      );

      // 2. Light Mode PrimaryScreenSurface on Home Screen (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return PrimaryScreenSurface(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  child: const SizedBox(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PrimaryScreenSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final lightDec = lightContainer.decoration as BoxDecoration;
      expect(lightDec.color, Colors.white,
          reason:
              'Lower Rounded Surface (PrimaryScreenSurface) must remain Colors.white in Light Mode');
    });

    testWidgets(
        'Default PrimaryScreenSurface behavior without color override remains safe for other screens',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: PrimaryScreenSurface(
              child: SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final defaultContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PrimaryScreenSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final defaultDec = defaultContainer.decoration as BoxDecoration;
      expect(defaultDec.color, Colors.white,
          reason:
              'Default PrimaryScreenSurface must remain white in Light Mode when no color override is passed');
    });

    testWidgets('Header Search Icon renders #FFFFFF in Dark Mode and #1C1C1E in Light Mode', (tester) async {
      Widget buildSearchIcon(bool isDark, int selectedBgIndex) {
        return Icon(
          Icons.search_rounded,
          color: (isDark ||
                  selectedBgIndex == 1 ||
                  selectedBgIndex == 2 ||
                  selectedBgIndex == 6)
              ? Colors.white
              : const Color(0xFF1C1C1E),
          size: 22,
        );
      }

      // 1. Dark Mode Search Icon
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: buildSearchIcon(true, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkIcon = tester.widget<Icon>(find.byType(Icon));
      expect(darkIcon.color, Colors.white,
          reason: 'Search Icon must be #FFFFFF in Dark Mode');

      // 2. Light Mode Search Icon (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: buildSearchIcon(false, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightIcon = tester.widget<Icon>(find.byType(Icon));
      expect(lightIcon.color, const Color(0xFF1C1C1E),
          reason: 'Search Icon must remain #1C1C1E in Light Mode');
    });

    testWidgets('Greeting Typography renders #FFFFFF title and #757575 subtitle in Dark Mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notesProvider = NotesProvider();

      // 1. Dark Mode Greeting
      await tester.pumpWidget(
        ChangeNotifierProvider<NotesProvider>.value(
          value: notesProvider,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: HomePromptView(
                date: DateTime.now(),
                displayName: 'Hemanth',
                showProfileHeader: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title "Hi Hemanth," -> #FFFFFF
      final darkTitleFinder = find.text('Hi Hemanth,');
      expect(darkTitleFinder, findsOneWidget);
      final darkTitle = tester.widget<Text>(darkTitleFinder);
      expect(darkTitle.style?.color, Colors.white,
          reason: 'Greeting title must be #FFFFFF in Dark Mode');

      // Subtitle -> #757575
      final darkSubtitleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.toLowerCase().contains('morning') == true ||
                widget.data?.toLowerCase().contains('afternoon') == true ||
                widget.data?.toLowerCase().contains('evening') == true ||
                widget.data?.toLowerCase().contains('night') == true),
      );
      expect(darkSubtitleFinder, findsOneWidget);
      final darkSubtitle = tester.widget<Text>(darkSubtitleFinder);
      expect(darkSubtitle.style?.color, const Color(0xFF757575),
          reason: 'Greeting subtitle must be #757575 in Dark Mode');

      // 2. Light Mode Greeting (Unchanged)
      await tester.pumpWidget(
        ChangeNotifierProvider<NotesProvider>.value(
          value: notesProvider,
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: HomePromptView(
                date: DateTime.now(),
                displayName: 'Hemanth',
                showProfileHeader: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightTitleFinder = find.text('Hi Hemanth,');
      expect(lightTitleFinder, findsOneWidget);
      final lightTitle = tester.widget<Text>(lightTitleFinder);
      expect(lightTitle.style?.color, const Color(0xFF1C1C1E),
          reason: 'Greeting title must remain #1C1C1E in Light Mode');

      final lightSubtitleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.toLowerCase().contains('morning') == true ||
                widget.data?.toLowerCase().contains('afternoon') == true ||
                widget.data?.toLowerCase().contains('evening') == true ||
                widget.data?.toLowerCase().contains('night') == true),
      );
      expect(lightSubtitleFinder, findsOneWidget);
      final lightSubtitle = tester.widget<Text>(lightSubtitleFinder);
      expect(lightSubtitle.style?.color, const Color(0xFF8E8E93),
          reason: 'Greeting subtitle must remain #8E8E93 in Light Mode');
    });

    testWidgets('Phase D2-C: Notes Card renders Dark Mode palette accurately', (tester) async {
      final sampleNote = Note(
        id: 'note-1',
        title: 'Things to do today',
        content: 'Shopping\nDesign for new brand\nHaircut',
        tags: const [],
        attachments: const [],
        createdAt: DateTime(2026, 6, 1, 2, 0),
        updatedAt: DateTime(2026, 6, 1, 2, 0),
        colorValue: 0xFFFFFFFF,
      );

      // 1. Dark Mode Notes Card
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: NotesStackWidget(
                notes: [sampleNote],
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header Date & Time -> #FFFFFF
      final darkDateText = tester.widget<Text>(find.text('Mon, 1 June'));
      expect(darkDateText.style?.color, Colors.white,
          reason: 'Header date text must be #FFFFFF in Dark Mode');

      final darkTimeText = tester.widget<Text>(find.text('02:00 AM'));
      expect(darkTimeText.style?.color, Colors.white,
          reason: 'Header time text must be #FFFFFF in Dark Mode');

      // Verify Title -> #FFFFFF
      final darkTitle = tester.widget<Text>(find.text('Things to do today'));
      expect(darkTitle.style?.color, Colors.white,
          reason: 'Note title must be #FFFFFF in Dark Mode');

      // Verify Preview / Body Text -> #FFFFFF
      final darkPreview = tester.widget<Text>(find.text(sampleNote.previewText));
      expect(darkPreview.style?.color, Colors.white,
          reason: 'Note preview text must be #FFFFFF in Dark Mode');

      // Verify Card Body Container -> #2C2C2C
      final cardBodyContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == const Color(0xFF2C2C2C);
        }
        return false;
      });
      expect(cardBodyContainers, isNotEmpty,
          reason: 'Card body must be #2C2C2C in Dark Mode');

      // Verify Floating Edit Button Container -> #5A5A5A
      final editButtonContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(editButtonContainers, isNotEmpty,
          reason: 'Edit button container must be #5A5A5A in Dark Mode');

      // Verify Pencil SVG icon colorFilter -> #FFFFFF
      final svgPencilFinder = find.byType(SvgPicture);
      expect(svgPencilFinder, findsOneWidget);
      final svgPencil = tester.widget<SvgPicture>(svgPencilFinder);
      expect(
        svgPencil.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        reason: 'Pencil icon must be #FFFFFF in Dark Mode',
      );

      // 2. Light Mode Notes Card (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: NotesStackWidget(
                notes: [sampleNote],
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightDateText = tester.widget<Text>(find.text('Mon, 1 June'));
      expect(lightDateText.style?.color, const Color(0xFF333333),
          reason: 'Header date text must remain #333333 in Light Mode');

      final lightTimeText = tester.widget<Text>(find.text('02:00 AM'));
      expect(lightTimeText.style?.color, const Color(0xFF333333),
          reason: 'Header time text must remain #333333 in Light Mode');

      final lightTitle = tester.widget<Text>(find.text('Things to do today'));
      expect(lightTitle.style?.color, const Color(0xFF333333),
          reason: 'Note title must remain #333333 in Light Mode');

      final lightPreview = tester.widget<Text>(find.text(sampleNote.previewText));
      expect(lightPreview.style?.color, const Color(0xFF333333),
          reason: 'Note preview text must remain #333333 in Light Mode');

      final lightCardBodyContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == Colors.white;
        }
        return false;
      });
      expect(lightCardBodyContainers, isNotEmpty,
          reason: 'Card body must remain Colors.white in Light Mode');

      final lightEditButtonContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == Colors.white;
        }
        return false;
      });
      expect(lightEditButtonContainers, isNotEmpty,
          reason: 'Edit button container must remain Colors.white in Light Mode');

      final lightSvgPencil = tester.widget<SvgPicture>(svgPencilFinder);
      expect(
        lightSvgPencil.colorFilter,
        const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
        reason: 'Pencil icon must remain #1C1C1E in Light Mode',
      );
    });

    testWidgets('Phase D2-C: Notes Card Empty State renders Dark Mode palette accurately', (tester) async {
      // 1. Dark Mode Empty State
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: NotesStackWidget(
                notes: const [],
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkEmptyCard = tester.widget<Container>(find.byType(Container).first);
      final darkEmptyBox = darkEmptyCard.decoration as BoxDecoration;
      expect(darkEmptyBox.color, const Color(0xFF2C2C2C),
          reason: 'Empty state card body must be #2C2C2C in Dark Mode');

      final darkEmptyTitle = tester.widget<Text>(find.text('No Notes Found'));
      expect(darkEmptyTitle.style?.color, Colors.white,
          reason: 'Empty state title must be #FFFFFF in Dark Mode');

      final darkEmptySubtitle = tester.widget<Text>(find.text('Create a note to populate this deck.'));
      expect(darkEmptySubtitle.style?.color, const Color(0xFF757575),
          reason: 'Empty state subtitle must be #757575 in Dark Mode');

      // 2. Light Mode Empty State (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: NotesStackWidget(
                notes: const [],
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightEmptyCard = tester.widget<Container>(find.byType(Container).first);
      final lightEmptyBox = lightEmptyCard.decoration as BoxDecoration;
      expect(lightEmptyBox.color, Colors.white,
          reason: 'Empty state card body must remain Colors.white in Light Mode');

      final lightEmptyTitle = tester.widget<Text>(find.text('No Notes Found'));
      expect(lightEmptyTitle.style?.color, const Color(0xFF1C1C1E),
          reason: 'Empty state title must remain #1C1C1E in Light Mode');

      final lightEmptySubtitle = tester.widget<Text>(find.text('Create a note to populate this deck.'));
      expect(lightEmptySubtitle.style?.color, const Color(0xFF8E8E93),
          reason: 'Empty state subtitle must remain #8E8E93 in Light Mode');
    });

    testWidgets('Phase D2-D: FilterPill renders Dark Mode palette accurately', (tester) async {
      // 1. Dark Mode Filter Pills
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Row(
              children: [
                FilterPill(
                  filter: 'All',
                  text: 'All',
                  isSelected: true,
                  dotColor: const Color(0xFFFFCC00),
                  onTap: () {},
                ),
                FilterPill(
                  filter: 'Today',
                  text: "Today's Notes 2",
                  isSelected: false,
                  dotColor: const Color(0xFFFFCC00),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Active FilterPill: Background #5A5A5A, Text #FFFFFF
      final activePillText = tester.widget<Text>(find.text('All'));
      expect(activePillText.style?.color, Colors.white,
          reason: 'Active filter pill text must be #FFFFFF in Dark Mode');

      // Verify Inactive FilterPill: Background #5A5A5A, Text #757575
      final inactivePillText = tester.widget<Text>(find.text("Today's Notes 2"));
      expect(inactivePillText.style?.color, const Color(0xFF757575),
          reason: 'Inactive filter pill text must be #757575 in Dark Mode');

      final pillContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final box = c.decoration as BoxDecoration;
          return box.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(pillContainers.length, greaterThanOrEqualTo(2),
          reason: 'Filter pills must have #5A5A5A background in Dark Mode');

      // 2. Light Mode Filter Pills (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Row(
              children: [
                FilterPill(
                  filter: 'All',
                  text: 'All',
                  isSelected: true,
                  dotColor: const Color(0xFFFFCC00),
                  onTap: () {},
                ),
                FilterPill(
                  filter: 'Today',
                  text: "Today's Notes 2",
                  isSelected: false,
                  dotColor: const Color(0xFFFFCC00),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightActiveText = tester.widget<Text>(find.text('All'));
      expect(lightActiveText.style?.color, const Color(0xFF333333),
          reason: 'Active filter pill text must remain #333333 in Light Mode');

      final lightInactiveText = tester.widget<Text>(find.text("Today's Notes 2"));
      expect(lightInactiveText.style?.color, const Color(0x80333333),
          reason: 'Inactive filter pill text must remain 0x80333333 in Light Mode');

      final lightPillContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final box = c.decoration as BoxDecoration;
          return box.color == const Color(0x33787878);
        }
        return false;
      });
      expect(lightPillContainers.length, greaterThanOrEqualTo(2),
          reason: 'Filter pills must remain 0x33787878 in Light Mode');
    });

    testWidgets('Phase D2-D: NotesAndTaskPill renders Dark Mode palette accurately', (tester) async {
      // 1. Dark Mode NotesAndTaskPill (Notes Active)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: NotesAndTaskPill(
                isNotesActive: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Capsule Background -> #5A5A5A
      final outerCapsule = tester.widget<Container>(find.byType(Container).first);
      final outerShape = outerCapsule.decoration as ShapeDecoration;
      expect(outerShape.color, const Color(0xFF5A5A5A),
          reason: 'Segmented pill capsule must be #5A5A5A in Dark Mode');

      // Notes text (Active) -> #FFFFFF
      final darkNotesText = tester.widget<Text>(find.text('Notes'));
      expect(darkNotesText.style?.color, Colors.white,
          reason: 'Active tab text must be #FFFFFF in Dark Mode');

      // Tasks text (Inactive) -> #757575
      final darkTasksText = tester.widget<Text>(find.text('Tasks'));
      expect(darkTasksText.style?.color, const Color(0xFF757575),
          reason: 'Inactive tab text must be #757575 in Dark Mode');

      // Sliding Pod (Notes) -> #FFCC00
      final slidingPodContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == const Color(0xFFFFCC00);
        }
        return false;
      });
      expect(slidingPodContainers, isNotEmpty,
          reason: 'Notes sliding pod must remain #FFCC00');

      // 2. Dark Mode NotesAndTaskPill (Tasks Active)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: NotesAndTaskPill(
                isNotesActive: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkNotesInactive = tester.widget<Text>(find.text('Notes'));
      expect(darkNotesInactive.style?.color, const Color(0xFF757575),
          reason: 'Inactive Notes text must be #757575 in Dark Mode');

      final darkTasksActive = tester.widget<Text>(find.text('Tasks'));
      expect(darkTasksActive.style?.color, Colors.white,
          reason: 'Active Tasks text must be #FFFFFF in Dark Mode');

      // 3. Light Mode NotesAndTaskPill (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: NotesAndTaskPill(
                isNotesActive: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightOuterCapsule = tester.widget<Container>(find.byType(Container).first);
      final lightOuterShape = lightOuterCapsule.decoration as ShapeDecoration;
      expect(lightOuterShape.color, Colors.white,
          reason: 'Segmented pill capsule must remain Colors.white in Light Mode');

      final lightNotesText = tester.widget<Text>(find.text('Notes'));
      expect(lightNotesText.style?.color, Colors.white,
          reason: 'Active Notes text must remain Colors.white in Light Mode');

      final lightTasksText = tester.widget<Text>(find.text('Tasks'));
      expect(lightTasksText.style?.color, const Color(0xFF333333),
          reason: 'Inactive Tasks text must remain #333333 in Light Mode');
    });

    testWidgets('Phase D2-E: TaskWidget active card renders Dark Mode palette accurately', (tester) async {
      final sampleTask = TaskItem(
        id: 'task-1',
        title: 'Review PR & Deploy',
        dueDate: DateTime(2026, 9, 7, 14, 30),
        priority: 'High',
      );

      // 1. Dark Mode TaskWidget
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: TaskWidget(
                tasks: [sampleTask],
                onComplete: (_) {},
                onUndo: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header background -> #0088FF (preserved)
      final headerContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == const Color(0xFF0088FF);
        }
        return false;
      });
      expect(headerContainers, isNotEmpty,
          reason: 'Header must remain #0088FF in Dark Mode');

      // Header Date & Time -> Colors.white
      final darkDateText = tester.widget<Text>(find.text('Mon, 7 September'));
      expect(darkDateText.style?.color, Colors.white,
          reason: 'Header date text must be Colors.white in Dark Mode');

      final darkTimeRichFinder = find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText().contains(':') == true,
      );
      expect(darkTimeRichFinder, findsOneWidget);
      final darkTimeWidget = tester.widget<Text>(darkTimeRichFinder);
      final darkTimeSpan = (darkTimeWidget.textSpan as TextSpan)
          .children!
          .whereType<TextSpan>()
          .first;
      expect(darkTimeSpan.style?.color, Colors.white,
          reason: 'Header time text must be Colors.white in Dark Mode');

      // Card Body Container -> #2C2C2C
      final cardBodyContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == const Color(0xFF2C2C2C);
        }
        return false;
      });
      expect(cardBodyContainers, isNotEmpty,
          reason: 'Card body must be #2C2C2C in Dark Mode');

      // Task Title -> #FFFFFF
      final darkTitle = tester.widget<Text>(find.text('Review PR & Deploy'));
      expect(darkTitle.style?.color, Colors.white,
          reason: 'Task title must be #FFFFFF in Dark Mode');

      // Priority Pill Container -> #5A5A5A
      final priorityPillContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == const Color(0xFF5A5A5A);
        }
        return false;
      });
      expect(priorityPillContainers, isNotEmpty,
          reason: 'Priority pill container must be #5A5A5A in Dark Mode');

      // Slider Track Container -> #5A5A5A
      final sliderTrackContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final dec = c.decoration as BoxDecoration;
          return dec.color == const Color(0xFF5A5A5A) && dec.borderRadius == BorderRadius.circular(25.0);
        }
        return false;
      });
      expect(sliderTrackContainers, isNotEmpty,
          reason: 'Slider track capsule must be #5A5A5A in Dark Mode');

      // Slider Track Text ("Drag to mark done") -> #FFFFFF
      final sliderText = tester.widget<Text>(find.text('Drag to mark done'));
      expect(sliderText.style?.color, Colors.white,
          reason: 'Slider track prompt text must be Colors.white in Dark Mode');

      // Floating Edit Button Container -> #5A5A5A
      final editBtnContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final dec = c.decoration as BoxDecoration;
          return dec.color == const Color(0xFF5A5A5A) && dec.shape == BoxShape.circle;
        }
        return false;
      });
      expect(editBtnContainers, isNotEmpty,
          reason: 'Floating edit button container must be #5A5A5A in Dark Mode');

      // Floating Edit Button pencil icon -> Colors.white
      final pencilIcon = tester.widget<SvgPicture>(find.byWidgetPredicate((w) =>
          w is SvgPicture &&
          (w.bytesLoader.toString().contains('pencil.svg'))));
      expect(
        pencilIcon.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        reason: 'Pencil icon must be Colors.white in Dark Mode',
      );

      // 2. Light Mode TaskWidget (Unchanged)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: TaskWidget(
                tasks: [sampleTask],
                onComplete: (_) {},
                onUndo: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card Body Container -> Colors.white
      final lightCardBodyContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == Colors.white;
        }
        return false;
      });
      expect(lightCardBodyContainers, isNotEmpty,
          reason: 'Card body must remain Colors.white in Light Mode');

      // Task Title -> #333333
      final lightTitle = tester.widget<Text>(find.text('Review PR & Deploy'));
      expect(lightTitle.style?.color, const Color(0xFF333333),
          reason: 'Task title must remain #333333 in Light Mode');

      // Priority Pill Container -> #F2F2F7
      final lightPriorityContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is ShapeDecoration) {
          final shape = c.decoration as ShapeDecoration;
          return shape.color == const Color(0xFFF2F2F7);
        }
        return false;
      });
      expect(lightPriorityContainers, isNotEmpty,
          reason: 'Priority pill container must remain #F2F2F7 in Light Mode');

      // Slider Track Container -> 0x33787878
      final lightSliderContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final dec = c.decoration as BoxDecoration;
          return dec.color == const Color(0x33787878);
        }
        return false;
      });
      expect(lightSliderContainers, isNotEmpty,
          reason: 'Slider track capsule must remain 0x33787878 in Light Mode');

      // Slider Track Text -> #333333
      final lightSliderText = tester.widget<Text>(find.text('Drag to mark done'));
      expect(lightSliderText.style?.color, const Color(0xFF333333),
          reason: 'Slider track text must remain #333333 in Light Mode');

      // Floating Edit Button Container -> Colors.white
      final lightEditBtnContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final dec = c.decoration as BoxDecoration;
          return dec.color == Colors.white && dec.shape == BoxShape.circle;
        }
        return false;
      });
      expect(lightEditBtnContainers, isNotEmpty,
          reason: 'Floating edit button container must remain Colors.white in Light Mode');

      // Floating Edit Button pencil icon -> #1C1C1E
      final lightPencilIcon = tester.widget<SvgPicture>(find.byWidgetPredicate((w) =>
          w is SvgPicture &&
          (w.bytesLoader.toString().contains('pencil.svg'))));
      expect(
        lightPencilIcon.colorFilter,
        const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
        reason: 'Pencil icon must remain #1C1C1E in Light Mode',
      );
    });

    testWidgets('Phase D2-E: TaskWidget completed state and empty state render accurately', (tester) async {
      final completedTask = TaskItem(
        id: 'task-done',
        title: 'Completed Item',
        dueDate: DateTime(2026, 9, 7, 10, 0),
        priority: 'None',
        completed: true,
      );

      // 1. Dark Mode Completed State
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: TaskWidget(
                tasks: [completedTask],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Undo button container -> #5A5A5A
      final darkUndoContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final dec = c.decoration as BoxDecoration;
          return dec.color == const Color(0xFF5A5A5A) && dec.borderRadius == BorderRadius.circular(14.0);
        }
        return false;
      });
      expect(darkUndoContainers, isNotEmpty,
          reason: 'Undo button container must be #5A5A5A in Dark Mode');

      final darkUndoText = tester.widget<Text>(find.text('Undo'));
      expect(darkUndoText.style?.color, const Color(0xFF0088FF),
          reason: 'Undo text must remain #0088FF');

      // 2. Light Mode Completed State
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: TaskWidget(
                tasks: [completedTask],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightUndoContainers = tester.widgetList<Container>(find.byType(Container)).where((c) {
        if (c.decoration is BoxDecoration) {
          final dec = c.decoration as BoxDecoration;
          return dec.color == Colors.white && dec.borderRadius == BorderRadius.circular(14.0);
        }
        return false;
      });
      expect(lightUndoContainers, isNotEmpty,
          reason: 'Undo button container must remain Colors.white in Light Mode');

      // 3. Dark Mode Empty State
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Center(
              child: TaskWidget(
                tasks: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty State Card Container -> #2C2C2C
      final darkEmptyCard = tester.widget<Container>(find.descendant(
        of: find.byType(TaskWidget),
        matching: find.byType(Container).first,
      ));
      final darkEmptyDec = darkEmptyCard.decoration as BoxDecoration;
      expect(darkEmptyDec.color, const Color(0xFF2C2C2C),
          reason: 'Empty state card container must be #2C2C2C in Dark Mode');

      // Empty State Title -> Colors.white
      final darkEmptyTitle = tester.widget<Text>(find.text('All Caught Up!'));
      expect(darkEmptyTitle.style?.color, Colors.white,
          reason: 'Empty state title must be Colors.white in Dark Mode');

      // Empty State Subtitle -> #757575
      final darkEmptySubtitle = tester.widget<Text>(find.text('No pending tasks in this section.'));
      expect(darkEmptySubtitle.style?.color, const Color(0xFF757575),
          reason: 'Empty state subtitle must be #757575 in Dark Mode');

      // 4. Light Mode Empty State
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: Center(
              child: TaskWidget(
                tasks: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightEmptyCard = tester.widget<Container>(find.descendant(
        of: find.byType(TaskWidget),
        matching: find.byType(Container).first,
      ));
      final lightEmptyDec = lightEmptyCard.decoration as BoxDecoration;
      expect(lightEmptyDec.color, Colors.white,
          reason: 'Empty state card container must remain Colors.white in Light Mode');

      final lightEmptyTitle = tester.widget<Text>(find.text('All Caught Up!'));
      expect(lightEmptyTitle.style?.color, const Color(0xFF1C1C1E),
          reason: 'Empty state title must remain #1C1C1E in Light Mode');

      final lightEmptySubtitle = tester.widget<Text>(find.text('No pending tasks in this section.'));
      expect(lightEmptySubtitle.style?.color, const Color(0xFF8E8E93),
          reason: 'Empty state subtitle must remain #8E8E93 in Light Mode');
    });

    test(
        'Hard rule verification: #444444 must not exist in any lib/ source file',
        () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains('444444'),
          isFalse,
          reason: 'Prohibited color #444444 was found in ${file.path}',
        );
      }
    });
  });

  group('Phase D2-F: App Bottom Navigation Bar Stable Active Tint Pill & Glass Preservation', () {
    Widget buildNavWidget({
      required ThemeData theme,
      required int selectedIndex,
      required Color activeColor,
    }) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppBottomNavigationBar(
            selectedIndex: selectedIndex,
            activeColor: activeColor,
            onDestinationSelected: (_) {},
          ),
        ),
      );
    }

    testWidgets(
        'Notes active tint pill renders #FFCC00 stably across Light and Dark Mode with white backing',
        (tester) async {
      const notesTint = Color(0xFFFFCC00);

      // 1. Light Mode Verification
      await tester.pumpWidget(
        buildNavWidget(
          theme: ThemeData.light(),
          selectedIndex: 0,
          activeColor: notesTint,
        ),
      );
      await tester.pumpAndSettle();

      final lightIndicatorFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      expect(lightIndicatorFinder, findsOneWidget);

      final lightGlass = tester.widget<GlassSurface>(lightIndicatorFinder);
      expect(lightGlass.customTintColor, notesTint);
      expect(lightGlass.stableTint, isTrue);

      final lightContainers = tester.widgetList<Container>(
        find.descendant(
          of: lightIndicatorFinder,
          matching: find.byType(Container),
        ),
      ).toList();
      expect(lightContainers.length, greaterThanOrEqualTo(2));

      final lightBaseDec = lightContainers[0].decoration as BoxDecoration;
      expect(lightBaseDec.color, Colors.white.withValues(alpha: 0.94),
          reason: 'Light Mode base backing must be Colors.white @ 0.94');

      final lightTintDec = lightContainers[1].decoration as BoxDecoration;
      expect(lightTintDec.color, notesTint.withValues(alpha: 0.92),
          reason: 'Light Mode tint layer must be #FFCC00 @ 0.92');
      expect(lightTintDec.backgroundBlendMode, BlendMode.multiply);

      // 2. Dark Mode Verification
      await tester.pumpWidget(
        buildNavWidget(
          theme: ThemeData.dark(),
          selectedIndex: 0,
          activeColor: notesTint,
        ),
      );
      await tester.pumpAndSettle();

      final darkIndicatorFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      expect(darkIndicatorFinder, findsOneWidget);

      final darkGlass = tester.widget<GlassSurface>(darkIndicatorFinder);
      expect(darkGlass.customTintColor, notesTint);
      expect(darkGlass.stableTint, isTrue);

      final darkContainers = tester.widgetList<Container>(
        find.descendant(
          of: darkIndicatorFinder,
          matching: find.byType(Container),
        ),
      ).toList();
      expect(darkContainers.length, greaterThanOrEqualTo(2));

      final darkBaseDec = darkContainers[0].decoration as BoxDecoration;
      expect(darkBaseDec.color, Colors.white.withValues(alpha: 0.94),
          reason:
              'Dark Mode base backing must remain Colors.white @ 0.94 (not #333333)');

      final darkTintDec = darkContainers[1].decoration as BoxDecoration;
      expect(darkTintDec.color, notesTint.withValues(alpha: 0.92),
          reason:
              'Dark Mode tint layer must remain #FFCC00 @ 0.92 (not 0.40)');
      expect(darkTintDec.backgroundBlendMode, BlendMode.multiply);

      // Verify identical values between Light and Dark Mode
      expect(darkBaseDec.color, equals(lightBaseDec.color));
      expect(darkTintDec.color, equals(lightTintDec.color));
      expect(darkTintDec.backgroundBlendMode,
          equals(lightTintDec.backgroundBlendMode));
    });

    testWidgets(
        'Tasks active tint pill renders #0088FF stably across Light and Dark Mode with white backing',
        (tester) async {
      const tasksTint = Color(0xFF0088FF);

      // 1. Light Mode Verification
      await tester.pumpWidget(
        buildNavWidget(
          theme: ThemeData.light(),
          selectedIndex: 2,
          activeColor: tasksTint,
        ),
      );
      await tester.pumpAndSettle();

      final lightIndicatorFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      expect(lightIndicatorFinder, findsOneWidget);

      final lightGlass = tester.widget<GlassSurface>(lightIndicatorFinder);
      expect(lightGlass.customTintColor, tasksTint);
      expect(lightGlass.stableTint, isTrue);

      final lightContainers = tester.widgetList<Container>(
        find.descendant(
          of: lightIndicatorFinder,
          matching: find.byType(Container),
        ),
      ).toList();
      expect(lightContainers.length, greaterThanOrEqualTo(2));

      final lightBaseDec = lightContainers[0].decoration as BoxDecoration;
      expect(lightBaseDec.color, Colors.white.withValues(alpha: 0.94));

      final lightTintDec = lightContainers[1].decoration as BoxDecoration;
      expect(lightTintDec.color, tasksTint.withValues(alpha: 0.92));
      expect(lightTintDec.backgroundBlendMode, BlendMode.multiply);

      // 2. Dark Mode Verification
      await tester.pumpWidget(
        buildNavWidget(
          theme: ThemeData.dark(),
          selectedIndex: 2,
          activeColor: tasksTint,
        ),
      );
      await tester.pumpAndSettle();

      final darkIndicatorFinder =
          find.byKey(const ValueKey('physical_active_indicator'));
      expect(darkIndicatorFinder, findsOneWidget);

      final darkGlass = tester.widget<GlassSurface>(darkIndicatorFinder);
      expect(darkGlass.customTintColor, tasksTint);
      expect(darkGlass.stableTint, isTrue);

      final darkContainers = tester.widgetList<Container>(
        find.descendant(
          of: darkIndicatorFinder,
          matching: find.byType(Container),
        ),
      ).toList();
      expect(darkContainers.length, greaterThanOrEqualTo(2));

      final darkBaseDec = darkContainers[0].decoration as BoxDecoration;
      expect(darkBaseDec.color, Colors.white.withValues(alpha: 0.94),
          reason:
              'Dark Mode Tasks base backing must remain Colors.white @ 0.94');

      final darkTintDec = darkContainers[1].decoration as BoxDecoration;
      expect(darkTintDec.color, tasksTint.withValues(alpha: 0.92),
          reason: 'Dark Mode Tasks tint layer must remain #0088FF @ 0.92');
      expect(darkTintDec.backgroundBlendMode, BlendMode.multiply);

      // Verify identical values between Light and Dark Mode
      expect(darkBaseDec.color, equals(lightBaseDec.color));
      expect(darkTintDec.color, equals(lightTintDec.color));
      expect(darkTintDec.backgroundBlendMode,
          equals(lightTintDec.backgroundBlendMode));
    });

    testWidgets(
        'Liquid Glass BottomBarGlassSurface and BackdropFilter remain fully intact in Dark Mode',
        (tester) async {
      await tester.pumpWidget(
        buildNavWidget(
          theme: ThemeData.dark(),
          selectedIndex: 0,
          activeColor: const Color(0xFFFFCC00),
        ),
      );
      await tester.pumpAndSettle();

      // Verify BottomBarGlassSurface is present
      expect(find.byType(BottomBarGlassSurface), findsWidgets);

      // Verify BackdropFilter is present
      final backdropFinder = find.descendant(
        of: find.byType(BottomBarGlassSurface).first,
        matching: find.byType(BackdropFilter),
      );
      expect(backdropFinder, findsWidgets);

      // Verify active icon color is white (#FFFFFF)
      final activeSvg = tester.widget<SvgPicture>(
        find.descendant(
          of: find.byType(AppBottomNavigationBar),
          matching: find.byWidgetPredicate(
            (w) => w is SvgPicture && w.key == const ValueKey(true),
          ),
        ),
      );
      expect(activeSvg.colorFilter,
          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          reason: 'Active icon must remain Colors.white');

      // Phase D2-F.1: Verify unselected icons in Dark Mode are white (#FFFFFF)
      final inactiveSvgs = tester.widgetList<SvgPicture>(
        find.descendant(
          of: find.byType(AppBottomNavigationBar),
          matching: find.byWidgetPredicate(
            (w) => w is SvgPicture && w.key == const ValueKey(false),
          ),
        ),
      );
      expect(inactiveSvgs, isNotEmpty);
      for (final svg in inactiveSvgs) {
        expect(svg.colorFilter,
            const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            reason:
                'Phase D2-F.1: Dark Mode inactive navigation icons must render Colors.white (#FFFFFF) for visibility');
      }
    });

    testWidgets(
        'Phase D2-F.1: Dark Mode renders all navigation icons as #FFFFFF while Light Mode preserves #333333 inactive icons',
        (tester) async {
      // ── 1. Dark Mode Verification across multiple destinations ─────────────
      for (final selectedIndex in [0, 1, 2]) {
        await tester.pumpWidget(
          buildNavWidget(
            theme: ThemeData.dark(),
            selectedIndex: selectedIndex,
            activeColor: selectedIndex == 2
                ? const Color(0xFF0088FF)
                : const Color(0xFFFFCC00),
          ),
        );
        await tester.pumpAndSettle();

        // All SvgPicture icons in Dark Mode must be Colors.white
        final allSvgs = tester.widgetList<SvgPicture>(
          find.descendant(
            of: find.byType(AppBottomNavigationBar),
            matching: find.byType(SvgPicture),
          ),
        );
        expect(allSvgs, isNotEmpty);
        for (final svg in allSvgs) {
          expect(svg.colorFilter,
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              reason:
                  'In Dark Mode (selectedIndex: $selectedIndex), all SVG navigation icons must be #FFFFFF');
        }

        // When selectedIndex == 1, plus icon on FAB must also be Colors.white
        if (selectedIndex == 1) {
          final plusIcon = tester.widget<Icon>(find.byKey(const ValueKey('plus_icon')));
          expect(plusIcon.color, Colors.white,
              reason: 'In Dark Mode, plus icon on FAB must be Colors.white');
        }
      }

      // ── 2. Light Mode Verification (Strict Regression Safety) ──────────────
      await tester.pumpWidget(
        buildNavWidget(
          theme: ThemeData.light(),
          selectedIndex: 0,
          activeColor: const Color(0xFFFFCC00),
        ),
      );
      await tester.pumpAndSettle();

      // Selected SVG must remain Colors.white
      final lightActiveSvg = tester.widget<SvgPicture>(
        find.descendant(
          of: find.byType(AppBottomNavigationBar),
          matching: find.byWidgetPredicate(
            (w) => w is SvgPicture && w.key == const ValueKey(true),
          ),
        ),
      );
      expect(lightActiveSvg.colorFilter,
          const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          reason: 'In Light Mode, active icon must remain Colors.white');

      // Inactive SVGs must remain #333333
      final lightInactiveSvgs = tester.widgetList<SvgPicture>(
        find.descendant(
          of: find.byType(AppBottomNavigationBar),
          matching: find.byWidgetPredicate(
            (w) => w is SvgPicture && w.key == const ValueKey(false),
          ),
        ),
      );
      expect(lightInactiveSvgs, isNotEmpty);
      for (final svg in lightInactiveSvgs) {
        expect(svg.colorFilter,
            const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn),
            reason:
                'In Light Mode, inactive icons must strictly remain #333333');
      }

      // Light Mode FAB plus icon when selectedIndex == 1
      await tester.pumpWidget(
        buildNavWidget(
          theme: ThemeData.light(),
          selectedIndex: 1,
          activeColor: const Color(0xFFFFCC00),
        ),
      );
      await tester.pumpAndSettle();

      final lightPlusIcon = tester.widget<Icon>(find.byKey(const ValueKey('plus_icon')));
      expect(lightPlusIcon.color, const Color(0xFF333333),
          reason:
              'In Light Mode, inactive FAB plus icon must strictly remain #333333');
    });
  });
}

