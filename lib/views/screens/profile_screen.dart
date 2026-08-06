import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_header_bar.dart';
import '../widgets/tactile_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  String? _imagePath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fullNameController.text = prefs.getString('profile_full_name') ?? '';
      _emailController.text = prefs.getString('profile_email') ?? '';
      _usernameController.text = prefs.getString('profile_username') ?? '';
      _imagePath = prefs.getString('profile_image_path');
      _isLoading = false;
    });
  }

  Future<void> _saveProfileData() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_full_name', _fullNameController.text.trim());
    await prefs.setString('profile_email', _emailController.text.trim());
    await prefs.setString('profile_username', _usernameController.text.trim());
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      await prefs.setString('profile_image_path', _imagePath!);
    } else {
      await prefs.remove('profile_image_path');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile saved successfully',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF333333),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  void _showDeleteAccountDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete Account",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
          ),
        ),
        content: Text(
          "Are you sure you want to delete your account? This action is permanent and cannot be undone.",
          style: GoogleFonts.inter(
            color: const Color(0xFF333333).withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: Text(
              "Delete",
              style: GoogleFonts.inter(
                color: const Color(0xFFFF453A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_full_name');
    await prefs.remove('profile_email');
    await prefs.remove('profile_username');
    await prefs.remove('profile_image_path');

    setState(() {
      _fullNameController.clear();
      _emailController.clear();
      _usernameController.clear();
      _imagePath = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account data deleted',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryTextColor = Color(0xFF333333);
    const hintTextColor = Color(0x80333333);
    const borderColor = Color(0xFF333333);
    const circleColor = Color(0x33787878);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: AppHeaderBar(
                leftWidth: 44.0,
                onLeftTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).maybePop();
                },
                leftChild: SvgPicture.asset(
                  'assets/icons/angle_left.svg',
                  width: 22,
                  height: 22,
                  colorFilter: const ColorFilter.mode(
                    primaryTextColor,
                    BlendMode.srcIn,
                  ),
                ),
                titleWidget: Text(
                  "Edit Profile",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 0.88,
                    letterSpacing: -0.43,
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryTextColor))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 24.0,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                children: [
                                  const SizedBox(height: 20.0),

                                  // Avatar (100x100) with camera icon (22x22)
                                  Center(
                                    child: SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            child: Container(
                                              width: 100,
                                              height: 100,
                                              decoration: const ShapeDecoration(
                                                color: circleColor,
                                                shape: OvalBorder(),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: _imagePath != null && File(_imagePath!).existsSync()
                                                  ? Image.file(
                                                      File(_imagePath!),
                                                      width: 100,
                                                      height: 100,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          Positioned(
                                            left: 74,
                                            top: 73,
                                            child: GestureDetector(
                                              onTap: _pickImage,
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: const ShapeDecoration(
                                                  color: circleColor,
                                                  shape: OvalBorder(),
                                                ),
                                                child: Center(
                                                  child: SvgPicture.asset(
                                                    'assets/icons/camera.svg',
                                                    width: 12,
                                                    height: 12,
                                                    colorFilter: const ColorFilter.mode(
                                                      primaryTextColor,
                                                      BlendMode.srcIn,
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

                                  const SizedBox(height: 36.0),

                                  // User details card (Full name, Email, Username)
                                  Center(
                                    child: Container(
                                      width: 322,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: ShapeDecoration(
                                        color: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        shadows: const [
                                          BoxShadow(
                                            color: Color(0x3F000000),
                                            blurRadius: 16,
                                            offset: Offset(0, 0),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Full name field
                                          Container(
                                            width: 322,
                                            height: 50,
                                            alignment: Alignment.centerLeft,
                                            decoration: const ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(
                                                  width: 0.20,
                                                  strokeAlign: BorderSide.strokeAlignOutside,
                                                  color: borderColor,
                                                ),
                                              ),
                                            ),
                                            child: TextField(
                                              controller: _fullNameController,
                                              style: GoogleFonts.inter(
                                                color: primaryTextColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                height: 0.88,
                                                letterSpacing: -0.43,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Full name',
                                                hintStyle: GoogleFonts.inter(
                                                  color: hintTextColor,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  height: 0.88,
                                                  letterSpacing: -0.43,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                              ),
                                            ),
                                          ),
                                          // Email field
                                          Container(
                                            width: 322,
                                            height: 50,
                                            alignment: Alignment.centerLeft,
                                            decoration: const ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(
                                                  width: 0.20,
                                                  strokeAlign: BorderSide.strokeAlignOutside,
                                                  color: borderColor,
                                                ),
                                              ),
                                            ),
                                            child: TextField(
                                              controller: _emailController,
                                              keyboardType: TextInputType.emailAddress,
                                              style: GoogleFonts.inter(
                                                color: primaryTextColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                height: 0.88,
                                                letterSpacing: -0.43,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Email',
                                                hintStyle: GoogleFonts.inter(
                                                  color: hintTextColor,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  height: 0.88,
                                                  letterSpacing: -0.43,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                              ),
                                            ),
                                          ),
                                          // Username field
                                          Container(
                                            width: 322,
                                            height: 50,
                                            alignment: Alignment.centerLeft,
                                            child: TextField(
                                              controller: _usernameController,
                                              style: GoogleFonts.inter(
                                                color: primaryTextColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                height: 0.88,
                                                letterSpacing: -0.43,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Username',
                                                hintStyle: GoogleFonts.inter(
                                                  color: hintTextColor,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  height: 0.88,
                                                  letterSpacing: -0.43,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24.0),

                                  // Save changes button
                                  Center(
                                    child: TactileButton(
                                      onTap: _saveProfileData,
                                      useAppleSpring: true,
                                      child: Container(
                                        width: 322,
                                        height: 38,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          shadows: const [
                                            BoxShadow(
                                              color: Color(0x3F000000),
                                              blurRadius: 16,
                                              offset: Offset(0, 0),
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Save changes',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              color: primaryTextColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              height: 0.88,
                                              letterSpacing: -0.43,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const Spacer(),

                                  const SizedBox(height: 32.0),

                                  // Delete Account button
                                  Center(
                                    child: TactileButton(
                                      onTap: _showDeleteAccountDialog,
                                      useAppleSpring: true,
                                      child: Container(
                                        width: 322,
                                        height: 38,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          shadows: const [
                                            BoxShadow(
                                              color: Color(0x3F000000),
                                              blurRadius: 16,
                                              offset: Offset(0, 0),
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Delete Account',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              color: primaryTextColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              height: 0.88,
                                              letterSpacing: -0.43,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
