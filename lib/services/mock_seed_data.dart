import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/cash_topup.dart';
import '../models/reimbursement_claim.dart';
import '../models/settlement_cycle.dart';

class MockSeedData {
  static List<SettlementCycle> get initialCycles {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return [
      SettlementCycle(
        id: 'cycle-${now.year}-${now.month.toString().padLeft(2, '0')}',
        title: '$monthName (Current Cycle)',
        startDate: start,
        endDate: end,
        isClosed: false,
      ),
    ];
  }

  static List<CashTopUp> get initialTopUps => [];

  static List<Expense> get initialExpenses => [];

  static List<ReimbursementClaim> get initialClaims => [];
}
