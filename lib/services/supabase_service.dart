import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bank_account.dart';
import '../models/debt.dart';
import '../models/habit.dart';
import '../models/transaction.dart';
import '../models/user.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  // Replace these with your Supabase Project Credentials or pass via main()
  static const String defaultUrl = 'https://egfzwncxqjwgrpoglusq.supabase.co';
  static const String defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnZnp3bmN4cWp3Z3Jwb2dsdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxOTk4MTQsImV4cCI6MjEwMzc3NTgxNH0.HPKcrSv9feDjA-6fkEWm81bPh9TP_fdRPxS-vMlWIU0';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient? _customClient;

  SupabaseClient? get client {
    if (_customClient != null) return _customClient;
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<bool> initialize({String? url, String? anonKey, bool saveCredentials = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final targetUrl = url ?? prefs.getString('supabase_url') ?? defaultUrl;
    final targetKey = anonKey ?? prefs.getString('supabase_anon_key') ?? defaultAnonKey;

    if (targetUrl.contains('YOUR_SUPABASE_PROJECT_ID') || targetKey.isEmpty) {
      debugPrint('Supabase initialized in Offline/Placeholder mode.');
      _isInitialized = false;
      return false;
    }

    try {
      try {
        await Supabase.initialize(
          url: targetUrl,
          anonKey: targetKey,
        );
      } catch (e) {
        debugPrint('Supabase initialize skipped (already initialized): $e');
      }

      _customClient = SupabaseClient(targetUrl, targetKey);
      await _customClient!.from('profiles').select().limit(1);

      _isInitialized = true;
      debugPrint('Supabase initialized and verified successfully!');

      if (saveCredentials) {
        await prefs.setString('supabase_url', targetUrl);
        await prefs.setString('supabase_anon_key', targetKey);
      }
      return true;
    } catch (e) {
      debugPrint('Supabase verification failed ($targetUrl): $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<String> testAndSaveCredentials(String url, String anonKey) async {
    final targetUrl = url.trim();
    final targetKey = anonKey.trim();

    if (targetUrl.isEmpty || targetKey.isEmpty) {
      return 'Please enter both Supabase Project URL and Anon Key.';
    }

    try {
      final testClient = SupabaseClient(targetUrl, targetKey);
      await testClient.from('profiles').select().limit(1);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_url', targetUrl);
      await prefs.setString('supabase_anon_key', targetKey);

      _customClient = testClient;
      _isInitialized = true;

      return 'Connected to Supabase Cloud Database successfully!';
    } catch (e) {
      final err = e.toString();
      debugPrint('Supabase test error: $err');
      _isInitialized = false;

      if (err.contains('401') || err.contains('Unregistered API key') || err.contains('Unauthorized')) {
        return 'Invalid Anon Key or Project URL. Please check your Supabase Project Settings -> API Key.';
      } else if (err.contains('42P01') || err.contains('relation') || err.contains('does not exist')) {
        return 'Database tables missing! Please run supabase_schema.sql in your Supabase SQL Editor.';
      } else {
        return 'Connection failed: ${err.length > 90 ? err.substring(0, 90) : err}';
      }
    }
  }

  // --- Profile Sync ---
  Future<void> syncUserProfile(AppUser user) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('profiles').upsert({
        'user_id': user.id,
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
        'role': user.role,
        'status': user.status,
        'last_login_at': user.lastLoginAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Supabase syncUserProfile error: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> fetchAllUserProfiles() async {
    if (!_isInitialized || client == null) return null;
    try {
      final response = await client!.from('profiles').select().order('created_at', ascending: false);
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Supabase fetchAllUserProfiles error: $e');
      return null;
    }
  }

  // --- Habits Cloud Operations ---
  Future<List<Habit>?> fetchHabits(String userId) async {
    if (!_isInitialized || client == null) return null;
    try {
      final response = await client!.from('habits').select().eq('user_id', userId);
      final List<dynamic> data = response as List<dynamic>;
      final List<Habit> result = data.map((json) {
        final completedDatesSet = (json['completed_dates'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{};
        final notesMap = (json['notes_json'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            <String, String>{};

        return Habit(
          id: json['id'] as String,
          title: json['title'] as String,
          description: json['description'] as String? ?? '',
          iconCodePoint: json['icon_code_point'] as int? ??
              int.tryParse(json['icon']?.toString() ?? '') ??
              Icons.check_rounded.codePoint,
          colorValue: json['color_value'] as int? ?? 0xFF10B981,
          category: json['category'] as String? ?? 'General',
          completedDates: completedDatesSet,
          notes: notesMap,
        );
      }).toList();

      return result;
    } catch (e) {
      debugPrint('Supabase fetchHabits error: $e');
      return null;
    }
  }

  Future<void> upsertHabit(Habit habit, String userId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('habits').upsert({
        'id': habit.id,
        'user_id': userId,
        'title': habit.title,
        'description': habit.description,
        'icon': habit.iconCodePoint.toString(),
        'icon_code_point': habit.iconCodePoint,
        'color_value': habit.colorValue,
        'category': habit.category,
        'completed_dates': habit.completedDates.toList(),
        'notes_json': habit.notes,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Supabase upsertHabit error: $e');
    }
  }

  Future<void> deleteHabit(String habitId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('habits').delete().eq('id', habitId);
    } catch (e) {
      debugPrint('Supabase deleteHabit error: $e');
    }
  }

  // --- Financial Transactions Cloud Operations ---
  Future<List<FinancialTransaction>?> fetchTransactions(String userId) async {
    if (!_isInitialized || client == null) return null;
    try {
      final response = await client!
          .from('financial_transactions')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        return FinancialTransaction(
          id: json['id'] as String,
          title: json['title'] as String,
          amount: (json['amount'] as num).toDouble(),
          type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
          paymentMethod: json['payment_method'] == 'cash' ? PaymentMethod.cash : PaymentMethod.bank,
          bankAccountId: json['bank_account_id'] as String?,
          category: json['category'] as String? ?? 'General',
          date: DateTime.parse(json['date'] as String),
          notes: json['notes'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase fetchTransactions error: $e');
      return null;
    }
  }

  Future<void> upsertTransaction(FinancialTransaction tx, String userId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('financial_transactions').upsert({
        'id': tx.id,
        'user_id': userId,
        'title': tx.title,
        'amount': tx.amount,
        'type': tx.type == TransactionType.income ? 'income' : 'expense',
        'payment_method': tx.paymentMethod == PaymentMethod.cash ? 'cash' : 'bank',
        'bank_account_id': tx.bankAccountId,
        'category': tx.category,
        'date': tx.date.toIso8601String(),
        'notes': tx.notes,
      });
    } catch (e) {
      debugPrint('Supabase upsertTransaction error: $e');
    }
  }

  Future<void> deleteTransaction(String txId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('financial_transactions').delete().eq('id', txId);
    } catch (e) {
      debugPrint('Supabase deleteTransaction error: $e');
    }
  }

  // --- Bank Accounts Cloud Operations ---
  Future<List<BankAccount>?> fetchBankAccounts(String userId) async {
    if (!_isInitialized || client == null) return null;
    try {
      final response = await client!.from('bank_accounts').select().eq('user_id', userId);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        return BankAccount(
          id: json['id'] as String,
          name: json['name'] as String,
          accountNumberLast4: json['account_number_last4'] as String,
          initialBalance: (json['initial_balance'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase fetchBankAccounts error: $e');
      return null;
    }
  }

  Future<void> upsertBankAccount(BankAccount bank, String userId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('bank_accounts').upsert({
        'id': bank.id,
        'user_id': userId,
        'name': bank.name,
        'account_number_last4': bank.accountNumberLast4,
        'initial_balance': bank.initialBalance,
      });
    } catch (e) {
      debugPrint('Supabase upsertBankAccount error: $e');
    }
  }

  Future<void> deleteBankAccount(String bankId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('bank_accounts').delete().eq('id', bankId);
    } catch (e) {
      debugPrint('Supabase deleteBankAccount error: $e');
    }
  }

  // --- Debts Cloud Operations ---
  Future<List<Debt>?> fetchDebts(String userId) async {
    if (!_isInitialized || client == null) return null;
    try {
      final response = await client!.from('debts').select().eq('user_id', userId);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        return Debt(
          id: json['id'] as String,
          personName: json['person_name'] as String,
          amount: (json['amount'] as num).toDouble(),
          type: json['type'] == 'owe' ? DebtType.owe : DebtType.receivable,
          dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
          notes: json['notes'] as String?,
          isSettled: json['is_settled'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Supabase fetchDebts error: $e');
      return null;
    }
  }

  Future<void> upsertDebt(Debt debt, String userId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('debts').upsert({
        'id': debt.id,
        'user_id': userId,
        'person_name': debt.personName,
        'amount': debt.amount,
        'type': debt.type == DebtType.owe ? 'owe' : 'receivable',
        'due_date': debt.dueDate?.toIso8601String(),
        'notes': debt.notes,
        'is_settled': debt.isSettled,
      });
    } catch (e) {
      debugPrint('Supabase upsertDebt error: $e');
    }
  }

  Future<void> deleteDebt(String debtId) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('debts').delete().eq('id', debtId);
    } catch (e) {
      debugPrint('Supabase deleteDebt error: $e');
    }
  }
}
