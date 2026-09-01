import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/bank_account.dart';
import 'models/debt.dart';
import 'models/habit.dart';
import 'models/transaction.dart';
import 'models/user.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/home_screen.dart';
import 'screens/payment_expired_screen.dart';
import 'services/auth_service.dart';
import 'services/finance_storage_service.dart';
import 'services/habit_storage_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SupabaseService.instance.initialize();
  runApp(const HabitTrackerApp());
}

class HabitTrackerApp extends StatefulWidget {
  const HabitTrackerApp({super.key});

  @override
  State<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends State<HabitTrackerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final AuthService _authService = AuthService();
  AppUser? _currentUser;
  bool _isAuthLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _isAuthLoading = false;
    });
  }

  void _onAuthenticated(AppUser user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _onLogout() async {
    await _authService.logout();
    setState(() {
      _currentUser = null;
    });
  }

  void _onAddNewAccount() {
    setState(() {
      _currentUser = null;
    });
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TYM Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _isAuthLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _currentUser == null
              ? AuthScreen(
                  onAuthenticated: _onAuthenticated,
                )
              : _currentUser!.isDisabled
                  ? _buildAccountDisabledScreen(context)
                  : _currentUser!.isExpired
                      ? PaymentExpiredScreen(
                          user: _currentUser!,
                          onLogout: _onLogout,
                          onUserUpdated: _onAuthenticated,
                        )
                      : MainNavigationContainer(
                          key: ValueKey(_currentUser!.id),
                          currentUser: _currentUser!,
                          onToggleTheme: _toggleTheme,
                          themeMode: _themeMode,
                          onUserSwitched: _onAuthenticated,
                          onLogout: _onLogout,
                          onAddNewAccount: _onAddNewAccount,
                        ),
    );
  }

  Widget _buildAccountDisabledScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                'Account Suspended',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account (${_currentUser?.email}) has been disabled by the Super Admin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please contact the application owner/administrator for support.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Back to Login'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final Function(AppUser) onUserSwitched;
  final VoidCallback onLogout;
  final VoidCallback onAddNewAccount;

  const MainNavigationContainer({
    super.key,
    required this.currentUser,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onUserSwitched,
    required this.onLogout,
    required this.onAddNewAccount,
  });

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  final HabitStorageService _habitStorage = HabitStorageService();
  final FinanceStorageService _financeStorage = FinanceStorageService();
  Timer? _syncTimer;
  final List<StreamSubscription> _streamSubscriptions = [];

  List<Habit> _habits = [];
  List<FinancialTransaction> _transactions = [];
  List<BankAccount> _bankAccounts = [];
  List<Debt> _debts = [];
  double _initialCashBalance = 1500.0;

  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _setupRealtimeSubscriptions();
    _startPeriodicSync();
  }

  void _setupRealtimeSubscriptions() {
    for (var sub in _streamSubscriptions) {
      sub.cancel();
    }
    _streamSubscriptions.clear();

    if (SupabaseService.instance.isInitialized) {
      final userId = widget.currentUser.id;

      _streamSubscriptions.add(
        SupabaseService.instance.streamHabits(userId).listen((habits) {
          if (mounted) {
            setState(() {
              _habits = habits;
            });
            _habitStorage.saveHabits(habits, userId: userId, syncToCloud: false);
          }
        }),
      );

      _streamSubscriptions.add(
        SupabaseService.instance.streamTransactions(userId).listen((txs) {
          if (mounted) {
            setState(() {
              _transactions = txs;
            });
            _financeStorage.saveTransactions(txs, userId: userId, syncToCloud: false);
          }
        }),
      );

      _streamSubscriptions.add(
        SupabaseService.instance.streamBankAccounts(userId).listen((banks) {
          if (mounted) {
            setState(() {
              _bankAccounts = banks;
            });
            _financeStorage.saveBankAccounts(banks, userId: userId, syncToCloud: false);
          }
        }),
      );

      _streamSubscriptions.add(
        SupabaseService.instance.streamDebts(userId).listen((debts) {
          if (mounted) {
            setState(() {
              _debts = debts;
            });
            _financeStorage.saveDebts(debts, userId: userId, syncToCloud: false);
          }
        }),
      );
    }
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (SupabaseService.instance.isInitialized && mounted) {
        _refreshCloudDataSilently();
      }
    });
  }

  Future<void> _refreshCloudDataSilently() async {
    final habits = await _habitStorage.loadHabits(userId: widget.currentUser.id);
    final txs = await _financeStorage.loadTransactions(userId: widget.currentUser.id);
    final banks = await _financeStorage.loadBankAccounts(userId: widget.currentUser.id);
    final debts = await _financeStorage.loadDebts(userId: widget.currentUser.id);

    if (mounted) {
      setState(() {
        _habits = habits;
        _transactions = txs;
        _bankAccounts = banks;
        _debts = debts;
      });
    }
  }

  @override
  void dispose() {
    for (var sub in _streamSubscriptions) {
      sub.cancel();
    }
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainNavigationContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id) {
      _loadAllData();
      _setupRealtimeSubscriptions();
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });
    final habits = await _habitStorage.loadHabits(userId: widget.currentUser.id);
    final txs = await _financeStorage.loadTransactions(userId: widget.currentUser.id);
    final banks = await _financeStorage.loadBankAccounts(userId: widget.currentUser.id);
    final debts = await _financeStorage.loadDebts(userId: widget.currentUser.id);
    final cash = await _financeStorage.loadInitialCashBalance(userId: widget.currentUser.id);

    setState(() {
      _habits = habits;
      _transactions = txs;
      _bankAccounts = banks;
      _debts = debts;
      _initialCashBalance = cash;
      _isLoading = false;
    });
  }

  // --- Habit Handlers ---
  Future<void> _addHabit(Habit habit) async {
    final updated = await _habitStorage.addHabit(habit, userId: widget.currentUser.id);
    setState(() => _habits = updated);
  }

  Future<void> _updateHabit(Habit habit) async {
    final updated = await _habitStorage.updateHabit(habit, userId: widget.currentUser.id);
    setState(() => _habits = updated);
  }

  Future<void> _deleteHabit(String habitId) async {
    final updated = await _habitStorage.deleteHabit(habitId, userId: widget.currentUser.id);
    setState(() => _habits = updated);
  }

  Future<void> _toggleHabit(String habitId, DateTime date) async {
    final updated = await _habitStorage.toggleHabitCompletion(habitId, date, userId: widget.currentUser.id);
    setState(() => _habits = updated);
  }

  Future<void> _saveNote(String habitId, DateTime date, String note) async {
    final updated = await _habitStorage.saveHabitNote(habitId, date, note, userId: widget.currentUser.id);
    setState(() => _habits = updated);
  }

  // --- Finance Handlers ---
  Future<void> _addTransaction(FinancialTransaction tx) async {
    final updated = await _financeStorage.addTransaction(tx, userId: widget.currentUser.id);
    setState(() => _transactions = updated);
  }

  Future<void> _deleteTransaction(String txId) async {
    final updated = await _financeStorage.deleteTransaction(txId, userId: widget.currentUser.id);
    setState(() => _transactions = updated);
  }

  Future<void> _addBankAccount(BankAccount bank) async {
    final updated = await _financeStorage.addBankAccount(bank, userId: widget.currentUser.id);
    setState(() => _bankAccounts = updated);
  }

  Future<void> _deleteBankAccount(String bankId) async {
    final updated = await _financeStorage.deleteBankAccount(bankId, userId: widget.currentUser.id);
    setState(() => _bankAccounts = updated);
  }

  Future<void> _addDebt(Debt debt) async {
    final updated = await _financeStorage.addDebt(debt, userId: widget.currentUser.id);
    setState(() => _debts = updated);
  }

  Future<void> _toggleDebtSettled(String debtId) async {
    final updated = await _financeStorage.toggleDebtSettled(debtId, userId: widget.currentUser.id);
    setState(() => _debts = updated);
  }

  Future<void> _deleteDebt(String debtId) async {
    final updated = await _financeStorage.deleteDebt(debtId, userId: widget.currentUser.id);
    setState(() => _debts = updated);
  }

  Future<void> _updateCashBalance(double amount) async {
    await _financeStorage.saveInitialCashBalance(amount, userId: widget.currentUser.id);
    setState(() => _initialCashBalance = amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Loading data for ${widget.currentUser.name}...'),
            ],
          ),
        ),
      );
    }

    final screens = [
      HomeScreen(
        currentUser: widget.currentUser,
        habits: _habits,
        onAddHabit: _addHabit,
        onUpdateHabit: _updateHabit,
        onDeleteHabit: _deleteHabit,
        onToggleHabit: _toggleHabit,
        onSaveNote: _saveNote,
        onUserSwitched: widget.onUserSwitched,
        onLogout: widget.onLogout,
        onAddNewAccount: widget.onAddNewAccount,
      ),
      AnalyticsScreen(
        habits: _habits,
        transactions: _transactions,
        bankAccounts: _bankAccounts,
      ),
      FinanceScreen(
        userId: widget.currentUser.id,
        transactions: _transactions,
        bankAccounts: _bankAccounts,
        debts: _debts,
        initialCashBalance: _initialCashBalance,
        onAddTransaction: _addTransaction,
        onDeleteTransaction: _deleteTransaction,
        onAddBankAccount: _addBankAccount,
        onDeleteBankAccount: _deleteBankAccount,
        onAddDebt: _addDebt,
        onToggleDebtSettled: _toggleDebtSettled,
        onDeleteDebt: _deleteDebt,
        onUpdateCashBalance: _updateCashBalance,
      ),
      if (widget.currentUser.isAdmin)
        AdminDashboardScreen(
          currentUser: widget.currentUser,
          onLogout: widget.onLogout,
        ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        elevation: 0,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.check_box_outlined),
            selectedIcon: Icon(Icons.check_box_rounded, color: Color(0xFF6366F1)),
            label: 'Habit Tracker',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF6366F1)),
            label: 'Analytics',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0D9488)),
            label: 'Financial Tracker',
          ),
          if (widget.currentUser.isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6)),
              label: 'Super Admin',
            ),
        ],
      ),
    );
  }
}
