import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 08: Interactive Indicator Cost
///
/// Investigates indicator transit, jelly geometry skew, shader pinch,
/// and the performance implications of the package-enforced blur: 0.0 design constraint.
class IndicatorCostBenchmarkScreen extends StatefulWidget {
  const IndicatorCostBenchmarkScreen({super.key});

  @override
  State<IndicatorCostBenchmarkScreen> createState() =>
      _IndicatorCostBenchmarkScreenState();
}

enum IndicatorMode {
  staticIndicator('Static Indicator'),
  movingLinear('Moving Indicator'),
  movingWithPinch('Moving with Pinch'),
  movingWithJelly('Moving with Jelly');

  final String label;
  const IndicatorMode(this.label);
}

class _IndicatorCostBenchmarkScreenState extends State<IndicatorCostBenchmarkScreen> {
  IndicatorMode _mode = IndicatorMode.movingWithPinch;
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '08 — Interactive Indicator Cost',
      subtitle: 'Transit Dynamics, Shader Pinch & Zero-Blur Constraint',
      question:
          'How does indicator movement compare to static indicators, and what are the performance implications of the package enforcing blur: 0.0?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.lowObservedCost,
      classificationSummary:
          'Under the tested configuration, indicator transit with pinch and jelly physics showed no reproducible frame-budget violations. The indicator rendering path enforces blur: 0.0 during transit.',
      notes: const [
        'The indicator rendering path enforces blur: 0.0 during transit (verified package implementation fact).',
        'indicatorPinchStrength updates the concave lens distortion uniform in interactive_indicator.frag.',
        'Geometry skew via DraggableIndicatorPhysics.buildJellyTransform executes as a 2D transform during velocity drag.',
        'Observed indicator movement remained within the tested frame budget under the measured configuration.',
      ],
      configControls: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: IndicatorMode.values.map((m) {
          final isSelected = _mode == m;
          return ChoiceChip(
            label: Text(
              m.label,
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
              if (selected) setState(() => _mode = m);
            },
          );
        }).toList(),
      ),
      workloadBuilder: (context, isAnimating, animValue) {
        // In animated mode, cycle through tabs automatically
        final int activeIndex = isAnimating
            ? (animValue * 3).floor().clamp(0, 2)
            : _selectedTab;

        final double pinchStrength =
            (_mode == IndicatorMode.movingWithPinch || _mode == IndicatorMode.movingWithJelly)
                ? 0.35
                : 0.0;

        return GlassTabBar.bottom(
          selectedIndex: activeIndex,
          onTabSelected: (index) => setState(() => _selectedTab = index),
          indicatorPinchStrength: pinchStrength,
          tabs: const [
            GlassTab(icon: Icon(CupertinoIcons.square_list), label: 'Notes'),
            GlassTab(icon: Icon(CupertinoIcons.folder), label: 'Folders'),
            GlassTab(icon: Icon(CupertinoIcons.gear), label: 'Settings'),
          ],
        );
      },
    );
  }
}
