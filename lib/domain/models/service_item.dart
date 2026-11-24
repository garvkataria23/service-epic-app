import 'service_category.dart';

class ServicePackage {
  const ServicePackage({
    required this.name,
    required this.price,
    required this.deliveryLabel,
    required this.features,
  });

  final String name;
  final double price;
  final String deliveryLabel;
  final List<String> features;

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
    return ServicePackage(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      deliveryLabel: json['deliveryLabel'] as String,
      features: (json['features'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'deliveryLabel': deliveryLabel,
        'features': features,
      };
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.providerName,
    required this.providerTitle,
    required this.isVerifiedProvider,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    required this.basePrice,
    required this.priceUnit,
    required this.responseTimeMinutes,
    required this.location,
    required this.tags,
    required this.highlights,
    required this.packages,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final ServiceCategory category;
  final String description;
  final String providerName;
  final String providerTitle;
  final bool isVerifiedProvider;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final double basePrice;
  final String priceUnit;
  final int responseTimeMinutes;
  final String location;
  final List<String> tags;
  final List<String> highlights;
  final List<ServicePackage> packages;
  final bool isFeatured;

  String get formattedResponseTime {
    if (responseTimeMinutes < 60) {
      return '~$responseTimeMinutes min';
    }
    final hours = (responseTimeMinutes / 60).round();
    return '~$hours hr${hours > 1 ? 's' : ''}';
  }

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: ServiceCategory.fromId(json['category'] as String),
      description: json['description'] as String,
      providerName: json['providerName'] as String,
      providerTitle: json['providerTitle'] as String,
      isVerifiedProvider: json['isVerifiedProvider'] as bool? ?? false,
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['reviewCount'] as int,
      completedJobs: json['completedJobs'] as int,
      basePrice: (json['basePrice'] as num).toDouble(),
      priceUnit: json['priceUnit'] as String? ?? 'fixed',
      responseTimeMinutes: json['responseTimeMinutes'] as int? ?? 30,
      location: json['location'] as String? ?? 'Remote / Local',
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      highlights: (json['highlights'] as List<dynamic>).cast<String>(),
      packages: (json['packages'] as List<dynamic>)
          .map((e) => ServicePackage.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFeatured: json['isFeatured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.id,
        'description': description,
        'providerName': providerName,
        'providerTitle': providerTitle,
        'isVerifiedProvider': isVerifiedProvider,
        'rating': rating,
        'reviewCount': reviewCount,
        'completedJobs': completedJobs,
        'basePrice': basePrice,
        'priceUnit': priceUnit,
        'responseTimeMinutes': responseTimeMinutes,
        'location': location,
        'tags': tags,
        'highlights': highlights,
        'packages': packages.map((p) => p.toJson()).toList(),
        'isFeatured': isFeatured,
      };
}
