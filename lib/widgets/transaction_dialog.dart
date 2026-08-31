import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/bank_account.dart';
import '../models/transaction.dart';

class TransactionDialog extends StatefulWidget {
  final List<BankAccount> bankAccounts;
  final List<String>? customCategories;
  final Function(FinancialTransaction) onSave;

  const TransactionDialog({
    super.key,
    required this.bankAccounts,
    this.customCategories,
    required this.onSave,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  TransactionType _type = TransactionType.expense;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  String? _selectedBankAccountId;
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _category = 'General';
  DateTime _selectedDate = DateTime.now();

  static const List<String> _incomeCategories = [
    'Salary',
    'Freelance',
    'Investments',
    'Gift / Bonus',
    'Other Income',
  ];

  static const List<String> _expenseCategories = [
    'Food & Groceries',
    'Shopping',
    'Bills & Utilities',
    'Transport / Fuel',
    'Entertainment',
    'Health & Medical',
    'Education',
    'Other Expense',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.bankAccounts.isNotEmpty) {
      _selectedBankAccountId = widget.bankAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text.trim());
      final newTx = FinancialTransaction(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        paymentMethod: _paymentMethod,
        bankAccountId: _paymentMethod == PaymentMethod.bank ? _selectedBankAccountId : null,
        category: _category,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      widget.onSave(newTx);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final customCats = widget.customCategories ?? [];
    final defaultList = _type == TransactionType.income ? _incomeCategories : _expenseCategories;
    final List<String> categories = [
      ...defaultList,
      ...customCats.where((c) => !defaultList.any((d) => d.toLowerCase() == c.toLowerCase())),
    ];
    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Text(
                  'Record Transaction',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Income vs Expense Segmented Control
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Expense'),
                          ],
                        ),
                        selected: _type == TransactionType.expense,
                        selectedColor: Colors.red.shade400,
                        labelStyle: TextStyle(
                          color: _type == TransactionType.expense ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _type = TransactionType.expense;
                              _category = _expenseCategories.first;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Income'),
                          ],
                        ),
                        selected: _type == TransactionType.income,
                        selectedColor: const Color(0xFF10B981),
                        labelStyle: TextStyle(
                          color: _type == TransactionType.income ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _type = TransactionType.income;
                              _category = _incomeCategories.first;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter amount';
                    if (double.tryParse(val.trim()) == null) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Title
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Title / Description',
                    hintText: _type == TransactionType.income ? 'e.g. Salary, Client Payout' : 'e.g. Groceries, Restaurant',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter title';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Payment Method (Cash vs Bank)
                Text(
                  'Payment Account / Mode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.payments_rounded, size: 16),
                        label: const Text('Cash'),
                        selected: _paymentMethod == PaymentMethod.cash,
                        onSelected: (val) {
                          if (val) setState(() => _paymentMethod = PaymentMethod.cash);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.account_balance_rounded, size: 16),
                        label: const Text('Bank Account'),
                        selected: _paymentMethod == PaymentMethod.bank,
                        onSelected: (val) {
                          if (val) setState(() => _paymentMethod = PaymentMethod.bank);
                        },
                      ),
                    ),
                  ],
                ),

                // Bank Account Selector if PaymentMethod == Bank
                if (_paymentMethod == PaymentMethod.bank) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBankAccountId,
                    decoration: InputDecoration(
                      labelText: 'Select Bank Account',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: widget.bankAccounts.map((b) {
                      return DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBankAccountId = val;
                      });
                    },
                    validator: (val) {
                      if (_paymentMethod == PaymentMethod.bank && (val == null || val.isEmpty)) {
                        return 'Select a bank account';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 14),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: categories.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 14),

                // Date Picker Tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: const Text('Transaction Date', style: TextStyle(fontSize: 14)),
                  subtitle: Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _type == TransactionType.income ? const Color(0xFF10B981) : theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _submit,
                      child: Text(_type == TransactionType.income ? 'Add Income' : 'Add Expense'),
                    ),
                  ],
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
