import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/habit.dart';

class HabitFormDialog extends StatefulWidget {
  final Habit? existingHabit;
  final Function(Habit) onSave;

  const HabitFormDialog({
    super.key,
    this.existingHabit,
    required this.onSave,
  });

  @override
  State<HabitFormDialog> createState() => _HabitFormDialogState();
}

class _HabitFormDialogState extends State<HabitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late String _selectedCategory;
  late int _selectedColorValue;
  late int _selectedIconCode;
  late List<int> _selectedDays;

  static const List<int> _availableColors = [
    0xFF6366F1, // Indigo
    0xFF10B981, // Emerald
    0xFFF43F5E, // Rose
    0xFF06B6D4, // Cyan
    0xFFF59E0B, // Amber
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF3B82F6, // Blue
  ];

  static const List<IconData> _availableIcons = [
    Icons.favorite_rounded,
    Icons.fitness_center_rounded,
    Icons.water_drop_rounded,
    Icons.menu_book_rounded,
    Icons.self_improvement_rounded,
    Icons.bedtime_rounded,
    Icons.directions_run_rounded,
    Icons.code_rounded,
    Icons.brush_rounded,
    Icons.savings_rounded,
    Icons.alarm_rounded,
    Icons.star_rounded,
  ];

  final List<String> _weekDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final h = widget.existingHabit;
    _titleController = TextEditingController(text: h?.title ?? '');
    _descriptionController = TextEditingController(text: h?.description ?? '');
    _selectedCategory = h?.category ?? 'Health';
    _selectedColorValue = h?.colorValue ?? _availableColors[0];
    _selectedIconCode = h?.iconCodePoint ?? _availableIcons[0].codePoint;
    _selectedDays = h != null ? List<int>.from(h.frequencyDays) : [1, 2, 3, 4, 5, 6, 7];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final habit = Habit(
        id: widget.existingHabit?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        colorValue: _selectedColorValue,
        iconCodePoint: _selectedIconCode,
        frequencyDays: _selectedDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : _selectedDays,
        completedDates: widget.existingHabit?.completedDates ?? <String>{},
        createdAt: widget.existingHabit?.createdAt ?? DateTime.now(),
      );

      widget.onSave(habit);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Modal Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingHabit == null ? 'Create New Habit' : 'Edit Habit',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title input
              Text(
                'Habit Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                autofocus: widget.existingHabit == null,
                decoration: const InputDecoration(
                  hintText: 'e.g. Read 20 mins, Drink Water',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a habit title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description input
              Text(
                'Description (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Right after waking up',
                ),
              ),
              const SizedBox(height: 18),

              // Category Selector
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HabitCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat.label;
                  return ChoiceChip(
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    label: Text(cat.label),
                    selected: isSelected,
                    selectedColor: Color(_selectedColorValue),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat.label;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Icon Picker
              Text(
                'Icon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _availableIcons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final icon = _availableIcons[index];
                    final isSelected = _selectedIconCode == icon.codePoint;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIconCode = icon.codePoint;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColorValue).withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Color(_selectedColorValue)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? Color(_selectedColorValue)
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Color Picker
              Text(
                'Color Theme',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _availableColors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final colorVal = _availableColors[index];
                    final isSelected = _selectedColorValue == colorVal;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColorValue = colorVal;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Frequency Days Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Frequency',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedDays.length == 7) {
                          _selectedDays = [1, 2, 3, 4, 5]; // Weekdays
                        } else {
                          _selectedDays = [1, 2, 3, 4, 5, 6, 7]; // Everyday
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _selectedDays.length == 7 ? 'Weekdays Only' : 'Every Day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(_selectedColorValue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final dayNumber = index + 1;
                  final isSelected = _selectedDays.contains(dayNumber);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_selectedDays.length > 1) {
                            _selectedDays.remove(dayNumber);
                          }
                        } else {
                          _selectedDays.add(dayNumber);
                          _selectedDays.sort();
                        }
                      });
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColorValue)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Color(_selectedColorValue)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _weekDayLabels[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_selectedColorValue),
                  ),
                  onPressed: _submit,
                  child: Text(
                    widget.existingHabit == null ? 'Create Habit' : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
