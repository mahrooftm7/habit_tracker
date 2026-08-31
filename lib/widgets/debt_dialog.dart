import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/debt.dart';

class DebtDialog extends StatefulWidget {
  final Function(Debt) onSave;

  const DebtDialog({super.key, required this.onSave});

  @override
  State<DebtDialog> createState() => _DebtDialogState();
}

class _DebtDialogState extends State<DebtDialog> {
  final _formKey = GlobalKey<FormState>();
  DebtType _type = DebtType.receivable; // Receivable = someone owes me
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _dueDate;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text.trim());
      final newDebt = Debt(
        id: const Uuid().v4(),
        personName: _personController.text.trim(),
        amount: amount,
        type: _type,
        dueDate: _dueDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      widget.onSave(newDebt);
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

                Text(
                  'Record Credit / Debt',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Type Choice Chips
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call_received_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('Receivable (They owe me)'),
                          ],
                        ),
                        selected: _type == DebtType.receivable,
                        selectedColor: const Color(0xFF10B981),
                        labelStyle: TextStyle(
                          color: _type == DebtType.receivable ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _type = DebtType.receivable);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call_made_rounded, size: 16),
                            SizedBox(width: 4),
                            Text('Owe (I owe someone)'),
                          ],
                        ),
                        selected: _type == DebtType.owe,
                        selectedColor: Colors.orange.shade600,
                        labelStyle: TextStyle(
                          color: _type == DebtType.owe ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _type = DebtType.owe);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Person Name
                TextFormField(
                  controller: _personController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Person / Vendor Name',
                    hintText: 'e.g. Rahul, Local Merchant',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter name';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes / Reason (Optional)',
                    hintText: 'e.g. Dinner bill split, Borrowed cash',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // Due Date Picker Tile
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Due Date (Optional)', style: TextStyle(fontSize: 14)),
                  subtitle: Text(_dueDate == null ? 'No due date set' : DateFormat('EEE, d MMM yyyy').format(_dueDate!)),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
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
                        backgroundColor: _type == DebtType.receivable ? const Color(0xFF10B981) : Colors.orange.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _submit,
                      child: Text(_type == DebtType.receivable ? 'Record Receivable' : 'Record Debt'),
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
