import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 06: Specular & Fresnel Cost
///
/// Investigates whether specular sharpness, light intensity, and Fresnel strength
/// are performance-neutral arithmetic parameters or produce observable raster changes.
class SpecularFresnelCostBenchmarkScreen extends StatefulWidget {
  const SpecularFresnelCostBenchmarkScreen({super.key});

  @override
  State<SpecularFresnelCostBenchmarkScreen> createState() =>
      _SpecularFresnelCostBenchmarkScreenState();
}

class _SpecularFresnelCostBenchmarkScreenState
    extends State<SpecularFresnelCostBenchmarkScreen> {
  GlassSpecularSharpness _sharpness = GlassSpecularSharpness.medium;
  double _lightIntensity = 1.0;
  final double _fresnelStrength = 0.5;

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '06 — Specular & Fresnel Cost',
      subtitle: 'Lighting Arithmetic & Highlight Benchmarking',
      question:
          'Which lighting parameters show measurable raster-duration differences under the tested configuration?',
      reproducibilityQuality: 'GlassQuality.standard',
      classification: PerformanceClassification.lowObservedCost,
      classificationSummary:
          'Under the tested configuration, specular sharpness, light intensity, and Fresnel strength showed no measurable raster-duration differences within the observed measurement variance.',
      notes: const [
        'specularSharpness controls the Blinn-Phong exponent (n=8 for soft, n=16 for medium, n=32 for sharp). In the shader, this evaluates as a pow() call.',
        'lightIntensity is a scalar multiply on the highlight contribution.',
        'fresnelStrength scales the rim grazing angle reflectance.',
        'None of these parameters alter texture read counts, render pass counts, or pipeline branches in the shader source.',
      ],
      configControls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Sharpness: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(width: 8),
              for (final s in GlassSpecularSharpness.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      s.name,
                      style: TextStyle(
                        color: _sharpness == s ? Colors.white : Colors.white70,
                        fontSize: 10.5,
                        fontWeight: _sharpness == s ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: _sharpness == s,
                    selectedColor: const Color(0x55007AFF),
                    backgroundColor: const Color(0x22FFFFFF),
                    onSelected: (selected) {
                      if (selected) setState(() => _sharpness = s);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Intensity: ', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(width: 8),
              for (final val in [0.0, 1.0, 2.0])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      val == 0.0 ? 'Off (0.0)' : (val == 1.0 ? 'Std (1.0)' : 'High (2.0)'),
                      style: TextStyle(
                        color: _lightIntensity == val ? Colors.white : Colors.white70,
                        fontSize: 10.5,
                        fontWeight: _lightIntensity == val ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: _lightIntensity == val,
                    selectedColor: const Color(0x55007AFF),
                    backgroundColor: const Color(0x22FFFFFF),
                    onSelected: (selected) {
                      if (selected) setState(() => _lightIntensity = val);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
      workloadBuilder: (context, isAnimating, animValue) {
        return GlassContainer(
          width: 280,
          height: 140,
          useOwnLayer: true,
          settings: LiquidGlassSettings(
            blur: 10,
            thickness: 20,
            specularSharpness: _sharpness,
            lightIntensity: _lightIntensity,
            fresnelStrength: _fresnelStrength,
            lightAngle: animValue * 6.28318, // Rotates when animation is toggled
          ),
          quality: GlassQuality.standard,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Specular & Fresnel Surface',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sharpness: ${_sharpness.name} | Intensity: ${_lightIntensity.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Color(0xBBFFFFFF),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Evaluates via fragment shader arithmetic with no observed raster delta',
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
