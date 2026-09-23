import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';

/// Dedicated experiment observing the natural, heterogeneous interaction models
/// implemented across core catalog components.
class ComponentPhysicsExperimentScreen extends StatefulWidget {
  const ComponentPhysicsExperimentScreen({super.key});

  @override
  State<ComponentPhysicsExperimentScreen> createState() =>
      _ComponentPhysicsExperimentScreenState();
}

class _ComponentPhysicsExperimentScreenState
    extends State<ComponentPhysicsExperimentScreen> {
  double _sliderValue = 0.5;
  bool _switchValue = true;
  int _segmentedIndex = 0;

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
                          'Public API: GlassSlider, GlassSwitch, GlassSegmentedControl\nInternal Mechanism: Component-specific physics and spring controllers',
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
                          'Interact with each control to observe its distinct, component-specific physics model.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Component 1: GlassSlider (Velocity Squash/Stretch Thumb)
                        _buildSectionHeader(
                          '1. GlassSlider — Velocity Squash/Stretch Thumb',
                          'Thumb squashes horizontally and stretches perpendicularly proportional to drag speed.',
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 280,
                          child: GlassSlider(
                            value: _sliderValue,
                            onChanged: (val) => setState(() => _sliderValue = val),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Value: ${_sliderValue.toStringAsFixed(2)} (Drag fast to observe thumb squash)',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                        ),

                        const SizedBox(height: 32),

                        // Component 2: GlassSwitch (Tactile Spring Jump)
                        _buildSectionHeader(
                          '2. GlassSwitch — Tactile Spring Jump & Track Plump',
                          'Features a directional spring leap between on/off states and midpoint haptics.',
                        ),
                        const SizedBox(height: 10),
                        GlassSwitch(
                          value: _switchValue,
                          useOwnLayer: true,
                          onChanged: (val) => setState(() => _switchValue = val),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'State: ${_switchValue ? "ON (Green)" : "OFF (Neutral)"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                        ),

                        const SizedBox(height: 32),

                        // Component 3: GlassSegmentedControl (Liquid Platter Pill)
                        _buildSectionHeader(
                          '3. GlassSegmentedControl — Liquid Platter Pill',
                          'Indicator slides along segments with spring momentum and drag selection.',
                        ),
                        const SizedBox(height: 10),
                        GlassSegmentedControl(
                          selectedIndex: _segmentedIndex,
                          segments: const [
                            GlassSegment(label: 'Spring'),
                            GlassSegment(label: 'Damp'),
                            GlassSegment(label: 'Snap'),
                          ],
                          onSegmentSelected: (idx) =>
                              setState(() => _segmentedIndex = idx),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Selected Index: $_segmentedIndex',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
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
            'Component Physics',
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

  Widget _buildSectionHeader(String title, String subtitle) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
