enum DebtType {
  owe, // Money I owe to someone else (Payable)
  receivable, // Money someone owes to me (Receivable)
}

class Debt {
  final String id;
  final String personName;
  final double amount;
  final DebtType type;
  final DateTime? dueDate;
  final String? notes;
  final bool isSettled;

  Debt({
    required this.id,
    required this.personName,
    required this.amount,
    required this.type,
    this.dueDate,
    this.notes,
    this.isSettled = false,
  });

  Debt copyWith({
    String? id,
    String? personName,
    double? amount,
    DebtType? type,
    DateTime? dueDate,
    String? notes,
    bool? isSettled,
  }) {
    return Debt(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'type': type.name,
      'dueDate': dueDate?.toIso8601String(),
      'notes': notes,
      'isSettled': isSettled,
    };
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      personName: json['personName'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: DebtType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DebtType.owe,
      ),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      notes: json['notes'] as String?,
      isSettled: json['isSettled'] as bool? ?? false,
    );
  }
}
