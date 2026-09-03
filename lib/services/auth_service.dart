import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import 'supabase_service.dart';

class AuthService {
  static const String _usersKey = 'auth_users_v1';
  static const String _currentUserIdKey = 'auth_current_user_id_v1';
  static const Uuid _uuid = Uuid();

  Future<List<AppUser>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_usersKey) ??
        prefs.getString('auth_users') ??
        prefs.getString('users') ??
        prefs.getString('registered_users');

    List<AppUser> localUsers = [];

    if (usersJson != null && usersJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(usersJson) as List<dynamic>;
        localUsers = decoded.map((item) => AppUser.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error decoding users: $e');
        localUsers = _getInitialSeedUsers();
      }
    } else {
      localUsers = _getInitialSeedUsers();
    }

    // Merge with Supabase Cloud Profiles if available
    try {
      final cloudProfiles = await SupabaseService.instance.fetchAllUserProfiles();
      if (cloudProfiles != null && cloudProfiles.isNotEmpty) {
        final Map<String, AppUser> mergedMap = {for (var u in localUsers) u.id: u};
        final Map<String, String> emailToId = {
          for (var u in localUsers)
            if (u.email.isNotEmpty) u.email.toLowerCase(): u.id
        };

        for (var map in cloudProfiles) {
          final cloudUser = AppUser.fromSupabase(map);
          if (cloudUser.id.isNotEmpty) {
            String? existingId;
            if (mergedMap.containsKey(cloudUser.id)) {
              existingId = cloudUser.id;
            } else if (cloudUser.email.isNotEmpty && emailToId.containsKey(cloudUser.email.toLowerCase())) {
              existingId = emailToId[cloudUser.email.toLowerCase()];
            }

            if (existingId != null && mergedMap.containsKey(existingId)) {
              final existing = mergedMap[existingId]!;
              mergedMap[existingId] = existing.copyWith(
                name: cloudUser.name.isNotEmpty ? cloudUser.name : existing.name,
                email: cloudUser.email.isNotEmpty ? cloudUser.email : existing.email,
                phone: cloudUser.phone.isNotEmpty ? cloudUser.phone : existing.phone,
                role: cloudUser.role,
                status: cloudUser.status,
                lastLoginAt: cloudUser.lastLoginAt ?? existing.lastLoginAt,
                subscriptionExpiresAt: cloudUser.subscriptionExpiresAt ?? existing.subscriptionExpiresAt,
                paymentStatus: cloudUser.paymentStatus,
                paymentProofUrl: cloudUser.paymentProofUrl ?? existing.paymentProofUrl,
              );
            } else {
              mergedMap[cloudUser.id] = cloudUser;
              if (cloudUser.email.isNotEmpty) {
                emailToId[cloudUser.email.toLowerCase()] = cloudUser.id;
              }
            }
          }
        }
        localUsers = mergedMap.values.toList();
        await _saveUsers(localUsers);
      }
    } catch (e) {
      debugPrint('Error merging Supabase profiles: $e');
    }

    // Push all local users to Supabase Cloud so any user created before sync is uploaded
    for (var user in localUsers) {
      await SupabaseService.instance.syncUserProfile(user);
    }

    return localUsers;
  }

  Future<AppUser> submitPaymentProof(String userId, String proofDetails) async {
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == userId);
    if (index == -1) throw Exception('User not found.');

    final updated = users[index].copyWith(
      paymentStatus: 'pending',
      paymentProofUrl: proofDetails,
    );
    users[index] = updated;
    await _saveUsers(users);
    await SupabaseService.instance.syncUserProfile(updated);
    return updated;
  }

  Future<List<AppUser>> approveUserSubscription(String userId, {int validDays = 365}) async {
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final now = DateTime.now();
      final currentExpiry = users[index].subscriptionExpiresAt;
      final startFrom = (currentExpiry != null && currentExpiry.isAfter(now)) ? currentExpiry : now;
      final newExpiry = startFrom.add(Duration(days: validDays));

      final updated = users[index].copyWith(
        status: 'active',
        subscriptionExpiresAt: newExpiry,
        paymentStatus: 'approved',
      );
      users[index] = updated;
      await _saveUsers(users);
      await SupabaseService.instance.syncUserProfile(updated);
    }
    return users;
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

  Future<AppUser> login(String identifier, String password) async {
    final users = await getAllUsers();
    final input = identifier.trim().toLowerCase();
    final cleanInputPhone = input.replaceAll(RegExp(r'\D'), '');

    AppUser? user = users.cast<AppUser?>().firstWhere(
      (u) {
        if (u == null) return false;
        if (u.email.toLowerCase() == input) return true;
        if (u.phone.isNotEmpty) {
          final userPhone = u.phone.toLowerCase();
          if (userPhone == input) return true;
          final cleanUserPhone = userPhone.replaceAll(RegExp(r'\D'), '');
          if (cleanInputPhone.isNotEmpty && cleanUserPhone == cleanInputPhone) return true;
        }
        return false;
      },
      orElse: () => null,
    );

    // Fallback alias matching for Super Admin
    if (user == null && (input == 'admin@habittracking.com' || input == 'admin@habittracker.com' || input == 'admin@example.com')) {
      user = users.cast<AppUser?>().firstWhere(
        (u) => u?.id == 'user_admin_001',
        orElse: () => null,
      );
    }

    // Direct Cloud Fetch Fallback: If user is not found locally, fetch latest profiles directly from Supabase Cloud
    if (user == null) {
      try {
        final cloudProfiles = await SupabaseService.instance.fetchAllUserProfiles();
        if (cloudProfiles != null && cloudProfiles.isNotEmpty) {
          for (var map in cloudProfiles) {
            final cloudUser = AppUser.fromSupabase(map);
            if (cloudUser.id.isNotEmpty && !users.any((u) => u.id == cloudUser.id)) {
              users.add(cloudUser);
            }
          }
          await _saveUsers(users);
        }
      } catch (e) {
        debugPrint('Error fetching cloud profiles during login: $e');
      }

      user = users.cast<AppUser?>().firstWhere(
        (u) {
          if (u == null) return false;
          if (u.email.toLowerCase() == input) return true;
          if (u.phone.isNotEmpty) {
            final userPhone = u.phone.toLowerCase();
            if (userPhone == input) return true;
            final cleanUserPhone = userPhone.replaceAll(RegExp(r'\D'), '');
            if (cleanInputPhone.isNotEmpty && cleanUserPhone == cleanInputPhone) return true;
          }
          return false;
        },
        orElse: () => null,
      );
    }

    if (user == null) {
      throw Exception('No account found with this email address or mobile number.');
    }

    final targetUser = user;

    if (targetUser.isDisabled) {
      throw Exception('Your account has been disabled by the Super Admin. Please contact support.');
    }

    // Set/update password if profile was fetched from cloud or password match
    final updatedPassword = (targetUser.password.isEmpty && password.isNotEmpty) ? password : targetUser.password;
    if (updatedPassword.isNotEmpty && updatedPassword != password) {
      throw Exception('Incorrect password. Please try again.');
    }

    final updatedUser = targetUser.copyWith(
      password: password.isNotEmpty ? password : updatedPassword,
      lastLoginAt: DateTime.now(),
    );

    final index = users.indexWhere((u) => u.id == targetUser.id);
    if (index != -1) {
      users[index] = updatedUser;
      await _saveUsers(users);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, updatedUser.id);

    // Sync user login to Supabase Cloud
    await SupabaseService.instance.syncUserProfile(updatedUser);

    return updatedUser;
  }

  Future<AppUser> register(String name, String email, String password, {required String phone}) async {
    final users = await getAllUsers();
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedPhone = phone.trim();
    final cleanPhone = trimmedPhone.replaceAll(RegExp(r'\D'), '');

    if (trimmedPhone.isEmpty) {
      throw Exception('Mobile number is mandatory for registration.');
    }

    final exists = users.any((u) => u.email.toLowerCase() == normalizedEmail);
    if (exists) {
      try {
        return await login(normalizedEmail, password);
      } catch (_) {
        throw Exception('An account with this email address already exists. Please tap "Sign In" to log in.');
      }
    }

    if (cleanPhone.isNotEmpty) {
      final phoneExists = users.any((u) {
        final uClean = u.phone.replaceAll(RegExp(r'\D'), '');
        return uClean.isNotEmpty && uClean == cleanPhone;
      });
      if (phoneExists) {
        try {
          return await login(cleanPhone, password);
        } catch (_) {
          throw Exception('An account with this mobile number already exists. Please tap "Sign In" to log in.');
        }
      }
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

    // Sync new user to Supabase Cloud with retry loop
    bool synced = false;
    for (int attempt = 0; attempt < 3; attempt++) {
      synced = await SupabaseService.instance.syncUserProfile(newUser);
      if (synced) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (!synced) {
      debugPrint('Warning: Initial profile sync failed for ${newUser.email}, background timer will retry.');
    }

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
        email: 'admin@habittracking.com',
        phone: '+1 555-0199',
        password: 'admin123',
        avatarColor: 0xFF8B5CF6,
        role: 'admin',
        status: 'active',
        lastLoginAt: now,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      AppUser(
        id: 'user_rehan_001',
        name: 'Rehan',
        email: '1@tym.com',
        phone: '+91 98765 43210',
        password: 'password123',
        avatarColor: 0xFFF43F5E,
        role: 'user',
        status: 'active',
        lastLoginAt: now,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      AppUser(
        id: 'user_tym2_002',
        name: 'Tym User 2',
        email: '2@tym.com',
        phone: '+91 98765 43211',
        password: 'password123',
        avatarColor: 0xFF3B82F6,
        role: 'user',
        status: 'active',
        lastLoginAt: now,
        createdAt: now.subtract(const Duration(days: 4)),
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
      AppUser(
        id: 'user_tymat_103',
        name: 'Tymat User',
        email: 'tymat@gmail.com',
        phone: '',
        password: 'password123',
        avatarColor: 0xFF10B981,
        role: 'user',
        status: 'active',
        lastLoginAt: now,
        createdAt: now,
      ),
    ];
  }
}
