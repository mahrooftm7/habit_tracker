enum TransactionType { income, expense }

enum PaymentMethod { cash, bank }

class FinancialTransaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final PaymentMethod paymentMethod;
  final String? bankAccountId; // If paymentMethod == PaymentMethod.bank
  final String category;
  final DateTime date;
  final String? notes;

  FinancialTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    this.bankAccountId,
    this.category = 'General',
    DateTime? date,
    this.notes,
  }) : date = date ?? DateTime.now();

  FinancialTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    PaymentMethod? paymentMethod,
    String? bankAccountId,
    String? category,
    DateTime? date,
    String? notes,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'paymentMethod': paymentMethod.name,
      'bankAccountId': bankAccountId,
      'category': category,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    return FinancialTransaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.expense,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      bankAccountId: json['bankAccountId'] as String?,
      category: json['category'] as String? ?? 'General',
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      notes: json['notes'] as String?,
    );
  }
}
