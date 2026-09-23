import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';
import 'optical_test_pattern.dart';

/// Dedicated experiment investigating optical distortion behavior in liquid_glass_widgets 1.7.2.
/// Demonstrates that distortion is an emergent phenomenon of refraction, thickness, and rim bevel.
class DistortionExperimentScreen extends StatefulWidget {
  const DistortionExperimentScreen({super.key});

  @override
  State<DistortionExperimentScreen> createState() => _DistortionExperimentScreenState();
}

class _DistortionExperimentScreenState extends State<DistortionExperimentScreen> {
  double _refractiveIndex = 1.4;
  double _thickness = 25.0;

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
                          'API: Emergent from LiquidGlassSettings.refractiveIndex, thickness',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Scientific principle note
                        Text(
                          'No standalone "distortion" parameter. Distortion emerges from Snell refraction across the 3D surface bevel.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Glass surface placed over high-frequency vertical stripes
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Stripes extending beyond the glass edges to observe rim warp
                            const OpticalTestPattern.stripes(width: 300, height: 160),

                            // The glass surface
                            GlassContainer(
                              useOwnLayer: true,
                              width: 250,
                              height: 140,
                              settings: LiquidGlassSettings(
                                blur: 0, // Zero blur isolates pure geometric distortion
                                refractiveIndex: _refractiveIndex,
                                thickness: _thickness,
                              ),
                              child: const Center(
                                child: Text(
                                  'Observe Edge Warp\nOver High-Frequency Stripes',
                                  textAlign: TextAlign.center,
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

                        const SizedBox(height: 36),

                        // Minimal live controls for underlying physical drivers
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
            'Distortion',
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
                'Refractive Index (Displacement)',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                _refractiveIndex.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CupertinoSlider(
            value: _refractiveIndex,
            min: 1.0,
            max: 2.0,
            onChanged: (val) => setState(() => _refractiveIndex = val),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bevel Depth (Thickness)',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_thickness.toStringAsFixed(0)} px',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CupertinoSlider(
            value: _thickness,
            min: 0.0,
            max: 50.0,
            onChanged: (val) => setState(() => _thickness = val),
          ),
        ],
      ),
    );
  }
}
