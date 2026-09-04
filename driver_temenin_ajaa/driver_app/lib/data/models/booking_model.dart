import 'user_model.dart';

class BookingModel {
  final String id;
  final String userId;
  final String? driverId;
  final String status;
  final String pickupLocation;
  final String dropoffLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final int duration;
  final double totalPrice;
  final DateTime? bookingDate;
  final Map<String, dynamic>? additionalDetails;
  final DateTime createdAt;
  final UserModel? client; // Joined client user data

  BookingModel({
    required this.id,
    required this.userId,
    this.driverId,
    required this.status,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    required this.duration,
    required this.totalPrice,
    this.bookingDate,
    this.additionalDetails,
    required this.createdAt,
    this.client,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      driverId: json['driver_id'] ?? json['driverId'],
      status: json['status'] ?? 'pending',
      pickupLocation: json['pickup_location'] ?? json['pickupLocation'] ?? '',
      dropoffLocation: json['dropoff_location'] ?? json['dropoffLocation'] ?? '',
      pickupLatitude: json['pickup_latitude'] != null ? (json['pickup_latitude'] as num).toDouble() : null,
      pickupLongitude: json['pickup_longitude'] != null ? (json['pickup_longitude'] as num).toDouble() : null,
      dropoffLatitude: json['dropoff_latitude'] != null ? (json['dropoff_latitude'] as num).toDouble() : null,
      dropoffLongitude: json['dropoff_longitude'] != null ? (json['dropoff_longitude'] as num).toDouble() : null,
      duration: json['duration'] ?? 0,
      totalPrice: (json['total_price'] ?? json['totalPrice'] ?? 0.0).toDouble(),
      bookingDate: json['booking_date'] != null ? DateTime.parse(json['booking_date']) : null,
      additionalDetails: json['additional_details'] ?? json['additionalDetails'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      client: json['users'] != null ? UserModel.fromJson(json['users']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'driver_id': driverId,
      'status': status,
      'pickup_location': pickupLocation,
      'dropoff_location': dropoffLocation,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'dropoff_latitude': dropoffLatitude,
      'dropoff_longitude': dropoffLongitude,
      'duration': duration,
      'total_price': totalPrice,
      'booking_date': bookingDate?.toIso8601String(),
      'additional_details': additionalDetails,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
