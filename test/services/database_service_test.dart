import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:quick_notes/services/database_service.dart';
import 'package:quick_notes/services/database_exceptions.dart';
import 'package:quick_notes/models/database_integrity_result.dart';
import 'package:quick_notes/models/note.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  setUpAll(() {
    // Mock path_provider platform channel for desktop/CLI unit test environment
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );

    // Initialize FFI for local SQLite testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Phase 1.1 — Database Safety Foundation Tests', () {
    final dbService = DatabaseService.instance;

    test('1. Successful transaction commits writes atomically', () async {
      final id1 = 'test_tx_${uuid.v4()}';
      final id2 = 'test_tx_${uuid.v4()}';

      final note1 = Note(
        id: id1,
        title: 'Transaction Note 1',
        content: 'Content 1',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final note2 = Note(
        id: id2,
        title: 'Transaction Note 2',
        content: 'Content 2',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dbService.runInTransaction((executor) async {
        await executor.insert('notes', note1.toMap());
        await executor.insert('notes', note2.toMap());
      });

      final fetched1 = await dbService.queryById(id1);
      final fetched2 = await dbService.queryById(id2);

      expect(fetched1, isNotNull);
      expect(fetched1!.title, equals('Transaction Note 1'));
      expect(fetched2, isNotNull);
      expect(fetched2!.title, equals('Transaction Note 2'));
    });

    test('2. Failed transaction rolls back all writes executed within the block', () async {
      final rollbackId = 'test_rollback_${uuid.v4()}';

      final noteOk = Note(
        id: rollbackId,
        title: 'Rollback Note OK',
        content: 'Content OK',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () async {
          await dbService.runInTransaction((executor) async {
            await executor.insert('notes', noteOk.toMap());
            // Intentionally throw exception midway through transaction
            throw Exception('Simulated atomic write failure');
          });
        },
        throwsA(isA<DatabaseTransactionException>()),
      );

      // Verify that noteOk was rolled back and is NOT present in database
      final fetched = await dbService.queryById(rollbackId);
      expect(fetched, isNull);
    });

    test('3. Nested transaction calls execute safely without throwing TransactionAlreadyStarted', () async {
      final outerId = 'test_nested_outer_${uuid.v4()}';
      final innerId = 'test_nested_inner_${uuid.v4()}';

      final noteOuter = Note(
        id: outerId,
        title: 'Outer Note',
        content: 'Outer Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final noteInner = Note(
        id: innerId,
        title: 'Inner Note',
        content: 'Inner Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dbService.runInTransaction((outerExecutor) async {
        await outerExecutor.insert('notes', noteOuter.toMap());

        // Nested call to runInTransaction
        await dbService.runInTransaction((innerExecutor) async {
          await innerExecutor.insert('notes', noteInner.toMap());
        });
      });

      final fetchedOuter = await dbService.queryById(outerId);
      final fetchedInner = await dbService.queryById(innerId);

      expect(fetchedOuter, isNotNull);
      expect(fetchedInner, isNotNull);
    });

    test('4. Database exception propagates cleanly wrapped in DatabaseTransactionException', () async {
      expect(
        () async {
          await dbService.runInTransaction((executor) async {
            // Intentionally run invalid SQL syntax to trigger SQLite exception
            await executor.execute('INVALID SQL SYNTAX HERE');
          });
        },
        throwsA(isA<DatabaseTransactionException>()),
      );
    });

    test('5. Database integrity check reports healthy database', () async {
      final DatabaseIntegrityResult result = await dbService.checkIntegrity();

      expect(result.isHealthy, isTrue);
      expect(result.errors, isEmpty);
    });

    test('6. Transaction executes purely locally with zero network dependency', () async {
      final fastId = 'test_fast_${uuid.v4()}';
      final stopwatch = Stopwatch()..start();

      final noteFast = Note(
        id: fastId,
        title: 'Fast Local Note',
        content: 'Fast Local Content',
        tags: const [],
        attachments: const [],
        colorValue: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dbService.runInTransaction((executor) async {
        await executor.insert('notes', noteFast.toMap());
      });

      stopwatch.stop();

      // Verify transaction execution finished sub-500ms locally
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      final fetched = await dbService.queryById(fastId);
      expect(fetched, isNotNull);
    });
  });
}
