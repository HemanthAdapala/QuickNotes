import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'catalog_background.dart';
import 'component_detail_screen.dart';
import 'optical_effects/blur_experiment.dart';
import 'optical_effects/chromatic_aberration_experiment.dart';
import 'optical_effects/distortion_experiment.dart';
import 'optical_effects/magnification_experiment.dart';
import 'optical_effects/refraction_experiment.dart';
import 'optical_effects/specular_experiment.dart';
import 'interaction/component_physics_experiment.dart';
import 'interaction/drag_stretch_experiment.dart';
import 'interaction/interactive_indicator_experiment.dart';
import 'interaction/optical_interaction_experiment.dart';
import 'interaction/press_response_experiment.dart';
import 'interaction/touch_glow_experiment.dart';
import 'performance/baseline_benchmark.dart';
import 'performance/blur_cost_benchmark.dart';
import 'performance/chromatic_aberration_cost_benchmark.dart';
import 'performance/indicator_cost_benchmark.dart';
import 'performance/interaction_cost_benchmark.dart';
import 'performance/quality_modes_benchmark.dart';
import 'performance/refraction_cost_benchmark.dart';
import 'performance/specular_fresnel_cost_benchmark.dart';
import 'performance/surface_count_benchmark.dart';

/// Phase 1A, 1B, 1C & 1D: Minimal Liquid Glass Component, Optical Effects, Interaction & Performance Index
///
/// Functions as a simple technical index over the single supplied background.
/// Tapping any component, optical effect, interaction experiment, or performance benchmark opens its dedicated inspection screen.
class LiquidGlassCatalogScreen extends StatelessWidget {
  const LiquidGlassCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CatalogBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Buttons ──────────────────────────────────────────
                      _buildCategoryHeader('Buttons'),
                      _buildComponentItem(
                        context,
                        'Glass Button',
                        CatalogComponentType.glassButton,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Icon Button',
                        CatalogComponentType.glassIconButton,
                      ),

                      const SizedBox(height: 24),

                      // ─── Containers ───────────────────────────────────────
                      _buildCategoryHeader('Containers'),
                      _buildComponentItem(
                        context,
                        'Glass Container',
                        CatalogComponentType.glassContainer,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Card',
                        CatalogComponentType.glassCard,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Grouped Section',
                        CatalogComponentType.glassGroupedSection,
                      ),

                      const SizedBox(height: 24),

                      // ─── Controls ─────────────────────────────────────────
                      _buildCategoryHeader('Controls'),
                      _buildComponentItem(
                        context,
                        'Glass Chip',
                        CatalogComponentType.glassChip,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Switch',
                        CatalogComponentType.glassSwitch,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Slider',
                        CatalogComponentType.glassSlider,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Segmented Control',
                        CatalogComponentType.glassSegmentedControl,
                      ),

                      const SizedBox(height: 24),

                      // ─── Surfaces ─────────────────────────────────────────
                      _buildCategoryHeader('Surfaces'),
                      _buildComponentItem(
                        context,
                        'Glass App Bar',
                        CatalogComponentType.glassAppBar,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Tab Bar',
                        CatalogComponentType.glassTabBar,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Scaffold',
                        CatalogComponentType.glassScaffold,
                      ),

                      const SizedBox(height: 24),

                      // ─── Optical Effects ──────────────────────────────────
                      _buildCategoryHeader('Optical Effects'),
                      _buildEffectItem(
                        context,
                        'Blur',
                        () => const BlurExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Refraction',
                        () => const RefractionExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Distortion',
                        () => const DistortionExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Magnification',
                        () => const MagnificationExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Specular Highlight',
                        () => const SpecularExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Chromatic Aberration',
                        () => const ChromaticAberrationExperimentScreen(),
                      ),

                      const SizedBox(height: 24),

                      // ─── Interaction ──────────────────────────────────────
                      _buildCategoryHeader('Interaction'),
                      _buildEffectItem(
                        context,
                        'Press Response',
                        () => const PressResponseExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Touch Glow',
                        () => const TouchGlowExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Drag Stretch',
                        () => const DragStretchExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Interactive Indicator',
                        () => const InteractiveIndicatorExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Component Physics',
                        () => const ComponentPhysicsExperimentScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        'Optical Interaction',
                        () => const OpticalInteractionExperimentScreen(),
                      ),

                      const SizedBox(height: 24),

                      // ─── Performance ──────────────────────────────────────
                      _buildCategoryHeader('Performance'),
                      _buildEffectItem(
                        context,
                        '01 — Baseline',
                        () => const BaselineBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '02 — Surface Count',
                        () => const SurfaceCountBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '03 — Blur Cost',
                        () => const BlurCostBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '04 — Refraction Cost',
                        () => const RefractionCostBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '05 — Chromatic Aberration Cost',
                        () => const ChromaticAberrationCostBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '06 — Specular / Fresnel Cost',
                        () => const SpecularFresnelCostBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '07 — Interaction Cost',
                        () => const InteractionCostBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '08 — Interactive Indicator Cost',
                        () => const IndicatorCostBenchmarkScreen(),
                      ),
                      _buildEffectItem(
                        context,
                        '09 — Quality Modes',
                        () => const QualityModesBenchmarkScreen(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Return to Settings',
          ),
          const SizedBox(width: 4),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIQUID GLASS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Catalog 1.7.2',
                style: TextStyle(
                  color: Color(0xAAFFFFFF),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildComponentItem(
    BuildContext context,
    String label,
    CatalogComponentType type,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ComponentDetailScreen(componentType: type),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: Color(0x88FFFFFF),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEffectItem(
    BuildContext context,
    String label,
    Widget Function() screenBuilder,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => screenBuilder(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: Color(0x88FFFFFF),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
