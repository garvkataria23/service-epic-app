enum NotificationType {
  quote('quote'),
  message('message'),
  payment('payment'),
  status('status');

  const NotificationType(this.id);
  final String id;

  static NotificationType fromId(String id) {
    return NotificationType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => NotificationType.status,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.relatedRequestId,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedRequestId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      relatedRequestId: relatedRequestId,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: NotificationType.fromId(json['type'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
        relatedRequestId: json['relatedRequestId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.id,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'relatedRequestId': relatedRequestId,
      };
}
