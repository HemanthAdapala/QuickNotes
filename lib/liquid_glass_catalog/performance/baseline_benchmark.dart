import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 01: Baseline
///
/// Investigates static rendering cost vs animation/rebuild overhead vs glass + animation interaction
/// across 4 distinct workloads:
/// - Baseline A: No glass + idle
/// - Baseline B: Glass + idle
/// - Baseline C: No glass + continuous animation
/// - Baseline D: Glass + continuous animation
class BaselineBenchmarkScreen extends StatefulWidget {
  const BaselineBenchmarkScreen({super.key});

  @override
  State<BaselineBenchmarkScreen> createState() => _BaselineBenchmarkScreenState();
}

enum BaselineMode {
  aNoGlassIdle('Baseline A\nNo Glass Idle'),
  bGlassIdle('Baseline B\nGlass Idle'),
  cNoGlassAnim('Baseline C\nNo Glass Anim'),
  dGlassAnim('Baseline D\nGlass Anim');

  final String label;
  const BaselineMode(this.label);
}

class _BaselineBenchmarkScreenState extends State<BaselineBenchmarkScreen> {
  BaselineMode _mode = BaselineMode.bGlassIdle;

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '01 — Baseline',
      subtitle: 'Static vs Animated Rendering Cost Matrix',
      question:
          'What does a completely static glass surface cost versus no glass, and how does animation impact both?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.lowObservedCost,
      classificationSummary:
          'Under the tested configuration, static glass rendering (Baseline B) shows no reproducible frame-budget violations compared to no glass (Baseline A). Introducing continuous animation (C & D) increases UI build and raster workload, but stays within 60 fps budget.',
      notes: const [
        'Baseline A (No glass + idle): Control group establishing background repaint baseline.',
        'Baseline B (Glass + idle): Measures static glass shader composition overhead when no widget rebuilds occur.',
        'Baseline C (No glass + animation): Isolates framework rebuild & translation overhead without glass shaders.',
        'Baseline D (Glass + animation): Evaluates combined cost of continuous widget rebuilds and glass shader passes.',
        'The package fragment shader pipeline executes only when scene invalidation occurs; static glass does not continuously re-execute every frame if the tree is idle.',
      ],
      configControls: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: BaselineMode.values.map((mode) {
          final isSelected = _mode == mode;
          return ChoiceChip(
            label: Text(
              mode.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            selectedColor: const Color(0x55007AFF),
            backgroundColor: const Color(0x22FFFFFF),
            onSelected: (selected) {
              if (selected) setState(() => _mode = mode);
            },
          );
        }).toList(),
      ),
      workloadBuilder: (context, harnessAnimating, animValue) {
        final bool isGlass = _mode == BaselineMode.bGlassIdle || _mode == BaselineMode.dGlassAnim;
        final bool isAnimated = _mode == BaselineMode.cNoGlassAnim || _mode == BaselineMode.dGlassAnim;

        // When in animated mode, translate or rotate content
        final double offset = isAnimated ? math.sin(animValue * 2 * math.pi) * 20.0 : 0.0;

        Widget content = Container(
          width: 260,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGlass ? CupertinoIcons.drop_fill : CupertinoIcons.square_fill,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                _mode.label.replaceAll('\n', ': '),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                isGlass ? 'LiquidGlass Standard (blur: 12, th: 25)' : 'Opaque Container Baseline',
                style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 10),
              ),
            ],
          ),
        );

        if (isGlass) {
          content = GlassContainer(
            settings: const LiquidGlassSettings(
              blur: 12,
              thickness: 25,
            ),
            useOwnLayer: true,
            quality: GlassQuality.standard,
            child: content,
          );
        } else {
          content = Container(
            decoration: BoxDecoration(
              color: const Color(0x44000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: content,
          );
        }

        return Transform.translate(
          offset: Offset(offset, 0),
          child: content,
        );
      },
    );
  }
}
