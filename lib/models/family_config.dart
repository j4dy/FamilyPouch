class FamilyConfig {
  final String familyId;
  final String familyName;
  final String currencySymbol;
  final DateTime createdAt;

  const FamilyConfig({
    required this.familyId,
    required this.familyName,
    this.currencySymbol = 'HK\$',
    required this.createdAt,
  });

  static String normalizeId(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
  }

  static FamilyConfig defaultFamily() {
    return FamilyConfig(
      familyId: 'j4dy',
      familyName: 'j4dy Family',
      currencySymbol: 'HK\$',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'familyId': familyId,
        'familyName': familyName,
        'currencySymbol': currencySymbol,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FamilyConfig.fromJson(Map<String, dynamic> json) => FamilyConfig(
        familyId: json['familyId'] as String? ?? 'j4dy',
        familyName: json['familyName'] as String? ?? 'j4dy Family',
        currencySymbol: json['currencySymbol'] as String? ?? 'HK\$',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
