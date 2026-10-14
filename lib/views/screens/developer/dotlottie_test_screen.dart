import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dotlottie_flutter/dotlottie_flutter.dart';

import '../../../providers/settings_provider.dart';
import '../../widgets/app_header_bar.dart';
import '../../widgets/quick_notes_liquid_glass_back_button.dart';
import '../../widgets/primary_screen_surface.dart';

/// DotLottieTestScreen — Dedicated, isolated test screen for comparing
/// Figma dotLottie exports:
/// - Export A: Native Figma export (`assets/animations/quick_notes_intro_text.lottie`)
/// - Export B: LottieFiles Figma plugin export (`assets/animations/Quick_Notes___animated.lottie`)
///
/// In release builds, this widget returns [SizedBox.shrink] for strict isolation.
class DotLottieTestScreen extends StatefulWidget {
  const DotLottieTestScreen({super.key});

  static const String assetPathA =
      'assets/animations/quick_notes_intro_text.lottie';
  static const String assetPathB =
      'assets/animations/Quick_Notes___animated.lottie';

  /// Retained for backwards-compatibility with existing tests.
  static const String assetPath = assetPathA;

  @override
  State<DotLottieTestScreen> createState() => _DotLottieTestScreenState();
}

class _DotLottieTestScreenState extends State<DotLottieTestScreen> {
  DotLottieViewController? _controller;
  bool _isExportB = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isPlaying = true;
  bool _isLooping = true;
  bool _isCenteredView = true;
  int _rebuildKey = 0;
  Timer? _fallbackTimer;

  String get _currentAssetPath => _isExportB
      ? DotLottieTestScreen.assetPathB
      : DotLottieTestScreen.assetPathA;

  /// [DotLottieView] automatically prepends 'assets/' to [source] when [sourceType] is 'asset'.
  /// Therefore, the source passed to DotLottieView must be relative to 'assets/'.
  String get _relativeSource {
    const prefix = 'assets/';
    final path = _currentAssetPath;
    if (path.startsWith(prefix)) {
      return path.substring(prefix.length);
    }
    return path;
  }

  @override
  void initState() {
    super.initState();
    _armLoadingFallback();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _armLoadingFallback() {
    _fallbackTimer?.cancel();
    // If native platform view does not trigger onLoad event within 2.5 seconds,
    // automatically dismiss loading overlay to reveal the active rendered surface.
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _selectExport(bool useExportB) {
    if (_isExportB == useExportB) return;
    setState(() {
      _isExportB = useExportB;
      _isLoading = true;
      _hasError = false;
      _rebuildKey++;
    });
    _armLoadingFallback();
  }

  void _onViewCreated(DotLottieViewController controller) {
    _controller = controller;
    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  void _onLoad() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _isPlaying = true;
      });
    }
  }

  void _onLoadError() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            'Failed to load dotLottie animation from $_currentAssetPath.';
      });
    }
  }

  Future<void> _play() async {
    if (_controller != null) {
      await _controller!.play();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    }
  }

  Future<void> _pause() async {
    if (_controller != null) {
      await _controller!.pause();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }

  Future<void> _restart() async {
    if (_controller != null) {
      await _controller!.stop();
      await _controller!.play();
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    } else {
      // Re-trigger view initialization
      setState(() {
        _isLoading = true;
        _hasError = false;
        _rebuildKey++;
      });
      _armLoadingFallback();
    }
  }

  void _toggleLoop() {
    setState(() {
      _isLooping = !_isLooping;
      _rebuildKey++;
    });
    _armLoadingFallback();
  }

  Widget _buildPlayerWidget() {
    return DotLottieView(
      key: ValueKey('dotlottie_stage_${_isExportB ? "B" : "A"}_$_rebuildKey'),
      sourceType: 'asset',
      source: _relativeSource,
      autoplay: true,
      loop: _isLooping,
      fit: BoxFit.contain,
      onViewCreated: _onViewCreated,
      onLoad: _onLoad,
      onLoadError: _onLoadError,
      onPlay: () {
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
          });
        }
      },
      onPause: () {
        if (mounted) setState(() => _isPlaying = false);
      },
      onRender: (_) {
        if (mounted && _isLoading) {
          setState(() => _isLoading = false);
        }
      },
      onComplete: () {
        if (!_isLooping && mounted) {
          setState(() => _isPlaying = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final isDark = context.select<SettingsProvider, bool>((p) => p.isDarkMode);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF333333);
    final secondaryTextColor =
        isDark ? const Color(0xFF9E9E9E) : const Color(0xFF8E8E93);
    final backgroundColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF2F2F7);
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorderColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: PrimaryScreenSurface(
              color: backgroundColor,
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppHeaderBar(
                  title: 'dotLottie Test',
                  leftChild: QuickNotesLiquidGlassBackButton(
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  useSelfContainedLeftControl: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Subheading ──────────────────────────────────────
                        Text(
                          'FIGMA DOTLOTTIE FIDELITY TEST',
                          style: GoogleFonts.outfit(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          'Controlled comparison between Export A (Native Figma) and Export B (LottieFiles Plugin).',
                          style: GoogleFonts.outfit(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // ── Export Selector (A vs B) ────────────────────────
                        Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF252528)
                                : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectExport(false),
                                  borderRadius: BorderRadius.circular(9.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !_isExportB
                                          ? cardBgColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9.0),
                                      boxShadow: !_isExportB
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                                blurRadius: 4.0,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Export A (Native Figma)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.0,
                                          fontWeight: !_isExportB
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: !_isExportB
                                              ? const Color(0xFF6366F1)
                                              : secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectExport(true),
                                  borderRadius: BorderRadius.circular(9.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isExportB
                                          ? cardBgColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9.0),
                                      boxShadow: _isExportB
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.08,
                                                ),
                                                blurRadius: 4.0,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Export B (LottieFiles)',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.0,
                                          fontWeight: _isExportB
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _isExportB
                                              ? const Color(0xFF6366F1)
                                              : secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12.0),

                        // ── View Mode Selector (For Export A canvas handling) ──
                        if (!_isExportB)
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (!_isCenteredView) {
                                      setState(() => _isCenteredView = true);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    decoration: BoxDecoration(
                                      color: _isCenteredView
                                          ? const Color(0xFF6366F1)
                                              .withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10.0),
                                      border: Border.all(
                                        color: _isCenteredView
                                            ? const Color(0xFF6366F1)
                                            : cardBorderColor,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Centered Focus',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w600,
                                          color: _isCenteredView
                                              ? const Color(0xFF6366F1)
                                              : secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (_isCenteredView) {
                                      setState(() => _isCenteredView = false);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    decoration: BoxDecoration(
                                      color: !_isCenteredView
                                          ? const Color(0xFF6366F1)
                                              .withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10.0),
                                      border: Border.all(
                                        color: !_isCenteredView
                                            ? const Color(0xFF6366F1)
                                            : cardBorderColor,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Full 800×800 Canvas',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w600,
                                          color: !_isCenteredView
                                              ? const Color(0xFF6366F1)
                                              : secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.3),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16.0,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    'Native 202×136 Canvas — True Vector Bézier Curves (No Rasterization)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12.0),

                        // ── Animation Stage Card ────────────────────────────
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 280,
                            maxHeight: 340,
                          ),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.3 : 0.05,
                                ),
                                blurRadius: 16.0,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // The dotLottie player view
                              if (!_hasError)
                                !_isExportB
                                    ? (_isCenteredView
                                        ? LayoutBuilder(
                                            builder: (context, constraints) {
                                              final cardW =
                                                  constraints.maxWidth;
                                              final cardH =
                                                  constraints.maxHeight.isFinite
                                                      ? constraints.maxHeight
                                                      : 300.0;
                                              // Scale canvas so text (~106px in 800px) is ~190px
                                              final canvasSize = cardW * 1.8;
                                              final offsetX = (cardW / 2) -
                                                  (canvasSize *
                                                      (402.25 / 800.0));
                                              final offsetY = (cardH / 2) -
                                                  (canvasSize *
                                                      (769.0 / 800.0));

                                              return OverflowBox(
                                                minWidth: canvasSize,
                                                maxWidth: canvasSize,
                                                minHeight: canvasSize,
                                                maxHeight: canvasSize,
                                                alignment: Alignment.topLeft,
                                                child: Transform.translate(
                                                  offset:
                                                      Offset(offsetX, offsetY),
                                                  child: SizedBox(
                                                    width: canvasSize,
                                                    height: canvasSize,
                                                    child: _buildPlayerWidget(),
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : Center(
                                            child: AspectRatio(
                                              aspectRatio: 1.0,
                                              child: _buildPlayerWidget(),
                                            ),
                                          ))
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24.0,
                                            vertical: 20.0,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 202.0 / 136.0,
                                            child: _buildPlayerWidget(),
                                          ),
                                        ),
                                      ),

                              // Loading indicator
                              if (_isLoading && !_hasError)
                                Container(
                                  color: cardBgColor.withValues(alpha: 0.8),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        Text(
                                          'Loading dotLottie ${_isExportB ? "Export B" : "Export A"}...',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w500,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Error state
                              if (_hasError)
                                Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 40.0,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(height: 12.0),
                                      Text(
                                        'Playback Error',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6.0),
                                      Text(
                                        _errorMessage,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.0,
                                          color: secondaryTextColor,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 16.0),
                                      ElevatedButton.icon(
                                        onPressed: _restart,
                                        icon:
                                            const Icon(Icons.refresh, size: 16),
                                        label: const Text('Retry'),
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        // ── Playback Controls ───────────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildControlButton(
                                icon: _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                label: _isPlaying ? 'Pause' : 'Play',
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: _isPlaying ? _pause : _play,
                              ),
                              _buildControlButton(
                                icon: Icons.replay_rounded,
                                label: 'Restart',
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: _restart,
                              ),
                              _buildControlButton(
                                icon: _isLooping
                                    ? Icons.repeat_rounded
                                    : Icons.repeat_one_rounded,
                                label: _isLooping ? 'Loop: ON' : 'Loop: OFF',
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                isActive: _isLooping,
                                onTap: _toggleLoop,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20.0),

                        // ── Animation Metadata Card ─────────────────────────
                        Text(
                          'ANIMATION SPECIFICATIONS',
                          style: GoogleFonts.outfit(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildMetaRow(
                                'Active Target',
                                _isExportB
                                    ? 'Export B (LottieFiles Plugin)'
                                    : 'Export A (Native Figma Exporter)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Asset Path',
                                _currentAssetPath,
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Format & Spec',
                                _isExportB
                                    ? 'dotLottie v2.0 (manifest v2, generator: LottieFiles)'
                                    : 'dotLottie v1.0 (manifest v1.0, generator: Figma)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Layer Type',
                                _isExportB
                                    ? '10 Vector Bézier Shape Layers (ty: 4)'
                                    : '10 Raster Image Layers (ty: 2)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Embedded Bitmaps',
                                _isExportB
                                    ? '0 PNG images (Pure Vector Math)'
                                    : '10 PNG bitmaps (25–34px slices in images/)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Canvas Dimensions',
                                _isExportB
                                    ? '202 × 136 (tight bounding box around text)'
                                    : '800 × 800 (1:1 artboard with text offset)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Frames & Timing',
                                '120 frames @ 60 fps (2.0s duration)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Motion & Easing',
                                'Overshoot Spring (Drop frame 13–34, settle frame 48–70)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const Divider(height: 16.0),
                              _buildMetaRow(
                                'Player Package',
                                'dotlottie_flutter ^0.1.7 (dotlottie-rs)',
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primaryTextColor,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26.0,
              color: isActive ? const Color(0xFF6366F1) : primaryTextColor,
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: isActive ? const Color(0xFF6366F1) : primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    String label,
    String value,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: secondaryTextColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
          ),
        ),
      ],
    );
  }
}
