import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 02: Surface Count
///
/// Investigates how rendering cost changes as the number of simultaneous
/// glass surfaces scales (1, 2, 4, 8, 16 identical surfaces).
class SurfaceCountBenchmarkScreen extends StatefulWidget {
  const SurfaceCountBenchmarkScreen({super.key});

  @override
  State<SurfaceCountBenchmarkScreen> createState() => _SurfaceCountBenchmarkScreenState();
}

class _SurfaceCountBenchmarkScreenState extends State<SurfaceCountBenchmarkScreen> {
  int _surfaceCount = 4;
  final List<int> _counts = [1, 2, 4, 8, 16];

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '02 — Surface Count',
      subtitle: 'Simultaneous Glass Surfaces Scaling',
      question:
          'How does rendering cost scale with increasing simultaneous glass surfaces (1, 2, 4, 8, 16)?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.moderateObservedCost,
      classificationSummary:
          'Observed raster duration increased approximately linearly across the tested 1–16 surface workload. Under the tested configuration, 1–4 surfaces showed low raster duration, while 16 simultaneous surfaces approached the tested frame budget without sustained violations.',
      notes: const [
        'Each surface renders an independent GlassContainer with standardized blur: 12 and thickness: 25.',
        'At 1–4 surfaces, observed raster duration remained low on the tested configuration.',
        'At 8–16 surfaces, multiple backdrop texture reads and shader passes compound in the compositor.',
        '16 simultaneous surfaces approached the tested frame budget on the measured configuration.',
        'The package documentation notes that screens with 10+ simultaneous glass widgets increase cumulative shader load.',
      ],
      configControls: Wrap(
        spacing: 8,
        children: _counts.map((count) {
          final isSelected = _surfaceCount == count;
          return ChoiceChip(
            label: Text(
              '$count Surface${count > 1 ? 's' : ''}',
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
              if (selected) setState(() => _surfaceCount = count);
            },
          );
        }).toList(),
      ),
      workloadBuilder: (context, isAnimating, animValue) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(_surfaceCount, (index) {
            final double size = _surfaceCount <= 4
                ? 100.0
                : (_surfaceCount <= 8 ? 72.0 : 54.0);

            return GlassContainer(
              width: size,
              height: size,
              settings: const LiquidGlassSettings(
                blur: 12,
                thickness: 25,
              ),
              useOwnLayer: true,
              quality: GlassQuality.standard,
              child: Center(
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: _surfaceCount > 8 ? 11 : 14,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
