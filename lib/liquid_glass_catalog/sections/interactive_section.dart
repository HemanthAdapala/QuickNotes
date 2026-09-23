import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_card_wrapper.dart';

/// Phase 1A Catalog: Interactive Controls
class InteractiveSection extends StatefulWidget {
  const InteractiveSection({super.key});

  @override
  State<InteractiveSection> createState() => _InteractiveSectionState();
}

class _InteractiveSectionState extends State<InteractiveSection> {
  // GlassButton state
  int _buttonTapCount = 0;
  bool _buttonsEnabled = true;

  // GlassIconButton state
  bool _iconButtonSquare = false;

  // GlassChip state
  bool _chipSelected1 = true;
  bool _chipSelected2 = false;
  bool _chipDismissed = false;

  // GlassSwitch state
  bool _switchValue1 = true;
  bool _switchValue2 = false;

  // GlassSlider state
  double _sliderValueContinuous = 0.65;
  double _sliderValueDiscrete = 3.0;

  // GlassSegmentedControl state
  int _segmentedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildGlassButtonDemo(),
        _buildGlassIconButtonDemo(),
        _buildGlassChipDemo(),
        _buildGlassSwitchDemo(),
        _buildGlassSliderDemo(),
        _buildGlassSegmentedControlDemo(),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. GlassButton & GlassButton.custom
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassButtonDemo() {
    return CatalogCardWrapper(
      title: 'GlassButton & GlassButton.custom',
      description:
          'Interactive buttons featuring spring inflation when pressed, subtle squash & stretch physics on drag, and touch-responsive glow.',
      parameterTags: const [
        'useOwnLayer',
        'GlassButton (icon)',
        'GlassButton.custom (composite)',
        'stretch',
        'enabled',
      ],
      preview: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Standard Icon GlassButton
          GlassButton(
            useOwnLayer: true,
            enabled: _buttonsEnabled,
            icon: const Icon(CupertinoIcons.heart_fill, color: Colors.white, size: 20),
            onTap: () => setState(() => _buttonTapCount++),
          ),

          // Custom content GlassButton
          GlassButton.custom(
            useOwnLayer: true,
            enabled: _buttonsEnabled,
            shape: const LiquidRoundedSuperellipse(borderRadius: 22),
            onTap: () => setState(() => _buttonTapCount++),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_fill, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Launch Test',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      controls: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Taps recorded: $_buttonTapCount',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          Row(
            children: [
              const Text(
                'Enabled: ',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              CupertinoSwitch(
                value: _buttonsEnabled,
                onChanged: (v) => setState(() => _buttonsEnabled = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. GlassIconButton
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassIconButtonDemo() {
    final shape = _iconButtonSquare
        ? GlassIconButtonShape.roundedSquare
        : GlassIconButtonShape.circle;

    return CatalogCardWrapper(
      title: 'GlassIconButton',
      description:
          'Dedicated icon button with touch glow and squash/stretch physics. Supports circular and rounded-square profiles.',
      parameterTags: const [
        'useOwnLayer',
        'GlassIconButtonShape.circle',
        'GlassIconButtonShape.roundedSquare',
        'size = 44',
      ],
      preview: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassIconButton(
            useOwnLayer: true,
            icon: const Icon(CupertinoIcons.camera, color: Colors.white),
            shape: shape,
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          GlassIconButton(
            useOwnLayer: true,
            icon: const Icon(CupertinoIcons.bookmark, color: Colors.white),
            shape: shape,
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          GlassIconButton(
            useOwnLayer: true,
            icon: const Icon(CupertinoIcons.share, color: Colors.white),
            shape: shape,
            onPressed: () {},
          ),
        ],
      ),
      controls: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Shape: Rounded Square vs Circle',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          CupertinoSwitch(
            value: _iconButtonSquare,
            onChanged: (v) => setState(() => _iconButtonSquare = v),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. GlassChip
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassChipDemo() {
    return CatalogCardWrapper(
      title: 'GlassChip',
      description:
          'Pill-shaped glass chip supporting selection states, leading icons, and dismissal actions with organic touch feedback.',
      parameterTags: const [
        'useOwnLayer',
        'selected: bool',
        'selectedColor',
        'onDeleted',
      ],
      preview: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          GlassChip(
            useOwnLayer: true,
            label: 'Filter: Active',
            selected: _chipSelected1,
            selectedColor: const Color(0xFF2563EB),
            icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 14),
            onTap: () => setState(() => _chipSelected1 = !_chipSelected1),
          ),
          GlassChip(
            useOwnLayer: true,
            label: 'Optics Mode',
            selected: _chipSelected2,
            selectedColor: const Color(0xFF9333EA),
            icon: const Icon(CupertinoIcons.sparkles, size: 14),
            onTap: () => setState(() => _chipSelected2 = !_chipSelected2),
          ),
          if (!_chipDismissed)
            GlassChip(
              useOwnLayer: true,
              label: 'Dismissible Tag',
              onDeleted: () => setState(() => _chipDismissed = true),
              onTap: () {},
            ),
        ],
      ),
      controls: _chipDismissed
          ? Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _chipDismissed = false),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reset Dismissed Chip', style: TextStyle(fontSize: 12)),
              ),
            )
          : null,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. GlassSwitch
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassSwitchDemo() {
    return CatalogCardWrapper(
      title: 'GlassSwitch',
      description:
          'iOS toggle switch featuring spring-based thumb dynamics and Apple\'s signature tactile jump animation.',
      parameterTags: const [
        'useOwnLayer',
        'value: bool',
        'activeColor',
        'enableHaptics = true',
      ],
      preview: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              GlassSwitch(
                useOwnLayer: true,
                value: _switchValue1,
                activeColor: CupertinoColors.systemGreen,
                onChanged: (v) => setState(() => _switchValue1 = v),
              ),
              const SizedBox(height: 6),
              Text(
                'Green (${_switchValue1 ? "ON" : "OFF"})',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
          Column(
            children: [
              GlassSwitch(
                useOwnLayer: true,
                value: _switchValue2,
                activeColor: CupertinoColors.systemIndigo,
                onChanged: (v) => setState(() => _switchValue2 = v),
              ),
              const SizedBox(height: 6),
              Text(
                'Indigo (${_switchValue2 ? "ON" : "OFF"})',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. GlassSlider
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassSliderDemo() {
    return CatalogCardWrapper(
      title: 'GlassSlider',
      description:
          'Glass morphism slider with refractive track, jelly thumb squash/stretch physics, and discrete divisions support.',
      parameterTags: const [
        'useOwnLayer',
        'min / max',
        'divisions',
        'jelly physics thumb',
      ],
      preview: Column(
        children: [
          Row(
            children: [
              const Text('Continuous: ', style: TextStyle(color: Colors.white, fontSize: 12)),
              Text(
                _sliderValueContinuous.toStringAsFixed(2),
                style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GlassSlider(
            useOwnLayer: true,
            value: _sliderValueContinuous,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _sliderValueContinuous = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Discrete (5 steps): ', style: TextStyle(color: Colors.white, fontSize: 12)),
              Text(
                'Step ${_sliderValueDiscrete.toInt()}',
                style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GlassSlider(
            useOwnLayer: true,
            value: _sliderValueDiscrete,
            min: 1.0,
            max: 5.0,
            divisions: 4,
            onChanged: (v) => setState(() => _sliderValueDiscrete = v),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. GlassSegmentedControl
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassSegmentedControlDemo() {
    return CatalogCardWrapper(
      title: 'GlassSegmentedControl',
      description:
          'Segmented control featuring a smoothly sliding glass indicator with organic jelly physics between segment options.',
      parameterTags: const [
        'useOwnLayer',
        'segments: List<GlassSegment>',
        'selectedIndex',
        'animated glass indicator',
      ],
      preview: SizedBox(
        width: 320,
        child: GlassSegmentedControl(
          useOwnLayer: true,
          selectedIndex: _segmentedIndex,
          onSegmentSelected: (index) => setState(() => _segmentedIndex = index),
          segments: const [
            GlassSegment(label: 'Standard'),
            GlassSegment(label: 'Refraction'),
            GlassSegment(label: 'Specular'),
          ],
        ),
      ),
      controls: Center(
        child: Text(
          'Active Selection: Index $_segmentedIndex',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      ),
    );
  }
}
