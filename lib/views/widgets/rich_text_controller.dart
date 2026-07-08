import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fullscreen_image_viewer.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Style {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final String heading; // 'normal', 'h1', 'h2', 'h3'
  final Color? color;
  final Color? highlight;
  final TextAlign align;
  final String listType; // 'normal', 'bullet', 'number', 'checkbox'
  final bool checked;
  final String? imageUrl;
  final double? imageWidth;
  final double? imageHeight;
  final String? imageCaption;

  const Style({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.heading = 'normal',
    this.color,
    this.highlight,
    this.align = TextAlign.left,
    this.listType = 'normal',
    this.checked = false,
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    this.imageCaption,
  });

  Style copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? heading,
    Color? color,
    Color? highlight,
    TextAlign? align,
    String? listType,
    bool? checked,
    String? imageUrl,
    double? imageWidth,
    double? imageHeight,
    String? imageCaption,
    bool clearColor = false,
    bool clearHighlight = false,
    bool clearImage = false,
    bool clearCaption = false,
  }) {
    return Style(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      heading: heading ?? this.heading,
      color: clearColor ? null : (color ?? this.color),
      highlight: clearHighlight ? null : (highlight ?? this.highlight),
      align: align ?? this.align,
      listType: listType ?? this.listType,
      checked: checked ?? this.checked,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      imageWidth: clearImage ? null : (imageWidth ?? this.imageWidth),
      imageHeight: clearImage ? null : (imageHeight ?? this.imageHeight),
      imageCaption: clearImage || clearCaption
          ? null
          : (imageCaption ?? this.imageCaption),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Style &&
        other.bold == bold &&
        other.italic == italic &&
        other.underline == underline &&
        other.strikethrough == strikethrough &&
        other.heading == heading &&
        other.color == color &&
        other.highlight == highlight &&
        other.align == align &&
        other.listType == listType &&
        other.checked == checked &&
        other.imageUrl == imageUrl &&
        other.imageWidth == imageWidth &&
        other.imageHeight == imageHeight &&
        other.imageCaption == imageCaption;
  }

  @override
  int get hashCode => Object.hash(
        bold,
        italic,
        underline,
        strikethrough,
        heading,
        color,
        highlight,
        align,
        listType,
        checked,
        imageUrl,
        imageWidth,
        imageHeight,
        imageCaption,
      );
}

class StyledChar {
  final String char;
  final Style style;

  const StyledChar({required this.char, required this.style});
}

class LineRange {
  final int start;
  final int end;

  const LineRange(this.start, this.end);
}

class InteractiveCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;

  const InteractiveCheckbox({
    super.key,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8.0, right: 8.0, left: 4.0),
        width: 10,
        height: 10,
        decoration: checked
            ? const BoxDecoration(color: Color(0xFF222222))
            : BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
        child: checked
            ? Center(
                child: SvgPicture.asset(
                  'assets/icons/vector_check.svg',
                  width: 6,
                  height: 6,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              )
            : null,
      ),
    );
  }
}

class ResizableImageWidget extends StatefulWidget {
  final String imagePath;
  final double? initialWidth;
  final String? caption;
  final int index;
  final Function(double width, String? caption) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback? onReplace;
  final bool isStacked;
  final int? stackImageIndex;

  const ResizableImageWidget({
    super.key,
    required this.imagePath,
    required this.initialWidth,
    required this.caption,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
    this.onReplace,
    this.isStacked = false,
    this.stackImageIndex,
  });

  @override
  State<ResizableImageWidget> createState() => _ResizableImageWidgetState();
}

class _ResizableImageWidgetState extends State<ResizableImageWidget>
    with SingleTickerProviderStateMixin {
  double? _width;
  bool _showControls = false;
  late TextEditingController _captionController;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
    _captionController = TextEditingController(text: widget.caption ?? '');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant ResizableImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWidth != widget.initialWidth) {
      setState(() {
        _width = widget.initialWidth;
      });
    }
    if (oldWidget.caption != widget.caption &&
        widget.caption != _captionController.text) {
      _captionController.text = widget.caption ?? '';
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _triggerDelete() async {
    setState(() {
      _isDeleting = true;
    });
    await _animController.reverse();
    widget.onDelete();
  }

  Widget _buildToolbarActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ThemeData theme,
    Color? color,
  }) {
    final textColor = color ?? theme.colorScheme.primary;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: textColor),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor:
            (color ?? theme.colorScheme.primary).withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildResizeHandle(ThemeData theme) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Center(
        child: Icon(Icons.drag_handle_rounded, size: 10, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFile = !widget.imagePath.startsWith('http://') &&
        !widget.imagePath.startsWith('https://');

    final double screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = (screenWidth - 48.0).clamp(100.0, 720.0);
    final double currentWidth = widget.isStacked
        ? double.infinity
        : (_width ?? maxWidth).clamp(150.0, maxWidth);
    final double currentHeight = widget.isStacked ? 180.0 : currentWidth * 0.75;

    int? cacheWidth;
    if (!widget.isStacked) {
      cacheWidth = currentWidth.toInt();
    } else {
      cacheWidth = 400;
    }

    ImageProvider imageProvider;
    if (isFile) {
      String cleanPath = widget.imagePath;
      if (cleanPath.startsWith('file://')) {
        cleanPath = cleanPath.substring(7);
      }
      if (cleanPath.startsWith('/') &&
          cleanPath.length > 2 &&
          cleanPath[2] == ':') {
        cleanPath = cleanPath.substring(1);
      }
      imageProvider = ResizeImage(
        FileImage(File(cleanPath)),
        width: cacheWidth,
      );
    } else {
      imageProvider = ResizeImage(
        NetworkImage(widget.imagePath),
        width: cacheWidth,
      );
    }

    final heroTag =
        'inline-image-${widget.imagePath}-${widget.index}-${widget.stackImageIndex ?? -1}';

    String? displayCaption = widget.caption;
    if (displayCaption != null && displayCaption.isNotEmpty) {
      if (!displayCaption.startsWith('📍')) {
        displayCaption = '📍 $displayCaption';
      }
    }

    Widget imageContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
          },
          onDoubleTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                barrierDismissible: true,
                pageBuilder: (context, _, __) => FullscreenImageViewer(
                  imagePath: widget.imagePath,
                  heroTag: heroTag,
                ),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Hero(
                tag: heroTag,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    border: _showControls
                        ? Border.all(
                            color: theme.colorScheme.primary, width: 2.0)
                        : Border.all(color: Colors.transparent, width: 2.0),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _showControls
                        ? [
                            BoxShadow(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.15),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ]
                        : null,
                  ),
                  constraints: widget.isStacked
                      ? const BoxConstraints.tightFor(height: 180.0)
                      : BoxConstraints(maxWidth: maxWidth),
                  width: widget.isStacked ? double.infinity : currentWidth,
                  height: widget.isStacked ? 180.0 : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image(
                      image: imageProvider,
                      width: widget.isStacked ? double.infinity : currentWidth,
                      height: widget.isStacked ? 180.0 : null,
                      fit: widget.isStacked ? BoxFit.cover : BoxFit.contain,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) {
                          return child;
                        }
                        return AnimatedCrossFade(
                          firstChild: Container(
                            width: widget.isStacked
                                ? double.infinity
                                : currentWidth,
                            height: currentHeight,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          secondChild: child,
                          crossFadeState: frame == null
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 300),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: widget.isStacked ? double.infinity : 200,
                          height: 150,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined,
                                  size: 40, color: Colors.grey),
                              SizedBox(height: 4),
                              Text("Error loading image",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_showControls && !widget.isStacked) ...[
                // Left resize handle
                Positioned(
                  left: -10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            _width = (currentWidth - details.delta.dx)
                                .clamp(150.0, maxWidth);
                          });
                          widget.onUpdate(
                              _width!,
                              _captionController.text.trim().isEmpty
                                  ? null
                                  : _captionController.text.trim());
                        },
                        child: _buildResizeHandle(theme),
                      ),
                    ),
                  ),
                ),
                // Right resize handle
                Positioned(
                  right: -10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            _width = (currentWidth + details.delta.dx)
                                .clamp(150.0, maxWidth);
                          });
                          widget.onUpdate(
                              _width!,
                              _captionController.text.trim().isEmpty
                                  ? null
                                  : _captionController.text.trim());
                        },
                        child: _buildResizeHandle(theme),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (displayCaption != null &&
            displayCaption.isNotEmpty &&
            !_showControls)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 4.0),
            child: Text(
              displayCaption,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        if (_showControls) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onReplace != null)
                _buildToolbarActionButton(
                  icon: Icons.sync_rounded,
                  label: "Replace",
                  onPressed: widget.onReplace!,
                  theme: theme,
                ),
              _buildToolbarActionButton(
                icon: Icons.fullscreen_rounded,
                label: "Fullscreen",
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      barrierDismissible: true,
                      pageBuilder: (context, _, __) => FullscreenImageViewer(
                        imagePath: widget.imagePath,
                        heroTag: heroTag,
                      ),
                    ),
                  );
                },
                theme: theme,
              ),
              _buildToolbarActionButton(
                icon: Icons.delete_outline_rounded,
                label: "Delete",
                color: theme.colorScheme.error,
                onPressed: _triggerDelete,
                theme: theme,
              ),
            ],
          ),
          if (!widget.isStacked) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: currentWidth,
              child: TextField(
                controller: _captionController,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Add optional caption (e.g. 📍 Sunset)...",
                  hintStyle: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
                onChanged: (val) {
                  widget.onUpdate(_width ?? currentWidth,
                      val.trim().isEmpty ? null : val.trim());
                },
              ),
            ),
          ],
        ]
      ],
    );

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: LongPressDraggable<Map<String, dynamic>>(
        data: {
          'oldIndex': widget.index,
          'stackImageIndex': widget.stackImageIndex,
          'imagePath': widget.imagePath,
        },
        onDragStarted: () =>
            print('DRAG_DEBUG: Drag started for ${widget.imagePath}'),
        onDragCompleted: () =>
            print('DRAG_DEBUG: Drag completed for ${widget.imagePath}'),
        onDraggableCanceled: (velocity, offset) =>
            print('DRAG_DEBUG: Drag canceled for ${widget.imagePath}'),
        onDragEnd: (details) =>
            print('DRAG_DEBUG: Drag ended for ${widget.imagePath}'),
        maxSimultaneousDrags: _showControls || _isDeleting ? 0 : 1,
        feedback: DragFeedbackImage(
          imageProvider: imageProvider,
          width: widget.isStacked ? (screenWidth - 48.0) / 2 : currentWidth,
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: IgnorePointer(
            child: SizedBox(
              width: widget.isStacked ? (screenWidth - 48.0) / 2 : currentWidth,
              height: widget.isStacked ? 180 : 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        child: imageContent,
      ),
    );
  }
}

class DragFeedbackImage extends StatefulWidget {
  final ImageProvider imageProvider;
  final double width;
  const DragFeedbackImage(
      {super.key, required this.imageProvider, required this.width});

  @override
  State<DragFeedbackImage> createState() => _DragFeedbackImageState();
}

class _DragFeedbackImageState extends State<DragFeedbackImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          elevation: 12.0,
          borderRadius: BorderRadius.circular(12),
          shadowColor: Colors.black54,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: widget.imageProvider,
              width: widget.width,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class RichTextEditingController extends TextEditingController {
  List<StyledChar> styledChars = [];
  Style currentActiveStyle = const Style();
  VoidCallback? onStyleChanged;
  void Function(int index)? onReplaceImage;

  RichTextEditingController({String? markdown}) {
    if (markdown != null && markdown.isNotEmpty) {
      styledChars = parseMarkdownToStyledChars(markdown);
      super.text = _getTextOnly();
    }
  }

  String _getTextOnly() {
    return styledChars.map((sc) => sc.char).join();
  }

  void setMarkdown(String markdown) {
    styledChars = parseMarkdownToStyledChars(markdown);
    value = TextEditingValue(
      text: _getTextOnly(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  set text(String newText) {
    // Setting text directly replaces the whole document with normal style
    styledChars = newText
        .split('')
        .map((char) => StyledChar(char: char, style: const Style()))
        .toList();
    super.text = newText;
  }

  // Helper to check if style has an attribute
  bool _hasAttribute(Style style, String attribute, dynamic value) {
    switch (attribute) {
      case 'bold':
        return style.bold;
      case 'italic':
        return style.italic;
      case 'underline':
        return style.underline;
      case 'strikethrough':
        return style.strikethrough;
      case 'h1':
        return style.heading == 'h1';
      case 'h2':
        return style.heading == 'h2';
      case 'h3':
        return style.heading == 'h3';
      case 'bullet':
        return style.listType == 'bullet';
      case 'number':
        return style.listType == 'number';
      case 'checkbox':
        return style.listType == 'checkbox';
      case 'color':
        return style.color == value;
      case 'highlight':
        return style.highlight == value;
      default:
        return false;
    }
  }

  // Helper to toggle attribute
  Style _toggleAttribute(Style style, String attribute, dynamic value) {
    switch (attribute) {
      case 'bold':
        return style.copyWith(bold: !style.bold);
      case 'italic':
        return style.copyWith(italic: !style.italic);
      case 'underline':
        return style.copyWith(underline: !style.underline);
      case 'strikethrough':
        return style.copyWith(strikethrough: !style.strikethrough);
      case 'color':
        return style.copyWith(
            color: style.color == value ? null : value,
            clearColor: style.color == value);
      case 'highlight':
        return style.copyWith(
            highlight: style.highlight == value ? null : value,
            clearHighlight: style.highlight == value);
      default:
        return style;
    }
  }

  Style _setAttribute(
      Style style, String attribute, bool enable, dynamic value) {
    switch (attribute) {
      case 'bold':
        return style.copyWith(bold: enable);
      case 'italic':
        return style.copyWith(italic: enable);
      case 'underline':
        return style.copyWith(underline: enable);
      case 'strikethrough':
        return style.copyWith(strikethrough: enable);
      case 'color':
        return enable
            ? style.copyWith(color: value)
            : style.copyWith(clearColor: true);
      case 'highlight':
        return enable
            ? style.copyWith(highlight: value)
            : style.copyWith(clearHighlight: true);
      default:
        return style;
    }
  }

  void toggleStyleAttribute(String attribute, {dynamic value}) {
    final sel = selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      // Toggle for next character typed
      currentActiveStyle =
          _toggleAttribute(currentActiveStyle, attribute, value);
      if (onStyleChanged != null) onStyleChanged!();
    } else {
      // Check if all characters in selection have this attribute
      bool allHave = true;
      for (int i = sel.start; i < sel.end; i++) {
        if (i >= 0 && i < styledChars.length) {
          if (!_hasAttribute(styledChars[i].style, attribute, value)) {
            allHave = false;
            break;
          }
        }
      }

      // Toggle attribute
      final enable = !allHave;
      for (int i = sel.start; i < sel.end; i++) {
        if (i >= 0 && i < styledChars.length) {
          styledChars[i] = StyledChar(
            char: styledChars[i].char,
            style:
                _setAttribute(styledChars[i].style, attribute, enable, value),
          );
        }
      }
      notifyListeners();
    }
  }

  List<LineRange> getOverlappingLineRanges(TextSelection sel) {
    final List<LineRange> ranges = [];
    final textStr = text;
    int start = 0;

    while (start <= textStr.length) {
      int end = textStr.indexOf('\n', start);
      if (end == -1) {
        end = textStr.length;
      }

      final selStart = sel.start;
      final selEnd = sel.end;

      bool overlap = false;
      if (selStart == selEnd) {
        overlap = (selStart >= start && selStart <= end);
      } else {
        final int maxStart = selStart > start ? selStart : start;
        final int minEnd = selEnd < end ? selEnd : end;
        overlap = maxStart <= minEnd;
      }

      if (overlap) {
        ranges.add(LineRange(start, end));
      }

      if (end == textStr.length) break;
      start = end + 1;
    }
    return ranges;
  }

  void toggleParagraphStyle(String styleName) {
    final oldSel = selection;
    if (!oldSel.isValid) return;

    final lines = getOverlappingLineRanges(oldSel);
    if (lines.isEmpty) return;

    List<StyledChar> newChars = List.from(styledChars);
    int selectionStartShift = 0;
    int selectionEndShift = 0;

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final lineStart = line.start;

      final existingStyle = lineStart < newChars.length
          ? newChars[lineStart].style
          : const Style();

      if (styleName == 'bullet' ||
          styleName == 'checkbox' ||
          styleName == 'number' ||
          styleName == 'quote') {
        bool hasBullet =
            lineStart < newChars.length && newChars[lineStart].char == '•';
        bool hasCheckbox = lineStart < newChars.length &&
            (newChars[lineStart].char == '\u2610' ||
                newChars[lineStart].char == '\u2611');
        bool hasQuote =
            lineStart < newChars.length && newChars[lineStart].char == '›';
        bool hasNumber =
            lineStart < newChars.length && newChars[lineStart].char == '\u2008';

        // Remove existing prefix if any
        if (hasBullet || hasCheckbox || hasQuote || hasNumber) {
          newChars.removeAt(lineStart);
          if (oldSel.start > lineStart) selectionStartShift--;
          if (oldSel.end > lineStart) selectionEndShift--;
        }

        String newListType = 'normal';
        String prefixChar = '';

        if (styleName == 'bullet' && existingStyle.listType != 'bullet') {
          newListType = 'bullet';
          prefixChar = '•';
        } else if (styleName == 'checkbox' &&
            existingStyle.listType != 'checkbox') {
          newListType = 'checkbox';
          prefixChar = '\u2610';
        } else if (styleName == 'quote' && existingStyle.listType != 'quote') {
          newListType = 'quote';
          prefixChar = '›';
        } else if (styleName == 'number' && existingStyle.listType != 'number') {
          newListType = 'number';
          prefixChar = '\u2008';
        }

        if (prefixChar.isNotEmpty) {
          final newStyle =
              existingStyle.copyWith(listType: newListType, checked: false);
          newChars.insert(
              lineStart, StyledChar(char: prefixChar, style: newStyle));
          if (oldSel.start > lineStart) selectionStartShift++;
          if (oldSel.end > lineStart) selectionEndShift++;
        }

        // Apply updated list type styles to the rest of the line characters
        int currentLineEnd = lineStart;
        while (currentLineEnd < newChars.length &&
            newChars[currentLineEnd].char != '\n') {
          currentLineEnd++;
        }

        for (int j = lineStart; j <= currentLineEnd; j++) {
          if (j < newChars.length) {
            newChars[j] = StyledChar(
              char: newChars[j].char,
              style: newChars[j].style.copyWith(
                  listType: newListType, checked: false, strikethrough: false),
            );
          }
        }
      } else if (styleName == 'h1' || styleName == 'h2' || styleName == 'h3') {
        final targetHeading =
            existingStyle.heading == styleName ? 'normal' : styleName;

        int currentLineEnd = lineStart;
        while (currentLineEnd < newChars.length &&
            newChars[currentLineEnd].char != '\n') {
          currentLineEnd++;
        }

        for (int j = lineStart; j <= currentLineEnd; j++) {
          if (j < newChars.length) {
            newChars[j] = StyledChar(
              char: newChars[j].char,
              style: newChars[j].style.copyWith(heading: targetHeading),
            );
          }
        }
      } else if (styleName.startsWith('align-')) {
        TextAlign targetAlign = TextAlign.left;
        if (styleName == 'align-center') {
          targetAlign = TextAlign.center;
        } else if (styleName == 'align-right')
          targetAlign = TextAlign.right;
        else if (styleName == 'align-justify') targetAlign = TextAlign.justify;

        if (existingStyle.align == targetAlign) {
          targetAlign = TextAlign.left;
        }

        int currentLineEnd = lineStart;
        while (currentLineEnd < newChars.length &&
            newChars[currentLineEnd].char != '\n') {
          currentLineEnd++;
        }

        for (int j = lineStart; j <= currentLineEnd; j++) {
          if (j < newChars.length) {
            newChars[j] = StyledChar(
              char: newChars[j].char,
              style: newChars[j].style.copyWith(align: targetAlign),
            );
          }
        }
      }
    }

    styledChars = newChars;
    final newTextStr = _getTextOnly();

    final newSelStart =
        (oldSel.start + selectionStartShift).clamp(0, newTextStr.length);
    final newSelEnd =
        (oldSel.end + selectionEndShift).clamp(0, newTextStr.length);

    value = TextEditingValue(
      text: newTextStr,
      selection:
          TextSelection(baseOffset: newSelStart, extentOffset: newSelEnd),
    );
    notifyListeners();
  }

  void insertImage(String path) {
    final sel = selection;
    final textStr = text;
    final List<StyledChar> newChars = List.from(styledChars);

    int cursor = sel.isValid ? sel.start : textStr.length;
    cursor = cursor.clamp(0, textStr.length);

    // Insert leading newline if not at start of line
    if (cursor > 0 && newChars[cursor - 1].char != '\n') {
      newChars.insert(cursor, StyledChar(char: '\n', style: const Style()));
      cursor++;
    }

    final imgStyle = Style(imageUrl: path, imageWidth: 300.0);
    newChars.insert(cursor, StyledChar(char: '\uFFFC', style: imgStyle));
    cursor++;

    // Always insert a trailing newline after the image to make it separate
    newChars.insert(cursor, StyledChar(char: '\n', style: const Style()));
    cursor++;

    styledChars = newChars;
    final newTextStr = _getTextOnly();

    value = TextEditingValue(
      text: newTextStr,
      selection: TextSelection.collapsed(offset: cursor),
    );
    notifyListeners();
  }

  void toggleChecklistState(int index) {
    if (index >= 0 && index < styledChars.length) {
      final char = styledChars[index].char;
      if (char == '\u2610' || char == '\u2611') {
        final newChar = char == '\u2610' ? '\u2611' : '\u2610';
        final newChecked = char == '\u2610';

        int lineStart = index;
        while (lineStart > 0 && styledChars[lineStart - 1].char != '\n') {
          lineStart--;
        }
        int lineEnd = index;
        while (
            lineEnd < styledChars.length && styledChars[lineEnd].char != '\n') {
          lineEnd++;
        }

        List<StyledChar> newChars = List.from(styledChars);
        newChars[index] = StyledChar(
          char: newChar,
          style: styledChars[index].style.copyWith(checked: newChecked),
        );

        // Apply line-through strikethrough to the text of the checklist line when checked
        for (int j = lineStart; j < lineEnd; j++) {
          if (j < newChars.length && j != index) {
            newChars[j] = StyledChar(
              char: newChars[j].char,
              style: newChars[j].style.copyWith(
                    strikethrough: newChecked,
                    checked: newChecked,
                  ),
            );
          }
        }

        styledChars = newChars;
        final newTextStr = _getTextOnly();
        value = TextEditingValue(
          text: newTextStr,
          selection: selection,
        );
        notifyListeners();
      }
    }
  }

  @override
  set value(TextEditingValue newValue) {
    var finalValue = newValue;
    final oldText = text;
    var newText = newValue.text;

    if (oldText != newText && _getTextOnly() != newText) {
      int prefixLen = 0;
      while (prefixLen < oldText.length &&
          prefixLen < newText.length &&
          oldText.codeUnitAt(prefixLen) == newText.codeUnitAt(prefixLen)) {
        prefixLen++;
      }

      int suffixLen = 0;
      while (suffixLen < oldText.length - prefixLen &&
          suffixLen < newText.length - prefixLen &&
          oldText.codeUnitAt(oldText.length - 1 - suffixLen) ==
              newText.codeUnitAt(newText.length - 1 - suffixLen)) {
        suffixLen++;
      }

      final int diffStart = prefixLen;
      final int diffEndOld = oldText.length - suffixLen;
      var diffEndNew = newText.length - suffixLen;

      List<StyledChar> newChars = List.from(styledChars);
      if (diffEndOld > diffStart) {
        newChars.removeRange(diffStart, diffEndOld);
      }

      Style baseStyle = currentActiveStyle;
      if (diffStart > 0 && diffStart - 1 < styledChars.length) {
        baseStyle = styledChars[diffStart - 1].style.copyWith(
              bold: currentActiveStyle.bold,
              italic: currentActiveStyle.italic,
              underline: currentActiveStyle.underline,
              strikethrough: currentActiveStyle.strikethrough,
              color: currentActiveStyle.color,
              highlight: currentActiveStyle.highlight,
              clearColor: currentActiveStyle.color == null,
              clearHighlight: currentActiveStyle.highlight == null,
            );
      }

      final bool isNewlineInsert =
          (diffEndNew - diffStart == 1) && newText[diffStart] == '\n';

      final List<StyledChar> insertedStyledChars = [];
      if (isNewlineInsert) {
        insertedStyledChars.add(StyledChar(char: '\n', style: baseStyle));

        if (baseStyle.listType == 'bullet') {
          insertedStyledChars.add(StyledChar(char: '•', style: baseStyle));
          newText =
              '${newText.substring(0, diffStart + 1)}•${newText.substring(diffStart + 1)}';
          diffEndNew++;

          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
                offset: newValue.selection.baseOffset + 1),
          );
        } else if (baseStyle.listType == 'checkbox') {
          final checkboxStyle = baseStyle.copyWith(checked: false);
          insertedStyledChars
              .add(StyledChar(char: '\u2610', style: checkboxStyle));
          newText =
              '${newText.substring(0, diffStart + 1)}\u2610${newText.substring(diffStart + 1)}';
          diffEndNew++;

          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
                offset: newValue.selection.baseOffset + 1),
          );
        } else if (baseStyle.listType == 'number') {
          insertedStyledChars.add(StyledChar(char: '\u2008', style: baseStyle));
          newText =
              '${newText.substring(0, diffStart + 1)}\u2008${newText.substring(diffStart + 1)}';
          diffEndNew++;

          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
                offset: newValue.selection.baseOffset + 1),
          );
        } else if (baseStyle.listType == 'quote') {
          insertedStyledChars.add(StyledChar(char: '›', style: baseStyle));
          newText =
              '${newText.substring(0, diffStart + 1)}›${newText.substring(diffStart + 1)}';
          diffEndNew++;

          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
                offset: newValue.selection.baseOffset + 1),
          );
        } else {
          baseStyle = baseStyle.copyWith(heading: 'normal');
        }
      } else {
        for (int i = diffStart; i < diffEndNew; i++) {
          insertedStyledChars
              .add(StyledChar(char: newText[i], style: baseStyle));
        }
      }

      if (insertedStyledChars.isNotEmpty) {
        newChars.insertAll(diffStart, insertedStyledChars);
      }

      styledChars = newChars;
    }

    super.value = finalValue;

    // Update active toolbar style state to match character style at cursor when collapsed
    if (selection.isCollapsed &&
        selection.start >= 0 &&
        selection.start < styledChars.length) {
      currentActiveStyle = styledChars[selection.start].style;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (styledChars.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final baseStyle = style ?? const TextStyle();
    final List<InlineSpan> children = [];

    int i = 0;
    while (i < styledChars.length) {
      final sc = styledChars[i];

      if (sc.style.imageUrl != null && sc.char == '\uFFFC') {
        final String url = sc.style.imageUrl!;
        final double? width = sc.style.imageWidth;
        final String? caption = sc.style.imageCaption;
        final int index = i;

        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: ResizableImageWidget(
            imagePath: url,
            initialWidth: width,
            caption: caption,
            index: index,
            onUpdate: (newWidth, newCaption) {
              styledChars[index] = StyledChar(
                char: styledChars[index].char,
                style: styledChars[index].style.copyWith(
                      imageWidth: newWidth,
                      imageCaption: newCaption,
                      clearCaption: newCaption == null,
                    ),
              );
              notifyListeners();
            },
            onDelete: () {
              styledChars.removeAt(index);
              final newTextStr = _getTextOnly();
              value = TextEditingValue(
                text: newTextStr,
                selection: TextSelection.collapsed(
                    offset: index.clamp(0, newTextStr.length)),
              );
              notifyListeners();
            },
            onReplace:
                onReplaceImage != null ? () => onReplaceImage!(index) : null,
          ),
        ));
        i++;
      } else if (sc.char == '\u2610' || sc.char == '\u2611') {
        final bool checked = sc.char == '\u2611';
        final int index = i;

        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InteractiveCheckbox(
            checked: checked,
            onTap: () => toggleChecklistState(index),
          ),
        ));
        i++;
      } else if (sc.char == '\u2008') {
        final int index = i;
        int numberIndex = 1;
        int scan = index - 1;
        while (scan >= 0) {
          if (styledChars[scan].char == '\n') {
            if (scan + 1 < styledChars.length && styledChars[scan + 1].char == '\u2008') {
              numberIndex++;
            } else {
              break;
            }
          }
          scan--;
        }
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.only(right: 8.0),
            constraints: const BoxConstraints(minWidth: 20),
            alignment: Alignment.centerRight,
            child: Text(
              '$numberIndex.',
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w500,
                color: baseStyle.color,
              ),
            ),
          ),
        ));
        i++;
      } else if (sc.char == '›') {
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.only(right: 8.0),
            width: 3.5,
            height: 16,
            decoration: BoxDecoration(
              color: baseStyle.color?.withOpacity(0.4) ?? const Color(0xFF6B7280),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ));
        i++;
      } else {
        final start = i;
        final currentStyle = sc.style;
        i++;

        while (i < styledChars.length &&
            styledChars[i].char != '\u2610' &&
            styledChars[i].char != '\u2611' &&
            styledChars[i].char != '\u2008' &&
            styledChars[i].char != '›' &&
            styledChars[i].style == currentStyle) {
          i++;
        }

        final textRun = text.substring(start, i);

        TextStyle runStyle = baseStyle.copyWith(
          fontWeight: currentStyle.bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: currentStyle.listType == 'quote' ? FontStyle.italic : (currentStyle.italic ? FontStyle.italic : FontStyle.normal),
          color: currentStyle.listType == 'quote' ? (currentStyle.color ?? baseStyle.color)?.withOpacity(0.7) : (currentStyle.color ?? baseStyle.color),
          backgroundColor: currentStyle.highlight,
        );

        if (currentStyle.underline && currentStyle.strikethrough) {
          runStyle = runStyle.copyWith(
            decoration: TextDecoration.combine(
                [TextDecoration.underline, TextDecoration.lineThrough]),
          );
        } else if (currentStyle.underline) {
          runStyle = runStyle.copyWith(decoration: TextDecoration.underline);
        } else if (currentStyle.strikethrough) {
          runStyle = runStyle.copyWith(decoration: TextDecoration.lineThrough);
        } else {
          runStyle = runStyle.copyWith(decoration: TextDecoration.none);
        }

        if (currentStyle.heading == 'h1') {
          runStyle = runStyle.copyWith(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          );
        } else if (currentStyle.heading == 'h2') {
          runStyle = runStyle.copyWith(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          );
        } else if (currentStyle.heading == 'h3') {
          runStyle = runStyle.copyWith(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          );
        }

        children.add(TextSpan(
          text: textRun,
          style: runStyle,
        ));
      }
    }

    return TextSpan(children: children, style: baseStyle);
  }
}

// Markdown Parser from Markdown String to StyledChar list
List<StyledChar> parseMarkdownToStyledChars(String markdown) {
  final List<StyledChar> result = [];
  final lines = markdown.split('\n');

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];

    TextAlign align = TextAlign.left;
    String heading = 'normal';
    String listType = 'normal';
    bool checked = false;

    // Parse alignment HTML wrappers
    final centerReg = RegExp(r'^<p align="center">(.*)</p>$');
    final rightReg = RegExp(r'^<p align="right">(.*)</p>$');
    final justifyReg = RegExp(r'^<p align="justify">(.*)</p>$');
    final leftReg = RegExp(r'^<p align="left">(.*)</p>$');

    if (centerReg.hasMatch(line)) {
      align = TextAlign.center;
      line = centerReg.firstMatch(line)!.group(1) ?? '';
    } else if (rightReg.hasMatch(line)) {
      align = TextAlign.right;
      line = rightReg.firstMatch(line)!.group(1) ?? '';
    } else if (justifyReg.hasMatch(line)) {
      align = TextAlign.justify;
      line = justifyReg.firstMatch(line)!.group(1) ?? '';
    } else if (leftReg.hasMatch(line)) {
      align = TextAlign.left;
      line = leftReg.firstMatch(line)!.group(1) ?? '';
    }

    // Parse headings
    if (line.startsWith('# ')) {
      heading = 'h1';
      line = line.substring(2);
    } else if (line.startsWith('## ')) {
      heading = 'h2';
      line = line.substring(3);
    } else if (line.startsWith('### ')) {
      heading = 'h3';
      line = line.substring(4);
    }

    // Parse lists and checklists
    final numListRegex = RegExp(r'^(\d+)\.\s(.*)$');
    if (line.startsWith('- [ ] ')) {
      listType = 'checkbox';
      checked = false;
      line = '\u2610${line.substring(6)}';
    } else if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
      listType = 'checkbox';
      checked = true;
      line = '\u2611${line.substring(6)}';
    } else if (line.startsWith('- ')) {
      listType = 'bullet';
      line = '•${line.substring(2)}';
    } else if (line.startsWith('* ')) {
      listType = 'bullet';
      line = '•${line.substring(2)}';
    } else if (line.startsWith('> ')) {
      listType = 'quote';
      line = '›${line.substring(2)}';
    } else if (numListRegex.hasMatch(line)) {
      listType = 'number';
      final match = numListRegex.firstMatch(line)!;
      final rest = match.group(2) ?? '';
      line = '\u2008$rest';
    }

    int idx = 0;
    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool strikethrough = false;
    Color? color;
    Color? highlight;

    while (idx < line.length) {
      // Parse <span color="0x..." highlight="0x..."> tags
      if (idx + 5 < line.length && line.substring(idx, idx + 5) == '<span') {
        int closeTag = line.indexOf('>', idx + 5);
        if (closeTag != -1) {
          final tagContent = line.substring(idx, closeTag);
          final colorMatch = RegExp(r'color="0x([0-9a-fA-F]+)"').firstMatch(tagContent);
          if (colorMatch != null) {
            final colorHex = colorMatch.group(1)!;
            color = Color(int.parse(colorHex, radix: 16));
          }
          final highlightMatch = RegExp(r'highlight="0x([0-9a-fA-F]+)"').firstMatch(tagContent);
          if (highlightMatch != null) {
            final highlightHex = highlightMatch.group(1)!;
            highlight = Color(int.parse(highlightHex, radix: 16));
          }
          idx = closeTag + 1;
          continue;
        }
      }

      // Parse </span> tags
      if (idx + 6 < line.length && line.substring(idx, idx + 7) == '</span>') {
        color = null;
        highlight = null;
        idx += 7;
        continue;
      }

      if (line[idx] == '!' && idx + 1 < line.length && line[idx + 1] == '[') {
        int closeBracket = line.indexOf(']', idx + 2);
        if (closeBracket != -1 &&
            closeBracket + 1 < line.length &&
            line[closeBracket + 1] == '(') {
          int closeParenthesis = line.indexOf(')', closeBracket + 2);
          if (closeParenthesis != -1) {
            final alt = line.substring(idx + 2, closeBracket);
            final url = line.substring(closeBracket + 2, closeParenthesis);

            double? width;
            double? height;
            String cleanUrl = url;

            final uri = Uri.tryParse(url);
            if (uri != null && uri.hasQuery) {
              final wStr = uri.queryParameters['width'];
              final hStr = uri.queryParameters['height'];
              if (wStr != null) width = double.tryParse(wStr);
              if (hStr != null) height = double.tryParse(hStr);

              int qIdx = url.indexOf('?');
              if (qIdx != -1) {
                cleanUrl = url.substring(0, qIdx);
              }
            }

            result.add(StyledChar(
              char: '\uFFFC',
              style: Style(
                bold: bold,
                italic: italic,
                underline: underline,
                strikethrough: strikethrough,
                heading: heading,
                align: align,
                listType: listType,
                checked: checked,
                imageUrl: cleanUrl,
                imageWidth: width,
                imageHeight: height,
                imageCaption: (alt.isNotEmpty && alt != 'Image') ? alt : null,
              ),
            ));
            idx = closeParenthesis + 1;
            continue;
          }
        }
      }

      if (idx + 1 < line.length &&
          (line.substring(idx, idx + 2) == '**' ||
              line.substring(idx, idx + 2) == '__')) {
        bold = !bold;
        idx += 2;
      } else if (line[idx] == '*' || line[idx] == '_') {
        italic = !italic;
        idx += 1;
      } else if (idx + 2 < line.length &&
          line.substring(idx, idx + 3) == '<u>') {
        underline = true;
        idx += 3;
      } else if (idx + 3 < line.length &&
          line.substring(idx, idx + 4) == '</u>') {
        underline = false;
        idx += 4;
      } else if (idx + 1 < line.length &&
          line.substring(idx, idx + 2) == '~~') {
        strikethrough = !strikethrough;
        idx += 2;
      } else {
        result.add(StyledChar(
          char: line[idx],
          style: Style(
            bold: bold,
            italic: italic,
            underline: underline,
            strikethrough: strikethrough,
            heading: heading,
            align: align,
            listType: listType,
            checked: checked,
            color: color,
            highlight: highlight,
          ),
        ));
        idx++;
      }
    }

    if (i < lines.length - 1) {
      result.add(StyledChar(
        char: '\n',
        style: Style(
          heading: heading,
          align: align,
          listType: listType,
          checked: checked,
        ),
      ));
    }
  }
  return result;
}

String generateInlineMarkdown(List<StyledChar> lineChars) {
  final StringBuffer sb = StringBuffer();
  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strikethrough = false;
  Color? color;
  Color? highlight;

  for (int i = 0; i < lineChars.length; i++) {
    final style = lineChars[i].style;
    final char = lineChars[i].char;

    if (style.imageUrl != null && char == '\uFFFC') {
      if (bold) {
        sb.write('**');
        bold = false;
      }
      if (italic) {
        sb.write('*');
        italic = false;
      }
      if (underline) {
        sb.write('</u>');
        underline = false;
      }
      if (strikethrough) {
        sb.write('~~');
        strikethrough = false;
      }
      if (color != null || highlight != null) {
        sb.write('</span>');
        color = null;
        highlight = null;
      }

      final urlBuffer = StringBuffer(style.imageUrl!);
      if (style.imageWidth != null || style.imageHeight != null) {
        urlBuffer.write('?');
        final List<String> params = [];
        if (style.imageWidth != null) {
          params.add('width=${style.imageWidth!.toInt()}');
        }
        if (style.imageHeight != null) {
          params.add('height=${style.imageHeight!.toInt()}');
        }
        urlBuffer.write(params.join('&'));
      }
      final altText = style.imageCaption ?? '';
      sb.write('![$altText](${urlBuffer.toString()})');
      continue;
    }

    if (style.color != color || style.highlight != highlight) {
      if (color != null || highlight != null) {
        sb.write('</span>');
      }
      color = style.color;
      highlight = style.highlight;
      if (color != null || highlight != null) {
        sb.write('<span');
        if (color != null) sb.write(' color="0x${color.value.toRadixString(16)}"');
        if (highlight != null) sb.write(' highlight="0x${highlight.value.toRadixString(16)}"');
        sb.write('>');
      }
    }

    if (style.bold != bold) {
      sb.write('**');
      bold = style.bold;
    }
    if (style.italic != italic) {
      sb.write('*');
      italic = style.italic;
    }
    if (style.underline != underline) {
      sb.write(style.underline ? '<u>' : '</u>');
      underline = style.underline;
    }
    if (style.strikethrough != strikethrough) {
      sb.write('~~');
      strikethrough = style.strikethrough;
    }

    sb.write(char);
  }

  if (bold) sb.write('**');
  if (italic) sb.write('*');
  if (underline) sb.write('</u>');
  if (strikethrough) sb.write('~~');
  if (color != null || highlight != null) sb.write('</span>');

  return sb.toString();
}

// Generates standard Markdown string from StyledChar list
String generateMarkdownFromStyledChars(List<StyledChar> styledChars) {
  if (styledChars.isEmpty) return "";

  final List<List<StyledChar>> lines = [];
  List<StyledChar> currentLine = [];

  for (var sc in styledChars) {
    if (sc.char == '\n') {
      lines.add(currentLine);
      currentLine = [];
    } else {
      currentLine.add(sc);
    }
  }
  lines.add(currentLine);

  final List<String> markdownLines = [];

  for (int i = 0; i < lines.length; i++) {
    final lineChars = lines[i];
    final style = lineChars.isNotEmpty ? lineChars.first.style : const Style();

    List<StyledChar> contentChars = List.from(lineChars);
    if (contentChars.isNotEmpty &&
        (contentChars.first.char == '•' ||
            contentChars.first.char == '›' ||
            contentChars.first.char == '\u2610' ||
            contentChars.first.char == '\u2611' ||
            contentChars.first.char == '\u2008')) {
      contentChars.removeAt(0);
    }

    String lineContent = generateInlineMarkdown(contentChars);

    if (style.listType == 'checkbox') {
      lineContent = style.checked ? '- [x] $lineContent' : '- [ ] $lineContent';
    } else if (style.listType == 'bullet') {
      lineContent = '- $lineContent';
    } else if (style.listType == 'quote') {
      lineContent = '> $lineContent';
    } else if (style.listType == 'number') {
      lineContent = '1. $lineContent';
    }

    if (style.heading == 'h1') {
      lineContent = '# $lineContent';
    } else if (style.heading == 'h2') {
      lineContent = '## $lineContent';
    } else if (style.heading == 'h3') {
      lineContent = '### $lineContent';
    }

    if (style.align == TextAlign.center) {
      lineContent = '<p align="center">$lineContent</p>';
    } else if (style.align == TextAlign.right) {
      lineContent = '<p align="right">$lineContent</p>';
    } else if (style.align == TextAlign.justify) {
      lineContent = '<p align="justify">$lineContent</p>';
    }

    markdownLines.add(lineContent);
  }

  return markdownLines.join('\n');
}
