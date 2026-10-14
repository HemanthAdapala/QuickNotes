// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/providers/settings_provider.dart';
import 'package:quick_notes/views/screens/developer/dotlottie_test_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('dotLottie Export A Validation', () {
    const assetPath = DotLottieTestScreen.assetPathA;

    test('Export A file exists and is non-empty', () {
      final file = File(assetPath);
      expect(file.existsSync(), isTrue,
          reason: 'Expected $assetPath to exist on disk.');
      expect(file.lengthSync(), greaterThan(1000),
          reason: 'Expected $assetPath to be a substantial dotLottie archive.');
    });

    test('Export A is a valid ZIP archive containing dotLottie v1 files', () {
      final bytes = File(assetPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.files.map((f) => f.name).toSet();

      // Check manifest
      expect(fileNames.contains('manifest.json'), isTrue,
          reason: 'Export A dotLottie archive must contain manifest.json');

      // Check animation JSON
      expect(fileNames.contains('animations/animation.json'), isTrue,
          reason: 'Export A dotLottie archive must contain animations/animation.json');

      // Verify manifest content
      final manifestFile = archive.findFile('manifest.json')!;
      final manifestJson =
          json.decode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;

      expect(manifestJson['version'], '1.0');
      expect(manifestJson['generator'], 'Figma');
      expect(manifestJson['animations'], isNotEmpty);

      // Verify animation JSON specifications
      final animFile = archive.findFile('animations/animation.json')!;
      final animJson =
          json.decode(utf8.decode(animFile.content as List<int>))
              as Map<String, dynamic>;

      expect(animJson['w'], 800, reason: 'Expected canvas width 800');
      expect(animJson['h'], 800, reason: 'Expected canvas height 800');
      expect(animJson['fr'], 60, reason: 'Expected frame rate 60 fps');
      expect(animJson['op'], 120, reason: 'Expected total frames 120');

      // Verify image assets are present
      final images =
          fileNames.where((n) => n.startsWith('images/')).toList();
      expect(images.length, equals(10),
          reason: 'Expected exactly 10 bundled PNG images in Export A');
    });

    test('pubspec.yaml registers the exact Export A asset path', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains(assetPath), isTrue,
          reason: 'pubspec.yaml must register $assetPath directly.');
    });
  });

  group('dotLottie Export B Validation', () {
    const assetPath = DotLottieTestScreen.assetPathB;

    test('Export B file exists and is non-empty', () {
      final file = File(assetPath);
      expect(file.existsSync(), isTrue,
          reason: 'Expected $assetPath to exist on disk.');
      expect(file.lengthSync(), greaterThan(1000),
          reason: 'Expected $assetPath to be a substantial dotLottie archive.');
    });

    test('Export B is a valid dotLottie v2 archive with pure vector shape layers', () {
      final bytes = File(assetPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.files.map((f) => f.name).toSet();

      // Check manifest
      expect(fileNames.contains('manifest.json'), isTrue,
          reason: 'Export B dotLottie archive must contain manifest.json');

      // Check animation JSON inside 'a/' directory (dotLottie v2 convention)
      final animFiles = fileNames
          .where((f) => f.endsWith('.json') && f != 'manifest.json')
          .toList();
      expect(animFiles, isNotEmpty,
          reason: 'Export B must contain an animation JSON');

      // Verify manifest content
      final manifestFile = archive.findFile('manifest.json')!;
      final manifestJson =
          json.decode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;

      expect(manifestJson['version'], '2');
      expect(manifestJson['generator'], contains('LottieFiles'));

      // Verify animation JSON specifications
      final animFile = archive.findFile(animFiles.first)!;
      final animJson =
          json.decode(utf8.decode(animFile.content as List<int>))
              as Map<String, dynamic>;

      expect(animJson['w'], 202, reason: 'Expected tight canvas width 202');
      expect(animJson['h'], 136, reason: 'Expected tight canvas height 136');
      expect(animJson['fr'], 60, reason: 'Expected frame rate 60 fps');
      expect(animJson['op'], 120, reason: 'Expected total frames 120');

      // Verify NO raster images are bundled in Export B (pure vector)
      final images =
          fileNames.where((n) => n.startsWith('images/')).toList();
      expect(images, isEmpty,
          reason: 'Export B must contain 0 raster PNG images (pure vector)');

      // Verify layer types are vector Shape layers (ty == 4)
      final layers = animJson['layers'] as List<dynamic>;
      expect(layers.length, equals(10));
      for (final layer in layers) {
        expect(layer['ty'], equals(4),
            reason: 'Each letter layer must be a Shape layer (ty: 4)');
      }
    });

    test('pubspec.yaml registers the exact Export B asset path', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains(assetPath), isTrue,
          reason: 'pubspec.yaml must register $assetPath directly.');
    });
  });

  group('DotLottieTestScreen Widget Tests', () {
    late SettingsProvider settingsProvider;

    setUp(() async {
      settingsProvider = SettingsProvider();
      await settingsProvider.initialize();
    });

    Widget createTestApp() {
      return ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: const MaterialApp(
          home: DotLottieTestScreen(),
        ),
      );
    }

    testWidgets('renders screen header, stage, switcher and specifications',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Verify Header
      expect(find.text('dotLottie Test'), findsOneWidget);

      // Verify Subtitle and Description
      expect(find.text('FIGMA DOTLOTTIE FIDELITY TEST'), findsOneWidget);

      // Verify Export Selector Buttons
      expect(find.text('Export A (Native Figma)'), findsOneWidget);
      expect(find.text('Export B (LottieFiles)'), findsOneWidget);

      // Verify Controls
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Loop: ON'), findsOneWidget);

      // Verify Specifications Card for default Export A
      expect(find.text('ANIMATION SPECIFICATIONS'), findsOneWidget);
      expect(find.text(DotLottieTestScreen.assetPathA), findsOneWidget);
      expect(find.text('800 × 800 (1:1 artboard with text offset)'), findsOneWidget);
      expect(find.text('dotlottie_flutter ^0.1.7 (dotlottie-rs)'), findsOneWidget);
    });

    testWidgets('tapping Export B switches active export and updates specifications',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Tap Export B
      await tester.tap(find.text('Export B (LottieFiles)'));
      await tester.pump();

      // Specifications card should now show Export B specs
      expect(find.text(DotLottieTestScreen.assetPathB), findsOneWidget);
      expect(find.text('202 × 136 (tight bounding box around text)'), findsOneWidget);
      expect(find.text('10 Vector Bézier Shape Layers (ty: 4)'), findsOneWidget);
      expect(find.text('0 PNG images (Pure Vector Math)'), findsOneWidget);

      // Tap back to Export A
      await tester.tap(find.text('Export A (Native Figma)'));
      await tester.pump();

      expect(find.text(DotLottieTestScreen.assetPathA), findsOneWidget);
      expect(find.text('800 × 800 (1:1 artboard with text offset)'), findsOneWidget);
    });

    testWidgets('tapping Loop button toggles between ON and OFF',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('Loop: ON'), findsOneWidget);

      await tester.tap(find.text('Loop: ON'));
      await tester.pump();

      expect(find.text('Loop: OFF'), findsOneWidget);

      await tester.tap(find.text('Loop: OFF'));
      await tester.pump();

      expect(find.text('Loop: ON'), findsOneWidget);
    });

    testWidgets('view mode toggles between Centered Focus and Full 800×800 Canvas in Export A',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('Centered Focus'), findsOneWidget);
      expect(find.text('Full 800×800 Canvas'), findsOneWidget);

      // Tap Full Canvas
      await tester.tap(find.text('Full 800×800 Canvas'));
      await tester.pump();

      // Tap Centered Focus
      await tester.tap(find.text('Centered Focus'));
      await tester.pump();

      expect(find.text('Centered Focus'), findsOneWidget);
    });
  });
}
