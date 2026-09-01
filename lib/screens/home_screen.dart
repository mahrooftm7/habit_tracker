import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../models/user.dart';
import '../widgets/date_timeline_bar.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/habit_card.dart';
import '../widgets/habit_form_dialog.dart';
import '../widgets/note_dialog.dart';
import '../widgets/user_profile_dialog.dart';
import 'habit_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser currentUser;
  final List<Habit> habits;
  final Function(Habit) onAddHabit;
  final Function(Habit) onUpdateHabit;
  final Function(String) onDeleteHabit;
  final Function(String, DateTime) onToggleHabit;
  final Function(String habitId, DateTime date, String note) onSaveNote;
  final Function(AppUser) onUserSwitched;
  final VoidCallback onLogout;
  final VoidCallback onAddNewAccount;

  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.habits,
    required this.onAddHabit,
    required this.onUpdateHabit,
    required this.onDeleteHabit,
    required this.onToggleHabit,
    required this.onSaveNote,
    required this.onUserSwitched,
    required this.onLogout,
    required this.onAddNewAccount,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'All';

  void _openAddHabitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HabitFormDialog(
        onSave: widget.onAddHabit,
      ),
    );
  }

  void _openNoteDialog(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoteDialog(
        habit: habit,
        date: _selectedDate,
        onSave: (note) => widget.onSaveNote(habit.id, _selectedDate, note),
      ),
    );
  }

  void _openUserProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserProfileDialog(
        currentUser: widget.currentUser,
        onUserSwitched: widget.onUserSwitched,
        onLogout: widget.onLogout,
        onAddNewAccount: widget.onAddNewAccount,
      ),
    );
  }

  void _openHabitDetails(Habit habit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => HabitDetailScreen(
          habit: habit,
          onUpdate: widget.onUpdateHabit,
          onDelete: widget.onDeleteHabit,
          onToggleDate: (date) => widget.onToggleHabit(habit.id, date),
          onSaveNote: (date, note) => widget.onSaveNote(habit.id, date, note),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter habits scheduled for the selected day
    final scheduledHabits = widget.habits.where((h) => h.isScheduledFor(_selectedDate)).toList();

    final completedCount = scheduledHabits.where((h) => h.isCompletedOn(_selectedDate)).length;
    final totalCount = scheduledHabits.length;

    // Further filter by selected category
    final displayedHabits = _selectedCategory == 'All'
        ? scheduledHabits
        : scheduledHabits.where((h) => h.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with User Profile and Add Habit
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // User profile avatar & greeting
                          GestureDetector(
                            onTap: _openUserProfile,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: widget.currentUser.color,
                                  child: Text(
                                    widget.currentUser.initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          widget.currentUser.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      DateFormat('EEEE, d MMM').format(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Explicit Add Habit Button
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Add Habit',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: _openAddHabitSheet,
                          ),
                        ],
                      ),
                    ),

                    if (widget.currentUser.isTrial) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_rounded, color: Colors.amber, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '15-Day Free Trial: ${widget.currentUser.remainingTrialDays} days remaining',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Date Timeline with Month selection above it
                    DateTimelineBar(
                      selectedDate: _selectedDate,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    // Daily Progress Card
                    DailyProgressCard(
                      completedCount: completedCount,
                      totalCount: totalCount,
                      selectedDate: _selectedDate,
                    ),

                    const SizedBox(height: 8),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          _buildCategoryChip('All', isDark),
                          ...HabitCategory.values.map((cat) => _buildCategoryChip(cat.label, isDark)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ];
          },
          body: displayedHabits.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 90, top: 4),
                  itemCount: displayedHabits.length,
                  itemBuilder: (context, index) {
                    final habit = displayedHabits[index];
                    return HabitCard(
                      habit: habit,
                      selectedDate: _selectedDate,
                      onToggle: () => widget.onToggleHabit(habit.id, _selectedDate),
                      onTap: () => _openHabitDetails(habit),
                      onDelete: () => widget.onDeleteHabit(habit.id),
                      onOpenNote: () => _openNoteDialog(habit),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryName, bool isDark) {
    final isSelected = _selectedCategory.toLowerCase() == categoryName.toLowerCase();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(categoryName),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected
              ? Colors.white
              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: (_) {
          setState(() {
            _selectedCategory = categoryName;
          });
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 40,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == 'All'
                  ? 'No Habits for this day'
                  : 'No habits in "$_selectedCategory"',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + New Habit below to build your routine',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
