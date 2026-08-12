import 'package:flutter/material.dart';
import 'search_transition_routes.dart';

/// Unified SearchRoute delegating to PixelAlignedSearchRoute for smooth HomeScreen transition consistency.
class SearchRoute<T> extends PixelAlignedSearchRoute<T> {
  SearchRoute({required super.builder});
}
