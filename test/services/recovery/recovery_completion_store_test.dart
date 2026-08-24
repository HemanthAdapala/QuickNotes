import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quick_notes/services/recovery/recovery_completion_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecoveryCompletionStore Unit Tests', () {
    late RecoveryCompletionStore store;
    const testHashA = 'hash_account_a_123456';
    const testHashB = 'hash_account_b_789012';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = RecoveryCompletionStore();
    });

    test('1. Missing status defaults to notCompleted', () async {
      final status = await store.getStatus(testHashA);
      expect(status, equals(RecoveryCompletionStatus.notCompleted));
    });

    test('2. Empty or blank hash safely returns notCompleted', () async {
      expect(await store.getStatus(''), equals(RecoveryCompletionStatus.notCompleted));
      expect(await store.getStatus('   '), equals(RecoveryCompletionStatus.notCompleted));
    });

    test('3. Setting restored persists correctly and reads back as restored', () async {
      await store.setStatus(testHashA, RecoveryCompletionStatus.restored);
      final status = await store.getStatus(testHashA);
      expect(status, equals(RecoveryCompletionStatus.restored));
    });

    test('4. Setting skipped persists correctly and reads back as skipped', () async {
      await store.setStatus(testHashA, RecoveryCompletionStatus.skipped);
      final status = await store.getStatus(testHashA);
      expect(status, equals(RecoveryCompletionStatus.skipped));
    });

    test('5. Setting keptLocalData persists correctly and reads back as keptLocalData', () async {
      await store.setStatus(testHashA, RecoveryCompletionStatus.keptLocalData);
      final status = await store.getStatus(testHashA);
      expect(status, equals(RecoveryCompletionStatus.keptLocalData));
    });

    test('6. Setting notCompleted cleans up stored preference key', () async {
      await store.setStatus(testHashA, RecoveryCompletionStatus.restored);
      expect(await store.getStatus(testHashA), equals(RecoveryCompletionStatus.restored));

      await store.setStatus(testHashA, RecoveryCompletionStatus.notCompleted);
      expect(await store.getStatus(testHashA), equals(RecoveryCompletionStatus.notCompleted));
    });

    test('7. Multi-tenant isolation: Account A status NEVER affects Account B', () async {
      await store.setStatus(testHashA, RecoveryCompletionStatus.restored);
      await store.setStatus(testHashB, RecoveryCompletionStatus.skipped);

      expect(await store.getStatus(testHashA), equals(RecoveryCompletionStatus.restored));
      expect(await store.getStatus(testHashB), equals(RecoveryCompletionStatus.skipped));

      // Clear Account A only
      await store.clearStatus(testHashA);

      expect(await store.getStatus(testHashA), equals(RecoveryCompletionStatus.notCompleted));
      expect(await store.getStatus(testHashB), equals(RecoveryCompletionStatus.skipped));
    });

    test('8. Clear status on non-existent hash handles safely without error', () async {
      await store.clearStatus('non_existent_hash');
      await store.clearStatus('');
      expect(await store.getStatus('non_existent_hash'), equals(RecoveryCompletionStatus.notCompleted));
    });

    test('9. Custom SharedPreferences instance injection works', () async {
      SharedPreferences.setMockInitialValues({'recovery_status_custom_hash': 'restored'});
      final customPrefs = await SharedPreferences.getInstance();
      final customStore = RecoveryCompletionStore(prefs: customPrefs);

      expect(await customStore.getStatus('custom_hash'), equals(RecoveryCompletionStatus.restored));
    });
  });
}
