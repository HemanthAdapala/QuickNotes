import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_background.dart';

/// Dedicated experiment investigating drag stretch physics (anchored elongation vs free follow).
class DragStretchExperimentScreen extends StatefulWidget {
  const DragStretchExperimentScreen({super.key});

  @override
  State<DragStretchExperimentScreen> createState() => _DragStretchExperimentScreenState();
}

class _DragStretchExperimentScreenState extends State<DragStretchExperimentScreen> {
  bool _anchorStretch = true;
  double _stretch = 0.6;
  double _bounciness = 0.20;

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
                          'Public API: GlassButton.stretch, anchorStretch, anchorStretchSettings\nInternal Mechanism: AnchorStretchSettings squash/translation damping',
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
                          'Press and drag the glass button below in any direction to observe elongation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // The draggable glass button under test
                        SizedBox(
                          height: 120,
                          child: Center(
                            child: GlassButton(
                              icon: const Icon(CupertinoIcons.move, color: Colors.white, size: 28),
                              width: 68,
                              height: 68,
                              stretch: _stretch,
                              anchorStretch: _anchorStretch,
                              anchorStretchSettings: AnchorStretchSettings(
                                intensity: _stretch,
                                bounciness: _bounciness,
                                squashFactor: 0.3,
                              ),
                              onTap: () {},
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
            'Drag Stretch',
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
                'Stretch Mode',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => setState(() => _anchorStretch = !_anchorStretch),
                child: Text(
                  _anchorStretch ? 'anchorStretch: true (Elongate)' : 'anchorStretch: false (Follow)',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stretch Amount',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                _stretch.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _stretch,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => setState(() => _stretch = val),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Release Bounciness',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                _bounciness.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
          CupertinoSlider(
            value: _bounciness,
            min: 0.0,
            max: 0.40,
            onChanged: (val) => setState(() => _bounciness = val),
          ),
        ],
      ),
    );
  }
}
