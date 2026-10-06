import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_button.dart';

class _MockFoldersProvider extends NotesProvider {
  final List<Folder> _mockFolders = [];

  @override
  List<Folder> get folders => List.unmodifiable(_mockFolders);

  @override
  Future<void> createFolder(String name, {String? parentId}) async {
    _mockFolders.add(Folder(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildHarness({
    required bool isDark,
    NotesProvider? provider,
  }) {
    SharedPreferences.setMockInitialValues({});
    return ChangeNotifierProvider<NotesProvider>.value(
      value: provider ?? _MockFoldersProvider(),
      child: MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: FolderManagementScreen(
          onMenuTap: () {},
          onNavigateToTab: (_) {},
        ),
      ),
    );
  }

  group('FolderManagementScreen QuickNotesLiquidGlassButton Integration Tests', () {
    testWidgets('renders QuickNotesLiquidGlassButton with validated 200x50 geometry and label', (tester) async {
      await tester.pumpWidget(buildHarness(isDark: false));
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(QuickNotesLiquidGlassButton);
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<QuickNotesLiquidGlassButton>(buttonFinder);
      expect(button.width, equals(200.0));
      expect(button.height, equals(50.0));
      expect(button.label, equals('Create Folder'));
      expect(button.isDark, isFalse);
      expect(button.enabled, isTrue);
      expect(button.enableFlex, isTrue);

      final glassFinder = find.descendant(
        of: buttonFinder,
        matching: find.byType(BottomBarGlassSurface),
      );
      expect(glassFinder, findsOneWidget);

      expect(find.text('Create Folder'), findsOneWidget);
    });

    testWidgets('passes isDark=true in Dark Mode', (tester) async {
      await tester.pumpWidget(buildHarness(isDark: true));
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(QuickNotesLiquidGlassButton);
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<QuickNotesLiquidGlassButton>(buttonFinder);
      expect(button.isDark, isTrue);
    });

    testWidgets('tapping QuickNotesLiquidGlassButton invokes showCreateFolderDialog and creates folder', (tester) async {
      final mockProvider = _MockFoldersProvider();
      await tester.pumpWidget(buildHarness(isDark: false, provider: mockProvider));
      await tester.pumpAndSettle();

      expect(find.text('New Folder'), findsNothing);

      // Tap the QuickNotesLiquidGlassButton
      await tester.tap(find.byType(QuickNotesLiquidGlassButton));
      await tester.pumpAndSettle();

      // Dialog should now be open
      expect(find.text('New Folder'), findsOneWidget);
      expect(find.text('save'), findsOneWidget);

      // Enter a folder name
      await tester.enterText(find.byType(TextField), 'Project Glass');
      await tester.pumpAndSettle();

      // Tap 'save' button inside the dialog
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      // Dialog dismissed and folder created in provider
      expect(find.text('New Folder'), findsNothing);
      expect(mockProvider.folders.length, equals(1));
      expect(mockProvider.folders.first.name, equals('Project Glass'));
    });
  });
}
