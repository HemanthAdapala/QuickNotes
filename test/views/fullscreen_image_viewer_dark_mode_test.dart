import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_notes/views/widgets/fullscreen_image_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('D6-D1 FullscreenImageViewer Dark Mode Contract Tests', () {
    testWidgets('Viewer backdrop is pure black in Dark Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const FullscreenImageViewer(
            imagePath: 'file:///fake_image_test.png',
            heroTag: 'test-hero-dark',
          ),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));
      expect(scaffold.backgroundColor?.toARGB32(), equals(0xFF000000));
    });

    testWidgets('Viewer backdrop is pure black in Light Mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const FullscreenImageViewer(
            imagePath: 'file:///fake_image_test.png',
            heroTag: 'test-hero-light',
          ),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(Colors.black));
      expect(scaffold.backgroundColor?.toARGB32(), equals(0xFF000000));
    });

    testWidgets(
        'Close button control retains translucent black backing and white icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const FullscreenImageViewer(
            imagePath: 'file:///fake_image_test.png',
            heroTag: 'test-hero-close',
          ),
        ),
      );
      await tester.pump();

      final circleAvatarFinder = find.byType(CircleAvatar);
      expect(circleAvatarFinder, findsOneWidget);
      final circleAvatar = tester.widget<CircleAvatar>(circleAvatarFinder);
      expect(circleAvatar.backgroundColor, equals(Colors.black38));

      final iconFinder = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, equals(Colors.white));
    });
  });
}
