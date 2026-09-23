import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';

/// Dedicated experiment investigating whether and how interaction modifies shader uniforms
/// (dynamic lightAngle via GlassMotionScope vs dynamic pinchStrength in shaders).
class OpticalInteractionExperimentScreen extends StatefulWidget {
  const OpticalInteractionExperimentScreen({super.key});

  @override
  State<OpticalInteractionExperimentScreen> createState() =>
      _OpticalInteractionExperimentScreenState();
}

class _OpticalInteractionExperimentScreenState
    extends State<OpticalInteractionExperimentScreen> {
  final StreamController<double> _motionStream =
      StreamController<double>.broadcast();
  double _motionAngleDegrees = 135.0; // Upper-left default
  int _selectedTab = 0;

  @override
  void dispose() {
    _motionStream.close();
    super.dispose();
  }

  void _updateAngle(double degrees) {
    setState(() => _motionAngleDegrees = degrees);
    _motionStream.add(degrees * math.pi / 180.0);
  }

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
                          'Public API: GlassMotionScope.lightAngle, indicatorPinchStrength\nInternal Mechanism: Direct GPU uniform updates without widget rebuilds',
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
                          'Touch pointer does NOT rotate global lightAngle. Global light movement requires GlassMotionScope streams.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 1: GlassMotionScope dynamic light angle
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '1. Dynamic Specular Orbit (GlassMotionScope)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GlassMotionScope(
                          lightAngle: _motionStream.stream,
                          child: GlassContainer(
                            useOwnLayer: true,
                            width: 260,
                            height: 130,
                            shape: const LiquidRoundedSuperellipse(borderRadius: 22),
                            settings: const LiquidGlassSettings(
                              blur: 4,
                              thickness: 30,
                              lightIntensity: 1.2,
                            ),
                            child: Center(
                              child: Text(
                                'Light Angle: ${_motionAngleDegrees.toStringAsFixed(0)}°\n(Driven by Stream)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildMotionControl(),

                        const SizedBox(height: 32),

                        // Section 2: Dynamic Shader Pinch during transit
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '2. Dynamic Shader Concave Pinch During Transit',
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
                          indicatorPinchStrength: 0.8,
                          onTabSelected: (idx) => setState(() => _selectedTab = idx),
                          tabs: const [
                            GlassTab(icon: Icon(CupertinoIcons.circle_grid_3x3), label: 'Pinch 1'),
                            GlassTab(icon: Icon(CupertinoIcons.circle_grid_3x3_fill), label: 'Pinch 2'),
                            GlassTab(icon: Icon(CupertinoIcons.scope), label: 'Pinch 3'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pinch strength: 0.8 (high) — shader depresses the lens during transit',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
                        ),

                        const SizedBox(height: 20),
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
            'Optical Interaction',
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

  Widget _buildMotionControl() {
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
                'Orbit Virtual Sun Angle',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_motionAngleDegrees.toStringAsFixed(0)}°',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _motionAngleDegrees,
            min: 0.0,
            max: 360.0,
            onChanged: _updateAngle,
          ),
        ],
      ),
    );
  }
}
