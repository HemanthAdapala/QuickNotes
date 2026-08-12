import 'dart:async';
import 'package:flutter/material.dart';

/// Pure state and auto-hide timer controller for NoteEditorScreen quick-scrolling.
/// Listens to a ScrollController, determines boundary reachability, and manages
/// an auto-hide timer that reveals the control pill while scrolling and hides it
/// after [autoHideDelay] of inactivity.
class EditorAutoScrollController extends ChangeNotifier {
  final ScrollController scrollController;
  final Duration autoHideDelay;
  final double threshold;

  bool _isVisible = false;
  bool _canScrollToTop = false;
  bool _canScrollToBottom = false;
  Timer? _hideTimer;
  bool _disposed = false;

  EditorAutoScrollController({
    required this.scrollController,
    this.autoHideDelay = const Duration(milliseconds: 1500),
    this.threshold = 150.0,
  }) {
    scrollController.addListener(_onScroll);
    _updateBoundaries();
  }

  bool get isVisible => _isVisible;
  bool get canScrollToTop => _canScrollToTop;
  bool get canScrollToBottom => _canScrollToBottom;

  void _onScroll() {
    if (_disposed || !scrollController.hasClients) return;

    _updateBoundaries();

    // Reveal quick-scroll pill while scrolling
    if (!_isVisible) {
      _isVisible = true;
      notifyListeners();
    }

    // Reset auto-hide timer
    _hideTimer?.cancel();
    _hideTimer = Timer(autoHideDelay, () {
      if (!_disposed && _isVisible) {
        _isVisible = false;
        notifyListeners();
      }
    });
  }

  void _updateBoundaries() {
    if (!scrollController.hasClients) return;

    final offset = scrollController.offset;
    final maxScroll = scrollController.position.maxScrollExtent;

    final newCanTop = offset > threshold;
    final newCanBottom = offset < (maxScroll - threshold);

    if (newCanTop != _canScrollToTop || newCanBottom != _canScrollToBottom) {
      _canScrollToTop = newCanTop;
      _canScrollToBottom = newCanBottom;
      notifyListeners();
    }
  }

  /// Smoothly scrolls to the top of the document (0.0)
  Future<void> scrollToBeginning({
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOutCubic,
  }) async {
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(0.0, duration: duration, curve: curve);
  }

  /// Smoothly scrolls to the bottom of the document (maxScrollExtent)
  Future<void> scrollToEnd({
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeOutCubic,
  }) async {
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: duration,
      curve: curve,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    scrollController.removeListener(_onScroll);
    super.dispose();
  }
}
