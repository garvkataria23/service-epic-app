import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:service_epic/data/repositories/auth_repository.dart';
import 'package:service_epic/data/repositories/payment_repository.dart';
import 'package:service_epic/data/services/local_storage_service.dart';
import 'package:service_epic/data/services/seed_data.dart';
import 'package:service_epic/domain/models/payment_transaction.dart';

void main() {
  late LocalStorageService storage;
  late AuthRepository authRepo;
  late PaymentRepository paymentRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    authRepo = AuthRepository(storage: storage);
    paymentRepo = PaymentRepository(storage: storage);
  });

  group('AuthRepository', () {
    test('signInDemo authenticates user and persists session', () async {
      expect(authRepo.isLoggedIn, isFalse);
      final res = await authRepo.signInDemo();
      expect(res.isSuccess, isTrue);
      expect(authRepo.isLoggedIn, isTrue);
      expect(authRepo.getCurrentUser()?.email, 'garv.client@example.com');
    });

    test('signUp creates custom profile and signOut clears token', () async {
      final res = await authRepo.signUp(
        fullName: 'Aarav Patel',
        email: 'aarav@example.com',
        phone: '+1 555-222-3333',
        city: 'Austin, TX',
        password: 'Password123',
      );
      expect(res.isSuccess, isTrue);
      expect(authRepo.getCurrentUser()?.fullName, 'Aarav Patel');
      await authRepo.signOut();
      expect(authRepo.isLoggedIn, isFalse);
    });
  });

  group('PaymentRepository', () {
    test('validates promo codes accurately', () {
      expect(paymentRepo.validatePromoCode('EPIC10'), 0.10);
      expect(paymentRepo.validatePromoCode('welcome15'), 0.15);
      expect(paymentRepo.validatePromoCode('INVALID'), isNull);
    });

    test('processEscrowPayment deducts wallet and creates held transaction',
        () async {
      await authRepo.signInDemo();
      final user = authRepo.getCurrentUser()!;
      final req = SeedData.initialRequests().first;
      final quote = SeedData.initialResponses().first; // $125

      final res = await paymentRepo.processEscrowPayment(
        user: user,
        request: req,
        quote: quote,
        method: PaymentMethodType.wallet,
        methodDetail: 'ServiceEpic Wallet',
        promoCode: 'EPIC10',
      );

      expect(res.isSuccess, isTrue);
      final txn = res.dataOrNull!;
      expect(txn.status, EscrowStatus.heldInEscrow);
      expect(txn.discount, 12.50);
      expect(txn.platformFee, 3.75);
      expect(txn.totalAmount, 116.25);

      final updatedUser = authRepo.getCurrentUser()!;
      expect(updatedUser.walletBalance, 2500.0 - 116.25);

      await paymentRepo.releaseEscrowForRequest(req.id);
      final updatedTxn = paymentRepo
          .getTransactions()
          .firstWhere((t) => t.id == txn.id);
      expect(updatedTxn.status, EscrowStatus.released);
    });
  });
}
