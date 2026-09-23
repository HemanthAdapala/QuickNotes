import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';

/// Dedicated experiment investigating pointer/touch-position dependent glow on glass surfaces.
class TouchGlowExperimentScreen extends StatefulWidget {
  const TouchGlowExperimentScreen({super.key});

  @override
  State<TouchGlowExperimentScreen> createState() => _TouchGlowExperimentScreenState();
}

class _TouchGlowExperimentScreenState extends State<TouchGlowExperimentScreen> {
  GlassInteractionBehavior _behavior = GlassInteractionBehavior.full;
  double _glowRadius = 1.4;
  double _glowBlurRadius = 16.0;
  bool _useCyanGlow = false;

  Color get _effectiveGlowColor =>
      _useCyanGlow ? const Color(0x6600E5FF) : const Color(0x44FFFFFF);

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
                          'Public API: GlassGlow, GlassInteractionBehavior\nInternal Mechanism: Touch coordinate tracking to radial glow pass',
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
                          'Touch or drag across the glass pane to observe the directional highlight follow your finger.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Interactive glass surface with touch glow
                        SizedBox(
                          width: 270,
                          height: 160,
                          child: GlassContainer(
                            useOwnLayer: true,
                            width: 270,
                            height: 160,
                            shape: const LiquidRoundedSuperellipse(borderRadius: 22),
                            settings: const LiquidGlassSettings(
                              blur: 6,
                              thickness: 24,
                            ),
                            child: _behavior.hasGlow
                                ? GlassGlow(
                                    glowColor: _effectiveGlowColor,
                                    glowRadius: _glowRadius,
                                    glowBlurRadius: _glowBlurRadius,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            CupertinoIcons.hand_point_right_fill,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Mode: ${_behavior.name}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Drag to test glow',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      'Mode: ${_behavior.name}\n(Glow Disabled)',
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
            'Touch Glow',
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
            'GlassInteractionBehavior',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _behaviorTab('none', GlassInteractionBehavior.none),
              const SizedBox(width: 6),
              _behaviorTab('glowOnly', GlassInteractionBehavior.glowOnly),
              const SizedBox(width: 6),
              _behaviorTab('scaleOnly', GlassInteractionBehavior.scaleOnly),
              const SizedBox(width: 6),
              _behaviorTab('full', GlassInteractionBehavior.full),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Glow Radius (Exploration Range)',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_glowRadius.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _glowRadius,
            min: 0.5,
            max: 2.5,
            onChanged: (val) => setState(() => _glowRadius = val),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Glow Blur Radius (Exploration Range)',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_glowBlurRadius.toStringAsFixed(0)} px',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _glowBlurRadius,
            min: 0.0,
            max: 32.0,
            onChanged: (val) => setState(() => _glowBlurRadius = val),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Glow Tint Color',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => setState(() => _useCyanGlow = !_useCyanGlow),
                child: Text(
                  _useCyanGlow ? 'Cyan Accent' : 'White Ambient',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _behaviorTab(String label, GlassInteractionBehavior val) {
    final isSelected = _behavior == val;
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: isSelected ? Colors.white24 : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        onPressed: () => setState(() => _behavior = val),
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
