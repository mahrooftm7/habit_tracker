import 'package:flutter/material.dart';
import '../models/habit.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final DateTime selectedDate;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenNote;

  const HabitCard({
    super.key,
    required this.habit,
    required this.selectedDate,
    required this.onToggle,
    required this.onTap,
    this.onDelete,
    this.onOpenNote,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleCheckTap() {
    _animController.forward().then((_) {
      _animController.reverse();
      widget.onToggle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompleted = widget.habit.isCompletedOn(widget.selectedDate);
    final habitColor = widget.habit.color;
    final streak = widget.habit.currentStreak;

    return Dismissible(
      key: Key('habit_${widget.habit.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Habit?'),
            content: Text('Are you sure you want to delete "${widget.habit.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        widget.onDelete?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? habitColor.withValues(alpha: 0.5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isCompleted ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Habit Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: habitColor.withValues(alpha: isCompleted ? 0.9 : 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.habit.icon,
                      color: isCompleted ? Colors.white : habitColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Habit Title & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.habit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            decorationColor: habitColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Category Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.habit.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Streak Badge
                            if (streak > 0) ...[
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrangeAccent, size: 15),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$streak d',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.deepOrangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Note Indicator Badge if present
                            if (widget.habit.hasNoteOn(widget.selectedDate))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: habitColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.comment_rounded, size: 12, color: habitColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Note',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: habitColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (widget.habit.hasNoteOn(widget.selectedDate)) ...[
                          const SizedBox(height: 4),
                          Text(
                            '"${widget.habit.getNoteFor(widget.selectedDate)}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Note Quick Edit Button
                  if (widget.onOpenNote != null)
                    IconButton(
                      icon: Icon(
                        widget.habit.hasNoteOn(widget.selectedDate)
                            ? Icons.note_alt_rounded
                            : Icons.note_add_outlined,
                        size: 20,
                        color: widget.habit.hasNoteOn(widget.selectedDate)
                            ? habitColor
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                      onPressed: widget.onOpenNote,
                      tooltip: widget.habit.hasNoteOn(widget.selectedDate) ? 'Edit Note' : 'Add Note',
                    ),

                  const SizedBox(width: 4),

                  // Animated Check Button
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: GestureDetector(
                      onTap: _handleCheckTap,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isCompleted ? habitColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted ? habitColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
