import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../catalog_card_wrapper.dart';

/// Phase 1A Catalog: Surfaces & Structural Components
///
/// NOTE: These entries document the structural and surface primitives provided
/// by liquid_glass_widgets for reference. They are structural catalog entries
/// rather than Quick Notes architectural recommendations.
class SurfacesSection extends StatefulWidget {
  const SurfacesSection({super.key});

  @override
  State<SurfacesSection> createState() => _SurfacesSectionState();
}

class _SurfacesSectionState extends State<SurfacesSection> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildGlassAppBarDemo(),
        _buildGlassTabBarDemo(),
        _buildGlassScaffoldOverview(),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. GlassAppBar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassAppBarDemo() {
    return CatalogCardWrapper(
      title: 'GlassAppBar (Structural)',
      description:
          'Specialized navigation bar implementing ObstructingPreferredSizeWidget. Designed to coordinate with GlassScaffold for large titles and scroll fading.',
      parameterTags: const [
        'GlassAppBar',
        'leading: Widget?',
        'title: Widget?',
        'actions: List<Widget>?',
      ],
      preview: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GlassAppBar(
            title: const Text(
              'Surface Inspector',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: GlassButton(
              useOwnLayer: true,
              icon: const Icon(CupertinoIcons.slider_horizontal_below_rectangle, color: Colors.white, size: 18),
              onTap: () {},
            ),
            actions: [
              GlassButton(
                useOwnLayer: true,
                icon: const Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: 18),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. GlassTabBar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassTabBarDemo() {
    return CatalogCardWrapper(
      title: 'GlassTabBar.bottom (Structural)',
      description:
          'Floating bottom navigation bar mirroring iOS 26 UITabBarController. Features responsive jelly physics indicators and bottom accessory support.',
      parameterTags: const [
        'GlassTabBar.bottom',
        'tabs: List<GlassTab>',
        'selectedIndex: int',
        'onTabSelected',
      ],
      preview: SizedBox(
        height: 70,
        child: Center(
          child: GlassTabBar.bottom(
            tabs: const [
              GlassTab(icon: Icon(CupertinoIcons.cube), label: 'Shapes'),
              GlassTab(icon: Icon(CupertinoIcons.sparkles), label: 'Refraction'),
              GlassTab(icon: Icon(CupertinoIcons.gauge), label: 'Metrics'),
            ],
            selectedIndex: _selectedTabIndex,
            onTabSelected: (index) => setState(() => _selectedTabIndex = index),
          ),
        ),
      ),
      controls: Center(
        child: Text(
          'Active Navigation Pill: Tab $_selectedTabIndex',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. GlassScaffold Architectural Reference
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildGlassScaffoldOverview() {
    return CatalogCardWrapper(
      title: 'GlassScaffold (Full-Screen Coordinator)',
      description:
          'Top-level scaffold primitive that combines GlassPage, GlassScrollEdgeEffect, and z-ordering stack. Manages auto-edge-fades and status bar styling.',
      parameterTags: const [
        'GlassScaffold',
        'appBar: GlassAppBar',
        'bottomBar: GlassTabBar',
        'GlassScrollEdgeEffect',
      ],
      preview: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(CupertinoIcons.layers_alt, color: Color(0xFF38BDF8), size: 18),
                SizedBox(width: 8),
                Text(
                  'Package Glass Pipeline Hierarchy',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPipelineStep('1. GlassScaffold', 'Hosts root GlassPage and background canvas'),
            _buildPipelineStep('2. GlassAppBar', 'Z-ordered above body with safe-area top fading'),
            _buildPipelineStep('3. Body Content', 'Scrollable slivers with GlassScrollEdgeEffect'),
            _buildPipelineStep('4. GlassTabBar', 'Floating bottom pill with automatic content inset'),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineStep(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4, right: 8),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF38BDF8),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, height: 1.4),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  TextSpan(
                    text: detail,
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
