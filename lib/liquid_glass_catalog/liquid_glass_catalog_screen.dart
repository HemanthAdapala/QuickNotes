import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'catalog_background.dart';
import 'component_detail_screen.dart';

/// Phase 1A: Minimal Liquid Glass Component Catalog Index
///
/// Functions as a simple technical component index over the single supplied background.
/// Tapping any component opens its dedicated inspection experiment.
class LiquidGlassCatalogScreen extends StatelessWidget {
  const LiquidGlassCatalogScreen({super.key});

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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Buttons ──────────────────────────────────────────
                      _buildCategoryHeader('Buttons'),
                      _buildComponentItem(
                        context,
                        'Glass Button',
                        CatalogComponentType.glassButton,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Icon Button',
                        CatalogComponentType.glassIconButton,
                      ),

                      const SizedBox(height: 24),

                      // ─── Containers ───────────────────────────────────────
                      _buildCategoryHeader('Containers'),
                      _buildComponentItem(
                        context,
                        'Glass Container',
                        CatalogComponentType.glassContainer,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Card',
                        CatalogComponentType.glassCard,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Grouped Section',
                        CatalogComponentType.glassGroupedSection,
                      ),

                      const SizedBox(height: 24),

                      // ─── Controls ─────────────────────────────────────────
                      _buildCategoryHeader('Controls'),
                      _buildComponentItem(
                        context,
                        'Glass Chip',
                        CatalogComponentType.glassChip,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Switch',
                        CatalogComponentType.glassSwitch,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Slider',
                        CatalogComponentType.glassSlider,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Segmented Control',
                        CatalogComponentType.glassSegmentedControl,
                      ),

                      const SizedBox(height: 24),

                      // ─── Surfaces ─────────────────────────────────────────
                      _buildCategoryHeader('Surfaces'),
                      _buildComponentItem(
                        context,
                        'Glass App Bar',
                        CatalogComponentType.glassAppBar,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Tab Bar',
                        CatalogComponentType.glassTabBar,
                      ),
                      _buildComponentItem(
                        context,
                        'Glass Scaffold',
                        CatalogComponentType.glassScaffold,
                      ),
                    ],
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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Return to Settings',
          ),
          const SizedBox(width: 4),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIQUID GLASS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Catalog 1.7.2',
                style: TextStyle(
                  color: Color(0xAAFFFFFF),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildComponentItem(
    BuildContext context,
    String label,
    CatalogComponentType type,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ComponentDetailScreen(componentType: type),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: Color(0x88FFFFFF),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
