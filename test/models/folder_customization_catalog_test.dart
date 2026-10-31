import 'package:flutter_test/flutter_test.dart';
import 'package:quick_notes/models/folder.dart';
import 'package:quick_notes/models/folder_customization_icon.dart';

void main() {
  group('Folder Customization Catalog & Resolver Tests', () {
    test('1. Catalog contains exactly 67 icons with zero duplicates', () {
      final all = FolderCustomizationCatalog.allIcons;
      expect(all.length, equals(67));

      final idSet = <String>{};
      final pathSet = <String>{};

      for (final icon in all) {
        expect(idSet.add(icon.id), isTrue,
            reason: 'Duplicate icon ID detected: ${icon.id}');
        expect(pathSet.add(icon.assetPath), isTrue,
            reason: 'Duplicate asset path detected: ${icon.assetPath}');
      }
    });

    test('2. Each category has the exact expected count of icons', () {
      final calendar =
          FolderCustomizationCatalog.getByCategory(FolderIconCategory.calendar);
      final casual =
          FolderCustomizationCatalog.getByCategory(FolderIconCategory.casual);
      final food =
          FolderCustomizationCatalog.getByCategory(FolderIconCategory.food);
      final classic = FolderCustomizationCatalog.getByCategory(
          FolderIconCategory.classicStickers);

      expect(calendar.length, equals(23),
          reason: 'Calendar must contain 23 icons');
      expect(casual.length, equals(19),
          reason: 'Casual must contain 19 icons');
      expect(food.length, equals(19),
          reason: 'Food must contain 19 icons');
      expect(classic.length, equals(6),
          reason: 'Classic Stickers must contain 6 legacy icons');

      expect(calendar.length + casual.length + food.length + classic.length,
          equals(67));
    });

    test('3. Category filtering and category association integrity', () {
      for (final icon in FolderCustomizationCatalog.allIcons) {
        final filtered =
            FolderCustomizationCatalog.getByCategory(icon.category);
        expect(filtered.contains(icon), isTrue,
            reason: '${icon.id} must be in its category list');
        expect(
            FolderCustomizationCatalog.findCategoryForIdentifier(icon.id),
            equals(icon.category));
      }
    });

    test('4. FolderIconResolver resolves legacy sticker identifiers correctly',
        () {
      expect(FolderIconResolver.resolveAssetPath('birds.png'),
          equals('assets/stickers/birds.png'));
      expect(FolderIconResolver.resolveAssetPath('customer-service.png'),
          equals('assets/stickers/customer-service.png'));
      expect(FolderIconResolver.resolveAssetPath('kiss (1).png'),
          equals('assets/stickers/kiss (1).png'));
      expect(FolderIconResolver.resolveAssetPath('kiss.png'),
          equals('assets/stickers/kiss.png'));
      expect(FolderIconResolver.resolveAssetPath('love.png'),
          equals('assets/stickers/love.png'));
      expect(FolderIconResolver.resolveAssetPath('nurse.png'),
          equals('assets/stickers/nurse.png'));
    });

    test('5. FolderIconResolver resolves new categorized icons across formats',
        () {
      // By exact catalog ID
      expect(
        FolderIconResolver.resolveAssetPath('Calender/january.png'),
        equals('assets/Customization Icons/Calender/january.png'),
      );
      expect(
        FolderIconResolver.resolveAssetPath('Casual/coffee-time.png'),
        equals('assets/Customization Icons/Casual/coffee-time.png'),
      );
      expect(
        FolderIconResolver.resolveAssetPath('Food/pizza.png'),
        equals('assets/Customization Icons/Food/pizza.png'),
      );

      // By filename fallback
      expect(
        FolderIconResolver.resolveAssetPath('pizza.png'),
        equals('assets/Customization Icons/Food/pizza.png'),
      );
      expect(
        FolderIconResolver.resolveAssetPath('coffee-time.png'),
        equals('assets/Customization Icons/Casual/coffee-time.png'),
      );

      // By full asset path
      expect(
        FolderIconResolver.resolveAssetPath(
            'assets/Customization Icons/Food/pizza.png'),
        equals('assets/Customization Icons/Food/pizza.png'),
      );
    });

    test('6. FolderIconResolver returns null for null, empty, or unknown icons',
        () {
      expect(FolderIconResolver.resolveAssetPath(null), isNull);
      expect(FolderIconResolver.resolveAssetPath(''), isNull);
      expect(FolderIconResolver.resolveAssetPath('   '), isNull);
      expect(FolderIconResolver.resolveAssetPath('non_existent/icon.png'),
          isNull);
    });

    test('7. Saving and reloading a folder preserves its selected icon and color',
        () {
      final now = DateTime.now();
      final folder = Folder(
        id: 'f_persist_test',
        name: 'Design Assets',
        createdAt: now,
        colorHex: '0xFFFFBDE6',
        sticker: 'Calender/january.png',
      );

      final map = folder.toMap();
      expect(map['colorHex'], equals('0xFFFFBDE6'));
      expect(map['sticker'], equals('Calender/january.png'));

      final restored = Folder.fromMap(map);
      expect(restored.id, equals('f_persist_test'));
      expect(restored.name, equals('Design Assets'));
      expect(restored.colorHex, equals('0xFFFFBDE6'));
      expect(restored.sticker, equals('Calender/january.png'));

      final resolvedPath =
          FolderIconResolver.resolveAssetPath(restored.sticker);
      expect(resolvedPath,
          equals('assets/Customization Icons/Calender/january.png'));
    });
  });
}
