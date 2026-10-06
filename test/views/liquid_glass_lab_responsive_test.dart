import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:quick_notes/views/screens/experimental/liquid_glass_easy_button_lab_screen.dart';

void main() {
  const viewports = <String, Size>{
    'Small Phone (320x640)': Size(320, 640),
    'Standard Phone (390x844)': Size(390, 844),
    'Large Phone (430x932)': Size(430, 932),
    'Tablet (768x1024)': Size(768, 1024),
    'Desktop Window (1280x800)': Size(1280, 800),
  };

  for (final entry in viewports.entries) {
    testWidgets('Responsive & Theme test at ${entry.key}', (WidgetTester tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Verify in Light Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const LiquidGlassEasyButtonLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassButton), findsOneWidget);
      expect(find.byKey(const ValueKey('background_layer_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('background_layer_2')), findsOneWidget);
      final lightErr = tester.takeException();
      if (lightErr != null && lightErr is FlutterError) {
        for (final d in lightErr.diagnostics) {
          debugPrint(d.toString());
        }
      }
      expect(lightErr, isNull, reason: 'No layout or overflow exception in Light mode');

      // 2. Verify in Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const LiquidGlassEasyButtonLabScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassButton), findsOneWidget);
      expect(find.byKey(const ValueKey('background_layer_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('background_layer_2')), findsOneWidget);
      final darkErr = tester.takeException();
      expect(darkErr, isNull, reason: 'No layout or overflow exception in Dark mode');
    });
  }
}
