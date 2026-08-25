import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/note.dart';
import '../../services/export_service.dart';

class ExportDialog extends StatefulWidget {
  final Note note;

  const ExportDialog({super.key, required this.note});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  String _selectedFormat = 'pdf'; // 'pdf', 'html', 'md'
  ExportTemplate _selectedTemplate = ExportTemplate.minimalist;
  bool _isExporting = false;

  void _runExport(bool shareImmediately) async {
    setState(() {
      _isExporting = true;
    });

    try {
      final filePath = await ExportService.instance.exportNote(
        note: widget.note,
        template: _selectedTemplate,
        format: _selectedFormat,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Exported successfully to: $filePath"),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: "Share",
              onPressed: () {
                ExportService.instance.shareFile(filePath, widget.note.title);
              },
            ),
          ),
        );

        if (shareImmediately) {
          await ExportService.instance.shareFile(filePath, widget.note.title);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Export & Share",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Format Selection
            Text(
              "Format",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFormatButton(
                    'pdf', 'PDF Document', Icons.picture_as_pdf_rounded),
                const SizedBox(width: 8),
                _buildFormatButton('html', 'HTML Webpage', Icons.html_rounded),
                const SizedBox(width: 8),
                _buildFormatButton('md', 'Markdown File', Icons.code_rounded),
              ],
            ),
            const SizedBox(height: 20),

            // Template Selection (Only if PDF or HTML is selected)
            if (_selectedFormat == 'pdf' || _selectedFormat == 'html') ...[
              Text(
                "Document Template",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _buildTemplateDropdown(),
              const SizedBox(height: 24),
            ],

            if (_isExporting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _runExport(true),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text("Share"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _runExport(false),
                    icon: const Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text("Export"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(String format, String label, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _selectedFormat == format;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFormat = format;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withAlpha(100)
                : theme.colorScheme.surfaceContainerHighest.withAlpha(50),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateDropdown() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ExportTemplate>(
          value: _selectedTemplate,
          isExpanded: true,
          dropdownColor: theme.colorScheme.surface,
          items: const [
            DropdownMenuItem(
              value: ExportTemplate.minimalist,
              child: Text("Minimalist Modern"),
            ),
            DropdownMenuItem(
              value: ExportTemplate.academic,
              child: Text("Academic Journal (Serif)"),
            ),
            DropdownMenuItem(
              value: ExportTemplate.creative,
              child: Text("Creative Gradient Accent"),
            ),
            DropdownMenuItem(
              value: ExportTemplate.meeting,
              child: Text("Meeting Minutes Style"),
            ),
          ],
          onChanged: (ExportTemplate? val) {
            if (val != null) {
              setState(() {
                _selectedTemplate = val;
              });
            }
          },
        ),
      ),
    );
  }
}
