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
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101';
    final prefs = await SharedPreferences.getInstance();

    List<FinancialTransaction> localTxs = [];
    final String? jsonStr = prefs.getString(_txKey(userId));
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
        localTxs = decoded.map((item) => FinancialTransaction.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error decoding transactions for $userId: $e');
      }
    }

    final cloudTxs = await SupabaseService.instance.fetchTransactions(targetUserId);

    if (cloudTxs != null) {
      final Map<String, FinancialTransaction> txMap = {for (var t in localTxs) t.id: t};
      for (var ct in cloudTxs) {
        txMap[ct.id] = ct;
      }
      final mergedList = txMap.values.toList();
      for (var t in localTxs) {
        if (!cloudTxs.any((ct) => ct.id == t.id)) {
          SupabaseService.instance.upsertTransaction(t, targetUserId);
        }
      }
      final String encoded = jsonEncode(mergedList.map((t) => t.toJson()).toList());
      await prefs.setString(_txKey(userId), encoded);
      return mergedList;
    }

    return localTxs;
  }

  Future<void> saveTransactions(List<FinancialTransaction> list, {String? userId, bool syncToCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(list.map((t) => t.toJson()).toList());
    await prefs.setString(_txKey(userId), encoded);

    if (syncToCloud) {
      final targetUserId = (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101';
      for (final t in list) {
        SupabaseService.instance.upsertTransaction(t, targetUserId);
      }
    }
  }

  Future<List<FinancialTransaction>> addTransaction(FinancialTransaction tx, {String? userId}) async {
    final list = await loadTransactions(userId: userId);
    list.removeWhere((t) => t.id == tx.id);
    list.insert(0, tx);
    await saveTransactions(list, userId: userId);
    SupabaseService.instance.upsertTransaction(tx, (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101');
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
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101';
    final prefs = await SharedPreferences.getInstance();

    List<BankAccount> localBanks = [];
    final String? jsonStr = prefs.getString(_bankKey(userId));
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
        localBanks = decoded.map((item) => BankAccount.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error decoding bank accounts for $userId: $e');
      }
    }

    final cloudBanks = await SupabaseService.instance.fetchBankAccounts(targetUserId);

    if (cloudBanks != null) {
      final Map<String, BankAccount> bankMap = {for (var b in localBanks) b.id: b};
      for (var cb in cloudBanks) {
        bankMap[cb.id] = cb;
      }
      final mergedList = bankMap.values.toList();
      for (var b in localBanks) {
        if (!cloudBanks.any((cb) => cb.id == b.id)) {
          SupabaseService.instance.upsertBankAccount(b, targetUserId);
        }
      }
      final String encoded = jsonEncode(mergedList.map((b) => b.toJson()).toList());
      await prefs.setString(_bankKey(userId), encoded);
      return mergedList;
    }

    return localBanks;
  }

  Future<void> saveBankAccounts(List<BankAccount> list, {String? userId, bool syncToCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(list.map((b) => b.toJson()).toList());
    await prefs.setString(_bankKey(userId), encoded);

    if (syncToCloud) {
      final targetUserId = (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101';
      for (final b in list) {
        SupabaseService.instance.upsertBankAccount(b, targetUserId);
      }
    }
  }

  Future<List<BankAccount>> addBankAccount(BankAccount bank, {String? userId}) async {
    final list = await loadBankAccounts(userId: userId);
    list.removeWhere((b) => b.id == bank.id);
    list.add(bank);
    await saveBankAccounts(list, userId: userId);
    SupabaseService.instance.upsertBankAccount(bank, (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101');
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
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : 'user_alex_101';
    final prefs = await SharedPreferences.getInstance();

    List<Debt> localDebts = [];
    final String? jsonStr = prefs.getString(_debtKey(userId));
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
        localDebts = decoded.map((item) => Debt.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Error decoding debts for $userId: $e');
      }
    }

    final cloudDebts = await SupabaseService.instance.fetchDebts(targetUserId);

    if (cloudDebts != null) {
      final Map<String, Debt> debtMap = {for (var d in localDebts) d.id: d};
      for (var cd in cloudDebts) {
        debtMap[cd.id] = cd;
      }
      final mergedList = debtMap.values.toList();
      for (var d in localDebts) {
        if (!cloudDebts.any((cd) => cd.id == d.id)) {
          SupabaseService.instance.upsertDebt(d, targetUserId);
        }
      }
      final String encoded = jsonEncode(mergedList.map((d) => d.toJson()).toList());
      await prefs.setString(_debtKey(userId), encoded);
      return mergedList;
    }

    return localDebts;
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


}
