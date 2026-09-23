import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';
import 'optical_test_pattern.dart';

/// Dedicated experiment evaluating chromatic aberration (RGB channel splitting) in liquid_glass_widgets 1.7.2.
class ChromaticAberrationExperimentScreen extends StatefulWidget {
  const ChromaticAberrationExperimentScreen({super.key});

  @override
  State<ChromaticAberrationExperimentScreen> createState() => _ChromaticAberrationExperimentScreenState();
}

class _ChromaticAberrationExperimentScreenState extends State<ChromaticAberrationExperimentScreen> {
  double _chromaticAberration = 0.15;

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
                          'API: LiquidGlassSettings.chromaticAberration',
                          textAlign: TextAlign.center,
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
                          'Shader separates RGB texture samples at refractive boundaries to produce prism dispersion.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Glass surface placed over high-contrast edges
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Chromatic edge test pattern behind the glass
                            const OpticalTestPattern.chromaticEdges(width: 260, height: 160),

                            // The glass surface
                            GlassContainer(
                              useOwnLayer: true,
                              width: 250,
                              height: 150,
                              settings: LiquidGlassSettings(
                                blur: 0, // Zero blur keeps chromatic fringes sharp
                                refractiveIndex: 1.3,
                                thickness: 25,
                                chromaticAberration: _chromaticAberration,
                              ),
                              child: Center(
                                child: Text(
                                  _chromaticAberration == 0.0
                                      ? 'Dispersion: 0.0\n(Zero Color Split)'
                                      : 'Aberration: ${_chromaticAberration.toStringAsFixed(2)}\nPrism Edge Split',
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
            'Chromatic Aberration',
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
                'Chromatic Dispersion',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                _chromaticAberration.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CupertinoSlider(
            value: _chromaticAberration,
            min: 0.0,
            max: 0.5,
            onChanged: (val) => setState(() => _chromaticAberration = val),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _presetButton('0.0 (None)', 0.0),
              _presetButton('0.01 (Def)', 0.01),
              _presetButton('0.15 (Rim)', 0.15),
              _presetButton('0.40 (Prism)', 0.40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetButton(String label, double val) {
    final isSelected = (_chromaticAberration - val).abs() < 0.02;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: isSelected ? Colors.white24 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      onPressed: () => setState(() => _chromaticAberration = val),
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
