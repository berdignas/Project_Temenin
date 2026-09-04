class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? gender;
  final String role;
  final double balance;
  final int points;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.gender,
    required this.role,
    this.balance = 0.0,
    this.points = 0,
    this.avatarUrl,
    this.isVerified = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      phone: json['phone'],
      gender: json['gender'],
      role: json['role'] ?? 'driver',
      balance: (json['balance'] ?? 0.0).toDouble(),
      points: json['points'] ?? 0,
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'gender': gender,
      'role': role,
      'balance': balance,
      'points': points,
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? gender,
    String? role,
    double? balance,
    int? points,
    String? avatarUrl,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      balance: balance ?? this.balance,
      points: points ?? this.points,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
