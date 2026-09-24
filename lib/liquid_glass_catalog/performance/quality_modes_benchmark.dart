import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'performance_benchmark_harness.dart';

/// Phase 1D — Scenario 09: Quality Modes
///
/// Investigates rendering path differences and frame timings between
/// the 3 actual package quality tiers: minimal, standard, and premium.
class QualityModesBenchmarkScreen extends StatefulWidget {
  const QualityModesBenchmarkScreen({super.key});

  @override
  State<QualityModesBenchmarkScreen> createState() => _QualityModesBenchmarkScreenState();
}

class _QualityModesBenchmarkScreenState extends State<QualityModesBenchmarkScreen> {
  GlassQuality _quality = GlassQuality.standard;

  @override
  Widget build(BuildContext context) {
    return PerformanceBenchmarkHarness(
      title: '09 — Quality Modes',
      subtitle: 'Minimal vs Standard vs Premium Pipeline Comparison',
      question:
          'How do the 3 package quality tiers differ in rendering path, shader execution, and measurable performance?',
      reproducibilityQuality: 'GlassQuality.${_quality.name}',
      classification: PerformanceClassification.deviceBackendDependent,
      classificationSummary:
          'Under the tested configuration, Minimal and Standard quality modes showed comparable observed raster durations without sustained frame-budget violations. Premium rendering activates multi-pass Impeller shaders on supported mobile/desktop backends.',
      notes: const [
        'GlassQuality.minimal rendering path: BackdropFilter fallback + Rec. 709 saturation + rim stroke (zero custom fragment shaders). Package documentation notes this tier for list views or low-power modes.',
        'GlassQuality.standard rendering path: Single-pass lightweight fragment shader (lightweight_glass.frag). Package documentation identifies this as the default tier for general widgets.',
        'GlassQuality.premium rendering path: Multi-pass Impeller shader pipeline with texture capture, chromatic dispersion, and specular sheen.',
        'Platform constraint: Windows, Linux, and Web are statically capped at Standard quality by GlassAdaptiveScope.',
        'Observed performance: Under the tested desktop configuration, Minimal and Standard showed comparable raster duration with no sustained frame-budget violations.',
      ],
      configControls: Wrap(
        spacing: 8,
        children: GlassQuality.values.map((q) {
          final isSelected = _quality == q;
          return ChoiceChip(
            label: Text(
              q == GlassQuality.minimal
                  ? 'Minimal (BackdropFilter)'
                  : (q == GlassQuality.standard ? 'Standard (Lightweight)' : 'Premium (Multi-Pass)'),
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
              if (selected) setState(() => _quality = q);
            },
          );
        }).toList(),
      ),
      workloadBuilder: (context, isAnimating, animValue) {
        return GlassContainer(
          width: 280,
          height: 150,
          useOwnLayer: true,
          settings: const LiquidGlassSettings(
            blur: 14,
            thickness: 25,
          ),
          quality: _quality,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _quality == GlassQuality.minimal
                      ? CupertinoIcons.layers
                      : (_quality == GlassQuality.standard
                          ? CupertinoIcons.bolt_fill
                          : CupertinoIcons.sparkles),
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  'GlassQuality.${_quality.name.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _quality == GlassQuality.minimal
                      ? 'BackdropFilter fallback • 0 custom shaders'
                      : (_quality == GlassQuality.standard
                          ? 'lightweight_glass.frag • Single-pass'
                          : 'liquid_glass_render.frag • Multi-pass Impeller'),
                  style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 10.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform: ${defaultTargetPlatform.name}',
                  style: const TextStyle(
                    color: Color(0x77FFFFFF),
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
