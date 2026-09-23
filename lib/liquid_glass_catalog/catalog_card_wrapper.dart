import 'package:flutter/material.dart';

/// A laboratory presentation wrapper for cataloging a component.
///
/// Provides a clear technical header with component API name, purpose description,
/// parameter tags, and a live demonstration area.
class CatalogCardWrapper extends StatelessWidget {
  final String title;
  final String description;
  final List<String> parameterTags;
  final Widget preview;
  final Widget? controls;

  const CatalogCardWrapper({
    super.key,
    required this.title,
    required this.description,
    this.parameterTags = const [],
    required this.preview,
    this.controls,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161922).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2A2E3D),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.science_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (parameterTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: parameterTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2E3D), height: 1),

          // Live Preview Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: preview,
            ),
          ),

          // Live Controls (if any)
          if (controls != null) ...[
            const Divider(color: Color(0xFF2A2E3D), height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF111319),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: controls!,
            ),
          ],
        ],
      ),
    );
  }
}
