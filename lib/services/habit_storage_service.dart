import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/habit.dart';
import 'supabase_service.dart';

class HabitStorageService {
  static const String _defaultHabitsKeyPrefix = 'user_habits_';
  static const Uuid _uuid = Uuid();

  String _getKey(String? userId) {
    final uid = (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101';
    return '$_defaultHabitsKeyPrefix$uid';
  }

  Future<List<Habit>> loadHabits({String? userId}) async {
    final targetUserId = userId ?? 'user_alex_101';
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(userId);

    List<Habit> localHabits = [];
    final String? habitsJson = prefs.getString(key);
    if (habitsJson != null && habitsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(habitsJson) as List<dynamic>;
        localHabits = decoded.map((item) => Habit.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error decoding habits for $userId: $e');
        localHabits = _getInitialSeedHabitsForUser(userId);
      }
    } else {
      localHabits = _getInitialSeedHabitsForUser(userId);
    }

    final cloudHabits = await SupabaseService.instance.fetchHabits(targetUserId);

    if (cloudHabits != null) {
      final Map<String, Habit> habitMap = {for (var h in localHabits) h.id: h};
      for (var ch in cloudHabits) {
        habitMap[ch.id] = ch;
      }
      final mergedList = habitMap.values.toList();
      for (var h in localHabits) {
        if (!cloudHabits.any((ch) => ch.id == h.id)) {
          SupabaseService.instance.upsertHabit(h, targetUserId);
        }
      }
      final String encoded = jsonEncode(mergedList.map((h) => h.toJson()).toList());
      await prefs.setString(key, encoded);
      return mergedList;
    }

    return localHabits;
  }

  Future<void> saveHabits(List<Habit> habits, {String? userId, bool syncToCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(userId);
    final String encoded = jsonEncode(habits.map((h) => h.toJson()).toList());
    await prefs.setString(key, encoded);

    if (syncToCloud) {
      final targetUserId = userId ?? 'user_alex_101';
      for (final h in habits) {
        SupabaseService.instance.upsertHabit(h, targetUserId);
      }
    }
  }

  Future<List<Habit>> addHabit(Habit habit, {String? userId}) async {
    final habits = await loadHabits(userId: userId);
    habits.insert(0, habit);
    await saveHabits(habits, userId: userId);
    return habits;
  }

  Future<List<Habit>> updateHabit(Habit habit, {String? userId}) async {
    final habits = await loadHabits(userId: userId);
    final index = habits.indexWhere((h) => h.id == habit.id);
    if (index != -1) {
      habits[index] = habit;
      await saveHabits(habits, userId: userId);
    }
    return habits;
  }

  Future<List<Habit>> deleteHabit(String habitId, {String? userId}) async {
    final habits = await loadHabits(userId: userId);
    habits.removeWhere((h) => h.id == habitId);
    await saveHabits(habits, userId: userId);
    SupabaseService.instance.deleteHabit(habitId);
    return habits;
  }

  Future<List<Habit>> toggleHabitCompletion(String habitId, DateTime date, {String? userId}) async {
    final targetUserId = userId ?? 'user_alex_101';
    final habits = await loadHabits(userId: targetUserId);
    final index = habits.indexWhere((h) => h.id == habitId);
    if (index != -1) {
      final habit = habits[index];
      final dateStr = Habit.formatDate(date);
      final updatedDates = Set<String>.from(habit.completedDates);

      if (updatedDates.contains(dateStr)) {
        updatedDates.remove(dateStr);
      } else {
        updatedDates.add(dateStr);
      }

      final updatedHabit = habit.copyWith(completedDates: updatedDates);
      habits[index] = updatedHabit;
      await saveHabits(habits, userId: targetUserId, syncToCloud: true);
      await SupabaseService.instance.upsertHabit(updatedHabit, targetUserId);
    }
    return habits;
  }

  Future<List<Habit>> saveHabitNote(String habitId, DateTime date, String note, {String? userId}) async {
    final targetUserId = userId ?? 'user_alex_101';
    final habits = await loadHabits(userId: targetUserId);
    final index = habits.indexWhere((h) => h.id == habitId);
    if (index != -1) {
      final habit = habits[index];
      final dateStr = Habit.formatDate(date);
      final updatedNotes = Map<String, String>.from(habit.notes);

      if (note.trim().isEmpty) {
        updatedNotes.remove(dateStr);
      } else {
        updatedNotes[dateStr] = note.trim();
      }

      final updatedHabit = habit.copyWith(notes: updatedNotes);
      habits[index] = updatedHabit;
      await saveHabits(habits, userId: targetUserId, syncToCloud: true);
      await SupabaseService.instance.upsertHabit(updatedHabit, targetUserId);
    }
    return habits;
  }

  List<Habit> _getInitialSeedHabitsForUser(String? userId) {
    return [];
  }
}
