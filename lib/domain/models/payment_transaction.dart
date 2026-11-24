enum PaymentMethodType {
  card('card', 'Credit / Debit Card'),
  upi('upi', 'UPI / Instant Bank'),
  wallet('wallet', 'ServiceEpic Wallet');

  const PaymentMethodType(this.id, this.label);
  final String id;
  final String label;

  static PaymentMethodType fromId(String id) {
    return PaymentMethodType.values.firstWhere(
      (m) => m.id == id,
      orElse: () => PaymentMethodType.card,
    );
  }
}

enum EscrowStatus {
  heldInEscrow('held_in_escrow', 'Held in Escrow'),
  released('released', 'Released to Provider'),
  refunded('refunded', 'Refunded'),
  topUp('top_up', 'Wallet Top-Up');

  const EscrowStatus(this.id, this.label);
  final String id;
  final String label;

  static EscrowStatus fromId(String id) {
    return EscrowStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => EscrowStatus.heldInEscrow,
    );
  }
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.requestId,
    required this.quoteId,
    required this.providerName,
    required this.serviceTitle,
    required this.subtotal,
    required this.platformFee,
    required this.discount,
    required this.totalAmount,
    required this.method,
    required this.methodDetail,
    required this.status,
    required this.createdAt,
    this.promoCode,
  });

  final String id;
  final String requestId;
  final String quoteId;
  final String providerName;
  final String serviceTitle;
  final double subtotal;
  final double platformFee;
  final double discount;
  final double totalAmount;
  final PaymentMethodType method;
  final String methodDetail;
  final EscrowStatus status;
  final DateTime createdAt;
  final String? promoCode;

  PaymentTransaction copyWith({EscrowStatus? status}) {
    return PaymentTransaction(
      id: id,
      requestId: requestId,
      quoteId: quoteId,
      providerName: providerName,
      serviceTitle: serviceTitle,
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      totalAmount: totalAmount,
      method: method,
      methodDetail: methodDetail,
      status: status ?? this.status,
      createdAt: createdAt,
      promoCode: promoCode,
    );
  }

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) =>
      PaymentTransaction(
        id: json['id'] as String,
        requestId: json['requestId'] as String,
        quoteId: json['quoteId'] as String,
        providerName: json['providerName'] as String,
        serviceTitle: json['serviceTitle'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        platformFee: (json['platformFee'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        method: PaymentMethodType.fromId(json['method'] as String),
        methodDetail: json['methodDetail'] as String,
        status: EscrowStatus.fromId(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        promoCode: json['promoCode'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestId': requestId,
        'quoteId': quoteId,
        'providerName': providerName,
        'serviceTitle': serviceTitle,
        'subtotal': subtotal,
        'platformFee': platformFee,
        'discount': discount,
        'totalAmount': totalAmount,
        'method': method.id,
        'methodDetail': methodDetail,
        'status': status.id,
        'createdAt': createdAt.toIso8601String(),
        'promoCode': promoCode,
      };
}
