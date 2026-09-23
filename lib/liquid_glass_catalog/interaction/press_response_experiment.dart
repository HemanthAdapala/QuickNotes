import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';

/// Dedicated experiment investigating press-induced spring scale inflation in liquid_glass_widgets 1.7.2.
class PressResponseExperimentScreen extends StatefulWidget {
  const PressResponseExperimentScreen({super.key});

  @override
  State<PressResponseExperimentScreen> createState() => _PressResponseExperimentScreenState();
}

class _PressResponseExperimentScreenState extends State<PressResponseExperimentScreen> {
  double _interactionScale = 1.20;
  int _pressCount = 0;

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
                          'Public API: GlassButton.interactionScale\nInternal Mechanism: LiquidStretch spring scale',
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
                          'Press and hold buttons below to observe spring inflation and release snap-back.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Interactive buttons under test
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. Icon Button
                            GlassButton(
                              icon: const Icon(CupertinoIcons.hand_draw_fill, color: Colors.white),
                              interactionScale: _interactionScale,
                              onTap: () => setState(() => _pressCount++),
                            ),
                            const SizedBox(width: 24),
                            // 2. Custom Pill Button
                            GlassButton.custom(
                              interactionScale: _interactionScale,
                              onTap: () => setState(() => _pressCount++),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Press Me ($_pressCount)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
            'Press Response',
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
                'Interaction Scale Factor',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_interactionScale.toStringAsFixed(2)}x',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CupertinoSlider(
            value: _interactionScale,
            min: 1.0,
            max: 1.40,
            onChanged: (val) => setState(() => _interactionScale = val),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _presetButton('1.0 (No scale)', 1.0),
              _presetButton('1.15 (Moderate)', 1.15),
              _presetButton('1.30 (Strong)', 1.30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetButton(String label, double val) {
    final isSelected = (_interactionScale - val).abs() < 0.04;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: isSelected ? Colors.white24 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      onPressed: () => setState(() => _interactionScale = val),
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
