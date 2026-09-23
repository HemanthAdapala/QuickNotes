import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';

/// Dedicated experiment evaluating specular highlights, light direction, and Fresnel sheen in liquid_glass_widgets 1.7.2.
class SpecularExperimentScreen extends StatefulWidget {
  const SpecularExperimentScreen({super.key});

  @override
  State<SpecularExperimentScreen> createState() => _SpecularExperimentScreenState();
}

class _SpecularExperimentScreenState extends State<SpecularExperimentScreen> {
  GlassSpecularSharpness _sharpness = GlassSpecularSharpness.medium;
  double _lightIntensity = 0.8;
  double _lightAngleDegrees = 315.0; // Standard top-left light angle
  double _fresnelStrength = 1.0;

  @override
  Widget build(BuildContext context) {
    final lightAngleRadians = _lightAngleDegrees * math.pi / 180.0;

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
                          'API: LiquidGlassSettings.specularSharpness, lightIntensity, lightAngle, fresnelStrength',
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
                          'Specular sharpness controls power-of-2 lobe exponent (soft=8, medium=16, sharp=32).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // The glass surface
                        GlassContainer(
                          useOwnLayer: true,
                          width: 250,
                          height: 160,
                          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
                          settings: LiquidGlassSettings(
                            blur: 4,
                            thickness: 30,
                            specularSharpness: _sharpness,
                            lightIntensity: _lightIntensity,
                            lightAngle: lightAngleRadians,
                            fresnelStrength: _fresnelStrength,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sharpness: ${_sharpness.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Angle: ${_lightAngleDegrees.toStringAsFixed(0)}°',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
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
            'Specular Highlight',
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
          const Text(
            'Specular Sharpness Lobe',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _sharpnessTab('soft (diffuse)', GlassSpecularSharpness.soft),
              const SizedBox(width: 8),
              _sharpnessTab('medium (default)', GlassSpecularSharpness.medium),
              const SizedBox(width: 8),
              _sharpnessTab('sharp (tight)', GlassSpecularSharpness.sharp),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Light Intensity',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                _lightIntensity.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _lightIntensity,
            min: 0.0,
            max: 2.0,
            onChanged: (val) => setState(() => _lightIntensity = val),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Light Direction Angle',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_lightAngleDegrees.toStringAsFixed(0)}°',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _lightAngleDegrees,
            min: 0.0,
            max: 360.0,
            onChanged: (val) => setState(() => _lightAngleDegrees = val),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fresnel Rim Sheen',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                _fresnelStrength.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _fresnelStrength,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => setState(() => _fresnelStrength = val),
          ),
        ],
      ),
    );
  }

  Widget _sharpnessTab(String label, GlassSpecularSharpness val) {
    final isSelected = _sharpness == val;
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: isSelected ? Colors.white24 : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        onPressed: () => setState(() => _sharpness = val),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
