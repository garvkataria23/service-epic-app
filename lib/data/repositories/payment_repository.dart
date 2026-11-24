import 'dart:math';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/payment_transaction.dart';
import '../../domain/models/provider_response.dart';
import '../../domain/models/service_request.dart';
import '../../domain/models/user_profile.dart';
import '../services/local_storage_service.dart';

class PaymentRepository {
  PaymentRepository({required LocalStorageService storage})
      : _storage = storage;

  final LocalStorageService _storage;
  final _uuid = const Uuid();
  final _random = Random();

  static const Map<String, double> promoDiscounts = {
    'EPIC10': 0.10,
    'WELCOME15': 0.15,
    'PRO20': 0.20,
  };

  double? validatePromoCode(String code) {
    final normalized = code.trim().toUpperCase();
    return promoDiscounts[normalized];
  }

  List<PaymentTransaction> getTransactions() {
    final list = _storage.loadTransactions();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<AppNotification> getNotifications() {
    final list = _storage.loadNotifications();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> addNotification(AppNotification notif) async {
    final current = _storage.loadNotifications();
    current.insert(0, notif);
    await _storage.saveNotifications(current);
  }

  Future<void> markAllNotificationsRead() async {
    final current = _storage
        .loadNotifications()
        .map((n) => n.copyWith(isRead: true))
        .toList();
    await _storage.saveNotifications(current);
  }

  Future<Result<PaymentTransaction>> processEscrowPayment({
    required UserProfile user,
    required ServiceRequest request,
    required ProviderResponse quote,
    required PaymentMethodType method,
    required String methodDetail,
    String? promoCode,
    SavedCard? newCardToSave,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Payment gateway unreachable. No funds were charged.'),
      );
    }

    final subtotal = quote.quotedPrice;
    final platformFee = double.parse((subtotal * 0.03).toStringAsFixed(2));
    final discountRate =
        promoCode != null ? (validatePromoCode(promoCode) ?? 0.0) : 0.0;
    final discount =
        double.parse((subtotal * discountRate).toStringAsFixed(2));
    final total =
        double.parse((subtotal + platformFee - discount).toStringAsFixed(2));

    var updatedUser = user;
    if (method == PaymentMethodType.wallet) {
      if (user.walletBalance < total) {
        return Failure(
          ValidationException(
            'Insufficient wallet balance (\$${user.walletBalance.toStringAsFixed(2)}). Please top up or select Card/UPI.',
          ),
        );
      }
      updatedUser = user.copyWith(
        walletBalance: double.parse((user.walletBalance - total).toStringAsFixed(2)),
      );
    }

    if (newCardToSave != null) {
      final exists = updatedUser.savedCards.any(
        (c) => c.last4 == newCardToSave.last4 && c.expiry == newCardToSave.expiry,
      );
      if (!exists) {
        updatedUser = updatedUser.copyWith(
          savedCards: [...updatedUser.savedCards, newCardToSave],
        );
      }
    }
    await _storage.saveUserProfile(updatedUser);

    final txn = PaymentTransaction(
      id: 'TXN-${10000 + _random.nextInt(89999)}',
      requestId: request.id,
      quoteId: quote.id,
      providerName: quote.providerName,
      serviceTitle: request.title,
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      totalAmount: total,
      method: method,
      methodDetail: methodDetail,
      status: EscrowStatus.heldInEscrow,
      promoCode: discountRate > 0 ? promoCode?.trim().toUpperCase() : null,
      createdAt: DateTime.now(),
    );

    final txns = _storage.loadTransactions()..insert(0, txn);
    await _storage.saveTransactions(txns);

    await addNotification(
      AppNotification(
        id: 'NOTIF-${_uuid.v4().substring(0, 6)}',
        title: 'Escrow Payment Confirmed (\$${total.toStringAsFixed(2)})',
        body:
            'Paid via $methodDetail for ${request.id}. Funds are protected until completion.',
        type: NotificationType.payment,
        createdAt: DateTime.now(),
        relatedRequestId: request.id,
      ),
    );

    return Success(txn);
  }

  Future<void> releaseEscrowForRequest(String requestId) async {
    final txns = _storage.loadTransactions();
    var changed = false;
    for (var i = 0; i < txns.length; i++) {
      if (txns[i].requestId == requestId &&
          txns[i].status == EscrowStatus.heldInEscrow) {
        txns[i] = txns[i].copyWith(status: EscrowStatus.released);
        changed = true;
      }
    }
    if (changed) {
      await _storage.saveTransactions(txns);
      await addNotification(
        AppNotification(
          id: 'NOTIF-${_uuid.v4().substring(0, 6)}',
          title: 'Escrow Released to Provider',
          body: 'Payment for $requestId has been released upon job completion.',
          type: NotificationType.payment,
          createdAt: DateTime.now(),
          relatedRequestId: requestId,
        ),
      );
    }
  }
}
