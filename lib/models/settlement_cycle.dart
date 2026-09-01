import 'user_role.dart';

class SettlementCycle {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final bool isClosed;
  final DateTime? closedAt;
  final UserRole? closedBy;

  SettlementCycle({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.isClosed = false,
    this.closedAt,
    this.closedBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'isClosed': isClosed,
        'closedAt': closedAt?.toIso8601String(),
        'closedBy': closedBy?.name,
      };

  factory SettlementCycle.fromJson(Map<String, dynamic> json) =>
      SettlementCycle(
        id: json['id'] as String,
        title: json['title'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        isClosed: json['isClosed'] as bool? ?? false,
        closedAt: json['closedAt'] != null
            ? DateTime.parse(json['closedAt'] as String)
            : null,
        closedBy: json['closedBy'] != null
            ? UserRole.fromString(json['closedBy'] as String)
            : null,
      );
}

class CycleSummaryReport {
  final SettlementCycle cycle;
  final double totalJointSpend;
  final double totalMotherOutOfPocket;
  final double totalFatherOutOfPocket;
  final double totalHelperOutOfPocket;
  final double totalHelperGroceryCashSpend;
  final double totalCashTopUps;
  final double helperCashBalance;

  // Split calculation between Mother & Father
  // Direct joint spend is 50/50 funded.
  // Out of pocket spend net settlement:
  // Total shared out-of-pocket by parents = Mother OOP + Father OOP
  // Per-parent share = Total shared / 2
  // Mother net balance = Mother OOP - Per-parent share
  // Father net balance = Father OOP - Per-parent share
  // If Mother spent 300 and Father spent 100: Total = 400. Share = 200. Mother net = +100 (she is owed), Father net = -100 (he owes).

  CycleSummaryReport({
    required this.cycle,
    required this.totalJointSpend,
    required this.totalMotherOutOfPocket,
    required this.totalFatherOutOfPocket,
    required this.totalHelperOutOfPocket,
    required this.totalHelperGroceryCashSpend,
    required this.totalCashTopUps,
    required this.helperCashBalance,
  });

  double get totalFamilySpend =>
      totalJointSpend +
      totalMotherOutOfPocket +
      totalFatherOutOfPocket +
      totalHelperOutOfPocket +
      totalHelperGroceryCashSpend;

  double get totalParentsOutOfPocket =>
      totalMotherOutOfPocket + totalFatherOutOfPocket;

  double get parentEqualShare => totalParentsOutOfPocket / 2.0;

  double get motherNetBalance => totalMotherOutOfPocket - parentEqualShare;

  double get fatherNetBalance => totalFatherOutOfPocket - parentEqualShare;

  /// Returns who pays whom and the amount
  Map<String, dynamic> get settlementAction {
    if (motherNetBalance > 0.009) {
      return {
        'from': UserRole.father,
        'to': UserRole.mother,
        'amount': motherNetBalance,
        'message':
            'Father transfers \$${motherNetBalance.toStringAsFixed(2)} to Mother'
      };
    } else if (fatherNetBalance > 0.009) {
      return {
        'from': UserRole.mother,
        'to': UserRole.father,
        'amount': fatherNetBalance,
        'message':
            'Mother transfers \$${fatherNetBalance.toStringAsFixed(2)} to Father'
      };
    } else {
      return {
        'from': null,
        'to': null,
        'amount': 0.0,
        'message': 'All out-of-pocket expenses are perfectly balanced (\$0.00 owed).'
      };
    }
  }
}
