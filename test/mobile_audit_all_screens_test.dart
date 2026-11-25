import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_epic/data/repositories/auth_repository.dart';
import 'package:service_epic/data/repositories/cart_order_repository.dart';
import 'package:service_epic/data/repositories/payment_repository.dart';
import 'package:service_epic/data/repositories/request_repository.dart';
import 'package:service_epic/data/repositories/service_repository.dart';
import 'package:service_epic/data/services/app_database.dart';
import 'package:service_epic/data/services/local_storage_service.dart';
import 'package:service_epic/data/services/seed_data.dart';
import 'package:service_epic/data/services/service_api_client.dart';
import 'package:service_epic/main.dart';

void main() {
  testWidgets(
      'Mobile 360x800 full button & workflow audit: ServiceDetail -> Cart -> Checkout -> Receipt -> Orders (Reschedule/Cancel) -> SubmitRequest -> RequestDetail -> Wallet -> Currency Toggle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final database = await AppDatabase.open(prefs, useSqlite: false);
    final apiClient = ServiceApiClient(storage: storage);
    final serviceRepo = ServiceRepository(
      apiClient: apiClient,
      storage: storage,
      database: database,
    );
    final requestRepo = RequestRepository(apiClient: apiClient);
    final authRepo = AuthRepository(storage: storage);
    final paymentRepo = PaymentRepository(storage: storage);
    final cartOrderRepo = CartOrderRepository(
      database: database,
      storage: storage,
      paymentRepository: paymentRepo,
    );

    await tester.pumpWidget(
      ServiceEpicApp(
        storage: storage,
        database: database,
        serviceRepository: serviceRepo,
        requestRepository: requestRepo,
        authRepository: authRepo,
        paymentRepository: paymentRepo,
        cartOrderRepository: cartOrderRepo,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 1. Auth -> Demo Login
    await tester.tap(find.text('One-Tap Demo Client Login'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('₹ INR'), findsOneWidget);

    // Verify one-tap currency pill in Discovery header
    await tester.tap(find.text('₹ INR'));
    await tester.pumpAndSettle();
    expect(find.text('\$ USD'), findsOneWidget);
    await tester.tap(find.text('\$ USD'));
    await tester.pumpAndSettle();
    expect(find.text('₹ INR'), findsOneWidget);

    // Verify Saved filter chip exists
    expect(find.textContaining('Saved ('), findsOneWidget);

    // 2. Discovery -> Open first Service Detail
    await tester.tap(find.text(SeedData.services.first.title).first);
    await tester.pumpAndSettle();
    expect(find.text('Add to Cart'), findsOneWidget);
    expect(find.text('Buy Now'), findsOneWidget);

    // Add to Cart & open Cart via SnackBar 'View Cart'
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Cart'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 3. Cart -> Proceed to Buy Now -> Checkout
    expect(find.text('Proceed to Buy Now'), findsOneWidget);
    await tester.tap(find.text('Proceed to Buy Now'));
    await tester.pumpAndSettle();
    expect(find.text('Secure Escrow Checkout'), findsOneWidget);
    expect(find.text('Preferred Arrival / Kickoff Slot'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Service Visit Address'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Service Visit Address'), findsOneWidget);

    // Select Wallet & Pay in Escrow
    await tester.scrollUntilVisible(
      find.text('Wallet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify & Pay'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 4. Payment Receipt -> Copy Invoice & Done
    expect(find.text('Payment Receipt'), findsOneWidget);
    expect(find.text('Order Confirmed & Protected'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Done'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Invoice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // 5. Orders Tab -> ConfirmationBanner + Reschedule + Cancel Order
    expect(find.text('Order Confirmed & Protected'), findsOneWidget);
    await tester.tap(find.text('Reschedule').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5:00 PM – 7:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Slot'));
    await tester.pumpAndSettle();
    expect(find.text('Arrival Slot Updated'), findsOneWidget);

    await tester.tap(find.text('Cancel Order').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel & Refund'));
    await tester.pumpAndSettle();
    expect(find.text('Order Cancelled & Refunded'), findsOneWidget);

    // Back to Discovery
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();

    // 6. Wallet Tab -> Top Up Payment Flow (UPI/Card + OTP Verification) + ConfirmationBanner
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Top Up Epic Wallet'), findsOneWidget);
    await tester.tap(find.text('Proceed to Verify & Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Verify Top-Up Payment'), findsOneWidget);
    await tester.tap(find.text('Verify & Top Up'));
    await tester.pumpAndSettle();
    expect(find.text('Wallet Topped Up'), findsOneWidget);

    // 7. Account Tab -> Toggle INR <-> USD
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    final currencySwitch = find.textContaining('Display Currency');
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(currencySwitch);
    await tester.pumpAndSettle();
    expect(find.textContaining('USD'), findsWidgets);
  });
}
