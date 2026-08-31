import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

class AuthService {
  static const String _usersKey = 'auth_users_v1';
  static const String _currentUserIdKey = 'auth_current_user_id_v1';
  static const Uuid _uuid = Uuid();

  Future<List<AppUser>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_usersKey);

    if (usersJson == null || usersJson.isEmpty) {
      final defaultUsers = _getInitialSeedUsers();
      await _saveUsers(defaultUsers);
      // Default to first user on initial launch
      await prefs.setString(_currentUserIdKey, defaultUsers.first.id);
      return defaultUsers;
    }

    try {
      final List<dynamic> decoded = jsonDecode(usersJson) as List<dynamic>;
      return decoded.map((item) => AppUser.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error decoding users: $e');
      final defaultUsers = _getInitialSeedUsers();
      await _saveUsers(defaultUsers);
      return defaultUsers;
    }
  }

  Future<void> _saveUsers(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(users.map((u) => u.toJson()).toList());
    await prefs.setString(_usersKey, encoded);
  }

  Future<AppUser?> getCurrentUser() async {
    final users = await getAllUsers();
    final prefs = await SharedPreferences.getInstance();
    final currentId = prefs.getString(_currentUserIdKey);

    if (currentId == null || currentId.isEmpty) {
      return null;
    }

    try {
      return users.firstWhere((u) => u.id == currentId);
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> login(String email, String password) async {
    final users = await getAllUsers();
    final normalizedEmail = email.trim().toLowerCase();

    final user = users.cast<AppUser?>().firstWhere(
      (u) => u?.email.toLowerCase() == normalizedEmail,
      orElse: () => null,
    );

    if (user == null) {
      throw Exception('No account found with this email address.');
    }

    if (user.isDisabled) {
      throw Exception('Your account has been disabled by the Super Admin. Please contact support.');
    }

    if (user.password.isNotEmpty && user.password != password) {
      throw Exception('Incorrect password. Please try again.');
    }

    final updatedUser = user.copyWith(lastLoginAt: DateTime.now());
    final index = users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      users[index] = updatedUser;
      await _saveUsers(users);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, updatedUser.id);
    return updatedUser;
  }

  Future<AppUser> register(String name, String email, String password, {String phone = ''}) async {
    final users = await getAllUsers();
    final normalizedEmail = email.trim().toLowerCase();

    final exists = users.any((u) => u.email.toLowerCase() == normalizedEmail);
    if (exists) {
      throw Exception('An account with this email already exists.');
    }

    const availableColors = [
      0xFF6366F1, // Indigo
      0xFFEC4899, // Pink
      0xFF10B981, // Emerald
      0xFFF59E0B, // Amber
      0xFF3B82F6, // Blue
      0xFF8B5CF6, // Purple
      0xFF14B8A6, // Teal
      0xFFF43F5E, // Rose
    ];
    final color = availableColors[users.length % availableColors.length];

    final now = DateTime.now();
    final newUser = AppUser(
      id: _uuid.v4(),
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      password: password,
      avatarColor: color,
      role: 'user',
      status: 'active',
      lastLoginAt: now,
      createdAt: now,
    );

    users.add(newUser);
    await _saveUsers(users);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, newUser.id);
    return newUser;
  }

  Future<void> switchUser(String userId) async {
    final users = await getAllUsers();
    final user = users.cast<AppUser?>().firstWhere((u) => u?.id == userId, orElse: () => null);
    if (user != null && user.isDisabled) {
      throw Exception('This account is disabled by the Super Admin.');
    }
    if (user != null) {
      final index = users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        users[index] = user.copyWith(lastLoginAt: DateTime.now());
        await _saveUsers(users);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, userId);
  }

  Future<List<AppUser>> updateUserStatus(String userId, String newStatus) async {
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      users[index] = users[index].copyWith(status: newStatus);
      await _saveUsers(users);
    }
    return users;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
  }

  List<AppUser> _getInitialSeedUsers() {
    final now = DateTime.now();
    return [
      AppUser(
        id: 'user_admin_001',
        name: 'Super Admin (Owner)',
        email: 'admin@habittracker.com',
        phone: '+1 555-0199',
        password: 'admin123',
        avatarColor: 0xFF8B5CF6,
        role: 'admin',
        status: 'active',
        lastLoginAt: now,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      AppUser(
        id: 'user_alex_101',
        name: 'Alex Morgan',
        email: 'alex@example.com',
        phone: '+1 555-0144',
        password: 'password123',
        avatarColor: 0xFF6366F1,
        role: 'user',
        status: 'active',
        lastLoginAt: now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(days: 30)),
      ),
      AppUser(
        id: 'user_sarah_102',
        name: 'Sarah Chen',
        email: 'sarah@example.com',
        phone: '+1 555-0188',
        password: 'password123',
        avatarColor: 0xFFEC4899,
        role: 'user',
        status: 'active',
        lastLoginAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 15)),
      ),
    ];
  }
}
