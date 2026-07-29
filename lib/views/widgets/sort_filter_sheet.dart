import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/notes_provider.dart';

class SortFilterSheet extends StatelessWidget {
  const SortFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context);

    return Padding(
      padding: EdgeInsets.only(
        top: 20.0,
        left: 24.0,
        right: 24.0,
        bottom: 24.0 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Sheet Title
          Text(
            "Sort Notes By",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Sorting options
          RadioGroup<SortOption>(
            groupValue: provider.currentSort,
            onChanged: (SortOption? value) {
              if (value != null) {
                provider.setSortOption(value);
                Navigator.pop(context);
              }
            },
            child: Column(
              children: [
                _buildSortTile(
                  context: context,
                  title: "Newest First",
                  subtitle: "Notes updated recently appear first",
                  icon: Icons.update_rounded,
                  option: SortOption.newest,
                  currentOption: provider.currentSort,
                  onTap: () {
                    provider.setSortOption(SortOption.newest);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _buildSortTile(
                  context: context,
                  title: "Oldest First",
                  subtitle: "Oldest notes appear first",
                  icon: Icons.history_rounded,
                  option: SortOption.oldest,
                  currentOption: provider.currentSort,
                  onTap: () {
                    provider.setSortOption(SortOption.oldest);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8),
                _buildSortTile(
                  context: context,
                  title: "Alphabetical",
                  subtitle: "A-Z sorting based on note title",
                  icon: Icons.sort_by_alpha_rounded,
                  option: SortOption.alphabetical,
                  currentOption: provider.currentSort,
                  onTap: () {
                    provider.setSortOption(SortOption.alphabetical);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required SortOption option,
    required SortOption currentOption,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isSelected = option == currentOption;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withAlpha(80)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withAlpha(100)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Radio<SortOption>(
              value: option,
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
