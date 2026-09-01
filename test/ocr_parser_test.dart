import 'package:flutter_test/flutter_test.dart';
import 'package:family_pouch/services/ocr/receipt_parser_rules.dart';

void main() {
  group('ReceiptParserRules Unit Tests', () {
    test('Extracts Total Amount and candidates correctly', () {
      const sampleText = '''
WELLCOME SUPERMARKET
Date: 2026-08-28
Fresh Milk 1L HK\$46.00
Organic Eggs HK\$28.50
SUBTOTAL: HK\$74.50
DISCOUNT: -HK\$5.00
TOTAL AMOUNT: HK\$69.50
PAID BY CASH
''';

      final result = ReceiptParserRules.parse(sampleText);

      expect(result.merchant, 'Wellcome Supermarket');
      expect(result.totalAmount, 69.50);
      expect(result.candidateAmounts, containsAll([46.00, 28.50, 74.50, 69.50]));
      expect(result.category, 'Groceries');
      expect(result.date, DateTime(2026, 8, 28));
    });

    test('Parses various date formats', () {
      const isoText = 'Store XYZ\nDate: 2026-09-01\nTOTAL: \$100.00';
      expect(ReceiptParserRules.parse(isoText).date, DateTime(2026, 9, 1));

      const dmyText = 'Store XYZ\nDate: 25/08/2026\nTOTAL: \$100.00';
      expect(ReceiptParserRules.parse(dmyText).date, DateTime(2026, 8, 25));
    });

    test('Auto-classifies pharmacy merchant and category', () {
      const pharmacyText = '''
WATSONS PHARMACY
Date: 2026-08-29
Panadol Extra HK\$58.00
TOTAL: HK\$58.00
''';

      final result = ReceiptParserRules.parse(pharmacyText);

      expect(result.merchant, 'Watsons Pharmacy');
      expect(result.category, 'Health & Medical');
      expect(result.totalAmount, 58.00);
    });

    test('Parses itemized receipt line items', () {
      const lineItemText = '''
PARKNSHOP SUPERMARKET
Date: 2026-08-30
Organic Broccoli 2x HK\$32.00
Boneless Chicken HK\$48.00
TOTAL: HK\$80.00
''';

      final result = ReceiptParserRules.parse(lineItemText);

      expect(result.lineItems.length, greaterThanOrEqualTo(2));
      expect(result.lineItems.any((i) => i.name.contains('Broccoli') && i.price == 32.00), isTrue);
      expect(result.lineItems.any((i) => i.name.contains('Chicken') && i.price == 48.00), isTrue);
    });
  });
}
