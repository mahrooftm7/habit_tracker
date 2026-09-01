import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bank_account.dart';
import '../models/debt.dart';
import '../models/transaction.dart';
import '../services/category_storage_service.dart';
import '../widgets/bank_account_dialog.dart';
import '../widgets/category_dialog.dart';
import '../widgets/date_timeline_bar.dart';
import '../widgets/debt_dialog.dart';
import '../widgets/transaction_dialog.dart';
import '../widgets/transfer_dialog.dart';

class FinanceScreen extends StatefulWidget {
  final String userId;
  final List<FinancialTransaction> transactions;
  final List<BankAccount> bankAccounts;
  final List<Debt> debts;
  final double initialCashBalance;
  final Function(FinancialTransaction) onAddTransaction;
  final Function(String) onDeleteTransaction;
  final Function(BankAccount) onAddBankAccount;
  final Function(String) onDeleteBankAccount;
  final Function(Debt) onAddDebt;
  final Function(String) onToggleDebtSettled;
  final Function(String) onDeleteDebt;
  final Function(double) onUpdateCashBalance;

  const FinanceScreen({
    super.key,
    required this.userId,
    required this.transactions,
    required this.bankAccounts,
    required this.debts,
    required this.initialCashBalance,
    required this.onAddTransaction,
    required this.onDeleteTransaction,
    required this.onAddBankAccount,
    required this.onDeleteBankAccount,
    required this.onAddDebt,
    required this.onToggleDebtSettled,
    required this.onDeleteDebt,
    required this.onUpdateCashBalance,
  });

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final CategoryStorageService _categoryStorage = CategoryStorageService();
  DateTime _selectedDate = DateTime.now();
  bool _isDayView = true;
  DateTimeRange? _customDateRange;
  String _txFilter = 'All'; // 'All', 'Income', 'Expense', 'Cash', 'Bank'
  String _selectedCategory = 'All'; // 'All', 'Salary', 'Groceries', etc.
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _categoryStorage.loadCategories(widget.userId);
    if (mounted) {
      setState(() => _categories = cats);
    }
  }

  Future<void> _addCategory(String name) async {
    final cats = await _categoryStorage.addCategory(widget.userId, name);
    if (mounted) {
      setState(() => _categories = cats);
    }
  }

  Future<void> _deleteCategory(String name) async {
    final cats = await _categoryStorage.deleteCategory(widget.userId, name);
    if (mounted) {
      setState(() => _categories = cats);
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: _selectedDate.subtract(const Duration(days: 7)),
        end: _selectedDate,
      ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
      });
    }
  }

  void _openAddTransactionSheet({TransactionType? initialType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionDialog(
        bankAccounts: widget.bankAccounts,
        customCategories: _categories,
        onSave: widget.onAddTransaction,
      ),
    );
  }

  void _openTransferSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransferDialog(
        bankAccounts: widget.bankAccounts,
        onSaveTransaction: widget.onAddTransaction,
      ),
    );
  }

  void _openAddBankAccountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BankAccountDialog(
        onSave: widget.onAddBankAccount,
      ),
    );
  }

  void _openAddDebtSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DebtDialog(
        onSave: widget.onAddDebt,
      ),
    );
  }

  void _openAddCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryDialog(
        categories: _categories,
        onAddCategory: _addCategory,
        onDeleteCategory: _deleteCategory,
      ),
    );
  }

  void _openEditCashBalanceDialog(double currentCash) {
    final controller = TextEditingController(text: currentCash.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Base Cash Balance'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cash in Hand',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newBal = double.tryParse(controller.text.trim());
              if (newBal != null) {
                widget.onUpdateCashBalance(newBal);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');

    // Calculate Cash Balance
    double cashIncome = 0;
    double cashExpense = 0;
    for (final tx in widget.transactions) {
      if (tx.paymentMethod == PaymentMethod.cash) {
        if (tx.type == TransactionType.income) {
          cashIncome += tx.amount;
        } else {
          cashExpense += tx.amount;
        }
      }
    }
    final double totalCashBalance = widget.initialCashBalance + cashIncome - cashExpense;

    // Calculate Bank Balances per Account
    final Map<String, double> bankBalances = {};
    for (final b in widget.bankAccounts) {
      bankBalances[b.id] = b.initialBalance;
    }
    for (final tx in widget.transactions) {
      if (tx.paymentMethod == PaymentMethod.bank && tx.bankAccountId != null) {
        final current = bankBalances[tx.bankAccountId!] ?? 0.0;
        if (tx.type == TransactionType.income) {
          bankBalances[tx.bankAccountId!] = current + tx.amount;
        } else {
          bankBalances[tx.bankAccountId!] = current - tx.amount;
        }
      }
    }

    final double totalBankBalance = bankBalances.values.fold(0.0, (sum, val) => sum + val);

    // Debts & Receivables
    double totalOwedToOthers = 0;
    double totalReceivable = 0;
    for (final d in widget.debts) {
      if (!d.isSettled) {
        if (d.type == DebtType.owe) {
          totalOwedToOthers += d.amount;
        } else {
          totalReceivable += d.amount;
        }
      }
    }

    final double netWorth = totalCashBalance + totalBankBalance + totalReceivable - totalOwedToOthers;

    // Calculate Monthly Dashboard Metrics for Selected Month & Year
    double periodIncome = 0;
    double periodExpense = 0;
    for (final tx in widget.transactions) {
      if (tx.date.month == _selectedDate.month && tx.date.year == _selectedDate.year) {
        if (tx.type == TransactionType.income) {
          periodIncome += tx.amount;
        } else {
          periodExpense += tx.amount;
        }
      }
    }
    final double periodNetSavings = periodIncome - periodExpense;

    // Available Categories for Filter Chips (Dynamic)
    final availableCategories = ['All', ..._categories];

    // Filtered Transactions (Dynamic per Exact Day, Custom Range, or Month)
    final filteredTxs = widget.transactions.where((tx) {
      // Date Scope Filter
      if (_customDateRange != null) {
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        if (tx.date.isBefore(start) || tx.date.isAfter(end)) return false;
      } else if (_isDayView) {
        if (tx.date.year != _selectedDate.year ||
            tx.date.month != _selectedDate.month ||
            tx.date.day != _selectedDate.day) {
          return false;
        }
      } else {
        if (tx.date.month != _selectedDate.month || tx.date.year != _selectedDate.year) {
          return false;
        }
      }

      // Type/Payment Filter
      if (_txFilter == 'Income' && tx.type != TransactionType.income) return false;
      if (_txFilter == 'Expense' && tx.type != TransactionType.expense) return false;
      if (_txFilter == 'Cash' && tx.paymentMethod != PaymentMethod.cash) return false;
      if (_txFilter == 'Bank' && tx.paymentMethod != PaymentMethod.bank) return false;

      // Category Filter
      if (_selectedCategory != 'All' && tx.category.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      // Top Title Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Financial Tracker',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('d MMMM yyyy').format(_selectedDate),
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

                      const SizedBox(height: 12),

                      // Horizontally Scrollable Action Bar for Mobile Responsiveness
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Income', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              onPressed: () => _openAddTransactionSheet(initialType: TransactionType.income),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade500,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.remove_rounded, size: 16),
                              label: const Text('Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              onPressed: () => _openAddTransactionSheet(initialType: TransactionType.expense),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('Transfer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              onPressed: _openTransferSheet,
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                foregroundColor: const Color(0xFF6366F1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.account_balance_rounded, size: 18),
                              tooltip: 'Add Bank Account',
                              onPressed: _openAddBankAccountSheet,
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.orange.withValues(alpha: 0.15),
                                foregroundColor: Colors.orange.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                              tooltip: 'Add Debt / Credit',
                              onPressed: _openAddDebtSheet,
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.purple.withValues(alpha: 0.15),
                                foregroundColor: Colors.purple.shade600,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.category_rounded, size: 18),
                              tooltip: 'Manage Categories',
                              onPressed: _openAddCategorySheet,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Net Financial Position Banner (Top Position)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                                  'Net Financial Position',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Total Assets - Liabilities',
                                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currencyFmt.format(netWorth),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cash in Hand',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                                      ),
                                      Text(
                                        currencyFmt.format(totalCashBalance),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.3)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bank Accounts',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                                      ),
                                      Text(
                                        currencyFmt.format(totalBankBalance),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.3)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Receivables',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                                      ),
                                      Text(
                                        currencyFmt.format(totalReceivable),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Date Timeline Bar (Month & Date Selector)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    DateTimelineBar(
                      selectedDate: _selectedDate,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedDate = date;
                          _customDateRange = null; // Clear custom range when picking date
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          // Day vs Month View Toggle
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text('Day View', style: TextStyle(fontSize: 11)),
                                icon: Icon(Icons.today_rounded, size: 14),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text('Month View', style: TextStyle(fontSize: 11)),
                                icon: Icon(Icons.calendar_month_rounded, size: 14),
                              ),
                            ],
                            selected: {_isDayView},
                            onSelectionChanged: (set) {
                              setState(() {
                                _isDayView = set.first;
                                _customDateRange = null;
                              });
                            },
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const Spacer(),

                          // Custom Date Range Button
                          ActionChip(
                            avatar: Icon(
                              Icons.date_range_rounded,
                              size: 16,
                              color: _customDateRange != null ? Colors.white : theme.colorScheme.primary,
                            ),
                            label: Text(
                              _customDateRange != null
                                  ? '${DateFormat('d MMM').format(_customDateRange!.start)} - ${DateFormat('d MMM').format(_customDateRange!.end)}'
                                  : 'Custom Range',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _customDateRange != null ? Colors.white : theme.colorScheme.primary,
                              ),
                            ),
                            backgroundColor: _customDateRange != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.1),
                            onPressed: _pickCustomDateRange,
                          ),

                          if (_customDateRange != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _customDateRange = null),
                              tooltip: 'Clear Custom Range',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 2. Period Financial Dashboard Card (Monthly Summary)
                Container(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${DateFormat('MMMM yyyy').format(_selectedDate)} Summary',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: periodNetSavings >= 0 ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              periodNetSavings >= 0 ? 'Net Saved' : 'Net Deficit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: periodNetSavings >= 0 ? const Color(0xFF10B981) : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Monthly Income', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(currencyFmt.format(periodIncome), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Monthly Expense', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(currencyFmt.format(periodExpense), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.red.shade400)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Liquid Accounts Breakdown Grid (Cash & Bank Cards)
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 20),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _openEditCashBalanceDialog(widget.initialCashBalance),
                                  tooltip: 'Edit Base Cash',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFmt.format(totalCashBalance),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cash Balance',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.account_balance_rounded, color: Color(0xFF6366F1), size: 20),
                                ),
                                Text(
                                  '${widget.bankAccounts.length} Banks',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFmt.format(totalBankBalance),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Bank Balance',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. Bank Accounts List Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bank Accounts (${widget.bankAccounts.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openAddBankAccountSheet,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Bank'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (widget.bankAccounts.isEmpty)
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
                    child: const Text('No bank accounts added yet. Tap "+ Add Bank" to add one.'),
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
                      itemCount: widget.bankAccounts.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final bank = widget.bankAccounts[index];
                        final bal = bankBalances[bank.id] ?? bank.initialBalance;

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_rounded, color: Color(0xFF6366F1), size: 20),
                          ),
                          title: Text(
                            bank.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Text(
                            bank.accountNumberLast4 != null ? 'A/C ending in **** ${bank.accountNumberLast4}' : 'Bank Account',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currencyFmt.format(bal),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                onPressed: () => widget.onDeleteBankAccount(bank.id),
                                tooltip: 'Delete Bank',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),

                // 5. Daily Transactions Section with Category Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981)),
                          onPressed: () => _openAddTransactionSheet(initialType: TransactionType.income),
                          tooltip: 'Add Income',
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                          onPressed: () => _openAddTransactionSheet(initialType: TransactionType.expense),
                          tooltip: 'Add Expense',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Mode Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['All', 'Income', 'Expense', 'Cash', 'Bank'].map((f) {
                      final isSelected = _txFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _txFilter = f);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: availableCategories.map((cat) {
                      final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              _selectedCategory = val ? cat : 'All';
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                if (filteredTxs.isEmpty)
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
                        Icon(Icons.receipt_long_rounded, size: 36, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        const SizedBox(height: 8),
                        Text(
                          'No transactions matching "$_txFilter" ($_selectedCategory)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                      itemCount: filteredTxs.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final tx = filteredTxs[index];
                        final isIncome = tx.type == TransactionType.income;
                        final dateStr = DateFormat('MMM d, yyyy').format(tx.date);

                        BankAccount? bank;
                        if (tx.paymentMethod == PaymentMethod.bank && tx.bankAccountId != null) {
                          bank = widget.bankAccounts.firstWhere(
                            (b) => b.id == tx.bankAccountId,
                            orElse: () => BankAccount(id: '', name: 'Bank'),
                          );
                        }

                        return Dismissible(
                          key: Key('tx_${tx.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade400,
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) => widget.onDeleteTransaction(tx.id),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isIncome ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isIncome ? const Color(0xFF10B981) : Colors.red,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    tx.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                                Text(
                                  '${isIncome ? '+' : '-'} ${currencyFmt.format(tx.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isIncome ? const Color(0xFF10B981) : Colors.red.shade400,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tx.category,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (tx.paymentMethod == PaymentMethod.cash ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tx.paymentMethod == PaymentMethod.cash ? 'Cash' : (bank?.name ?? 'Bank'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: tx.paymentMethod == PaymentMethod.cash ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 24),

                // 6. Debts & Receivables Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Debts & Credits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openAddDebtSheet,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Credit/Debt'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Debt Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Receivable (Collect)', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(currencyFmt.format(totalReceivable), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Owed (To Pay)', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(currencyFmt.format(totalOwedToOthers), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (widget.debts.isEmpty)
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
                    child: const Text('No debts or credits recorded.'),
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
                      itemCount: widget.debts.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final debt = widget.debts[index];
                        final isOwe = debt.type == DebtType.owe;

                        return ListTile(
                          leading: Checkbox(
                            value: debt.isSettled,
                            onChanged: (_) => widget.onToggleDebtSettled(debt.id),
                          ),
                          title: Text(
                            debt.personName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              decoration: debt.isSettled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            '${isOwe ? 'I owe' : 'Receivable'} • ${debt.notes ?? (debt.dueDate != null ? 'Due: ${DateFormat('d MMM').format(debt.dueDate!)}' : '')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currencyFmt.format(debt.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: debt.isSettled
                                      ? Colors.grey
                                      : (isOwe ? Colors.orange.shade700 : const Color(0xFF10B981)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                onPressed: () => widget.onDeleteDebt(debt.id),
                                tooltip: 'Delete Record',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
