import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/grouped_list_container.dart';
import '../../widgets/app_header_bar.dart';

class BackupAndSyncScreen extends StatefulWidget {
  const BackupAndSyncScreen({super.key});

  @override
  State<BackupAndSyncScreen> createState() => _BackupAndSyncScreenState();
}

class _BackupAndSyncScreenState extends State<BackupAndSyncScreen> {
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
    const backgroundColor = Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0.0),
              child: AppHeaderBar(
                leftHeroTag: 'hero_backup_sync_back',
                rightHeroTag: 'hero_backup_sync_empty',
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
                  "Backup & Sync",
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 24.0),
                child: Column(
                  children: [
                    GroupedListContainer(
                      children: [
                        GroupedTile.keyValue(
                          iconPath:
                              'assets/icons/bottom_navigation/settings.svg',
                          title: 'User Name',
                          value: _username,
                        ),
                        GroupedTile.keyValue(
                          iconPath: 'assets/icons/terms-info.svg',
                          title: 'Email Address',
                          value: _email,
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bottom Caption Text
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32.0, vertical: 16.0),
                      child: Text(
                        "Back up your notes and tasks to the Gmail so you don't lose them when you get a new Android phone.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFC7C7CC),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
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


