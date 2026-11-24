import 'service_category.dart';

enum RequestStatus {
  open('open', 'Open'),
  quoted('quoted', 'Quotes Received'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.id, this.label);
  final String id;
  final String label;

  static RequestStatus fromId(String id) {
    return RequestStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => RequestStatus.open,
    );
  }
}

enum RequestUrgency {
  flexible('flexible', 'Flexible (Within 2 weeks)'),
  normal('normal', 'Standard (Within 3–5 days)'),
  urgent('urgent', 'Urgent (Within 24–48 hrs)'),
  emergency('emergency', 'Immediate / Same Day');

  const RequestUrgency(this.id, this.label);
  final String id;
  final String label;

  static RequestUrgency fromId(String id) {
    return RequestUrgency.values.firstWhere(
      (u) => u.id == id,
      orElse: () => RequestUrgency.normal,
    );
  }
}

class TimelineEvent {
  const TimelineEvent({
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  final String title;
  final String subtitle;
  final DateTime timestamp;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    this.serviceId,
    this.serviceTitle,
    required this.title,
    required this.category,
    required this.description,
    required this.budgetMin,
    required this.budgetMax,
    required this.urgency,
    required this.preferredDate,
    required this.location,
    required this.contactEmail,
    required this.contactPhone,
    this.customAnswers = const {},
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.timeline = const [],
    this.clientRating,
    this.clientReview,
  });

  final String id;
  final String? serviceId;
  final String? serviceTitle;
  final String title;
  final ServiceCategory category;
  final String description;
  final double budgetMin;
  final double budgetMax;
  final RequestUrgency urgency;
  final DateTime preferredDate;
  final String location;
  final String contactEmail;
  final String contactPhone;
  final Map<String, String> customAnswers;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TimelineEvent> timeline;
  final double? clientRating;
  final String? clientReview;

  ServiceRequest copyWith({
    String? title,
    ServiceCategory? category,
    String? description,
    double? budgetMin,
    double? budgetMax,
    RequestUrgency? urgency,
    DateTime? preferredDate,
    String? location,
    String? contactEmail,
    String? contactPhone,
    Map<String, String>? customAnswers,
    RequestStatus? status,
    DateTime? updatedAt,
    List<TimelineEvent>? timeline,
    double? clientRating,
    String? clientReview,
  }) {
    return ServiceRequest(
      id: id,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      urgency: urgency ?? this.urgency,
      preferredDate: preferredDate ?? this.preferredDate,
      location: location ?? this.location,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      customAnswers: customAnswers ?? this.customAnswers,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      timeline: timeline ?? this.timeline,
      clientRating: clientRating ?? this.clientRating,
      clientReview: clientReview ?? this.clientReview,
    );
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      serviceId: json['serviceId'] as String?,
      serviceTitle: json['serviceTitle'] as String?,
      title: json['title'] as String,
      category: ServiceCategory.fromId(json['category'] as String),
      description: json['description'] as String,
      budgetMin: (json['budgetMin'] as num).toDouble(),
      budgetMax: (json['budgetMax'] as num).toDouble(),
      urgency: RequestUrgency.fromId(json['urgency'] as String),
      preferredDate: DateTime.parse(json['preferredDate'] as String),
      location: json['location'] as String,
      contactEmail: json['contactEmail'] as String,
      contactPhone: json['contactPhone'] as String,
      customAnswers:
          (json['customAnswers'] as Map<String, dynamic>? ?? const {})
              .map((k, v) => MapEntry(k, v.toString())),
      status: RequestStatus.fromId(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      timeline: (json['timeline'] as List<dynamic>? ?? const [])
          .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      clientRating: (json['clientRating'] as num?)?.toDouble(),
      clientReview: json['clientReview'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        'serviceTitle': serviceTitle,
        'title': title,
        'category': category.id,
        'description': description,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'urgency': urgency.id,
        'preferredDate': preferredDate.toIso8601String(),
        'location': location,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'customAnswers': customAnswers,
        'status': status.id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'clientRating': clientRating,
        'clientReview': clientReview,
      };
}
