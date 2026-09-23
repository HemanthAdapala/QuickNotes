import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';

/// Dedicated experiment investigating interactive indicator transit dynamics
/// (velocity-based jelly transform and optical concave lens pinch).
class InteractiveIndicatorExperimentScreen extends StatefulWidget {
  const InteractiveIndicatorExperimentScreen({super.key});

  @override
  State<InteractiveIndicatorExperimentScreen> createState() =>
      _InteractiveIndicatorExperimentScreenState();
}

class _InteractiveIndicatorExperimentScreenState
    extends State<InteractiveIndicatorExperimentScreen> {
  int _selectedTab = 0;
  int _selectedSegment = 1;
  double _pinchStrength = 0.5;

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
                        // Tiny factual API labels separating Public API from Internal Mechanism
                        const Text(
                          'Public API: AnimatedGlassIndicator, indicatorPinchStrength\nInternal Mechanism: DraggableIndicatorPhysics jelly transform, shader pinch',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap different tabs or segments to trigger indicator transit and observe squash, stretch, and optical pinch.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 1: GlassSegmentedControl indicator
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '1. GlassSegmentedControl Indicator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GlassSegmentedControl(
                          selectedIndex: _selectedSegment,
                          indicatorPinchStrength: _pinchStrength,
                          segments: const [
                            GlassSegment(label: 'Alpha'),
                            GlassSegment(label: 'Beta'),
                            GlassSegment(label: 'Gamma'),
                          ],
                          onSegmentSelected: (idx) =>
                              setState(() => _selectedSegment = idx),
                        ),

                        const SizedBox(height: 28),

                        // Section 2: GlassTabBar floating indicator
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '2. GlassTabBar Indicator Pill',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GlassTabBar.bottom(
                          selectedIndex: _selectedTab,
                          indicatorPinchStrength: _pinchStrength,
                          onTabSelected: (idx) => setState(() => _selectedTab = idx),
                          tabs: const [
                            GlassTab(icon: Icon(CupertinoIcons.circle_grid_hex), label: 'Transit'),
                            GlassTab(icon: Icon(CupertinoIcons.waveform_path), label: 'Velocity'),
                            GlassTab(icon: Icon(CupertinoIcons.eye_solid), label: 'Optics'),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // Minimal live control
                        _buildControls(),
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
            'Interactive Indicator',
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

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Indicator Pinch Strength',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                _pinchStrength.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CupertinoSlider(
            value: _pinchStrength,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => setState(() => _pinchStrength = val),
          ),
          const SizedBox(height: 4),
          Text(
            'Higher pinch creates a deeper concave lens depression in the shader during movement.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
