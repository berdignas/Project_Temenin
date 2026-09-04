// Path: models\user_model.dart
import 'package:temenin_ajaa/core/constants/api_constants.dart';

class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final int balance;
  final int points;
  final bool isVerified;
  final String? role;
  final DateTime? createdAt;
  final Map<String, dynamic>? stats;
  final String? nik;
  final String? address;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.balance = 0,
    this.points = 0,
    this.isVerified = false,
    this.role,
    this.createdAt,
    this.stats, 
    this.nik,
    this.address,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'],
      phone: json['phone'],
      avatarUrl: (json['avatar_url'] != null && json['avatar_url'].toString().startsWith('/'))
          ? '${ApiConstants.baseUrl}${json['avatar_url']}'
          : json['avatar_url'],
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] ?? false,
      role: json['role'] as String? ?? 'user',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null, 
      stats: json['stats'] != null
          ? {
              'totalBookings': json['stats']['total_bookings'] ?? json['stats']['totalBookings'] ?? 0,
              'ongoingBookings': json['stats']['ongoing_bookings'] ?? json['stats']['ongoingBookings'] ?? 0,
              'completedBookings': json['stats']['completed_bookings'] ?? json['stats']['completedBookings'] ?? 0,
            }
          : {
              'totalBookings': 0,
              'ongoingBookings': 0,
              'completedBookings': 0,
            },
      nik: json['nik'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'balance': balance,
      'points': points,
      'is_verified': isVerified,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
      'stats': stats, 
      'nik': nik,
      'address': address,
    };
  }
UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    int? balance,
    int? points,
    bool? isVerified,
    String? role,
    DateTime? createdAt,
    Map<String, dynamic>? stats,
    String? nik,
    String? address,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      balance: balance ?? this.balance,
      points: points ?? this.points,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      stats: stats ?? this.stats, 
      nik: nik ?? this.nik,
      address: address ?? this.address,
    );
  }
}