import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/folder.dart';
import '../../providers/notes_provider.dart';
import '../../themes/app_theme.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/folder_selection_sheet.dart';
import '../widgets/blurred_bottom_sheet.dart';

class CreateTaskScreen extends StatefulWidget {
  final DateTime? initialDate;

  const CreateTaskScreen({
    super.key,
    this.initialDate,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  
  String _selectedPriority = 'pink'; // 'pink' (High), 'yellow' (Medium), 'blue' (Low), 'none' (None)
  String? _selectedFolderId;
  
  bool _isTitleNotEmpty = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime(2026, 6, 15);
    _selectedTime = const TimeOfDay(hour: 9, minute: 0); // Default 9:00 AM
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    final bool hasText = _titleController.text.trim().isNotEmpty;
    if (hasText != _isTitleNotEmpty) {
      setState(() {
        _isTitleNotEmpty = hasText;
      });
    }
  }

  // Pick Due Date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF222222),
              onPrimary: Colors.white,
              onSurface: Color(0xFF222222),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Pick Due Time
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF222222),
              onPrimary: Colors.white,
              onSurface: Color(0xFF222222),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Link Folder Sheet
  void _showFolderSelector() {
    showBlurredBottomSheet(
      context: context,
      child: FolderSelectionSheet(
        currentFolderId: _selectedFolderId,
        onFolderSelected: (folderId) {
          setState(() {
            _selectedFolderId = folderId;
          });
        },
      ),
    );
  }

  // Save the Task
  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final provider = Provider.of<NotesProvider>(context, listen: false);
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    
    // Construct reminder time DateTime
    final DateTime reminderDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Save as checklist note in DB
    await provider.addNote(
      title: "Task: $title",
      content: description.isNotEmpty ? description : "[]",
      colorIndex: 0,
      category: 'Uncategorized',
      tags: [_selectedPriority],
      attachments: [],
      reminderTime: reminderDateTime,
      folderId: _selectedFolderId,
      noteType: 'text',
    );

    HapticFeedback.mediumImpact();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Helper to build priority buttons
  Widget _buildPriorityButton({
    required String type,
    required String label,
    required Color color,
  }) {
    final bool isSelected = _selectedPriority == type;

    return Expanded(
      child: TactileButton(
        onTap: () {
          setState(() {
            _selectedPriority = type;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: const Color(0xFF222222), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF222222),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context);
    
    // Resolve Linked Folder Label
    String folderLabel = "Root (No Folder)";
    if (_selectedFolderId != null) {
      final folder = provider.folders.firstWhere(
        (f) => f.id == _selectedFolderId,
        orElse: () => Folder(id: '', name: '', createdAt: DateTime.now()),
      );
      if (folder.name.isNotEmpty) {
        folderLabel = folder.name;
      }
    }

    // Format Date / Time Strings
    final String dateStr = DateFormat('MMMM d, yyyy').format(_selectedDate);
    final String timeStr = DateFormat('h:mm a').format(
      DateTime(2026, 1, 1, _selectedTime.hour, _selectedTime.minute),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2EE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: AppHeaderBar(
                leftWidth: 44.0,
                onLeftTap: () => Navigator.pop(context),
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(Color(0xFF1C1C1E), BlendMode.srcIn),
                ),
                title: "Create Task",
                rightWidth: 44.0,
                rightChild: TactileButton(
                  useAppleSpring: true,
                  compressionScale: 0.7,
                  settleDuration: const Duration(milliseconds: 1000),
                  onTap: _isTitleNotEmpty ? _saveTask : () {},
                  child: Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: _isTitleNotEmpty ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E).withOpacity(0.3),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title Header ──────────────────────────────────────────────
                    Text(
                      "Create Task",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222222),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Form Inputs ───────────────────────────────────────────────
                    // Task Title
                    Text(
                      "Task Title",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EAC0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _titleController,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF222222),
                        ),
                        decoration: InputDecoration(
                          hintText: "Add task title...",
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF9A916C).withOpacity(0.7),
                            fontWeight: FontWeight.normal,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Due Date & Time
                    Text(
                      "Due Date & Time",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Date Picker Field
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EAC0),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF222222),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                    color: Color(0xFF222222),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Time Picker Field
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectTime,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EAC0),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF222222),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.access_time,
                                    size: 20,
                                    color: Color(0xFF222222),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Priority
                    Text(
                      "Priority",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityButton(type: 'pink', label: 'High', color: const Color(0xFFF9C2D9)),
                        const SizedBox(width: 8),
                        _buildPriorityButton(type: 'yellow', label: 'Medium', color: const Color(0xFFFDE69C)),
                        const SizedBox(width: 8),
                        _buildPriorityButton(type: 'blue', label: 'Low', color: const Color(0xFFA8E1F5)),
                        const SizedBox(width: 8),
                        _buildPriorityButton(type: 'none', label: 'None', color: const Color(0xFFD1D1D1)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Link to Folder
                    Text(
                      "Link to Folder/Note",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showFolderSelector,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EAC0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              folderLabel,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF222222),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 24,
                              color: Color(0xFF222222),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Notes/Description
                    Text(
                      "Notes/Description",
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EAC0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF222222),
                        ),
                        decoration: InputDecoration(
                          hintText: "Add details...",
                          hintStyle: GoogleFonts.inter(
                            color: const Color(0xFF9A916C).withOpacity(0.7),
                            fontWeight: FontWeight.normal,
                          ),
                          contentPadding: const EdgeInsets.all(20),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
