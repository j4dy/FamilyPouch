import 'package:flutter/material.dart';

enum ClaimStatus {
  notApplicable, // For Joint Account or Grocery Cash
  unclaimed, // Out-of-pocket, not yet included in any claim
  pendingApproval, // Included in an active claim batch
  settled; // Reimbursed & paid

  String get displayName {
    switch (this) {
      case ClaimStatus.notApplicable:
        return 'Direct Spend';
      case ClaimStatus.unclaimed:
        return 'Unclaimed';
      case ClaimStatus.pendingApproval:
        return 'Claim Pending';
      case ClaimStatus.settled:
        return 'Settled / Reimbursed';
    }
  }

  Color get badgeColor {
    switch (this) {
      case ClaimStatus.notApplicable:
        return Colors.blueGrey;
      case ClaimStatus.unclaimed:
        return const Color(0xFFF59E0B); // Amber
      case ClaimStatus.pendingApproval:
        return const Color(0xFF8B5CF6); // Purple
      case ClaimStatus.settled:
        return const Color(0xFF10B981); // Green
    }
  }

  static ClaimStatus fromString(String val) {
    return ClaimStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => ClaimStatus.unclaimed,
    );
  }
}
