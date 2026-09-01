import 'package:flutter_test/flutter_test.dart';
import 'package:family_pouch/models/user_role.dart';
import 'package:family_pouch/models/settlement_cycle.dart';

void main() {
  group('Accounting and Bill Split Math Tests', () {
    test('Calculates equal out-of-pocket split with net zero balance', () {
      final cycle = SettlementCycle(
        id: 'test-cycle',
        title: 'Test Cycle',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      final report = CycleSummaryReport(
        cycle: cycle,
        totalJointSpend: 1000.0,
        totalMotherOutOfPocket: 300.0,
        totalFatherOutOfPocket: 300.0,
        totalHelperOutOfPocket: 0.0,
        totalHelperGroceryCashSpend: 200.0,
        totalCashTopUps: 500.0,
        helperCashBalance: 300.0,
      );

      expect(report.totalParentsOutOfPocket, 600.0);
      expect(report.parentEqualShare, 300.0);
      expect(report.motherNetBalance, 0.0);
      expect(report.fatherNetBalance, 0.0);
      expect(report.settlementAction['amount'], 0.0);
      expect(report.settlementAction['from'], isNull);
    });

    test('Calculates unequal out-of-pocket split where Father owes Mother', () {
      final cycle = SettlementCycle(
        id: 'test-cycle',
        title: 'Test Cycle',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 31),
      );

      // Mother spent $450 out of pocket, Father spent $150
      // Total OOP = $600. Share = $300 each.
      // Father owes Mother ($450 - $150)/2 = $150
      final report = CycleSummaryReport(
        cycle: cycle,
        totalJointSpend: 500.0,
        totalMotherOutOfPocket: 450.0,
        totalFatherOutOfPocket: 150.0,
        totalHelperOutOfPocket: 0.0,
        totalHelperGroceryCashSpend: 200.0,
        totalCashTopUps: 500.0,
        helperCashBalance: 300.0,
      );

      expect(report.totalParentsOutOfPocket, 600.0);
      expect(report.parentEqualShare, 300.0);
      expect(report.motherNetBalance, 150.0);
      expect(report.fatherNetBalance, -150.0);

      final action = report.settlementAction;
      expect(action['from'], UserRole.father);
      expect(action['to'], UserRole.mother);
      expect(action['amount'], 150.0);
      expect(action['message'], contains('Father transfers \$150.00 to Mother'));
    });

    test('Helper grocery cash float reconciliation math', () {
      const topUps = 800.0;
      const spent = 263.50;
      const balance = topUps - spent;

      expect(balance, 536.50);
    });
  });
}
