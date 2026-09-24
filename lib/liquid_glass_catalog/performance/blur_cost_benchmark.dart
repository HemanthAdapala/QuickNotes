import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 03: Blur Cost
///
/// Investigates whether increasing blur radius (0, 5, 12, 25) measurably increases
/// GPU raster cost, and whether animated blur introduces additional compositing pressure.
class BlurCostBenchmarkScreen extends StatefulWidget {
  const BlurCostBenchmarkScreen({super.key});

  @override
  State<BlurCostBenchmarkScreen> createState() => _BlurCostBenchmarkScreenState();
}

class _BlurCostBenchmarkScreenState extends State<BlurCostBenchmarkScreen> {
  double _blur = 12.0;
  bool _isDynamicBlur = false;

  final List<double> _presets = [0.0, 5.0, 12.0, 25.0];

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '03 — Blur Cost',
      subtitle: 'Static & Dynamic Blur Radius Benchmarking',
      question:
          'Does increasing blur radius measurably increase observed Flutter raster duration, and does static blur differ from animated blur?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.lowObservedCost,
      classificationSummary:
          'Under the tested configuration, no significant raster-duration difference was observed between the tested blur values in the tested static configuration. In dynamic animated blur mode, observed raster duration increased slightly during per-frame uniform updates, without sustained budget violations.',
      notes: const [
        'blur: 0.0 represents clear optical glass with edge refraction and specular sheen active; it is NOT "no glass".',
        'In GlassQuality.standard, blur uses a lightweight fragment shader convolution kernel.',
        'Static blur updates do not trigger continuous scene invalidation on idle frames.',
        'Continuous dynamic blur updates force per-frame texture sampling changes without dropping frames on the tested configuration.',
      ],
      configControls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  label: Text(
                    p == 0.0 ? 'Clear (0px)' : (p == 5.0 ? 'Low (5px)' : (p == 12.0 ? 'Med (12px)' : 'High (25px)')),
                    style: TextStyle(
                      color: (!_isDynamicBlur && _blur == p) ? Colors.white : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: (!_isDynamicBlur && _blur == p) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: !_isDynamicBlur && _blur == p,
                  selectedColor: const Color(0x55007AFF),
                  backgroundColor: const Color(0x22FFFFFF),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _isDynamicBlur = false;
                        _blur = p;
                      });
                    }
                  },
                ),
              ChoiceChip(
                label: Text(
                  'Dynamic Wave (0–25px)',
                  style: TextStyle(
                    color: _isDynamicBlur ? const Color(0xFF34C759) : Colors.white70,
                    fontSize: 10.5,
                    fontWeight: _isDynamicBlur ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: _isDynamicBlur,
                selectedColor: const Color(0x4434C759),
                backgroundColor: const Color(0x22FFFFFF),
                onSelected: (selected) {
                  setState(() => _isDynamicBlur = selected);
                },
              ),
            ],
          ),
        ],
      ),
      workloadBuilder: (context, isAnimating, animValue) {
        final double effectiveBlur = _isDynamicBlur
            ? (12.5 + 12.5 * math.sin(animValue * 2 * math.pi)).clamp(0.0, 25.0)
            : _blur;

        return GlassContainer(
          width: 280,
          height: 140,
          settings: LiquidGlassSettings(
            blur: effectiveBlur,
            thickness: 25,
          ),
          useOwnLayer: true,
          quality: GlassQuality.standard,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.circle_grid_hex_fill, color: Colors.white, size: 28),
                const SizedBox(height: 6),
                Text(
                  'Blur: ${effectiveBlur.toStringAsFixed(1)} px',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  _isDynamicBlur ? 'Dynamic Uniform Modulation' : 'Static Radius Benchmark',
                  style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 10.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
