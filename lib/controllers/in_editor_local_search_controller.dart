import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Represents a single match range in title or document content
class LocalSearchMatch {
  final bool isTitle;
  final int start;
  final int end;

  const LocalSearchMatch({
    required this.isTitle,
    required this.start,
    required this.end,
  });
}

/// Standalone controller for local search state, match calculation, and navigation
class InEditorLocalSearchController extends ChangeNotifier {
  String _query = '';
  List<LocalSearchMatch> _matches = [];
  int _currentMatchIndex = 0;

  String get query => _query;
  List<LocalSearchMatch> get matches => List.unmodifiable(_matches);
  int get currentMatchIndex => _currentMatchIndex;
  int get totalMatches => _matches.length;
  LocalSearchMatch? get currentMatch =>
      _matches.isNotEmpty && _currentMatchIndex < _matches.length
          ? _matches[_currentMatchIndex]
          : null;

  /// Performs a fresh search against title and body text
  void performSearch(String newQuery, String titleText, String bodyText) {
    _query = newQuery.trim();
    _matches.clear();
    _currentMatchIndex = 0;

    if (_query.isEmpty) {
      notifyListeners();
      return;
    }

    final lowerQuery = _query.toLowerCase();

    // 1. Search inside Title
    final lowerTitle = titleText.toLowerCase();
    int idx = 0;
    while ((idx = lowerTitle.indexOf(lowerQuery, idx)) != -1) {
      _matches.add(LocalSearchMatch(
        isTitle: true,
        start: idx,
        end: idx + lowerQuery.length,
      ));
      idx += lowerQuery.length;
    }

    // 2. Search inside Document Body
    final lowerBody = bodyText.toLowerCase();
    idx = 0;
    while ((idx = lowerBody.indexOf(lowerQuery, idx)) != -1) {
      _matches.add(LocalSearchMatch(
        isTitle: false,
        start: idx,
        end: idx + lowerQuery.length,
      ));
      idx += lowerQuery.length;
    }

    notifyListeners();
  }

  /// Advances to the next match with wrap-around
  void nextMatch() {
    if (_matches.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    notifyListeners();
  }

  /// Steps back to the previous match with wrap-around
  void previousMatch() {
    if (_matches.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    notifyListeners();
  }

  /// Resets search state completely
  void clear() {
    _query = '';
    _matches.clear();
    _currentMatchIndex = 0;
    notifyListeners();
  }
}
