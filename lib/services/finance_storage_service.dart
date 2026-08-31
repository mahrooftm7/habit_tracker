import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bank_account.dart';
import '../models/debt.dart';
import '../models/transaction.dart';
import 'supabase_service.dart';

class FinanceStorageService {

  String _txKey(String? userId) => 'user_finance_tx_${userId ?? 'default'}';
  String _bankKey(String? userId) => 'user_finance_bank_${userId ?? 'default'}';
  String _debtKey(String? userId) => 'user_finance_debt_${userId ?? 'default'}';
  String _cashKey(String? userId) => 'user_finance_cash_${userId ?? 'default'}';

  // --- Transactions ---
  Future<List<FinancialTransaction>> loadTransactions({String? userId}) async {
    final targetUserId = userId ?? 'user_alex_101';
    final cloudTxs = await SupabaseService.instance.fetchTransactions(targetUserId);
    if (cloudTxs != null && cloudTxs.isNotEmpty) {
      await saveTransactions(cloudTxs, userId: targetUserId, syncToCloud: false);
      return cloudTxs;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_txKey(userId));

    if (jsonStr == null || jsonStr.isEmpty) {
      final defaultData = _getInitialTransactions();
      await saveTransactions(defaultData, userId: userId);
      return defaultData;
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((item) => FinancialTransaction.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error decoding transactions for $userId: $e');
      final defaultData = _getInitialTransactions();
      await saveTransactions(defaultData, userId: userId);
      return defaultData;
    }
  }

  Future<void> saveTransactions(List<FinancialTransaction> list, {String? userId, bool syncToCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(list.map((t) => t.toJson()).toList());
    await prefs.setString(_txKey(userId), encoded);

    if (syncToCloud) {
      final targetUserId = userId ?? 'user_alex_101';
      for (final t in list) {
        SupabaseService.instance.upsertTransaction(t, targetUserId);
      }
    }
  }

  Future<List<FinancialTransaction>> addTransaction(FinancialTransaction tx, {String? userId}) async {
    final list = await loadTransactions(userId: userId);
    list.insert(0, tx);
    await saveTransactions(list, userId: userId);
    SupabaseService.instance.upsertTransaction(tx, userId ?? 'user_alex_101');
    return list;
  }

  Future<List<FinancialTransaction>> deleteTransaction(String txId, {String? userId}) async {
    final list = await loadTransactions(userId: userId);
    list.removeWhere((t) => t.id == txId);
    await saveTransactions(list, userId: userId);
    SupabaseService.instance.deleteTransaction(txId);
    return list;
  }

  // --- Bank Accounts ---
  Future<List<BankAccount>> loadBankAccounts({String? userId}) async {
    final targetUserId = userId ?? 'user_alex_101';
    final cloudBanks = await SupabaseService.instance.fetchBankAccounts(targetUserId);
    if (cloudBanks != null && cloudBanks.isNotEmpty) {
      await saveBankAccounts(cloudBanks, userId: targetUserId, syncToCloud: false);
      return cloudBanks;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_bankKey(userId));

    if (jsonStr == null || jsonStr.isEmpty) {
      final defaultData = _getInitialBankAccounts();
      await saveBankAccounts(defaultData, userId: userId);
      return defaultData;
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((item) => BankAccount.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error decoding bank accounts for $userId: $e');
      final defaultData = _getInitialBankAccounts();
      await saveBankAccounts(defaultData, userId: userId);
      return defaultData;
    }
  }

  Future<void> saveBankAccounts(List<BankAccount> list, {String? userId, bool syncToCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(list.map((b) => b.toJson()).toList());
    await prefs.setString(_bankKey(userId), encoded);

    if (syncToCloud) {
      final targetUserId = userId ?? 'user_alex_101';
      for (final b in list) {
        SupabaseService.instance.upsertBankAccount(b, targetUserId);
      }
    }
  }

  Future<List<BankAccount>> addBankAccount(BankAccount bank, {String? userId}) async {
    final list = await loadBankAccounts(userId: userId);
    list.add(bank);
    await saveBankAccounts(list, userId: userId);
    SupabaseService.instance.upsertBankAccount(bank, userId ?? 'user_alex_101');
    return list;
  }

  Future<List<BankAccount>> deleteBankAccount(String bankId, {String? userId}) async {
    final list = await loadBankAccounts(userId: userId);
    list.removeWhere((b) => b.id == bankId);
    await saveBankAccounts(list, userId: userId);
    SupabaseService.instance.deleteBankAccount(bankId);
    return list;
  }

  // --- Debts & Receivables ---
  Future<List<Debt>> loadDebts({String? userId}) async {
    final targetUserId = userId ?? 'user_alex_101';
    final cloudDebts = await SupabaseService.instance.fetchDebts(targetUserId);
    if (cloudDebts != null && cloudDebts.isNotEmpty) {
      await saveDebts(cloudDebts, userId: targetUserId, syncToCloud: false);
      return cloudDebts;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_debtKey(userId));

    if (jsonStr == null || jsonStr.isEmpty) {
      final defaultData = _getInitialDebts();
      await saveDebts(defaultData, userId: userId);
      return defaultData;
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((item) => Debt.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error decoding debts for $userId: $e');
      final defaultData = _getInitialDebts();
      await saveDebts(defaultData, userId: userId);
      return defaultData;
    }
  }

  Future<void> saveDebts(List<Debt> list, {String? userId, bool syncToCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(list.map((d) => d.toJson()).toList());
    await prefs.setString(_debtKey(userId), encoded);

    if (syncToCloud) {
      final targetUserId = userId ?? 'user_alex_101';
      for (final d in list) {
        SupabaseService.instance.upsertDebt(d, targetUserId);
      }
    }
  }

  Future<List<Debt>> addDebt(Debt debt, {String? userId}) async {
    final list = await loadDebts(userId: userId);
    list.insert(0, debt);
    await saveDebts(list, userId: userId);
    SupabaseService.instance.upsertDebt(debt, userId ?? 'user_alex_101');
    return list;
  }

  Future<List<Debt>> toggleDebtSettled(String debtId, {String? userId}) async {
    final list = await loadDebts(userId: userId);
    final idx = list.indexWhere((d) => d.id == debtId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isSettled: !list[idx].isSettled);
      await saveDebts(list, userId: userId);
      SupabaseService.instance.upsertDebt(list[idx], userId ?? 'user_alex_101');
    }
    return list;
  }

  Future<List<Debt>> deleteDebt(String debtId, {String? userId}) async {
    final list = await loadDebts(userId: userId);
    list.removeWhere((d) => d.id == debtId);
    await saveDebts(list, userId: userId);
    SupabaseService.instance.deleteDebt(debtId);
    return list;
  }

  // --- Initial Cash Balance ---
  Future<double> loadInitialCashBalance({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_cashKey(userId)) ?? 0.00;
  }

  Future<void> saveInitialCashBalance(double amount, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cashKey(userId), amount);
  }

  // --- Seed Data (Clean Zero Slate) ---
  List<BankAccount> _getInitialBankAccounts() {
    return [];
  }

  List<FinancialTransaction> _getInitialTransactions() {
    return [];
  }

  List<Debt> _getInitialDebts() {
    return [];
  }
}
