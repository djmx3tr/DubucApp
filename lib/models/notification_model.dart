class NotificationModel {
  final int? id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? machineId;
  final String? alertType;
  final String? severity;

  NotificationModel({
    this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.machineId,
    this.alertType,
    this.severity,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      body: map['body'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: map['isRead'] == 1,
      machineId: map['machineId'] as String?,
      alertType: map['alertType'] as String?,
      severity: map['severity'] as String?,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      isRead: false,
      machineId: json['machine_id'] as String?,
      alertType: json['alert_type'] as String?,
      severity: json['severity'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead ? 1 : 0,
      'machineId': machineId,
      'alertType': alertType,
      'severity': severity,
    };
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? machineId,
    String? alertType,
    String? severity,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      machineId: machineId ?? this.machineId,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
    );
  }
}
