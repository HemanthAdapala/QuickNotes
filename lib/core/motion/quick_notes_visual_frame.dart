import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'morph_content_controller.dart';

/// Single authoritative visual frame model for the Quick Notes visual motion system.
///
/// Encapsulates the live instantaneous geometric, shape, and content state of a
/// visual transition at a specific animation frame tick:
/// - [liveRect]: Instantaneous bounding rectangle of the moving surface.
/// - [anchor]: Reference spatial anchor governing alignment and deformation.
/// - [borderRadius]: Instantaneous corner radius interpolated across states.
/// - [progress]: Normalized transition progress `[0.0 .. 1.0]`.
/// - [isMoving]: Whether the frame clock is actively advancing or fully settled.
/// - [contentSnapshot]: Evaluated content layer state (opacity, scale, blur, offsets).
/// - [extra]: Extensible capability payload for pluggable future capabilities (e.g. Adaptivity).
@immutable
class QuickNotesVisualFrame {
  const QuickNotesVisualFrame({
    required this.liveRect,
    required this.anchor,
    required this.borderRadius,
    required this.progress,
    required this.isMoving,
    this.contentSnapshot,
    this.extra = const <String, Object?>{},
  });

  /// Instantaneous geometry of the visual surface in local layout space.
  final Rect liveRect;

  /// Spatial anchor governing deformation and positioning.
  final Alignment anchor;

  /// Instantaneous corner radius of the visual surface.
  final BorderRadius borderRadius;

  /// Normalized animation progress from origin to target `[0.0 .. 1.0]`.
  final double progress;

  /// Whether the frame is actively in motion.
  final bool isMoving;

  /// Optional content crossfade, blur, and scale snapshot.
  final QuickNotesMorphContentSnapshot<Object>? contentSnapshot;

  /// Extensible key-value store for pluggable visual capabilities.
  final Map<String, Object?> extra;

  /// Current width of the visual surface.
  double get width => liveRect.width;

  /// Current height of the visual surface.
  double get height => liveRect.height;

  /// Top-left position of the visual surface.
  Offset get topLeft => liveRect.topLeft;

  /// Center position of the visual surface.
  Offset get center => liveRect.center;

  /// Creates a copy of this frame with the specified attributes replaced.
  QuickNotesVisualFrame copyWith({
    Rect? liveRect,
    Alignment? anchor,
    BorderRadius? borderRadius,
    double? progress,
    bool? isMoving,
    QuickNotesMorphContentSnapshot<Object>? contentSnapshot,
    Map<String, Object?>? extra,
  }) {
    return QuickNotesVisualFrame(
      liveRect: liveRect ?? this.liveRect,
      anchor: anchor ?? this.anchor,
      borderRadius: borderRadius ?? this.borderRadius,
      progress: progress ?? this.progress,
      isMoving: isMoving ?? this.isMoving,
      contentSnapshot: contentSnapshot ?? this.contentSnapshot,
      extra: extra ?? this.extra,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickNotesVisualFrame &&
        other.liveRect == liveRect &&
        other.anchor == anchor &&
        other.borderRadius == borderRadius &&
        other.progress == progress &&
        other.isMoving == isMoving &&
        other.contentSnapshot == contentSnapshot;
  }

  @override
  int get hashCode => Object.hash(
        liveRect,
        anchor,
        borderRadius,
        progress,
        isMoving,
        contentSnapshot,
      );

  @override
  String toString() {
    return 'QuickNotesVisualFrame('
        'rect: ${liveRect.width.toStringAsFixed(1)}x${liveRect.height.toStringAsFixed(1)}@${liveRect.topLeft}, '
        'radius: $borderRadius, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'moving: $isMoving)';
  }
}
