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
      'EXTREME mobile stress test (320x640 @ 1.25x textScale): all tabs, ServiceDetail, Compare, Cart, Orders, Checkout, Receipt, SubmitRequest, RequestDetail, Wallet, Account',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.25;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

    // 1. Auth Screen (Sign In & Sign Up tabs)
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('One-Tap Demo Client Login'));
    await tester.tap(find.text('One-Tap Demo Client Login'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 2. Discovery Screen -> Open ServiceDetail -> Add to Cart -> Cart -> Checkout -> Receipt -> Orders
    await tester.tap(find.text(SeedData.services.first.title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Cart'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Proceed to Buy Now'));
    await tester.pumpAndSettle();
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

    // Receipt -> Done
    await tester.scrollUntilVisible(
      find.text('Done'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Back from Cart & ServiceDetail to Discovery
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();

    // 3. Discovery -> Scroll to service cards, select 2 & open CompareScreen
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    final compareIcons = find.byIcon(Icons.compare_arrows_rounded);
    await tester.ensureVisible(compareIcons.at(0));
    await tester.tap(compareIcons.at(0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(compareIcons.at(1));
    await tester.tap(compareIcons.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Compare (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();

    // 4. Requests Tab -> Open SubmitRequestScreen -> Back -> Open RequestDetailScreen -> Overview
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('REQ-').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details & Timeline'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();

    // 5. Wallet Tab
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    // 6. Account Tab
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
  });
}
