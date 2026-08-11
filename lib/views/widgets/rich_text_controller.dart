import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fullscreen_image_viewer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tactile_button.dart';
import '../../core/layout/paragraph_block_behavior.dart';

const bool kImageDebug = true;

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
  final int indent; // 0 to 5 list indent level
  final String? imageUrl;
  final double? imageWidth;
  final double? imageHeight;
  final String? imageCaption;
  final bool isDivider;
  final String? linkUrl;

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
    this.indent = 0,
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    this.imageCaption,
    this.isDivider = false,
    this.linkUrl,
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
    int? indent,
    String? imageUrl,
    double? imageWidth,
    double? imageHeight,
    String? imageCaption,
    bool? isDivider,
    String? linkUrl,
    bool clearColor = false,
    bool clearHighlight = false,
    bool clearImage = false,
    bool clearCaption = false,
    bool clearLink = false,
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
      indent: indent ?? this.indent,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      imageWidth: clearImage ? null : (imageWidth ?? this.imageWidth),
      imageHeight: clearImage ? null : (imageHeight ?? this.imageHeight),
      imageCaption: clearImage || clearCaption
          ? null
          : (imageCaption ?? this.imageCaption),
      isDivider: isDivider ?? this.isDivider,
      linkUrl: clearLink ? null : (linkUrl ?? this.linkUrl),
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
        other.indent == indent &&
        other.imageUrl == imageUrl &&
        other.imageWidth == imageWidth &&
        other.imageHeight == imageHeight &&
        other.imageCaption == imageCaption &&
        other.isDivider == isDivider &&
        other.linkUrl == linkUrl;
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
        indent,
        imageUrl,
        imageWidth,
        imageHeight,
        imageCaption,
        isDivider,
        linkUrl,
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
  final EdgeInsetsGeometry? margin;

  const InteractiveCheckbox({
    super.key,
    required this.checked,
    required this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final uncheckedBorderColor = isDark 
        ? Colors.white.withOpacity(0.4) 
        : Colors.black.withOpacity(0.3);
        
    final checkedBgColor = const Color(0xFFFFCC00);
    final checkIconColor = const Color(0xFF333333);

    return TactileButton(
      onTap: onTap,
      compressionScale: 0.7,
      settleDuration: const Duration(milliseconds: 1000),
      playSelectionHaptic: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: margin ?? const EdgeInsets.only(top: 8.0, right: 8.0, left: 4.0),
        width: 16,
        height: 16,
        decoration: checked
            ? BoxDecoration(
                color: checkedBgColor,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: checkedBgColor, width: 1.5),
              )
            : BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: uncheckedBorderColor, width: 1.5),
                borderRadius: BorderRadius.circular(5),
              ),
        child: checked
            ? Center(
                child: SvgPicture.asset(
                  'assets/icons/vector_check.svg',
                  width: 10,
                  height: 10,
                  colorFilter: ColorFilter.mode(checkIconColor, BlendMode.srcIn),
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
  final VoidCallback? onTap;
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
    this.onTap,
    this.isStacked = false,
    this.stackImageIndex,
  });

  @override
  State<ResizableImageWidget> createState() => ResizableImageWidgetState();
}

class ResizableImageWidgetState extends State<ResizableImageWidget>
    with SingleTickerProviderStateMixin {
  double? _width;
  bool _showControls = false;
  late TextEditingController _captionController;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isDeleting = false;
  int _lastPointerDownTime = 0;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
    _captionController = TextEditingController(text: widget.caption ?? '');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
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

  bool get showControls => _showControls;

  void toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void updateWidth(double deltaX, int direction) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = (screenWidth - 48.0).clamp(100.0, 720.0);
    final double currentWidth = widget.isStacked
        ? double.infinity
        : (_width ?? maxWidth).clamp(150.0, maxWidth);
        
    setState(() {
      if (direction == -1) {
        _width = (currentWidth - deltaX).clamp(150.0, maxWidth);
      } else if (direction == 1) {
        _width = (currentWidth + deltaX).clamp(150.0, maxWidth);
      }
    });
    
    widget.onUpdate(
      _width!,
      _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
    );
  }

  Future<void> _triggerDelete() async {
    HapticFeedback.mediumImpact();
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
    if (kImageDebug) {
      debugPrint("[Stage 9] Started - ResizableImageWidget.build()");
      debugPrint("Relevant state: image path=${widget.imagePath}, index=${widget.index}, stackImageIndex=${widget.stackImageIndex}");
    }
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
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (kImageDebug) {
              debugPrint("[Stage 9 - PointerDown] Image Listener onPointerDown. Event position: ${event.position}");
            }
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - _lastPointerDownTime < 300) {
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
            } else {
              setState(() {
                _showControls = !_showControls;
              });
              if (widget.onTap != null) {
                widget.onTap!();
              }
            }
            _lastPointerDownTime = now;
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
                        if (kImageDebug) {
                          debugPrint("[Stage 10] Image frameBuilder. Frame: $frame, SyncLoaded: $wasSynchronouslyLoaded");
                        }
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
                        if (kImageDebug) {
                          debugPrint("[Stage 10 - ERROR] Image loading failed. Error: $error");
                        }
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
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerMove: (event) {
                          setState(() {
                            _width = (currentWidth - event.delta.dx)
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
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerMove: (event) {
                          setState(() {
                            _width = (currentWidth + event.delta.dx)
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

    if (kImageDebug) {
      debugPrint("[Stage 9] Completed");
      debugPrint("Relevant state: currentWidth=$currentWidth, currentHeight=$currentHeight");
    }

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

class UndoState {
  final List<StyledChar> styledChars;
  final TextSelection selection;

  UndoState(List<StyledChar> chars, this.selection)
      : styledChars = List.from(chars);
}

class RichTextEditingController extends TextEditingController {
  List<StyledChar> styledChars = [];
  final Map<String, GlobalKey> _imageKeyCache = {};
  final Map<int, GlobalKey> imageKeys = {};

  GlobalKey _getImageKey(String url, int index) {
    final cacheKey = '$url-$index';
    return _imageKeyCache.putIfAbsent(cacheKey, () => GlobalKey());
  }
  Style currentActiveStyle = const Style();
  VoidCallback? onStyleChanged;
  void Function(int index)? onReplaceImage;
  void Function(int index)? onTapImage;
  final List<TapGestureRecognizer> _recognizers = [];
  final List<UndoState> _undoStack = [];
  final List<UndoState> _redoStack = [];
  bool _isUndoOrRedoAction = false;
  DateTime? _lastTypeTime;
  String? _lastText;

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void saveUndoState() {
    if (_isUndoOrRedoAction) return;

    final currentState = UndoState(styledChars, selection);
    if (_undoStack.isNotEmpty) {
      final last = _undoStack.last;
      if (_areStatesEqual(last, currentState)) {
        return;
      }
    }

    _undoStack.add(currentState);
    if (_undoStack.length > 100) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  bool _areStatesEqual(UndoState a, UndoState b) {
    if (a.styledChars.length != b.styledChars.length) return false;
    for (int i = 0; i < a.styledChars.length; i++) {
      if (a.styledChars[i].char != b.styledChars[i].char ||
          a.styledChars[i].style != b.styledChars[i].style) {
        return false;
      }
    }
    return true;
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (!canUndo) return;
    _isUndoOrRedoAction = true;

    _redoStack.add(UndoState(styledChars, selection));

    final previous = _undoStack.removeLast();
    styledChars = List.from(previous.styledChars);
    value = TextEditingValue(
      text: _getTextOnly(),
      selection: previous.selection,
    );

    _isUndoOrRedoAction = false;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _isUndoOrRedoAction = true;

    _undoStack.add(UndoState(styledChars, selection));

    final next = _redoStack.removeLast();
    styledChars = List.from(next.styledChars);
    value = TextEditingValue(
      text: _getTextOnly(),
      selection: next.selection,
    );

    _isUndoOrRedoAction = false;
    notifyListeners();
  }

  void handleTextEditingStateSaving(String newText) {
    if (_isUndoOrRedoAction) return;

    final now = DateTime.now();
    final isWordBoundary = newText.endsWith(' ') || newText.endsWith('\n') || newText.endsWith('\t');
    final timePassed = _lastTypeTime == null ? true : now.difference(_lastTypeTime!) > const Duration(milliseconds: 1500);

    if (isWordBoundary || timePassed || _lastText == null || (_lastText!.length - newText.length).abs() > 5) {
      saveUndoState();
    }

    _lastTypeTime = now;
    _lastText = newText;
  }

  void copy() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;

    final selectedChars = styledChars.sublist(sel.start, sel.end);
    final markdown = generateInlineMarkdown(selectedChars);

    Clipboard.setData(ClipboardData(text: markdown));
  }

  void cut() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;

    copy();
    saveUndoState();

    final List<StyledChar> newChars = List.from(styledChars);
    newChars.removeRange(sel.start, sel.end);

    styledChars = newChars;
    final newTextStr = _getTextOnly();

    value = TextEditingValue(
      text: newTextStr,
      selection: TextSelection.collapsed(offset: sel.start),
    );
    notifyListeners();
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) return;

    final sel = selection;
    saveUndoState();

    final List<StyledChar> newChars = List.from(styledChars);
    int start = sel.isValid ? sel.start : styledChars.length;
    int end = sel.isValid ? sel.end : styledChars.length;

    final textVal = data.text!;
    final hasMarkdown = textVal.contains('**') ||
        textVal.contains('*') ||
        textVal.contains('#') ||
        textVal.contains('- [') ||
        textVal.contains('- ') ||
        textVal.contains('>') ||
        RegExp(r'(?:\n|^)\s*\d+\.\s').hasMatch(textVal) ||
        textVal.contains('---');

    List<StyledChar> pastedChars;
    if (hasMarkdown) {
      pastedChars = parseMarkdownToStyledChars(textVal, baseStyle: currentActiveStyle);
    } else {
      final normalized = textVal.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      pastedChars = normalized.split('').map((c) => StyledChar(char: c, style: currentActiveStyle)).toList();
    }

    if (end > start) {
      newChars.removeRange(start, end);
    }

    newChars.insertAll(start, pastedChars);

    styledChars = newChars;
    final newTextStr = _getTextOnly();

    value = TextEditingValue(
      text: newTextStr,
      selection: TextSelection.collapsed(offset: start + pastedChars.length),
    );
    notifyListeners();
  }

  void duplicateSelection() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;

    saveUndoState();

    final selectedChars = styledChars.sublist(sel.start, sel.end);
    final List<StyledChar> newChars = List.from(styledChars);

    newChars.insertAll(sel.end, selectedChars);

    styledChars = newChars;
    final newTextStr = _getTextOnly();

    value = TextEditingValue(
      text: newTextStr,
      selection: TextSelection(
        baseOffset: sel.end,
        extentOffset: sel.end + selectedChars.length,
      ),
    );
    notifyListeners();
  }

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
    saveUndoState();
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
    saveUndoState();
    final oldSel = selection;
    if (!oldSel.isValid) return;

    final lines = getOverlappingLineRanges(oldSel);
    if (lines.isEmpty) return;

    List<StyledChar> newChars = List.from(styledChars);
    int selectionStartShift = 0;
    int selectionEndShift = 0;

    // Pre-scan to determine if we should apply or revert the target style across the entire selection
    bool applyTargetStyle = true;
    if (styleName.startsWith('align-')) {
      TextAlign targetAlign = TextAlign.left;
      if (styleName == 'align-center') targetAlign = TextAlign.center;
      else if (styleName == 'align-right') targetAlign = TextAlign.right;
      else if (styleName == 'align-justify') targetAlign = TextAlign.justify;

      bool allMatch = true;
      for (final line in lines) {
        final existingStyle = line.start < styledChars.length
            ? styledChars[line.start].style
            : const Style();
        if (existingStyle.align != targetAlign) {
          allMatch = false;
          break;
        }
      }
      applyTargetStyle = !allMatch;
    } else if (styleName == 'h1' || styleName == 'h2' || styleName == 'h3') {
      bool allMatch = true;
      for (final line in lines) {
        final existingStyle = line.start < styledChars.length
            ? styledChars[line.start].style
            : const Style();
        if (existingStyle.heading != styleName) {
          allMatch = false;
          break;
        }
      }
      applyTargetStyle = !allMatch;
    } else {
      bool allMatch = true;
      for (final line in lines) {
        final existingStyle = line.start < styledChars.length
            ? styledChars[line.start].style
            : const Style();
        if (existingStyle.listType != styleName) {
          allMatch = false;
          break;
        }
      }
      applyTargetStyle = !allMatch;
    }

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final lineStart = line.start;

      final existingStyle = lineStart < newChars.length
          ? newChars[lineStart].style
          : const Style();

      final behavior = ParagraphBlockRegistry.getBehaviorForListType(styleName);
      if (behavior != null) {
        // Query the behavior of the existing line listType to remove its prefix
        final existingBehavior = ParagraphBlockRegistry.getBehaviorForListType(existingStyle.listType);
        if (existingBehavior != null) {
          final bool hasPrefix = lineStart < newChars.length &&
              existingBehavior.hasPrefix(newChars[lineStart].char);
          if (hasPrefix) {
            newChars.removeAt(lineStart);
            if (oldSel.start > lineStart) selectionStartShift -= existingBehavior.prefixLen;
            if (oldSel.end > lineStart) selectionEndShift -= existingBehavior.prefixLen;
          }
        }

        String newListType = 'normal';
        StyledChar? prefixChar;
        String targetHeading = existingStyle.heading;

        if (applyTargetStyle) {
          newListType = styleName;
          prefixChar = behavior.getPrefixChar(existingStyle);
          // Lists are mutually exclusive with headings: strip heading formatting
          targetHeading = 'normal';
        }

        if (prefixChar != null) {
          newChars.insert(lineStart, prefixChar);
          if (oldSel.start >= lineStart) selectionStartShift += behavior.prefixLen;
          if (oldSel.end >= lineStart) selectionEndShift += behavior.prefixLen;
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
                  listType: newListType,
                  checked: false,
                  strikethrough: false,
                  heading: targetHeading,
              ),
            );
          }
        }
      } else if (styleName == 'h1' || styleName == 'h2' || styleName == 'h3') {
        final targetHeading = applyTargetStyle ? styleName : 'normal';

        // Headings are mutually exclusive with lists. If applying heading, clear list formatting and strip list prefix.
        String newListType = existingStyle.listType;
        if (applyTargetStyle && existingStyle.listType != 'normal') {
          final existingBehavior = ParagraphBlockRegistry.getBehaviorForListType(existingStyle.listType);
          if (existingBehavior != null) {
            final bool hasPrefix = lineStart < newChars.length &&
                existingBehavior.hasPrefix(newChars[lineStart].char);
            if (hasPrefix) {
              newChars.removeAt(lineStart);
              if (oldSel.start > lineStart) selectionStartShift -= existingBehavior.prefixLen;
              if (oldSel.end > lineStart) selectionEndShift -= existingBehavior.prefixLen;
            }
          }
          newListType = 'normal';
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
              style: newChars[j].style.copyWith(
                heading: targetHeading,
                listType: newListType,
                checked: false,
                strikethrough: false,
              ),
            );
          }
        }
      } else if (styleName.startsWith('align-')) {
        TextAlign targetAlign = TextAlign.left;
        if (applyTargetStyle) {
          if (styleName == 'align-center') {
            targetAlign = TextAlign.center;
          } else if (styleName == 'align-right') {
            targetAlign = TextAlign.right;
          } else if (styleName == 'align-justify') {
            targetAlign = TextAlign.justify;
          }
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

    // Override currentActiveStyle to prevent it from being reset to default for empty lines/selections
    if (styleName.startsWith('align-')) {
      TextAlign targetAlign = TextAlign.left;
      if (applyTargetStyle) {
        if (styleName == 'align-center') {
          targetAlign = TextAlign.center;
        } else if (styleName == 'align-right') {
          targetAlign = TextAlign.right;
        } else if (styleName == 'align-justify') {
          targetAlign = TextAlign.justify;
        }
      }
      currentActiveStyle = currentActiveStyle.copyWith(align: targetAlign);
    } else if (styleName == 'h1' || styleName == 'h2' || styleName == 'h3') {
      currentActiveStyle = currentActiveStyle.copyWith(
        heading: applyTargetStyle ? styleName : 'normal',
      );
    } else {
      currentActiveStyle = currentActiveStyle.copyWith(
        listType: applyTargetStyle ? styleName : 'normal',
        checked: false,
      );
    }

    if (onStyleChanged != null) {
      onStyleChanged!();
    }
    notifyListeners();
  }

  void insertImage(String path) {
    if (kImageDebug) {
      debugPrint("[Stage 5] Started");
      debugPrint("Relevant state: image path=$path, selection=$selection, styledChars length=${styledChars.length}");
    }
    saveUndoState();
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
    if (kImageDebug) {
      debugPrint("[Stage 5] Completed");
      debugPrint("Relevant state: new text length=${text.length}, new selection=$selection, new styledChars length=${styledChars.length}");
    }
  }

  void insertDivider() {
    saveUndoState();
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

    final divStyle = Style(isDivider: true);
    newChars.insert(cursor, StyledChar(char: '\u2014', style: divStyle));
    cursor++;

    // Always insert a trailing newline after the divider to make it separate
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
    saveUndoState();
    if (index >= 0 && index < styledChars.length) {
      final char = styledChars[index].char;
      if (char == '\u2610' || char == '\u2611') {
        HapticFeedback.lightImpact();
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
    if (kImageDebug) {
      debugPrint("[Stage 6] Started");
      debugPrint("Relevant state: newValue text length=${newValue.text.length}, newValue selection=${newValue.selection}, styledChars length=${styledChars.length}");
    }
    var finalValue = newValue;
    final oldText = text;
    var newText = newValue.text;

    if (!_isUndoOrRedoAction && oldText != newText) {
      handleTextEditingStateSaving(newText);
    }

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

      int diffStart = prefixLen;
      int diffEndOld = oldText.length - suffixLen;
      var diffEndNew = newText.length - suffixLen;

      List<StyledChar> newChars = List.from(styledChars);
      bool prefixDeleted = false;
      bool isHeadingBackspace = false;
      bool dividerDeleted = false;

      // Newline-adjacent-to-image deletion protection:
      // If a newline immediately before or after the image character (\uFFFC)
      // is deleted, delete the image character as well. This prevents merging
      // text onto the same line as the image.
      int imageIndexToDelete = -1;
      if (diffEndOld - diffStart == 1 && oldText[diffStart] == '\n') {
        if (diffStart > 0 && oldText[diffStart - 1] == '\uFFFC') {
          imageIndexToDelete = diffStart - 1;
        } else if (diffStart + 1 < oldText.length && oldText[diffStart + 1] == '\uFFFC') {
          imageIndexToDelete = diffStart + 1;
        }
      }

      if (imageIndexToDelete != -1) {
        if (imageIndexToDelete < diffStart) {
          // Image is before newline (deleting trailing newline of image)
          // Also check if there is a leading newline before the image to clean it up too
          bool hasLeadingNewline = (imageIndexToDelete > 0 && oldText[imageIndexToDelete - 1] == '\n');
          
          newChars.removeAt(diffStart); // removes trailing newline
          newChars.removeAt(imageIndexToDelete); // removes image
          if (hasLeadingNewline) {
            newChars.removeAt(imageIndexToDelete - 1); // removes leading newline
            newText = '${newText.substring(0, imageIndexToDelete - 1)}${newText.substring(diffStart)}';
            finalValue = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: (imageIndexToDelete - 1).clamp(0, newText.length)),
            );
            diffStart = imageIndexToDelete - 1;
          } else {
            newText = '${newText.substring(0, imageIndexToDelete)}${newText.substring(diffStart)}';
            finalValue = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: imageIndexToDelete.clamp(0, newText.length)),
            );
            diffStart = imageIndexToDelete;
          }
        } else {
          // Image is after newline
          newChars.removeAt(imageIndexToDelete); // removes image
          newChars.removeAt(diffStart); // removes newline
          newText = '${newText.substring(0, diffStart)}${newText.substring(imageIndexToDelete)}';
          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: diffStart.clamp(0, newText.length)),
          );
        }
        diffEndNew = diffStart;
        diffEndOld = diffStart;
      }

      if (diffEndOld - diffStart == 1 && oldText[diffStart] == '\n') {
        int currentLineCharIdx = diffStart + 1;
        if (currentLineCharIdx < styledChars.length) {
          final style = styledChars[currentLineCharIdx].style;
          if (style.heading != 'normal') {
            isHeadingBackspace = true;
          }
        }
      }

      if (isHeadingBackspace) {
        int scan = diffStart + 1;
        while (scan < newChars.length && newChars[scan].char != '\n') {
          newChars[scan] = StyledChar(
            char: newChars[scan].char,
            style: newChars[scan].style.copyWith(heading: 'normal'),
          );
          scan++;
        }
        currentActiveStyle = currentActiveStyle.copyWith(heading: 'normal');
        
        finalValue = TextEditingValue(
          text: oldText,
          selection: TextSelection.collapsed(offset: diffStart + 1),
        );
      } else {
        if (diffEndOld > diffStart) {
          for (int k = diffStart; k < diffEndOld; k++) {
            if (k < styledChars.length) {
              final char = styledChars[k].char;
              if (ParagraphBlockRegistry.hasAnyPrefix(char)) {
                prefixDeleted = true;
              }
              if (styledChars[k].style.isDivider) {
                dividerDeleted = true;
              }
            }
          }
          newChars.removeRange(diffStart, diffEndOld);
        }
      }

      if (dividerDeleted) {
        if (diffStart > 0 && newChars[diffStart - 1].char == '\n') {
          newChars.removeAt(diffStart - 1);
          newText = '${newText.substring(0, diffStart - 1)}${newText.substring(diffStart)}';
          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: (newValue.selection.baseOffset - 1).clamp(0, newText.length)),
          );
          diffStart--;
        }
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
              clearImage: true,
            );
      }

      if (prefixDeleted) {
        int scan = diffStart;
        while (scan < newChars.length) {
          final char = newChars[scan].char;
          newChars[scan] = StyledChar(
            char: char,
            style: newChars[scan].style.copyWith(listType: 'normal', checked: false),
          );
          if (char == '\n') {
            break;
          }
          scan++;
        }
        baseStyle = baseStyle.copyWith(listType: 'normal', checked: false);
        currentActiveStyle = baseStyle;
      }

      final bool isNewlineInsert =
          (diffEndNew - diffStart == 1) && newText[diffStart] == '\n';

      final List<StyledChar> insertedStyledChars = [];
      if (isNewlineInsert) {
        int lineStart = diffStart - 1;
        while (lineStart >= 0 && newText[lineStart] != '\n') {
          lineStart--;
        }
        lineStart++;

        bool isLineEmptyList = false;
        if (diffStart > lineStart) {
          final prefixText = newText.substring(lineStart, diffStart);
          if (ParagraphBlockRegistry.hasAnyPrefix(prefixText)) {
            isLineEmptyList = true;
          }
        }

        if (isLineEmptyList) {
          newChars.removeAt(lineStart);
          final normalStyle = baseStyle.copyWith(listType: 'normal', checked: false);
          insertedStyledChars.add(StyledChar(char: '\n', style: normalStyle));
          newText = '${newText.substring(0, lineStart)}${newText.substring(diffStart)}';
          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: lineStart + 1),
          );
          currentActiveStyle = normalStyle;
          diffStart = lineStart;
        } else {
          if (baseStyle.heading != 'normal') {
            final normalStyle = baseStyle.copyWith(heading: 'normal');
            insertedStyledChars.add(StyledChar(char: '\n', style: normalStyle));

            int scan = diffStart;
            while (scan < newChars.length && newChars[scan].char != '\n') {
              newChars[scan] = StyledChar(
                char: newChars[scan].char,
                style: newChars[scan].style.copyWith(heading: 'normal'),
              );
              scan++;
            }
            currentActiveStyle = normalStyle;
            baseStyle = normalStyle;
          } else {
            insertedStyledChars.add(StyledChar(char: '\n', style: baseStyle));
          }

          final behavior = ParagraphBlockRegistry.getBehaviorForListType(baseStyle.listType);
          if (behavior != null) {
            final prefixChar = behavior.getPrefixChar(baseStyle);
            insertedStyledChars.add(prefixChar);
            newText =
                '${newText.substring(0, diffStart + 1)}${prefixChar.char}${newText.substring(diffStart + 1)}';
            diffEndNew += behavior.prefixLen;

            finalValue = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(
                  offset: newValue.selection.baseOffset + behavior.prefixLen),
            );
          } else {
            baseStyle = baseStyle.copyWith(heading: 'normal');
          }
        }
      } else {
        final bool isPaste = (diffEndNew - diffStart > 1);
        if (isPaste) {
          final pastedText = newText.substring(diffStart, diffEndNew);
          final hasMarkdown = pastedText.contains('**') ||
              pastedText.contains('*') ||
              pastedText.contains('# ') ||
              pastedText.contains('- [') ||
              pastedText.contains('- ') ||
              pastedText.contains('---');

          List<StyledChar> pastedChars;
          if (hasMarkdown) {
            pastedChars = parseMarkdownToStyledChars(pastedText);
          } else {
            final normalized = pastedText.replaceAll(RegExp(r'\n{3,}'), '\n\n');
            pastedChars = normalized.split('').map((c) => StyledChar(char: c, style: baseStyle)).toList();
          }

          insertedStyledChars.addAll(pastedChars);

          final insertTextStr = pastedChars.map((sc) => sc.char).join();
          newText = '${newText.substring(0, diffStart)}$insertTextStr${newText.substring(diffEndNew)}';
          diffEndNew = diffStart + insertTextStr.length;

          finalValue = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: diffEndNew),
          );
        } else {
          for (int i = diffStart; i < diffEndNew; i++) {
            insertedStyledChars
                .add(StyledChar(char: newText[i], style: baseStyle));
          }
        }
      }

      if (insertedStyledChars.isNotEmpty) {
        newChars.insertAll(diffStart, insertedStyledChars);
      }

      styledChars = newChars;
    }

    super.value = finalValue;
    if (kImageDebug) {
      debugPrint("[Stage 6] Completed");
      debugPrint("Relevant state: final text length=${text.length}, final selection=$selection, final styledChars length=${styledChars.length}");
    }

    if (selection.isValid && selection.start >= 0) {
      if (selection.isCollapsed) {
        int checkIdx = selection.start - 1;
        if (checkIdx >= 0 && checkIdx < styledChars.length) {
          final style = styledChars[checkIdx].style;
          if (styledChars[checkIdx].char == '\n') {
            final currentStyle = selection.start < styledChars.length
                ? styledChars[selection.start].style
                : const Style();
            currentActiveStyle = style.copyWith(
              listType: 'normal',
              checked: false,
              indent: 0,
              align: currentStyle.align,
              heading: currentStyle.heading,
            );
          } else {
            currentActiveStyle = style;
          }
        } else if (selection.start >= 0 && selection.start < styledChars.length) {
          currentActiveStyle = styledChars[selection.start].style;
        } else {
          currentActiveStyle = const Style();
        }
      } else {
        currentActiveStyle = _getCommonStyleOfSelection(selection);
      }
    }
  }

  Style _getCommonStyleOfSelection(TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed || styledChars.isEmpty) {
      return const Style();
    }
    int start = sel.start;
    int end = sel.end.clamp(0, styledChars.length);
    if (start >= end) return const Style();

    Style common = styledChars[start].style;
    bool bold = common.bold;
    bool italic = common.italic;
    bool underline = common.underline;
    bool strikethrough = common.strikethrough;
    Color? highlight = common.highlight;
    String heading = common.heading;
    String listType = common.listType;
    TextAlign align = common.align;

    for (int i = start + 1; i < end; i++) {
      final style = styledChars[i].style;
      if (style.bold != bold) bold = false;
      if (style.italic != italic) italic = false;
      if (style.underline != underline) underline = false;
      if (style.strikethrough != strikethrough) strikethrough = false;
      if (style.highlight != highlight) highlight = null;
      if (style.heading != heading) heading = 'normal';
      if (style.listType != listType) listType = 'normal';
      if (style.align != align) align = TextAlign.left;
    }

    return Style(
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      highlight: highlight,
      heading: heading,
      listType: listType,
      indent: common.indent,
      align: align,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    imageKeys.clear();
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    if (styledChars.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final baseStyle = style ?? const TextStyle();
    final List<InlineSpan> children = [];

    int i = 0;
    while (i < styledChars.length) {
      final sc = styledChars[i];

      if (sc.style.isDivider) {
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16.0),
            height: 20.0,
            alignment: Alignment.center,
            child: Container(
              height: 1.5,
              color: baseStyle.color?.withOpacity(0.2) ?? Colors.grey.withOpacity(0.2),
            ),
          ),
        ));
        i++;
      } else if (sc.style.imageUrl != null && sc.char == '\uFFFC') {
        final String url = sc.style.imageUrl!;
        final double? width = sc.style.imageWidth;
        final String? caption = sc.style.imageCaption;
        final int index = i;
        final key = _getImageKey(url, index);
        imageKeys[index] = key;

        if (kImageDebug) {
          debugPrint("[Stage 8] Started - Mapping styledChar $index to ResizableImageWidget");
          debugPrint("Relevant state: image path=$url, imageWidth=$width, caption=$caption");
        }

        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: ResizableImageWidget(
            key: key,
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
            onTap: () {
              if (onTapImage != null) {
                onTapImage!(index);
              }
            },
          ),
        ));
        i++;
        if (kImageDebug) {
          debugPrint("[Stage 8] Completed");
        }
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
        children.add(TextSpan(
          text: '$numberIndex. ',
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: baseStyle.color,
          ),
        ));
        i++;
      } else if (sc.char == '›') {
        children.add(TextSpan(
          text: '│ ',
          style: baseStyle.copyWith(
            color: (baseStyle.color ?? const Color(0xFF6B7280)).withOpacity(0.5),
            fontWeight: FontWeight.w300,
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
            !styledChars[i].style.isDivider &&
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

        if (currentStyle.linkUrl != null) {
          final linkStyle = runStyle.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          );
          final recognizer = TapGestureRecognizer()
            ..onTap = () {
              handleUrlLaunch(currentStyle.linkUrl!);
            };
          _recognizers.add(recognizer);
          children.add(TextSpan(
            text: textRun,
            style: linkStyle,
            recognizer: recognizer,
          ));
        } else {
          final urlMatches = findUrlMatches(textRun);
          if (urlMatches.isEmpty) {
            children.add(TextSpan(
              text: textRun,
              style: runStyle,
            ));
          } else {
            int lastIndex = 0;
            for (final match in urlMatches) {
              if (match.start > lastIndex) {
                children.add(TextSpan(
                  text: textRun.substring(lastIndex, match.start),
                  style: runStyle,
                ));
              }
              final url = match.group(0)!;
              final linkStyle = runStyle.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              );
              final recognizer = TapGestureRecognizer()
                ..onTap = () {
                  handleUrlLaunch(url);
                };
              _recognizers.add(recognizer);
              children.add(TextSpan(
                text: url,
                style: linkStyle,
                recognizer: recognizer,
              ));
              lastIndex = match.end;
            }
            if (lastIndex < textRun.length) {
              children.add(TextSpan(
                text: textRun.substring(lastIndex),
                style: runStyle,
              ));
            }
          }
        }
      }
    }

    return TextSpan(children: children, style: baseStyle);
  }

  List<RegExpMatch> findUrlMatches(String text) {
    final urlRegExp = RegExp(
      r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
      caseSensitive: false,
    );
    return urlRegExp.allMatches(text).toList();
  }

  Future<void> handleUrlLaunch(String url) async {
    try {
      String cleanUrl = url;
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      final uri = Uri.parse(cleanUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

class RangeTextEditingController extends TextEditingController {
  final RichTextEditingController parent;
  final int segmentIndex;
  final FocusNode? focusNode;
  int startOffset;
  int endOffset;

  TextSelection _localSelection = const TextSelection.collapsed(offset: 0);
  TextRange _composing = TextRange.empty;
  bool _isSettingValue = false;
  String _lastKnownText = "";
  String _lastParentText = "";
  bool _allowCapitalization = true;
  String? _autoCapitalizedChar;
  List<StyledChar>? _transientStyledChars;

  RangeTextEditingController({
    required this.parent,
    required this.segmentIndex,
    this.focusNode,
    required this.startOffset,
    required this.endOffset,
  }) {
    _lastParentText = parent.text;
    parent.addListener(_onParentChanged);
    _lastKnownText = text;
    _updateLocalSelectionFromParent();
  }

  @override
  void dispose() {
    parent.removeListener(_onParentChanged);
    super.dispose();
  }

  bool _hasCheckboxPrefix(String t) {
    return ParagraphBlockRegistry.hasAnyPrefix(t);
  }



  void _syncBackingValue() {
    int base = _localSelection.baseOffset;
    int extent = _localSelection.extentOffset;
    final prefixOffset = _hasCheckboxPrefix(_lastKnownText) ? 1 : 0;
    if (base < prefixOffset || base > _lastKnownText.length) {
      base = base.clamp(prefixOffset, _lastKnownText.length);
    }
    if (extent < prefixOffset || extent > _lastKnownText.length) {
      extent = extent.clamp(prefixOffset, _lastKnownText.length);
    }
    final clamped = _localSelection.copyWith(
      baseOffset: base,
      extentOffset: extent,
    );

    super.value = TextEditingValue(
      text: _lastKnownText,
      selection: clamped,
      composing: TextRange.empty,
    );
  }

  void _onParentChanged() {
    if (_isSettingValue) return;
    _transientStyledChars = null;
    if (parent.text != _lastParentText) {
      _lastParentText = parent.text;
    }
    final oldSelection = _localSelection;
    final oldText = _lastKnownText;

    _updateLocalSelectionFromParent();
    _lastKnownText = text;

    if (kImageDebug) {
      debugPrint("RangeTextEditingController[_onParentChanged] segmentIndex=$segmentIndex, parentSel=${parent.selection}, oldSel=$oldSelection, newSel=$_localSelection");
    }

    _syncBackingValue();

    if (_localSelection != oldSelection || _lastKnownText != oldText) {
      if (kImageDebug) {
        debugPrint("  Notifying listeners for segmentIndex=$segmentIndex due to selection/text change");
      }
      notifyListeners();
    }
  }

  void updateOffsets(int start, int end) {
    if (startOffset != start || endOffset != end || _lastParentText != parent.text) {
      if (kImageDebug) {
        debugPrint("RangeTextEditingController[updateOffsets] segmentIndex=$segmentIndex, start=$start, end=$end, parentTextLength=${parent.text.length}");
      }
      final oldSelection = _localSelection;
      final oldText = _lastKnownText;

      _transientStyledChars = null;
      startOffset = start;
      endOffset = end;
      _lastParentText = parent.text;
      _lastKnownText = text;
      _updateLocalSelectionFromParent();

      _syncBackingValue();

      if (_lastKnownText != oldText || _localSelection != oldSelection) {
        if (kImageDebug) {
          debugPrint("  Notifying listeners for segmentIndex=$segmentIndex inside updateOffsets");
        }
        notifyListeners();
      }
    }
  }

  /// Silently shifts start and end offsets by delta and synchronizes _lastParentText
  /// without triggering listener notifications, selection recalculation, or value mutations.
  void shiftOffsetsSilently(int delta) {
    _transientStyledChars = null;
    startOffset += delta;
    endOffset += delta;
    _lastParentText = parent.text;
  }

  void _updateLocalSelectionFromParent() {
    final parentSel = parent.selection;
    final range = getRange();
    if (parentSel.isValid && range.isValid && range.start >= 0) {
      final start = range.start;
      final end = range.end;

      if (parentSel.isCollapsed) {
        if (parentSel.baseOffset >= start && parentSel.baseOffset <= end) {
          final localOffset = parentSel.baseOffset - start;
          final prefixOffset = _hasCheckboxPrefix(text) ? 1 : 0;
          final clamped = localOffset < prefixOffset ? prefixOffset : localOffset;
          _localSelection = TextSelection.collapsed(offset: clamped);
        } else {
          _localSelection = const TextSelection.collapsed(offset: 0);
        }
      } else {
        final selStart = parentSel.start;
        final selEnd = parentSel.end;
        if (selEnd >= start && selStart <= end) {
          final clampedStart = selStart.clamp(start, end);
          final clampedEnd = selEnd.clamp(start, end);
          final isBackwards = parentSel.baseOffset > parentSel.extentOffset;

          final localBase = (isBackwards ? clampedEnd : clampedStart) - start;
          final localExtent = (isBackwards ? clampedStart : clampedEnd) - start;
          final prefixOffset = _hasCheckboxPrefix(text) ? 1 : 0;

          _localSelection = TextSelection(
            baseOffset: localBase < prefixOffset ? prefixOffset : localBase,
            extentOffset: localExtent < prefixOffset ? prefixOffset : localExtent,
          );
        } else {
          _localSelection = const TextSelection.collapsed(offset: 0);
        }
      }
    } else {
      _localSelection = const TextSelection.collapsed(offset: 0);
    }
  }

  TextRange getRange() {
    return TextRange(start: startOffset, end: endOffset);
  }

  TextAlign get lineAlignment {
    if (startOffset >= 0 && startOffset < parent.styledChars.length) {
      return parent.styledChars[startOffset].style.align;
    }
    return parent.currentActiveStyle.align;
  }

  @override
  String get text {
    final range = getRange();
    if (!range.isValid || range.isCollapsed || range.start < 0 || range.end > parent.styledChars.length) return "";
    final chars = parent.styledChars.sublist(range.start, range.end);
    return chars.map((sc) => sc.char).join();
  }

  @override
  set text(String newText) {
    value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  @override
  TextEditingValue get value {
    final currentText = text;
    _updateLocalSelectionFromParent();

    // Clamp selection to current text length to prevent out-of-bounds errors
    int base = _localSelection.baseOffset;
    int extent = _localSelection.extentOffset;
    final prefixOffset = _hasCheckboxPrefix(currentText) ? 1 : 0;

    if (base < prefixOffset || base > currentText.length) {
      base = base.clamp(prefixOffset, currentText.length);
    }
    if (extent < prefixOffset || extent > currentText.length) {
      extent = extent.clamp(prefixOffset, currentText.length);
    }

    final clampedSel = _localSelection.copyWith(
      baseOffset: base,
      extentOffset: extent,
    );

    // Sanitize composing range to prevent out-of-bounds selection/rendering issues
    TextRange clampedComposing = _composing;
    if (clampedComposing.isValid) {
      if (clampedComposing.start < 0 || clampedComposing.start > currentText.length ||
          clampedComposing.end < 0 || clampedComposing.end > currentText.length) {
        clampedComposing = TextRange.empty;
      }
    } else {
      clampedComposing = TextRange.empty;
    }

    return TextEditingValue(
      text: currentText,
      selection: clampedSel,
      composing: clampedComposing,
    );
  }

  @override
  set value(TextEditingValue newValue) {
    // Sanitize composing range on setting as well
    TextRange newComposing = newValue.composing;
    if (newComposing.isValid) {
      if (newComposing.start < 0 || newComposing.start > newValue.text.length ||
          newComposing.end < 0 || newComposing.end > newValue.text.length) {
        newComposing = TextRange.empty;
      }
    } else {
      newComposing = TextRange.empty;
    }
    _composing = newComposing;
    // Intercept and handle auto-capitalization override for checklists
    final newText = newValue.text;
    final oldText = text;
    final bool hasPrefix = ParagraphBlockRegistry.hasAnyPrefix(newText);

    if (hasPrefix) {
      if (newText.length == 2 && oldText.length == 1) {
        if (_allowCapitalization) {
          final firstChar = newText[0];
          final secondChar = newText[1];
          final upperSecond = secondChar.toUpperCase();
          if (secondChar != upperSecond) {
            newValue = newValue.copyWith(
              text: firstChar + upperSecond,
            );
            _allowCapitalization = false;
            _autoCapitalizedChar = upperSecond;
          }
        }
      } else if (newText.length == 1 && oldText.length == 2) {
        // User backspaced the capitalized character!
        final secondChar = oldText[1];
        if (secondChar == _autoCapitalizedChar) {
          final firstChar = oldText[0];
          final lowerSecond = secondChar.toLowerCase();
          newValue = newValue.copyWith(
            text: firstChar + lowerSecond,
            selection: const TextSelection.collapsed(offset: 2),
          );
          _allowCapitalization = false;
          _autoCapitalizedChar = null;
        } else {
          _allowCapitalization = true;
          _autoCapitalizedChar = null;
        }
      } else if (newText.length == 1) {
        _allowCapitalization = true;
        _autoCapitalizedChar = null;
      }
    } else {
      _allowCapitalization = true;
      _autoCapitalizedChar = null;
    }

    _isSettingValue = true;
    try {
      final prefixOffset = _hasCheckboxPrefix(newValue.text) ? 1 : 0;
      int base = newValue.selection.baseOffset;
      int extent = newValue.selection.extentOffset;
      if (newValue.selection.isValid) {
        if (base < prefixOffset) base = prefixOffset;
        if (base > newValue.text.length) base = newValue.text.length;
        if (extent < prefixOffset) extent = prefixOffset;
        if (extent > newValue.text.length) extent = newValue.text.length;
      }
      final clampedSel = newValue.selection.copyWith(
        baseOffset: base,
        extentOffset: extent,
      );
      newValue = newValue.copyWith(selection: clampedSel);
      _localSelection = clampedSel;

      final range = getRange();
      if (!range.isValid || range.start < 0 || range.end > parent.styledChars.length) return;

      final start = range.start;
      final end = range.end;

      final newText = newValue.text;
      final oldText = text;

      if (newText == oldText) {
        final bool hasFocus = focusNode?.hasFocus ?? true;
        if (hasFocus) {
          TextSelection parentSel = const TextSelection.collapsed(offset: -1);
          if (clampedSel.isValid) {
            parentSel = TextSelection(
              baseOffset: start + clampedSel.baseOffset,
              extentOffset: start + clampedSel.extentOffset,
            );
          }
          parent.value = parent.value.copyWith(selection: parentSel);
        }
        return;
      }

      final oldSegmentChars = parent.styledChars.sublist(start, end);

      int prefixLen = 0;
      while (prefixLen < oldText.length &&
          prefixLen < newText.length &&
          oldText[prefixLen] == newText[prefixLen]) {
        prefixLen++;
      }

      int suffixLen = 0;
      while (suffixLen < oldText.length - prefixLen &&
          suffixLen < newText.length - prefixLen &&
          oldText[oldText.length - 1 - suffixLen] == newText[newText.length - 1 - suffixLen]) {
        suffixLen++;
      }

      int insertStart = prefixLen;
      final int insertEnd = newText.length - suffixLen;
      final String insertedText = newText.substring(insertStart, insertEnd);

      // Fix: The mobile IME sometimes bundles extra characters with the newline
      // in a single set value call (e.g. a trailing space inserted automatically
      // after an emoji, giving insertedText = " \n" instead of "\n").
      // We detect this by checking if insertedText ends with '\n', then fold
      // any pre-newline characters into the prefix so that the newline-insert
      // path fires correctly.
      final bool isNewlineInsert = insertedText.endsWith('\n');
      final int adjustedInsertStart = isNewlineInsert && insertedText.length > 1
          ? insertEnd - 1   // point insertStart at the '\n' only
          : insertStart;

      if (isNewlineInsert) {
        // If the IME bundled extra chars before the '\n' (e.g. an auto-space
        // after emoji giving " \n"), commit those chars into oldSegmentChars
        // first so the split point (adjustedInsertStart) is correct.
        List<StyledChar> effectiveSegmentChars = List.from(oldSegmentChars);
        final int adjustedPrefixLen;
        if (adjustedInsertStart > insertStart) {
          // There are pre-newline chars to commit (e.g. the auto-space).
          final preNewlineText = newText.substring(insertStart, adjustedInsertStart);
          final Style baseStyle = parent.currentActiveStyle;
          final List<StyledChar> preChars = preNewlineText
              .split('')
              .map((c) => StyledChar(char: c, style: baseStyle))
              .toList();
          // Insert them at insertStart within the segment chars
          effectiveSegmentChars.insertAll(insertStart, preChars);
          adjustedPrefixLen = adjustedInsertStart;
        } else {
          adjustedPrefixLen = prefixLen;
        }

        final cleanText = newValue.text.substring(0, adjustedInsertStart) +
            newValue.text.substring(adjustedInsertStart + 1);
        final baseOffset = clampedSel.baseOffset;
        final extentOffset = clampedSel.extentOffset;
        final cleanSelection = TextSelection(
          baseOffset: baseOffset > adjustedInsertStart ? baseOffset - 1 : baseOffset,
          extentOffset: extentOffset > adjustedInsertStart ? extentOffset - 1 : extentOffset,
        );

        final List<StyledChar> tempChars = [];
        tempChars.addAll(effectiveSegmentChars.take(adjustedInsertStart));
        tempChars.add(StyledChar(char: '\n', style: parent.currentActiveStyle));
        tempChars.addAll(effectiveSegmentChars.skip(adjustedInsertStart));
        _transientStyledChars = tempChars;

        // Accept the new value temporarily and clear composing range
        _composing = TextRange.empty;
        super.value = newValue.copyWith(composing: TextRange.empty);

        // Perform structural parent document layout shift in a post-frame callback
        // to avoid EditableText state reconciliation conflicts.
        debugPrint("[PostFrame] Scheduling layout shift callback for segmentIndex=$segmentIndex");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint("[PostFrame] Running layout shift callback for segmentIndex=$segmentIndex, parent.hasListeners=${parent.hasListeners}");
          if (!parent.hasListeners) return;

          if (start < 0 || end > parent.styledChars.length || start > end) {
            debugPrint("RangeTextEditingController[PostFrame] ABORTED due to out-of-bounds start=$start, end=$end, parent.length=${parent.styledChars.length}");
            return;
          }

          final List<StyledChar> newSegmentChars = [];
          newSegmentChars.addAll(effectiveSegmentChars.take(adjustedPrefixLen));

          Style baseStyle = parent.currentActiveStyle;
          if (adjustedPrefixLen > 0 && adjustedPrefixLen - 1 < effectiveSegmentChars.length) {
            baseStyle = effectiveSegmentChars[adjustedPrefixLen - 1].style;
          } else if (effectiveSegmentChars.isNotEmpty) {
            baseStyle = effectiveSegmentChars.first.style;
          }

          if (baseStyle.heading != 'normal') {
            baseStyle = baseStyle.copyWith(heading: 'normal');
          }
          if (baseStyle.listType == 'checkbox') {
            baseStyle = baseStyle.copyWith(checked: false, strikethrough: false);
          }

          bool isLineEmptyList = false;
          final oldBehavior = ParagraphBlockRegistry.getBehaviorForText(oldText);
          if (oldBehavior != null && oldText.length == oldBehavior.prefixLen) {
            isLineEmptyList = true;
          }

          if (isLineEmptyList) {
            newSegmentChars.clear();
          } else {
            final listStyle = baseStyle.copyWith(checked: false, strikethrough: false);
            newSegmentChars.add(StyledChar(char: '\n', style: listStyle));
            final behavior = ParagraphBlockRegistry.getBehaviorForListType(baseStyle.listType);
            if (behavior != null) {
              newSegmentChars.add(behavior.getPrefixChar(listStyle));
            }
          }

          newSegmentChars.addAll(effectiveSegmentChars.skip(effectiveSegmentChars.length - suffixLen));

          final List<StyledChar> updatedParentChars = List.from(parent.styledChars);
          updatedParentChars.removeRange(start, end);
          updatedParentChars.insertAll(start, newSegmentChars);

          int selectionShift = 0;
          if (isLineEmptyList) {
            final int oldPrefixLen = oldBehavior?.prefixLen ?? 1;
            selectionShift = -(oldPrefixLen + 1);
          } else {
            final behavior = ParagraphBlockRegistry.getBehaviorForListType(baseStyle.listType);
            if (behavior != null) {
              selectionShift = behavior.prefixLen;
            }
          }

          final TextSelection parentSel = TextSelection(
            baseOffset: start + newValue.selection.baseOffset + selectionShift,
            extentOffset: start + newValue.selection.extentOffset + selectionShift,
          );

          parent.styledChars = updatedParentChars;
          parent.value = TextEditingValue(
            text: updatedParentChars.map((sc) => sc.char).join(),
            selection: parentSel,
          );

          // Force local segment controller to reflect the clean text and notify listeners
          // to override the TextField's internal stale value (which contains '\n').
          _localSelection = cleanSelection;
          _lastKnownText = cleanText;
          super.value = TextEditingValue(
            text: _lastKnownText,
            selection: _localSelection,
            composing: _composing,
          );
          notifyListeners();
        });
      } else {
        final List<StyledChar> newSegmentChars = [];
        newSegmentChars.addAll(oldSegmentChars.take(prefixLen));

        Style baseStyle = parent.currentActiveStyle;
        if (oldSegmentChars.isNotEmpty && !oldSegmentChars.first.style.checked) {
          baseStyle = baseStyle.copyWith(checked: false, strikethrough: false);
        }

        if (insertedText.length > 1) {
          final parsed = parseMarkdownToStyledChars(insertedText, baseStyle: baseStyle);
          newSegmentChars.addAll(parsed);
        } else {
          for (int i = insertStart; i < insertEnd; i++) {
            newSegmentChars.add(StyledChar(char: newText[i], style: baseStyle));
          }
        }

        newSegmentChars.addAll(oldSegmentChars.skip(oldSegmentChars.length - suffixLen));
        _transientStyledChars = newSegmentChars;

        // Non-structural edit: Update local super.value synchronously
        super.value = newValue;

        final List<StyledChar> updatedParentChars = List.from(parent.styledChars);
        updatedParentChars.removeRange(start, end);
        updatedParentChars.insertAll(start, newSegmentChars);

        parent.styledChars = updatedParentChars;
        parent.value = TextEditingValue(
          text: updatedParentChars.map((sc) => sc.char).join(),
          selection: TextSelection(
            baseOffset: start + newValue.selection.baseOffset,
            extentOffset: start + newValue.selection.extentOffset,
          ),
        );
      }
    } finally {
      _isSettingValue = false;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final range = getRange();
    final List<StyledChar> segmentChars;
    final String segmentText;

    if (_transientStyledChars != null) {
      segmentChars = _transientStyledChars!;
      segmentText = super.value.text;
    } else {
      if (!range.isValid || range.isCollapsed || range.start < 0 || range.end > parent.styledChars.length) {
        return TextSpan(text: '', style: style);
      }
      segmentChars = parent.styledChars.sublist(range.start, range.end);
      segmentText = segmentChars.map((sc) => sc.char).join();
    }

    final baseStyle = style ?? const TextStyle();
    final List<InlineSpan> children = [];

    final isCheckedCheckbox = segmentChars.isNotEmpty && segmentChars.first.char == '\u2611';

    int i = 0;
    while (i < segmentChars.length) {
      final sc = segmentChars[i];
      final start = i;
      final currentStyle = sc.style;
      i++;

      while (i < segmentChars.length && segmentChars[i].style == currentStyle) {
        i++;
      }

      String textRun = segmentText.substring(start, i);

      if (start == 0 && textRun.isNotEmpty) {
        final firstChar = textRun[0];
        if (firstChar == '•' ||
            firstChar == '\u2610' ||
            firstChar == '\u2611' ||
            firstChar == '›' ||
            firstChar == '\u2008') {
          children.add(TextSpan(
            text: firstChar,
            style: baseStyle.copyWith(
              fontSize: 0.001,
              color: Colors.transparent,
              letterSpacing: 0,
              wordSpacing: 0,
              height: 0.001,
            ),
          ));
          textRun = textRun.substring(1);
        }
      }

      Color? displayColor = currentStyle.color ?? baseStyle.color;
      if (isCheckedCheckbox) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final defaultColor = isDark ? Colors.white : Colors.black;
        displayColor = (displayColor ?? defaultColor).withOpacity(0.4);
      }

      TextStyle runStyle = baseStyle.copyWith(
        fontWeight: currentStyle.bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: currentStyle.listType == 'quote' ? FontStyle.italic : (currentStyle.italic ? FontStyle.italic : FontStyle.normal),
        color: currentStyle.listType == 'quote' ? (currentStyle.color ?? baseStyle.color)?.withOpacity(0.7) : displayColor,
        backgroundColor: currentStyle.highlight,
      );

      final hasLineThrough = currentStyle.strikethrough || isCheckedCheckbox;
      if (currentStyle.underline && hasLineThrough) {
        runStyle = runStyle.copyWith(
          decoration: TextDecoration.combine(
              [TextDecoration.underline, TextDecoration.lineThrough]),
        );
      } else if (currentStyle.underline) {
        runStyle = runStyle.copyWith(decoration: TextDecoration.underline);
      } else if (hasLineThrough) {
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

      if (currentStyle.linkUrl != null) {
        final linkStyle = runStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            parent.handleUrlLaunch(currentStyle.linkUrl!);
          };
        children.add(TextSpan(
          text: textRun,
          style: linkStyle,
          recognizer: recognizer,
        ));
      } else {
        final urlMatches = parent.findUrlMatches(textRun);
        if (urlMatches.isEmpty) {
          children.add(TextSpan(
            text: textRun,
            style: runStyle,
          ));
        } else {
          int lastIndex = 0;
          for (final match in urlMatches) {
            if (match.start > lastIndex) {
              children.add(TextSpan(
                text: textRun.substring(lastIndex, match.start),
                style: runStyle,
              ));
            }
            final url = match.group(0)!;
            final linkStyle = runStyle.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            );
            final recognizer = TapGestureRecognizer()
              ..onTap = () {
                parent.handleUrlLaunch(url);
              };
            children.add(TextSpan(
              text: url,
              style: linkStyle,
              recognizer: recognizer,
            ));
            lastIndex = match.end;
          }
          if (lastIndex < textRun.length) {
            children.add(TextSpan(
              text: textRun.substring(lastIndex),
              style: runStyle,
            ));
          }
        }
      }
    }

    return TextSpan(children: children, style: baseStyle);
  }
}
List<StyledChar> parseMarkdownToStyledChars(String markdown, {Style? baseStyle}) {
  final List<StyledChar> result = [];
  final lines = markdown.split('\n');
  final fallbackStyle = baseStyle ?? const Style();

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];

    int indent = (i == 0) ? fallbackStyle.indent : 0;
    int spaces = 0;
    while (spaces < line.length && (line[spaces] == ' ' || line[spaces] == '\t')) {
      if (line[spaces] == '\t') {
        indent += 1;
        spaces++;
      } else {
        spaces++;
        if (spaces < line.length && line[spaces] == ' ') {
          indent += 1;
          spaces++;
        }
      }
    }
    spaces = spaces.clamp(0, line.length);
    line = line.substring(spaces);

    // Parse dividers
    if (line.trim() == '---') {
      result.add(StyledChar(
        char: '\u2014',
        style: const Style(
          isDivider: true,
        ),
      ));
      if (i < lines.length - 1) {
        result.add(StyledChar(
          char: '\n',
          style: const Style(),
        ));
      }
      continue;
    }

    final lineFallback = (i == 0) ? fallbackStyle : const Style();
    TextAlign align = lineFallback.align;
    String heading = lineFallback.heading;
    String listType = lineFallback.listType;
    bool checked = lineFallback.checked;

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
        int closeBracket = (idx + 2 <= line.length) ? line.indexOf(']', idx + 2) : -1;
        if (closeBracket != -1 &&
            closeBracket + 1 < line.length &&
            line[closeBracket + 1] == '(') {
          int closeParenthesis = (closeBracket + 2 <= line.length)
              ? line.indexOf(')', closeBracket + 2)
              : -1;
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
                bold: bold || fallbackStyle.bold,
                italic: italic || fallbackStyle.italic,
                underline: underline || fallbackStyle.underline,
                strikethrough: strikethrough || fallbackStyle.strikethrough,
                heading: heading,
                align: align,
                listType: listType,
                checked: checked,
                indent: indent,
                imageUrl: cleanUrl,
                imageWidth: width,
                imageHeight: height,
                imageCaption: (alt.isNotEmpty && alt != 'Image') ? alt : null,
                color: color ?? fallbackStyle.color,
                highlight: highlight ?? fallbackStyle.highlight,
              ),
            ));
            idx = closeParenthesis + 1;
            continue;
          }
        }
      }

      if (line[idx] == '[' && idx + 1 < line.length) {
        int closeBracket = line.indexOf(']', idx + 1);
        if (closeBracket != -1 &&
            closeBracket + 1 < line.length &&
            line[closeBracket + 1] == '(') {
          int closeParenthesis = line.indexOf(')', closeBracket + 2);
          if (closeParenthesis != -1) {
            final linkText = line.substring(idx + 1, closeBracket);
            final url = line.substring(closeBracket + 2, closeParenthesis);

            for (int k = 0; k < linkText.length; k++) {
              result.add(StyledChar(
                char: linkText[k],
                style: Style(
                  bold: bold || fallbackStyle.bold,
                  italic: italic || fallbackStyle.italic,
                  underline: underline || fallbackStyle.underline,
                  strikethrough: strikethrough || fallbackStyle.strikethrough,
                  heading: heading,
                  align: align,
                  listType: listType,
                  checked: checked,
                  indent: indent,
                  color: color ?? fallbackStyle.color,
                  highlight: highlight ?? fallbackStyle.highlight,
                  linkUrl: url,
                ),
              ));
            }
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
            bold: bold || fallbackStyle.bold,
            italic: italic || fallbackStyle.italic,
            underline: underline || fallbackStyle.underline,
            strikethrough: listType == 'checkbox' ? (checked || strikethrough) : (strikethrough || fallbackStyle.strikethrough),
            heading: heading,
            align: align,
            listType: listType,
            checked: checked,
            indent: indent,
            color: color ?? fallbackStyle.color,
            highlight: highlight ?? fallbackStyle.highlight,
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
          indent: indent,
          bold: fallbackStyle.bold,
          italic: fallbackStyle.italic,
          underline: fallbackStyle.underline,
          strikethrough: fallbackStyle.strikethrough,
          color: fallbackStyle.color,
          highlight: fallbackStyle.highlight,
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

    final linkUrl = style.linkUrl;
    if (linkUrl != null) {
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

      int runEnd = i;
      while (runEnd < lineChars.length && lineChars[runEnd].style.linkUrl == linkUrl) {
        runEnd++;
      }
      final linkChars = lineChars.sublist(i, runEnd);
      i = runEnd - 1;

      final clearedLinkChars = linkChars.map((sc) => StyledChar(
        char: sc.char,
        style: sc.style.copyWith(clearLink: true),
      )).toList();

      final linkText = generateInlineMarkdown(clearedLinkChars);
      sb.write('[$linkText]($linkUrl)');
      continue;
    }

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
    final bool isChecked = style.checked || (lineChars.isNotEmpty && lineChars.first.char == '\u2611');

    String lineContent = "";
    if (style.isDivider) {
      lineContent = '---';
    } else {
      List<StyledChar> contentChars = List.from(lineChars);
      if (contentChars.isNotEmpty &&
          (contentChars.first.char == '•' ||
              contentChars.first.char == '›' ||
              contentChars.first.char == '\u2610' ||
              contentChars.first.char == '\u2611' ||
              contentChars.first.char == '\u2008')) {
        contentChars.removeAt(0);
      }
      lineContent = generateInlineMarkdown(contentChars);
    }

    final String indentSpaces = '  ' * style.indent;
    if (style.listType == 'checkbox' || (lineChars.isNotEmpty && (lineChars.first.char == '\u2610' || lineChars.first.char == '\u2611'))) {
      lineContent = isChecked ? '${indentSpaces}- [x] $lineContent' : '${indentSpaces}- [ ] $lineContent';
    } else if (style.listType == 'bullet') {
      lineContent = '${indentSpaces}- $lineContent';
    } else if (style.listType == 'quote') {
      lineContent = '${indentSpaces}> $lineContent';
    } else if (style.listType == 'number') {
      lineContent = '${indentSpaces}1. $lineContent';
    } else if (style.indent > 0) {
      lineContent = '$indentSpaces$lineContent';
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
