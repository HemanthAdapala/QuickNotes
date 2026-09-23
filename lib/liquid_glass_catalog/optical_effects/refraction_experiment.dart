import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';
import 'optical_test_pattern.dart';

/// Dedicated experiment evaluating Snell's law refractive displacement in liquid_glass_widgets 1.7.2.
class RefractionExperimentScreen extends StatefulWidget {
  const RefractionExperimentScreen({super.key});

  @override
  State<RefractionExperimentScreen> createState() => _RefractionExperimentScreenState();
}

class _RefractionExperimentScreenState extends State<RefractionExperimentScreen> {
  double _refractiveIndex = 1.2;
  double _thickness = 20.0;

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
                          'API: LiquidGlassSettings.refractiveIndex, thickness',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Scientific observation note
                        Text(
                          'refractiveIndex 1.0 → 2.0 is an exploration range to observe shader response, not a linear scale.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Glass surface placed over geometric grid lines & text
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Test pattern behind glass: grid lines extending beyond glass boundary
                            const OpticalTestPattern.gridLines(width: 300, height: 180),

                            // The glass surface
                            GlassContainer(
                              useOwnLayer: true,
                              width: 250,
                              height: 150,
                              settings: LiquidGlassSettings(
                                blur: 0, // Zero blur isolates refraction displacement
                                refractiveIndex: _refractiveIndex,
                                thickness: _thickness,
                              ),
                              child: Center(
                                child: Text(
                                  _refractiveIndex <= 1.0
                                      ? 'Refractive Index: 1.0\n(Zero Displacement)'
                                      : 'Index: ${_refractiveIndex.toStringAsFixed(2)}\nThickness: ${_thickness.toStringAsFixed(0)} px',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),

                        // Minimal live controls
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
            'Refraction',
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
                'Refractive Index',
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
                'Surface Thickness (Depth)',
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _presetButton('1.0 (Flat)', 1.0),
              _presetButton('1.2 (Default)', 1.2),
              _presetButton('1.5 (Dense)', 1.5),
              _presetButton('2.0 (High)', 2.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetButton(String label, double val) {
    final isSelected = (_refractiveIndex - val).abs() < 0.05;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: isSelected ? Colors.white24 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      onPressed: () => setState(() => _refractiveIndex = val),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
