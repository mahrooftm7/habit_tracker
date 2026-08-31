import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_tracker/main.dart';
import 'package:habit_tracker/models/transaction.dart';
import 'package:habit_tracker/services/auth_service.dart';
import 'package:habit_tracker/services/finance_storage_service.dart';
import 'package:habit_tracker/services/habit_storage_service.dart';
import 'package:intl/intl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Habit Tracker loads home dashboard with month selector & active user', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitTrackerApp());
    await tester.pumpAndSettle();

    // Verify user name is displayed
    expect(find.text('Super Admin (Owner)'), findsOneWidget);

    // Verify navigation tabs (Habit Tracker, Analytics, Financial Tracker, Super Admin)
    expect(find.text('Habit Tracker'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Financial Tracker'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);

    // Verify current Month and Year header
    final currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());
    expect(find.text(currentMonthYear), findsOneWidget);

    // Verify current month abbreviation is rendered
    final currentMonthShort = DateFormat('MMM').format(DateTime.now());
    expect(find.text(currentMonthShort), findsOneWidget);
  });

  testWidgets('AuthService allows user registration, login, and switching', (WidgetTester tester) async {
    final authService = AuthService();

    final users = await authService.getAllUsers();
    expect(users.length, greaterThanOrEqualTo(2));

    // Register a new user
    final newUser = await authService.register('John Doe', 'john@example.com', 'password123');
    expect(newUser.name, 'John Doe');
    expect(newUser.email, 'john@example.com');

    // Switch user
    await authService.switchUser(newUser.id);
    final current = await authService.getCurrentUser();
    expect(current?.id, newUser.id);
  });

  testWidgets('HabitStorageService handles saving and updating notes for habits', (WidgetTester tester) async {
    final storage = HabitStorageService();
    final habits = await storage.loadHabits();
    expect(habits, isNotEmpty);

    final habit = habits.first;
    final today = DateTime.now();

    // Add note
    final updatedList = await storage.saveHabitNote(habit.id, today, 'Completed workout with 5km run');
    final updatedHabit = updatedList.firstWhere((h) => h.id == habit.id);
    expect(updatedHabit.hasNoteOn(today), isTrue);
    expect(updatedHabit.getNoteFor(today), 'Completed workout with 5km run');

    // Remove note
    final clearedList = await storage.saveHabitNote(habit.id, today, '');
    final clearedHabit = clearedList.firstWhere((h) => h.id == habit.id);
    expect(clearedHabit.hasNoteOn(today), isFalse);
  });

  testWidgets('FinanceStorageService manages transactions, bank accounts and cash balance', (WidgetTester tester) async {
    final storage = FinanceStorageService();
    final banks = await storage.loadBankAccounts();
    final txs = await storage.loadTransactions();
    final debts = await storage.loadDebts();
    final cash = await storage.loadInitialCashBalance();

    expect(banks, isEmpty);
    expect(txs, isEmpty);
    expect(debts, isEmpty);
    expect(cash, equals(0.0));

    // Add new Income Transaction
    final newTx = FinancialTransaction(
      id: 'test_tx_101',
      title: 'Consulting Fee',
      amount: 5000.0,
      type: TransactionType.income,
      paymentMethod: PaymentMethod.cash,
      category: 'Freelance',
    );

    final updatedTxs = await storage.addTransaction(newTx);
    expect(updatedTxs.any((t) => t.id == 'test_tx_101'), isTrue);
  });
}
