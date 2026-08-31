import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bank_account.dart';
import '../models/habit.dart';
import '../models/transaction.dart';

enum AnalyticsTimeHorizon { month, week, day, allTime }

class AnalyticsScreen extends StatefulWidget {
  final List<Habit> habits;
  final List<FinancialTransaction> transactions;
  final List<BankAccount> bankAccounts;

  const AnalyticsScreen({
    super.key,
    required this.habits,
    this.transactions = const [],
    this.bankAccounts = const [],
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _activeAnalyticsMode = 0; // 0: Habit Analytics, 1: Financial Analytics
  AnalyticsTimeHorizon _timeHorizon = AnalyticsTimeHorizon.month;
  DateTime _focusedDate = DateTime.now();
  String _selectedHabitId = 'all'; // 'all' or habit ID

  void _navigatePeriod(int direction) {
    setState(() {
      switch (_timeHorizon) {
        case AnalyticsTimeHorizon.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + direction, 1);
          break;
        case AnalyticsTimeHorizon.week:
          _focusedDate = _focusedDate.add(Duration(days: direction * 7));
          break;
        case AnalyticsTimeHorizon.day:
          _focusedDate = _focusedDate.add(Duration(days: direction));
          break;
        case AnalyticsTimeHorizon.allTime:
          break;
      }
    });
  }

  List<DateTime> _getDatesInScope() {
    final now = _focusedDate;
    final List<DateTime> dates = [];

    switch (_timeHorizon) {
      case AnalyticsTimeHorizon.day:
        dates.add(DateTime(now.year, now.month, now.day));
        break;
      case AnalyticsTimeHorizon.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        for (int i = 0; i < 7; i++) {
          dates.add(DateTime(monday.year, monday.month, monday.day).add(Duration(days: i)));
        }
        break;
      case AnalyticsTimeHorizon.month:
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
        for (int i = 1; i <= daysInMonth; i++) {
          dates.add(DateTime(now.year, now.month, i));
        }
        break;
      case AnalyticsTimeHorizon.allTime:
        for (int i = 29; i >= 0; i--) {
          dates.add(now.subtract(Duration(days: i)));
        }
        break;
    }
    return dates;
  }

  String _getPeriodLabel() {
    final fmtMonth = DateFormat('MMMM yyyy');
    final fmtDay = DateFormat('EEE, d MMM yyyy');

    switch (_timeHorizon) {
      case AnalyticsTimeHorizon.month:
        return fmtMonth.format(_focusedDate);
      case AnalyticsTimeHorizon.week:
        final dates = _getDatesInScope();
        final start = DateFormat('d MMM').format(dates.first);
        final end = DateFormat('d MMM yyyy').format(dates.last);
        return '$start - $end';
      case AnalyticsTimeHorizon.day:
        return fmtDay.format(_focusedDate);
      case AnalyticsTimeHorizon.allTime:
        return 'All Time Trend';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Insights'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Analytics Mode Switcher (Habits vs Financials)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeAnalyticsMode = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeAnalyticsMode == 0
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              size: 16,
                              color: _activeAnalyticsMode == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Habit Analytics',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _activeAnalyticsMode == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeAnalyticsMode = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeAnalyticsMode == 1
                              ? const Color(0xFF0D9488)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 16,
                              color: _activeAnalyticsMode == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Financial Analytics',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _activeAnalyticsMode == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Time Horizon Selector Tabs
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTimeHorizonChip('Month', AnalyticsTimeHorizon.month, isDark),
                  _buildTimeHorizonChip('Week', AnalyticsTimeHorizon.week, isDark),
                  _buildTimeHorizonChip('Day', AnalyticsTimeHorizon.day, isDark),
                  _buildTimeHorizonChip('All Time', AnalyticsTimeHorizon.allTime, isDark),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Date Navigation Bar
            if (_timeHorizon != AnalyticsTimeHorizon.allTime)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _navigatePeriod(-1),
                      tooltip: 'Previous Period',
                    ),
                    Text(
                      _getPeriodLabel(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _navigatePeriod(1),
                      tooltip: 'Next Period',
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Mode 0: Habit Analytics View
            if (_activeAnalyticsMode == 0) _buildHabitAnalyticsView(context, isDark),

            // Mode 1: Financial Analytics View
            if (_activeAnalyticsMode == 1) _buildFinancialAnalyticsView(context, isDark),
          ],
        ),
      ),
    );
  }

  // --- HABIT ANALYTICS VIEW ---
  Widget _buildHabitAnalyticsView(BuildContext context, bool isDark) {
    if (widget.habits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.insights_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('No Habit Data Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Create your first habit to unlock analytics', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final List<Habit> filteredHabits = _selectedHabitId == 'all'
        ? widget.habits
        : widget.habits.where((h) => h.id == _selectedHabitId).toList();

    final Habit? activeSingleHabit = _selectedHabitId != 'all' && filteredHabits.isNotEmpty
        ? filteredHabits.first
        : null;

    final datesInScope = _getDatesInScope();

    int totalCheckinsInPeriod = 0;
    int scheduledCountInPeriod = 0;

    final Map<int, int> weekdayCompletions = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final Map<int, int> weekdayScheduled = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

    final List<int> dailyCompletionsList = [];

    for (final date in datesInScope) {
      int dayDone = 0;
      for (final h in filteredHabits) {
        if (h.isScheduledFor(date)) {
          scheduledCountInPeriod++;
          weekdayScheduled[date.weekday] = (weekdayScheduled[date.weekday] ?? 0) + 1;
          if (h.isCompletedOn(date)) {
            totalCheckinsInPeriod++;
            dayDone++;
            weekdayCompletions[date.weekday] = (weekdayCompletions[date.weekday] ?? 0) + 1;
          }
        }
      }
      dailyCompletionsList.add(dayDone);
    }

    final double periodCompletionRate = scheduledCountInPeriod > 0
        ? (totalCheckinsInPeriod / scheduledCountInPeriod).clamp(0.0, 1.0)
        : 0.0;

    int bestWeekday = 1;
    double bestWeekdayRate = -1.0;
    for (int day = 1; day <= 7; day++) {
      final sched = weekdayScheduled[day] ?? 0;
      final comp = weekdayCompletions[day] ?? 0;
      final rate = sched > 0 ? comp / sched : 0.0;
      if (rate > bestWeekdayRate && sched > 0) {
        bestWeekdayRate = rate;
        bestWeekday = day;
      }
    }

    final String bestDayName = DateFormat('EEEE').format(DateTime(2026, 8, 24 + (bestWeekday - 1)));

    final Map<String, int> categoryHabitCount = {};
    for (final h in filteredHabits) {
      categoryHabitCount[h.category] = (categoryHabitCount[h.category] ?? 0) + 1;
    }

    final List<MapEntry<Habit, MapEntry<String, String>>> notesInPeriod = [];
    for (final h in filteredHabits) {
      for (final date in datesInScope) {
        final dateStr = Habit.formatDate(date);
        if (h.notes.containsKey(dateStr) && h.notes[dateStr]!.trim().isNotEmpty) {
          notesInPeriod.add(MapEntry(h, MapEntry(dateStr, h.notes[dateStr]!)));
        }
      }
    }
    notesInPeriod.sort((a, b) => b.value.key.compareTo(a.value.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Habit Filter Chips
        Text(
          'Filter by Habit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildHabitFilterChip(
                id: 'all',
                title: 'All Habits (${widget.habits.length})',
                icon: Icons.apps_rounded,
                color: const Color(0xFF6366F1),
                isDark: isDark,
              ),
              ...widget.habits.map(
                (h) => _buildHabitFilterChip(
                  id: h.id,
                  title: h.title,
                  icon: h.icon,
                  color: h.color,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Period Overview Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: activeSingleHabit != null
                  ? [activeSingleHabit.color, activeSingleHabit.color.withValues(alpha: 0.8)]
                  : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (activeSingleHabit?.color ?? const Color(0xFF3B82F6)).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    activeSingleHabit != null ? activeSingleHabit.title : 'Period Consistency',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getPeriodLabel(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '${(periodCompletionRate * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      periodCompletionRate > 0.7
                          ? 'Outstanding habit performance!'
                          : (periodCompletionRate > 0.4
                              ? 'Good progress! Staying on track.'
                              : 'Keep building daily consistency.'),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: periodCompletionRate,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Key Metrics Grid
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                icon: Icons.checklist_rounded,
                color: const Color(0xFF10B981),
                label: 'Habits Tracked',
                value: '${filteredHabits.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF6366F1),
                label: 'Period Check-ins',
                value: '$totalCheckinsInPeriod',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                icon: Icons.stars_rounded,
                color: Colors.amber.shade700,
                label: 'Most Active Day',
                value: bestWeekdayRate > 0 ? bestDayName : 'N/A',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                icon: Icons.local_fire_department_rounded,
                color: Colors.deepOrangeAccent,
                label: activeSingleHabit != null ? 'Current Streak' : 'Max Streak',
                value: activeSingleHabit != null
                    ? '${activeSingleHabit.currentStreak} days'
                    : '${filteredHabits.isEmpty ? 0 : filteredHabits.map((h) => h.longestStreak).reduce((a, b) => a > b ? a : b)} days',
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Completion Bar Chart
        _buildCompletionBarChart(context, datesInScope, dailyCompletionsList, filteredHabits.length, isDark),

        const SizedBox(height: 24),

        // Remarks & Daily Notes Section
        _buildPeriodNotesSection(context, notesInPeriod, isDark),

        const SizedBox(height: 32),
      ],
    );
  }

  // --- FINANCIAL ANALYTICS VIEW ---
  Widget _buildFinancialAnalyticsView(BuildContext context, bool isDark) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');
    final datesInScope = _getDatesInScope();

    // Filter transactions in date scope
    final List<FinancialTransaction> scopeTxs = widget.transactions.where((tx) {
      return datesInScope.any((d) => d.year == tx.date.year && d.month == tx.date.month && d.day == tx.date.day);
    }).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    double cashAmount = 0;
    double bankAmount = 0;

    final Map<String, double> categoryExpenses = {};

    for (final tx in scopeTxs) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        categoryExpenses[tx.category] = (categoryExpenses[tx.category] ?? 0.0) + tx.amount;
      }

      if (tx.paymentMethod == PaymentMethod.cash) {
        cashAmount += tx.amount;
      } else {
        bankAmount += tx.amount;
      }
    }

    final double netSavings = totalIncome - totalExpense;
    final double savingsRate = totalIncome > 0 ? ((netSavings / totalIncome) * 100).clamp(0.0, 100.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Financial Overview Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Period Net Savings',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Savings Rate: ${savingsRate.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                currencyFmt.format(netSavings),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Income', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                        Text(currencyFmt.format(totalIncome), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Expenses', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                        Text(currencyFmt.format(totalExpense), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Financial Metrics Tiles
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                icon: Icons.payments_rounded,
                color: const Color(0xFF10B981),
                label: 'Cash Flow',
                value: currencyFmt.format(cashAmount),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                isDark: isDark,
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF6366F1),
                label: 'Bank Transactions',
                value: currencyFmt.format(bankAmount),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Category Expense Distribution Breakdown
        Text(
          'Expense Breakdown by Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        if (categoryExpenses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: const Text('No expense transactions recorded for this timeframe.'),
          )
        else
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: categoryExpenses.entries.map((entry) {
                final double fraction = totalExpense > 0 ? entry.value / totalExpense : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text(
                            '${currencyFmt.format(entry.value)} (${(fraction * 100).toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 8,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTimeHorizonChip(String label, AnalyticsTimeHorizon horizon, bool isDark) {
    final isSelected = _timeHorizon == horizon;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _timeHorizon = horizon;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitFilterChip({
    required String id,
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedHabitId == id;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
        label: Text(title),
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
            _selectedHabitId = id;
          });
        },
      ),
    );
  }

  Widget _buildCompletionBarChart(
    BuildContext context,
    List<DateTime> dates,
    List<int> completionsList,
    int maxCapacity,
    bool isDark,
  ) {
    final maxVal = maxCapacity > 0 ? maxCapacity : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completion Trend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${dates.length} days view',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(dates.length, (index) {
                final date = dates[index];
                final count = completionsList[index];
                final double heightRatio = (count / maxVal).clamp(0.05, 1.0);
                final isToday = DateUtils.isSameDay(date, DateTime.now());

                return Expanded(
                  child: Tooltip(
                    message: '${DateFormat('EEE, d MMM').format(date)}: $count done',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Text(
                              '$count',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Container(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: heightRatio,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: count > 0
                                          ? [const Color(0xFF3B82F6), const Color(0xFF6366F1)]
                                          : [
                                              isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                            ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: isToday
                                        ? Border.all(color: Colors.amberAccent, width: 1.5)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dates.length > 14
                                ? (index % 5 == 0 ? '${date.day}' : '')
                                : DateFormat('EEEEE').format(date),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                              color: isToday
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodNotesSection(
    BuildContext context,
    List<MapEntry<Habit, MapEntry<String, String>>> notesInPeriod,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Period Remarks & Notes (${notesInPeriod.length})',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        if (notesInPeriod.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              'No notes recorded for this period & habit filter.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
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
              itemCount: notesInPeriod.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final habit = notesInPeriod[index].key;
                final dateStr = notesInPeriod[index].value.key;
                final note = notesInPeriod[index].value.value;
                final dateFormatted = DateFormat('EEE, d MMM').format(DateTime.parse(dateStr));

                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: habit.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(habit.icon, color: habit.color, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        habit.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        dateFormatted,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '"$note"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMetricTile({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
