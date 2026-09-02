import 'package:flutter_test/flutter_test.dart';
import 'package:family_pouch/services/ocr/receipt_parser_rules.dart';

void main() {
  group('ReceiptParserRules Unit Tests', () {
    test('Extracts Total Amount, Merchant from header, and candidates correctly', () {
      const sampleText = '''
TRADER JOE'S MARKET
100 Main Street
Date: 2026-08-28
Fresh Milk 1L \$4.50
Organic Eggs \$6.20
SUBTOTAL: \$10.70
DISCOUNT: -\$1.00
TOTAL AMOUNT: \$9.70
PAID BY CASH
''';

      final result = ReceiptParserRules.parse(sampleText);

      expect(result.merchant, "TRADER JOE'S MARKET");
      expect(result.totalAmount, 9.70);
      expect(result.candidateAmounts, containsAll([4.50, 6.20, 10.70, 9.70]));
      expect(result.category, 'Groceries');
      expect(result.date, DateTime(2026, 8, 28));
    });

    test('Parses various date formats', () {
      const isoText = 'Downtown Cafe\nDate: 2026-09-01\nTOTAL: \$100.00';
      expect(ReceiptParserRules.parse(isoText).date, DateTime(2026, 9, 1));

      const dmyText = 'Downtown Cafe\nDate: 25/08/2026\nTOTAL: \$100.00';
      expect(ReceiptParserRules.parse(dmyText).date, DateTime(2026, 8, 25));
    });

    test('Auto-classifies pharmacy merchant and category from text', () {
      const pharmacyText = '''
CARE HEALTH PHARMACY
Date: 2026-08-29
Medicine Paracetamol \$18.00
TOTAL: \$18.00
''';

      final result = ReceiptParserRules.parse(pharmacyText);

      expect(result.merchant, 'CARE HEALTH PHARMACY');
      expect(result.category, 'Health & Medical');
      expect(result.totalAmount, 18.00);
    });

    test('Parses itemized receipt line items', () {
      const lineItemText = '''
ORGANIC GROCERY STORE
Date: 2026-08-30
Organic Broccoli \$12.00
Fresh Chicken \$24.00
TOTAL: \$36.00
''';

      final result = ReceiptParserRules.parse(lineItemText);

      expect(result.lineItems.length, greaterThanOrEqualTo(2));
      expect(result.lineItems.any((i) => i.name.contains('Broccoli') && i.price == 12.00), isTrue);
      expect(result.lineItems.any((i) => i.name.contains('Chicken') && i.price == 24.00), isTrue);
    });
  });
}
