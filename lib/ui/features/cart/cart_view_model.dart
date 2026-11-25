import 'package:flutter/foundation.dart';

import '../../../data/repositories/cart_order_repository.dart';
import '../../../domain/models/cart_item.dart';
import '../../../domain/models/service_item.dart';
import '../../../domain/models/service_order.dart';
import '../../../domain/models/user_profile.dart';

class CartViewModel extends ChangeNotifier {
  CartViewModel({required CartOrderRepository repository})
      : _repository = repository;

  final CartOrderRepository _repository;

  List<CartItem> _items = [];
  List<ServiceOrder> _orders = [];
  bool _isLoading = false;

  List<CartItem> get items => _items;
  List<ServiceOrder> get orders => _orders;
  bool get isLoading => _isLoading;

  int get totalItemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.lineTotal);

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    _items = await _repository.getCartItems();
    _orders = await _repository.getOrders();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addToCart({
    required ServiceItem service,
    required ServicePackage package,
    int quantity = 1,
  }) async {
    _items = await _repository.addToCart(
      service: service,
      package: package,
      quantity: quantity,
    );
    notifyListeners();
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    _items = await _repository.updateQuantity(cartItemId, quantity);
    notifyListeners();
  }

  Future<void> refreshOrders() async {
    _items = await _repository.getCartItems();
    _orders = await _repository.getOrders();
    notifyListeners();
  }

  Future<ServiceOrder> cancelOrder({
    required ServiceOrder order,
    required UserProfile user,
    required String reason,
  }) async {
    final updated = await _repository.cancelOrder(
      order: order,
      user: user,
      reason: reason,
    );
    _orders = await _repository.getOrders();
    notifyListeners();
    return updated;
  }

  Future<ServiceOrder> rescheduleOrderSlot({
    required ServiceOrder order,
    required String newSlot,
  }) async {
    final updated = await _repository.rescheduleOrderSlot(
      order: order,
      newSlot: newSlot,
    );
    _orders = await _repository.getOrders();
    notifyListeners();
    return updated;
  }

  Future<ServiceOrder> requestReturnOrReplace({
    required ServiceOrder order,
    required bool isReplacement,
    required String reason,
    UserProfile? user,
    String? newSlot,
  }) async {
    final updated = await _repository.requestReturnOrReplace(
      order: order,
      isReplacement: isReplacement,
      reason: reason,
      user: user,
      newSlot: newSlot,
    );
    _orders = await _repository.getOrders();
    notifyListeners();
    return updated;
  }

  Future<ServiceOrder> advanceOrderProgress(ServiceOrder order) async {
    final updated = await _repository.advanceOrderProgress(order);
    _orders = await _repository.getOrders();
    notifyListeners();
    return updated;
  }
}
