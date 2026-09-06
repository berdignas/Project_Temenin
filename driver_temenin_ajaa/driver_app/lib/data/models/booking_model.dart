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
    final addDetails = json['additional_details'] is Map<String, dynamic>
        ? json['additional_details'] as Map<String, dynamic>
        : (json['additionalDetails'] is Map<String, dynamic>
            ? json['additionalDetails'] as Map<String, dynamic>
            : (json['additional_details'] != null
                ? Map<String, dynamic>.from(json['additional_details'])
                : (json['additionalDetails'] != null
                    ? Map<String, dynamic>.from(json['additionalDetails'])
                    : null)));

    final rawStatus = json['status']?.toString() ?? 'pending';
    final subStatus = addDetails?['sub_status']?.toString();
    final isDpPaid = addDetails?['dp_paid'] == true || subStatus == 'dp_paid' || json['dp_paid'] == true;

    final isAdvanced = subStatus == 'on_the_way' || 
                       subStatus == 'arrived' || 
                       subStatus == 'started' || 
                       subStatus == 'ongoing' || 
                       subStatus == 'completed' || 
                       subStatus == 'paid';

    String effectiveStatus = subStatus ?? rawStatus;
    if (isDpPaid && !isAdvanced) {
      effectiveStatus = 'dp_paid';
    }

    return BookingModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? json['driverId']?.toString(),
      status: effectiveStatus,
      pickupLocation: json['pickup_location'] ?? json['pickupLocation'] ?? '',
      dropoffLocation: json['dropoff_location'] ?? json['dropoffLocation'] ?? '',
      pickupLatitude: json['pickup_latitude'] != null ? (json['pickup_latitude'] as num).toDouble() : null,
      pickupLongitude: json['pickup_longitude'] != null ? (json['pickup_longitude'] as num).toDouble() : null,
      dropoffLatitude: json['dropoff_latitude'] != null ? (json['dropoff_latitude'] as num).toDouble() : null,
      dropoffLongitude: json['dropoff_longitude'] != null ? (json['dropoff_longitude'] as num).toDouble() : null,
      duration: json['duration'] ?? 0,
      totalPrice: (json['total_price'] ?? json['totalPrice'] ?? 0.0).toDouble(),
      bookingDate: json['booking_date'] != null ? DateTime.tryParse(json['booking_date'].toString()) : null,
      additionalDetails: addDetails,
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()) : DateTime.now(),
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

  BookingModel copyWith({
    String? id,
    String? userId,
    String? driverId,
    String? status,
    String? pickupLocation,
    String? dropoffLocation,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    int? duration,
    double? totalPrice,
    DateTime? bookingDate,
    Map<String, dynamic>? additionalDetails,
    DateTime? createdAt,
    UserModel? client,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropoffLatitude: dropoffLatitude ?? this.dropoffLatitude,
      dropoffLongitude: dropoffLongitude ?? this.dropoffLongitude,
      duration: duration ?? this.duration,
      totalPrice: totalPrice ?? this.totalPrice,
      bookingDate: bookingDate ?? this.bookingDate,
      additionalDetails: additionalDetails ?? this.additionalDetails,
      createdAt: createdAt ?? this.createdAt,
      client: client ?? this.client,
    );
  }
}
