import 'package:flutter/foundation.dart';

import '../../../data/repositories/cart_order_repository.dart';
import '../../../domain/models/cart_item.dart';
import '../../../domain/models/service_item.dart';
import '../../../domain/models/service_order.dart';

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

  Future<void> requestReturnOrReplace({
    required ServiceOrder order,
    required bool isReplacement,
    required String reason,
  }) async {
    await _repository.requestReturnOrReplace(
      order: order,
      isReplacement: isReplacement,
      reason: reason,
    );
    _orders = await _repository.getOrders();
    notifyListeners();
  }
}
