import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_notes/views/widgets/new_image_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('D6-D2 NewImageWidget Dark Mode Contract Tests', () {
    testWidgets('Unselected border and shadow in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF0088FF),
          ),
          home: Scaffold(
            body: NewImageWidget(
              imagePath: 'file:///test_image.png',
              isSelected: false,
              caption: 'Dark Mode Caption',
              onTap: () {},
              onResize: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Container with border & shadow
      final containerFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
      final darkContainer = tester.widget<Container>(containerFinder.first);
      final darkDecoration = darkContainer.decoration as BoxDecoration;

      // Dark Mode Unselected Border: Colors.white @ 12%
      final darkBorder = darkDecoration.border as Border;
      expect(darkBorder.top.color, Colors.white.withValues(alpha: 0.12));
      expect(darkBorder.top.width, 1.0);

      // Dark Mode Shadow: Colors.black @ 25%
      expect(darkDecoration.boxShadow, isNotNull);
      final darkShadow = darkDecoration.boxShadow!.first;
      expect(darkShadow.color, Colors.black.withValues(alpha: 0.25));

      // Caption in Dark Mode: Colors.white @ 70%
      final darkCaptionText =
          tester.widget<Text>(find.text('📍 Dark Mode Caption'));
      expect(darkCaptionText.style?.color,
          equals(Colors.white.withValues(alpha: 0.70)));
    });

    testWidgets('Unselected border and shadow in Light Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF0088FF),
          ),
          home: Scaffold(
            body: NewImageWidget(
              imagePath: 'file:///test_image.png',
              isSelected: false,
              caption: 'Light Mode Caption',
              onTap: () {},
              onResize: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
      final lightContainer = tester.widget<Container>(containerFinder.first);
      final lightDecoration = lightContainer.decoration as BoxDecoration;

      // Light Mode Unselected Border: Color(0xFF333333) @ 8%
      final lightBorder = lightDecoration.border as Border;
      expect(lightBorder.top.color,
          const Color(0xFF333333).withValues(alpha: 0.08));
      expect(lightBorder.top.width, 1.0);

      // Light Mode Shadow: Color(0xFF333333) @ 4%
      final lightShadow = lightDecoration.boxShadow!.first;
      expect(
          lightShadow.color, const Color(0xFF333333).withValues(alpha: 0.04));

      // Caption in Light Mode
      final lightCaptionText =
          tester.widget<Text>(find.text('📍 Light Mode Caption'));
      expect(lightCaptionText.style?.color,
          ThemeData.light().colorScheme.onSurface.withValues(alpha: 0.70));
    });

    testWidgets('Selected border and Action Panel styling in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF0088FF),
          ),
          home: Scaffold(
            body: NewImageWidget(
              imagePath: 'file:///test_image.png',
              isSelected: true,
              onTap: () {},
              onResize: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Selected Border: theme.primaryColor (#0088FF), width 2.5
      final containerFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, const Color(0xFF0088FF));
      expect(border.top.width, 2.5);

      // Action Panel Finder
      final actionPanelFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final d = widget.decoration as BoxDecoration;
          return d.borderRadius == BorderRadius.circular(20);
        }
        return false;
      });
      expect(actionPanelFinder, findsWidgets);

      final actionPanel = tester.widget<Container>(actionPanelFinder.at(1));
      final panelDeco = actionPanel.decoration as BoxDecoration;

      // Action Panel Surface: #3A3A3C
      expect(panelDeco.color, const Color(0xFF3A3A3C));

      // Action Panel Border: Colors.white @ 15%
      final panelBorder = panelDeco.border as Border;
      expect(panelBorder.top.color, Colors.white.withValues(alpha: 0.15));

      // Resize Action Icon: white
      final resizeIcon = tester
          .widget<Icon>(find.byIcon(Icons.photo_size_select_large_outlined));
      expect(resizeIcon.color, Colors.white);

      // Delete Action Icon: semantic red
      final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
      expect(deleteIcon.color, Colors.red);

      // Tap Resize button to enter slider mode
      await tester.tap(find.byIcon(Icons.photo_size_select_large_outlined));
      await tester.pumpAndSettle();

      // Find slider panel
      expect(find.byType(Slider), findsOneWidget);
      final sliderPanel = tester.widget<Container>(actionPanelFinder.at(1));
      final sliderPanelDeco = sliderPanel.decoration as BoxDecoration;
      expect(sliderPanelDeco.color, const Color(0xFF3A3A3C));
      final sliderPanelBorder = sliderPanelDeco.border as Border;
      expect(sliderPanelBorder.top.color, Colors.white.withValues(alpha: 0.15));

      // Slider back icon is white
      final backIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_back));
      expect(backIcon.color, Colors.white);
    });

    testWidgets('Error container and error text/icon styling in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: NewImageWidget(
              imagePath: 'file:///non_existent_error_image.png',
              isSelected: false,
              onTap: () {},
              onResize: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.errorBuilder, isNotNull);

      // Invoke errorBuilder with element context
      final errorWidget = imageWidget.errorBuilder!(
        tester.element(imageFinder),
        Exception('Test image load failure'),
        null,
      );

      // Verify Error Container Surface: #3A3A3C
      expect(errorWidget, isA<Container>());
      final container = errorWidget as Container;
      expect(container.color, const Color(0xFF3A3A3C));

      // Verify Column children: Icon and Text
      final column = container.child as Column;
      final icon = column.children[0] as Icon;
      expect(icon.icon, Icons.broken_image_outlined);
      expect(icon.color, const Color(0xFF8E8E93));

      final text = column.children[2] as Text;
      expect(text.data, 'Error loading image');
      expect(text.style?.color, const Color(0xFF8E8E93));
    });

    testWidgets('Error container and error text/icon styling in Light Mode',
        (WidgetTester tester) async {
      final lightTheme = ThemeData.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: NewImageWidget(
              imagePath: 'file:///non_existent_error_image.png',
              isSelected: false,
              onTap: () {},
              onResize: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.errorBuilder, isNotNull);

      final errorWidget = imageWidget.errorBuilder!(
        tester.element(imageFinder),
        Exception('Test image load failure'),
        null,
      );

      expect(errorWidget, isA<Container>());
      final container = errorWidget as Container;
      expect(container.color, lightTheme.colorScheme.surfaceContainerHighest);

      final column = container.child as Column;
      final icon = column.children[0] as Icon;
      expect(icon.icon, Icons.broken_image_outlined);
      expect(icon.color, Colors.grey);

      final text = column.children[2] as Text;
      expect(text.data, 'Error loading image');
      expect(text.style?.color, Colors.grey);
    });

    testWidgets('Image pixel integrity: no ColorFiltered or opacity wrap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: NewImageWidget(
              imagePath: 'file:///test_image.png',
              isSelected: false,
              onTap: () {},
              onResize: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Ensure no ColorFiltered is wrapping the image
      expect(find.byType(ColorFiltered), findsNothing);

      // Ensure Image widget is rendered directly inside ClipRRect
      final clipRRectFinder = find.byType(ClipRRect);
      expect(clipRRectFinder, findsOneWidget);
      final clipRRect = tester.widget<ClipRRect>(clipRRectFinder);
      expect(clipRRect.child, isA<Image>());
    });
  });
}
