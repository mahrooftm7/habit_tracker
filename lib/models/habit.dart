import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum HabitCategory {
  health('Health', Icons.favorite_rounded, Color(0xFFE57373)),
  fitness('Fitness', Icons.fitness_center_rounded, Color(0xFFFF8A65)),
  productivity('Productivity', Icons.bolt_rounded, Color(0xFFFFB74D)),
  mindfulness('Mindfulness', Icons.spa_rounded, Color(0xFF81C784)),
  learning('Learning', Icons.menu_book_rounded, Color(0xFF64B5F6)),
  lifestyle('Lifestyle', Icons.star_rounded, Color(0xFFBA68C8));

  final String label;
  final IconData icon;
  final Color defaultColor;

  const HabitCategory(this.label, this.icon, this.defaultColor);

  static HabitCategory fromString(String label) {
    return HabitCategory.values.firstWhere(
      (cat) => cat.label.toLowerCase() == label.toLowerCase(),
      orElse: () => HabitCategory.lifestyle,
    );
  }
}

class Habit {
  final String id;
  final String title;
  final String description;
  final String category;
  final int colorValue;
  final int iconCodePoint;
  final List<int> frequencyDays; // 1 = Mon, 7 = Sun. Empty means daily.
  final int targetPerDay;
  final Set<String> completedDates; // Format: yyyy-MM-dd
  final Map<String, String> notes; // Format: yyyy-MM-dd -> Note string
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Lifestyle',
    required this.colorValue,
    required this.iconCodePoint,
    this.frequencyDays = const [1, 2, 3, 4, 5, 6, 7],
    this.targetPerDay = 1,
    Set<String>? completedDates,
    Map<String, String>? notes,
    DateTime? createdAt,
  })  : completedDates = completedDates ?? <String>{},
        notes = notes ?? <String, String>{},
        createdAt = createdAt ?? DateTime.now();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  static String formatDate(DateTime date) => _dateFormat.format(date);

  Color get color => Color(colorValue);
  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  bool isCompletedOn(DateTime date) {
    return completedDates.contains(formatDate(date));
  }

  bool hasNoteOn(DateTime date) {
    final key = formatDate(date);
    return notes.containsKey(key) && notes[key]!.trim().isNotEmpty;
  }

  String? getNoteFor(DateTime date) {
    final key = formatDate(date);
    return notes[key];
  }

  bool isScheduledFor(DateTime date) {
    if (frequencyDays.isEmpty) return true;
    return frequencyDays.contains(date.weekday);
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    int? colorValue,
    int? iconCodePoint,
    List<int>? frequencyDays,
    int? targetPerDay,
    Set<String>? completedDates,
    Map<String, String>? notes,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      targetPerDay: targetPerDay ?? this.targetPerDay,
      completedDates: completedDates != null ? Set<String>.from(completedDates) : Set<String>.from(this.completedDates),
      notes: notes != null ? Map<String, String>.from(notes) : Map<String, String>.from(this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  int get currentStreak {
    if (completedDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = formatDate(today);

    // Check if completed today or yesterday
    var checkDate = today;
    if (!completedDates.contains(todayStr)) {
      // If not completed today, maybe streak is alive from yesterday
      checkDate = today.subtract(const Duration(days: 1));
      if (!completedDates.contains(formatDate(checkDate))) {
        return 0;
      }
    }

    int streak = 0;
    while (true) {
      final dateStr = formatDate(checkDate);
      if (completedDates.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  int get longestStreak {
    if (completedDates.isEmpty) return 0;

    final sortedDates = completedDates.map((d) => DateTime.parse(d)).toList()
      ..sort((a, b) => a.compareTo(b));

    int maxStreak = 0;
    int currentRun = 0;
    DateTime? prevDate;

    for (final date in sortedDates) {
      if (prevDate == null) {
        currentRun = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          currentRun++;
        } else if (diff > 1) {
          currentRun = 1;
        }
      }
      if (currentRun > maxStreak) {
        maxStreak = currentRun;
      }
      prevDate = date;
    }

    return maxStreak;
  }

  double get completionRateLast30Days {
    final now = DateTime.now();
    int scheduledCount = 0;
    int completedCount = 0;

    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      if (isScheduledFor(d)) {
        scheduledCount++;
        if (isCompletedOn(d)) {
          completedCount++;
        }
      }
    }

    if (scheduledCount == 0) return 0.0;
    return (completedCount / scheduledCount).clamp(0.0, 1.0);
  }

  int get totalCompletions => completedDates.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'frequencyDays': frequencyDays,
      'targetPerDay': targetPerDay,
      'completedDates': completedDates.toList(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    Map<String, String> parsedNotes = {};
    if (json['notes'] != null) {
      final rawNotes = json['notes'] as Map<String, dynamic>;
      parsedNotes = rawNotes.map((key, value) => MapEntry(key, value.toString()));
    }
    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Lifestyle',
      colorValue: json['colorValue'] as int? ?? 0xFF6366F1,
      iconCodePoint: json['iconCodePoint'] as int? ?? Icons.star_rounded.codePoint,
      frequencyDays: (json['frequencyDays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [1, 2, 3, 4, 5, 6, 7],
      targetPerDay: json['targetPerDay'] as int? ?? 1,
      completedDates: (json['completedDates'] as List<dynamic>?)?.map((e) => e as String).toSet() ?? <String>{},
      notes: parsedNotes,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    );
  }
}
