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
import '../models/family_config.dart';

class AccountingRepository extends ChangeNotifier {
  String _familyId = 'j4dy';
  FamilyConfig _familyConfig = FamilyConfig.defaultFamily();
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
  StreamSubscription? _familyConfigSub;

  String get familyId => _familyId;
  FamilyConfig get familyConfig => _familyConfig;
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
    // Check URL parameters for ?family=... if on web
    String initialFamily = 'j4dy';
    if (kIsWeb) {
      try {
        final queryParam = Uri.base.queryParameters['family'];
        if (queryParam != null && queryParam.trim().isNotEmpty) {
          initialFamily = FamilyConfig.normalizeId(queryParam);
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final savedFamily = prefs.getString('fp_active_family_id');
    if (kIsWeb && Uri.base.queryParameters.containsKey('family')) {
      _familyId = initialFamily;
    } else if (savedFamily != null && savedFamily.trim().isNotEmpty) {
      _familyId = FamilyConfig.normalizeId(savedFamily);
    } else {
      _familyId = 'j4dy';
    }

    _familyConfig = FamilyConfig(
      familyId: _familyId,
      familyName: '$_familyId Family',
      createdAt: DateTime.now(),
    );

    await _loadFromLocalStorage();
    _initFirestoreSync();
  }

  /// Switch active family workspace
  Future<void> switchFamily(String newFamilyId, {String? familyName}) async {
    final cleanId = FamilyConfig.normalizeId(newFamilyId);
    if (cleanId.isEmpty || cleanId == _familyId) return;

    _familyId = cleanId;
    _familyConfig = FamilyConfig(
      familyId: cleanId,
      familyName: familyName ?? '$cleanId Family',
      createdAt: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fp_active_family_id', cleanId);

    // Cancel old streams
    await _cancelFirestoreSubscriptions();

    // Reset collections & load new family data
    _expenses = [];
    _cashTopUps = [];
    _claims = [];
    final def = createDefaultCurrentCycle();
    _cycles = [def];
    _selectedCycleId = def.id;

    await _loadFromLocalStorage();
    _initFirestoreSync();
    notifyListeners();
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

  // --- Real-time Firestore Sync Engine (Scoped by Family ID) ---

  DocumentReference<Map<String, dynamic>> get _familyDoc =>
      FirebaseFirestore.instance.collection('families').doc(_familyId);

  CollectionReference<Map<String, dynamic>> get _expensesCollection =>
      _familyDoc.collection('expenses');

  CollectionReference<Map<String, dynamic>> get _topUpsCollection =>
      _familyDoc.collection('topups');

  CollectionReference<Map<String, dynamic>> get _claimsCollection =>
      _familyDoc.collection('claims');

  CollectionReference<Map<String, dynamic>> get _cyclesCollection =>
      _familyDoc.collection('cycles');

  Future<void> _cancelFirestoreSubscriptions() async {
    await _expensesSub?.cancel();
    await _topUpsSub?.cancel();
    await _claimsSub?.cancel();
    await _cyclesSub?.cancel();
    await _familyConfigSub?.cancel();
  }

  void _initFirestoreSync() {
    try {
      // 0. Family Settings Stream
      _familyConfigSub = _familyDoc.snapshots().listen((doc) {
        if (doc.exists && doc.data() != null) {
          _familyConfig = FamilyConfig.fromJson(doc.data()!);
          notifyListeners();
        } else {
          // Initialize family config doc in Firestore
          _familyDoc.set(_familyConfig.toJson(), SetOptions(merge: true));
        }
      }, onError: (e) {
        debugPrint('Firestore family doc error: $e');
      });

      // 1. Expenses Stream
      _expensesSub = _expensesCollection.snapshots().listen(
        (snapshot) {
          _isUsingFirestore = true;
          _expenses = snapshot.docs.map((doc) {
            return Expense.fromJson(doc.data());
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
      _topUpsSub = _topUpsCollection.snapshots().listen(
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
      _claimsSub = _claimsCollection.snapshots().listen(
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
      _cyclesSub = _cyclesCollection.snapshots().listen(
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
      await _expensesCollection.doc(expense.id).set(expense.toJson());
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
      await _expensesCollection.doc(updated.id).set(updated.toJson());
    } catch (e) {
      debugPrint('Firestore updateExpense fallback: $e');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    _expenses.removeWhere((e) => e.id == expenseId);
    _saveToLocalStorage();
    notifyListeners();

    try {
      await _expensesCollection.doc(expenseId).delete();
    } catch (e) {
      debugPrint('Firestore deleteExpense fallback: $e');
    }
  }

  Future<void> addCashTopUp(CashTopUp topUp) async {
    _cashTopUps.insert(0, topUp);
    _saveToLocalStorage();
    notifyListeners();

    try {
      await _topUpsCollection.doc(topUp.id).set(topUp.toJson());
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
          _expensesCollection.doc(_expenses[i].id).set(_expenses[i].toJson());
        } catch (_) {}
      }
    }

    _saveToLocalStorage();
    notifyListeners();

    try {
      await _claimsCollection.doc(claim.id).set(claim.toJson());
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
          _expensesCollection.doc(_expenses[i].id).set(_expenses[i].toJson());
        } catch (_) {}
      }
    }

    _saveToLocalStorage();
    notifyListeners();

    try {
      await _claimsCollection.doc(updated.id).set(updated.toJson());
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
        await _cyclesCollection.doc(updated.id).set(updated.toJson());
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
      await prefs.remove('fp_family_${_familyId}_expenses');
      await prefs.remove('fp_family_${_familyId}_topups');
      await prefs.remove('fp_family_${_familyId}_claims');
      await prefs.remove('fp_family_${_familyId}_cycles');
    } catch (_) {}

    _saveToLocalStorage();
    notifyListeners();

    try {
      final exps = await _expensesCollection.get();
      for (var d in exps.docs) {
        await d.reference.delete();
      }
      final tops = await _topUpsCollection.get();
      for (var d in tops.docs) {
        await d.reference.delete();
      }
      final clms = await _claimsCollection.get();
      for (var d in clms.docs) {
        await d.reference.delete();
      }
    } catch (e) {
      debugPrint('Firestore clearAllData fallback: $e');
    }
  }

  // --- Local Storage Layer (Scoped by Family ID) ---

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expJson = prefs.getString('fp_family_${_familyId}_expenses');
      final topUpJson = prefs.getString('fp_family_${_familyId}_topups');
      final claimsJson = prefs.getString('fp_family_${_familyId}_claims');
      final cyclesJson = prefs.getString('fp_family_${_familyId}_cycles');

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
          'fp_family_${_familyId}_expenses', jsonEncode(_expenses.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_family_${_familyId}_topups', jsonEncode(_cashTopUps.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_family_${_familyId}_claims', jsonEncode(_claims.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'fp_family_${_familyId}_cycles', jsonEncode(_cycles.map((e) => e.toJson()).toList()));
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
    _familyConfigSub?.cancel();
    super.dispose();
  }
}
