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

  Future<ServiceOrder> placeSampleOrder() async {
    await authRepo.signInDemo();
    final user = authRepo.getCurrentUser()!;
    final svc = SeedData.services.first;
    final items = await cartRepo.addToCart(
      service: svc,
      package: svc.packages.first,
    );
    final res = await cartRepo.placeDirectOrder(
      user: user,
      items: items,
      method: PaymentMethodType.wallet,
      methodDetail: 'Epic Wallet',
      clearCartAfter: true,
      preferredSlot: '10:00 AM – 12:00 PM',
    );
    return res.dataOrNull!;
  }

  test('Order cancel marks order cancelled, refunds txn, and restores wallet',
      () async {
    await authRepo.signInDemo();
    final initialBalance = authRepo.getCurrentUser()!.walletBalance;
    final order = await placeSampleOrder();
    final afterOrderUser = storage.loadUserProfile()!;
    expect(afterOrderUser.walletBalance, lessThan(initialBalance));

    final cancelled = await cartRepo.cancelOrder(
      order: order,
      user: afterOrderUser,
      reason: 'Booked wrong slot',
    );
    expect(cancelled.status, OrderStatus.cancelled);
    expect(cancelled.returnOrReplaceReason, contains('Booked wrong slot'));

    final refundedUser = storage.loadUserProfile()!;
    expect(refundedUser.walletBalance, closeTo(initialBalance, 0.01));

    final txn = paymentRepo
        .getTransactions()
        .firstWhere((t) => t.requestId == order.id);
    expect(txn.status, EscrowStatus.refunded);
  });

  test('Reschedule order updates preferredSlot and status', () async {
    final order = await placeSampleOrder();
    final updated = await cartRepo.rescheduleOrderSlot(
      order: order,
      newSlot: '5:00 PM – 7:00 PM',
    );
    expect(updated.preferredSlot, '5:00 PM – 7:00 PM');
    expect(updated.status, OrderStatus.scheduled);
  });

  test('Advance order to stage 4 completes order and releases escrow',
      () async {
    var order = await placeSampleOrder();
    for (var i = 0; i < 4; i++) {
      order = await cartRepo.advanceOrderProgress(order);
    }
    expect(order.progressStep, 4);
    expect(order.status, OrderStatus.completed);

    final txn = paymentRepo
        .getTransactions()
        .firstWhere((t) => t.requestId == order.id);
    expect(txn.status, EscrowStatus.released);
  });

  test('Return & Refund credits wallet and marks order & txn refunded',
      () async {
    await authRepo.signInDemo();
    final initialBalance = authRepo.getCurrentUser()!.walletBalance;
    final order = await placeSampleOrder();
    final afterOrderUser = storage.loadUserProfile()!;

    final returned = await cartRepo.requestReturnOrReplace(
      order: order,
      isReplacement: false,
      reason: 'Quality issue',
      user: afterOrderUser,
    );
    expect(returned.status, OrderStatus.refunded);
    expect(storage.loadUserProfile()!.walletBalance,
        closeTo(initialBalance, 0.01));

    final txn = paymentRepo
        .getTransactions()
        .firstWhere((t) => t.requestId == order.id);
    expect(txn.status, EscrowStatus.refunded);
  });

  test('Replacement generates fresh PIN, new slot, and resets to stage 1',
      () async {
    final order = await placeSampleOrder();
    final replaced = await cartRepo.requestReturnOrReplace(
      order: order,
      isReplacement: true,
      reason: 'Need another specialist',
      newSlot: '2:00 PM – 4:00 PM',
    );
    expect(replaced.status, OrderStatus.replacementScheduled);
    expect(replaced.preferredSlot, '2:00 PM – 4:00 PM');
    expect(replaced.progressStep, 1);
    expect(replaced.jobStartPin.length, 4);
  });
}
