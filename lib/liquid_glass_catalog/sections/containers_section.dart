import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_card_wrapper.dart';

/// Phase 1A Catalog: Containers & Basic Surfaces
class ContainersSection extends StatefulWidget {
  const ContainersSection({super.key});

  @override
  State<ContainersSection> createState() => _ContainersSectionState();
}

class _ContainersSectionState extends State<ContainersSection> {
  // Live control state for GlassContainer
  double _containerBlur = 6.0;
  double _containerThickness = 20.0;
  bool _isOval = false;

  // Selected preset for GlassCard comparison
  int _cardPresetIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildGlassContainerDemo(),
        _buildGlassCardDemo(),
        _buildGlassGroupedSectionDemo(),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. GlassContainer
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassContainerDemo() {
    return CatalogCardWrapper(
      title: 'GlassContainer',
      description:
          'Foundational liquid glass primitive with configurable shape, sizing, and padding. Uses own layer in standalone mode.',
      parameterTags: const [
        'useOwnLayer',
        'settings: LiquidGlassSettings',
        'shape: LiquidShape',
        'padding',
      ],
      preview: GlassContainer(
        useOwnLayer: true,
        width: 260,
        height: 120,
        shape: _isOval
            ? const LiquidOval()
            : const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: LiquidGlassSettings(
          blur: _containerBlur,
          thickness: _containerThickness,
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.cube_box_fill,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                'Blur: ${_containerBlur.toStringAsFixed(1)} | Thick: ${_containerThickness.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Blur: ${_containerBlur.toStringAsFixed(1)}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _containerBlur,
                    min: 0.0,
                    max: 20.0,
                    onChanged: (v) => setState(() => _containerBlur = v),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thickness: ${_containerThickness.toStringAsFixed(1)}',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _containerThickness,
                    min: 5.0,
                    max: 45.0,
                    onChanged: (v) => setState(() => _containerThickness = v),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shape: Oval vs Superellipse',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              CupertinoSwitch(
                value: _isOval,
                onChanged: (v) => setState(() => _isOval = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. GlassCard
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassCardDemo() {
    LiquidGlassSettings activeSettings;
    String presetLabel;

    switch (_cardPresetIndex) {
      case 0:
        activeSettings = const LiquidGlassSettings(blur: 5, thickness: 20);
        presetLabel = 'Default (Blur 5, Thickness 20)';
        break;
      case 1:
        activeSettings = const LiquidGlassSettings(blur: 14, thickness: 35);
        presetLabel = 'Strong (Blur 14, Thickness 35)';
        break;
      case 2:
      default:
        activeSettings = const LiquidGlassSettings(blur: 2, thickness: 8);
        presetLabel = 'Subtle (Blur 2, Thickness 8)';
        break;
    }

    return CatalogCardWrapper(
      title: 'GlassCard',
      description:
          'Specialized glass surface with opinionated iOS card insets (16px) and rounded superellipse corners. Compared across 3 presets.',
      parameterTags: const [
        'useOwnLayer',
        'padding = 16',
        'shape = LiquidRoundedSuperellipse(12)',
      ],
      preview: GlassCard(
        useOwnLayer: true,
        width: 280,
        settings: activeSettings,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.creditcard,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    presetLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'GlassCard encapsulates iOS 26 card metrics with automatic corner smoothing and edge refraction.',
              style: TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      controls: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPresetButton(0, 'Default'),
          _buildPresetButton(1, 'Strong'),
          _buildPresetButton(2, 'Subtle'),
        ],
      ),
    );
  }

  Widget _buildPresetButton(int index, String label) {
    final isSelected = _cardPresetIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _cardPresetIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. GlassGroupedSection
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassGroupedSectionDemo() {
    return const CatalogCardWrapper(
      title: 'GlassGroupedSection + GlassListTile',
      description:
          'Replicates iOS 26 grouped table sections. Automatically injects GlassDividers with intelligent 56px leading indents between adjacent GlassListTiles.',
      parameterTags: [
        'GlassGroupedSection',
        'GlassListTile',
        'GlassDivider (auto-injected)',
      ],
      preview: SizedBox(
        width: 320,
        child: GlassGroupedSection(
          useOwnLayer: true,
          header: Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'HARDWARE CONFIGURATION',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          children: [
            GlassListTile(
              leading: Icon(CupertinoIcons.wifi, color: Colors.white, size: 20),
              title: Text('Wi-Fi 6E', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text('Connected to Laboratory_5G', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11)),
              trailing: Icon(CupertinoIcons.chevron_forward, color: Color(0x66FFFFFF), size: 16),
            ),
            GlassListTile(
              leading: Icon(CupertinoIcons.bluetooth, color: Colors.white, size: 20),
              title: Text('Bluetooth', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text('Active (3 devices)', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11)),
              trailing: Icon(CupertinoIcons.chevron_forward, color: Color(0x66FFFFFF), size: 16),
            ),
            GlassListTile(
              leading: Icon(CupertinoIcons.shield_fill, color: Colors.white, size: 20),
              title: Text('Memory Guard', style: TextStyle(color: Colors.white, fontSize: 14)),
              trailing: Icon(CupertinoIcons.chevron_forward, color: Color(0x66FFFFFF), size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
