import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';
import 'optical_test_pattern.dart';

/// Dedicated experiment evaluating blur / frost rendering in liquid_glass_widgets 1.7.2.
class BlurExperimentScreen extends StatefulWidget {
  const BlurExperimentScreen({super.key});

  @override
  State<BlurExperimentScreen> createState() => _BlurExperimentScreenState();
}

class _BlurExperimentScreenState extends State<BlurExperimentScreen> {
  double _blur = 8.0;

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
                          'API: LiquidGlassSettings.blur',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Scientific clarification note
                        Text(
                          'blur = 0 produces clear optical glass (specular rim & refraction intact), not a flat surface.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Glass surface placed over test pattern
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Reference markings behind the glass
                            const OpticalTestPattern.alphanumeric(width: 260, height: 160),

                            // The actual package glass surface
                            GlassContainer(
                              useOwnLayer: true,
                              width: 260,
                              height: 160,
                              settings: LiquidGlassSettings(
                                blur: _blur,
                                thickness: 20,
                              ),
                              child: Center(
                                child: Text(
                                  _blur == 0.0
                                      ? 'Clear Optical Glass'
                                      : 'Blur: ${_blur.toStringAsFixed(1)} px',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
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
            'Blur',
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
                'Blur Radius',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_blur.toStringAsFixed(1)} px',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoSlider(
            value: _blur,
            min: 0.0,
            max: 30.0,
            onChanged: (val) => setState(() => _blur = val),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _presetButton('0 (Clear)', 0.0),
              _presetButton('5 (Subtle)', 5.0),
              _presetButton('12 (Std)', 12.0),
              _presetButton('25 (Frost)', 25.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetButton(String label, double val) {
    final isSelected = (_blur - val).abs() < 0.1;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: isSelected ? Colors.white24 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      onPressed: () => setState(() => _blur = val),
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
