import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/bank_account.dart';

class BankAccountDialog extends StatefulWidget {
  final Function(BankAccount) onSave;

  const BankAccountDialog({super.key, required this.onSave});

  @override
  State<BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<BankAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _last4Controller = TextEditingController();
  final TextEditingController _balanceController = TextEditingController(text: '0');

  @override
  void dispose() {
    _nameController.dispose();
    _last4Controller.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final initBal = double.tryParse(_balanceController.text.trim()) ?? 0.0;
      final newBank = BankAccount(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        accountNumberLast4: _last4Controller.text.trim().isEmpty ? null : _last4Controller.text.trim(),
        initialBalance: initBal,
      );

      widget.onSave(newBank);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
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

              Text(
                'Add Bank Account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Bank Name',
                  hintText: 'e.g. HDFC Bank, SBI Account B',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter bank name';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _last4Controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: 'Last 4 Digits (Optional)',
                  hintText: 'e.g. 4821',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Opening Balance',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter opening balance';
                  if (double.tryParse(val.trim()) == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _submit,
                    child: const Text('Save Bank Account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
