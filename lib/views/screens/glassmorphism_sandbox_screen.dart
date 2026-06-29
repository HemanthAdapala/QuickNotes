import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../widgets/glass_container.dart';
import '../widgets/liquid_glass_dock.dart';

class GlassmorphismSandboxScreen extends StatefulWidget {
  const GlassmorphismSandboxScreen({super.key});

  @override
  State<GlassmorphismSandboxScreen> createState() => _GlassmorphismSandboxScreenState();
}

class _GlassmorphismSandboxScreenState extends State<GlassmorphismSandboxScreen> with TickerProviderStateMixin {
  // Pill positions
  Offset _pillPosition = const Offset(100, 250);
  Offset _dockPosition = const Offset(60, 360);
  bool _initialized = false;

  // Active Tab
  bool _showVisualsTab = true;

  // Background and Shadow Style selection
  String _bgType = 'Image';
  String _selectedShadowPreset = 'S0';

  // 1. Visual Style State Values
  double _blurSigma = 18.0;
  double _frostOpacity = 0.34;
  double _depthOpacity = 0.18;
  Color? _tintColor;
  String _tintName = 'None';
  double _outlineWidth = 0.8;
  double _outlineOpacity = 0.36;
  double _bevelIntensity = 0.0; // Defaults to flat Apple Liquid Glass!

  // Liquid Glass Renderer Settings
  bool _useShaderGlass = true;
  double _thickness = 20.0;
  double _refractiveIndex = 1.5;
  double _saturation = 1.2;
  double _lightIntensity = 1.0;
  double _blendStrength = 35.0;

  // 2. Motion Physics State Values
  bool _isMorphed = true; // start morphed (wide pill shape)
  int _morphDurationMs = 420;
  String _selectedMorphCurveName = 'Apple Emphasized';

  String _selectedTapStyle = 'Apple Pressable';
  double _tapCompressionScale = 0.85;
  int _settleDurationMs = 400;
  String _selectedSettleCurveName = 'Spring Settle';
  String _selectedHapticType = 'Light';

  // Animation Controllers
  late AnimationController _pressController;
  late AnimationController _releaseController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;

  // Settings Panel state
  bool _isPanelCollapsed = false;

  // List of tint colors for picker
  final List<Map<String, dynamic>> _tints = [
    {'name': 'None', 'color': null},
    {'name': 'White', 'color': Colors.white},
    {'name': 'Amber', 'color': const Color(0xFFFFA322)},
    {'name': 'Purple', 'color': Colors.purple},
    {'name': 'Blue', 'color': Colors.blue},
    {'name': 'Red', 'color': Colors.red},
    {'name': 'Green', 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    // Press down controller (linear ease-out over 80ms)
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    // Release spring settle controller
    _releaseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _settleDurationMs),
    );
    // Radial particle burst controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Shimmer sweep sweep controller
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _releaseController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Curve _getMorphCurve() {
    switch (_selectedMorphCurveName) {
      case 'Spring (Elastic)':
        return Curves.elasticOut;
      case 'Bouncy':
        return Curves.bounceOut;
      case 'Ease In Out':
        return Curves.easeInOut;
      case 'Linear':
        return Curves.linear;
      case 'Apple Emphasized':
      default:
        return const Cubic(0.16, 1.0, 0.3, 1.0);
    }
  }

  Curve _getSettleCurve() {
    switch (_selectedSettleCurveName) {
      case 'Slight Bounce':
        return Curves.easeOutBack;
      case 'Standard Ease':
        return Curves.easeOut;
      case 'Spring Settle':
      default:
        return Curves.elasticOut;
    }
  }

  void _triggerHaptic() {
    switch (_selectedHapticType) {
      case 'Light':
        HapticFeedback.lightImpact();
        break;
      case 'Medium':
        HapticFeedback.mediumImpact();
        break;
      case 'Heavy':
        HapticFeedback.vibrate();
        break;
      case 'Selection':
        HapticFeedback.selectionClick();
        break;
      case 'None':
      default:
        break;
    }
  }

  Widget _buildBackground() {
    switch (_bgType) {
      case 'White':
        return Container(color: Colors.white);
      case 'Black':
        return Container(color: const Color(0xFF0F0F0F));
      case 'Cream':
        return Container(color: const Color(0xFFF5F0E8));
      case 'Grey':
        return Container(color: Colors.grey.shade800);
      case 'Image':
      default:
        return Image.asset(
          'assets/icons/glass_background.jpg',
          fit: BoxFit.cover,
        );
    }
  }

  List<BoxShadow>? _getShadows() {
    switch (_selectedShadowPreset) {
      case 'S0':
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.42),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(-8, -10),
          ),
        ];
      case 'S1':
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ];
      case 'S2':
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 6),
          ),
        ];
      case 'None':
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Position the pill in the center on first launch
    if (!_initialized) {
      _pillPosition = Offset((size.width - 250) / 2, (size.height - 65) / 2 - 120);
      _dockPosition = Offset((size.width - 264) / 2, (size.height - 50) / 2 + 60);
      _initialized = true;
    }

    // Dynamic scale and morph sizes
    final double targetWidth = _isMorphed ? 250.0 : 65.0;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background
          Positioned.fill(
            child: _buildBackground(),
          ),

          // 2. Background Texts Layer (Behind the pill)
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antigravity',
                      style: GoogleFonts.outfit(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'MOTION & GLASS PLAYGROUND',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFA322),
                        letterSpacing: 3.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hold & tap the pill to test animations. Slide controls at the bottom to compare Apple curves, spring settles, particle bursts, and visual outlines.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Apple Liquid Glass Playground',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFA322),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Drag the dock and pill around to test refraction on different backgrounds.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: Colors.black.withValues(alpha: 0.6),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TAP PHYSICS PLAYGROUND',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Draggable overlays with real LiquidGlass Layer & Blending
          LiquidGlassLayer(
            fake: !_useShaderGlass,
            settings: LiquidGlassSettings(
              thickness: _thickness,
              blur: _blurSigma,
              glassColor: (_tintColor ?? Colors.white).withValues(alpha: _frostOpacity),
              refractiveIndex: _refractiveIndex,
              lightIntensity: _lightIntensity,
              saturation: _saturation,
            ),
            child: LiquidGlassBlendGroup(
              blend: _blendStrength,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 3a. Draggable & Clickable Glass Pill
                  Positioned(
                    left: _pillPosition.dx,
                    top: _pillPosition.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _pillPosition = Offset(
                            (_pillPosition.dx + details.delta.dx).clamp(0.0, size.width - targetWidth),
                            (_pillPosition.dy + details.delta.dy).clamp(0.0, size.height - 180),
                          );
                        });
                      },
                      onTapDown: (_) {
                        _triggerHaptic();
                        _releaseController.stop();
                        _pressController.forward(from: 0.0);
                        if (_selectedTapStyle == 'Shimmer Sweep') {
                          _shimmerController.forward(from: 0.0);
                        }
                      },
                      onTapCancel: () {
                        _pressController.stop();
                        _releaseController.duration = Duration(milliseconds: _settleDurationMs);
                        _releaseController.forward(from: 0.0);
                      },
                      onTapUp: (_) {
                        _pressController.stop();
                        _releaseController.duration = Duration(milliseconds: _settleDurationMs);
                        _releaseController.forward(from: 0.0);
                        if (_selectedTapStyle == 'Particle Burst') {
                          _particleController.forward(from: 0.0);
                        }
                      },
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pressController, _releaseController, _particleController, _shimmerController]),
                        builder: (context, child) {
                          // Calculate compression scale
                          double scale = 1.0;
                          if (_pressController.isAnimating || _pressController.value > 0.0) {
                            scale = 1.0 - (_pressController.value * (1.0 - _tapCompressionScale));
                          } else if (_releaseController.isAnimating) {
                            final releaseVal = CurvedAnimation(parent: _releaseController, curve: _getSettleCurve()).value;
                            scale = _tapCompressionScale + (releaseVal * (1.0 - _tapCompressionScale));
                          }

                          return Transform.scale(
                            scale: scale,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                // Glass Pill morphing width
                                AnimatedContainer(
                                  duration: Duration(milliseconds: _morphDurationMs),
                                  curve: _getMorphCurve(),
                                  width: targetWidth,
                                  height: 65,
                                  child: LiquidGlass.grouped(
                                    shape: LiquidRoundedSuperellipse(borderRadius: 32.5),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32.5),
                                      child: Stack(
                                        children: [
                                          // Shimmer Sweep overlay
                                          if (_selectedTapStyle == 'Shimmer Sweep')
                                            Positioned.fill(
                                              child: IgnorePointer(
                                                child: CustomPaint(
                                                  painter: _ShimmerSweepPainter(progress: _shimmerController.value),
                                                ),
                                              ),
                                            ),
                                          // Content Crossfade
                                          Center(
                                            child: AnimatedCrossFade(
                                              firstChild: Container(
                                                width: 65,
                                                height: 65,
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.blur_on_rounded,
                                                  color: _tintColor != null ? const Color(0xFF333333) : const Color(0xFFFFA322),
                                                  size: 24,
                                                ),
                                              ),
                                              secondChild: SizedBox(
                                                width: 250,
                                                height: 65,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.blur_on_rounded,
                                                      color: _tintColor != null ? const Color(0xFF333333) : const Color(0xFFFFA322),
                                                      size: 24,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Glass Pill',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF333333),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              crossFadeState: _isMorphed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                              duration: Duration(milliseconds: (_morphDurationMs * 0.4).toInt()),
                                            ),
                                          ),
                                          // Material Ripple overlay
                                          if (_selectedTapStyle == 'Material Ripple')
                                            Positioned.fill(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(32.5),
                                                  onTap: () {},
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Particle Burst overlay (drawn outside so they fly off bounds)
                                if (_selectedTapStyle == 'Particle Burst')
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _DotBurstPainter(
                                          progress: _particleController.value,
                                          directions: const [
                                            Offset(0.951, 0.309),   // 18 degrees
                                            Offset(0.000, 1.000),   // 90 degrees
                                            Offset(-0.951, 0.309),  // 162 degrees
                                            Offset(-0.588, -0.809), // 234 degrees
                                            Offset(0.588, -0.809),  // 306 degrees
                                          ],
                                          scale: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 3b. Draggable Liquid Glass Dock
                  Positioned(
                    left: _dockPosition.dx,
                    top: _dockPosition.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _dockPosition = Offset(
                            (_dockPosition.dx + details.delta.dx).clamp(0.0, size.width - 264),
                            (_dockPosition.dy + details.delta.dy).clamp(0.0, size.height - 180),
                          );
                        });
                      },
                      child: LiquidGlass.grouped(
                        shape: LiquidRoundedSuperellipse(borderRadius: 25.0),
                        child: const SizedBox(
                          width: 264,
                          height: 50,
                          child: LiquidGlassDock(useRawLayout: true),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Back navigation button (Floating in top-left)
          Positioned(
            top: 50,
            left: 20,
            child: SafeArea(
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // 5. Dual Settings Panel (Bottom Docked)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Collapse / Expand Drag handle
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPanelCollapsed = !_isPanelCollapsed;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isPanelCollapsed ? 'Tap to Show Controls' : 'Design & Motion Playground',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!_isPanelCollapsed) ...[
                    // Tab Headers Selection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: _showVisualsTab ? const Color(0xFFFFA322) : Colors.black12,
                                foregroundColor: _showVisualsTab ? Colors.white : Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => setState(() => _showVisualsTab = true),
                              child: Text('Visual Style', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: !_showVisualsTab ? const Color(0xFFFFA322) : Colors.black12,
                                foregroundColor: !_showVisualsTab ? Colors.white : Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => setState(() => _showVisualsTab = false),
                              child: Text('Motion Physics', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Active Tab Contents
                    Padding(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 28),
                      child: _showVisualsTab ? _buildVisualsTab() : _buildMotionTab(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blur Slider
        _buildSliderRow(
          label: 'Blur Sigma',
          value: _blurSigma,
          min: 0.0,
          max: 50.0,
          displayValue: _blurSigma.toStringAsFixed(1),
          onChanged: (val) => setState(() => _blurSigma = val),
        ),
        const SizedBox(height: 10),

        // Frost Slider
        _buildSliderRow(
          label: 'Frost Opacity',
          value: _frostOpacity,
          min: 0.0,
          max: 1.0,
          displayValue: '${(_frostOpacity * 100).toInt()}%',
          onChanged: (val) => setState(() => _frostOpacity = val),
        ),
        const SizedBox(height: 10),

        // Outline Width Slider
        _buildSliderRow(
          label: 'Outline Width',
          value: _outlineWidth,
          min: 0.0,
          max: 3.0,
          displayValue: _outlineWidth.toStringAsFixed(1),
          onChanged: (val) => setState(() => _outlineWidth = val),
        ),
        const SizedBox(height: 10),

        // Outline Opacity Slider
        _buildSliderRow(
          label: 'Outline Opacity',
          value: _outlineOpacity,
          min: 0.0,
          max: 1.0,
          displayValue: '${(_outlineOpacity * 100).toInt()}%',
          onChanged: (val) => setState(() => _outlineOpacity = val),
        ),
        const SizedBox(height: 10),

        // Bevel/3D Intensity Slider
        _buildSliderRow(
          label: 'Bevel/3D Style',
          value: _bevelIntensity,
          min: 0.0,
          max: 1.0,
          displayValue: '${(_bevelIntensity * 100).toInt()}%',
          onChanged: (val) => setState(() => _bevelIntensity = val),
        ),
        const SizedBox(height: 14),

        // Tint Picker Row
        Row(
          children: [
            Text(
              'Tint Color: ',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
            ),
            Text(
              _tintName,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFA322)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _tints.length,
            itemBuilder: (context, index) {
              final tint = _tints[index];
              final isSelected = _tintName == tint['name'];
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _tintColor = tint['color'] as Color?;
                      _tintName = tint['name'] as String;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint['color'] as Color? ?? Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFFA322) : Colors.grey.shade400,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: tint['color'] == null
                        ? const Icon(Icons.block, size: 14, color: Colors.grey)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Background Style Choice Selector
        Text(
          'Background Style:',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['Image', 'White', 'Black', 'Cream', 'Grey'].map((type) {
              final isSelected = _bgType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(type, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFA322),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _bgType = type);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Shadow Preset Choice Selector
        Text(
          'Shadow Preset:',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['S0', 'S1', 'S2', 'None'].map((preset) {
              final isSelected = _selectedShadowPreset == preset;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(preset, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFA322),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedShadowPreset = preset);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // -------------------------------------------------------------
        // Liquid Glass Shader controls
        // -------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Use Real Glass Shader:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
            ),
            Switch(
              value: _useShaderGlass,
              activeColor: const Color(0xFFFFA322),
              onChanged: (val) => setState(() => _useShaderGlass = val),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_useShaderGlass) ...[
          // Thickness Slider
          _buildSliderRow(
            label: 'Glass Thickness',
            value: _thickness,
            min: 0.0,
            max: 60.0,
            displayValue: _thickness.toStringAsFixed(1),
            onChanged: (val) => setState(() => _thickness = val),
          ),
          const SizedBox(height: 10),

          // Refractive Index Slider
          _buildSliderRow(
            label: 'Refractive Index',
            value: _refractiveIndex,
            min: 1.0,
            max: 2.0,
            displayValue: _refractiveIndex.toStringAsFixed(2),
            onChanged: (val) => setState(() => _refractiveIndex = val),
          ),
          const SizedBox(height: 10),

          // Saturation Slider
          _buildSliderRow(
            label: 'Saturation',
            value: _saturation,
            min: 0.5,
            max: 2.0,
            displayValue: _saturation.toStringAsFixed(2),
            onChanged: (val) => setState(() => _saturation = val),
          ),
          const SizedBox(height: 10),

          // Light Intensity Slider
          _buildSliderRow(
            label: 'Light Intensity',
            value: _lightIntensity,
            min: 0.0,
            max: 3.0,
            displayValue: _lightIntensity.toStringAsFixed(2),
            onChanged: (val) => setState(() => _lightIntensity = val),
          ),
          const SizedBox(height: 10),

          // Blend Strength Slider
          _buildSliderRow(
            label: 'Blend Strength',
            value: _blendStrength,
            min: 0.0,
            max: 100.0,
            displayValue: _blendStrength.toStringAsFixed(1),
            onChanged: (val) => setState(() => _blendStrength = val),
          ),
        ],
      ],
    );
  }

  Widget _buildMotionTab() {
    final List<String> curves = ['Apple Emphasized', 'Spring (Elastic)', 'Bouncy', 'Ease In Out', 'Linear'];
    final List<String> tapStyles = ['Apple Pressable', 'Particle Burst', 'Shimmer Sweep', 'Material Ripple', 'Standard'];
    final List<String> haptics = ['None', 'Light', 'Medium', 'Heavy', 'Selection'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Morph Width Toggle Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pill Width: ${_isMorphed ? "Wide (250px)" : "Circle (65px)"}',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
            ),
            Switch(
              value: _isMorphed,
              activeColor: const Color(0xFFFFA322),
              onChanged: (val) => setState(() => _isMorphed = val),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Morph Duration Slider
        _buildSliderRow(
          label: 'Morph Duration',
          value: _morphDurationMs.toDouble(),
          min: 100.0,
          max: 2000.0,
          displayValue: '${_morphDurationMs}ms',
          onChanged: (val) => setState(() => _morphDurationMs = val.toInt()),
        ),
        const SizedBox(height: 10),

        // Morph Curve Select Box
        Text(
          'Morph Curve:',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: curves.length,
            itemBuilder: (context, index) {
              final curve = curves[index];
              final isSelected = _selectedMorphCurveName == curve;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(curve, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFA322),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMorphCurveName = curve);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Tap Style Picker
        Text(
          'Tap Animation Look:',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tapStyles.length,
            itemBuilder: (context, index) {
              final style = tapStyles[index];
              final isSelected = _selectedTapStyle == style;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(style, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFA322),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedTapStyle = style);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Tap Compression scale
        _buildSliderRow(
          label: 'Tap Compression Scale',
          value: _tapCompressionScale,
          min: 0.60,
          max: 1.0,
          displayValue: _tapCompressionScale.toStringAsFixed(2),
          onChanged: (val) => setState(() => _tapCompressionScale = val),
        ),
        const SizedBox(height: 10),

        // Tap Settle Duration
        _buildSliderRow(
          label: 'Settle Duration',
          value: _settleDurationMs.toDouble(),
          min: 100.0,
          max: 1500.0,
          displayValue: '${_settleDurationMs}ms',
          onChanged: (val) => setState(() => _settleDurationMs = val.toInt()),
        ),
        const SizedBox(height: 12),

        // Haptic Trigger Selector
        Text(
          'Haptic Click Touchdown:',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF333333)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: haptics.length,
            itemBuilder: (context, index) {
              final hap = haptics[index];
              final isSelected = _selectedHapticType == hap;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(hap, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFA322),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedHapticType = hap);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFFA322),
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: const Color(0xFFFFA322),
              overlayColor: const Color(0xFFFFA322).withValues(alpha: 0.12),
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              displayValue,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFA322),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Helper Custom Painters
// -------------------------------------------------------------

class _ShimmerSweepPainter extends CustomPainter {
  _ShimmerSweepPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);

    canvas.save();
    final translation = -size.width + (progress * size.width * 3);
    canvas.translate(translation, 0);
    
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.4, 0)
      ..lineTo(size.width * 0.8, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..close();
      
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerSweepPainter oldDelegate) => oldDelegate.progress != progress;
}

class _DotBurstPainter extends CustomPainter {
  _DotBurstPainter({
    required this.progress,
    required this.directions,
    required this.scale,
  });

  final double progress;
  final List<Offset> directions;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFFFA322).withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.fill;

    final currentRadius = 40.0 * scale * Curves.easeOut.transform(progress);
    final dotRadius = 2.5 * scale;

    for (final dir in directions) {
      final dotOffset = center + dir * currentRadius;
      canvas.drawCircle(dotOffset, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.scale != scale;
  }
}
