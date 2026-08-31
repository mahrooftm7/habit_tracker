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
    if (userId == null || userId.isEmpty) {
      return 'user_habits_v1';
    }
    return '$_defaultHabitsKeyPrefix$userId';
  }

  Future<List<Habit>> loadHabits({String? userId}) async {
    final targetUserId = userId ?? 'user_alex_101';
    final cloudHabits = await SupabaseService.instance.fetchHabits(targetUserId);
    if (cloudHabits != null && cloudHabits.isNotEmpty) {
      await saveHabits(cloudHabits, userId: targetUserId, syncToCloud: false);
      return cloudHabits;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(userId);
    final String? habitsJson = prefs.getString(key);

    if (habitsJson == null || habitsJson.isEmpty) {
      final defaultHabits = _getInitialSeedHabitsForUser(userId);
      await saveHabits(defaultHabits, userId: userId);
      return defaultHabits;
    }

    try {
      final List<dynamic> decoded = jsonDecode(habitsJson) as List<dynamic>;
      return decoded.map((item) => Habit.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error decoding habits for $userId: $e');
      final defaultHabits = _getInitialSeedHabitsForUser(userId);
      await saveHabits(defaultHabits, userId: userId);
      return defaultHabits;
    }
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
    final habits = await loadHabits(userId: userId);
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

      habits[index] = habit.copyWith(completedDates: updatedDates);
      await saveHabits(habits, userId: userId);
    }
    return habits;
  }

  Future<List<Habit>> saveHabitNote(String habitId, DateTime date, String note, {String? userId}) async {
    final habits = await loadHabits(userId: userId);
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

      habits[index] = habit.copyWith(notes: updatedNotes);
      await saveHabits(habits, userId: userId);
    }
    return habits;
  }

  List<Habit> _getInitialSeedHabitsForUser(String? userId) {
    final now = DateTime.now();
    String daysAgo(int d) => Habit.formatDate(now.subtract(Duration(days: d)));

    if (userId == 'user_sarah_102') {
      return [
        Habit(
          id: _uuid.v4(),
          title: 'Morning Yoga',
          description: '15 min gentle flow & stretching',
          category: 'Fitness',
          colorValue: 0xFFEC4899, // Pink
          iconCodePoint: Icons.self_improvement_rounded.codePoint,
          frequencyDays: [1, 2, 3, 4, 5, 6, 7],
          completedDates: {daysAgo(0), daysAgo(1), daysAgo(2), daysAgo(4)},
          notes: {
            daysAgo(0): 'Felt super energetic after sun salutations!',
            daysAgo(1): 'Focused on deep hip stretches.',
          },
          createdAt: now.subtract(const Duration(days: 10)),
        ),
        Habit(
          id: _uuid.v4(),
          title: 'Daily Journaling',
          description: 'Gratitude reflection & daily highlights',
          category: 'Mindfulness',
          colorValue: 0xFF8B5CF6, // Purple
          iconCodePoint: Icons.edit_note_rounded.codePoint,
          frequencyDays: [1, 2, 3, 4, 5, 6, 7],
          completedDates: {daysAgo(0), daysAgo(1), daysAgo(3)},
          notes: {
            daysAgo(0): 'Wrote down 3 things I am grateful for today.',
          },
          createdAt: now.subtract(const Duration(days: 12)),
        ),
        Habit(
          id: _uuid.v4(),
          title: 'Duolingo French',
          description: 'Complete 2 lessons daily',
          category: 'Learning',
          colorValue: 0xFF10B981, // Green
          iconCodePoint: Icons.language_rounded.codePoint,
          frequencyDays: [1, 2, 3, 4, 5],
          completedDates: {daysAgo(1), daysAgo(2)},
          notes: {
            daysAgo(1): 'Mastered French greetings unit!',
          },
          createdAt: now.subtract(const Duration(days: 8)),
        ),
      ];
    }

    return [
      Habit(
        id: _uuid.v4(),
        title: 'Morning Meditation',
        description: '10 minutes of mindfulness and calm breathing',
        category: 'Mindfulness',
        colorValue: 0xFF10B981, // Emerald green
        iconCodePoint: Icons.self_improvement_rounded.codePoint,
        frequencyDays: [1, 2, 3, 4, 5, 6, 7],
        completedDates: {daysAgo(0), daysAgo(1), daysAgo(2), daysAgo(3), daysAgo(5)},
        notes: {
          daysAgo(0): 'Felt peaceful and calm after 10 mins of breathwork.',
          daysAgo(1): 'Tried box breathing technique today.',
        },
        createdAt: now.subtract(const Duration(days: 14)),
      ),
      Habit(
        id: _uuid.v4(),
        title: 'Drink 2.5L Water',
        description: 'Stay hydrated throughout the day',
        category: 'Health',
        colorValue: 0xFF06B6D4, // Cyan
        iconCodePoint: Icons.water_drop_rounded.codePoint,
        frequencyDays: [1, 2, 3, 4, 5, 6, 7],
        completedDates: {daysAgo(0), daysAgo(1), daysAgo(2), daysAgo(4), daysAgo(6)},
        notes: {
          daysAgo(0): 'Drank 3 full bottles before 6 PM!',
        },
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      Habit(
        id: _uuid.v4(),
        title: 'Read 20 Pages',
        description: 'Non-fiction books or technical literature',
        category: 'Learning',
        colorValue: 0xFF6366F1, // Indigo
        iconCodePoint: Icons.menu_book_rounded.codePoint,
        frequencyDays: [1, 2, 3, 4, 5, 6, 7],
        completedDates: {daysAgo(1), daysAgo(2), daysAgo(3), daysAgo(4)},
        notes: {
          daysAgo(1): 'Finished Chapter 4 on Habit Loops in Atomic Habits.',
        },
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      Habit(
        id: _uuid.v4(),
        title: 'Evening Workout',
        description: 'Gym, calisthenics or cardio session',
        category: 'Fitness',
        colorValue: 0xFFF43F5E, // Rose / Coral
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
        frequencyDays: [1, 2, 3, 4, 5],
        completedDates: {daysAgo(1), daysAgo(3), daysAgo(4)},
        notes: {
          daysAgo(1): 'Leg day! 4 sets squats & lunges.',
        },
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ];
  }
}
