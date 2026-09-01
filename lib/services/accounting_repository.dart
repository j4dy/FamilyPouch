import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isUsingFirestore = false;

  StreamSubscription? _expensesSub;
  StreamSubscription? _topUpsSub;
  StreamSubscription? _claimsSub;
  StreamSubscription? _cyclesSub;

  UserRole get currentUser => _currentUser;
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<CashTopUp> get cashTopUps => List.unmodifiable(_cashTopUps);
  List<ReimbursementClaim> get claims => List.unmodifiable(_claims);
  List<SettlementCycle> get cycles => List.unmodifiable(_cycles);
  String get selectedCycleId => _selectedCycleId;
  bool get isInitialized => _isInitialized;
  bool get isUsingFirestore => _isUsingFirestore;

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
    _initRepository();
  }

  Future<void> _initRepository() async {
    await _loadFromLocalStorage();
    _initFirestoreSync();
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

  // --- Real-time Firestore Sync Engine ---

  void _initFirestoreSync() {
    try {
      final db = FirebaseFirestore.instance;

      // 1. Expenses Stream
      _expensesSub = db.collection('family_expenses').snapshots().listen(
        (snapshot) {
          _isUsingFirestore = true;
          _expenses = snapshot.docs.map((doc) {
            final data = doc.data();
            return Expense.fromJson(data);
          }).toList();
          _expenses.sort((a, b) => b.date.compareTo(a.date));
          _saveToLocalStorage();
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firestore expenses stream error: $e');
        },
      );

      // 2. Cash Top-ups Stream
      _topUpsSub = db.collection('family_topups').snapshots().listen(
        (snapshot) {
          _isUsingFirestore = true;
          _cashTopUps = snapshot.docs.map((doc) {
            return CashTopUp.fromJson(doc.data());
          }).toList();
          _cashTopUps.sort((a, b) => b.date.compareTo(a.date));
          _saveToLocalStorage();
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firestore topups stream error: $e');
        },
      );

      // 3. Claims Stream
      _claimsSub = db.collection('family_claims').snapshots().listen(
        (snapshot) {
          _isUsingFirestore = true;
          _claims = snapshot.docs.map((doc) {
            return ReimbursementClaim.fromJson(doc.data());
          }).toList();
          _claims.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
          _saveToLocalStorage();
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firestore claims stream error: $e');
        },
      );

      // 4. Cycles Stream
      _cyclesSub = db.collection('family_cycles').snapshots().listen(
        (snapshot) {
          _isUsingFirestore = true;
          if (snapshot.docs.isNotEmpty) {
            _cycles = snapshot.docs.map((doc) {
              return SettlementCycle.fromJson(doc.data());
            }).toList();
            _cycles.sort((a, b) => b.startDate.compareTo(a.startDate));
            if (!_cycles.any((c) => c.id == _selectedCycleId)) {
              _selectedCycleId = _cycles.first.id;
            }
          }
          _saveToLocalStorage();
          notifyListeners();
        },
        onError: (e) {
          debugPrint('Firestore cycles stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Firestore not yet provisioned: $e');
    }
  }

  // --- Financial Balances & Calculations ---

  double get totalCashTopUpsAmount {
    return _cashTopUps.fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalHelperGroceryCashSpent {
    return _expenses
        .where((e) => e.payer.isHelper && e.paymentSource == PaymentSource.groceryCash)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get helperGroceryCashBalance {
    final bal = totalCashTopUpsAmount - totalHelperGroceryCashSpent;
    return bal > 0 ? bal : 0.0;
  }

  List<ReimbursementClaim> get pendingClaims {
    return _claims.where((c) => c.status == ClaimStatus.pendingApproval).toList();
  }

  List<Expense> get unclaimedExpensesForCurrentUser {
    return _expenses
        .where((e) =>
            e.payer == _currentUser &&
            e.paymentSource == PaymentSource.outOfPocket &&
            e.claimStatus == ClaimStatus.unclaimed)
        .toList();
  }

  List<Expense> get currentCycleExpenses {
    return _expenses.where((e) => e.cycleId == _selectedCycleId).toList();
  }

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

  Future<void> addExpense(Expense expense) async {
    _expenses.insert(0, expense);
    _saveToLocalStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('family_expenses')
          .doc(expense.id)
          .set(expense.toJson());
    } catch (e) {
      debugPrint('Firestore addExpense fallback: $e');
    }
  }

  Future<void> updateExpense(Expense updated) async {
    final idx = _expenses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _expenses[idx] = updated;
      _saveToLocalStorage();
      notifyListeners();
    }

    try {
      await FirebaseFirestore.instance
          .collection('family_expenses')
          .doc(updated.id)
          .set(updated.toJson());
    } catch (e) {
      debugPrint('Firestore updateExpense fallback: $e');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    _expenses.removeWhere((e) => e.id == expenseId);
    _saveToLocalStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('family_expenses')
          .doc(expenseId)
          .delete();
    } catch (e) {
      debugPrint('Firestore deleteExpense fallback: $e');
    }
  }

  Future<void> addCashTopUp(CashTopUp topUp) async {
    _cashTopUps.insert(0, topUp);
    _saveToLocalStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('family_topups')
          .doc(topUp.id)
          .set(topUp.toJson());
    } catch (e) {
      debugPrint('Firestore addCashTopUp fallback: $e');
    }
  }

  Future<void> submitReimbursementClaim({
    required List<String> expenseIds,
    required String notes,
  }) async {
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

    for (int i = 0; i < _expenses.length; i++) {
      if (expenseIds.contains(_expenses[i].id)) {
        _expenses[i] = _expenses[i].copyWith(
          claimStatus: ClaimStatus.pendingApproval,
          claimId: claimId,
        );
        try {
          FirebaseFirestore.instance
              .collection('family_expenses')
              .doc(_expenses[i].id)
              .set(_expenses[i].toJson());
        } catch (_) {}
      }
    }

    _saveToLocalStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('family_claims')
          .doc(claim.id)
          .set(claim.toJson());
    } catch (e) {
      debugPrint('Firestore submitClaim fallback: $e');
    }
  }

  Future<void> settleClaim({
    required String claimId,
    required String? transferProofPhotoBase64,
    required String transferReference,
    required String notes,
  }) async {
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

    for (int i = 0; i < _expenses.length; i++) {
      if (existing.expenseIds.contains(_expenses[i].id)) {
        _expenses[i] = _expenses[i].copyWith(
          claimStatus: ClaimStatus.settled,
        );
        try {
          FirebaseFirestore.instance
              .collection('family_expenses')
              .doc(_expenses[i].id)
              .set(_expenses[i].toJson());
        } catch (_) {}
      }
    }

    _saveToLocalStorage();
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('family_claims')
          .doc(updated.id)
          .set(updated.toJson());
    } catch (e) {
      debugPrint('Firestore settleClaim fallback: $e');
    }
  }

  Future<void> closeSettlementCycle(String cycleId) async {
    final idx = _cycles.indexWhere((c) => c.id == cycleId);
    if (idx != -1) {
      final existing = _cycles[idx];
      final updated = SettlementCycle(
        id: existing.id,
        title: existing.title,
        startDate: existing.startDate,
        endDate: existing.endDate,
        isClosed: true,
        closedAt: DateTime.now(),
        closedBy: _currentUser,
      );
      _cycles[idx] = updated;
      _saveToLocalStorage();
      notifyListeners();

      try {
        await FirebaseFirestore.instance
          .collection('family_cycles')
          .doc(updated.id)
          .set(updated.toJson());
      } catch (e) {
        debugPrint('Firestore closeCycle fallback: $e');
      }
    }
  }

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

    _saveToLocalStorage();
    notifyListeners();

    try {
      final db = FirebaseFirestore.instance;
      final exps = await db.collection('family_expenses').get();
      for (var d in exps.docs) {
        await d.reference.delete();
      }
      final tops = await db.collection('family_topups').get();
      for (var d in tops.docs) {
        await d.reference.delete();
      }
      final clms = await db.collection('family_claims').get();
      for (var d in clms.docs) {
        await d.reference.delete();
      }
    } catch (e) {
      debugPrint('Firestore clearAllData fallback: $e');
    }
  }

  // --- Local Storage Layer ---

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expJson = prefs.getString('fp_v5_expenses');
      final topUpJson = prefs.getString('fp_v5_topups');
      final claimsJson = prefs.getString('fp_v5_claims');
      final cyclesJson = prefs.getString('fp_v5_cycles');

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

      if (_cycles.isEmpty) {
        _cycles = [createDefaultCurrentCycle()];
      }
      _selectedCycleId = _cycles.first.id;
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

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'fp_v5_expenses', jsonEncode(_expenses.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_v5_topups', jsonEncode(_cashTopUps.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_v5_claims', jsonEncode(_claims.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_v5_cycles', jsonEncode(_cycles.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving storage: $e');
    }
  }

  @override
  void dispose() {
    _expensesSub?.cancel();
    _topUpsSub?.cancel();
    _claimsSub?.cancel();
    _cyclesSub?.cancel();
    super.dispose();
  }
}
