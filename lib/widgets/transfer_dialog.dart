import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/bank_account.dart';
import '../models/transaction.dart';

class TransferDialog extends StatefulWidget {
  final List<BankAccount> bankAccounts;
  final Function(FinancialTransaction) onSaveTransaction;

  const TransferDialog({
    super.key,
    required this.bankAccounts,
    required this.onSaveTransaction,
  });

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  String _fromAccount = 'cash'; // 'cash' or bank account id
  String _toAccount = 'cash';   // 'cash' or bank account id

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default 'from' to cash, and 'to' to first bank account if available
    if (widget.bankAccounts.isNotEmpty) {
      _toAccount = widget.bankAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _swapAccounts() {
    setState(() {
      final temp = _fromAccount;
      _fromAccount = _toAccount;
      _toAccount = temp;
    });
  }

  String _getAccountName(String id) {
    if (id == 'cash') return 'Cash in Hand';
    final bank = widget.bankAccounts.firstWhere(
      (b) => b.id == id,
      orElse: () => BankAccount(
        id: id,
        name: 'Bank Account',
        accountNumberLast4: '',
        initialBalance: 0,
      ),
    );
    return '${bank.name} (*${bank.accountNumberLast4})';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccount == _toAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select different accounts for "From" and "To"'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid transfer amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fromName = _getAccountName(_fromAccount);
    final toName = _getAccountName(_toAccount);
    final notes = _notesController.text.trim().isEmpty
        ? 'Internal transfer from $fromName to $toName'
        : _notesController.text.trim();

    // 1. Outflow Transaction from Source Account
    final outflowTx = FinancialTransaction(
      id: _uuid.v4(),
      title: 'Transfer to $toName',
      amount: amount,
      type: TransactionType.expense,
      paymentMethod: _fromAccount == 'cash' ? PaymentMethod.cash : PaymentMethod.bank,
      bankAccountId: _fromAccount == 'cash' ? null : _fromAccount,
      category: 'Internal Transfer',
      date: _selectedDate,
      notes: notes,
    );

    // 2. Inflow Transaction into Destination Account
    final inflowTx = FinancialTransaction(
      id: _uuid.v4(),
      title: 'Transfer from $fromName',
      amount: amount,
      type: TransactionType.income,
      paymentMethod: _toAccount == 'cash' ? PaymentMethod.cash : PaymentMethod.bank,
      bankAccountId: _toAccount == 'cash' ? null : _toAccount,
      category: 'Internal Transfer',
      date: _selectedDate,
      notes: notes,
    );

    widget.onSaveTransaction(outflowTx);
    widget.onSaveTransaction(inflowTx);

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transferred ₹${amount.toStringAsFixed(2)} from $fromName to $toName'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accountOptions = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: 'cash',
        child: Row(
          children: [
            Icon(Icons.payments_outlined, size: 18, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Cash in Hand'),
          ],
        ),
      ),
      ...widget.bankAccounts.map((b) => DropdownMenuItem(
            value: b.id,
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text('${b.name} (*${b.accountNumberLast4})'),
              ],
            ),
          )),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
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

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Internal Transfer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Move funds between Cash & Bank Accounts',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // From & To Accounts Selection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    // From Account Dropdown
                    DropdownButtonFormField<String>(
                      value: _fromAccount,
                      items: accountOptions,
                      onChanged: (val) {
                        if (val != null) setState(() => _fromAccount = val);
                      },
                      decoration: InputDecoration(
                        labelText: 'Transfer From (Source)',
                        prefixIcon: const Icon(Icons.arrow_upward_rounded, color: Colors.red),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Swap Button
                    Center(
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF6366F1)),
                        onPressed: _swapAccounts,
                        tooltip: 'Swap From and To',
                      ),
                    ),

                    const SizedBox(height: 10),

                    // To Account Dropdown
                    DropdownButtonFormField<String>(
                      value: _toAccount,
                      items: accountOptions,
                      onChanged: (val) {
                        if (val != null) setState(() => _toAccount = val);
                      },
                      decoration: InputDecoration(
                        labelText: 'Transfer To (Destination)',
                        prefixIcon: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Transfer Amount',
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Date Picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF6366F1)),
                          const SizedBox(width: 10),
                          Text(
                            'Date: ${DateFormat('d MMMM yyyy').format(_selectedDate)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Notes / Description
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes / Description (Optional)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text(
                    'Confirm Transfer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
