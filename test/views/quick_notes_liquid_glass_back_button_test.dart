import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/views/widgets/app_bottom_navigation_bar.dart';
import 'package:quick_notes/views/widgets/quick_notes_liquid_glass_back_button.dart';
import 'package:quick_notes/views/widgets/tactile_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LB-R7: QuickNotesLiquidGlassBackButton Production Forensic Verification', () {
    testWidgets('1. Geometry: Renders at strictly 44.0 x 44.0 circular dimensions with 22.0px radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassBackButton(
                onPressed: () {},
                isDark: true,
                enableFlex: false,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(QuickNotesLiquidGlassBackButton);
      expect(buttonFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(buttonFinder);
      expect(renderBox.size.width, 44.0);
      expect(renderBox.size.height, 44.0);

      // Verify internal BottomBarGlassSurface has radius 22.0
      final glassSurface = tester.widget<BottomBarGlassSurface>(
        find.descendant(
          of: buttonFinder,
          matching: find.byType(BottomBarGlassSurface),
        ),
      );
      expect(glassSurface.width, 44.0);
      expect(glassSurface.height, 44.0);
      expect(glassSurface.borderRadius, BorderRadius.circular(22.0));
    });

    testWidgets('2. Iconography: Renders angle_left.svg asset at exactly 22.0 x 22.0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassBackButton(
                onPressed: () {},
                isDark: true,
                enableFlex: false,
              ),
            ),
          ),
        ),
      );

      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);

      final svgWidget = tester.widget<SvgPicture>(svgFinder);
      expect(svgWidget.width, 22.0);
      expect(svgWidget.height, 22.0);

      final assetBytesLoader = svgWidget.bytesLoader as SvgAssetLoader;
      expect(assetBytesLoader.assetName, 'assets/icons/angle_left.svg');
    });

    testWidgets('3. Single Glass & Zero TactileButton: Strictly 1 BottomBarGlassSurface and 0 TactileButtons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassBackButton(
                onPressed: () {},
                isDark: true,
                enableFlex: true,
              ),
            ),
          ),
        ),
      );

      // Exactly ONE glass surface
      expect(find.byType(BottomBarGlassSurface), findsOneWidget);

      // Exactly ZERO TactileButton
      expect(find.byType(TactileButton), findsNothing);
    });

    testWidgets('4. Haptic Feedback: Emits intentional haptic event exactly once on tap', (tester) async {
      int hapticCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          hapticCount++;
        }
        return null;
      });

      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassBackButton(
                onPressed: () => tapCount++,
                isDark: true,
                enableFlex: false,
                playHaptic: true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(QuickNotesLiquidGlassBackButton));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
      expect(hapticCount, 1);
    });

    testWidgets('5. Theme Resolution: Dark theme resolves white icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassBackButton(
                onPressed: () {},
                enableFlex: false,
              ),
            ),
          ),
        ),
      );

      final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final ColorFilter filter = svg.colorFilter as ColorFilter;
      expect(filter, const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn));
    });

    testWidgets('6. Theme Resolution: Light theme resolves dark icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassBackButton(
                onPressed: () {},
                enableFlex: false,
              ),
            ),
          ),
        ),
      );

      final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final ColorFilter filter = svg.colorFilter as ColorFilter;
      expect(filter, const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn));
    });

    testWidgets('7. Semantics: Exposes button role, Back label, and enabled state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickNotesLiquidGlassBackButton(
                onPressed: () {},
                semanticLabel: 'Back',
              ),
            ),
          ),
        ),
      );

      final data = tester.getSemantics(find.byType(QuickNotesLiquidGlassBackButton)).getSemanticsData();
      expect(data.label, 'Back');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, equals(Tristate.isTrue));

      final renderBox = tester.renderObject<RenderBox>(find.byType(QuickNotesLiquidGlassBackButton));
      expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(44.0));
    });
  });
}
