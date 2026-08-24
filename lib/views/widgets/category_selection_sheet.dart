import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/notes_provider.dart';
import 'tactile_button.dart';

class CategorySelectionSheet extends StatefulWidget {
  final String currentCategory;
  final ValueChanged<String> onCategorySelected;

  const CategorySelectionSheet({
    super.key,
    required this.currentCategory,
    required this.onCategorySelected,
  });

  @override
  State<CategorySelectionSheet> createState() => _CategorySelectionSheetState();
}

class _CategorySelectionSheetState extends State<CategorySelectionSheet> {
  final TextEditingController _categoryNameController = TextEditingController();

  // Color mappings for default categories
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'personal':
        return const Color(0xFF78C291);
      case 'work':
        return const Color(0xFF4A90E2);
      case 'study':
        return const Color(0xFFA388E8);
      case 'ideas':
        return const Color(0xFFF5D44A);
      case 'important':
        return const Color(0xFFE57373);
      case 'unimportant':
        return const Color(0xFFFF7043);
      case 'uncategorized':
      default:
        return Colors.transparent;
    }
  }

  // Predefined custom category colors rotation
  Color _getCustomCategoryColor(String category, List<String> customList) {
    final defaultColor = _getCategoryColor(category);
    if (defaultColor != Colors.transparent) return defaultColor;

    final palette = [
      const Color(0xFF78C291),
      const Color(0xFF4A90E2),
      const Color(0xFFA388E8),
      const Color(0xFFF5D44A),
      const Color(0xFFE57373),
      const Color(0xFFFF7043),
    ];
    final index = customList.indexOf(category);
    if (index == -1) return palette[0];
    return palette[index % palette.length];
  }

  void _showCreateCategoryDialog(List<String> existingCategories) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF2F2EE),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            "New Category",
            style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          content: TextField(
            controller: _categoryNameController,
            autofocus: true,
            style: GoogleFonts.inter(color: Color(0xFF333333)),
            decoration: InputDecoration(
              labelText: "Category Name",
              labelStyle: GoogleFonts.inter(color: const Color(0xFF8C8987)),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE6E3D2)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF222222), width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _categoryNameController.clear();
                Navigator.pop(context);
              },
              child: Text("Cancel",
                  style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C8987))),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _categoryNameController.text.trim();
                if (name.isNotEmpty) {
                  // If category isn't in existing categories, select it
                  widget.onCategorySelected(name);
                  _categoryNameController.clear();
                  Navigator.pop(context);

                  // Dismiss bottom sheet after a short delay
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF222222),
                foregroundColor: const Color(0xFFF2F2EE),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Create",
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);

    // Dynamic categories list (default categories + any unique custom category used in active notes + current category)
    final Set<String> allCategoriesSet = {
      ...NotesProvider.categories,
      ...notesProvider.allActiveNotes.map((n) => n.category),
      widget.currentCategory,
    };

    final allCategories = allCategoriesSet.toList();

    // Sort default categories first, custom ones after, but keep Uncategorized at the end
    final List<String> gridCategories =
        allCategories.where((c) => c.toLowerCase() != 'uncategorized').toList();

    // Sort custom categories alphabetically
    final List<String> defaultStatic = ['Personal', 'Work', 'Ideas', 'Study'];
    gridCategories.sort((a, b) {
      final aIsDefault = defaultStatic.contains(a);
      final bIsDefault = defaultStatic.contains(b);
      if (aIsDefault && !bIsDefault) return -1;
      if (!aIsDefault && bIsDefault) return 1;
      return a.compareTo(b);
    });

    final customCategoriesOnly =
        gridCategories.where((c) => !defaultStatic.contains(c)).toList();

    // Group gridCategories into rows of 2
    final List<List<String>> rows = [];
    for (var i = 0; i < gridCategories.length; i += 2) {
      if (i + 1 < gridCategories.length) {
        rows.add([gridCategories[i], gridCategories[i + 1]]);
      } else {
        rows.add([gridCategories[i]]);
      }
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 402),
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2EE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 40,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E3D2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header Row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Category",
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Organize this note",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            color: const Color(0xFF8C8987),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TactileButton(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBE9D8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tag Grid List (Scrollable if there are many custom categories)
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    // Layout grid categories as 2-column rows
                    ...rows.map((rowItems) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTagButton(
                                category: rowItems[0],
                                isSelected:
                                    widget.currentCategory == rowItems[0],
                                color: _getCustomCategoryColor(
                                    rowItems[0], customCategoriesOnly),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: rowItems.length > 1
                                  ? _buildTagButton(
                                      category: rowItems[1],
                                      isSelected:
                                          widget.currentCategory == rowItems[1],
                                      color: _getCustomCategoryColor(
                                          rowItems[1], customCategoriesOnly),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    }),
                    // Uncategorized button (spans 2 columns at the bottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildTagButton(
                        category: "Uncategorized",
                        isSelected: widget.currentCategory.toLowerCase() ==
                            'uncategorized',
                        color: Colors.transparent,
                        isFullWidth: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Action Footer
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0x80E6E3D2),
                    width: 1.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              alignment: Alignment.center,
              child: TactileButton(
                onTap: () => _showCreateCategoryDialog(allCategories),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add,
                        size: 18,
                        color: Color(0xFF8C8987),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "+ Create Category",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.05 * 12, // conversion for em spacing
                          color: const Color(0xFF8C8987),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTagButton({
    required String category,
    required bool isSelected,
    required Color color,
    bool isFullWidth = false,
  }) {
    return TactileButton(
      onTap: () {
        widget.onCategorySelected(category);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF222222) : const Color(0xFFF2F2EE),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(
                  color: const Color(0xFFEBE9D8),
                  width: 1.0,
                ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x26000000),
                    offset: Offset(0, 10),
                    blurRadius: 15,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: isSelected
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color == Colors.transparent ? null : color,
                    border: color == Colors.transparent
                        ? Border.all(
                            color: isSelected
                                ? const Color(0xFFF2F2EE)
                                : const Color(0xFF747878),
                            width: 1.5,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isSelected ? const Color(0xFFF2F2EE) : Color(0xFF333333),
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFFF2F2EE),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
