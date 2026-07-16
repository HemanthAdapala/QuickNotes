import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';

enum ExportTemplate { minimalist, academic, creative, meeting }

class ExportService {
  ExportService._privateConstructor();
  static final ExportService instance = ExportService._privateConstructor();

  // Helper to sanitize filename strings
  String _sanitizeFileName(String title) {
    final clean = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return clean.isEmpty ? 'untitled_note' : clean;
  }

  // Find valid public Downloads folder or fallback
  Future<Directory> _getExportDirectory() async {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    
    if (dir == null && Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    }
    
    if (dir == null || !dir.existsSync()) {
      dir = await getApplicationDocumentsDirectory();
    }
    return dir;
  }

  // --- HTML Export Builder ---
  String generateHtml(Note note, ExportTemplate template) {
    final title = note.title.isEmpty ? 'Untitled Note' : note.title;
    final dateStr = note.updatedAt.toLocal().toString().substring(0, 16);
    
    String fontStyle = "font-family: 'Inter', sans-serif;";
    String themeStyle = "";
    
    switch (template) {
      case ExportTemplate.minimalist:
        themeStyle = """
          body { background: #fafafa; color: #2d3748; padding: 40px; }
          .container { max-width: 650px; margin: 0 auto; background: white; padding: 32px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
          h1 { font-size: 28px; margin-bottom: 8px; border-bottom: 2px solid #edf2f7; padding-bottom: 12px; }
          .meta { font-size: 13px; color: #a0aec0; margin-bottom: 24px; }
        """;
        break;
      case ExportTemplate.academic:
        fontStyle = "font-family: 'Georgia', serif;";
        themeStyle = """
          body { background: #fff; color: #111; padding: 50px; line-height: 1.6; }
          .container { max-width: 700px; margin: 0 auto; text-align: justify; }
          h1 { font-size: 26px; font-weight: normal; text-align: center; margin-bottom: 4px; }
          .meta { font-size: 12px; font-style: italic; text-align: center; color: #555; margin-bottom: 40px; border-bottom: 1px double #000; padding-bottom: 16px; }
        """;
        break;
      case ExportTemplate.creative:
        fontStyle = "font-family: 'Trebuchet MS', sans-serif;";
        themeStyle = """
          body { background: #f7fafc; color: #1a202c; padding: 40px; }
          .container { max-width: 650px; margin: 0 auto; background: white; padding: 36px; border-radius: 24px; border: 3px solid #667eea; box-shadow: 0 10px 15px rgba(0,0,0,0.05); position: relative; }
          .container::before { content: ''; position: absolute; top:0; left:0; width:100%; height:8px; background: linear-gradient(90deg, #667eea, #764ba2); border-radius: 20px 20px 0 0; }
          h1 { font-size: 32px; color: #4a5568; margin-top: 10px; margin-bottom: 6px; }
          .meta { font-size: 13px; color: #764ba2; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 24px; }
        """;
        break;
      case ExportTemplate.meeting:
        themeStyle = """
          body { background: #edf2f7; color: #2d3748; padding: 30px; }
          .container { max-width: 700px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
          .meeting-header { background: #2b6cb0; color: white; padding: 20px; border-radius: 8px; margin-bottom: 24px; }
          .meeting-header h1 { margin: 0 0 8px 0; font-size: 26px; }
          .meeting-meta { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 13px; }
          .meta-label { font-weight: bold; opacity: 0.9; }
        """;
        break;
    }

    String contentBodyHtml = "";
    contentBodyHtml += "<p style='white-space: pre-wrap; font-size: 16px; line-height: 1.6;'>${note.content}</p>";

    // Embed Image/Voice attachment metadata references
    if (note.attachments.isNotEmpty) {
      contentBodyHtml += "<div style='margin-top: 32px; border-top: 1px solid #edf2f7; padding-top: 16px;'>";
      contentBodyHtml += "<h3 style='font-size: 14px; color: #718096; margin-bottom: 12px;'>Attachments</h3><div style='display: flex; gap: 12px; flex-wrap: wrap;'>";
      for (var att in note.attachments) {
        final type = att['type'] ?? 'file';
        final path = att['path'] ?? '';
        final name = p.basename(path);
        final icon = type == 'image' ? '🖼️' : '🎵';
        contentBodyHtml += "<div style='background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 8px 12px; font-size: 13px;'><span style='margin-right: 6px;'>$icon</span>$name ($type)</div>";
      }
      contentBodyHtml += "</div></div>";
    }

    String headerBlock = """
      <h1>$title</h1>
      <div class="meta">Category: ${note.category} | Last updated: $dateStr</div>
    """;
    
    if (template == ExportTemplate.meeting) {
      headerBlock = """
        <div class="meeting-header">
          <h1>$title</h1>
          <div class="meeting-meta">
            <div><span class="meta-label">Organized In:</span> ${note.category}</div>
            <div><span class="meta-label">Date/Time:</span> $dateStr</div>
            <div><span class="meta-label">Format:</span> Styled Meeting Minutes</div>
            <div><span class="meta-label">Tags:</span> ${note.tags.join(', ')}</div>
          </div>
        </div>
      """;
    }

    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>$title</title>
      <style>
        * { box-sizing: border-box; }
        html, body { margin: 0; padding: 0; $fontStyle }
        $themeStyle
      </style>
    </head>
    <body>
      <div class="container">
        $headerBlock
        <div class="content">
          $contentBodyHtml
        </div>
      </div>
    </body>
    </html>
    """;
  }

  // --- PDF Export Builder ---
  Future<pw.Document> generatePdf(Note note, ExportTemplate template) async {
    final pdf = pw.Document();
    
    // Choose Fonts based on Template (Academic -> Serif, else Sans-serif)
    final isSerif = template == ExportTemplate.academic;
    final fontNormal = isSerif ? pw.Font.times() : pw.Font.helvetica();
    final fontBold = isSerif ? pw.Font.timesBold() : pw.Font.helveticaBold();
    final fontItalic = isSerif ? pw.Font.timesItalic() : pw.Font.helveticaOblique();

    final title = note.title.isEmpty ? 'Untitled Note' : note.title;
    final dateStr = note.updatedAt.toLocal().toString().substring(0, 16);

    // Styling metrics
    PdfColor primaryColor = PdfColors.black;
    PdfColor textColor = PdfColors.grey900;
    double titleSize = 24;
    pw.Alignment titleAlignment = pw.Alignment.centerLeft;
    
    switch (template) {
      case ExportTemplate.minimalist:
        primaryColor = PdfColors.blueGrey800;
        break;
      case ExportTemplate.academic:
        titleAlignment = pw.Alignment.center;
        titleSize = 22;
        break;
      case ExportTemplate.creative:
        primaryColor = const PdfColor.fromInt(0xff667eea);
        titleSize = 26;
        break;
      case ExportTemplate.meeting:
        primaryColor = const PdfColor.fromInt(0xff2b6cb0);
        break;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: fontNormal,
          bold: fontBold,
          italic: fontItalic,
        ),
        build: (pw.Context context) {
          return [
            // Styled Title & Meta Header
            if (template == ExportTemplate.meeting) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(fontSize: 22, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Workspace: ${note.category}", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                        pw.Text("Date: $dateStr", style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ] else ...[
              pw.Container(
                alignment: titleAlignment,
                child: pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: titleSize, color: primaryColor, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                alignment: titleAlignment,
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
                ),
                child: pw.Text(
                  "Workspace: ${note.category}   |   Last Updated: $dateStr",
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Content body
            pw.Paragraph(
              text: note.content,
              style: pw.TextStyle(fontSize: 13, color: textColor, height: 1.5),
            ),

            // Tags chips
            if (note.tags.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text("Tags: ", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 6),
                  ...note.tags.map((tag) => pw.Container(
                    margin: const pw.EdgeInsets.only(right: 6),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(tag, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  )),
                ],
              ),
            ],

            // Attachments summary
            if (note.attachments.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Text("Attachments Summary", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 8),
              pw.GridView(
                crossAxisCount: 2,
                childAspectRatio: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: note.attachments.map((att) {
                  final path = att['path'] ?? '';
                  final type = att['type'] ?? 'file';
                  final name = p.basename(path);
                  return pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      color: PdfColors.grey50,
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text(type == 'image' ? "[IMG]" : "[AUD]", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(width: 6),
                        pw.Expanded(
                          child: pw.Text(name, style: const pw.TextStyle(fontSize: 9), maxLines: 1, overflow: pw.TextOverflow.clip),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ]
          ];
        },
      ),
    );
    return pdf;
  }

  // --- Markdown Export Builder ---
  String generateMarkdown(Note note) {
    final title = note.title.isEmpty ? 'Untitled Note' : note.title;
    final dateStr = note.updatedAt.toLocal().toString().substring(0, 16);
    
    var md = """# $title

**Workspace:** ${note.category}
**Last Updated:** $dateStr
**Tags:** ${note.tags.join(', ')}

---

""";

    md += note.content;

    if (note.attachments.isNotEmpty) {
      md += "\n\n---\n\n### Attachments\n";
      for (var att in note.attachments) {
        final path = att['path'] ?? '';
        final type = att['type'] ?? 'file';
        final name = p.basename(path);
        if (type == 'image') {
          md += "- ![Image Attachment]($path) ($name)\n";
        } else {
          md += "- [Audio Attachment]($path) ($name)\n";
        }
      }
    }
    return md;
  }

  // --- Export Runner (Save to file & share) ---
  Future<String> exportNote({
    required Note note,
    required ExportTemplate template,
    required String format, // 'pdf', 'html', 'md'
  }) async {
    final dir = await _getExportDirectory();
    final filename = "${_sanitizeFileName(note.title)}.$format";
    final filePath = p.join(dir.path, filename);
    final file = File(filePath);

    if (format == 'pdf') {
      final pdfDoc = await generatePdf(note, template);
      await file.writeAsBytes(await pdfDoc.save());
    } else if (format == 'html') {
      final htmlStr = generateHtml(note, template);
      await file.writeAsString(htmlStr);
    } else {
      final mdStr = generateMarkdown(note);
      await file.writeAsString(mdStr);
    }
    return filePath;
  }

  // --- Share Sheet launcher ---
  Future<void> shareFile(String filePath, String noteTitle) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text: 'Sharing "$noteTitle" from QuickNotes',
      ),
    );
  }
}
