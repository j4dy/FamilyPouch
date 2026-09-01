import 'package:flutter/material.dart';
import 'user_role.dart';

enum PaymentSource {
  jointAccount,
  outOfPocket,
  groceryCash;

  String get displayName {
    switch (this) {
      case PaymentSource.jointAccount:
        return 'Joint Account';
      case PaymentSource.outOfPocket:
        return 'Out-of-Pocket';
      case PaymentSource.groceryCash:
        return 'Grocery Cash Float';
    }
  }

  String get shortLabel {
    switch (this) {
      case PaymentSource.jointAccount:
        return 'Joint Acct';
      case PaymentSource.outOfPocket:
        return 'Out-of-Pocket';
      case PaymentSource.groceryCash:
        return 'Grocery Cash';
    }
  }

  String get description {
    switch (this) {
      case PaymentSource.jointAccount:
        return 'Paid directly from shared family joint account (no claim needed)';
      case PaymentSource.outOfPocket:
        return 'Paid personally, to be reimbursed / split';
      case PaymentSource.groceryCash:
        return 'Paid from employer-provided cash float';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentSource.jointAccount:
        return Icons.account_balance;
      case PaymentSource.outOfPocket:
        return Icons.credit_card;
      case PaymentSource.groceryCash:
        return Icons.payments_outlined;
    }
  }

  Color get color {
    switch (this) {
      case PaymentSource.jointAccount:
        return const Color(0xFF6366F1); // Indigo
      case PaymentSource.outOfPocket:
        return const Color(0xFFF59E0B); // Amber
      case PaymentSource.groceryCash:
        return const Color(0xFF10B981); // Emerald
    }
  }

  static List<PaymentSource> availableSourcesFor(UserRole role) {
    if (role.isEmployer) {
      return [PaymentSource.jointAccount, PaymentSource.outOfPocket];
    } else {
      return [PaymentSource.groceryCash, PaymentSource.outOfPocket];
    }
  }

  static PaymentSource fromString(String val) {
    return PaymentSource.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => PaymentSource.jointAccount,
    );
  }
}
