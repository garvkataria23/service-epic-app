import 'service_category.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.category,
    required this.providerName,
    required this.variantName,
    required this.sizeOrScope,
    required this.unitPrice,
    required this.quantity,
    required this.deliveryLabel,
  });

  final String id;
  final String serviceId;
  final String serviceTitle;
  final ServiceCategory category;
  final String providerName;
  final String variantName;
  final String sizeOrScope;
  final double unitPrice;
  final int quantity;
  final String deliveryLabel;

  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        id: id,
        serviceId: serviceId,
        serviceTitle: serviceTitle,
        category: category,
        providerName: providerName,
        variantName: variantName,
        sizeOrScope: sizeOrScope,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        deliveryLabel: deliveryLabel,
      );

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String,
        serviceTitle: json['serviceTitle'] as String,
        category: ServiceCategory.fromId(json['category'] as String),
        providerName: json['providerName'] as String,
        variantName: json['variantName'] as String,
        sizeOrScope: json['sizeOrScope'] as String? ?? '',
        unitPrice: (json['unitPrice'] as num).toDouble(),
        quantity: json['quantity'] as int,
        deliveryLabel: json['deliveryLabel'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        'serviceTitle': serviceTitle,
        'category': category.id,
        'providerName': providerName,
        'variantName': variantName,
        'sizeOrScope': sizeOrScope,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'deliveryLabel': deliveryLabel,
      };
}
