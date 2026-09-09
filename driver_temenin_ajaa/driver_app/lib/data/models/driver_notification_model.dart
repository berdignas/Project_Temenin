import 'booking_model.dart';

enum NotificationType {
  newOrder,
  orderCancelled,
  orderNegotiation,
  systemAlert,
}

class DriverNotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final BookingModel? booking;
  bool isRead;

  DriverNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type = NotificationType.newOrder,
    this.booking,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'isRead': isRead,
  };
}
