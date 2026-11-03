import 'package:flutter/foundation.dart';

/// Available categories for folder customization icons and stickers.
enum FolderIconCategory {
  calendar('Calendar'),
  casual('Casual'),
  food('Food'),
  classicStickers('Classic Stickers');

  final String label;
  const FolderIconCategory(this.label);
}

/// Metadata representation of a folder customization icon or sticker.
@immutable
class FolderCustomizationIcon {
  final String id;
  final String assetPath;
  final String label;
  final FolderIconCategory category;

  const FolderCustomizationIcon({
    required this.id,
    required this.assetPath,
    required this.label,
    required this.category,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderCustomizationIcon &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FolderCustomizationIcon(id: $id, label: $label, category: ${category.name})';
}

/// Authoritative catalog of all 67 folder customization icons.
class FolderCustomizationCatalog {
  FolderCustomizationCatalog._();

  /// All 67 icons across Calendar, Casual, Food, and Classic Stickers.
  static const List<FolderCustomizationIcon> allIcons = [
    // ── Calendar (23 icons) ──
    FolderCustomizationIcon(
      id: 'Calender/april.png',
      assetPath: 'assets/Customization Icons/Calender/april.png',
      label: 'April',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/august.png',
      assetPath: 'assets/Customization Icons/Calender/august.png',
      label: 'August',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/autumn.png',
      assetPath: 'assets/Customization Icons/Calender/autumn.png',
      label: 'Autumn',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/december.png',
      assetPath: 'assets/Customization Icons/Calender/december.png',
      label: 'December',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/february.png',
      assetPath: 'assets/Customization Icons/Calender/february.png',
      label: 'February',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/friday.png',
      assetPath: 'assets/Customization Icons/Calender/friday.png',
      label: 'Friday',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/january.png',
      assetPath: 'assets/Customization Icons/Calender/january.png',
      label: 'January',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/july.png',
      assetPath: 'assets/Customization Icons/Calender/july.png',
      label: 'July',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/june.png',
      assetPath: 'assets/Customization Icons/Calender/june.png',
      label: 'June',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/march.png',
      assetPath: 'assets/Customization Icons/Calender/march.png',
      label: 'March',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/may.png',
      assetPath: 'assets/Customization Icons/Calender/may.png',
      label: 'May',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/monday.png',
      assetPath: 'assets/Customization Icons/Calender/monday.png',
      label: 'Monday',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/november.png',
      assetPath: 'assets/Customization Icons/Calender/november.png',
      label: 'November',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/october.png',
      assetPath: 'assets/Customization Icons/Calender/october.png',
      label: 'October',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/saturday.png',
      assetPath: 'assets/Customization Icons/Calender/saturday.png',
      label: 'Saturday',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/september.png',
      assetPath: 'assets/Customization Icons/Calender/september.png',
      label: 'September',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/spring.png',
      assetPath: 'assets/Customization Icons/Calender/spring.png',
      label: 'Spring',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/summer.png',
      assetPath: 'assets/Customization Icons/Calender/summer.png',
      label: 'Summer',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/sunday.png',
      assetPath: 'assets/Customization Icons/Calender/sunday.png',
      label: 'Sunday',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/thursday.png',
      assetPath: 'assets/Customization Icons/Calender/thursday.png',
      label: 'Thursday',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/tuesday.png',
      assetPath: 'assets/Customization Icons/Calender/tuesday.png',
      label: 'Tuesday',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/wednesday.png',
      assetPath: 'assets/Customization Icons/Calender/wednesday.png',
      label: 'Wednesday',
      category: FolderIconCategory.calendar,
    ),
    FolderCustomizationIcon(
      id: 'Calender/winter.png',
      assetPath: 'assets/Customization Icons/Calender/winter.png',
      label: 'Winter',
      category: FolderIconCategory.calendar,
    ),

    // ── Casual (19 icons) ──
    FolderCustomizationIcon(
      id: 'Casual/bath.png',
      assetPath: 'assets/Customization Icons/Casual/bath.png',
      label: 'Bath',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/chatting.png',
      assetPath: 'assets/Customization Icons/Casual/chatting.png',
      label: 'Chatting',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/coffee-time.png',
      assetPath: 'assets/Customization Icons/Casual/coffee-time.png',
      label: 'Coffee Time',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/cooking.png',
      assetPath: 'assets/Customization Icons/Casual/cooking.png',
      label: 'Cooking',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/drinking.png',
      assetPath: 'assets/Customization Icons/Casual/drinking.png',
      label: 'Drinking',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/dumbbell.png',
      assetPath: 'assets/Customization Icons/Casual/dumbbell.png',
      label: 'Dumbbell',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/guitar.png',
      assetPath: 'assets/Customization Icons/Casual/guitar.png',
      label: 'Guitar',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/laptop.png',
      assetPath: 'assets/Customization Icons/Casual/laptop.png',
      label: 'Laptop',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/listening (1).png',
      assetPath: 'assets/Customization Icons/Casual/listening (1).png',
      label: 'Listening (Alt 1)',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/listening (2).png',
      assetPath: 'assets/Customization Icons/Casual/listening (2).png',
      label: 'Listening (Alt 2)',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/listening.png',
      assetPath: 'assets/Customization Icons/Casual/listening.png',
      label: 'Listening',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/online-training.png',
      assetPath: 'assets/Customization Icons/Casual/online-training.png',
      label: 'Online Training',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/play-with-pet.png',
      assetPath: 'assets/Customization Icons/Casual/play-with-pet.png',
      label: 'Play With Pet',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/reading (1).png',
      assetPath: 'assets/Customization Icons/Casual/reading (1).png',
      label: 'Reading (Alt)',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/reading.png',
      assetPath: 'assets/Customization Icons/Casual/reading.png',
      label: 'Reading',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/stay-at-home.png',
      assetPath: 'assets/Customization Icons/Casual/stay-at-home.png',
      label: 'Stay At Home',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/tea-time.png',
      assetPath: 'assets/Customization Icons/Casual/tea-time.png',
      label: 'Tea Time',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/video-calling.png',
      assetPath: 'assets/Customization Icons/Casual/video-calling.png',
      label: 'Video Calling',
      category: FolderIconCategory.casual,
    ),
    FolderCustomizationIcon(
      id: 'Casual/watering-plants.png',
      assetPath: 'assets/Customization Icons/Casual/watering-plants.png',
      label: 'Watering Plants',
      category: FolderIconCategory.casual,
    ),

    // ── Food (19 icons) ──
    FolderCustomizationIcon(
      id: 'Food/breakfast.png',
      assetPath: 'assets/Customization Icons/Food/breakfast.png',
      label: 'Breakfast',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/burger.png',
      assetPath: 'assets/Customization Icons/Food/burger.png',
      label: 'Burger',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/cake.png',
      assetPath: 'assets/Customization Icons/Food/cake.png',
      label: 'Cake',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/chicken.png',
      assetPath: 'assets/Customization Icons/Food/chicken.png',
      label: 'Chicken',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/donut.png',
      assetPath: 'assets/Customization Icons/Food/donut.png',
      label: 'Donut',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/french-fries.png',
      assetPath: 'assets/Customization Icons/Food/french-fries.png',
      label: 'French Fries',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/hot-dog.png',
      assetPath: 'assets/Customization Icons/Food/hot-dog.png',
      label: 'Hot Dog',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/ice-cream.png',
      assetPath: 'assets/Customization Icons/Food/ice-cream.png',
      label: 'Ice Cream',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/japanese-food.png',
      assetPath: 'assets/Customization Icons/Food/japanese-food.png',
      label: 'Japanese Food',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/kebab.png',
      assetPath: 'assets/Customization Icons/Food/kebab.png',
      label: 'Kebab',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/noodles.png',
      assetPath: 'assets/Customization Icons/Food/noodles.png',
      label: 'Noodles',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/pancake.png',
      assetPath: 'assets/Customization Icons/Food/pancake.png',
      label: 'Pancake',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/pizza.png',
      assetPath: 'assets/Customization Icons/Food/pizza.png',
      label: 'Pizza',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/sandwich (1).png',
      assetPath: 'assets/Customization Icons/Food/sandwich (1).png',
      label: 'Sandwich (Alt)',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/sandwich.png',
      assetPath: 'assets/Customization Icons/Food/sandwich.png',
      label: 'Sandwich',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/spaghetti.png',
      assetPath: 'assets/Customization Icons/Food/spaghetti.png',
      label: 'Spaghetti',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/sushi.png',
      assetPath: 'assets/Customization Icons/Food/sushi.png',
      label: 'Sushi',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/taco.png',
      assetPath: 'assets/Customization Icons/Food/taco.png',
      label: 'Taco',
      category: FolderIconCategory.food,
    ),
    FolderCustomizationIcon(
      id: 'Food/waffle.png',
      assetPath: 'assets/Customization Icons/Food/waffle.png',
      label: 'Waffle',
      category: FolderIconCategory.food,
    ),

    // ── Classic Stickers (6 icons) ──
    FolderCustomizationIcon(
      id: 'birds.png',
      assetPath: 'assets/stickers/birds.png',
      label: 'Birds',
      category: FolderIconCategory.classicStickers,
    ),
    FolderCustomizationIcon(
      id: 'customer-service.png',
      assetPath: 'assets/stickers/customer-service.png',
      label: 'Customer Service',
      category: FolderIconCategory.classicStickers,
    ),
    FolderCustomizationIcon(
      id: 'kiss (1).png',
      assetPath: 'assets/stickers/kiss (1).png',
      label: 'Kiss (Alt)',
      category: FolderIconCategory.classicStickers,
    ),
    FolderCustomizationIcon(
      id: 'kiss.png',
      assetPath: 'assets/stickers/kiss.png',
      label: 'Kiss',
      category: FolderIconCategory.classicStickers,
    ),
    FolderCustomizationIcon(
      id: 'love.png',
      assetPath: 'assets/stickers/love.png',
      label: 'Love',
      category: FolderIconCategory.classicStickers,
    ),
    FolderCustomizationIcon(
      id: 'nurse.png',
      assetPath: 'assets/stickers/nurse.png',
      label: 'Nurse',
      category: FolderIconCategory.classicStickers,
    ),
  ];

  static final Map<String, FolderCustomizationIcon> _byId = {
    for (final icon in allIcons) icon.id: icon,
  };

  static final Map<String, FolderCustomizationIcon> _byAssetPath = {
    for (final icon in allIcons) icon.assetPath: icon,
  };

  static final Map<String, FolderCustomizationIcon> _byFileName = {
    for (final icon in allIcons) icon.assetPath.split('/').last: icon,
  };

  static final Map<FolderIconCategory, List<FolderCustomizationIcon>> _byCategory = {
    for (final cat in FolderIconCategory.values)
      cat: allIcons.where((icon) => icon.category == cat).toList(growable: false),
  };

  /// Retrieves all icons belonging to a specific [category].
  static List<FolderCustomizationIcon> getByCategory(FolderIconCategory category) {
    return _byCategory[category] ?? const [];
  }

  /// Finds the icon definition matching the given [identifier], if any.
  /// Matches by exact ID, exact asset path, or filename.
  static FolderCustomizationIcon? findIcon(String? identifier) {
    if (identifier == null || identifier.trim().isEmpty) return null;
    final trimmed = identifier.trim();
    return _byId[trimmed] ??
        _byAssetPath[trimmed] ??
        _byFileName[trimmed.split('/').last];
  }

  /// Determines which category an [identifier] belongs to.
  static FolderIconCategory? findCategoryForIdentifier(String? identifier) {
    return findIcon(identifier)?.category;
  }
}

/// Centralized resolver for converting persisted folder sticker/icon identifiers
/// into valid Flutter asset paths. Supports both legacy sticker names (e.g. `birds.png`)
/// and new categorized icon identifiers.
class FolderIconResolver {
  FolderIconResolver._();

  /// Resolves a persisted [stickerIdentifier] to its runtime asset bundle path.
  /// Returns `null` if the identifier is null, empty, or unknown.
  static String? resolveAssetPath(String? stickerIdentifier) {
    if (stickerIdentifier == null || stickerIdentifier.trim().isEmpty) {
      return null;
    }

    final trimmed = stickerIdentifier.trim();

    // 1. Direct catalog lookup (by ID, asset path, or filename)
    final matchedIcon = FolderCustomizationCatalog.findIcon(trimmed);
    if (matchedIcon != null) {
      return matchedIcon.assetPath;
    }

    // 2. Backward compatibility: if it already begins with 'assets/', return as-is
    if (trimmed.startsWith('assets/')) {
      return trimmed;
    }

    // 3. Fallback: if it's a legacy flat filename without slash
    if (!trimmed.contains('/')) {
      return 'assets/stickers/$trimmed';
    }

    return null;
  }
}

