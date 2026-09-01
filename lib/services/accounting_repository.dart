import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_role.dart';
import '../models/payment_source.dart';
import '../models/claim_status.dart';
import '../models/expense.dart';
import '../models/cash_topup.dart';
import '../models/reimbursement_claim.dart';
import '../models/settlement_cycle.dart';

class AccountingRepository extends ChangeNotifier {
  UserRole _currentUser = UserRole.mother;
  List<Expense> _expenses = [];
  List<CashTopUp> _cashTopUps = [];
  List<ReimbursementClaim> _claims = [];
  List<SettlementCycle> _cycles = [];
  String _selectedCycleId = '';
  bool _isInitialized = false;

  UserRole get currentUser => _currentUser;
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<CashTopUp> get cashTopUps => List.unmodifiable(_cashTopUps);
  List<ReimbursementClaim> get claims => List.unmodifiable(_claims);
  List<SettlementCycle> get cycles => List.unmodifiable(_cycles);
  String get selectedCycleId => _selectedCycleId;
  bool get isInitialized => _isInitialized;

  static SettlementCycle createDefaultCurrentCycle() {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return SettlementCycle(
      id: 'cycle-${now.year}-${now.month.toString().padLeft(2, '0')}',
      title: '$monthName (Current Cycle)',
      startDate: start,
      endDate: end,
      isClosed: false,
    );
  }

  SettlementCycle get currentCycle {
    if (_cycles.isEmpty) {
      return createDefaultCurrentCycle();
    }
    return _cycles.firstWhere(
      (c) => c.id == _selectedCycleId,
      orElse: () => _cycles.first,
    );
  }

  AccountingRepository() {
    final def = createDefaultCurrentCycle();
    _cycles = [def];
    _selectedCycleId = def.id;
    _loadFromStorage();
  }

  void switchUser(UserRole role) {
    if (_currentUser != role) {
      _currentUser = role;
      notifyListeners();
    }
  }

  void selectCycle(String cycleId) {
    if (_selectedCycleId != cycleId) {
      _selectedCycleId = cycleId;
      notifyListeners();
    }
  }

  // --- Financial Balances & Calculations ---

  /// Total Top-ups given to Helper from Joint Account
  double get totalCashTopUpsAmount {
    return _cashTopUps.fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Total Grocery Cash spent by Helper
  double get totalHelperGroceryCashSpent {
    return _expenses
        .where((e) => e.payer.isHelper && e.paymentSource == PaymentSource.groceryCash)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Remaining Grocery Cash Float held by Helper
  double get helperGroceryCashBalance {
    final bal = totalCashTopUpsAmount - totalHelperGroceryCashSpent;
    return bal > 0 ? bal : 0.0;
  }

  /// Pending out-of-pocket claims awaiting employer settlement
  List<ReimbursementClaim> get pendingClaims {
    return _claims.where((c) => c.status == ClaimStatus.pendingApproval).toList();
  }

  /// Unclaimed out-of-pocket expenses for current user
  List<Expense> get unclaimedExpensesForCurrentUser {
    return _expenses
        .where((e) =>
            e.payer == _currentUser &&
            e.paymentSource == PaymentSource.outOfPocket &&
            e.claimStatus == ClaimStatus.unclaimed)
        .toList();
  }

  /// Current cycle expenses
  List<Expense> get currentCycleExpenses {
    return _expenses.where((e) => e.cycleId == _selectedCycleId).toList();
  }

  /// Generate comprehensive bill split and settlement report
  CycleSummaryReport generateCycleReport({String? cycleId}) {
    final targetId = cycleId ?? _selectedCycleId;
    final cycle = _cycles.firstWhere(
      (c) => c.id == targetId,
      orElse: () => currentCycle,
    );

    final cycleExps = _expenses.where((e) => e.cycleId == targetId).toList();

    final jointSpend = cycleExps
        .where((e) => e.paymentSource == PaymentSource.jointAccount)
        .fold(0.0, (sum, e) => sum + e.amount);

    final motherOOP = cycleExps
        .where((e) =>
            e.payer == UserRole.mother &&
            e.paymentSource == PaymentSource.outOfPocket)
        .fold(0.0, (sum, e) => sum + e.amount);

    final fatherOOP = cycleExps
        .where((e) =>
            e.payer == UserRole.father &&
            e.paymentSource == PaymentSource.outOfPocket)
        .fold(0.0, (sum, e) => sum + e.amount);

    final helperOOP = cycleExps
        .where((e) =>
            e.payer == UserRole.helper &&
            e.paymentSource == PaymentSource.outOfPocket)
        .fold(0.0, (sum, e) => sum + e.amount);

    final helperCashSpend = cycleExps
        .where((e) =>
            e.payer == UserRole.helper &&
            e.paymentSource == PaymentSource.groceryCash)
        .fold(0.0, (sum, e) => sum + e.amount);

    return CycleSummaryReport(
      cycle: cycle,
      totalJointSpend: jointSpend,
      totalMotherOutOfPocket: motherOOP,
      totalFatherOutOfPocket: fatherOOP,
      totalHelperOutOfPocket: helperOOP,
      totalHelperGroceryCashSpend: helperCashSpend,
      totalCashTopUps: totalCashTopUpsAmount,
      helperCashBalance: helperGroceryCashBalance,
    );
  }

  // --- Mutation Methods ---

  void addExpense(Expense expense) {
    _expenses.insert(0, expense);
    _saveToStorage();
    notifyListeners();
  }

  void updateExpense(Expense updated) {
    final idx = _expenses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _expenses[idx] = updated;
      _saveToStorage();
      notifyListeners();
    }
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
    _saveToStorage();
    notifyListeners();
  }

  void addCashTopUp(CashTopUp topUp) {
    _cashTopUps.insert(0, topUp);
    _saveToStorage();
    notifyListeners();
  }

  void submitReimbursementClaim({
    required List<String> expenseIds,
    required String notes,
  }) {
    if (expenseIds.isEmpty) return;

    final claimExpenses =
        _expenses.where((e) => expenseIds.contains(e.id)).toList();
    final totalAmount =
        claimExpenses.fold(0.0, (sum, e) => sum + e.amount);

    final claimId = 'claim-${DateTime.now().millisecondsSinceEpoch}';
    final claim = ReimbursementClaim(
      id: claimId,
      claimant: _currentUser,
      expenseIds: expenseIds,
      totalAmount: totalAmount,
      submittedAt: DateTime.now(),
      status: ClaimStatus.pendingApproval,
      notes: notes,
    );

    _claims.insert(0, claim);

    // Update expense statuses
    for (int i = 0; i < _expenses.length; i++) {
      if (expenseIds.contains(_expenses[i].id)) {
        _expenses[i] = _expenses[i].copyWith(
          claimStatus: ClaimStatus.pendingApproval,
          claimId: claimId,
        );
      }
    }

    _saveToStorage();
    notifyListeners();
  }

  void settleClaim({
    required String claimId,
    required String? transferProofPhotoBase64,
    required String transferReference,
    required String notes,
  }) {
    final claimIdx = _claims.indexWhere((c) => c.id == claimId);
    if (claimIdx == -1) return;

    final existing = _claims[claimIdx];
    final updated = existing.copyWith(
      status: ClaimStatus.settled,
      settledAt: DateTime.now(),
      settledBy: _currentUser,
      transferProofPhotoBase64: transferProofPhotoBase64,
      transferReference: transferReference,
      notes: notes.isNotEmpty ? '${existing.notes} | $notes' : existing.notes,
    );

    _claims[claimIdx] = updated;

    // Mark linked expenses as settled
    for (int i = 0; i < _expenses.length; i++) {
      if (existing.expenseIds.contains(_expenses[i].id)) {
        _expenses[i] = _expenses[i].copyWith(
          claimStatus: ClaimStatus.settled,
        );
      }
    }

    _saveToStorage();
    notifyListeners();
  }

  void closeSettlementCycle(String cycleId) {
    final idx = _cycles.indexWhere((c) => c.id == cycleId);
    if (idx != -1) {
      final existing = _cycles[idx];
      _cycles[idx] = SettlementCycle(
        id: existing.id,
        title: existing.title,
        startDate: existing.startDate,
        endDate: existing.endDate,
        isClosed: true,
        closedAt: DateTime.now(),
        closedBy: _currentUser,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  /// Completely clears all data to start fresh
  Future<void> clearAllData() async {
    _expenses = [];
    _cashTopUps = [];
    _claims = [];
    final def = createDefaultCurrentCycle();
    _cycles = [def];
    _selectedCycleId = def.id;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    _saveToStorage();
    notifyListeners();
  }

  // --- Persistence Layer ---

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final expJson = prefs.getString('fp_expenses');
      final topUpJson = prefs.getString('fp_topups');
      final claimsJson = prefs.getString('fp_claims');
      final cyclesJson = prefs.getString('fp_cycles');

      if (expJson != null) {
        final List list = jsonDecode(expJson);
        _expenses = list.map((e) => Expense.fromJson(e)).toList();
      } else {
        _expenses = [];
      }

      if (topUpJson != null) {
        final List list = jsonDecode(topUpJson);
        _cashTopUps = list.map((e) => CashTopUp.fromJson(e)).toList();
      } else {
        _cashTopUps = [];
      }

      if (claimsJson != null) {
        final List list = jsonDecode(claimsJson);
        _claims = list.map((e) => ReimbursementClaim.fromJson(e)).toList();
      } else {
        _claims = [];
      }

      if (cyclesJson != null) {
        final List list = jsonDecode(cyclesJson);
        _cycles = list.map((e) => SettlementCycle.fromJson(e)).toList();
      } else {
        _cycles = [createDefaultCurrentCycle()];
      }

      // Force purge any legacy mock test data
      _expenses.removeWhere((e) => e.id.startsWith('exp-') || e.cycleId == 'cycle-aug-2026');
      _cashTopUps.removeWhere((t) => t.id.startsWith('topup-'));
      _claims.removeWhere((c) => c.id.startsWith('claim-1') || c.id.startsWith('claim-past-1'));
      _cycles.removeWhere((c) => c.id == 'cycle-aug-2026' || c.id == 'cycle-jul-2026');

      if (_cycles.isEmpty) {
        _cycles = [createDefaultCurrentCycle()];
      }
      _selectedCycleId = _cycles.first.id;

      await _saveToStorage();
    } catch (e) {
      debugPrint('Error loading storage: $e');
      _expenses = [];
      _cashTopUps = [];
      _claims = [];
      final def = createDefaultCurrentCycle();
      _cycles = [def];
      _selectedCycleId = def.id;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fp_clean_v2', true);
      await prefs.setString(
          'fp_expenses', jsonEncode(_expenses.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_topups', jsonEncode(_cashTopUps.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_claims', jsonEncode(_claims.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_cycles', jsonEncode(_cycles.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving storage: $e');
    }
  }
}
