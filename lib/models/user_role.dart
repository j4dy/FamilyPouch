import 'package:flutter/material.dart';

enum UserRole {
  mother,
  father,
  helper;

  String get displayName {
    switch (this) {
      case UserRole.mother:
        return 'Mother';
      case UserRole.father:
        return 'Father';
      case UserRole.helper:
        return 'Helper';
    }
  }

  String get roleTypeLabel {
    switch (this) {
      case UserRole.mother:
      case UserRole.father:
        return 'Employer';
      case UserRole.helper:
        return 'Helper';
    }
  }

  String get emoji {
    switch (this) {
      case UserRole.mother:
        return '👩';
      case UserRole.father:
        return '👨';
      case UserRole.helper:
        return '🧑‍🍳';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.mother:
        return const Color(0xFFEC4899); // Pink
      case UserRole.father:
        return const Color(0xFF3B82F6); // Blue
      case UserRole.helper:
        return const Color(0xFF10B981); // Emerald Green
    }
  }

  bool get isEmployer => this == UserRole.mother || this == UserRole.father;
  bool get isHelper => this == UserRole.helper;

  static UserRole fromString(String val) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => UserRole.mother,
    );
  }
}
