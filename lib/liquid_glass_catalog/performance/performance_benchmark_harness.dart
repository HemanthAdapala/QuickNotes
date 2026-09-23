import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../catalog_background.dart';

/// Evidence-based performance classifications under tested configurations.
enum PerformanceClassification {
  lowObservedCost('LOW OBSERVED COST', Color(0xFF34C759)),
  moderateObservedCost('MODERATE OBSERVED COST', Color(0xFFFF9500)),
  highObservedCost('HIGH OBSERVED COST', Color(0xFFFF3B30)),
  deviceBackendDependent('DEVICE / BACKEND DEPENDENT', Color(0xFF007AFF)),
  notMeasurableInCurrentTest('NOT MEASURABLE IN CURRENT TEST', Color(0xFF8E8E93)),
  inconclusive('INCONCLUSIVE', Color(0xFFAF52DE));

  final String label;
  final Color color;

  const PerformanceClassification(this.label, this.color);
}

/// Lightweight, minimal telemetry benchmarking scaffold for Phase 1D experiments.
///
/// Features:
/// 1. Real-time frame timing collection via [SchedulerBinding.addTimingsCallback].
/// 2. Optional continuous animation ticker for comparing static vs active rebuild costs.
/// 3. Telemetry UI hide toggle to allow measuring pure glass workloads without telemetry repainting.
/// 4. Standardized reproducibility metadata block (device, OS, renderer, package version, warm-up).
class PerformanceBenchmarkHarness extends StatefulWidget {
  final String title;
  final String subtitle;
  final String question;
  final String reproducibilityQuality;
  final PerformanceClassification classification;
  final String classificationSummary;
  final List<String> notes;
  final Widget configControls;
  final Widget Function(BuildContext context, bool isAnimating, double animationValue) workloadBuilder;
  final bool supportsContinuousAnimation;

  const PerformanceBenchmarkHarness({
    super.key,
    required this.title,
    required this.subtitle,
    required this.question,
    this.reproducibilityQuality = 'GlassQuality.standard',
    required this.classification,
    required this.classificationSummary,
    required this.notes,
    required this.configControls,
    required this.workloadBuilder,
    this.supportsContinuousAnimation = true,
  });

  @override
  State<PerformanceBenchmarkHarness> createState() => _PerformanceBenchmarkHarnessState();
}

class _PerformanceBenchmarkHarnessState extends State<PerformanceBenchmarkHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _isAnimating = false;
  bool _hideTelemetryOverlay = false;

  // Frame timings ring buffer (last 60 frames)
  final List<FrameTiming> _recentTimings = [];
  static const int _sampleWindow = 60;

  double _lastBuildMs = 0.0;
  double _lastRasterMs = 0.0;
  double _lastTotalMs = 0.0;

  double _avgBuildMs = 0.0;
  double _avgRasterMs = 0.0;
  double _avgTotalMs = 0.0;
  int _overBudgetCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _animationController.dispose();
    super.dispose();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!mounted) return;

    for (final timing in timings) {
      _recentTimings.add(timing);
      if (_recentTimings.length > _sampleWindow) {
        _recentTimings.removeAt(0);
      }
    }

    if (_recentTimings.isNotEmpty) {
      final latest = _recentTimings.last;
      _lastBuildMs = latest.buildDuration.inMicroseconds / 1000.0;
      _lastRasterMs = latest.rasterDuration.inMicroseconds / 1000.0;
      _lastTotalMs = latest.totalSpan.inMicroseconds / 1000.0;

      double totalBuild = 0.0;
      double totalRaster = 0.0;
      double totalSpan = 0.0;
      int overBudget = 0;

      for (final t in _recentTimings) {
        final r = t.rasterDuration.inMicroseconds / 1000.0;
        final b = t.buildDuration.inMicroseconds / 1000.0;
        final s = t.totalSpan.inMicroseconds / 1000.0;
        totalRaster += r;
        totalBuild += b;
        totalSpan += s;
        if (s > 16.6) {
          overBudget++;
        }
      }

      final count = _recentTimings.length;
      _avgBuildMs = totalBuild / count;
      _avgRasterMs = totalRaster / count;
      _avgTotalMs = totalSpan / count;
      _overBudgetCount = overBudget;

      // Update state without interrupting rendering if telemetry is visible
      if (!_hideTelemetryOverlay) {
        setState(() {});
      }
    }
  }

  void _toggleAnimation() {
    setState(() {
      _isAnimating = !_isAnimating;
      if (_isAnimating) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CatalogBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header & Performance Question
                      _buildHeaderBlock(),
                      const SizedBox(height: 12),

                      // Reproducibility Metadata Block
                      _buildReproducibilityBlock(),
                      const SizedBox(height: 12),

                      // Configuration Controls
                      _buildConfigSection(),
                      const SizedBox(height: 14),

                      // Live Benchmark Workload
                      _buildWorkloadContainer(),
                      const SizedBox(height: 14),

                      // Telemetry & Results
                      _buildTelemetryAndResults(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Return to Catalog Index',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Toggle Telemetry Overlay to allow measuring pure workload
          TextButton.icon(
            onPressed: () {
              setState(() {
                _hideTelemetryOverlay = !_hideTelemetryOverlay;
              });
            },
            icon: Icon(
              _hideTelemetryOverlay ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              color: Colors.white70,
              size: 16,
            ),
            label: Text(
              _hideTelemetryOverlay ? 'Show Telemetry' : 'Hide Telemetry',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERFORMANCE QUESTION',
            style: TextStyle(
              color: Color(0x88FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReproducibilityBlock() {
    final platformName = defaultTargetPlatform.name;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x18000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x15FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPRODUCIBILITY METADATA',
            style: TextStyle(
              color: Color(0x88FFFFFF),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildMetaItem('Target', platformName),
              _buildMetaItem('Package', 'v1.7.2'),
              _buildMetaItem('Quality', widget.reproducibilityQuality),
              _buildMetaItem('Warm-up', 'Pre-warmed'),
              _buildMetaItem('Window', '60 frames'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String key, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
        children: [
          TextSpan(text: '$key: ', style: const TextStyle(color: Color(0x88FFFFFF))),
          TextSpan(text: value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildConfigSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CONTROLLED CONFIGURATION',
              style: TextStyle(
                color: Color(0x88FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            if (widget.supportsContinuousAnimation)
              InkWell(
                onTap: _toggleAnimation,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isAnimating ? const Color(0x4434C759) : const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isAnimating ? const Color(0xFF34C759) : const Color(0x33FFFFFF),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAnimating ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: _isAnimating ? const Color(0xFF34C759) : Colors.white70,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isAnimating ? 'Animating' : 'Static Idle',
                        style: TextStyle(
                          color: _isAnimating ? const Color(0xFF34C759) : Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        widget.configControls,
      ],
    );
  }

  Widget _buildWorkloadContainer() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x10000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return widget.workloadBuilder(
            context,
            _isAnimating,
            _animationController.value,
          );
        },
      ),
    );
  }

  Widget _buildTelemetryAndResults() {
    if (_hideTelemetryOverlay) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x1A000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'Telemetry overlay hidden. Pure glass workload active.',
            style: TextStyle(color: Color(0x77FFFFFF), fontSize: 11),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Telemetry Cards
        _buildTelemetryCards(),
        const SizedBox(height: 12),

        // Evidence-Based Classification
        _buildClassificationCard(),
        const SizedBox(height: 12),

        // Empirical Notes
        _buildNotesCard(),
      ],
    );
  }

  Widget _buildTelemetryCards() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE TELEMETRY (ROLLING 60 FRAMES)',
                style: TextStyle(
                  color: Color(0x88FFFFFF),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Over 16.6ms: $_overBudgetCount',
                style: TextStyle(
                  color: _overBudgetCount > 0 ? const Color(0xFFFF9500) : const Color(0x88FFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'UI Build / Paint',
                  '${_lastBuildMs.toStringAsFixed(2)} ms',
                  'avg: ${_avgBuildMs.toStringAsFixed(2)} ms',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'GPU Raster',
                  '${_lastRasterMs.toStringAsFixed(2)} ms',
                  'avg: ${_avgRasterMs.toStringAsFixed(2)} ms',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'Total Frame',
                  '${_lastTotalMs.toStringAsFixed(2)} ms',
                  'avg: ${_avgTotalMs.toStringAsFixed(2)} ms',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x26000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x18FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 9.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            sub,
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 8.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.classification.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.classification.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: widget.classification.color, width: 1),
                ),
                child: Text(
                  widget.classification.label,
                  style: TextStyle(
                    color: widget.classification.color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.classificationSummary,
            style: const TextStyle(
              color: Color(0xDDFFFFFF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x18000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x15FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EMPIRICAL OBSERVATIONS & NOTES',
            style: TextStyle(
              color: Color(0x88FFFFFF),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          for (final note in widget.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0x88FFFFFF), fontSize: 11)),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
