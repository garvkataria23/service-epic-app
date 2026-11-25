import 'cart_item.dart';
import 'payment_transaction.dart';

enum OrderStatus {
  confirmed('confirmed', 'Confirmed'),
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  returnRequested('return_requested', 'Return / Refund Requested'),
  replacementScheduled('replacement_scheduled', 'Replacement Scheduled'),
  refunded('refunded', 'Refunded');

  const OrderStatus(this.id, this.label);
  final String id;
  final String label;

  static OrderStatus fromId(String id) {
    return OrderStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => OrderStatus.confirmed,
    );
  }
}

class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.platformFee,
    required this.discount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentDetail,
    required this.transactionId,
    required this.status,
    required this.createdAt,
    this.promoCode,
    this.returnOrReplaceReason,
  });

  final String id;
  final List<CartItem> items;
  final double subtotal;
  final double platformFee;
  final double discount;
  final double totalAmount;
  final PaymentMethodType paymentMethod;
  final String paymentDetail;
  final String transactionId;
  final OrderStatus status;
  final DateTime createdAt;
  final String? promoCode;
  final String? returnOrReplaceReason;

  ServiceOrder copyWith({
    OrderStatus? status,
    String? returnOrReplaceReason,
  }) =>
      ServiceOrder(
        id: id,
        items: items,
        subtotal: subtotal,
        platformFee: platformFee,
        discount: discount,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        paymentDetail: paymentDetail,
        transactionId: transactionId,
        status: status ?? this.status,
        createdAt: createdAt,
        promoCode: promoCode,
        returnOrReplaceReason:
            returnOrReplaceReason ?? this.returnOrReplaceReason,
      );

  factory ServiceOrder.fromJson(Map<String, dynamic> json) => ServiceOrder(
        id: json['id'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        platformFee: (json['platformFee'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        paymentMethod:
            PaymentMethodType.fromId(json['paymentMethod'] as String),
        paymentDetail: json['paymentDetail'] as String,
        transactionId: json['transactionId'] as String,
        status: OrderStatus.fromId(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        promoCode: json['promoCode'] as String?,
        returnOrReplaceReason: json['returnOrReplaceReason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'platformFee': platformFee,
        'discount': discount,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod.id,
        'paymentDetail': paymentDetail,
        'transactionId': transactionId,
        'status': status.id,
        'createdAt': createdAt.toIso8601String(),
        'promoCode': promoCode,
        'returnOrReplaceReason': returnOrReplaceReason,
      };
}
