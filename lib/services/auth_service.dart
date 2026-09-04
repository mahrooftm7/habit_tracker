import 'dart:async';
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

  Future<List<AppUser>> getAllUsers({bool includeCloudMerge = true}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Read ALL possible keys where users might have been stored in past versions
    final keys = [_usersKey, 'auth_users', 'users', 'registered_users'];
    final Map<String, AppUser> combinedMap = {};

    for (final key in keys) {
      final String? jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              final user = AppUser.fromJson(item);
              if (user.id.isNotEmpty && !combinedMap.containsKey(user.id)) {
                combinedMap[user.id] = user;
              }
            }
          }
        } catch (e) {
          debugPrint('Error decoding key $key: $e');
        }
      }
    }

    if (combinedMap.isEmpty) {
      for (var seed in _getInitialSeedUsers()) {
        combinedMap[seed.id] = seed;
      }
    }

    List<AppUser> localUsers = combinedMap.values.toList();
    await _saveUsers(localUsers);

    if (!includeCloudMerge) {
      return localUsers;
    }

    // Merge with Supabase Cloud Profiles (2-second timeout for instant responsiveness)
    localUsers = await _syncLocalWithCloud(localUsers);

    return localUsers;
  }

  Future<List<AppUser>> _syncLocalWithCloud(List<AppUser> localUsers) async {
    final Map<String, AppUser> mergedMap = {for (var u in localUsers) u.id: u};

    try {
      final cloudProfiles = await SupabaseService.instance.fetchAllUserProfiles();

      if (cloudProfiles != null && cloudProfiles.isNotEmpty) {
        for (var map in cloudProfiles) {
          final cloudUser = AppUser.fromSupabase(map);
          if (cloudUser.id.isNotEmpty) {
            final localUser = mergedMap[cloudUser.id];
            if (localUser != null && localUser.password.isNotEmpty && cloudUser.password.isEmpty) {
              mergedMap[cloudUser.id] = cloudUser.copyWith(password: localUser.password);
            } else {
              mergedMap[cloudUser.id] = cloudUser;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Cloud merge error: $e');
    }

    final resultList = mergedMap.values.toList();
    await _saveUsers(resultList);

    for (var user in resultList) {
      unawaited(SupabaseService.instance.syncUserProfile(user));
    }

    return resultList;
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
    final users = await getAllUsers(includeCloudMerge: false);
    final input = identifier.trim().toLowerCase();
    final cleanInputPhone = input.replaceAll(RegExp(r'\D'), '');

    if (input.isEmpty) {
      throw Exception('Please enter your email address or mobile number.');
    }

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

    // Check Supabase Cloud Profiles if not found in local storage
    if (user == null) {
      try {
        final cloudProfiles = await SupabaseService.instance.fetchAllUserProfiles();
        if (cloudProfiles != null && cloudProfiles.isNotEmpty) {
          for (var map in cloudProfiles) {
            final cloudUser = AppUser.fromSupabase(map);
            if (cloudUser.id.isNotEmpty) {
              if (cloudUser.email.toLowerCase() == input ||
                  (cloudUser.phone.isNotEmpty && cleanInputPhone.isNotEmpty &&
                      cloudUser.phone.replaceAll(RegExp(r'\D'), '') == cleanInputPhone)) {
                user = cloudUser;
                if (!users.any((u) => u.id == cloudUser.id)) {
                  users.add(cloudUser);
                  await _saveUsers(users);
                }
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Cloud profile lookup during login error: $e');
      }
    }

    // Auto-create user if account does not exist locally or in Supabase Cloud
    if (user == null) {
      return await register(
        input.contains('@') ? input.split('@').first : 'User',
        input.contains('@') ? input : '',
        password,
        phone: !input.contains('@') ? input : '',
      );
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

    // Sync user login to Supabase Cloud immediately
    try {
      await SupabaseService.instance.syncUserProfile(updatedUser);
    } catch (e) {
      debugPrint('Sync user profile error during login: $e');
    }

    return updatedUser;
  }

  String _generateUserId(String email, String phone) {
    final normEmail = email.trim().toLowerCase();
    if (normEmail.isNotEmpty) {
      final safeEmail = normEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      return 'user_$safeEmail';
    }
    final cleanPh = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (cleanPh.isNotEmpty) {
      return 'user_ph_$cleanPh';
    }
    return _uuid.v4();
  }

  Future<AppUser> register(String name, String email, String password, {required String phone}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedPhone = phone.trim();
    final cleanPhone = trimmedPhone.replaceAll(RegExp(r'\D'), '');

    if (normalizedEmail.isEmpty && cleanPhone.isEmpty) {
      throw Exception('Email address or mobile number is required.');
    }

    final users = await getAllUsers(includeCloudMerge: true);
    final now = DateTime.now();
    AppUser? existingUser;

    if (normalizedEmail.isNotEmpty) {
      final emailIdx = users.indexWhere((u) => u.email.toLowerCase() == normalizedEmail);
      if (emailIdx != -1) {
        existingUser = users[emailIdx];
      }
    }

    if (existingUser == null && cleanPhone.isNotEmpty) {
      final phoneIdx = users.indexWhere((u) {
        final uClean = u.phone.replaceAll(RegExp(r'\D'), '');
        return uClean.isNotEmpty && uClean == cleanPhone;
      });
      if (phoneIdx != -1) {
        existingUser = users[phoneIdx];
      }
    }

    // Double-check Supabase Cloud directly if not found locally
    if (existingUser == null) {
      try {
        final cloudProfiles = await SupabaseService.instance.fetchAllUserProfiles();
        if (cloudProfiles != null && cloudProfiles.isNotEmpty) {
          for (var map in cloudProfiles) {
            final cloudUser = AppUser.fromSupabase(map);
            if (cloudUser.id.isNotEmpty) {
              if ((normalizedEmail.isNotEmpty && cloudUser.email.toLowerCase() == normalizedEmail) ||
                  (cleanPhone.isNotEmpty && cloudUser.phone.replaceAll(RegExp(r'\D'), '') == cleanPhone)) {
                existingUser = cloudUser;
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Cloud profile check error during registration: $e');
      }
    }

    AppUser targetUser;
    if (existingUser != null) {
      targetUser = existingUser.copyWith(
        name: name.trim().isNotEmpty ? name.trim() : existingUser.name,
        email: normalizedEmail.isNotEmpty ? normalizedEmail : existingUser.email,
        phone: trimmedPhone.isNotEmpty ? trimmedPhone : existingUser.phone,
        password: password.isNotEmpty ? password : existingUser.password,
        status: 'active',
        lastLoginAt: now,
      );
      final idx = users.indexWhere((u) => u.id == existingUser!.id);
      if (idx != -1) {
        users[idx] = targetUser;
      } else {
        users.add(targetUser);
      }
    } else {
      const availableColors = [
        0xFF6366F1, 0xFFEC4899, 0xFF10B981, 0xFFF59E0B,
        0xFF3B82F6, 0xFF8B5CF6, 0xFF14B8A6, 0xFFF43F5E,
      ];
      final color = availableColors[users.length % availableColors.length];
      final deterministicId = _generateUserId(normalizedEmail, cleanPhone);

      targetUser = AppUser(
        id: deterministicId,
        name: name.trim().isNotEmpty ? name.trim() : 'User',
        email: normalizedEmail,
        phone: trimmedPhone,
        password: password,
        avatarColor: color,
        role: 'user',
        status: 'active',
        lastLoginAt: now,
        createdAt: now,
      );
      users.add(targetUser);
    }

    await _saveUsers(users);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, targetUser.id);

    // Sync new or updated user to Supabase Cloud immediately
    final synced = await SupabaseService.instance.syncUserProfile(targetUser);
    if (!synced) {
      debugPrint('Warning: Supabase profile sync returned false for ${targetUser.email}, retrying direct HTTP...');
    }

    return targetUser;
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
    ];
  }
}
