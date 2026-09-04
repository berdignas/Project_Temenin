// lib/data/models/booking_model.dart
class BookingModel {
  final String id;
  final String userId;
  final String? driverId;
  final String status;
  final String? pickupLocation;
  final String? dropoffLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final int? duration;
  final int? totalPrice;
  final DateTime? bookingDate;
  final DateTime? createdAt;
  final DriverModel? driver;

  BookingModel({
    required this.id,
    required this.userId,
    this.driverId,
    required this.status,
    this.pickupLocation,
    this.dropoffLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.duration,
    this.totalPrice,
    this.bookingDate,
    this.createdAt,
    this.driver,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      driverId: json['driver_id'],
      status: json['status'] ?? 'pending',
      pickupLocation: json['pickup_location'],
      dropoffLocation: json['dropoff_location'],
      pickupLatitude: json['pickup_latitude']?.toDouble(),
      pickupLongitude: json['pickup_longitude']?.toDouble(),
      dropoffLatitude: json['dropoff_latitude']?.toDouble(),
      dropoffLongitude: json['dropoff_longitude']?.toDouble(),
      duration: (json['duration'] as num?)?.toInt(),
      totalPrice: (json['total_price'] as num?)?.toInt(),
      bookingDate: json['booking_date'] != null 
          ? DateTime.parse(json['booking_date']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      driver: json['driver'] != null 
          ? DriverModel.fromJson(json['driver']) 
          : null,
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
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class DriverModel {
  final String? id;
  final String? vehicleName;
  final String? vehicleType;
  final String? plateNumber;
  final int? pricePerHour;
  final double? rating;

  DriverModel({
    this.id,
    this.vehicleName,
    this.vehicleType,
    this.plateNumber,
    this.pricePerHour,
    this.rating,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'],
      vehicleName: json['vehicle_name'],
      vehicleType: json['vehicle_type'],
      plateNumber: json['plate_number'],
      pricePerHour: (json['price_per_hour'] as num?)?.toInt(),
      rating: json['rating']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_name': vehicleName,
      'vehicle_type': vehicleType,
      'plate_number': plateNumber,
      'price_per_hour': pricePerHour,
      'rating': rating,
    };
  }
}