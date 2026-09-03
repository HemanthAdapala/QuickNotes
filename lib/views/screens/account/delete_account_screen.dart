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
import '../../widgets/app_header_bar.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  String _username = 'Guest';
  String _email = 'Not connected';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final uname = prefs.getString('profile_username') ??
          prefs.getString('profile_full_name');
      final mail =
          prefs.getString('profile_email') ?? prefs.getString('user_email');
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
        bottom: false,
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
              child: AppHeaderBar(
                leftHeroTag: 'hero_delete_account_back',
                rightHeroTag: 'hero_delete_account_empty',
                leftWidth: 44.0,
                rightWidth: 44.0,
                rightChild: null,
                onLeftTap: () {
                  Navigator.pop(context);
                },
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(primaryTextColor, BlendMode.srcIn),
                ),
                titleWidget: Text(
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
            ),

            const SizedBox(height: 20.0),

            // Content Area (White Rounded Sheet)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                   alignment: Alignment.topCenter,
                   child: ConstrainedBox(
                     constraints: const BoxConstraints(maxWidth: 402.0),
                     child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(left: 32.0, right: 32.0, top: 36.0, bottom: 36.0 + MediaQuery.paddingOf(context).bottom),
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
                          final notesProvider = Provider.of<NotesProvider>(
                              context,
                              listen: false);
                          final tasksProvider = Provider.of<TasksProvider>(
                              context,
                              listen: false);
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);

                          final confirm = await showDeleteNoteDialog(
                            context,
                            title: 'Delete Account Data',
                            message:
                                'Are you sure you want to delete your account and all data? This action cannot be undone.',
                          );
                          if (confirm == true && mounted) {
                            for (final note
                                in List<Note>.from(notesProvider.notes)) {
                              await notesProvider.deleteNote(note.id);
                            }
                            for (final task
                                in List<TaskItem>.from(tasksProvider.tasks)) {
                              await tasksProvider.deleteTask(task.id);
                            }
                            for (final folder
                                in List<Folder>.from(notesProvider.folders)) {
                              await notesProvider.deleteFolder(folder.id);
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Account data deleted successfully.')),
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
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  "Continue",
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}


