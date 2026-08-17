import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/tactile_button.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import 'package:provider/provider.dart';
import 'package:quick_notes/providers/notes_provider.dart';
import 'package:quick_notes/providers/tasks_provider.dart';
import 'package:quick_notes/models/note.dart';
import 'package:quick_notes/models/task_item.dart';
import 'package:quick_notes/models/folder.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  String _username = 'Username';
  String _email = 'Email id';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final uname = prefs.getString('profile_username') ?? prefs.getString('profile_full_name');
      final mail = prefs.getString('profile_email') ?? prefs.getString('user_email');
      if (uname != null && uname.trim().isNotEmpty) {
        _username = uname.trim().replaceAll('@', '');
      }
      if (mail != null && mail.trim().isNotEmpty) {
        _email = mail.trim();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFF333333);
    const secondaryTextColor = Color(0xFF666666);
    const backgroundColor = Color(0xFFF2F2F7);
    const primaryBlueColor = Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  TactileButton(
                    useAppleSpring: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const ShapeDecoration(
                        color: Colors.white,
                        shape: OvalBorder(),
                        shadows: [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/angle_left.svg',
                          width: 18,
                          height: 18,
                          colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "Delete your account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.43,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            const SizedBox(height: 8.0),

            // Content Area (White Rounded Sheet)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 36.0),
                  child: Column(
                  children: [
                    Text(
                      "Closing your account means you won't be able to get your Notes and Tasks back. All of your QuickNotes data will be delete",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20.0),

                    Text(
                      _username,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 20.0),

                    Text(
                      "$_username, if you're ready to leave forever, we'll send an email with the final step to:",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20.0),

                    Text(
                      _email,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 36.0),

                    // Continue Button
                    TactileButton(
                      useAppleSpring: true,
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                        final tasksProvider = Provider.of<TasksProvider>(context, listen: false);
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        final confirm = await showDeleteNoteDialog(
                          context,
                          title: 'Delete Account Data',
                          message: 'Are you sure you want to delete your account and all data? This action cannot be undone.',
                        );
                        if (confirm == true && mounted) {
                          for (final note in List<Note>.from(notesProvider.notes)) {
                            await notesProvider.deleteNote(note.id);
                          }
                          for (final task in List<TaskItem>.from(tasksProvider.tasks)) {
                            await tasksProvider.deleteTask(task.id);
                          }
                          for (final folder in List<Folder>.from(notesProvider.folders)) {
                            await notesProvider.deleteFolder(folder.id);
                          }
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Account data deleted successfully.')),
                          );
                          navigator.pop();
                        }
                      },
                      child: Container(
                        width: 160,
                        height: 48,
                        decoration: ShapeDecoration(
                          color: primaryBlueColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          shadows: const [
                            BoxShadow(
                              color: Color(0x33007AFF),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "Continue",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
