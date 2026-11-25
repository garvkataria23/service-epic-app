import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_epic/data/repositories/auth_repository.dart';
import 'package:service_epic/data/repositories/cart_order_repository.dart';
import 'package:service_epic/data/repositories/payment_repository.dart';
import 'package:service_epic/data/services/app_database.dart';
import 'package:service_epic/data/services/local_storage_service.dart';
import 'package:service_epic/data/services/seed_data.dart';
import 'package:service_epic/domain/models/payment_transaction.dart';
import 'package:service_epic/domain/models/service_order.dart';

void main() {
  late LocalStorageService storage;
  late AppDatabase db;
  late AuthRepository authRepo;
  late PaymentRepository paymentRepo;
  late CartOrderRepository cartRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    db = await AppDatabase.open(prefs, useSqlite: false);
    authRepo = AuthRepository(storage: storage);
    paymentRepo = PaymentRepository(storage: storage);
    cartRepo = CartOrderRepository(
      database: db,
      storage: storage,
      paymentRepository: paymentRepo,
    );
  });

  test('AppDatabase seeds realistic services and initial order', () async {
    final counts = await db.getTableCounts();
    expect(counts['services'], SeedData.services.length);
    expect(counts['orders'], 1);

    final services = await db.getAllServices();
    expect(services.first.skuCode, 'EPIC-PLM-101');
    expect(services.first.packages.first.sizeOrScope, isNotEmpty);
    expect(services.first.returnPolicy, isNotEmpty);
    expect(services.first.replacementPolicy, isNotEmpty);
  });

  test('Cart -> Buy Now -> Return / Replace persists in AppDatabase', () async {
    await authRepo.signInDemo();
    final user = authRepo.getCurrentUser()!;
    final service = SeedData.services.first;
    final pkg = service.packages.first;

    final cart = await cartRepo.addToCart(
      service: service,
      package: pkg,
      quantity: 2,
    );
    expect(cart.length, 1);
    expect(cart.first.quantity, 2);

    final orderRes = await cartRepo.placeDirectOrder(
      user: user,
      items: cart,
      method: PaymentMethodType.wallet,
      methodDetail: 'ServiceEpic Wallet',
      promoCode: 'EPIC10',
      clearCartAfter: true,
    );
    expect(orderRes.isSuccess, isTrue);
    final order = orderRes.dataOrNull!;
    expect(order.status, OrderStatus.confirmed);

    final remainingCart = await cartRepo.getCartItems();
    expect(remainingCart, isEmpty);

    final replaced = await cartRepo.requestReturnOrReplace(
      order: order,
      isReplacement: true,
      reason: 'Need different specialist',
    );
    expect(replaced.status, OrderStatus.replacementScheduled);
  });
}
