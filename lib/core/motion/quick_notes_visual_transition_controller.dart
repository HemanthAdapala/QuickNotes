import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'morph_content_controller.dart';
import 'morph_geometry_config.dart';
import 'morph_geometry_controller.dart';
import 'quick_notes_visual_capability.dart';
import 'quick_notes_visual_frame.dart';
import 'quick_notes_visual_preset.dart';

/// Single authoritative visual motion controller driving the Quick Notes
/// universal visual transition engine.
///
/// Responsibilities:
/// - Maintains exactly ONE authoritative [Ticker] clock.
/// - Drives the validated 4D spring geometry controller ([QuickNotesMorphGeometryController]).
/// - Drives the content crossfade controller ([QuickNotesMorphContentController]).
/// - Coordinates attached [QuickNotesVisualCapability] plugins.
/// - Produces the single authoritative [QuickNotesVisualFrame] consumed by renderers.
/// - Automatically self-stops the [Ticker] when settled.
/// - Cleanly cleans up resources upon [dispose].
class QuickNotesVisualTransitionController
    implements QuickNotesVisualTransitionControllerInterface {
  QuickNotesVisualTransitionController({
    required TickerProvider vsync,
    required Rect initialRect,
    Alignment initialAnchor = Alignment.topRight,
    QuickNotesVisualPreset initialPreset = QuickNotesVisualPreset.baseline,
    BorderRadius initialRadius = const BorderRadius.all(Radius.circular(22.0)),
    List<QuickNotesVisualCapability> capabilities = const [],
    this.onTransitionEnd,
  })  : _preset = initialPreset,
        _anchor = initialAnchor,
        _targetRadius = initialRadius,
        _originRadius = initialRadius {
    _geometryController = QuickNotesMorphGeometryController(
      initialRect: initialRect,
      initialAnchor: initialAnchor,
    );

    _contentController = QuickNotesMorphContentController<Object>(
      initialState: 'initial',
      initialRect: initialRect,
      stiffness: initialPreset.stiffness,
    );

    _currentFrame = QuickNotesVisualFrame(
      liveRect: initialRect,
      anchor: initialAnchor,
      borderRadius: initialRadius,
      progress: 0.0,
      isMoving: false,
    );

    _ticker = vsync.createTicker(_onTick);
    setCapabilities(capabilities);
  }

  late final Ticker _ticker;
  late final QuickNotesMorphGeometryController _geometryController;
  late final QuickNotesMorphContentController<Object> _contentController;

  QuickNotesVisualPreset _preset;
  Alignment _anchor;
  BorderRadius _targetRadius;
  BorderRadius _originRadius;
  Rect _originRect = Rect.zero;
  Rect _targetRect = Rect.zero;
  Object? _currentState;
  Duration? _lastElapsed;

  late QuickNotesVisualFrame _currentFrame;
  final List<QuickNotesVisualCapability> _capabilities = [];
  final List<VoidCallback> _listeners = [];

  /// Callback invoked when a transition has settled.
  final VoidCallback? onTransitionEnd;

  @override
  Object? get currentState => _currentState;

  @override
  QuickNotesVisualFrame get currentFrame => _currentFrame;

  @override
  QuickNotesVisualPreset get preset => _preset;

  @override
  Alignment get anchor => _anchor;

  /// Whether the controller clock is currently ticking.
  bool get isAnimating => _ticker.isActive || _geometryController.isAnimating;

  /// Sets the active preset.
  void setPreset(QuickNotesVisualPreset preset) {
    if (_preset == preset) return;
    _preset = preset;
    markNeedsUpdate();
  }

  /// Sets the spatial anchor.
  void setAnchor(Alignment anchor) {
    if (_anchor == anchor) return;
    _anchor = anchor;
    markNeedsUpdate();
  }

  /// Attaches or replaces active capabilities.
  void setCapabilities(List<QuickNotesVisualCapability> capabilities) {
    for (final cap in _capabilities) {
      cap.onDetach();
    }
    _capabilities.clear();
    _capabilities.addAll(capabilities);
    for (final cap in _capabilities) {
      cap.onAttach(this);
    }
    markNeedsUpdate();
  }

  /// Adds a listener for frame updates.
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Removes a frame update listener.
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Starts or retargets a transition to [targetRect] and [targetRadius].
  void startTransition({
    required Rect targetRect,
    required BorderRadius targetRadius,
    required Object targetState,
    Alignment? anchor,
  }) {
    final Object? oldState = _currentState;
    _currentState = targetState;
    if (anchor != null) _anchor = anchor;

    _originRect = _geometryController.currentRect;
    _targetRect = targetRect;
    _originRadius = _currentFrame.borderRadius;
    _targetRadius = targetRadius;

    for (final cap in _capabilities) {
      cap.onStateChange(oldState, targetState);
    }

    // Resolve geometry config from preset and attached capabilities
    QuickNotesMorphGeometryConfig geomConfig =
        _preset.toGeometryConfig(anchor: _anchor);

    for (final cap in _capabilities) {
      if (cap is MotionCapability) {
        geomConfig = geomConfig.copyWith(
          stiffness: cap.stiffness,
          damping: cap.damping,
        );
      } else if (cap is StretchCapability) {
        geomConfig = geomConfig.copyWith(
          stretch: cap.stretch,
          leadBounce: cap.leadBounce,
          followDelaySeconds: cap.followDelaySeconds,
        );
      }
    }

    _geometryController.transitionToRect(targetRect, config: geomConfig);
    _contentController.transitionToState(
      targetState: targetState,
      targetRect: targetRect,
      liveGlassRect: _geometryController.currentRect,
      config: _preset.toContentConfig(),
      stiffness: geomConfig.stiffness,
    );

    if (!_ticker.isActive) {
      _lastElapsed = null;
      _ticker.start();
    }
    markNeedsUpdate();
  }

  @override
  void transitionTo(Object? targetState) {
    // Convenience state toggle if configured
    _currentState = targetState;
  }

  @override
  void markNeedsUpdate() {
    _notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final double dt;
    if (_lastElapsed == null) {
      dt = 1.0 / 60.0;
    } else {
      dt = (elapsed - _lastElapsed!).inMicroseconds / 1e6;
    }
    _lastElapsed = elapsed;

    QuickNotesMorphGeometryConfig geomConfig =
        _preset.toGeometryConfig(anchor: _anchor);

    for (final cap in _capabilities) {
      if (cap is MotionCapability) {
        geomConfig = geomConfig.copyWith(
          stiffness: cap.stiffness,
          damping: cap.damping,
        );
      } else if (cap is StretchCapability) {
        geomConfig = geomConfig.copyWith(
          stretch: cap.stretch,
          leadBounce: cap.leadBounce,
          followDelaySeconds: cap.followDelaySeconds,
        );
      }
    }

    final bool geomMoving = _geometryController.step(dt, geomConfig);
    final bool contentMoving =
        _contentController.step(dt, _preset.toContentConfig());

    final Rect live = _geometryController.currentRect;
    final double progress = _computeProgress(live);
    final BorderRadius liveRadius = _computeLiveRadius(progress);

    final snapshot = _contentController.evaluateAt(
      t: _contentController.progress,
      currentGlassRect: live,
      config: _preset.toContentConfig(),
    );

    QuickNotesVisualFrame frame = QuickNotesVisualFrame(
      liveRect: live,
      anchor: _anchor,
      borderRadius: liveRadius,
      progress: progress,
      isMoving: geomMoving || contentMoving,
      contentSnapshot: snapshot,
    );

    // Capability processing pipeline
    for (final cap in _capabilities) {
      frame = cap.processFrame(frame, dt);
    }
    _currentFrame = frame;

    _notifyListeners();

    if (!geomMoving && !contentMoving) {
      _ticker.stop();
      _lastElapsed = null;
      onTransitionEnd?.call();
    }
  }

  double _computeProgress(Rect live) {
    final double totalDx = (_targetRect.width - _originRect.width).abs();
    final double totalDy = (_targetRect.height - _originRect.height).abs();
    final double totalDist = math.sqrt(totalDx * totalDx + totalDy * totalDy);

    if (totalDist < 0.5) {
      return _geometryController.isAnimating ? 0.5 : 1.0;
    }

    final double curDx = (live.width - _originRect.width).abs();
    final double curDy = (live.height - _originRect.height).abs();
    final double curDist = math.sqrt(curDx * curDx + curDy * curDy);
    return (curDist / totalDist).clamp(0.0, 1.0);
  }

  BorderRadius _computeLiveRadius(double progress) {
    for (final cap in _capabilities) {
      if (cap is ShapeCapability) {
        return cap.computeRadius(progress);
      }
    }
    return BorderRadius.lerp(_originRadius, _targetRadius, progress)!;
  }

  void _notifyListeners() {
    for (int i = 0; i < _listeners.length; i++) {
      _listeners[i]();
    }
  }

  /// Disposes ticker and attached capabilities.
  void dispose() {
    for (final cap in _capabilities) {
      cap.onDetach();
    }
    _capabilities.clear();
    _listeners.clear();
    _ticker.dispose();
  }
}
