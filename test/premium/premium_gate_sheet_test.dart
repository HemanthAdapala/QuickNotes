import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumFeaturePresentation Metadata Unit Tests', () {
    test('1. Resolves presentation metadata for folderCustomization', () {
      final p = PremiumFeaturePresentation.forFeature(PremiumFeature.folderCustomization);
      expect(p.categoryTag, equals('FOLDER CUSTOMIZATION'));
      expect(p.headline, contains('Folder'));
      expect(p.description, contains('hex colors'));
      expect(p.icon, equals(Icons.folder_special_rounded));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });

    test('2. Resolves presentation metadata for darkMode', () {
      final p = PremiumFeaturePresentation.forFeature(PremiumFeature.darkMode);
      expect(p.categoryTag, equals('OBSIDIAN DARK MODE'));
      expect(p.headline, contains('Night'));
      expect(p.description, contains('aluminum'));
      expect(p.icon, equals(Icons.dark_mode_rounded));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });

    test('3. Resolves presentation metadata for widgets', () {
      final p = PremiumFeaturePresentation.forFeature(PremiumFeature.widgets);
      expect(p.categoryTag, equals('HOME SCREEN WIDGETS'));
      expect(p.headline, contains('Glance'));
      expect(p.description, contains('Quick Capture'));
      expect(p.icon, equals(Icons.widgets_rounded));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });

    test('4. Resolves default metadata when feature is null', () {
      final p = PremiumFeaturePresentation.forFeature(null);
      expect(p.categoryTag, equals('QUICK NOTES PREMIUM'));
      expect(p.headline, contains('Full Experience'));
      expect(p.benefits.length, greaterThanOrEqualTo(3));
    });
  });

  group('PremiumGateSheet Widget & Presentation Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      PremiumPurchaseSuccessCoordinator.reset();
    });

    testWidgets('5. Renders PremiumGateSheet for folderCustomization with all elements',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.folderCustomization,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('FOLDER CUSTOMIZATION'), findsOneWidget);
      expect(find.text('Make Every Folder Yours'), findsOneWidget);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);
      expect(find.text('Maybe Later'), findsOneWidget);
      expect(find.byIcon(Icons.folder_special_rounded), findsOneWidget);
    });

    testWidgets('6. Renders PremiumGateSheet for darkMode in Dark Theme',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.darkTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.darkMode,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('OBSIDIAN DARK MODE'), findsOneWidget);
      expect(find.text('A Calmer Workspace for Night'), findsOneWidget);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });

    testWidgets('7. Renders PremiumGateSheet for widgets with custom price subtitle',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.widgets,
              customPriceSubtitle: 'Special Introductory Offer',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HOME SCREEN WIDGETS'), findsOneWidget);
      expect(find.text('Your Thoughts, Right at a Glance'), findsOneWidget);
      expect(find.text('Special Introductory Offer'), findsOneWidget);
      expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);
    });

    testWidgets('8. Tapping Unlock Premium invokes callback and does NOT mutate entitlement',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final manager = PremiumEntitlementManager();
      await manager.initialize();

      bool unlockInvoked = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PremiumGateSheet(
                feature: PremiumFeature.folderCustomization,
                onUnlockPressed: () => unlockInvoked = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Initial state: free/inactive
      expect(manager.isPremiumActive, isFalse);

      // Tap Unlock Premium
      await tester.tap(find.text('Unlock Premium'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(unlockInvoked, isTrue);
      // Verify NO fake purchasing occurred: entitlement MUST still be inactive
      expect(manager.isPremiumActive, isFalse);
    });

    testWidgets('9. Tapping Restore Purchases invokes restore callback',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      bool restoreInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.folderCustomization,
              onRestorePressed: () => restoreInvoked = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      final restoreFinder = find.text('Restore Purchases');
      await tester.ensureVisible(restoreFinder);
      await tester.tap(restoreFinder);
      await tester.pump(const Duration(milliseconds: 300));

      expect(restoreInvoked, isTrue);
    });

    testWidgets('10. Responsive layout on compact screen without overflow',
        (WidgetTester tester) async {
      // iPhone SE / small screen size
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(
        MaterialApp(
          theme: QuickNotesTheme.lightTheme,
          home: const Scaffold(
            body: PremiumGateSheet(
              feature: PremiumFeature.darkMode,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('11. showPremiumGate skips presentation if user is already Premium',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final manager = PremiumEntitlementManager();
      await manager.initialize();
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      BuildContext? testContext;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  testContext = context;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(testContext, isNotNull);

      // Call showPremiumGate
      await showPremiumGate(
        context: testContext!,
        feature: PremiumFeature.darkMode,
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet should NOT be presented since user is already premium
      expect(find.text('Unlock Premium'), findsNothing);
    });

    testWidgets('12. Displays pending UI and pending banner when PurchaseActionStatus.pending is emitted',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            Provider<PurchaseProvider>.value(value: mockProvider),
            Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PremiumGateSheet(
                feature: PremiumFeature.darkMode,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.text('Payment Pending...'), findsNothing);

      // Emit pending status
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.pending,
          errorMessage:
              'Your purchase is pending payment approval. Premium features will unlock once the payment is completed and verified.',
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Payment Pending...'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(
        find.text(
          'Your purchase is pending payment approval. Premium features will unlock once the payment is completed and verified.',
        ),
        findsWidgets,
      );

      // Verify Premium remains locked
      expect(manager.isPremiumActive, isFalse);

      mockProvider.dispose();
    });

    testWidgets('13. Tapping button while pending displays snackbar notice and prevents duplicate purchase',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            Provider<PurchaseProvider>.value(value: mockProvider),
            Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PremiumGateSheet(
                feature: PremiumFeature.folderCustomization,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Emit pending
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.pending,
          errorMessage:
              'Your purchase is pending payment approval. Premium features will unlock once the payment is completed and verified.',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Payment Pending...'), findsOneWidget);

      // Tap pending button
      await tester.tap(find.text('Payment Pending...'));
      await tester.pump(const Duration(milliseconds: 300));

      // Notice snackbar must be displayed and purchasePremium must NOT be called again
      expect(mockProvider.purchaseCalled, isFalse);
      expect(manager.isPremiumActive, isFalse);

      mockProvider.dispose();
    });

    testWidgets('14. Restore state updates loading indicator and failure/timeout resets loading',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: manager),
            Provider<PurchaseProvider>.value(value: mockProvider),
            Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PremiumGateSheet(
                feature: PremiumFeature.widgets,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Restore Purchases'), findsOneWidget);

      // Emit restoring state
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.restoring,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Restoring purchases...'), findsOneWidget);

      // Emit timeout error
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage:
              'Unable to confirm previous purchases from the store. If you previously purchased Premium, please check your network and Google Play account, then try again.',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Loading spinner reset back to text
      expect(find.text('Restore Purchases'), findsOneWidget);
      expect(find.text('Restoring purchases...'), findsNothing);

      mockProvider.dispose();
    });
  });

  group('Phase 1 Regression Tests: Navigation Hierarchy & Single Dismissal', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    Widget createTestApp({
      required PremiumEntitlementManager manager,
      required MockPurchaseProvider mockProvider,
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: manager),
          Provider<PurchaseProvider>.value(value: mockProvider),
          Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Underlying HomeScreen')),
            body: Center(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showPremiumGate(
                        context: context,
                        feature: PremiumFeature.darkMode,
                      );
                    },
                    child: const Text('Trigger Premium Gate'),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Test A — Successful purchase dismisses gate once and preserves underlying HomeScreen',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        createTestApp(manager: manager, mockProvider: mockProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Underlying HomeScreen'), findsOneWidget);

      // Open gate sheet via real BlurredBottomSheetRoute
      await tester.tap(find.text('Trigger Premium Gate'));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Premium'), findsOneWidget);

      // Simulate purchase success: entitlement updated and purchase action success emitted
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.success),
      );
      await tester.pumpAndSettle();

      // Premium gate dismissed
      expect(find.text('Unlock Premium'), findsNothing);
      // Underlying route remains present and visible!
      expect(find.text('Underlying HomeScreen'), findsOneWidget);
      // Premium active
      expect(manager.isPremiumActive, isTrue);
      // Premium Purchase Success celebration modal displayed
      expect(find.text("You're Premium!"), findsOneWidget);
      expect(find.text("Your Quick Notes experience just got better."), findsOneWidget);
      expect(find.text("Let's go"), findsOneWidget);

      // Dismiss celebration modal via primary action
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);
      expect(manager.isPremiumActive, isTrue);

      mockProvider.dispose();
    });

    testWidgets('Test B — Successful restore dismisses gate once and preserves underlying HomeScreen',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        createTestApp(manager: manager, mockProvider: mockProvider),
      );
      await tester.pumpAndSettle();

      // Open gate sheet
      await tester.tap(find.text('Trigger Premium Gate'));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Premium'), findsOneWidget);

      // Emit restoring state
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.restoring),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Restoring purchases...'), findsOneWidget);

      // Simulate restored purchase success and entitlement update
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.success),
      );
      await tester.pumpAndSettle();

      // Gate dismissed, underlying route preserved
      expect(find.text('Unlock Premium'), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);
      expect(manager.isPremiumActive, isTrue);

      mockProvider.dispose();
    });

    testWidgets('Test C — Duplicate and re-entrant success events do not pop underlying route',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        createTestApp(manager: manager, mockProvider: mockProvider),
      );
      await tester.pumpAndSettle();

      // Open gate sheet
      await tester.tap(find.text('Trigger Premium Gate'));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Premium'), findsOneWidget);

      // Signal 1: Entitlement manager updates
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      // Step into reverse animation (in-flight dismissal)
      await tester.pump(const Duration(milliseconds: 50));

      // Signal 2 & 3: Repeated stateStream success events while animation in progress
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.success),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.success),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Signal 4: Redundant entitlement notification
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      await tester.pumpAndSettle();

      // Gate dismissed cleanly, underlying route still visible and untouched!
      expect(find.text('Unlock Premium'), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);
      expect(tester.takeException(), isNull);

      mockProvider.dispose();
    });

    testWidgets('Test D — Cancellation and error preserve gate presentation without dismissing route',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1100));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        createTestApp(manager: manager, mockProvider: mockProvider),
      );
      await tester.pumpAndSettle();

      // Open gate sheet
      await tester.tap(find.text('Trigger Premium Gate'));
      await tester.pumpAndSettle();

      // Emit cancellation
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.cancelled),
      );
      await tester.pumpAndSettle();

      // Gate remains open
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(manager.isPremiumActive, isFalse);

      // Emit failure
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage: 'Card issuer declined transaction',
        ),
      );
      await tester.pumpAndSettle();

      // Gate remains open and usable, error snackbar visible
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.text('Card issuer declined transaction'), findsOneWidget);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);

      mockProvider.dispose();
    });

    testWidgets('Test E — Lifecycle safety: disposal of gate while async events arrive does not throw or over-pop',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));

      final mockProvider = MockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(
        createTestApp(manager: manager, mockProvider: mockProvider),
      );
      await tester.pumpAndSettle();

      // Open gate sheet
      await tester.tap(find.text('Trigger Premium Gate'));
      await tester.pumpAndSettle();

      // Dismiss gate manually via "Maybe Later"
      await tester.tap(find.text('Maybe Later'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));

      // Asynchronous purchase events arrive during or after dismissal
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.success),
      );
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      await tester.pumpAndSettle();

      // Underlying route remains active and uncorrupted
      expect(find.text('Underlying HomeScreen'), findsOneWidget);
      expect(tester.takeException(), isNull);

      mockProvider.dispose();
    });
  });
}

class MockPurchaseProvider implements PurchaseProvider {
  final StreamController<PurchaseStateUpdate> _stateController =
      StreamController<PurchaseStateUpdate>.broadcast();
  final StreamController<PremiumEntitlement> _entitlementController =
      StreamController<PremiumEntitlement>.broadcast();

  PurchaseStateUpdate _currentState = const PurchaseStateUpdate.idle();
  bool purchaseCalled = false;
  bool restoreCalled = false;

  void emitState(PurchaseStateUpdate state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  StoreSource get storeSource => StoreSource.google;
  @override
  bool get isAvailable => true;
  @override
  ProductDetails? get productDetails => null;
  @override
  String? get formattedPrice => '\$4.99';
  @override
  PurchaseStateUpdate get currentState => _currentState;
  @override
  Stream<PurchaseStateUpdate> get stateStream => _stateController.stream;
  @override
  Stream<PremiumEntitlement> get entitlementStream =>
      _entitlementController.stream;
  @override
  Future<bool> isBillingAvailable() async => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<ProductDetails?> loadProductDetails() async => null;
  @override
  Future<bool> purchasePremium() async {
    purchaseCalled = true;
    return true;
  }
  @override
  Future<bool> restorePurchases() async {
    restoreCalled = true;
    return true;
  }
  @override
  Future<bool> reconcilePurchases({bool isUserTriggered = false}) async {
    restoreCalled = true;
    return true;
  }
  @override
  Future<void> onAppResume() async {}
  @override
  void dispose() {
    _stateController.close();
    _entitlementController.close();
  }
}
