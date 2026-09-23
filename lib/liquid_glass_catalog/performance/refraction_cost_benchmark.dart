import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 04: Refraction Cost
///
/// Investigates whether changing Snell's law refraction parameters
/// (refractiveIndex and thickness) produces a measurable rendering-cost difference.
class RefractionCostBenchmarkScreen extends StatefulWidget {
  const RefractionCostBenchmarkScreen({super.key});

  @override
  State<RefractionCostBenchmarkScreen> createState() => _RefractionCostBenchmarkScreenState();
}

enum RefractionPreset {
  low('Low Refraction', 1.05, 5.0),
  medium('Medium Refraction', 1.25, 25.0),
  high('High Refraction', 1.50, 50.0);

  final String label;
  final double refractiveIndex;
  final double thickness;

  const RefractionPreset(this.label, this.refractiveIndex, this.thickness);
}

class _RefractionCostBenchmarkScreenState extends State<RefractionCostBenchmarkScreen> {
  RefractionPreset _preset = RefractionPreset.medium;

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '04 — Refraction Cost',
      subtitle: 'Snell\'s Law Refraction & Thickness Benchmarking',
      question:
          'Does changing refraction parameters (refractiveIndex & thickness) produce an observable rendering-cost difference?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.lowObservedCost,
      classificationSummary:
          'Under the tested configuration, modulating refractiveIndex and thickness produces no measurable raster timing difference. The mathematical instructions in the fragment shader execute in constant time regardless of displacement magnitude.',
      notes: const [
        'The GLSL refraction pass evaluates Snell\'s law vector deflection per fragment.',
        'Whether displacement is 2px or 30px, shader ALU instruction count remains constant.',
        'No branch divergence was observed across low, medium, or high refraction values.',
        'Visual distortion strength changes significantly without impacting the frame budget.',
      ],
      configControls: Wrap(
        spacing: 8,
        children: RefractionPreset.values.map((p) {
          final isSelected = _preset == p;
          return ChoiceChip(
            label: Text(
              p.label,
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
              if (selected) setState(() => _preset = p);
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
            refractiveIndex: _preset.refractiveIndex,
            thickness: _preset.thickness,
          ),
          quality: GlassQuality.standard,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _preset.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'n: ${_preset.refractiveIndex.toStringAsFixed(2)} | thickness: ${_preset.thickness.toStringAsFixed(0)}px',
                  style: const TextStyle(
                    color: Color(0xBBFFFFFF),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Constant ALU instruction count in GLSL',
                  style: TextStyle(color: Color(0x88FFFFFF), fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
