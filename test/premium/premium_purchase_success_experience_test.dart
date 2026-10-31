import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:quick_notes/premium/premium.dart';
import 'package:quick_notes/themes/quick_notes_theme.dart';

class TestMockPurchaseProvider implements PurchaseProvider {
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

Widget createTestApp({
  required PremiumEntitlementManager manager,
  required TestMockPurchaseProvider mockProvider,
  ThemeData? theme,
  bool disableAnimations = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: manager),
      Provider<PurchaseProvider>.value(value: mockProvider),
      Provider<FeatureAccess>(create: (_) => DefaultFeatureAccess(manager)),
    ],
    child: MaterialApp(
      theme: theme ?? QuickNotesTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          size: const Size(400, 900),
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Underlying HomeScreen')),
          body: Center(
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    showPremiumGate(
                      context: context,
                      feature: PremiumFeature.darkMode,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Open Paywall'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    PremiumPurchaseSuccessCoordinator.reset();
  });

  group('BUG-002 Phase 2: Premium Purchase Success Experience Tests', () {
    testWidgets('1. A verified and persisted purchase displays the success experience',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      // Open paywall
      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock Premium'), findsOneWidget);

      // Complete verified & persisted purchase
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_verified_001',
        ),
      );
      await tester.pumpAndSettle();

      // Gate dismissed, celebration modal presented
      expect(find.text('Unlock Premium'), findsNothing);
      expect(find.text("You're Premium!"), findsOneWidget);
      expect(find.text("Your Quick Notes experience just got better."), findsOneWidget);
      expect(find.text("All premium features and themes are now unlocked."), findsOneWidget);
      expect(find.text("Let's go"), findsOneWidget);

      mockProvider.dispose();
    });

    testWidgets('2. Verification failure never displays success',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      // Emit error state (e.g. signature or receipt verification failed)
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage: 'Purchase verification failed: invalid signature',
        ),
      );
      await tester.pumpAndSettle();

      // Celebration modal is NOT shown; paywall remains with error
      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(find.text('Purchase verification failed: invalid signature'), findsOneWidget);
      expect(manager.isPremiumActive, isFalse);

      mockProvider.dispose();
    });

    testWidgets('3. Entitlement persistence failure never displays success',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      // Storage failure: coordinator emits error
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage: 'Failed to safely record Premium entitlement.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(manager.isPremiumActive, isFalse);

      mockProvider.dispose();
    });

    testWidgets('4. Premium activation must be confirmed before presentation',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      // Attempt to invoke showPremiumPurchaseSuccessDialog directly while Premium is inactive
      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      // Directly invoke showPremiumPurchaseSuccessDialog on paywall context while inactive
      final BuildContext currentContext = tester.element(find.text('Unlock Premium'));
      await showPremiumPurchaseSuccessDialog(
        context: currentContext,
        transactionId: 'tx_unconfirmed_004',
      );
      await tester.pumpAndSettle();

      // Celebration must not be presented because authoritative entitlement state is inactive
      expect(find.text("You're Premium!"), findsNothing);
      expect(manager.isPremiumActive, isFalse);

      mockProvider.dispose();
    });

    testWidgets('5. Duplicate purchase callbacks produce only one celebration',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      // Callback 1
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_duplicate_005',
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Callback 2 & 3 (duplicated rapidly in flight)
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_duplicate_005',
        ),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_duplicate_005',
        ),
      );
      await tester.pumpAndSettle();

      // Exactly ONE celebration modal is presented
      expect(find.text("You're Premium!"), findsOneWidget);
      expect(find.text("Let's go"), findsOneWidget);

      // Tapping dismiss once cleans up the modal completely
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);

      mockProvider.dispose();
    });

    testWidgets('6. Purchase-state and entitlement listeners cannot trigger duplicate celebrations',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      // Simultaneous listener notifications
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_simultaneous_006',
        ),
      );
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      await tester.pumpAndSettle();

      // Exactly ONE celebration modal appears without stacking
      expect(find.text("You're Premium!"), findsOneWidget);

      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);

      mockProvider.dispose();
    });

    testWidgets('7. Widget rebuilds do not replay success',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_rebuild_007',
        ),
      );
      await tester.pumpAndSettle();

      // Dismiss celebration
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsNothing);

      // Force entire widget tree to rebuild (theme change, layout pass, setState)
      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
        theme: QuickNotesTheme.darkTheme,
      ));
      await tester.pumpAndSettle();

      // Rebuild must NEVER resurrect or replay the celebration
      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);

      mockProvider.dispose();
    });

    testWidgets('8. Dismissing the celebration leaves Premium active',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_active_008',
        ),
      );
      await tester.pumpAndSettle();

      expect(manager.isPremiumActive, isTrue);

      // Tap "Let's go"
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      // Modal closed, but Premium remains 100% active!
      expect(find.text("You're Premium!"), findsNothing);
      expect(manager.isPremiumActive, isTrue);

      mockProvider.dispose();
    });

    testWidgets('9. Restoring an existing entitlement does not replay the new-purchase celebration',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      // Restore operation begins
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.restoring),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Restoring purchases...'), findsOneWidget);

      // Restored purchase arrives: entitlement is updated, but status goes to idle
      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.idle,
          transactionId: 'tx_restored_009',
        ),
      );
      await tester.pumpAndSettle();

      // Paywall closes, but celebration modal is NEVER displayed for restores
      expect(find.text('Unlock Premium'), findsNothing);
      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);
      expect(manager.isPremiumActive, isTrue);

      mockProvider.dispose();
    });

    testWidgets('10. App restart does not replay a stale celebration',
        (WidgetTester tester) async {
      // Session 1: User completes purchase and celebrates
      final mockProvider1 = TestMockPurchaseProvider();
      final manager1 = PremiumEntitlementManager();
      await manager1.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager1,
        mockProvider: mockProvider1,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      await manager1.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );
      mockProvider1.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.success,
          transactionId: 'tx_session1_010',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsNothing);
      mockProvider1.dispose();

      // Session 2 (Simulated App Restart): New manager and new provider mount with existing active entitlement
      final mockProvider2 = TestMockPurchaseProvider();
      final manager2 = PremiumEntitlementManager();
      await manager2.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager2,
        mockProvider: mockProvider2,
      ));
      await tester.pumpAndSettle();

      // Active state is restored from secure storage, but celebration is NOT replayed
      expect(manager2.isPremiumActive, isTrue);
      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Underlying HomeScreen'), findsOneWidget);

      mockProvider2.dispose();
    });

    testWidgets('11. Pending, cancelled, and failed purchases never display success',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Paywall'));
      await tester.pumpAndSettle();

      // Case A: Pending
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.pending),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text("You're Premium!"), findsNothing);
      expect(find.text('Payment Pending...'), findsOneWidget);

      // Case B: Cancelled
      mockProvider.emitState(
        const PurchaseStateUpdate(status: PurchaseActionStatus.cancelled),
      );
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsNothing);

      // Case C: Error
      mockProvider.emitState(
        const PurchaseStateUpdate(
          status: PurchaseActionStatus.error,
          errorMessage: 'Card expired',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsNothing);

      mockProvider.dispose();
    });

    testWidgets('12. The success action dismisses the experience safely',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      bool customDismissedCalled = false;

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      // Directly display dialog with onDismissed callback
      final BuildContext rootContext = tester.element(find.text('Open Paywall'));
      showPremiumPurchaseSuccessDialog(
        context: rootContext,
        transactionId: 'tx_dismiss_012',
        onDismissed: () => customDismissedCalled = true,
      );
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsOneWidget);
      expect(customDismissedCalled, isFalse);

      // Tap "Let's go"
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      // Modal cleanly popped and callback invoked
      expect(find.text("You're Premium!"), findsNothing);
      expect(customDismissedCalled, isTrue);

      mockProvider.dispose();
    });

    testWidgets('13. Both light and dark themes render correctly',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      // ── Test in Light Theme ──
      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
        theme: QuickNotesTheme.lightTheme,
      ));
      await tester.pumpAndSettle();

      final BuildContext lightContext = tester.element(find.text('Open Paywall'));
      showPremiumPurchaseSuccessDialog(
        context: lightContext,
        transactionId: 'tx_light_013',
      );
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsOneWidget);
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      // ── Test in Dark Theme ──
      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
        theme: QuickNotesTheme.darkTheme,
      ));
      await tester.pumpAndSettle();

      final BuildContext darkContext = tester.element(find.text('Open Paywall'));
      showPremiumPurchaseSuccessDialog(
        context: darkContext,
        transactionId: 'tx_dark_013',
      );
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsOneWidget);
      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsNothing);

      mockProvider.dispose();
    });

    testWidgets('14. Reduced-motion behavior is handled where supported',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      // Mount app with disableAnimations = true
      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Open Paywall'));
      showPremiumPurchaseSuccessDialog(
        context: context,
        transactionId: 'tx_reduced_motion_014',
      );
      // Under reduced motion, content renders immediately without waiting for controller progression
      await tester.pump();

      expect(find.text("You're Premium!"), findsOneWidget);
      expect(find.text("Let's go"), findsOneWidget);

      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();

      expect(find.text("You're Premium!"), findsNothing);

      mockProvider.dispose();
    });

    testWidgets('15. Two distinct legitimate purchases with different transaction IDs are not blocked',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      await tester.pumpWidget(createTestApp(
        manager: manager,
        mockProvider: mockProvider,
      ));
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.text('Open Paywall'));

      // Transaction A
      showPremiumPurchaseSuccessDialog(
        context: context,
        transactionId: 'order_A_015',
      );
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsOneWidget);

      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsNothing);

      // Re-triggering Transaction A is blocked
      showPremiumPurchaseSuccessDialog(
        context: context,
        transactionId: 'order_A_015',
      );
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsNothing);

      // Distinct Transaction B is accepted and celebrated
      showPremiumPurchaseSuccessDialog(
        context: context,
        transactionId: 'order_B_015',
      );
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsOneWidget);

      await tester.tap(find.text("Let's go"));
      await tester.pumpAndSettle();
      expect(find.text("You're Premium!"), findsNothing);

      mockProvider.dispose();
    });

    testWidgets('16. Dialog presentation on an unmounted context is safely rejected without consuming celebration',
        (WidgetTester tester) async {
      final mockProvider = TestMockPurchaseProvider();
      final manager = PremiumEntitlementManager();
      await manager.initialize();

      await manager.updateEntitlement(
        PremiumEntitlement.active(productId: 'quicknotes_premium_lifetime'),
      );

      BuildContext? savedContext;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const SizedBox();
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Replace widget tree so savedContext becomes unmounted
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(savedContext!.mounted, isFalse);

      await showPremiumPurchaseSuccessDialog(
        context: savedContext!,
        transactionId: 'tx_unmounted_016',
      );

      // Celebration was NOT consumed because context was unmounted
      expect(PremiumPurchaseSuccessCoordinator.hasCelebrated('tx_unmounted_016'), isFalse);

      mockProvider.dispose();
    });
  });
}
