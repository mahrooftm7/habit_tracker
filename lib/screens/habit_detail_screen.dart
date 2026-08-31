import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../widgets/habit_form_dialog.dart';
import '../widgets/note_dialog.dart';

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;
  final Function(Habit) onUpdate;
  final Function(String) onDelete;
  final Function(DateTime) onToggleDate;
  final Function(DateTime date, String note)? onSaveNote;

  const HabitDetailScreen({
    super.key,
    required this.habit,
    required this.onUpdate,
    required this.onDelete,
    required this.onToggleDate,
    this.onSaveNote,
  });

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late Habit _habit;
  DateTime _viewMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
  }

  void _openEditDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HabitFormDialog(
        existingHabit: _habit,
        onSave: (updated) {
          setState(() {
            _habit = updated;
          });
          widget.onUpdate(updated);
        },
      ),
    );
  }

  void _openNoteDialog(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoteDialog(
        habit: _habit,
        date: date,
        onSave: (note) {
          final dateStr = Habit.formatDate(date);
          final updatedNotes = Map<String, String>.from(_habit.notes);
          if (note.trim().isEmpty) {
            updatedNotes.remove(dateStr);
          } else {
            updatedNotes[dateStr] = note.trim();
          }
          final updatedHabit = _habit.copyWith(notes: updatedNotes);
          setState(() {
            _habit = updatedHabit;
          });
          widget.onSaveNote?.call(date, note);
        },
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Are you sure you want to permanently delete "${_habit.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop(); // pop dialog
              widget.onDelete(_habit.id);
              Navigator.of(context).pop(); // pop detail screen
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final habitColor = _habit.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(_habit.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEditDialog,
            tooltip: 'Edit Habit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _confirmDelete,
            tooltip: 'Delete Habit',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    habitColor,
                    habitColor.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: habitColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_habit.icon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _habit.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (_habit.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _habit.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _habit.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Streak & Analytics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.deepOrangeAccent,
                    value: '${_habit.currentStreak}',
                    label: 'Current Streak',
                    unit: 'days',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.emoji_events_rounded,
                    iconColor: Colors.amber,
                    value: '${_habit.longestStreak}',
                    label: 'Best Streak',
                    unit: 'days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.pie_chart_rounded,
                    iconColor: Colors.tealAccent.shade700,
                    value: '${(_habit.completionRateLast30Days * 100).toInt()}%',
                    label: '30-Day Rate',
                    unit: 'consistency',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context: context,
                    icon: Icons.check_circle_rounded,
                    iconColor: habitColor,
                    value: '${_habit.totalCompletions}',
                    label: 'Total Check-ins',
                    unit: 'times',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Monthly Calendar Heatmap Card
            _buildCalendarHeatmap(context, habitColor, isDark),

            const SizedBox(height: 24),

            // Frequency info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: habitColor, size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Schedule',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _habit.frequencyDays.length == 7
                            ? 'Every day of the week'
                            : 'Active on ${_habit.frequencyDays.length} days/week',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Daily Notes & Remarks Log Section
            _buildDailyNotesSection(context, isDark),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyNotesSection(BuildContext context, bool isDark) {
    final habitColor = _habit.color;
    final sortedNotes = _habit.notes.entries.where((e) => e.value.trim().isNotEmpty).toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Notes & Remarks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            TextButton.icon(
              onPressed: () => _openNoteDialog(DateTime.now()),
              icon: const Icon(Icons.note_add_rounded, size: 18),
              label: const Text('Add Note'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sortedNotes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.comment_outlined, size: 36, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                const SizedBox(height: 8),
                Text(
                  'No remarks recorded yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "+ Add Note" or long-press any date on the calendar to log thoughts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedNotes.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final entry = sortedNotes[index];
                final date = DateTime.parse(entry.key);
                final formattedDate = DateFormat('EEE, d MMM yyyy').format(date);
                final isCompleted = _habit.completedDates.contains(entry.key);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCompleted ? habitColor.withValues(alpha: 0.15) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle_rounded : Icons.comment_rounded,
                      color: isCompleted ? habitColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    formattedDate,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _openNoteDialog(date),
                    tooltip: 'Edit Note',
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String unit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeatmap(BuildContext context, Color habitColor, bool isDark) {
    final monthName = DateFormat('MMMM yyyy').format(_viewMonth);
    final daysInMonth = DateUtils.getDaysInMonth(_viewMonth.year, _viewMonth.month);
    final firstDayOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final startOffset = (firstDayOfMonth.weekday - 1); // 0 = Mon

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // Month Header with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    onPressed: () {
                      setState(() {
                        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    onPressed: () {
                      setState(() {
                        _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Day of week labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return SizedBox(
                width: 32,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startOffset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox.shrink();
              }
              final day = index - startOffset + 1;
              final date = DateTime(_viewMonth.year, _viewMonth.month, day);
              final isCompleted = _habit.isCompletedOn(date);
              final hasNote = _habit.hasNoteOn(date);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        widget.onToggleDate(date);
                        final dateStr = Habit.formatDate(date);
                        final updatedSet = Set<String>.from(_habit.completedDates);
                        if (updatedSet.contains(dateStr)) {
                          updatedSet.remove(dateStr);
                        } else {
                          updatedSet.add(dateStr);
                        }
                        setState(() {
                          _habit = _habit.copyWith(completedDates: updatedSet);
                        });
                      },
                onLongPress: isFuture ? null : () => _openNoteDialog(date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? habitColor
                        : (isToday
                            ? habitColor.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9))),
                    shape: BoxShape.circle,
                    border: isToday && !isCompleted
                        ? Border.all(color: habitColor, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      isCompleted
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isFuture
                                    ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                      if (hasNote)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.amberAccent : habitColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: habitColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                'Tap to toggle completion • Long press for notes',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
