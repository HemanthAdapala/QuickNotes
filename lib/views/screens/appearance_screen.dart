import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/tactile_button.dart';
import '../widgets/app_header_bar.dart';
import '../../themes/quick_notes_theme.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final _secureStorage = const FlutterSecureStorage();
  String _layoutDensity = "grid"; // grid or list
  double _fontSizeScale = 1.0; // 0.8, 1.0, 1.2
  String _selectedAccent = "yellow"; // yellow, white, gray

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final density = await _secureStorage.read(key: 'layout_density') ?? 'grid';
    final scaleStr = await _secureStorage.read(key: 'font_scale') ?? '1.0';
    final accent =
        await _secureStorage.read(key: 'accent_preference') ?? 'yellow';

    setState(() {
      _layoutDensity = density;
      _fontSizeScale = double.tryParse(scaleStr) ?? 1.0;
      _selectedAccent = accent;
    });
  }

  Future<void> _saveSetting(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: QuickNotesTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
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
                  colorFilter:
                      const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                title: "Appearance",
                titleColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12.0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("THEME STYLE"),
                      const SizedBox(height: 12),

                      // Obsidian Dark display tile (Non-toggleable premium default)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: QuickNotesTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: QuickNotesTheme.accent.withAlpha(50),
                              width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: QuickNotesTheme.background,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.circle,
                                    color: QuickNotesTheme.accent, size: 12),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Obsidian Night (Default)",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: QuickNotesTheme.textPrimary),
                                  ),
                                  Text(
                                    "Luxury machined dark aluminum canvas",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: QuickNotesTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded,
                                color: QuickNotesTheme.accent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle("LAYOUT DENSITY"),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildChoiceCard(
                              title: "Bento Grid",
                              description: "Masonry card view",
                              selected: _layoutDensity == "grid",
                              icon: Icons.dashboard_outlined,
                              onTap: () {
                                setState(() {
                                  _layoutDensity = "grid";
                                });
                                _saveSetting('layout_density', 'grid');
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildChoiceCard(
                              title: "Quiet List",
                              description: "High visual density",
                              selected: _layoutDensity == "list",
                              icon: Icons.view_headline_rounded,
                              onTap: () {
                                setState(() {
                                  _layoutDensity = "list";
                                });
                                _saveSetting('layout_density', 'list');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle("TYPOGRAPHY SCALE"),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: QuickNotesTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: QuickNotesTheme.border),
                        ),
                        child: Column(
                          children: [
                            Slider(
                              value: _fontSizeScale,
                              min: 0.8,
                              max: 1.2,
                              divisions: 2,
                              activeColor: QuickNotesTheme.accent,
                              inactiveColor: QuickNotesTheme.border,
                              onChanged: (val) {
                                setState(() {
                                  _fontSizeScale = val;
                                });
                                _saveSetting('font_scale', val.toString());
                              },
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Compact",
                                      style: theme.textTheme.bodySmall),
                                  Text("Regular",
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  Text("Large",
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle("ACCENT COLOR"),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAccentOption(
                              "yellow", QuickNotesTheme.accent, "Chartreuse"),
                          _buildAccentOption("white", Colors.white, "White"),
                          _buildAccentOption("gray", Colors.grey, "Muted"),
                        ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'JetBrains Mono',
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: QuickNotesTheme.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String description,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QuickNotesTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? QuickNotesTheme.accent : QuickNotesTheme.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected
                  ? QuickNotesTheme.accent
                  : QuickNotesTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: QuickNotesTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: QuickNotesTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentOption(String name, Color color, String label) {
    final isSelected = _selectedAccent == name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAccent = name;
        });
        _saveSetting('accent_preference', name);
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.0,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withAlpha(80),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color == Colors.white ? Color(0xFF333333) : Color(0xFF333333),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: QuickNotesTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
