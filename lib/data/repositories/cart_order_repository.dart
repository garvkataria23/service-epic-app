import 'dart:math';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/payment_transaction.dart';
import '../../domain/models/service_item.dart';
import '../../domain/models/service_order.dart';
import '../../domain/models/user_profile.dart';
import '../services/app_database.dart';
import '../services/local_storage_service.dart';
import 'payment_repository.dart';

class CartOrderRepository {
  CartOrderRepository({
    required AppDatabase database,
    required LocalStorageService storage,
    required PaymentRepository paymentRepository,
  })  : _database = database,
        _storage = storage,
        _paymentRepository = paymentRepository;

  final AppDatabase _database;
  final LocalStorageService _storage;
  final PaymentRepository _paymentRepository;
  final _uuid = const Uuid();
  final _random = Random();

  Future<List<CartItem>> getCartItems() => _database.getCartItems();

  Future<List<CartItem>> addToCart({
    required ServiceItem service,
    required ServicePackage package,
    int quantity = 1,
  }) async {
    final items = await _database.getCartItems();
    final idx = items.indexWhere(
      (i) => i.serviceId == service.id && i.variantName == package.name,
    );
    if (idx != -1) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + quantity);
    } else {
      items.add(
        CartItem(
          id: 'CART-${_uuid.v4().substring(0, 6).toUpperCase()}',
          serviceId: service.id,
          serviceTitle: service.title,
          category: service.category,
          providerName: service.providerName,
          variantName: package.name,
          sizeOrScope: package.sizeOrScope.isNotEmpty
              ? package.sizeOrScope
              : package.deliveryLabel,
          unitPrice: package.price,
          quantity: quantity,
          deliveryLabel: package.deliveryLabel,
        ),
      );
    }
    await _database.saveCartItems(items);
    return items;
  }

  Future<List<CartItem>> updateQuantity(String cartItemId, int quantity) async {
    final items = await _database.getCartItems();
    if (quantity <= 0) {
      items.removeWhere((i) => i.id == cartItemId);
    } else {
      final idx = items.indexWhere((i) => i.id == cartItemId);
      if (idx != -1) {
        items[idx] = items[idx].copyWith(quantity: quantity);
      }
    }
    await _database.saveCartItems(items);
    return items;
  }

  Future<List<CartItem>> clearCart() async {
    await _database.saveCartItems(const []);
    return const [];
  }

  Future<List<ServiceOrder>> getOrders() => _database.getAllOrders();

  Future<Result<ServiceOrder>> placeDirectOrder({
    required UserProfile user,
    required List<CartItem> items,
    required PaymentMethodType method,
    required String methodDetail,
    String? promoCode,
    SavedCard? newCardToSave,
    bool clearCartAfter = false,
    String preferredSlot = '10:00 AM – 12:00 PM',
  }) async {
    if (items.isEmpty) {
      return const Failure(ValidationException('Your cart is empty.'));
    }
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (_storage.simulateApiError) {
      return const Failure(
        NetworkException('Payment gateway unreachable. Order was not placed.'),
      );
    }

    final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    final platformFee = double.parse((subtotal * 0.03).toStringAsFixed(2));
    final discountRate = promoCode != null
        ? (_paymentRepository.validatePromoCode(promoCode) ?? 0.0)
        : 0.0;
    final discount =
        double.parse((subtotal * discountRate).toStringAsFixed(2));
    final total =
        double.parse((subtotal + platformFee - discount).toStringAsFixed(2));

    var updatedUser = user;
    if (method == PaymentMethodType.wallet) {
      if (user.walletBalance < total) {
        return Failure(
          ValidationException(
            'Insufficient wallet balance (\$${user.walletBalance.toStringAsFixed(2)}).',
          ),
        );
      }
      updatedUser = user.copyWith(
        walletBalance:
            double.parse((user.walletBalance - total).toStringAsFixed(2)),
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

    final orderId = 'ORD-${10000 + _random.nextInt(89999)}';
    final txnId = 'TXN-${10000 + _random.nextInt(89999)}';
    final pin = '${1000 + _random.nextInt(8999)}';

    final order = ServiceOrder(
      id: orderId,
      items: items,
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      totalAmount: total,
      paymentMethod: method,
      paymentDetail: methodDetail,
      transactionId: txnId,
      status: OrderStatus.confirmed,
      promoCode: discountRate > 0 ? promoCode?.trim().toUpperCase() : null,
      preferredSlot: preferredSlot,
      jobStartPin: pin,
      progressStep: 0,
      createdAt: DateTime.now(),
    );
    await _database.upsertOrder(order);

    final txn = PaymentTransaction(
      id: txnId,
      requestId: orderId,
      quoteId: 'DIRECT',
      providerName: items.first.providerName,
      serviceTitle: items.length == 1
          ? items.first.serviceTitle
          : '${items.first.serviceTitle} (+${items.length - 1} more)',
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      totalAmount: total,
      method: method,
      methodDetail: methodDetail,
      status: EscrowStatus.heldInEscrow,
      promoCode: order.promoCode,
      createdAt: DateTime.now(),
    );
    final txns = _storage.loadTransactions()..insert(0, txn);
    await _storage.saveTransactions(txns);

    await _paymentRepository.addNotification(
      AppNotification(
        id: 'NOTIF-${_uuid.v4().substring(0, 6)}',
        title: 'Order Confirmed ($orderId)',
        body:
            'Paid \$${total.toStringAsFixed(2)} via $methodDetail. Protected by 7-day Return & Replace policy.',
        type: NotificationType.payment,
        createdAt: DateTime.now(),
      ),
    );

    if (clearCartAfter) {
      await clearCart();
    }

    return Success(order);
  }

  Future<ServiceOrder> requestReturnOrReplace({
    required ServiceOrder order,
    required bool isReplacement,
    required String reason,
  }) async {
    final updated = order.copyWith(
      status: isReplacement
          ? OrderStatus.replacementScheduled
          : OrderStatus.returnRequested,
      returnOrReplaceReason: reason.trim(),
    );
    await _database.upsertOrder(updated);

    await _paymentRepository.addNotification(
      AppNotification(
        id: 'NOTIF-${_uuid.v4().substring(0, 6)}',
        title: isReplacement
            ? 'Free Replacement Scheduled (${order.id})'
            : 'Return & Refund Requested (${order.id})',
        body: 'Reason: ${reason.trim()}',
        type: NotificationType.status,
        createdAt: DateTime.now(),
      ),
    );

    return updated;
  }

  Future<ServiceOrder> advanceOrderProgress(ServiceOrder order) async {
    final nextStep = (order.progressStep + 1).clamp(0, 4);
    final nextStatus = nextStep >= 4
        ? OrderStatus.completed
        : (nextStep >= 1 ? OrderStatus.scheduled : OrderStatus.confirmed);
    final updated = order.copyWith(
      progressStep: nextStep,
      status: nextStatus,
    );
    await _database.upsertOrder(updated);
    if (nextStep >= 4) {
      await _paymentRepository.releaseEscrowForRequest(order.id);
    }
    return updated;
  }
}
