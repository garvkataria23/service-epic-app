import 'service_category.dart';

class ServicePackage {
  const ServicePackage({
    this.id = '',
    required this.name,
    this.sizeOrScope = '',
    required this.price,
    this.originalPrice,
    required this.deliveryLabel,
    required this.features,
  });

  final String id;
  final String name;
  final String sizeOrScope;
  final double price;
  final double? originalPrice;
  final String deliveryLabel;
  final List<String> features;

  int get discountPercent {
    if (originalPrice == null || originalPrice! <= price) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }

  factory ServicePackage.fromJson(Map<String, dynamic> json) {
    return ServicePackage(
      id: json['id'] as String? ?? '',
      name: json['name'] as String,
      sizeOrScope: json['sizeOrScope'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      deliveryLabel: json['deliveryLabel'] as String,
      features: (json['features'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sizeOrScope': sizeOrScope,
        'price': price,
        'originalPrice': originalPrice,
        'deliveryLabel': deliveryLabel,
        'features': features,
      };
}

class ServiceReview {
  const ServiceReview({
    required this.id,
    required this.reviewerName,
    required this.rating,
    required this.dateLabel,
    required this.comment,
    this.verifiedPurchase = true,
    this.variantPurchased = '',
  });

  final String id;
  final String reviewerName;
  final double rating;
  final String dateLabel;
  final String comment;
  final bool verifiedPurchase;
  final String variantPurchased;

  factory ServiceReview.fromJson(Map<String, dynamic> json) => ServiceReview(
        id: json['id'] as String,
        reviewerName: json['reviewerName'] as String,
        rating: (json['rating'] as num).toDouble(),
        dateLabel: json['dateLabel'] as String,
        comment: json['comment'] as String,
        verifiedPurchase: json['verifiedPurchase'] as bool? ?? true,
        variantPurchased: json['variantPurchased'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reviewerName': reviewerName,
        'rating': rating,
        'dateLabel': dateLabel,
        'comment': comment,
        'verifiedPurchase': verifiedPurchase,
        'variantPurchased': variantPurchased,
      };
}

class ServiceFaq {
  const ServiceFaq({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  factory ServiceFaq.fromJson(Map<String, dynamic> json) => ServiceFaq(
        question: json['question'] as String,
        answer: json['answer'] as String,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
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
    this.skuCode = 'EPIC-SRV',
    this.warrantyBadge = '30-Day Service Guarantee',
    this.returnPolicy =
        '7-day free rework or 100% refund if deliverables do not match the agreed scope.',
    this.replacementPolicy =
        'Free specialist or deliverable replacement within 24 hours on verified quality issues.',
    this.cancellationPolicy =
        '100% free cancellation up to 4 hours before scheduled slot.',
    this.slaGuarantee = 'On-Time Arrival & Milestone SLA Protection',
    this.customerReviews = const [],
    this.faqs = const [],
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

  final String skuCode;
  final String warrantyBadge;
  final String returnPolicy;
  final String replacementPolicy;
  final String cancellationPolicy;
  final String slaGuarantee;
  final List<ServiceReview> customerReviews;
  final List<ServiceFaq> faqs;

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
      skuCode: json['skuCode'] as String? ?? 'EPIC-SRV',
      warrantyBadge:
          json['warrantyBadge'] as String? ?? '30-Day Service Guarantee',
      returnPolicy: json['returnPolicy'] as String? ??
          '7-day free rework or 100% refund if deliverables do not match the agreed scope.',
      replacementPolicy: json['replacementPolicy'] as String? ??
          'Free specialist or deliverable replacement within 24 hours on verified quality issues.',
      cancellationPolicy: json['cancellationPolicy'] as String? ??
          '100% free cancellation up to 4 hours before scheduled slot.',
      slaGuarantee: json['slaGuarantee'] as String? ??
          'On-Time Arrival & Milestone SLA Protection',
      customerReviews: (json['customerReviews'] as List<dynamic>? ?? const [])
          .map((e) => ServiceReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      faqs: (json['faqs'] as List<dynamic>? ?? const [])
          .map((e) => ServiceFaq.fromJson(e as Map<String, dynamic>))
          .toList(),
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
        'skuCode': skuCode,
        'warrantyBadge': warrantyBadge,
        'returnPolicy': returnPolicy,
        'replacementPolicy': replacementPolicy,
        'cancellationPolicy': cancellationPolicy,
        'slaGuarantee': slaGuarantee,
        'customerReviews': customerReviews.map((r) => r.toJson()).toList(),
        'faqs': faqs.map((f) => f.toJson()).toList(),
      };
}
