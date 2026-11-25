import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_epic/data/repositories/auth_repository.dart';
import 'package:service_epic/data/repositories/cart_order_repository.dart';
import 'package:service_epic/data/repositories/payment_repository.dart';
import 'package:service_epic/data/repositories/request_repository.dart';
import 'package:service_epic/data/repositories/service_repository.dart';
import 'package:service_epic/data/services/app_database.dart';
import 'package:service_epic/data/services/local_storage_service.dart';
import 'package:service_epic/data/services/service_api_client.dart';
import 'package:service_epic/main.dart';

void main() {
  testWidgets('ServiceEpicApp renders AuthScreen and logs in via Demo Login',
      (WidgetTester tester) async {
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

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('One-Tap Demo Client Login'), findsOneWidget);

    await tester.tap(find.text('One-Tap Demo Client Login'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Discover Services'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
