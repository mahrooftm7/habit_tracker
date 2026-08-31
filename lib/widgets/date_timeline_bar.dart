import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimelineBar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DateTimelineBar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<DateTimelineBar> createState() => _DateTimelineBarState();
}

class _DateTimelineBarState extends State<DateTimelineBar> {
  late final ScrollController _datesScrollController;
  late final ScrollController _monthsScrollController;
  late DateTime _currentMonth;
  final double _dateItemWidth = 62.0;
  final double _monthItemWidth = 72.0;

  @override
  void initState() {
    super.initState();
    _datesScrollController = ScrollController();
    _monthsScrollController = ScrollController();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth(animate: false);
      _scrollToSelectedDate(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant DateTimelineBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameMonth(oldWidget.selectedDate, widget.selectedDate)) {
      setState(() {
        _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
      });
      _scrollToSelectedMonth(animate: true);
    }
    if (!_isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _scrollToSelectedDate(animate: true);
    }
  }

  @override
  void dispose() {
    _datesScrollController.dispose();
    _monthsScrollController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  int _daysInMonth(DateTime month) {
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  List<DateTime> _getDatesForCurrentMonth() {
    final totalDays = _daysInMonth(_currentMonth);
    return List.generate(
      totalDays,
      (index) => DateTime(_currentMonth.year, _currentMonth.month, index + 1),
    );
  }

  void _scrollToSelectedMonth({bool animate = true}) {
    if (!_monthsScrollController.hasClients) return;
    // Month index relative to 12 months in the year (0 = Jan .. 11 = Dec)
    final monthIndex = _currentMonth.month - 1;
    final offset = (monthIndex * _monthItemWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (_monthItemWidth / 2);
    final clampedOffset = offset.clamp(0.0, _monthsScrollController.position.maxScrollExtent);

    if (animate) {
      _monthsScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _monthsScrollController.jumpTo(clampedOffset);
    }
  }

  void _scrollToSelectedDate({bool animate = true}) {
    if (!_datesScrollController.hasClients) return;
    final dates = _getDatesForCurrentMonth();
    final index = dates.indexWhere((d) => _isSameDay(d, widget.selectedDate));

    if (index != -1) {
      final offset = (index * _dateItemWidth) -
          (MediaQuery.of(context).size.width / 2) +
          (_dateItemWidth / 2);
      final clampedOffset = offset.clamp(0.0, _datesScrollController.position.maxScrollExtent);

      if (animate) {
        _datesScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _datesScrollController.jumpTo(clampedOffset);
      }
    }
  }

  void _onSelectMonth(int monthNumber) {
    final now = DateTime.now();
    final targetMonth = DateTime(_currentMonth.year, monthNumber, 1);
    final daysInTargetMonth = _daysInMonth(targetMonth);

    // Pick appropriate day
    int newDay = widget.selectedDate.day;
    if (_isSameMonth(targetMonth, now)) {
      newDay = now.day;
    } else if (newDay > daysInTargetMonth) {
      newDay = daysInTargetMonth;
    }

    final newDate = DateTime(targetMonth.year, targetMonth.month, newDay);
    setState(() {
      _currentMonth = targetMonth;
    });

    widget.onDateSelected(newDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth(animate: true);
      _scrollToSelectedDate(animate: true);
    });
  }

  void _changeYear(int delta) {
    final newYearMonth = DateTime(_currentMonth.year + delta, _currentMonth.month, 1);
    final daysInTarget = _daysInMonth(newYearMonth);
    int newDay = widget.selectedDate.day.clamp(1, daysInTarget);
    final newDate = DateTime(newYearMonth.year, newYearMonth.month, newDay);

    setState(() {
      _currentMonth = newYearMonth;
    });
    widget.onDateSelected(newDate);
  }

  void _jumpToToday() {
    final today = DateTime.now();
    setState(() {
      _currentMonth = DateTime(today.year, today.month, 1);
    });
    widget.onDateSelected(today);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth(animate: true);
      _scrollToSelectedDate(animate: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isTodaySelected = _isSameDay(widget.selectedDate, today);
    final monthDates = _getDatesForCurrentMonth();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header: Month & Year Navigator with "Today" quick button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      if (_currentMonth.month == 1) {
                        _changeYear(-1);
                        _onSelectMonth(12);
                      } else {
                        _onSelectMonth(_currentMonth.month - 1);
                      }
                    },
                    tooltip: 'Previous Month',
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      if (_currentMonth.month == 12) {
                        _changeYear(1);
                        _onSelectMonth(1);
                      } else {
                        _onSelectMonth(_currentMonth.month + 1);
                      }
                    },
                    tooltip: 'Next Month',
                  ),
                ],
              ),
              if (!isTodaySelected)
                TextButton.icon(
                  onPressed: _jumpToToday,
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text('Today'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),

        // 1. Months Horizontal Strip (Jan .. Dec)
        SizedBox(
          height: 38,
          child: ListView.builder(
            controller: _monthsScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthNum = index + 1;
              final isSelectedMonth = _currentMonth.month == monthNum;
              final isNowMonth = now.month == monthNum && _currentMonth.year == now.year;
              final monthDate = DateTime(_currentMonth.year, monthNum, 1);
              final monthLabel = DateFormat('MMM').format(monthDate);

              return GestureDetector(
                onTap: () => _onSelectMonth(monthNum),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _monthItemWidth - 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelectedMonth
                        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelectedMonth
                          ? theme.colorScheme.primary
                          : (isNowMonth
                              ? theme.colorScheme.primary.withValues(alpha: 0.4)
                              : Colors.transparent),
                      width: isSelectedMonth ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          monthLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelectedMonth ? FontWeight.w700 : FontWeight.w500,
                            color: isSelectedMonth
                                ? theme.colorScheme.primary
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                        if (isNowMonth && !isSelectedMonth) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 6),

        // 2. Dates Horizontal Strip Assigned Under Selected Month
        SizedBox(
          height: 86,
          child: ListView.builder(
            controller: _datesScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: monthDates.length,
            itemBuilder: (context, index) {
              final date = monthDates[index];
              final isSelected = _isSameDay(date, widget.selectedDate);
              final isToday = _isSameDay(date, today);

              return GestureDetector(
                onTap: () => widget.onDateSelected(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _dateItemWidth - 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isToday
                              ? theme.colorScheme.primary.withValues(alpha: 0.6)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      width: isToday && !isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isToday)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
