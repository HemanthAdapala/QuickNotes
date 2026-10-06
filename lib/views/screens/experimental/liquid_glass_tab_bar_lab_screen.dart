import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../widgets/quick_notes_liquid_glass_tab_bar.dart';

/// Phase 7A: Interactive Comparison Laboratory for Liquid Glass TabBar.
///
/// Compares:
///   Stage 1: Native Reference (`LiquidGlassTabBar` from `liquid_glass_easy: 4.3.1`)
///   Stage 2: Quick Notes Recreation (Quick Notes frosted glass look + forensic physical interaction)
///
/// Stage 2 recreates the full Phase 7 forensic baseline:
///   - Harmonic travel spring (travelStiffness: 280, travelDamping: 31.4)
///   - Dual-axis lift springs (liftStiffness: 250, dampingX: 19.0, dampingY: 22.1)
///   - Pill grow height (12.0)
///   - Rolling-window acceleration squash/stretch (sensitivity: 0.00007, maxDeformation: 0.12, responseTime: 0.18s)
///   - Direction-keyed deformation with smooth reversal (signTau: 0.25s)
///   - Fluid exponential drag follow (followTau: 0.05s) with 100ms long press and 0.2-cell drag discrimination
///   - Landing handover (handoverStart: 0.92, handoverTau: 0.09s, glassReturnTau: 0.05s)
///   - Dual-layer aperture icon reveal (outside / inside pill clippers)
class LiquidGlassTabBarLabScreen extends StatefulWidget {
  const LiquidGlassTabBarLabScreen({super.key});

  @override
  State<LiquidGlassTabBarLabScreen> createState() =>
      _LiquidGlassTabBarLabScreenState();
}

class _LiquidGlassTabBarLabScreenState
    extends State<LiquidGlassTabBarLabScreen> {
  // ── Navigation & Carousel ──────────────────────────────────────────
  late final PageController _stagePageController;
  int _currentStageIndex = 0;
  bool _labScrollingEnabled = true;

  // ── Background Layers ──────────────────────────────────────────────
  Color _background1Color = const Color(0xFFFFFFFF); // Pure White default
  double _background1Opacity = 1.0;

  Color _background2Color =
      const Color(0xFFFFFFFF); // Pure White Island default
  double _background2Opacity = 1.0;

  // ── Stage 2 Physics Inspector Values (Forensic Defaults) ────────────
  double _travelStiffness = 280.0;
  double _travelDamping = 31.4;
  double _liftStiffness = 250.0;
  double _liftDampingX = 19.0;
  double _liftDampingY = 22.1;
  double _pillGrowHeight = 12.0;
  double _sensitivity = 0.00007;
  double _maxDeformation = 0.12;
  double _responseTime = 0.18;
  double _followTau = 0.05;
  double _signTau = 0.25;
  int _longPressMs = 100;
  double _dragThreshold = 0.20;

  // Selected tab states
  int _stage1SelectedIndex = 0;
  int _stage2SelectedIndex = 0;

  // Phase 7D.2: Runtime Forensic Debug State
  bool _debugMainNavPhysicsActive = false;
  bool _debugFabAnimationActive = false;

  @override
  void initState() {
    super.initState();
    _stagePageController = PageController();
  }

  @override
  void dispose() {
    _stagePageController.dispose();
    super.dispose();
  }

  void _resetToForensicDefaults() {
    setState(() {
      _background1Color = const Color(0xFFFFFFFF);
      _background1Opacity = 1.0;

      _background2Color = const Color(0xFFFFFFFF);
      _background2Opacity = 1.0;

      _labScrollingEnabled = true;
      _stage1SelectedIndex = 0;
      _stage2SelectedIndex = 0;
      _debugMainNavPhysicsActive = false;
      _debugFabAnimationActive = false;

      // Forensic baselines
      _travelStiffness = 280.0;
      _travelDamping = 31.4;
      _liftStiffness = 250.0;
      _liftDampingX = 19.0;
      _liftDampingY = 22.1;
      _pillGrowHeight = 12.0;
      _sensitivity = 0.00007;
      _maxDeformation = 0.12;
      _responseTime = 0.18;
      _followTau = 0.05;
      _signTau = 0.25;
      _longPressMs = 100;
      _dragThreshold = 0.20;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                // ── App Header Bar ───────────────────────────────────────────
                _buildHeader(context, textPrimary, textSecondary, panelBg,
                    panelBorder, isDark),

                // ── Lab Scrolling Control Bar (Pinned Top of Page) ───────────
                _buildLabScrollingBar(
                  textPrimary,
                  textSecondary,
                  panelBg,
                  panelBorder,
                  inputBg,
                ),

                // ── Main Body (Wide Split or Single-Column Scroll) ───────────
                Expanded(
                  child: isWide
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildPreviewStage(isDark, isWide: true),
                              ),
                              const SizedBox(width: 24),
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
                              _buildPreviewStage(isDark, isWide: false),
                              const SizedBox(height: 16),
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

  // ── Header Bar ───────────────────────────────────────────────────────────
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Liquid Glass TabBar Lab',
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
                        'PHASE 7A',
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
                  'Native Reference vs Quick Notes Navigation (Physics)',
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
          TextButton.icon(
            key: const ValueKey('tabbar_lab_reset_button'),
            onPressed: _resetToForensicDefaults,
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

  // ── Lab Scrolling Toggle Bar ─────────────────────────────────────────────
  Widget _buildLabScrollingBar(
    Color textPrimary,
    Color textSecondary,
    Color panelBg,
    Color panelBorder,
    Color inputBg,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(14),
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
                    _labScrollingEnabled ? Icons.swipe_vertical : Icons.lock,
                    size: 14,
                    color: _labScrollingEnabled
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Lab Scrolling',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                  key: const ValueKey('tabbar_lab_scrolling_on_button'),
                  onTap: () {
                    if (!_labScrollingEnabled) {
                      setState(() => _labScrollingEnabled = true);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  key: const ValueKey('tabbar_lab_scrolling_off_button'),
                  onTap: () {
                    if (_labScrollingEnabled) {
                      setState(() => _labScrollingEnabled = false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  // ── Preview Stage (Hero Carousel) ────────────────────────────────────────
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
          // Header info
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrow = headerConstraints.maxWidth < 320;
                final leftInfo = Row(
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
                    Flexible(
                      child: Text(
                        'TABBAR PREVIEW STAGE',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFA1A1AA)
                              : const Color(0xFF71717A),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                );

                final rightStageBadge = Text(
                  _currentStageIndex == 0
                      ? 'STAGE 1: NATIVE'
                      : 'STAGE 2: QUICK NOTES NAVIGATION',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.robotoMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _currentStageIndex == 0
                        ? const Color(0xFF007AFF)
                        : const Color(0xFFFF9500),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      leftInfo,
                      const SizedBox(height: 3),
                      rightStageBadge,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: leftInfo),
                    const SizedBox(width: 8),
                    rightStageBadge,
                  ],
                );
              },
            ),
          ),

          // Viewport AspectRatio
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: isWide ? 1.6 : 1.35,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // Layer 1: Background 1
                  ColoredBox(
                    key: const ValueKey('tabbar_lab_bg_layer_1'),
                    color: effectiveBg1,
                  ),

                  // Stage Tabs Switcher
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _buildStageSwitcherTabs(isDark),
                  ),

                  // Center Island
                  Center(
                    child: LayoutBuilder(
                      builder: (context, stageConstraints) {
                        final maxIslandWidth = stageConstraints.maxWidth - 8.0;
                        final islandWidth = (stageConstraints.maxWidth * 0.90)
                            .clamp(200.0, 360.0)
                            .clamp(0.0, maxIslandWidth);
                        final islandHeight = (stageConstraints.maxHeight * 0.72)
                            .clamp(140.0, 180.0);
                        final barWidth =
                            (islandWidth - 20.0).clamp(180.0, 320.0);

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
                                // Layer 2: Background 2
                                ColoredBox(
                                  key: const ValueKey('tabbar_lab_bg_layer_2'),
                                  color: effectiveBg2,
                                ),

                                // Carousel
                                PageView(
                                  key: const ValueKey(
                                      'tabbar_stage_carousel_page_view'),
                                  physics: const NeverScrollableScrollPhysics(),
                                  controller: _stagePageController,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentStageIndex = index;
                                    });
                                  },
                                  children: [
                                    // ── STAGE 1: NATIVE REFERENCE ────────────
                                    Center(
                                      child: _buildStage1Native(barWidth),
                                    ),

                                    // ── STAGE 2: QUICK NOTES RECREATION ──────
                                    Center(
                                      child: _buildStage2QuickNotes(
                                          barWidth, isDark),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Carousel Dots & Label
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStageDot(0, '1. Native'),
                        const SizedBox(width: 8),
                        _buildStageDot(1, '2. Quick Notes Navigation'),
                      ],
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

  Widget _buildStageDot(int index, String label) {
    final isSelected = _currentStageIndex == index;
    return GestureDetector(
      onTap: () {
        _stagePageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (index == 0 ? const Color(0xFF007AFF) : const Color(0xFFFF9500))
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.0,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStageSwitcherTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStageTab(0, '1. Native'),
          _buildStageTab(1, '2. Quick Notes Navigation'),
        ],
      ),
    );
  }

  Widget _buildStageTab(int index, String title) {
    final isSelected = _currentStageIndex == index;
    return GestureDetector(
      key: ValueKey('tabbar_stage_tab_$index'),
      onTap: () {
        _stagePageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (index == 0 ? const Color(0xFF007AFF) : const Color(0xFFFF9500))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Stage 1: Native Reference TabBar ─────────────────────────────────────
  Widget _buildStage1Native(double barWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF007AFF).withValues(alpha: 0.40),
            ),
          ),
          child: Text(
            'STAGE 1: NATIVE LIQUID GLASS TABBAR',
            style: GoogleFonts.inter(
              fontSize: 8.0,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF007AFF),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: barWidth,
          height: 64.0,
          child: LiquidGlassTabBar(
            key: const ValueKey('native_liquid_glass_tab_bar'),
            width: barWidth,
            height: 64.0,
            margin: EdgeInsets.zero,
            selectedIndex: _stage1SelectedIndex,
            onChanged: (idx) {
              setState(() => _stage1SelectedIndex = idx);
            },
            itemStyle: const LiquidGlassTabItemStyle(
              iconSize: 20.0,
              labelFontSize: 10.0,
              iconLabelGap: 2.0,
            ),
            pillStyle: const LiquidGlassTabPillStyle(
              mode: LiquidGlassPillMode.both,
              animated: true,
              travelStiffness: 280,
              travelDamping: 31.4,
              growHeight: 12,
            ),
            items: const [
              LiquidGlassTabBarItem(
                icon: Icons.home_rounded,
                label: 'Home',
              ),
              LiquidGlassTabBarItem(
                icon: Icons.search_rounded,
                label: 'Search',
              ),
              LiquidGlassTabBarItem(
                icon: Icons.folder_rounded,
                label: 'Library',
              ),
              LiquidGlassTabBarItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stage 2: Quick Notes Navigation ──────────────────────────────────────
  Widget _buildStage2QuickNotes(double barWidth, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFFF9500).withValues(alpha: 0.40),
            ),
          ),
          child: Text(
            'STAGE 2: QUICK NOTES NAVIGATION (PHYSICS)',
            style: GoogleFonts.inter(
              fontSize: 8.0,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF9500),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _QuickNotesTabBarRecreation(
          key: const ValueKey('quick_notes_tab_bar_recreation'),
          width: barWidth,
          selectedIndex: _stage2SelectedIndex,
          onChanged: (idx) {
            if (idx < 4) {
              setState(() => _stage2SelectedIndex = idx);
            }
          },
          onPhysicsActiveChanged: (active) {
            if (_debugMainNavPhysicsActive != active) {
              setState(() => _debugMainNavPhysicsActive = active);
            }
          },
          onFabAnimationActiveChanged: (active) {
            if (_debugFabAnimationActive != active) {
              setState(() => _debugFabAnimationActive = active);
            }
          },
          isDark: isDark,
          travelStiffness: _travelStiffness,
          travelDamping: _travelDamping,
          liftStiffness: _liftStiffness,
          liftDampingX: _liftDampingX,
          liftDampingY: _liftDampingY,
          pillGrowHeight: _pillGrowHeight,
          sensitivity: _sensitivity,
          maxDeformation: _maxDeformation,
          responseTime: _responseTime,
          followTau: _followTau,
          signTau: _signTau,
          longPressMs: _longPressMs,
          dragThreshold: _dragThreshold,
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Container(
              key: const ValueKey('debug_main_nav_physics_status'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _debugMainNavPhysicsActive
                    ? const Color(0xFF34C759).withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'NAV PHYSICS: ${_debugMainNavPhysicsActive ? "YES" : "NO"}',
                style: GoogleFonts.robotoMono(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  color: _debugMainNavPhysicsActive
                      ? const Color(0xFF34C759)
                      : (isDark ? Colors.white60 : Colors.black45),
                ),
              ),
            ),
            Container(
              key: const ValueKey('debug_fab_animation_status'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _debugFabAnimationActive
                    ? const Color(0xFF007AFF).withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'FAB ANIMATION: ${_debugFabAnimationActive ? "YES" : "NO"}',
                style: GoogleFonts.robotoMono(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  color: _debugFabAnimationActive
                      ? const Color(0xFF007AFF)
                      : (isDark ? Colors.white60 : Colors.black45),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Parameters Inspector Panel ───────────────────────────────────────────
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
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final titleText = Text(
                'STAGE 2 PHYSICS INSPECTOR',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFF9500),
                  letterSpacing: 0.8,
                ),
              );

              final resetButton = TextButton(
                key: const ValueKey('reset_physics_defaults_button'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    _travelStiffness = 280.0;
                    _travelDamping = 31.4;
                    _liftStiffness = 250.0;
                    _liftDampingX = 19.0;
                    _liftDampingY = 22.1;
                    _pillGrowHeight = 12.0;
                    _sensitivity = 0.00007;
                    _maxDeformation = 0.12;
                    _responseTime = 0.18;
                    _followTau = 0.05;
                    _signTau = 0.25;
                    _longPressMs = 100;
                    _dragThreshold = 0.20;
                  });
                },
                child: Text(
                  'Restore Forensic Defaults',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF007AFF),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleText,
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: resetButton,
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleText),
                  const SizedBox(width: 8),
                  resetButton,
                ],
              );
            },
          ),
          const SizedBox(height: 6),

          // 1. Travel Springs
          _buildSlider(
            label: 'Travel Stiffness',
            value: _travelStiffness,
            min: 50.0,
            max: 600.0,
            unit: 'N/m',
            sliderKey: const ValueKey('slider_travel_stiffness'),
            onChanged: (v) => setState(() => _travelStiffness = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildSlider(
            label: 'Travel Damping',
            value: _travelDamping,
            min: 5.0,
            max: 60.0,
            unit: 'N·s/m',
            sliderKey: const ValueKey('slider_travel_damping'),
            onChanged: (v) => setState(() => _travelDamping = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          Divider(height: 20, thickness: 1, color: dividerColor),

          // 2. Lift Springs & Pill Grow Height
          _buildSlider(
            label: 'Lift Stiffness',
            value: _liftStiffness,
            min: 50.0,
            max: 500.0,
            unit: 'N/m',
            sliderKey: const ValueKey('slider_lift_stiffness'),
            onChanged: (v) => setState(() => _liftStiffness = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildSlider(
            label: 'Lift Damping X (Width)',
            value: _liftDampingX,
            min: 5.0,
            max: 40.0,
            unit: 'N·s/m',
            sliderKey: const ValueKey('slider_lift_damping_x'),
            onChanged: (v) => setState(() => _liftDampingX = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildSlider(
            label: 'Lift Damping Y (Height)',
            value: _liftDampingY,
            min: 5.0,
            max: 40.0,
            unit: 'N·s/m',
            sliderKey: const ValueKey('slider_lift_damping_y'),
            onChanged: (v) => setState(() => _liftDampingY = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildSlider(
            label: 'Pill Grow Height',
            value: _pillGrowHeight,
            min: 0.0,
            max: 24.0,
            unit: 'px',
            sliderKey: const ValueKey('slider_pill_grow_height'),
            onChanged: (v) => setState(() => _pillGrowHeight = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          Divider(height: 20, thickness: 1, color: dividerColor),

          // 3. Acceleration Squash/Stretch
          _buildSlider(
            label: 'Max Deformation',
            value: _maxDeformation,
            min: 0.0,
            max: 0.30,
            unit: 'ratio',
            decimals: 2,
            sliderKey: const ValueKey('slider_max_deformation'),
            onChanged: (v) => setState(() => _maxDeformation = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildSlider(
            label: 'Response Time',
            value: _responseTime,
            min: 0.02,
            max: 0.40,
            unit: 's',
            decimals: 2,
            sliderKey: const ValueKey('slider_response_time'),
            onChanged: (v) => setState(() => _responseTime = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildSlider(
            label: 'Direction Sign Tau',
            value: _signTau,
            min: 0.05,
            max: 0.60,
            unit: 's',
            decimals: 2,
            sliderKey: const ValueKey('slider_sign_tau'),
            onChanged: (v) => setState(() => _signTau = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          Divider(height: 20, thickness: 1, color: dividerColor),

          // 4. Gesture Interaction Controls
          _buildSlider(
            label: 'Follow Tau (Drag Smoothing)',
            value: _followTau,
            min: 0.01,
            max: 0.15,
            unit: 's',
            decimals: 3,
            sliderKey: const ValueKey('slider_follow_tau'),
            onChanged: (v) => setState(() => _followTau = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildSlider(
            label: 'Drag Threshold',
            value: _dragThreshold,
            min: 0.05,
            max: 0.50,
            unit: 'cells',
            decimals: 2,
            sliderKey: const ValueKey('slider_drag_threshold'),
            onChanged: (v) => setState(() => _dragThreshold = v),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          Divider(height: 20, thickness: 1, color: dividerColor),

          // Environment Color Presets
          Text(
            'STAGE ENVIRONMENT PRESETS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip(
                  'Pure White',
                  const Color(0xFFFFFFFF),
                  1.0,
                  const Color(0xFFFFFFFF),
                  1.0,
                  inputBg,
                  panelBorder,
                  textPrimary),
              _buildPresetChip(
                  'High Contrast',
                  const Color(0xFFFFFFFF),
                  1.0,
                  const Color(0xFF007AFF),
                  0.50,
                  inputBg,
                  panelBorder,
                  textPrimary),
              _buildPresetChip(
                  'Vibrant Bloom',
                  const Color(0xFF1C1C1E),
                  1.0,
                  const Color(0xFFFF9500),
                  0.60,
                  inputBg,
                  panelBorder,
                  textPrimary),
              _buildPresetChip(
                  'Frosted Emerald',
                  const Color(0xFF0D0E12),
                  1.0,
                  const Color(0xFF34C759),
                  0.40,
                  inputBg,
                  panelBorder,
                  textPrimary),
              _buildPresetChip(
                  'Obsidian Glow',
                  const Color(0xFF000000),
                  1.0,
                  const Color(0xFFFF3B30),
                  0.45,
                  inputBg,
                  panelBorder,
                  textPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Key sliderKey,
    required ValueChanged<double> onChanged,
    required Color textPrimary,
    required Color textSecondary,
    int decimals = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${value.toStringAsFixed(decimals)} $unit',
                style: GoogleFonts.robotoMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF007AFF),
              inactiveTrackColor: textSecondary.withValues(alpha: 0.2),
              thumbColor: const Color(0xFF007AFF),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              key: sliderKey,
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    Color bg1,
    double op1,
    Color bg2,
    double op2,
    Color inputBg,
    Color panelBorder,
    Color textPrimary,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _background1Color = bg1;
          _background1Opacity = op1;
          _background2Color = bg2;
          _background2Opacity = op2;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: panelBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ),
    );
  }
}


// ============================================================================
// STAGE 2: QUICK NOTES RECREATED TABBAR IMPLEMENTATION (EXTRACTED)
// ============================================================================

typedef _QuickNotesTabBarRecreation = QuickNotesLiquidGlassTabBar;
