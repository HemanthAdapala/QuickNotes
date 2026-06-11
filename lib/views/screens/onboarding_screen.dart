import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../themes/quick_notes_theme.dart';
import '../../providers/notes_provider.dart';
import 'navigation_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _secureStorage = const FlutterSecureStorage();

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.border_color_rounded,
      title: "Zen Workspace",
      description: "A distraction-free writing environment built for clarity. Focus on your thoughts, framed by elegant matte-black surfaces.",
    ),
    OnboardingPageData(
      icon: Icons.folder_copy_rounded,
      title: "Notion-Style Folders",
      description: "Organize note structures with infinite depth. Connect notes, categories, and tags cleanly within a single sidebar.",
    ),
    OnboardingPageData(
      icon: Icons.vpn_key_rounded,
      title: "Encrypted Vault",
      description: "Lock sensitive information with high-grade local AES-256 encryption. Unlock effortlessly with your biometric print or passcode.",
    ),
  ];

  Future<void> _completeOnboarding() async {
    await _secureStorage.write(key: 'has_completed_onboarding', value: 'true');
    if (!mounted) return;
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NavigationShell(
          onThemeToggle: notesProvider.toggleTheme,
          isDarkMode: notesProvider.isDarkMode,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: QuickNotesTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Skip button at the top right
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    "SKIP",
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: QuickNotesTheme.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              
              // Slide views
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon card
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: QuickNotesTheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: QuickNotesTheme.border, width: 1.5),
                          ),
                          child: Icon(
                            item.icon,
                            color: QuickNotesTheme.accent,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Text Title
                        Text(
                          item.title,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            item.description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: QuickNotesTheme.textSecondary,
                              height: 1.5,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              // Dot Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    width: _currentPage == index ? 24.0 : 8.0,
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? QuickNotesTheme.accent
                          : QuickNotesTheme.border,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Bottom Action Button
              ElevatedButton(
                onPressed: () {
                  if (_currentPage == _pages.length - 1) {
                    _completeOnboarding();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: QuickNotesTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentPage == _pages.length - 1 ? "GET STARTED" : "NEXT",
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
