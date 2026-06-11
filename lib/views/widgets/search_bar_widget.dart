import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sort_filter_sheet.dart';

class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onSearchChanged;

  const SearchBarWidget({
    super.key,
    required this.onSearchChanged,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28.0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(120),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onSearchChanged,
        style: GoogleFonts.inter(
          fontSize: 16.0,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: "Search your notes...",
          hintStyle: GoogleFonts.inter(
            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearchChanged("");
                    setState(() {});
                  },
                  tooltip: "Clear search",
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28.0),
                      ),
                    ),
                    builder: (context) => const SortFilterSheet(),
                  );
                },
                tooltip: "Sort & Filter",
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 14.0,
          ),
        ),
      ),
    );
  }
}
