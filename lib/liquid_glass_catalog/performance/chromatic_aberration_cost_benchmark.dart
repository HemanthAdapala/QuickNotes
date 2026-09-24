import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 05: Chromatic Aberration Cost
///
/// Investigates whether enabling chromatic aberration in the shader produces
/// measurable differences in raster timing or animation smoothness.
class ChromaticAberrationCostBenchmarkScreen extends StatefulWidget {
  const ChromaticAberrationCostBenchmarkScreen({super.key});

  @override
  State<ChromaticAberrationCostBenchmarkScreen> createState() =>
      _ChromaticAberrationCostBenchmarkScreenState();
}

class _ChromaticAberrationCostBenchmarkScreenState
    extends State<ChromaticAberrationCostBenchmarkScreen> {
  double _chromaticAberration = 0.15;
  final List<double> _presets = [0.0, 0.05, 0.15, 0.30];

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '05 — Chromatic Aberration Cost',
      subtitle: 'Color Dispersion Shader Sampling Overhead',
      question:
          'Does enabling chromatic aberration in the shader produce measurable differences in raster timing or animation smoothness?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.lowObservedCost,
      classificationSummary:
          'Under the tested configuration, chromatic aberration produced no measurable Flutter raster-duration difference compared to 0.0 within the observed measurement variance.',
      notes: const [
        'chromaticAberration: 0.0 samples texture coordinates uniformly for R, G, and B.',
        'In the shader source, non-zero values apply a UV coordinate offset before texture lookup.',
        'No frame-budget pressure was observed across tested offset values (0.0 to 0.30) on the measured configuration.',
        'Dispersion remains visual with no measurable raster penalty under the tested workload.',
      ],
      configControls: Wrap(
        spacing: 8,
        children: _presets.map((val) {
          final isSelected = _chromaticAberration == val;
          return ChoiceChip(
            label: Text(
              val == 0.0 ? 'None (0.0)' : (val == 0.05 ? 'Low (0.05)' : (val == 0.15 ? 'Med (0.15)' : 'High (0.30)')),
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
              if (selected) setState(() => _chromaticAberration = val);
            },
          );
        }).toList(),
      ),
      workloadBuilder: (context, isAnimating, animValue) {
        return GlassContainer(
          width: 280,
          height: 140,
          useOwnLayer: true,
          settings: LiquidGlassSettings(
            blur: 10,
            refractiveIndex: 1.25,
            thickness: 25,
            chromaticAberration: _chromaticAberration,
          ),
          quality: GlassQuality.standard,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chromatic Aberration',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aberration: ${_chromaticAberration.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xBBFFFFFF),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _chromaticAberration == 0.0 ? 'Single UV Texture Fetch' : 'Offset UV R/G/B Dispersion',
                  style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
