import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'catalog_background.dart';

/// Enum of all basic components in the Liquid Glass catalog.
enum CatalogComponentType {
  glassButton,
  glassIconButton,
  glassContainer,
  glassCard,
  glassGroupedSection,
  glassChip,
  glassSwitch,
  glassSlider,
  glassSegmentedControl,
  glassAppBar,
  glassTabBar,
  glassScaffold,
}

/// A dedicated, minimal demonstration screen for inspecting a single component
/// against the single catalog background.
class ComponentDetailScreen extends StatefulWidget {
  final CatalogComponentType componentType;

  const ComponentDetailScreen({
    super.key,
    required this.componentType,
  });

  @override
  State<ComponentDetailScreen> createState() => _ComponentDetailScreenState();
}

class _ComponentDetailScreenState extends State<ComponentDetailScreen> {
  // State for interactive experiments
  int _buttonTapCount = 0;
  bool _switchVal1 = true;
  bool _switchVal2 = false;
  double _sliderContinuous = 0.6;
  double _sliderDiscrete = 3.0;
  int _segmentedIndex = 0;
  bool _chipSelected1 = true;
  bool _chipSelected2 = false;
  bool _chipDismissed = false;
  double _containerBlur = 6.0;
  double _containerThickness = 20.0;
  int _tabBarIndex = 0;

  String get _title {
    switch (widget.componentType) {
      case CatalogComponentType.glassButton:
        return 'Glass Button';
      case CatalogComponentType.glassIconButton:
        return 'Glass Icon Button';
      case CatalogComponentType.glassContainer:
        return 'Glass Container';
      case CatalogComponentType.glassCard:
        return 'Glass Card';
      case CatalogComponentType.glassGroupedSection:
        return 'Glass Grouped Section';
      case CatalogComponentType.glassChip:
        return 'Glass Chip';
      case CatalogComponentType.glassSwitch:
        return 'Glass Switch';
      case CatalogComponentType.glassSlider:
        return 'Glass Slider';
      case CatalogComponentType.glassSegmentedControl:
        return 'Glass Segmented Control';
      case CatalogComponentType.glassAppBar:
        return 'Glass App Bar';
      case CatalogComponentType.glassTabBar:
        return 'Glass Tab Bar';
      case CatalogComponentType.glassScaffold:
        return 'Glass Scaffold';
    }
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
                    child: _buildComponentContent(),
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
          Text(
            _title,
            style: const TextStyle(
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

  Widget _buildComponentContent() {
    switch (widget.componentType) {
      case CatalogComponentType.glassButton:
        return _buildGlassButtonExperiment();
      case CatalogComponentType.glassIconButton:
        return _buildGlassIconButtonExperiment();
      case CatalogComponentType.glassContainer:
        return _buildGlassContainerExperiment();
      case CatalogComponentType.glassCard:
        return _buildGlassCardExperiment();
      case CatalogComponentType.glassGroupedSection:
        return _buildGlassGroupedSectionExperiment();
      case CatalogComponentType.glassChip:
        return _buildGlassChipExperiment();
      case CatalogComponentType.glassSwitch:
        return _buildGlassSwitchExperiment();
      case CatalogComponentType.glassSlider:
        return _buildGlassSliderExperiment();
      case CatalogComponentType.glassSegmentedControl:
        return _buildGlassSegmentedControlExperiment();
      case CatalogComponentType.glassAppBar:
        return _buildGlassAppBarExperiment();
      case CatalogComponentType.glassTabBar:
        return _buildGlassTabBarExperiment();
      case CatalogComponentType.glassScaffold:
        return _buildGlassScaffoldExperiment();
    }
  }

  // ─── 1. Glass Button ───────────────────────────────────────────────────────
  Widget _buildGlassButtonExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('Default Icon'),
        GlassButton(
          useOwnLayer: true,
          icon: const Icon(CupertinoIcons.heart_fill, color: Colors.white, size: 24),
          onTap: () => setState(() => _buttonTapCount++),
        ),
        const SizedBox(height: 36),
        _buildVariantLabel('Custom Content'),
        GlassButton.custom(
          useOwnLayer: true,
          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
          onTap: () => setState(() => _buttonTapCount++),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.play_fill, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Launch Action',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        Text(
          'Taps: $_buttonTapCount',
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
        ),
      ],
    );
  }

  // ─── 2. Glass Icon Button ──────────────────────────────────────────────────
  Widget _buildGlassIconButtonExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('Circle'),
        GlassIconButton(
          useOwnLayer: true,
          size: 52,
          shape: GlassIconButtonShape.circle,
          icon: const Icon(CupertinoIcons.camera, color: Colors.white, size: 24),
          onPressed: () {},
        ),
        const SizedBox(height: 36),
        _buildVariantLabel('Rounded Square'),
        GlassIconButton(
          useOwnLayer: true,
          size: 52,
          shape: GlassIconButtonShape.roundedSquare,
          icon: const Icon(CupertinoIcons.bookmark, color: Colors.white, size: 24),
          onPressed: () {},
        ),
      ],
    );
  }

  // ─── 3. Glass Container ────────────────────────────────────────────────────
  Widget _buildGlassContainerExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('Superellipse'),
        GlassContainer(
          useOwnLayer: true,
          width: 260,
          height: 120,
          shape: const LiquidRoundedSuperellipse(borderRadius: 20),
          settings: LiquidGlassSettings(
            blur: _containerBlur,
            thickness: _containerThickness,
          ),
          child: const Center(
            child: Text(
              'Glass Container',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildVariantLabel('Oval'),
        GlassContainer(
          useOwnLayer: true,
          width: 220,
          height: 100,
          shape: const LiquidOval(),
          settings: LiquidGlassSettings(
            blur: _containerBlur,
            thickness: _containerThickness,
          ),
          child: const Center(
            child: Text(
              'Oval',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildMinimalSlider(
          label: 'Blur: ${_containerBlur.toStringAsFixed(1)}',
          value: _containerBlur,
          min: 0.0,
          max: 20.0,
          onChanged: (v) => setState(() => _containerBlur = v),
        ),
        _buildMinimalSlider(
          label: 'Thickness: ${_containerThickness.toStringAsFixed(1)}',
          value: _containerThickness,
          min: 5.0,
          max: 45.0,
          onChanged: (v) => setState(() => _containerThickness = v),
        ),
      ],
    );
  }

  // ─── 4. Glass Card ─────────────────────────────────────────────────────────
  Widget _buildGlassCardExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('Default Card (Blur 5, Thickness 20)'),
        const GlassCard(
          useOwnLayer: true,
          width: 280,
          settings: LiquidGlassSettings(blur: 5, thickness: 20),
          child: Text(
            'Default iOS card insets (16px) with corner smoothing and edge refraction.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 28),
        _buildVariantLabel('Subtle (Blur 2, Thickness 8)'),
        const GlassCard(
          useOwnLayer: true,
          width: 280,
          settings: LiquidGlassSettings(blur: 2, thickness: 8),
          child: Text(
            'Subtle frosted treatment with high backdrop visibility.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 28),
        _buildVariantLabel('Strong (Blur 14, Thickness 35)'),
        const GlassCard(
          useOwnLayer: true,
          width: 280,
          settings: LiquidGlassSettings(blur: 14, thickness: 35),
          child: Text(
            'Dense, highly refractive glass surface.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  // ─── 5. Glass Grouped Section ──────────────────────────────────────────────
  Widget _buildGlassGroupedSectionExperiment() {
    return const SizedBox(
      width: 320,
      child: GlassGroupedSection(
        useOwnLayer: true,
        header: Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'DEVICE SETTINGS',
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        children: [
          GlassListTile(
            leading: Icon(CupertinoIcons.wifi, color: Colors.white, size: 20),
            title: Text('Wi-Fi', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Connected', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11)),
            trailing: Icon(CupertinoIcons.chevron_forward, color: Color(0x66FFFFFF), size: 16),
          ),
          GlassListTile(
            leading: Icon(CupertinoIcons.bluetooth, color: Colors.white, size: 20),
            title: Text('Bluetooth', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('On', style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11)),
            trailing: Icon(CupertinoIcons.chevron_forward, color: Color(0x66FFFFFF), size: 16),
          ),
          GlassListTile(
            leading: Icon(CupertinoIcons.shield_fill, color: Colors.white, size: 20),
            title: Text('Security', style: TextStyle(color: Colors.white, fontSize: 14)),
            trailing: Icon(CupertinoIcons.chevron_forward, color: Color(0x66FFFFFF), size: 16),
          ),
        ],
      ),
    );
  }

  // ─── 6. Glass Chip ─────────────────────────────────────────────────────────
  Widget _buildGlassChipExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('Selectable Chips'),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            GlassChip(
              useOwnLayer: true,
              label: 'Selected',
              selected: _chipSelected1,
              selectedColor: const Color(0xFF2563EB),
              icon: const Icon(CupertinoIcons.check_mark, size: 14),
              onTap: () => setState(() => _chipSelected1 = !_chipSelected1),
            ),
            GlassChip(
              useOwnLayer: true,
              label: 'Accent',
              selected: _chipSelected2,
              selectedColor: const Color(0xFF9333EA),
              icon: const Icon(CupertinoIcons.sparkles, size: 14),
              onTap: () => setState(() => _chipSelected2 = !_chipSelected2),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildVariantLabel('Dismissible Chip'),
        if (!_chipDismissed)
          GlassChip(
            useOwnLayer: true,
            label: 'Tap X to dismiss',
            onDeleted: () => setState(() => _chipDismissed = true),
            onTap: () {},
          )
        else
          TextButton.icon(
            onPressed: () => setState(() => _chipDismissed = false),
            icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
            label: const Text('Reset Chip', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }

  // ─── 7. Glass Switch ───────────────────────────────────────────────────────
  Widget _buildGlassSwitchExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('System Green'),
        GlassSwitch(
          useOwnLayer: true,
          value: _switchVal1,
          activeColor: CupertinoColors.systemGreen,
          onChanged: (v) => setState(() => _switchVal1 = v),
        ),
        const SizedBox(height: 32),
        _buildVariantLabel('System Indigo'),
        GlassSwitch(
          useOwnLayer: true,
          value: _switchVal2,
          activeColor: CupertinoColors.systemIndigo,
          onChanged: (v) => setState(() => _switchVal2 = v),
        ),
      ],
    );
  }

  // ─── 8. Glass Slider ───────────────────────────────────────────────────────
  Widget _buildGlassSliderExperiment() {
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVariantLabel('Continuous (${_sliderContinuous.toStringAsFixed(2)})'),
          GlassSlider(
            useOwnLayer: true,
            value: _sliderContinuous,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => setState(() => _sliderContinuous = v),
          ),
          const SizedBox(height: 36),
          _buildVariantLabel('Discrete (Step ${_sliderDiscrete.toInt()})'),
          GlassSlider(
            useOwnLayer: true,
            value: _sliderDiscrete,
            min: 1.0,
            max: 5.0,
            divisions: 4,
            onChanged: (v) => setState(() => _sliderDiscrete = v),
          ),
        ],
      ),
    );
  }

  // ─── 9. Glass Segmented Control ────────────────────────────────────────────
  Widget _buildGlassSegmentedControlExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('3-Segment Switch'),
        SizedBox(
          width: 300,
          child: GlassSegmentedControl(
            useOwnLayer: true,
            selectedIndex: _segmentedIndex,
            onSegmentSelected: (index) => setState(() => _segmentedIndex = index),
            segments: const [
              GlassSegment(label: 'Day'),
              GlassSegment(label: 'Week'),
              GlassSegment(label: 'Month'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Selected: Index $_segmentedIndex',
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
        ),
      ],
    );
  }

  // ─── 10. Glass App Bar ─────────────────────────────────────────────────────
  Widget _buildGlassAppBarExperiment() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GlassAppBar(
          title: const Text(
            'Navigation Title',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          leading: GlassButton(
            useOwnLayer: true,
            icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 18),
            onTap: () {},
          ),
          actions: [
            GlassButton(
              useOwnLayer: true,
              icon: const Icon(CupertinoIcons.ellipsis, color: Colors.white, size: 18),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  // ─── 11. Glass Tab Bar ─────────────────────────────────────────────────────
  Widget _buildGlassTabBarExperiment() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVariantLabel('Floating Bottom Pill'),
        SizedBox(
          height: 70,
          child: Center(
            child: GlassTabBar.bottom(
              tabs: const [
                GlassTab(icon: Icon(CupertinoIcons.square_grid_2x2), label: 'Browse'),
                GlassTab(icon: Icon(CupertinoIcons.heart), label: 'Favorites'),
                GlassTab(icon: Icon(CupertinoIcons.gear), label: 'Settings'),
              ],
              selectedIndex: _tabBarIndex,
              onTabSelected: (i) => setState(() => _tabBarIndex = i),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Active Tab: $_tabBarIndex',
          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
        ),
      ],
    );
  }

  // ─── 12. Glass Scaffold ────────────────────────────────────────────────────
  Widget _buildGlassScaffoldExperiment() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GlassScaffold Architecture',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'In liquid_glass_widgets, GlassScaffold coordinates the full-screen glass pipeline:\n\n'
            '• GlassPage: Sets root rendering context & status bar appearance\n'
            '• GlassAppBar: Top pinned surface with auto-edge-fades\n'
            '• Body: Main scroll content wrapped in GlassScrollEdgeEffect\n'
            '• GlassTabBar: Bottom floating pill with safe-area auto-insets',
            style: TextStyle(color: Color(0xEEFFFFFF), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMinimalSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 2,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
