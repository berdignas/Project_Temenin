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
  final Map<String, dynamic>? additionalDetails;

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
    this.additionalDetails,
  });

  bool get isPaid {
    final s = status.toLowerCase();
    final sub = additionalDetails?['sub_status']?.toString().toLowerCase();
    return s == 'paid' || 
           s == 'completed' || 
           sub == 'paid' || 
           sub == 'completed' ||
           additionalDetails?['final_paid'] == true ||
           additionalDetails?['pelunasan_paid'] == true ||
           additionalDetails?['payment_status'] == 'LUNAS';
  }

  bool get isCompleted {
    final s = status.toLowerCase();
    final sub = additionalDetails?['sub_status']?.toString().toLowerCase();
    return s == 'completed' || 
           s == 'paid' || 
           s == 'selesai' ||
           s == 'closed' ||
           sub == 'completed' || 
           sub == 'paid' || 
           sub == 'selesai' ||
           sub == 'closed' ||
           additionalDetails?['pelunasan_paid'] == true ||
           additionalDetails?['final_paid'] == true ||
           additionalDetails?['has_reviewed'] == true ||
           additionalDetails?['review'] != null ||
           additionalDetails?['payment_status'] == 'LUNAS';
  }

  bool get isCancelled {
    final s = status.toLowerCase();
    final sub = additionalDetails?['sub_status']?.toString().toLowerCase();
    return s == 'cancelled' || s == 'canceled' || sub == 'cancelled' || sub == 'canceled';
  }

  int get downPayment {
    if (additionalDetails?['dp'] is num) {
      return (additionalDetails!['dp'] as num).toInt();
    }
    if (additionalDetails?['down_payment'] is num) {
      return (additionalDetails!['down_payment'] as num).toInt();
    }
    return totalPrice != null ? (totalPrice! * 0.5).toInt() : 0;
  }

  int get remainingPayment {
    if (additionalDetails?['remainingPayment'] is num) {
      return (additionalDetails!['remainingPayment'] as num).toInt();
    }
    if (totalPrice != null) {
      return totalPrice! - downPayment;
    }
    return 0;
  }

  double? get reviewRating {
    final r = additionalDetails?['rating'] ?? additionalDetails?['review']?['rating'];
    if (r is num) return r.toDouble();
    if (r != null) return double.tryParse(r.toString());
    return null;
  }

  String? get reviewComment {
    return additionalDetails?['comment']?.toString() ?? additionalDetails?['review']?['comment']?.toString();
  }

  double? get driverRatingClient {
    final r = additionalDetails?['driver_rating_client'] ?? additionalDetails?['client_review']?['rating'];
    if (r is num) return r.toDouble();
    if (r != null) return double.tryParse(r.toString());
    return null;
  }

  String? get driverCommentClient {
    return additionalDetails?['driver_comment_client']?.toString() ?? additionalDetails?['client_review']?['comment']?.toString();
  }

  bool get isVirtual {
    if (additionalDetails?['service_category'] == 'VIRTUAL' || 
        additionalDetails?['is_virtual'] == true || 
        callType != null) {
      return true;
    }
    final sType = (additionalDetails?['service_type'] ?? 
                   additionalDetails?['serviceType'] ?? 
                   driver?.vehicleType ?? '').toString().toLowerCase();
    return sType.contains('gaming') ||
           sType.contains('mabar') ||
           sType.contains('sleep') ||
           sType.contains('telepon') ||
           sType.contains('curhat') ||
           sType.contains('counseling') ||
           sType.contains('virtual');
  }

  String? get serviceCategory => 
      additionalDetails?['service_category']?.toString() ?? (isVirtual ? 'VIRTUAL' : 'PHYSICAL');

  String? get callType => 
      additionalDetails?['call_type']?.toString() ?? additionalDetails?['callType']?.toString();

  DateTime? get wakeUpTime {
    final raw = additionalDetails?['wake_up_time'] ?? additionalDetails?['wakeUpTime'];
    if (raw != null) return DateTime.tryParse(raw.toString());
    return null;
  }

  String? get wakeUpMethod => 
      additionalDetails?['wake_up_method']?.toString() ?? additionalDetails?['wakeUpMethod']?.toString();

  String? get chatTopic => 
      additionalDetails?['chat_topic']?.toString() ?? additionalDetails?['chatTopic']?.toString();

  int? get callDurationMinutes => 
      (additionalDetails?['call_duration_minutes'] as num?)?.toInt() ?? duration;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['additional_details'] is Map 
        ? Map<String, dynamic>.from(json['additional_details']) 
        : (json['additionalDetails'] is Map ? Map<String, dynamic>.from(json['additionalDetails']) : null);

    // Parse driver from drivers (*, users(*)), driver, or fallback to additional_details
    DriverModel? parsedDriver;
    final rawDriver = json['driver'] ?? json['drivers'];
    if (rawDriver is Map) {
      parsedDriver = DriverModel.fromJson(Map<String, dynamic>.from(rawDriver));
    } else if (rawDriver is List && rawDriver.isNotEmpty && rawDriver[0] is Map) {
      parsedDriver = DriverModel.fromJson(Map<String, dynamic>.from(rawDriver[0]));
    } else if (rawDetails != null && (rawDetails['driverName'] != null || rawDetails['partnerName'] != null || rawDetails['driverId'] != null)) {
      parsedDriver = DriverModel(
        id: rawDetails['driverId']?.toString() ?? rawDetails['driver_id']?.toString(),
        fullName: rawDetails['driverName']?.toString() ?? rawDetails['partnerName']?.toString(),
        avatarUrl: rawDetails['driverImage']?.toString(),
        vehicleName: rawDetails['vehicle']?.toString() ?? rawDetails['vehicle_name']?.toString() ?? rawDetails['driverName']?.toString(),
        vehicleType: rawDetails['serviceType']?.toString() ?? rawDetails['vehicle_type']?.toString(),
        plateNumber: rawDetails['plateNumber']?.toString(),
        rating: (rawDetails['driverRating'] as num?)?.toDouble() ?? (rawDetails['rating'] as num?)?.toDouble() ?? 0.0,
      );
    }

    final rawStatus = (json['status'] ?? rawDetails?['status'] ?? 'pending').toString();
    final subStatus = rawDetails?['sub_status']?.toString();
    final sLower = rawStatus.toLowerCase();
    final subLower = subStatus?.toLowerCase();
    final isDone = sLower == 'completed' || 
                   sLower == 'paid' || 
                   sLower == 'selesai' ||
                   sLower == 'closed' ||
                   subLower == 'completed' || 
                   subLower == 'paid' || 
                   subLower == 'selesai' ||
                   subLower == 'closed' ||
                   rawDetails?['pelunasan_paid'] == true ||
                   rawDetails?['final_paid'] == true ||
                   rawDetails?['has_reviewed'] == true ||
                   rawDetails?['review'] != null ||
                   rawDetails?['payment_status'] == 'LUNAS';
    final resolvedStatus = isDone ? 'completed' : (subStatus != null && subStatus.isNotEmpty ? subStatus : rawStatus);

    return BookingModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? rawDetails?['driverId']?.toString(),
      status: resolvedStatus,
      pickupLocation: json['pickup_location']?.toString() ?? rawDetails?['pickup']?.toString() ?? rawDetails?['location']?.toString(),
      dropoffLocation: json['dropoff_location']?.toString() ?? rawDetails?['destination']?.toString() ?? rawDetails?['location']?.toString(),
      pickupLatitude: json['pickup_latitude'] != null ? (json['pickup_latitude'] as num).toDouble() : null,
      pickupLongitude: json['pickup_longitude'] != null ? (json['pickup_longitude'] as num).toDouble() : null,
      dropoffLatitude: json['dropoff_latitude'] != null ? (json['dropoff_latitude'] as num).toDouble() : null,
      dropoffLongitude: json['dropoff_longitude'] != null ? (json['dropoff_longitude'] as num).toDouble() : null,
      duration: (json['duration'] as num?)?.toInt() ?? (rawDetails?['duration'] as num?)?.toInt(),
      totalPrice: (json['total_price'] as num?)?.toInt() ?? 
                  (rawDetails?['totalPayment'] as num?)?.toInt() ?? 
                  (rawDetails?['total_price'] as num?)?.toInt() ??
                  (rawDetails?['baseCost'] as num?)?.toInt(),
      bookingDate: json['booking_date'] != null 
          ? DateTime.tryParse(json['booking_date'].toString()) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
      driver: parsedDriver,
      additionalDetails: rawDetails,
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
      'additional_details': additionalDetails,
    };
  }
}

class DriverModel {
  final String? id;
  final String? fullName;
  final String? avatarUrl;
  final String? vehicleName;
  final String? vehicleType;
  final String? plateNumber;
  final int? pricePerHour;
  final double? rating;

  DriverModel({
    this.id,
    this.fullName,
    this.avatarUrl,
    this.vehicleName,
    this.vehicleType,
    this.plateNumber,
    this.pricePerHour,
    this.rating,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    final userObj = json['users'] is Map ? json['users'] : (json['user'] is Map ? json['user'] : null);
    final rawName = userObj?['full_name'] ?? json['full_name'] ?? json['name'] ?? json['driverName'] ?? json['partnerName'];
    final rawAvatar = userObj?['avatar_url'] ?? json['avatar_url'] ?? json['driverImage'];

    return DriverModel(
      id: json['id']?.toString(),
      fullName: rawName?.toString(),
      avatarUrl: rawAvatar?.toString(),
      vehicleName: json['vehicle_name']?.toString() ?? rawName?.toString(),
      vehicleType: json['vehicle_type']?.toString() ?? json['serviceType']?.toString() ?? 'Temenin Driver',
      plateNumber: json['plate_number']?.toString(),
      pricePerHour: (json['price_per_hour'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'vehicle_name': vehicleName,
      'vehicle_type': vehicleType,
      'plate_number': plateNumber,
      'price_per_hour': pricePerHour,
      'rating': rating,
    };
  }
}