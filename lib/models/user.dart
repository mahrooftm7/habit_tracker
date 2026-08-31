import 'package:flutter/material.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final int avatarColor;
  final String role; // 'user' or 'admin'
  final String status; // 'active' or 'disabled'
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.password,
    this.avatarColor = 0xFF6366F1,
    this.role = 'user',
    this.status = 'active',
    this.lastLoginAt,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isDisabled => status == 'disabled';

  Color get color => Color(avatarColor);

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'avatarColor': avatarColor,
      'role': role,
      'status': status,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatarColor: json['avatarColor'] as int? ?? 0xFF6366F1,
      role: json['role'] as String? ?? 'user',
      status: json['status'] as String? ?? 'active',
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.parse(json['lastLoginAt'] as String) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? password,
    int? avatarColor,
    String? role,
    String? status,
    DateTime? lastLoginAt,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      avatarColor: avatarColor ?? this.avatarColor,
      role: role ?? this.role,
      status: status ?? this.status,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
