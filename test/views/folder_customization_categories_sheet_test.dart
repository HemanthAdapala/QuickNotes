import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/folder_customization_icon.dart';
import 'package:quick_notes/views/screens/folder_management_screen.dart';
import 'package:quick_notes/views/widgets/folder_card.dart';

Widget buildCustomizationHarness({
  required Folder folder,
  required ValueChanged<Folder> onApply,
  bool isDark = false,
  FolderIconCategory? initialCategory,
}) {
  return MaterialApp(
    theme: isDark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(
      body: FolderCustomizationSheet(
        folder: folder,
        onApply: onApply,
        initialCategory: initialCategory,
      ),
    ),
  );
}

void main() {
  group('FolderCustomizationSheet Category Navigation & Interaction Tests', () {
    testWidgets('1. All four category chips appear on screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testFolder = Folder(
        id: 'f1',
        name: 'Work',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildCustomizationHarness(
        folder: testFolder,
        onApply: (_) {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Casual'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Classic Stickers'), findsOneWidget);
    });

    testWidgets('2. Switching categories updates the visible icons in the grid',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testFolder = Folder(
        id: 'f2',
        name: 'Travel',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildCustomizationHarness(
        folder: testFolder,
        onApply: (_) {},
      ));
      await tester.pumpAndSettle();

      // Default category is Calendar (23 icons + 1 none tile = 24 items)
      // Verify a calendar icon asset is present
      final januaryFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName ==
              'assets/Customization Icons/Calender/january.png');
      expect(januaryFinder, findsOneWidget);

      // Switch to Food category
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      final pizzaFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName ==
              'assets/Customization Icons/Food/pizza.png');
      expect(pizzaFinder, findsOneWidget);
      // Calendar icon should no longer be rendered
      expect(januaryFinder, findsNothing);

      // Switch to Casual category
      await tester.tap(find.text('Casual'));
      await tester.pumpAndSettle();

      final coffeeFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName ==
              'assets/Customization Icons/Casual/coffee-time.png');
      expect(coffeeFinder, findsOneWidget);
      expect(pizzaFinder, findsNothing);

      // Switch to Classic Stickers category
      await tester.tap(find.text('Classic Stickers'));
      await tester.pumpAndSettle();

      final birdsFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/stickers/birds.png');
      expect(birdsFinder, findsOneWidget);
    });

    testWidgets('3. Preserves selected icon when switching between categories',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Folder? applied;
      final testFolder = Folder(
        id: 'f3',
        name: 'Projects',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildCustomizationHarness(
        folder: testFolder,
        onApply: (f) => applied = f,
      ));
      await tester.pumpAndSettle();

      // Switch to Food and select Pizza
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      final pizzaFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName ==
              'assets/Customization Icons/Food/pizza.png');
      await tester.tap(pizzaFinder);
      await tester.pumpAndSettle();

      // Switch to Calendar tab - selection should persist in state
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Switch back to Food tab - Pizza should still have check badge
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();

      // Apply customization
      await tester.tap(find.text('Apply Customization'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.sticker, equals('Food/pizza.png'));
    });

    testWidgets('4. None option clears sticker selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Folder? applied;
      final testFolder = Folder(
        id: 'f4',
        name: 'Personal',
        sticker: 'birds.png',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildCustomizationHarness(
        folder: testFolder,
        onApply: (f) => applied = f,
      ));
      await tester.pumpAndSettle();

      // Initial category opens to Classic Stickers because sticker is birds.png
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);

      // Tap None button
      await tester.tap(find.byIcon(Icons.block_rounded));
      await tester.pumpAndSettle();

      // Apply customization
      await tester.tap(find.text('Apply Customization'));
      await tester.pumpAndSettle();

      expect(applied, isNotNull);
      expect(applied!.sticker, isNull);
    });

    testWidgets('5. FolderGridCard renders categorized icons and legacy stickers',
        (tester) async {
      final categorizedFolder = Folder(
        id: 'f5',
        name: 'Recipes',
        colorHex: '0xFFD4ECDD',
        sticker: 'Food/pizza.png',
        createdAt: DateTime.now(),
      );

      final legacyFolder = Folder(
        id: 'f6',
        name: 'Memories',
        colorHex: '0xFFFFBDE6',
        sticker: 'love.png',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FolderGridCard(
                folder: categorizedFolder,
                index: 0,
                noteCount: 5,
                onTap: () {},
              ),
              FolderGridCard(
                folder: legacyFolder,
                index: 1,
                noteCount: 2,
                onTap: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Categorized pizza icon should be rendered
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/Customization Icons/Food/pizza.png'),
        findsOneWidget,
      );

      // Legacy love sticker should be rendered
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/stickers/love.png'),
        findsOneWidget,
      );
    });
  });
}
