import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../services/vault_service.dart';
import '../widgets/folder_selector_dialog.dart';
import '../widgets/export_dialog.dart';
import '../widgets/rich_text_controller.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final String defaultCategory;
  final String defaultNoteType;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.defaultCategory = 'Uncategorized',
    this.defaultNoteType = 'text',
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  late final TextEditingController _contentController;
  final _tagController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _pageController = PageController();
  final GlobalKey _textFieldKey = GlobalKey();
  int _currentPage = 0;
  
  int _colorIndex = 0;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;
  String _category = 'Uncategorized';
  String _noteType = 'text'; // 'text' or 'checklist'
  bool _isLocked = false;
  DateTime? _reminderTime;

  List<String> _tags = [];
  List<Map<String, dynamic>> _attachments = [];
  List<Map<String, dynamic>> _checklistItems = []; // [{'text': '...', 'done': false}]
  List<TextEditingController> _checklistControllers = [];

  // Folders & Habits state
  String? _folderId;
  bool _isHabit = false;
  String _habitRecurrence = 'none';
  int _habitStreak = 0;
  DateTime? _habitLastCompleted;

  bool _hasChanges = false;
  bool _isPreviewMarkdown = false;
  bool _isPageSettled = false;
  int _wordCount = 0;
  int _charCount = 0;
  bool _isSaving = false;

  // Zen Focus Mode state
  Timer? _zenTimer;
  bool _isZenTyping = false;

  // Media Pickers and Record helpers
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Audio Playback state
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _colorIndex = widget.note!.colorValue;
      _isPinned = widget.note!.isPinned;
      _isFavorite = widget.note!.isFavorite;
      _isArchived = widget.note!.isArchived;
      _category = widget.note!.category;
      _noteType = widget.note!.noteType;
      _tags = List.from(widget.note!.tags);
      _attachments = List.from(widget.note!.attachments);
      _isLocked = widget.note!.isLocked;
      _reminderTime = widget.note!.reminderTime;
      _folderId = widget.note!.folderId;
      _isHabit = widget.note!.isHabit;
      _habitRecurrence = widget.note!.habitRecurrence;
      _habitStreak = widget.note!.habitStreak;
      _habitLastCompleted = widget.note!.habitLastCompleted;
      
      if (_noteType == 'checklist') {
        try {
          final decoded = jsonDecode(widget.note!.content) as List<dynamic>;
          _checklistItems = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (e) {
          _checklistItems = [];
        }
        _checklistControllers = _checklistItems.map((item) => TextEditingController(text: item['text'] ?? "")).toList();
        _contentController = TextEditingController();
      } else {
        _contentController = RichTextEditingController(markdown: widget.note!.content);
        final richCtrl = _contentController as RichTextEditingController;
        richCtrl.onStyleChanged = () {
          if (mounted) setState(() {});
        };
        richCtrl.onReplaceImage = _showReplaceGalleryBottomSheet;
      }
    } else {
      _category = widget.defaultCategory;
      _noteType = widget.defaultNoteType;
      _folderId = null;
      _isHabit = false;
      _habitRecurrence = 'none';
      _habitStreak = 0;
      _habitLastCompleted = null;

      if (_noteType == 'text') {
        _contentController = RichTextEditingController();
        final richCtrl = _contentController as RichTextEditingController;
        richCtrl.onStyleChanged = () {
          if (mounted) setState(() {});
        };
        richCtrl.onReplaceImage = _showReplaceGalleryBottomSheet;
      } else {
        _contentController = TextEditingController();
      }
    }
    _calculateCounts();

    _titleController.addListener(_onTitleTextChanged);
    _contentController.addListener(_onContentTextChanged);
    
    _contentFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Audio player listener
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _currentlyPlayingPath = null;
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        if (route.animation!.isCompleted) {
          if (mounted) {
            setState(() {
              _isPageSettled = true;
            });
            if (widget.note == null && _noteType == 'text') {
              _contentFocusNode.requestFocus();
            }
          }
        } else {
          void listener(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              route.animation!.removeStatusListener(listener);
              if (mounted) {
                setState(() {
                  _isPageSettled = true;
                });
                if (widget.note == null && _noteType == 'text') {
                  _contentFocusNode.requestFocus();
                }
              }
            }
          }
          route.animation!.addStatusListener(listener);
        }
      } else {
        if (mounted) {
          setState(() {
            _isPageSettled = true;
          });
          if (widget.note == null && _noteType == 'text') {
            _contentFocusNode.requestFocus();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _contentFocusNode.dispose();
    _pageController.dispose();
    for (final controller in _checklistControllers) {
      controller.dispose();
    }
    _recordTimer?.cancel();
    _zenTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startZenTimer() {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    if (!provider.isZenModeEnabled) {
      if (_isZenTyping) {
        setState(() {
          _isZenTyping = false;
        });
      }
      return;
    }

    _zenTimer?.cancel();
    if (!_isZenTyping) {
      setState(() {
        _isZenTyping = true;
      });
    }
    _zenTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isZenTyping = false;
        });
      }
    });
  }

  void _onTitleTextChanged() {
    _calculateCounts();
    setState(() {
      _hasChanges = true;
    });
  }

  void _onContentTextChanged() {
    _calculateCounts();
    _startZenTimer();
    setState(() {
      _hasChanges = true;
    });
  }

  TextAlign _getCurrentLineAlignment() {
    if (_contentController is RichTextEditingController) {
      final controller = _contentController as RichTextEditingController;
      final sel = controller.selection;
      if (sel.isValid && sel.start >= 0 && sel.start < controller.styledChars.length) {
        return controller.styledChars[sel.start].style.align;
      }
    }
    return TextAlign.left;
  }

  void _calculateCounts() {
    String text = "";
    if (_noteType == 'checklist') {
      text = _checklistItems.map((e) => e['text'].toString()).join(" ");
    } else {
      text = _contentController.text.trim();
    }
    setState(() {
      _charCount = text.length;
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    });
  }

  // --- Checklist operations ---
  void _syncControllers() {
    while (_checklistControllers.length < _checklistItems.length) {
      final index = _checklistControllers.length;
      final text = _checklistItems[index]['text'] ?? '';
      _checklistControllers.add(TextEditingController(text: text));
    }
    while (_checklistControllers.length > _checklistItems.length) {
      _checklistControllers.removeLast().dispose();
    }
    for (int i = 0; i < _checklistItems.length; i++) {
      final text = _checklistItems[i]['text'] ?? '';
      if (_checklistControllers[i].text != text) {
        _checklistControllers[i].text = text;
      }
    }
  }

  void _addChecklistItem() {
    _startZenTimer();
    setState(() {
      _checklistItems.add({'text': '', 'done': false});
      _checklistControllers.add(TextEditingController());
      _hasChanges = true;
      _calculateCounts();
    });
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _checklistItems.removeAt(index);
      if (index < _checklistControllers.length) {
        _checklistControllers.removeAt(index).dispose();
      }
      _hasChanges = true;
      _calculateCounts();
    });
  }


  Future<void> _showGalleryBottomSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final List<String> sampleUrls = [
      'https://images.unsplash.com/photo-1517842645767-c639042777db?w=500&q=80',
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=500&q=80',
      'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=500&q=80',
      'https://images.unsplash.com/photo-1472214222541-d510753a4907?w=500&q=80',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&q=80',
    ];

    List<String> selectedPaths = [];

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Insert Photo",
                          style: GoogleFonts.outfit(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedPaths.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _insertSelectedImages(selectedPaths);
                            },
                            child: Text(
                              "Insert (${selectedPaths.length})",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: sampleUrls.length + 2,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return InkWell(
                              onTap: () async {
                                Navigator.pop(context);
                                final picked = await _imagePicker.pickImage(source: ImageSource.camera);
                                if (picked != null) {
                                  _insertSelectedImages(['file://${picked.path}']);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 28),
                                    SizedBox(height: 4),
                                    Text("Camera", style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          } else if (index == 1) {
                            return InkWell(
                              onTap: () async {
                                Navigator.pop(context);
                                final pickedList = await _imagePicker.pickMultiImage();
                                if (pickedList.isNotEmpty) {
                                  _insertSelectedImages(pickedList.map((x) => 'file://${x.path}').toList());
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_outlined, size: 28),
                                    SizedBox(height: 4),
                                    Text("System Gallery", style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            final url = sampleUrls[index - 2];
                            final isSelected = selectedPaths.contains(url);
                            final selectIdx = selectedPaths.indexOf(url) + 1;

                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  if (isSelected) {
                                    selectedPaths.remove(url);
                                  } else {
                                    selectedPaths.add(url);
                                  }
                                });
                              },
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: theme.colorScheme.primary, width: 3),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: theme.colorScheme.primary,
                                        child: Text(
                                          "$selectIdx",
                                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _insertSelectedImages(List<String> paths) async {
    for (final path in paths) {
      if (_noteType == 'text') {
        final String markdownImage = '![Image]($path)';
        _insertTextAtCursor(markdownImage);
      } else {
        setState(() {
          _attachments.add({
            'type': 'image',
            'path': path.startsWith('file://') ? path.substring(7) : path,
          });
          _hasChanges = true;
        });
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<void> _showReplaceGalleryBottomSheet(int index) async {
    final theme = Theme.of(context);
    final List<String> sampleUrls = [
      'https://images.unsplash.com/photo-1517842645767-c639042777db?w=500&q=80',
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=500&q=80',
      'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=500&q=80',
      'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=500&q=80',
      'https://images.unsplash.com/photo-1472214222541-d510753a4907?w=500&q=80',
      'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&q=80',
    ];

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Replace Photo",
                  style: GoogleFonts.outfit(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: sampleUrls.length + 2,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, gridIndex) {
                      if (gridIndex == 0) {
                        return InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final picked = await _imagePicker.pickImage(source: ImageSource.camera);
                            if (picked != null) {
                              _replaceImage(index, 'file://${picked.path}');
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, size: 28),
                                SizedBox(height: 4),
                                Text("Camera", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      } else if (gridIndex == 1) {
                        return InkWell(
                          onTap: () async {
                            Navigator.pop(context);
                            final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                            if (picked != null) {
                              _replaceImage(index, 'file://${picked.path}');
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 28),
                                SizedBox(height: 4),
                                Text("System Gallery", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      } else {
                        final url = sampleUrls[gridIndex - 2];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _replaceImage(index, url);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _replaceImage(int index, String newPath) {
    if (_contentController is RichTextEditingController) {
      final controller = _contentController as RichTextEditingController;
      if (index >= 0 && index < controller.styledChars.length) {
        controller.styledChars[index] = StyledChar(
          char: controller.styledChars[index].char,
          style: controller.styledChars[index].style.copyWith(
            imageUrl: newPath,
          ),
        );
        final newTextStr = controller.styledChars.map((sc) => sc.char).join();
        controller.value = TextEditingValue(
          text: newTextStr,
          selection: controller.selection,
        );
        setState(() {
          _hasChanges = true;
        });
      }
    }
  }

  void _moveInlineImage(int oldIndex, Offset globalOffset) {
    if (_contentController is! RichTextEditingController) return;
    final controller = _contentController as RichTextEditingController;
    
    final renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final renderEditable = _findRenderEditable(renderBox);
    if (renderEditable == null) return;
    
    final localOffset = renderEditable.globalToLocal(globalOffset);
    final textPosition = renderEditable.getPositionForPoint(localOffset);
    int targetIndex = textPosition.offset;
    
    if (targetIndex < 0 || targetIndex > controller.styledChars.length) return;
    
    setState(() {
      final char = controller.styledChars.removeAt(oldIndex);
      int insertIdx = targetIndex;
      if (insertIdx > oldIndex) {
        insertIdx--;
      }
      insertIdx = insertIdx.clamp(0, controller.styledChars.length);
      controller.styledChars.insert(insertIdx, char);
      
      final newTextStr = controller.styledChars.map((sc) => sc.char).join();
      controller.value = TextEditingValue(
        text: newTextStr,
        selection: TextSelection.collapsed(offset: insertIdx),
      );
      _hasChanges = true;
    });
  }

  void _hoverInlineImage(Offset globalOffset) {
    if (_contentController is! RichTextEditingController) return;
    final controller = _contentController as RichTextEditingController;
    
    final renderBox = _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final renderEditable = _findRenderEditable(renderBox);
    if (renderEditable == null) return;
    
    final localOffset = renderEditable.globalToLocal(globalOffset);
    final textPosition = renderEditable.getPositionForPoint(localOffset);
    int targetIndex = textPosition.offset;
    
    if (targetIndex >= 0 && targetIndex <= controller.styledChars.length) {
      controller.selection = TextSelection.collapsed(offset: targetIndex);
    }
  }

  RenderEditable? _findRenderEditable(RenderObject? root) {
    if (root is RenderEditable) return root;
    RenderEditable? result;
    root?.visitChildren((child) {
      final found = _findRenderEditable(child);
      if (found != null) {
        result = found;
      }
    });
    return result;
  }

  void _toggleNoteType() {
    setState(() {
      if (_noteType == 'text') {
        // Convert plain text to checklist
        final lines = _contentController.text.split('\n');
        _checklistItems = lines
            .where((line) => line.trim().isNotEmpty)
            .map((line) {
              String cleanLine = line.trim();
              bool isDone = false;
              if (cleanLine.startsWith('- [ ]')) {
                cleanLine = cleanLine.substring(5).trim();
              } else if (cleanLine.startsWith('- [x]')) {
                cleanLine = cleanLine.substring(5).trim();
                isDone = true;
              } else if (cleanLine.startsWith('-')) {
                cleanLine = cleanLine.substring(1).trim();
              } else if (cleanLine.startsWith('\u2610')) {
                cleanLine = cleanLine.substring(1).trim();
              } else if (cleanLine.startsWith('\u2611')) {
                cleanLine = cleanLine.substring(1).trim();
                isDone = true;
              } else if (cleanLine.startsWith('•')) {
                cleanLine = cleanLine.substring(1).trim();
              }
              return {'text': cleanLine, 'done': isDone};
            })
            .toList();
        if (_checklistItems.isEmpty) {
          _checklistItems.add({'text': '', 'done': false});
        }
        for (final c in _checklistControllers) {
          c.dispose();
        }
        _checklistControllers = _checklistItems.map((item) => TextEditingController(text: item['text'] ?? "")).toList();
        _noteType = 'checklist';
      } else {
        // Convert checklist to plain text
        final text = _checklistItems.map((item) {
          final String prefix = item['done'] == true ? '- [x] ' : '- [ ] ';
          return '$prefix${item['text'] ?? ""}';
        }).join('\n');
        
        if (_contentController is RichTextEditingController) {
          (_contentController as RichTextEditingController).setMarkdown(text);
        } else {
          _contentController.text = text;
        }
        _noteType = 'text';
      }
      _hasChanges = true;
    });
  }

  // --- Audio Recording operations ---
  Future<void> _startRecording() async {
    try {
      final isGranted = await Permission.microphone.request().isGranted;
      if (!mounted) return;

      if (isGranted) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });
        });
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission denied")),
        );
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        setState(() {
          _attachments.add({
            'type': 'voice',
            'path': path,
            'duration': _recordDuration,
          });
          _hasChanges = true;
        });
      }
    } catch (e) {
      debugPrint("Error stopping record: $e");
    }
  }

  Future<void> _toggleAudioPlay(String path) async {
    try {
      if (_currentlyPlayingPath == path) {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.resume();
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _currentlyPlayingPath = path;
        });
      }
    } catch (e) {
      debugPrint("Playback error: $e");
    }
  }

  // --- Save Operations ---
  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim();
      final content = _noteType == 'checklist' 
          ? jsonEncode(_checklistItems) 
          : (_contentController is RichTextEditingController
              ? generateMarkdownFromStyledChars((_contentController as RichTextEditingController).styledChars).trim()
              : _contentController.text.trim());

      if (title.isEmpty && content.isEmpty) return;

      final provider = Provider.of<NotesProvider>(context, listen: false);

      if (widget.note == null) {
        await provider.addNote(
          title: title,
          content: content,
          colorIndex: _colorIndex,
          category: _category,
          noteType: _noteType,
          tags: _tags,
          attachments: _attachments,
          isPinned: _isPinned,
          isFavorite: _isFavorite,
          isArchived: _isArchived,
          isLocked: _isLocked,
          reminderTime: _reminderTime,
          folderId: _folderId,
          isHabit: _isHabit,
          habitRecurrence: _habitRecurrence,
        );
      } else {
        final updatedNote = widget.note!.copyWith(
          title: title,
          content: content,
          colorValue: _colorIndex,
          category: _category,
          noteType: _noteType,
          tags: _tags,
          attachments: _attachments,
          isPinned: _isPinned,
          isFavorite: _isFavorite,
          isArchived: _isArchived,
          isLocked: _isLocked,
          reminderTime: _reminderTime,
          folderId: _folderId,
          isHabit: _isHabit,
          habitRecurrence: _habitRecurrence,
          habitStreak: _habitStreak,
          habitLastCompleted: _habitLastCompleted,
        );
        await provider.updateNote(updatedNote);
      }
      
      setState(() {
        _hasChanges = false;
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_isRecording) {
      await _stopRecording();
    }
    await _audioPlayer.stop();

    if (_hasChanges && !_isSaving) {
      await _saveNote();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note auto-saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
    return true;
  }

  void _addTag() {
    final value = _tagController.text.trim().toLowerCase();
    if (value.isNotEmpty && !_tags.contains(value)) {
      setState(() {
        _tags.add(value);
        _tagController.clear();
        _hasChanges = true;
      });
    }
  }

  void _wrapSelection(String prefix, String suffix) {
    if (_contentController is RichTextEditingController) {
      final controller = _contentController as RichTextEditingController;
      if (prefix == '**') {
        controller.toggleStyleAttribute('bold');
      } else if (prefix == '*') {
        controller.toggleStyleAttribute('italic');
      } else if (prefix == '<u>') {
        controller.toggleStyleAttribute('underline');
      } else if (prefix == '~~') {
        controller.toggleStyleAttribute('strikethrough');
      } else if (prefix == 'highlight') {
        controller.toggleStyleAttribute('highlight', value: Colors.yellow.withAlpha(180));
      } else if (prefix == '```\n') {
        controller.toggleStyleAttribute('code');
      } else if (prefix.startsWith('<p align="')) {
        final alignName = prefix.split('"')[1];
        controller.toggleParagraphStyle('align-$alignName');
      } else {
        final text = _contentController.text;
        final selection = _contentController.selection;
        int start = selection.start;
        int end = selection.end;
        if (start == -1 || end == -1) {
          start = text.length;
          end = start;
        }
        final selectedText = text.substring(start, end);
        final replacement = '$prefix$selectedText$suffix';
        final newText = text.replaceRange(start, end, replacement);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: start + prefix.length,
            extentOffset: start + prefix.length + selectedText.length,
          ),
        );
      }
      _onContentTextChanged();
      return;
    }

    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start;
    int end = selection.end;
    
    if (start == -1 || end == -1) {
      start = text.length;
      end = start;
    }
    
    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);
    
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      ),
    );
    _onContentTextChanged();
  }

  void _insertTextAtCursor(String textToInsert) {
    if (_contentController is RichTextEditingController) {
      final controller = _contentController as RichTextEditingController;
      if (textToInsert == '> ') {
        controller.toggleParagraphStyle('quote');
      } else if (textToInsert == '# ') {
        controller.toggleParagraphStyle('h1');
      } else if (textToInsert == '## ') {
        controller.toggleParagraphStyle('h2');
      } else if (textToInsert == '### ') {
        controller.toggleParagraphStyle('h3');
      } else if (textToInsert == '- ') {
        controller.toggleParagraphStyle('bullet');
      } else if (textToInsert == '1. ') {
        controller.toggleParagraphStyle('number');
      } else if (textToInsert == '\u2610') {
        controller.toggleParagraphStyle('checkbox');
      } else if (textToInsert.startsWith('![') || textToInsert.contains('![')) {
        final parsedChars = parseMarkdownToStyledChars(textToInsert);
        final oldSel = controller.selection;
        int start = oldSel.start;
        int end = oldSel.end;
        if (start == -1 || end == -1) {
          start = controller.text.length;
          end = start;
        }

        bool prependNewline = false;
        if (start > 0 && controller.styledChars[start - 1].char != '\n') {
          prependNewline = true;
        }
        
        final List<StyledChar> insertBlock = [];
        if (prependNewline) {
          insertBlock.add(StyledChar(char: '\n', style: const Style()));
        }
        insertBlock.addAll(parsedChars);
        insertBlock.add(StyledChar(char: '\n', style: const Style()));

        final newChars = List<StyledChar>.from(controller.styledChars);
        if (end > start) {
          newChars.removeRange(start, end);
        }
        newChars.insertAll(start, insertBlock);
        controller.styledChars = newChars;

        final newText = controller.styledChars.map((sc) => sc.char).join();
        final int cursorOffset = start + (prependNewline ? 1 : 0) + parsedChars.length + 1;
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorOffset.clamp(0, newText.length)),
        );
      } else {
        final text = _contentController.text;
        final selection = _contentController.selection;
        int start = selection.start;
        int end = selection.end;
        if (start == -1 || end == -1) {
          start = text.length;
          end = start;
        }
        final newText = text.replaceRange(start, end, textToInsert);
        _contentController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start + textToInsert.length),
        );
      }
      _onContentTextChanged();
      return;
    }

    final text = _contentController.text;
    final selection = _contentController.selection;
    int start = selection.start;
    int end = selection.end;
    
    if (start == -1 || end == -1) {
      start = text.length;
      end = start;
    }
    
    final newText = text.replaceRange(start, end, textToInsert);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + textToInsert.length),
    );
    _onContentTextChanged();
  }

  Future<void> _pickReminder() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _reminderTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _hasChanges = true;
        });
      }
    }
  }

  // Command bar floating modal bottom sheet actions hub
  void _showCommandPalette() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCommandItem(
                context,
                icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: _isPinned ? "Unpin Note" : "Pin Note",
                onTap: () {
                  setState(() {
                    _isPinned = !_isPinned;
                    _hasChanges = true;
                  });
                },
              ),
              _buildCommandItem(
                context,
                icon: _isFavorite ? Icons.star : Icons.star_border,
                label: _isFavorite ? "Remove Favorite" : "Add Favorite",
                onTap: () {
                  setState(() {
                    _isFavorite = !_isFavorite;
                    _hasChanges = true;
                  });
                },
              ),
              _buildCommandItem(
                context,
                icon: Icons.folder_open_outlined,
                label: "Move to Folder",
                onTap: _showFolderSelectorDialog,
              ),
              _buildCommandItem(
                context,
                icon: _isLocked ? Icons.lock : Icons.lock_open,
                label: _isLocked ? "Unlock Note" : "Lock Note with PIN",
                onTap: () async {
                  if (!_isLocked) {
                    final hasPin = await VaultService.instance.hasPinConfigured();
                    if (!hasPin && mounted) {
                      _showSetupPinDialog();
                      return;
                    }
                  }
                  setState(() {
                    _isLocked = !_isLocked;
                    _hasChanges = true;
                  });
                },
              ),
              _buildCommandItem(
                context,
                icon: _noteType == 'text' ? Icons.playlist_add_check_rounded : Icons.text_snippet_rounded,
                label: _noteType == 'text' ? "Convert to Checklist" : "Convert to Plain Text",
                onTap: _toggleNoteType,
              ),
              if (_noteType == 'checklist')
                _buildCommandItem(
                  context,
                  icon: Icons.local_fire_department_rounded,
                  label: "Configure Habit",
                  onTap: _showHabitSettingsDialog,
                ),
              _buildCommandItem(
                context,
                icon: Icons.share_rounded,
                label: "Export & Share",
                onTap: _showExportDialog,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildCategorySelector(Color titleColor) {
    final categories = NotesProvider.categories;
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _category == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : titleColor.withAlpha(180),
              ),
              selectedColor: Theme.of(context).colorScheme.primary,
              backgroundColor: titleColor.withAlpha(15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Theme.of(context).colorScheme.primary : titleColor.withAlpha(30),
                  width: 1.0,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _category = cat;
                    _hasChanges = true;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormattingToolbar(Color textColor, Color titleColor) {
    final theme = Theme.of(context);
    final buttonColor = titleColor;
    final isDark = theme.brightness == Brightness.dark;

    final activeStyle = (_contentController is RichTextEditingController)
        ? (_contentController as RichTextEditingController).currentActiveStyle
        : const Style();

    // Helper for building toolbar items
    Widget buildToolbarButton({
      required IconData icon,
      required VoidCallback onPressed,
      required String tooltip,
      bool isActive = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primary.withAlpha(40) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                icon,
                color: isActive ? theme.colorScheme.primary : buttonColor.withAlpha(200),
                size: 20,
              ),
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      );
    }

    Widget buildPageWrapper(List<Widget> children) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    }

    return Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(
          color: buttonColor.withAlpha(25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left chevron arrow to navigate back
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _currentPage == 0,
              child: IconButton(
                icon: Transform(
                  transform: Matrix4.rotationY(3.14159),
                  alignment: Alignment.center,
                  child: Icon(Icons.play_arrow_rounded, color: buttonColor.withAlpha(180)),
                ),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
          
          // Sliding Options
          Expanded(
            child: SizedBox(
              height: 44,
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // Page 0: Styles Group
                  buildPageWrapper([
                    buildToolbarButton(
                      icon: Icons.format_bold_rounded,
                      onPressed: () => _wrapSelection('**', '**'),
                      tooltip: 'Bold',
                      isActive: activeStyle.bold,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_italic_rounded,
                      onPressed: () => _wrapSelection('*', '*'),
                      tooltip: 'Italic',
                      isActive: activeStyle.italic,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_underlined_rounded,
                      onPressed: () => _wrapSelection('<u>', '</u>'),
                      tooltip: 'Underline',
                      isActive: activeStyle.underline,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_strikethrough_rounded,
                      onPressed: () => _wrapSelection('~~', '~~'),
                      tooltip: 'Strikethrough',
                      isActive: activeStyle.strikethrough,
                    ),
                    buildToolbarButton(
                      icon: Icons.border_color_rounded,
                      onPressed: () => _wrapSelection('highlight', ''),
                      tooltip: 'Highlight',
                      isActive: activeStyle.highlight != null,
                    ),
                    buildToolbarButton(
                      icon: Icons.link_rounded,
                      onPressed: () => _wrapSelection('[', '](url)'),
                      tooltip: 'Link',
                    ),
                  ]),

                  // Page 1: Headings & Lists Group
                  buildPageWrapper([
                    buildToolbarButton(
                      icon: Icons.filter_1_rounded,
                      onPressed: () => _insertTextAtCursor('# '),
                      tooltip: 'Heading 1',
                      isActive: activeStyle.heading == 'h1',
                    ),
                    buildToolbarButton(
                      icon: Icons.filter_2_rounded,
                      onPressed: () => _insertTextAtCursor('## '),
                      tooltip: 'Heading 2',
                      isActive: activeStyle.heading == 'h2',
                    ),
                    buildToolbarButton(
                      icon: Icons.filter_3_rounded,
                      onPressed: () => _insertTextAtCursor('### '),
                      tooltip: 'Heading 3',
                      isActive: activeStyle.heading == 'h3',
                    ),
                    buildToolbarButton(
                      icon: Icons.format_list_bulleted_rounded,
                      onPressed: () => _insertTextAtCursor('- '),
                      tooltip: 'Bullet List',
                      isActive: activeStyle.listType == 'bullet',
                    ),
                    buildToolbarButton(
                      icon: Icons.format_list_numbered_rounded,
                      onPressed: () => _insertTextAtCursor('1. '),
                      tooltip: 'Numbered List',
                      isActive: activeStyle.listType == 'number',
                    ),
                    buildToolbarButton(
                      icon: Icons.add_task_rounded,
                      onPressed: () => _insertTextAtCursor('\u2610'),
                      tooltip: 'Checklist',
                      isActive: activeStyle.listType == 'checkbox',
                    ),
                  ]),

                  // Page 2: Alignments & Actions Group
                  buildPageWrapper([
                    buildToolbarButton(
                      icon: Icons.format_align_left_rounded,
                      onPressed: () => _wrapSelection('<p align="left">', '</p>'),
                      tooltip: 'Align Left',
                      isActive: activeStyle.align == TextAlign.left,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_align_center_rounded,
                      onPressed: () => _wrapSelection('<p align="center">', '</p>'),
                      tooltip: 'Align Center',
                      isActive: activeStyle.align == TextAlign.center,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_align_right_rounded,
                      onPressed: () => _wrapSelection('<p align="right">', '</p>'),
                      tooltip: 'Align Right',
                      isActive: activeStyle.align == TextAlign.right,
                    ),
                    buildToolbarButton(
                      icon: Icons.format_align_justify_rounded,
                      onPressed: () => _wrapSelection('<p align="justify">', '</p>'),
                      tooltip: 'Align Justify',
                      isActive: activeStyle.align == TextAlign.justify,
                    ),
                    buildToolbarButton(
                      icon: Icons.camera_alt_outlined,
                      onPressed: () => _showGalleryBottomSheet(context),
                      tooltip: 'Attach Image',
                    ),
                    buildToolbarButton(
                      icon: Icons.mic_none_rounded,
                      onPressed: _startRecording,
                      tooltip: 'Record Audio',
                    ),
                    buildToolbarButton(
                      icon: Icons.keyboard_hide_rounded,
                      onPressed: () => _contentFocusNode.unfocus(),
                      tooltip: 'Hide Keyboard',
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // Right chevron arrow to navigate forward
          AnimatedOpacity(
            opacity: _currentPage < 2 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _currentPage == 2,
              child: IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: buttonColor.withAlpha(180)),
                onPressed: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardBottomPanel(Color editorBgColor, Color titleColor, Color textColor, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$_wordCount words  |  $_charCount chars",
              style: GoogleFonts.inter(fontSize: 11.0, color: textColor.withAlpha(150)),
            ),
            SizedBox(
              height: 24,
              child: Row(
                children: List.generate(8, (index) {
                  final color = NotesProvider.getNoteColor(index, context);
                  final isSelected = _colorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _colorIndex = index;
                        _hasChanges = true;
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.black12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFEBEBE8)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _showCommandPalette,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.more_horiz_rounded, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          "Note Actions",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  width: 1,
                  height: 18,
                  child: ColoredBox(color: Color(0xFFEBEBE8)),
                ),
                InkWell(
                  onTap: _showQuickAddMenu,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          "Attachments",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Resolve note colors matching theme
    final editorBgColor = NotesProvider.getNoteColor(_colorIndex, context);
    final textColor = NotesProvider.getNoteTextColor(_colorIndex, context);
    final titleColor = NotesProvider.getNoteTitleColor(_colorIndex, context);

    final dateStr = DateFormat('MMM d, yyyy').format(widget.note?.updatedAt ?? DateTime.now());
    final readingTime = "${(_wordCount / 200).ceil()} min read";

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: editorBgColor,
        // AppBar (Faded in Zen Mode)
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AnimatedOpacity(
            opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_isPageSettled || _isZenTyping,
              child: AppBar(
                backgroundColor: editorBgColor,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  if (_noteType == 'text')
                    IconButton(
                      icon: Icon(
                        _isPreviewMarkdown ? Icons.menu_book_rounded : Icons.text_snippet_rounded,
                        color: titleColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPreviewMarkdown = !_isPreviewMarkdown;
                        });
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      _isLocked ? Icons.lock : Icons.lock_open,
                      color: _isLocked ? theme.colorScheme.primary : titleColor,
                    ),
                    onPressed: () async {
                      if (!_isLocked) {
                        final hasPin = await VaultService.instance.hasPinConfigured();
                        if (!hasPin && mounted) {
                          _showSetupPinDialog();
                          return;
                        }
                      }
                      setState(() {
                        _isLocked = !_isLocked;
                        _hasChanges = true;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.star : Icons.star_border,
                      color: _isFavorite ? Colors.amber : titleColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFavorite = !_isFavorite;
                        _hasChanges = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Media attachments (fades in zen mode)
              AnimatedOpacity(
                opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_isPageSettled || _isZenTyping,
                  child: Column(
                    children: [
                      // Images slider
                      if (_attachments.any((a) => a['type'] == 'image'))
                        Container(
                          height: 100,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _attachments.where((a) => a['type'] == 'image').map((image) {
                              final path = image['path'] as String;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(File(path), fit: BoxFit.cover, width: 90, height: 90),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _attachments.remove(image);
                                            _hasChanges = true;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      // Audio player panel
                      if (_attachments.any((a) => a['type'] == 'voice'))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                          child: Column(
                            children: _attachments.where((a) => a['type'] == 'voice').map((voice) {
                              final path = voice['path'] as String;
                              final duration = voice['duration'] as int;
                              final isCurrent = _currentlyPlayingPath == path;
                              final playStatus = isCurrent && _isPlaying;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: titleColor.withAlpha(15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(playStatus ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                                      onPressed: () => _toggleAudioPlay(path),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Voice Attachment (${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')})",
                                        style: GoogleFonts.inter(fontSize: 13, color: textColor),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _attachments.remove(voice);
                                          _hasChanges = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Main Writing canvas
              Expanded(
                child: DragTarget<Map<String, dynamic>>(
                  onWillAcceptWithDetails: (details) => _noteType == 'text',
                  onAcceptWithDetails: (details) {
                    final data = details.data;
                    final oldIndex = data['oldIndex'] as int;
                    _moveInlineImage(oldIndex, details.offset);
                  },
                  onMove: (details) {
                    _hoverInlineImage(details.offset);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          sliver: SliverFillRemaining(
                            hasScrollBody: false,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 720),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Metadata Info row (Faded in Zen mode)
                                    AnimatedOpacity(
                                      opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                                      duration: const Duration(milliseconds: 300),
                                      child: IgnorePointer(
                                        ignoring: !_isPageSettled || _isZenTyping,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 16.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF91918E)),
                                              const SizedBox(width: 4),
                                              Text(
                                                dateStr,
                                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF91918E)),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF91918E)),
                                              const SizedBox(width: 4),
                                              Text(
                                                readingTime,
                                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF91918E)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
          
                                    // Note Title input
                                    TextField(
                                      controller: _titleController,
                                      maxLines: 1,
                                      style: GoogleFonts.outfit(
                                        fontSize: 24.0,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Note Title",
                                        hintStyle: GoogleFonts.outfit(
                                          fontSize: 24.0,
                                          fontWeight: FontWeight.bold,
                                          color: titleColor.withAlpha(80),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        filled: false,
                                      ),
                                    ),
                                    const SizedBox(height: 12.0),
                                    _buildCategorySelector(titleColor),
                                    const SizedBox(height: 16.0),
          
                                    // Render Checklist mode OR Markdown body OR Text editor
                                    if (_noteType == 'checklist')
                                      _buildChecklistEditor(textColor)
                                    else if (_isPreviewMarkdown)
                                      _buildMarkdownPreview(textColor)
                                    else
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            _contentFocusNode.requestFocus();
                                            _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
                                          },
                                          child: TextField(
                                            key: _textFieldKey,
                                            controller: _contentController,
                                            focusNode: _contentFocusNode,
                                            maxLines: null,
                                            keyboardType: TextInputType.multiline,
                                            textAlign: _getCurrentLineAlignment(),
                                            style: GoogleFonts.inter(
                                              fontSize: 18.0,
                                              color: textColor,
                                              height: 1.6,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: "Start writing...",
                                              hintStyle: GoogleFonts.inter(
                                                fontSize: 18.0,
                                                color: textColor.withAlpha(80),
                                              ),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                              filled: false,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Tags Chip bar (Faded in Zen Mode)
              AnimatedOpacity(
                opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_isPageSettled || _isZenTyping,
                  child: Column(
                    children: [
                      if (_tags.isNotEmpty)
                        Container(
                          height: 32,
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            children: _tags.map((tag) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Chip(
                                  label: Text("#$tag"),
                                  labelStyle: GoogleFonts.inter(fontSize: 11, color: textColor),
                                  backgroundColor: titleColor.withAlpha(15),
                                  onDeleted: () {
                                    setState(() {
                                      _tags.remove(tag);
                                      _hasChanges = true;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom control panels (Fades in Zen mode)
              AnimatedOpacity(
                opacity: !_isPageSettled ? 0.0 : (_isZenTyping ? 0.0 : 1.0),
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_isPageSettled || _isZenTyping,
                  child: Container(
                    padding: _contentFocusNode.hasFocus && _noteType == 'text' && !_isPreviewMarkdown
                        ? const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0)
                        : const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: _contentFocusNode.hasFocus && _noteType == 'text' && !_isPreviewMarkdown
                          ? Colors.transparent
                          : editorBgColor,
                      border: _contentFocusNode.hasFocus && _noteType == 'text' && !_isPreviewMarkdown
                          ? null
                          : Border(top: BorderSide(color: titleColor.withAlpha(20))),
                    ),
                    child: _contentFocusNode.hasFocus && _noteType == 'text' && !_isPreviewMarkdown
                        ? _buildFormattingToolbar(textColor, titleColor)
                        : _buildStandardBottomPanel(editorBgColor, titleColor, textColor, theme),
                  ),
                ),
              ),

              // Audio Record overlay
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(24.0)),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        "Recording: ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}",
                        style: GoogleFonts.inter(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _stopRecording,
                        style: TextButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: Colors.white),
                        child: const Text("STOP"),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  ),
    );
  }

  // Quick addition features popup
  void _showQuickAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.mic_none_rounded),
                title: const Text("Record Voice Note"),
                onTap: () {
                  Navigator.pop(context);
                  _startRecording();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: const Text("Attach Image"),
                onTap: () {
                  Navigator.pop(context);
                  _showGalleryBottomSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.alarm_add_rounded),
                title: const Text("Set Reminder Alarm"),
                onTap: () {
                  Navigator.pop(context);
                  _pickReminder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.tag_rounded),
                title: const Text("Add Note Tag"),
                onTap: () {
                  Navigator.pop(context);
                  _showAddTagDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Note Tag"),
        content: TextField(
          controller: _tagController,
          decoration: const InputDecoration(hintText: "Enter tag (e.g. urgent)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addTag();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // Checklist editor view builder
  Widget _buildChecklistEditor(Color textColor) {
    if (_checklistControllers.length != _checklistItems.length) {
      _syncControllers();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_checklistItems.length, (index) {
          final item = _checklistItems[index];
          final bool isDone = item['done'] ?? false;
          final TextEditingController itemController = _checklistControllers[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Checkbox(
                  value: isDone,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (bool? val) {
                    setState(() {
                      _checklistItems[index]['done'] = val ?? false;
                      _hasChanges = true;
                      _calculateCounts();
                    });
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: itemController,
                    onChanged: (val) {
                      _checklistItems[index]['text'] = val;
                      _hasChanges = true;
                      _calculateCounts();
                    },
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDone ? textColor.withAlpha(120) : textColor,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    decoration: const InputDecoration(
                      hintText: "List item",
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => _removeChecklistItem(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _addChecklistItem,
          icon: const Icon(Icons.add_rounded),
          label: Text("Add Item", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // Markdown renderer viewer
  Widget _buildMarkdownPreview(Color textColor) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: _contentController.text,
      selectable: true,
      imageBuilder: (uri, title, alt) {
        final cleanUri = uri.hasQuery ? uri.replace(queryParameters: {}) : uri;
        final path = cleanUri.scheme == 'file' ? cleanUri.toFilePath() : cleanUri.toString();
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenImageViewer(imagePath: path),
              ),
            );
          },
          child: Hero(
            tag: 'markdown_img_$path',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: uri.scheme == 'file'
                  ? Image.file(
                      File(path),
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    )
                  : Image.network(
                      path,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
            ),
          ),
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: GoogleFonts.inter(fontSize: 18.0, color: textColor, height: 1.6),
        h1: GoogleFonts.outfit(fontSize: 24.0, fontWeight: FontWeight.bold, color: textColor),
        h2: GoogleFonts.outfit(fontSize: 22.0, fontWeight: FontWeight.bold, color: textColor),
        h3: GoogleFonts.outfit(fontSize: 20.0, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  void _showFolderSelectorDialog() {
    showDialog(
      context: context,
      builder: (context) => FolderSelectorDialog(
        currentFolderId: _folderId,
        onFolderSelected: (folderId) {
          setState(() {
            _folderId = folderId;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  void _showExportDialog() {
    final tempNote = Note(
      id: widget.note?.id ?? 'temp',
      title: _titleController.text.trim(),
      content: _noteType == 'checklist' ? jsonEncode(_checklistItems) : _contentController.text.trim(),
      tags: _tags,
      attachments: _attachments,
      category: _category,
      isPinned: _isPinned,
      isFavorite: _isFavorite,
      isArchived: _isArchived,
      isLocked: _isLocked,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      colorValue: _colorIndex,
      folderId: _folderId,
      isHabit: _isHabit,
      habitRecurrence: _habitRecurrence,
    );
    showDialog(
      context: context,
      builder: (context) => ExportDialog(note: tempNote),
    );
  }

  void _showHabitSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text("Habit Settings", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text("Track as Habit"),
                    value: _isHabit,
                    onChanged: (val) {
                      setState(() {
                        _isHabit = val;
                        if (!val) {
                          _habitRecurrence = 'none';
                        } else if (_habitRecurrence == 'none') {
                          _habitRecurrence = 'daily';
                        }
                        _hasChanges = true;
                      });
                      setDialogState(() {});
                    },
                  ),
                  if (_isHabit) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Reset Interval", border: OutlineInputBorder()),
                      dropdownColor: theme.colorScheme.surface,
                      initialValue: _habitRecurrence == 'none' ? 'daily' : _habitRecurrence,
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text("Daily Reset")),
                        DropdownMenuItem(value: 'weekly', child: Text("Weekly Reset")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _habitRecurrence = val;
                            _hasChanges = true;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
              ],
            );
          },
        );
      },
    );
  }

  void _showSetupPinDialog() {
    final theme = Theme.of(context);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text("Setup Secure PIN", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: "Enter 4-digit PIN", border: OutlineInputBorder(), counterText: ""),
                  validator: (value) {
                    if (value == null || value.length != 4 || int.tryParse(value) == null) {
                      return "Enter exactly 4 digits";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: "Confirm PIN", border: OutlineInputBorder(), counterText: ""),
                  validator: (value) {
                    if (value != pinController.text) {
                      return "PINs do not match";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await VaultService.instance.setVaultPin(pinController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {
                      _isLocked = true;
                      _hasChanges = true;
                    });
                  }
                }
              },
              child: const Text("Save & Lock"),
            ),
          ],
        );
      },
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;

  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final isFile = !imagePath.startsWith('http://') && !imagePath.startsWith('https://');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'markdown_img_$imagePath',
            child: isFile
                ? Image.file(
                    File(imagePath),
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  )
                : Image.network(
                    imagePath,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
