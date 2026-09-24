import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 07: Interaction Cost
///
/// Investigates whether interaction overhead originates from static glass rendering,
/// pointer event tracking, animated transform scaling, or anchor stretch spring physics.
class InteractionCostBenchmarkScreen extends StatefulWidget {
  const InteractionCostBenchmarkScreen({super.key});

  @override
  State<InteractionCostBenchmarkScreen> createState() =>
      _InteractionCostBenchmarkScreenState();
}

enum InteractionBenchmarkMode {
  idle('Idle State'),
  pressScale('Press Scale'),
  touchGlow('Touch Glow'),
  dragStretch('Drag Stretch');

  final String label;
  const InteractionBenchmarkMode(this.label);
}

class _InteractionCostBenchmarkScreenState
    extends State<InteractionCostBenchmarkScreen> {
  InteractionBenchmarkMode _mode = InteractionBenchmarkMode.pressScale;

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '07 — Interaction Cost',
      subtitle: 'Press, Touch Glow & Drag Physics Benchmarking',
      question:
          'Where does interaction cost originate: static glass, animated geometry, animated shader uniforms, pointer tracking, or spring physics?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.lowObservedCost,
      classificationSummary:
          'Observed interaction overhead coincided with per-frame framework updates and raster activity; no shader-compilation spike was observed during the tested interaction.',
      notes: const [
        'Idle state: Framework does not schedule continuous repaints when content is static.',
        'Press scale: LiquidStretch spring scale modifies the widget transform matrix without re-blurring.',
        'Touch glow: Pointer coordinates update dynamic uniforms in the radial glow pass.',
        'Drag stretch: Spring physics calculation coincides with per-frame framework layout and paint passes.',
        'Observed interaction frame times remained within the tested frame budget under the measured configuration.',
      ],
      configControls: Wrap(
        spacing: 8,
        children: InteractionBenchmarkMode.values.map((m) {
          final isSelected = _mode == m;
          return ChoiceChip(
            label: Text(
              m.label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            selectedColor: const Color(0x55007AFF),
            backgroundColor: const Color(0x22FFFFFF),
            onSelected: (selected) {
              if (selected) setState(() => _mode = m);
            },
          );
        }).toList(),
      ),
      workloadBuilder: (context, isAnimating, animValue) {
        switch (_mode) {
          case InteractionBenchmarkMode.idle:
            return GlassButton.custom(
              onTap: () {},
              interactionScale: 1.0,
              glowOpacity: 0.0,
              stretch: 0.0,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Idle Glass Button', style: TextStyle(color: Colors.white)),
              ),
            );

          case InteractionBenchmarkMode.pressScale:
            return GlassButton.custom(
              onTap: () {},
              interactionScale: 1.15,
              glowOpacity: 0.0,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Press & Hold to Scale', style: TextStyle(color: Colors.white)),
              ),
            );

          case InteractionBenchmarkMode.touchGlow:
            return GlassButton.custom(
              onTap: () {},
              interactionScale: 1.0,
              glowColor: CupertinoColors.activeBlue,
              glowRadius: 1.2,
              glowBlurRadius: 16.0,
              glowOpacity: 0.8,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Touch & Move for Glow', style: TextStyle(color: Colors.white)),
              ),
            );

          case InteractionBenchmarkMode.dragStretch:
            return GlassButton.custom(
              onTap: () {},
              anchorStretch: true,
              anchorStretchSettings: const AnchorStretchSettings(
                intensity: 0.15,
                bounciness: 0.7,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Drag Button to Stretch', style: TextStyle(color: Colors.white)),
              ),
            );
        }
      },
    );
  }
}
