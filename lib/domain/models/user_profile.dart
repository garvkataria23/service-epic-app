class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String fullAddress;
  final bool isDefault;

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        label: json['label'] as String,
        fullAddress: json['fullAddress'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fullAddress': fullAddress,
        'isDefault': isDefault,
      };
}

class SavedCard {
  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiry,
    required this.holderName,
  });

  final String id;
  final String brand;
  final String last4;
  final String expiry;
  final String holderName;

  factory SavedCard.fromJson(Map<String, dynamic> json) => SavedCard(
        id: json['id'] as String,
        brand: json['brand'] as String,
        last4: json['last4'] as String,
        expiry: json['expiry'] as String,
        holderName: json['holderName'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'last4': last4,
        'expiry': expiry,
        'holderName': holderName,
      };
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.walletBalance,
    this.savedAddresses = const [],
    this.savedCards = const [],
    required this.joinedAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final double walletBalance;
  final List<SavedAddress> savedAddresses;
  final List<SavedCard> savedCards;
  final DateTime joinedAt;

  String get defaultAddress {
    final def = savedAddresses.where((a) => a.isDefault).firstOrNull;
    return def?.fullAddress ??
        (savedAddresses.isNotEmpty ? savedAddresses.first.fullAddress : city);
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? city,
    double? walletBalance,
    List<SavedAddress>? savedAddresses,
    List<SavedCard>? savedCards,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      walletBalance: walletBalance ?? this.walletBalance,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      savedCards: savedCards ?? this.savedCards,
      joinedAt: joinedAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        city: json['city'] as String,
        walletBalance: (json['walletBalance'] as num).toDouble(),
        savedAddresses: (json['savedAddresses'] as List<dynamic>? ?? const [])
            .map((e) => SavedAddress.fromJson(e as Map<String, dynamic>))
            .toList(),
        savedCards: (json['savedCards'] as List<dynamic>? ?? const [])
            .map((e) => SavedCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'city': city,
        'walletBalance': walletBalance,
        'savedAddresses': savedAddresses.map((a) => a.toJson()).toList(),
        'savedCards': savedCards.map((c) => c.toJson()).toList(),
        'joinedAt': joinedAt.toIso8601String(),
      };
}
