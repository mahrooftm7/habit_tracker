class BankAccount {
  final String id;
  final String name; // e.g., 'HDFC Bank', 'State Bank of India', 'Chase'
  final String? accountNumberLast4;
  final double initialBalance;

  BankAccount({
    required this.id,
    required this.name,
    this.accountNumberLast4,
    this.initialBalance = 0.0,
  });

  BankAccount copyWith({
    String? id,
    String? name,
    String? accountNumberLast4,
    double? initialBalance,
  }) {
    return BankAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
      initialBalance: initialBalance ?? this.initialBalance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'accountNumberLast4': accountNumberLast4,
      'initialBalance': initialBalance,
    };
  }

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      accountNumberLast4: json['accountNumberLast4'] as String?,
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
