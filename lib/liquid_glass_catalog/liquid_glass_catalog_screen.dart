import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'catalog_background.dart';
import 'sections/containers_section.dart';
import 'sections/interactive_section.dart';
import 'sections/surfaces_section.dart';

/// Phase 1A: Isolated Liquid Glass Catalog Screen
///
/// This screen is a dedicated technical component catalog for inspecting
/// the basic glass building blocks of `liquid_glass_widgets 1.7.2`.
///
/// It is completely isolated from the Quick Notes production UI.
class LiquidGlassCatalogScreen extends StatefulWidget {
  const LiquidGlassCatalogScreen({super.key});

  @override
  State<LiquidGlassCatalogScreen> createState() =>
      _LiquidGlassCatalogScreenState();
}

class _LiquidGlassCatalogScreenState extends State<LiquidGlassCatalogScreen> {
  CatalogBackgroundMode _backgroundMode = CatalogBackgroundMode.vibrantGradient;
  int _activeCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      body: CatalogBackground(
        mode: _backgroundMode,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildCategoryBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8, bottom: 40),
                  child: _buildActiveCategoryContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Laboratory Header
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117).withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF222634), width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.back, color: Colors.white),
                tooltip: 'Return to QuickNotes',
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liquid Glass Catalog',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Phase 1A — Basic Glass • package v1.7.2',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<CatalogBackgroundMode>(
                icon: const Icon(
                  CupertinoIcons.circle_grid_hex,
                  color: Color(0xFF60A5FA),
                  size: 22,
                ),
                tooltip: 'Change Test Background',
                color: const Color(0xFF1E2230),
                onSelected: (mode) => setState(() => _backgroundMode = mode),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: CatalogBackgroundMode.vibrantGradient,
                    child: Text('Vibrant Gradient', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: CatalogBackgroundMode.geometricShapes,
                    child: Text('Geometric Shapes', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: CatalogBackgroundMode.monochromeGrid,
                    child: Text('Monochrome Grid', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Category Switcher
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryBar() {
    final categories = ['Containers', 'Interactive', 'Surfaces'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117).withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF1E2230), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(categories.length, (index) {
          final isSelected = _activeCategoryIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeCategoryIndex = index),
              child: Container(
                margin: EdgeInsets.only(
                  right: index < categories.length - 1 ? 8 : 0,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF1A1E29),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF262B3A),
                  ),
                ),
                child: Center(
                  child: Text(
                    categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveCategoryContent() {
    switch (_activeCategoryIndex) {
      case 0:
        return const ContainersSection();
      case 1:
        return const InteractiveSection();
      case 2:
      default:
        return const SurfacesSection();
    }
  }
}
