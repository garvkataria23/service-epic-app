enum QuoteStatus {
  pending('pending', 'Pending Review'),
  negotiating('negotiating', 'In Discussion'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined');

  const QuoteStatus(this.id, this.label);
  final String id;
  final String label;

  static QuoteStatus fromId(String id) {
    return QuoteStatus.values.firstWhere(
      (q) => q.id == id,
      orElse: () => QuoteStatus.pending,
    );
  }
}

class ResponseMessage {
  const ResponseMessage({
    required this.id,
    required this.senderIsClient,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final bool senderIsClient;
  final String senderName;
  final String text;
  final DateTime timestamp;

  factory ResponseMessage.fromJson(Map<String, dynamic> json) {
    return ResponseMessage(
      id: json['id'] as String,
      senderIsClient: json['senderIsClient'] as bool,
      senderName: json['senderName'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderIsClient': senderIsClient,
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };
}

class ProviderResponse {
  const ProviderResponse({
    required this.id,
    required this.requestId,
    required this.providerName,
    required this.providerRole,
    required this.rating,
    required this.completedJobs,
    required this.isVerified,
    required this.quotedPrice,
    required this.estimatedDuration,
    required this.message,
    required this.deliverables,
    required this.status,
    required this.createdAt,
    this.messages = const [],
  });

  final String id;
  final String requestId;
  final String providerName;
  final String providerRole;
  final double rating;
  final int completedJobs;
  final bool isVerified;
  final double quotedPrice;
  final String estimatedDuration;
  final String message;
  final List<String> deliverables;
  final QuoteStatus status;
  final DateTime createdAt;
  final List<ResponseMessage> messages;

  ProviderResponse copyWith({
    double? quotedPrice,
    String? estimatedDuration,
    QuoteStatus? status,
    List<ResponseMessage>? messages,
  }) {
    return ProviderResponse(
      id: id,
      requestId: requestId,
      providerName: providerName,
      providerRole: providerRole,
      rating: rating,
      completedJobs: completedJobs,
      isVerified: isVerified,
      quotedPrice: quotedPrice ?? this.quotedPrice,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      message: message,
      deliverables: deliverables,
      status: status ?? this.status,
      createdAt: createdAt,
      messages: messages ?? this.messages,
    );
  }

  factory ProviderResponse.fromJson(Map<String, dynamic> json) {
    return ProviderResponse(
      id: json['id'] as String,
      requestId: json['requestId'] as String,
      providerName: json['providerName'] as String,
      providerRole: json['providerRole'] as String,
      rating: (json['rating'] as num).toDouble(),
      completedJobs: json['completedJobs'] as int,
      isVerified: json['isVerified'] as bool? ?? false,
      quotedPrice: (json['quotedPrice'] as num).toDouble(),
      estimatedDuration: json['estimatedDuration'] as String,
      message: json['message'] as String,
      deliverables: (json['deliverables'] as List<dynamic>).cast<String>(),
      status: QuoteStatus.fromId(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((e) => ResponseMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestId': requestId,
        'providerName': providerName,
        'providerRole': providerRole,
        'rating': rating,
        'completedJobs': completedJobs,
        'isVerified': isVerified,
        'quotedPrice': quotedPrice,
        'estimatedDuration': estimatedDuration,
        'message': message,
        'deliverables': deliverables,
        'status': status.id,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}
