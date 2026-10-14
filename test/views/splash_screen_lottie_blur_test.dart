import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:quick_notes/services/splash_animation_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final productionFiles = [
    {
      'name': 'Notes Light',
      'path': SplashAnimationResolver.notesLight,
    },
    {
      'name': 'Notes Dark',
      'path': SplashAnimationResolver.notesDark,
    },
    {
      'name': 'Tasks Light',
      'path': SplashAnimationResolver.tasksLight,
    },
    {
      'name': 'Tasks Dark',
      'path': SplashAnimationResolver.tasksDark,
    },
  ];

  group('Phase 3 — Production Lottie Blur Verification', () {
    for (final fileInfo in productionFiles) {
      final name = fileInfo['name'] as String;
      final path = fileInfo['path'] as String;

      test('1-5. $name ($path): Small, Medium, Large layers have non-zero parsed blur radius (~350.0)', () async {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist on disk');

        final bytes = await file.readAsBytes();
        final comp = await LottieComposition.fromBytes(bytes);

        for (final layerName in ['Small', 'Medium', 'Large']) {
          final layer = comp.layers.firstWhere(
            (l) => l.name == layerName,
            orElse: () => throw StateError('Layer $layerName not found in $path'),
          );

          // 1, 2, 3: Must have non-zero parsed blur
          expect(layer.blurEffect, isNotNull, reason: '$name - $layerName must have a parsed blurEffect');
          final blurAnim = layer.blurEffect!.blurriness.createAnimation();
          expect(blurAnim.value, isNonZero, reason: '$name - $layerName blur must be non-zero');
          expect(blurAnim.value, isPositive, reason: '$name - $layerName blur must be positive');

          // 4: The effective parsed blur value is approximately 350.0
          expect(blurAnim.value, closeTo(350.0, 0.01),
              reason: '$name - $layerName parsed blur value must be ~350.0');

          // Check keyframe initial values directly on the model
          expect(layer.blurEffect!.blurriness.keyframes.isNotEmpty, isTrue);
          expect(layer.blurEffect!.blurriness.keyframes.first.startValue, closeTo(350.0, 0.01));
        }
      });

      test('6. $name ($path): Frame count, frame rate, dimensions, and duration remain unchanged', () async {
        final file = File(path);
        final rawJson = await file.readAsString();
        final Map<String, dynamic> data = json.decode(rawJson) as Map<String, dynamic>;

        // Dimensions: 402 x 874
        expect(data['w'], equals(402), reason: '$name width must be 402');
        expect(data['h'], equals(874), reason: '$name height must be 874');

        // Frame rate: 60 fps
        expect(data['fr'], equals(60), reason: '$name frame rate must be 60 fps');

        // Frame range: 0 to 85 (85 frames)
        expect(data['ip'], equals(0), reason: '$name inFrame must be 0');
        expect(data['op'], equals(85), reason: '$name outFrame must be 85');

        // Check parsed LottieComposition metadata matches
        final bytes = await file.readAsBytes();
        final comp = await LottieComposition.fromBytes(bytes);
        expect(comp.startFrame, equals(0.0));
        expect(comp.endFrame, closeTo(85.0, 0.05));
        expect(comp.frameRate, equals(60.0));
        expect(comp.bounds.width, equals(402.0));
        expect(comp.bounds.height, equals(874.0));
        expect(comp.duration.inMilliseconds, equals(1416)); // 85 / 60 * 1000 = 1416.67ms
      });
    }

    test('All 12 layer/animation combinations have non-zero parsed blur of approximately 350.0', () async {
      final summary = <String, double>{};
      for (final fileInfo in productionFiles) {
        final name = fileInfo['name'] as String;
        final path = fileInfo['path'] as String;
        final bytes = await File(path).readAsBytes();
        final comp = await LottieComposition.fromBytes(bytes);

        for (final layerName in ['Small', 'Medium', 'Large']) {
          final layer = comp.layers.firstWhere((l) => l.name == layerName);
          final value = layer.blurEffect!.blurriness.createAnimation().value;
          summary['$name -> $layerName'] = value;
          expect(value, closeTo(350.0, 0.01));
        }
      }

      expect(summary.length, equals(12));
      for (final entry in summary.entries) {
        expect(entry.value, closeTo(350.0, 0.01));
      }
    });

    test('Rendering level verification: multi-frame continuous blur across animation playback', () async {
      for (final fileInfo in productionFiles) {
        final name = fileInfo['name'] as String;
        final path = fileInfo['path'] as String;
        final bytes = await File(path).readAsBytes();
        final comp = await LottieComposition.fromBytes(bytes);

        final delegates = LottieDelegates(
          values: [
            ValueDelegate.blurRadius(
              const ['Small', '**'],
              callback: (info) => 350.0 + (info.overallProgress * 0.01),
            ),
            ValueDelegate.blurRadius(
              const ['Medium', '**'],
              callback: (info) => 350.0 + (info.overallProgress * 0.01),
            ),
            ValueDelegate.blurRadius(
              const ['Large', '**'],
              callback: (info) => 350.0 + (info.overallProgress * 0.01),
            ),
          ],
        );

        final drawable = LottieDrawable(comp);
        drawable.delegates = delegates;

        // Draw frame 1 (progress 0.1)
        drawable.setProgress(0.1);
        final rec1 = ui.PictureRecorder();
        drawable.draw(Canvas(rec1), const Rect.fromLTWH(0, 0, 402, 874));
        await rec1.endRecording().toImage(402, 874);

        // Draw frame 2 (progress 0.5)
        drawable.setProgress(0.5);
        final rec2 = ui.PictureRecorder();
        final canvas2 = Canvas(rec2);
        canvas2.drawRect(const Rect.fromLTWH(0, 0, 402, 874), Paint()..color = Colors.white);
        drawable.draw(canvas2, const Rect.fromLTWH(0, 0, 402, 874));
        final img2 = await rec2.endRecording().toImage(402, 874);
        final raw2 = (await img2.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

        // Without blur, there is a sharp discontinuity between y=142 and y=143
        // where the small circle ends and the medium circle begins (step diff > 30).
        // With blur, the transition is smooth (adjacent step <= 3 per pixel).
        const idx142 = (142 * 402 + 201) * 4;
        const idx143 = (143 * 402 + 201) * 4;
        final stepDiff = (raw2[idx142] - raw2[idx143]).abs() +
            (raw2[idx142 + 1] - raw2[idx143 + 1]).abs() +
            (raw2[idx142 + 2] - raw2[idx143 + 2]).abs();
        expect(stepDiff <= 3, isTrue,
            reason: '$name must exhibit smooth gradient transition at circle boundary on frame 2 (stepDiff: $stepDiff, expected <= 3)');
      }
    });
  });
}
