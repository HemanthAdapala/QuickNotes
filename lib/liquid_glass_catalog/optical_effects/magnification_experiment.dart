import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';
import 'optical_test_pattern.dart';

/// Dedicated experiment evaluating magnification behavior in liquid_glass_widgets 1.7.2.
/// Separates emergent optical lens refraction from component-level layout icon scaling.
class MagnificationExperimentScreen extends StatefulWidget {
  const MagnificationExperimentScreen({super.key});

  @override
  State<MagnificationExperimentScreen> createState() => _MagnificationExperimentScreenState();
}

class _MagnificationExperimentScreenState extends State<MagnificationExperimentScreen> {
  // Optical lens parameters
  double _refractiveIndex = 1.3;
  final double _thickness = 30.0;

  // Component layout magnification
  double _tabMagnification = 1.25;
  int _selectedTab = 1;

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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tiny actual-API indicator
                        const Text(
                          'API: Emergent refraction vs GlassTabBar.magnification',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Scientific distinction note
                        Text(
                          'The package has no standalone optical magnification uniform. Optical magnification emerges from lens curvature; GlassTabBar.magnification is layout scale.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 1: Optical Lens Refraction
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '1. Optical Lens Refraction (Shader)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            const OpticalTestPattern.alphanumeric(width: 280, height: 130),
                            GlassContainer(
                              useOwnLayer: true,
                              width: 240,
                              height: 110,
                              settings: LiquidGlassSettings(
                                blur: 0,
                                refractiveIndex: _refractiveIndex,
                                thickness: _thickness,
                              ),
                              child: const Center(
                                child: Text(
                                  'Curved Optical Pane',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildOpticalControls(),

                        const SizedBox(height: 36),

                        // Section 2: Component Layout Magnification
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '2. Component Layout Magnification (Widget Scale)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassTabBar.bottom(
                          selectedIndex: _selectedTab,
                          onTabSelected: (idx) => setState(() => _selectedTab = idx),
                          magnification: _tabMagnification,
                          tabs: const [
                            GlassTab(icon: Icon(CupertinoIcons.square_grid_2x2_fill), label: 'Grid'),
                            GlassTab(icon: Icon(CupertinoIcons.eye_fill), label: 'Focus'),
                            GlassTab(icon: Icon(CupertinoIcons.slider_horizontal_3), label: 'Scale'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildLayoutControls(),
                      ],
                    ),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => Navigator.of(context).pop(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.back, color: Colors.white, size: 22),
                SizedBox(width: 4),
                Text(
                  'Catalog',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            'Magnification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildOpticalControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lens Index',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                _refractiveIndex.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _refractiveIndex,
            min: 1.0,
            max: 2.0,
            onChanged: (val) => setState(() => _refractiveIndex = val),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GlassTabBar.magnification',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_tabMagnification.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _tabMagnification,
            min: 1.0,
            max: 1.6,
            onChanged: (val) => setState(() => _tabMagnification = val),
          ),
        ],
      ),
    );
  }
}
