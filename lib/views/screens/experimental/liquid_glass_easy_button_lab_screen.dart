import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../../widgets/quick_notes_liquid_glass_button.dart';
import 'experimental_quick_notes_liquid_glass_back_button.dart';

/// Redesigned Visual Laboratory & Component Playground for testing
/// the native [LiquidGlassButton] from `liquid_glass_easy` over two
/// distinct, configurable background layers, and comparing it directly
/// with the production Quick Notes "Create Folder" glass implementation.
///
/// Depth Hierarchy:
/// ┌─────────────────────────────────────────────────────────┐
/// │ Stage Canvas: Background 1 (Deepest / Base Surface)     │
/// │   ┌─────────────────────────────────────────────────┐   │
/// │   │ Surface Island: Background 2 (Elevated Overlay) │   │
/// │   │   ┌─────────────────────────────────────────┐   │   │
/// │   │   │ Horizontal Stage Carousel:              │   │   │
/// │   │   │  [Stage 1: Native LiquidGlassButton]    │   │   │
/// │   │   │  [Stage 2: Quick Notes Create Folder]   │   │   │
/// │   │   └─────────────────────────────────────────┘   │   │
/// │   └─────────────────────────────────────────────────┘   │
/// └─────────────────────────────────────────────────────────┘
class LiquidGlassEasyButtonLabScreen extends StatefulWidget {
  const LiquidGlassEasyButtonLabScreen({super.key});

  @override
  State<LiquidGlassEasyButtonLabScreen> createState() =>
      _LiquidGlassEasyButtonLabScreenState();
}

class _LiquidGlassEasyButtonLabScreenState
    extends State<LiquidGlassEasyButtonLabScreen> {
  // ============================================================
  // STAGE NAVIGATION (Horizontal Carousel) & ENVIRONMENT
  // ============================================================
  late final PageController _stagePageController;
  int _currentStageIndex = 0;
  bool _stage2FlexEnabled =
      true; // Toggle between Clean Static Baseline and LiquidGlassEasy Press Physics
  bool _labScrollingEnabled =
      true; // Toggle whether the lab page itself can vertically scroll
  double _stage2ChildFollow =
      0.0; // Stage 2 Content Follow: 0.0 (0%), 0.25 (25%), 0.50 (50%), 0.75 (75%), 1.0 (100%)

  // ============================================================
  // LB-R5 CIRCULAR BACK BUTTON VALIDATION ENVIRONMENT
  // ============================================================
  int _labMode = 0; // 0 = Standard Button Lab, 1 = LB-R5 Circular Back Button Validation
  int _backButtonTapCount = 0;
  bool _backButtonComparisonMode = true; // true = Side-by-side with reference, false = Isolated 44x44

  // ============================================================
  // BACKGROUND 1 (Base Canvas Layer)
  // ============================================================
  Color _background1Color =
      const Color(0xFF1E1B4B); // Deep Midnight Indigo default
  double _background1Opacity = 1.0;
  double _bg1SliderValue = 0.5; // Grayscale slider sync
  int _selectedPaletteIndex = -1;
  late TextEditingController _bg1HexController;

  // 12 Curated Palette Swatches for Background 1
  static const List<Color> _paletteColors = [
    Color(0xFFFFFFFF), // 1. Pure White
    Color(0xFFE5E5EA), // 2. Light Gray
    Color(0xFF8E8E93), // 3. Medium Gray
    Color(0xFF3A3A3C), // 4. Dark Gray
    Color(0xFF000000), // 5. Pure Black
    Color(0xFFFF3B30), // 6. System Red
    Color(0xFFFF9500), // 7. System Orange
    Color(0xFFFFCC00), // 8. System Yellow
    Color(0xFF34C759), // 9. System Green
    Color(0xFF00C7BE), // 10. Mint / Cyan
    Color(0xFF007AFF), // 11. System Blue
    Color(0xFFAF52DE), // 12. Purple
  ];

  // ============================================================
  // BACKGROUND 2 (Surface Island Layer)
  // ============================================================
  Color _background2Color = const Color(0xFFFF3B30); // Crimson accent default
  double _background2Opacity = 0.45;
  late TextEditingController _bg2HexController;

  // Curated Quick Accents for Background 2
  static const List<Color> _bg2Presets = [
    Color(0xFFFF3B30), // Crimson
    Color(0xFF007AFF), // Azure
    Color(0xFF34C759), // Emerald
    Color(0xFFFF9500), // Amber
    Color(0xFFAF52DE), // Violet
    Color(0xFF00C7BE), // Turquoise
    Color(0xFFFFFFFF), // White
    Color(0xFF000000), // Black
  ];

  @override
  void initState() {
    super.initState();
    _stagePageController = PageController(initialPage: _currentStageIndex);
    _bg1HexController =
        TextEditingController(text: _hexString(_background1Color));
    _bg2HexController =
        TextEditingController(text: _hexString(_background2Color));
  }

  @override
  void dispose() {
    _stagePageController.dispose();
    _bg1HexController.dispose();
    _bg2HexController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Helper / Utility Methods
  // ------------------------------------------------------------
  String _hexString(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase().substring(2)}';
  }

  Color? _tryParseHex(String input) {
    final clean = input.trim().replaceAll('#', '');
    if (clean.length == 6) {
      final int? val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final int? val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  Color _interpolateGrayscale(double t) {
    return Color.lerp(
      const Color(0xFFFFFFFF),
      const Color(0xFF000000),
      t,
    )!;
  }

  void _onBg1HexChanged(String val) {
    final parsed = _tryParseHex(val);
    if (parsed != null) {
      setState(() {
        _background1Color = parsed;
        _selectedPaletteIndex = -1;
      });
    }
  }

  void _onBg1OpacityChanged(double val) {
    setState(() {
      _background1Opacity = val;
    });
  }

  void _onBg1SliderChanged(double val) {
    final color = _interpolateGrayscale(val);
    setState(() {
      _bg1SliderValue = val;
      _background1Color = color;
      _selectedPaletteIndex = -1;
      _bg1HexController.text = _hexString(color);
    });
  }

  void _onPaletteColorSelected(int index) {
    final color = _paletteColors[index];
    setState(() {
      _selectedPaletteIndex = index;
      _background1Color = color;
      _bg1HexController.text = _hexString(color);

      if (color == const Color(0xFFFFFFFF)) {
        _bg1SliderValue = 0.0;
      } else if (color == const Color(0xFF000000)) {
        _bg1SliderValue = 1.0;
      } else if (color == const Color(0xFF8E8E93)) {
        _bg1SliderValue = 0.5;
      }
    });
  }

  void _onBg2HexChanged(String val) {
    final parsed = _tryParseHex(val);
    if (parsed != null) {
      setState(() {
        _background2Color = parsed;
      });
    }
  }

  void _onBg2OpacityChanged(double val) {
    setState(() {
      _background2Opacity = val;
    });
  }

  void _onBg2ColorPresetSelected(Color color) {
    setState(() {
      _background2Color = color;
      _bg2HexController.text = _hexString(color);
    });
  }

  void _resetToDefaults() {
    setState(() {
      _background1Color = const Color(0xFF1E1B4B);
      _background1Opacity = 1.0;
      _bg1SliderValue = 0.5;
      _selectedPaletteIndex = -1;
      _bg1HexController.text = _hexString(_background1Color);

      _background2Color = const Color(0xFFFF3B30);
      _background2Opacity = 0.45;
      _bg2HexController.text = _hexString(_background2Color);

      _labScrollingEnabled = true;
      _stage2FlexEnabled = true;
      _stage2ChildFollow = 0.0;
      _currentStageIndex = 0;
      _labMode = 0;
      _backButtonTapCount = 0;
      _backButtonComparisonMode = true;
    });
    if (_stagePageController.hasClients) {
      _stagePageController.jumpToPage(0);
    }
  }

  void _applyScenario(Color bg1, double op1, Color bg2, double op2) {
    setState(() {
      _background1Color = bg1;
      _background1Opacity = op1;
      _bg1HexController.text = _hexString(bg1);

      _background2Color = bg2;
      _background2Opacity = op2;
      _bg2HexController.text = _hexString(bg2);
      _selectedPaletteIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Theme Tokens
    final pageBg = isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7);
    final panelBg = isDark ? const Color(0xFF151518) : Colors.white;
    final panelBorder =
        isDark ? const Color(0xFF28282C) : const Color(0xFFE5E5EA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73);
    final inputBg = isDark ? const Color(0xFF1C1C20) : const Color(0xFFF5F5F7);
    final dividerColor =
        isDark ? const Color(0xFF242428) : const Color(0xFFEBEBF0);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;

            return Column(
              children: [
                // ── App Header / Top Navigation Bar ───────────────────────────
                _buildHeader(context, textPrimary, textSecondary, panelBg,
                    panelBorder, isDark),

                // ── Lab Mode Selector Bar (Standard vs LB-R5 Back Button) ────
                _buildLabModeSelectorBar(
                  textPrimary,
                  textSecondary,
                  panelBg,
                  panelBorder,
                  inputBg,
                  isDark,
                ),

                // ── Lab Scrolling Control Bar (Top of Page) ───────────────────
                _buildLabScrollingBar(
                  textPrimary,
                  textSecondary,
                  panelBg,
                  panelBorder,
                  inputBg,
                ),

                // ── Main Body (Responsive Split or Single-Column Scroll) ───────
                Expanded(
                  child: isWide
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Preview Stage (Hero)
                              Expanded(
                                flex: 6,
                                child: _buildPreviewStage(isDark, isWide: true),
                              ),
                              const SizedBox(width: 24),
                              // Right: Parameters Panel
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  physics: _labScrollingEnabled
                                      ? const AlwaysScrollableScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  child: _buildParametersPanel(
                                    panelBg,
                                    panelBorder,
                                    textPrimary,
                                    textSecondary,
                                    inputBg,
                                    dividerColor,
                                    isDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          physics: _labScrollingEnabled
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Preview Stage (Hero)
                              _buildPreviewStage(isDark, isWide: false),
                              const SizedBox(height: 16),
                              // Parameters Inspector Panel
                              _buildParametersPanel(
                                panelBg,
                                panelBorder,
                                textPrimary,
                                textSecondary,
                                inputBg,
                                dividerColor,
                                isDark,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // App Header Bar
  // ------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    Color textPrimary,
    Color textSecondary,
    Color panelBg,
    Color panelBorder,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: panelBorder),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title & Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Liquid Glass Button Lab',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF24242A)
                            : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NATIVE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Optical Layering & Depth',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Reset Button
          TextButton.icon(
            onPressed: _resetToDefaults,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: panelBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: panelBorder),
              ),
            ),
            icon: Icon(Icons.refresh_rounded, size: 14, color: textSecondary),
            label: Text(
              'Reset',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Lab Mode Selector Bar (Standard vs LB-R5 Circular Back Button)
  // ------------------------------------------------------------
  Widget _buildLabModeSelectorBar(
    Color textPrimary,
    Color textSecondary,
    Color panelBg,
    Color panelBorder,
    Color inputBg,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: panelBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                key: const ValueKey('lab_mode_standard_button'),
                onTap: () {
                  if (_labMode != 0) {
                    setState(() {
                      _labMode = 0;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _labMode == 0
                        ? (isDark
                            ? const Color(0xFF2C2C32)
                            : const Color(0xFFE5E5EA))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      'Standard Button Lab',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight:
                            _labMode == 0 ? FontWeight.w700 : FontWeight.w500,
                        color: _labMode == 0 ? textPrimary : textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                key: const ValueKey('lab_mode_circular_back_button'),
                onTap: () {
                  if (_labMode != 1) {
                    setState(() {
                      _labMode = 1;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _labMode == 1
                        ? const Color(0xFF007AFF).withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: _labMode == 1
                        ? Border.all(
                            color: const Color(0xFF007AFF)
                                .withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _labMode == 1
                              ? const Color(0xFF007AFF)
                              : Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Circular Back (44×44)',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight:
                                _labMode == 1 ? FontWeight.w700 : FontWeight.w500,
                            color: _labMode == 1
                                ? (isDark ? Colors.white : const Color(0xFF007AFF))
                                : textSecondary,
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

  // ------------------------------------------------------------
  // Lab Scrolling Control Bar (Pinned Top of Page)
  // ------------------------------------------------------------
  Widget _buildLabScrollingBar(
    Color textPrimary,
    Color textSecondary,
    Color panelBg,
    Color panelBorder,
    Color inputBg,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: panelBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swipe_vertical_rounded,
                    size: 15,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Lab Scrolling',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_labScrollingEnabled
                              ? const Color(0xFF34C759)
                              : const Color(0xFFFF3B30))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (_labScrollingEnabled
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF3B30))
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _labScrollingEnabled ? 'SCROLL ON' : 'SCROLL OFF',
                      style: GoogleFonts.robotoMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: _labScrollingEnabled
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  key: const ValueKey('lab_scrolling_on_button'),
                  onTap: () {
                    if (!_labScrollingEnabled) {
                      setState(() {
                        _labScrollingEnabled = true;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _labScrollingEnabled
                          ? const Color(0xFF34C759).withValues(alpha: 0.20)
                          : inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _labScrollingEnabled
                            ? const Color(0xFF34C759)
                            : panelBorder,
                        width: _labScrollingEnabled ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _labScrollingEnabled
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 11,
                          color: _labScrollingEnabled
                              ? const Color(0xFF34C759)
                              : textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'ON',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  key: const ValueKey('lab_scrolling_off_button'),
                  onTap: () {
                    if (_labScrollingEnabled) {
                      setState(() {
                        _labScrollingEnabled = false;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_labScrollingEnabled
                          ? const Color(0xFFFF3B30).withValues(alpha: 0.20)
                          : inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_labScrollingEnabled
                            ? const Color(0xFFFF3B30)
                            : panelBorder,
                        width: !_labScrollingEnabled ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !_labScrollingEnabled
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 11,
                          color: !_labScrollingEnabled
                              ? const Color(0xFFFF3B30)
                              : textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'OFF',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // THE PREVIEW STAGE (Hero Viewport)
  // ------------------------------------------------------------
  Widget _buildPreviewStage(bool isDark, {required bool isWide}) {
    final effectiveBg1 =
        _background1Color.withValues(alpha: _background1Opacity);
    final effectiveBg2 =
        _background2Color.withValues(alpha: _background2Opacity);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111114) : const Color(0xFFE8E8ED),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF28282E) : const Color(0xFFD6D6DD),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage Top Status Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF34C759),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PREVIEW STAGE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFA1A1AA)
                            : const Color(0xFF71717A),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Depth Hierarchy Indicator Tag
                Flexible(
                  child: Text(
                    'Canvas → Island → Glass',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF71717A)
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Dedicated Stage Viewport ────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: isWide ? 1.6 : 1.35,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // ====================================================
                  // LAYER 1: BACKGROUND 1 (Deepest / Base Surface)
                  // ====================================================
                  ColoredBox(
                    key: const ValueKey('background_layer_1'),
                    color: effectiveBg1,
                  ),

                  // Stage Grid Pattern (Subtle workbench alignment markers)
                  _buildStageGrid(isDark),

                  // Background 1 Corner Watermark
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        'BG 1: ${_hexString(_background1Color)}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 8.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Stage Tabs Switcher
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _buildStageSwitcherTabs(isDark),
                  ),

                  // ====================================================
                  // LAYER 2 & 3: BACKGROUND 2 ISLAND + HORIZONTAL STAGE CAROUSEL
                  // ====================================================
                  Center(
                    child: LayoutBuilder(
                      builder: (context, stageConstraints) {
                        final islandWidth = (stageConstraints.maxWidth * 0.86)
                            .clamp(220.0, 310.0);
                        final islandHeight = (stageConstraints.maxHeight * 0.70)
                            .clamp(120.0, 160.0);
                        final buttonWidth =
                            (islandWidth - 28.0).clamp(170.0, 210.0);

                        return Container(
                          width: islandWidth,
                          height: islandHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: isDark ? 0.22 : 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.30),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22.5),
                            child: Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: [
                                // Layer 2: ColoredBox for Background 2
                                ColoredBox(
                                  key: const ValueKey('background_layer_2'),
                                  color: effectiveBg2,
                                ),

                                // Background 2 Identifier Badge
                                Positioned(
                                  top: 6,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'BG 2: ${_hexString(_background2Color)} (${(_background2Opacity * 100).toInt()}%)',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 8.0,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                // ============================================
                                // LAYER 3: HORIZONTAL STAGE CAROUSEL (PAGEVIEW)
                                // ============================================
                                if (_labMode == 0)
                                  PageView(
                                  key: const ValueKey(
                                      'stage_carousel_page_view'),
                                  controller: _stagePageController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentStageIndex = index;
                                    });
                                  },
                                  children: [
                                    // ────────────────────────────────────────
                                    // STAGE 1: NATIVE LIQUID GLASS BUTTON
                                    // ────────────────────────────────────────
                                    Center(
                                      child: LiquidGlassButton(
                                        key: const ValueKey(
                                            'native_liquid_glass_button'),
                                        label: 'Continue',
                                        icon: Icons.arrow_forward_rounded,
                                        width: buttonWidth,
                                        height: 48.0,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        touch: const LiquidGlassTouch(
                                          flex: LiquidGlassFlex.subtle(),
                                        ),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: Colors.white,
                                                      size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'LiquidGlassButton tapped!',
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              duration: const Duration(
                                                  milliseconds: 900),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              backgroundColor:
                                                  const Color(0xFF1E1E24),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // ────────────────────────────────────────
                                    // STAGE 2: QUICK NOTES "CREATE FOLDER" GLASS
                                    // ────────────────────────────────────────
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Stage 2 Experimental Badge (Tappable to toggle baseline vs physics)
                                          GestureDetector(
                                            key: const ValueKey(
                                                'stage2_experiment_badge'),
                                            onTap: () {
                                              setState(() {
                                                _stage2FlexEnabled =
                                                    !_stage2FlexEnabled;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: (_stage2FlexEnabled
                                                        ? const Color(
                                                            0xFFFF9500)
                                                        : const Color(
                                                            0xFF007AFF))
                                                    .withValues(alpha: 0.16),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: (_stage2FlexEnabled
                                                          ? const Color(
                                                              0xFFFF9500)
                                                          : const Color(
                                                              0xFF007AFF))
                                                      .withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 5,
                                                    height: 5,
                                                    decoration: BoxDecoration(
                                                      color: _stage2FlexEnabled
                                                          ? const Color(
                                                              0xFFFF9500)
                                                          : const Color(
                                                              0xFF007AFF),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _stage2FlexEnabled
                                                        ? 'EXPERIMENTAL TOUCH: PRESS + STRETCH'
                                                        : 'CLEAN BASELINE: STATIC',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 8.0,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _stage2FlexEnabled
                                                          ? const Color(
                                                              0xFFFF9500)
                                                          : const Color(
                                                              0xFF007AFF),
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          QuickNotesLiquidGlassButton(
                                            key: const ValueKey(
                                                'quick_notes_create_folder_glass'),
                                            isDark: isDark,
                                            width:
                                                buttonWidth.clamp(170.0, 200.0),
                                            height: 50.0,
                                            enableFlex: _stage2FlexEnabled,
                                            childFollow: _stage2ChildFollow,
                                            onTap: () {
                                              ScaffoldMessenger.of(context)
                                                  .hideCurrentSnackBar();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .folder_open_rounded,
                                                          color: Colors.white,
                                                          size: 18),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Quick Notes "Create Folder" tapped!',
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  duration: const Duration(
                                                      milliseconds: 900),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  backgroundColor:
                                                      const Color(0xFF1E1E24),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                                else
                                  _buildCircularBackButtonValidationStage(
                                      context, isDark, buttonWidth),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Stage Footer Annotation & Indicator Dots
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_labMode == 0) ...[
                              Row(
                                key: const ValueKey('stage_indicator_dots'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildIndicatorDot(0),
                                  const SizedBox(width: 4),
                                  _buildIndicatorDot(1),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _currentStageIndex == 0
                                    ? 'STAGE 1: LG Easy'
                                    : (_stage2FlexEnabled
                                        ? 'STAGE 2: Quick Notes (Press + Stretch)'
                                        : 'STAGE 2: Quick Notes (Clean Baseline)'),
                                key: const ValueKey('stage_active_label'),
                                style: const TextStyle(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'LB-R5: Circular Back Button (44×44, r:22) | Taps: $_backButtonTapCount',
                                key: const ValueKey('stage_active_label'),
                                style: const TextStyle(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // LB-R5 Dedicated Circular Back Button Validation Stage
  // ------------------------------------------------------------
  Widget _buildCircularBackButtonValidationStage(
    BuildContext context,
    bool isDark,
    double buttonWidth,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Validation Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF007AFF).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _backButtonComparisonMode
                        ? 'LB-R5: 44×44 CIRCULAR vs 200×50 REFERENCE'
                        : 'LB-R5: 44×44 CIRCULAR (ISOLATED)',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF007AFF),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Main Interaction Display
          if (_backButtonComparisonMode)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Experimental 44x44 Circular Back Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExperimentalQuickNotesLiquidGlassBackButton(
                      key: const ValueKey('experimental_circular_back_button'),
                      isDark: isDark,
                      enableFlex: _stage2FlexEnabled,
                      childFollow: _stage2ChildFollow,
                      onPressed: () {
                        setState(() {
                          _backButtonTapCount++;
                        });
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Circular Back Button tapped! ($_backButtonTapCount)',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(milliseconds: 900),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFF1E1E24),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '44×44 r:22',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // 2. Reference Standard Validated Button (200x50)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QuickNotesLiquidGlassButton(
                      key: const ValueKey('reference_standard_button'),
                      isDark: isDark,
                      width: 160.0,
                      height: 44.0,
                      enableFlex: _stage2FlexEnabled,
                      childFollow: _stage2ChildFollow,
                      label: 'Create Folder',
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.folder_open_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Reference Button tapped!',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(milliseconds: 900),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFF1E1E24),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'REFERENCE',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            // Isolated 44x44 Circular Back Button
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExperimentalQuickNotesLiquidGlassBackButton(
                  key: const ValueKey(
                      'experimental_circular_back_button_isolated'),
                  isDark: isDark,
                  enableFlex: _stage2FlexEnabled,
                  childFollow: _stage2ChildFollow,
                  onPressed: () {
                    setState(() {
                      _backButtonTapCount++;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Circular Back Button tapped! ($_backButtonTapCount)',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 900),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFF1E1E24),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '44.0 × 44.0 | Radius 22.0',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 8),
          // View Mode Switcher (Side-by-Side vs Isolated)
          GestureDetector(
            key: const ValueKey('back_button_view_mode_toggle'),
            onTap: () {
              setState(() {
                _backButtonComparisonMode = !_backButtonComparisonMode;
              });
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                _backButtonComparisonMode
                    ? 'SWITCH TO ISOLATED VIEW'
                    : 'SWITCH TO SIDE-BY-SIDE VIEW',
                style: GoogleFonts.inter(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Subtle Technical Grid Overlay
  // ------------------------------------------------------------
  Widget _buildStageGrid(bool isDark) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _StageGridPainter(
          gridColor:
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Stage Navigation Switcher Tabs & Indicator Dots
  // ------------------------------------------------------------
  Widget _buildStageSwitcherTabs(bool isDark) {
    if (_labMode == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'LB-R5 BACK BUTTON',
              style: GoogleFonts.inter(
                fontSize: 9.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF007AFF),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStageTabItem(
            key: const ValueKey('stage_tab_1'),
            index: 0,
            label: '1. LG Easy',
            isActive: _currentStageIndex == 0,
          ),
          const SizedBox(width: 3),
          _buildStageTabItem(
            key: const ValueKey('stage_tab_2'),
            index: 1,
            label: '2. Quick Notes',
            isActive: _currentStageIndex == 1,
          ),
        ],
      ),
    );
  }

  Widget _buildStageTabItem({
    required Key key,
    required int index,
    required String label,
    required bool isActive,
  }) {
    return GestureDetector(
      key: key,
      onTap: () {
        _stagePageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorDot(int index) {
    final isActive = _currentStageIndex == index;
    return GestureDetector(
      key: ValueKey('stage_dot_$index'),
      onTap: () {
        _stagePageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: isActive ? 14 : 5,
        height: 5,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PARAMETERS / INSPECTOR PANEL
  // ------------------------------------------------------------
  Widget _buildParametersPanel(
    Color panelBg,
    Color panelBorder,
    Color textPrimary,
    Color textSecondary,
    Color inputBg,
    Color dividerColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: panelBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inspector Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SURFACE PARAMETERS',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIVE TUNING',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF007AFF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ============================================================
          // SECTION 1: BACKGROUND 1 (Base Layer)
          // ============================================================
          _buildLayerSectionHeader(
            title: 'Background 1 (Base Canvas)',
            color: _background1Color,
            opacity: _background1Opacity,
            textPrimary: textPrimary,
          ),
          const SizedBox(height: 10),

          // Color & HEX Input Row
          _buildColorInputRow(
            controller: _bg1HexController,
            color: _background1Color,
            onChanged: _onBg1HexChanged,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            inputBg: inputBg,
            panelBorder: panelBorder,
            fieldKey: const ValueKey('bg1_hex_input'),
          ),
          const SizedBox(height: 12),

          // Opacity Control Row
          _buildOpacitySlider(
            label: 'Opacity',
            value: _background1Opacity,
            sliderKey: const ValueKey('bg1_opacity_slider'),
            activeColor: _background1Color,
            onChanged: _onBg1OpacityChanged,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // Background 1 Palette Swatches (12 Colors)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_paletteColors.length, (index) {
                final color = _paletteColors[index];
                final isSelected = _selectedPaletteIndex == index;
                final checkColor = color.computeLuminance() < 0.5
                    ? Colors.white
                    : Colors.black;

                return GestureDetector(
                  key: ValueKey('palette_swatch_$index'),
                  onTap: () => _onPaletteColorSelected(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 7),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : (isDark ? Colors.white24 : Colors.black12),
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 14, color: checkColor)
                        : null,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),

          // Background 1 Grayscale Slider (White -> Black)
          Row(
            children: [
              Text(
                'White',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: textPrimary.withValues(alpha: 0.8),
                    inactiveTrackColor: textSecondary.withValues(alpha: 0.25),
                    thumbColor: textPrimary,
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    key: const ValueKey('bg1_slider'),
                    value: _bg1SliderValue,
                    min: 0.0,
                    max: 1.0,
                    onChanged: _onBg1SliderChanged,
                  ),
                ),
              ),
              Text(
                'Black',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),

          Divider(height: 32, thickness: 1, color: dividerColor),

          // ============================================================
          // SECTION 2: BACKGROUND 2 (Surface Island)
          // ============================================================
          _buildLayerSectionHeader(
            title: 'Background 2 (Surface Island)',
            color: _background2Color,
            opacity: _background2Opacity,
            textPrimary: textPrimary,
          ),
          const SizedBox(height: 10),

          // Color & HEX Input Row
          _buildColorInputRow(
            controller: _bg2HexController,
            color: _background2Color,
            onChanged: _onBg2HexChanged,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            inputBg: inputBg,
            panelBorder: panelBorder,
            fieldKey: const ValueKey('bg2_hex_input'),
          ),
          const SizedBox(height: 12),

          // Opacity Control Row
          _buildOpacitySlider(
            label: 'Opacity',
            value: _background2Opacity,
            sliderKey: const ValueKey('bg2_opacity_slider'),
            activeColor: _background2Color,
            onChanged: _onBg2OpacityChanged,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          // Background 2 Quick Accent Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _bg2Presets.map((color) {
                final isSelected =
                    _background2Color.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => _onBg2ColorPresetSelected(color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : Colors.black12,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            size: 14,
                            color: color.computeLuminance() < 0.5
                                ? Colors.white
                                : Colors.black,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          Divider(height: 32, thickness: 1, color: dividerColor),

          // ============================================================
          // CURATED LABORATORY SCENARIOS (Quick Test Presets)
          // ============================================================
          Text(
            'TEST SCENARIOS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScenarioChip(
                label: 'High Contrast',
                bg1: const Color(0xFFFFFFFF),
                op1: 1.0,
                bg2: const Color(0xFF007AFF),
                op2: 0.50,
                inputBg: inputBg,
                panelBorder: panelBorder,
                textPrimary: textPrimary,
              ),
              _buildScenarioChip(
                label: 'Vibrant Bloom',
                bg1: const Color(0xFF1C1C1E),
                op1: 1.0,
                bg2: const Color(0xFFFF9500),
                op2: 0.60,
                inputBg: inputBg,
                panelBorder: panelBorder,
                textPrimary: textPrimary,
              ),
              _buildScenarioChip(
                label: 'Frosted Emerald',
                bg1: const Color(0xFF0D0E12),
                op1: 1.0,
                bg2: const Color(0xFF34C759),
                op2: 0.40,
                inputBg: inputBg,
                panelBorder: panelBorder,
                textPrimary: textPrimary,
              ),
              _buildScenarioChip(
                label: 'Obsidian Glow',
                bg1: const Color(0xFF000000),
                op1: 1.0,
                bg2: const Color(0xFFFF3B30),
                op2: 0.45,
                inputBg: inputBg,
                panelBorder: panelBorder,
                textPrimary: textPrimary,
              ),
            ],
          ),

          Divider(height: 32, thickness: 1, color: dividerColor),

          // ============================================================
          // SECTION 3: STAGE 2 TOUCH PHYSICS (Quick Notes Glass)
          // ============================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Stage 2: Quick Notes Touch Mode',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (_stage2FlexEnabled
                          ? const Color(0xFFFF9500)
                          : const Color(0xFF007AFF))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (_stage2FlexEnabled
                            ? const Color(0xFFFF9500)
                            : const Color(0xFF007AFF))
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _stage2FlexEnabled ? 'PRESS + STRETCH' : 'STATIC BASELINE',
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _stage2FlexEnabled
                        ? const Color(0xFFFF9500)
                        : const Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                key: const ValueKey('stage2_baseline_mode_button'),
                onTap: () {
                  setState(() {
                    _stage2FlexEnabled = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: !_stage2FlexEnabled
                        ? const Color(0xFF007AFF).withValues(alpha: 0.20)
                        : inputBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !_stage2FlexEnabled
                          ? const Color(0xFF007AFF)
                          : panelBorder,
                      width: !_stage2FlexEnabled ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        !_stage2FlexEnabled
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 12,
                        color: !_stage2FlexEnabled
                            ? const Color(0xFF007AFF)
                            : textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Static Baseline',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                key: const ValueKey('stage2_press_mode_button'),
                onTap: () {
                  setState(() {
                    _stage2FlexEnabled = true;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _stage2FlexEnabled
                        ? const Color(0xFFFF9500).withValues(alpha: 0.20)
                        : inputBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _stage2FlexEnabled
                          ? const Color(0xFFFF9500)
                          : panelBorder,
                      width: _stage2FlexEnabled ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _stage2FlexEnabled
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 12,
                        color: _stage2FlexEnabled
                            ? const Color(0xFFFF9500)
                            : textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Press + Stretch',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, thickness: 1, color: dividerColor),

          // Stage 2 Content Follow (Deformation Ride-Along)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Content Follow',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              Container(
                key: const ValueKey('stage2_content_follow_badge'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${(_stage2ChildFollow * 100).toInt()}% (${_stage2ChildFollow.toStringAsFixed(2)})',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildContentFollowOption(0.00, '0%', inputBg, panelBorder,
                  textPrimary, textSecondary),
              _buildContentFollowOption(0.25, '25%', inputBg, panelBorder,
                  textPrimary, textSecondary),
              _buildContentFollowOption(0.50, '50%', inputBg, panelBorder,
                  textPrimary, textSecondary),
              _buildContentFollowOption(0.75, '75%', inputBg, panelBorder,
                  textPrimary, textSecondary),
              _buildContentFollowOption(1.00, '100%', inputBg, panelBorder,
                  textPrimary, textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Helper: Content Follow Selection Option
  // ------------------------------------------------------------
  Widget _buildContentFollowOption(
    double value,
    String label,
    Color inputBg,
    Color panelBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = (_stage2ChildFollow - value).abs() < 0.01;
    final int percentInt = (value * 100).toInt();

    return GestureDetector(
      key: ValueKey('stage2_content_follow_${percentInt}_button'),
      onTap: () {
        if (!isSelected) {
          setState(() {
            _stage2ChildFollow = value;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007AFF).withValues(alpha: 0.20)
              : inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : panelBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 11,
              color: isSelected ? const Color(0xFF007AFF) : textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Helper: Layer Section Header
  // ------------------------------------------------------------
  Widget _buildLayerSectionHeader({
    required String title,
    required Color color,
    required double opacity,
    required Color textPrimary,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            '${_hexString(color)} · ${(opacity * 100).toInt()}%',
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Helper: Compact Color Control Row (Swatch + Monospace Input)
  // ------------------------------------------------------------
  Widget _buildColorInputRow({
    required TextEditingController controller,
    required Color color,
    required ValueChanged<String> onChanged,
    required Color textPrimary,
    required Color textSecondary,
    required Color inputBg,
    required Color panelBorder,
    required Key fieldKey,
  }) {
    return Row(
      children: [
        // Live Color Preview Swatch
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.20),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Monospace HEX TextField
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: panelBorder),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              key: fieldKey,
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '#RRGGBB',
                hintStyle: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Helper: Opacity Slider Row
  // ------------------------------------------------------------
  Widget _buildOpacitySlider({
    required String label,
    required double value,
    required Key sliderKey,
    required Color activeColor,
    required ValueChanged<double> onChanged,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.12),
              thumbColor: activeColor,
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              key: sliderKey,
              value: value,
              min: 0.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(value * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // Helper: Scenario Preset Chip
  // ------------------------------------------------------------
  Widget _buildScenarioChip({
    required String label,
    required Color bg1,
    required double op1,
    required Color bg2,
    required double op2,
    required Color inputBg,
    required Color panelBorder,
    required Color textPrimary,
  }) {
    return InkWell(
      onTap: () => _applyScenario(bg1, op1, bg2, op2),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: panelBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini composite dots
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: bg1,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: bg2,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------
// Custom Painter for Workbench Grid Pattern
// --------------------------------------------------------------
class _StageGridPainter extends CustomPainter {
  final Color gridColor;

  const _StageGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const double step = 24.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StageGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}

// ============================================================================
// STAGE 2: PRODUCTION QUICK NOTES LIQUID GLASS BUTTON
// ============================================================================
// Stage 2 consumes the extracted production component:
// [QuickNotesLiquidGlassButton] from `lib/views/widgets/quick_notes_liquid_glass_button.dart`

