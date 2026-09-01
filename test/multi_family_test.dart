import 'package:flutter_test/flutter_test.dart';
import 'package:family_pouch/models/family_config.dart';

void main() {
  group('Multi-Family Configuration & Isolation Tests', () {
    test('Normalizes family codes correctly', () {
      expect(FamilyConfig.normalizeId('  J4DY  '), 'j4dy');
      expect(FamilyConfig.normalizeId('Smith Family!'), 'smith-family-');
      expect(FamilyConfig.normalizeId('chan_family_123'), 'chan_family_123');
    });

    test('Default family config is j4dy', () {
      final def = FamilyConfig.defaultFamily();
      expect(def.familyId, 'j4dy');
      expect(def.familyName, 'j4dy Family');
      expect(def.currencySymbol, 'HK\$');
    });

    test('Serializes and deserializes FamilyConfig properly', () {
      final config = FamilyConfig(
        familyId: 'smith',
        familyName: 'Smith Household',
        currencySymbol: '\$',
        createdAt: DateTime(2026, 9, 1),
      );

      final json = config.toJson();
      final revived = FamilyConfig.fromJson(json);

      expect(revived.familyId, 'smith');
      expect(revived.familyName, 'Smith Household');
      expect(revived.currencySymbol, '\$');
    });
  });
}
