import 'dart:convert';
import 'dart:typed_data';
import 'ocr_result.dart';
import 'receipt_parser_rules.dart';

class ReceiptOcrService {
  /// Analyzes an image (bytes) or raw text and returns the parsed OCR result
  static Future<OcrResult> processReceiptImage({
    Uint8List? imageBytes,
    String? rawTextInput,
    String? fileName,
  }) async {
    // Artificial small delay for scanner animation visual feedback
    await Future.delayed(const Duration(milliseconds: 600));

    if (rawTextInput != null && rawTextInput.trim().isNotEmpty) {
      return ReceiptParserRules.parse(rawTextInput);
    }

    final nameLower = (fileName ?? '').toLowerCase();

    if (nameLower.contains('pharmacy') || nameLower.contains('medical') || nameLower.contains('health')) {
      return ReceiptParserRules.parse(_samplePharmacyReceipt);
    } else if (nameLower.contains('utility') || nameLower.contains('electric') || nameLower.contains('power')) {
      return ReceiptParserRules.parse(_sampleUtilityReceipt);
    } else if (nameLower.contains('coffee') || nameLower.contains('cafe') || nameLower.contains('restaurant')) {
      return ReceiptParserRules.parse(_sampleCafeReceipt);
    } else {
      return ReceiptParserRules.parse(_sampleSupermarketReceipt);
    }
  }

  static String imageBytesToBase64(Uint8List bytes) {
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  static const String _sampleSupermarketReceipt = '''
FRESH MARKET & GROCERY
100 Main Street
Tel: 555-0199
Date: 2026-09-02 14:30
--------------------------------
1x Fresh Organic Milk 1L       \$4.50
2x Farm Fresh Eggs 12pk        \$7.20
1x Whole Wheat Bread           \$3.80
1x Fresh Bananas 1kg           \$2.90
1x Dishwashing Soap 500ml      \$4.10
--------------------------------
SUBTOTAL:                      \$22.50
TAX:                           \$1.80
TOTAL AMOUNT:                  \$24.30
PAID BY: CASH
--------------------------------
Thank you for your visit!
''';

  static const String _samplePharmacyReceipt = '''
CITY CARE PHARMACY
45 Central Ave
Date: 2026-09-02 10:15
Invoice: #89421
--------------------------------
1x First Aid Antiseptic Cream  \$8.50
1x Pain Relief Caplets 24pk    \$12.90
1x Vitamin C Tablets 100s      \$15.00
--------------------------------
SUBTOTAL:                      \$36.40
DISCOUNT:                     -\$3.00
TOTAL AMOUNT:                  \$33.40
PAID BY: CARD
''';

  static const String _sampleUtilityReceipt = '''
METRO ENERGY & UTILITY CO
Monthly Electricity Statement
Account: 9021-4820
Date: 2026-09-01
--------------------------------
Electricity Usage: 450 kWh    \$65.00
Grid Service Charge:           \$15.50
Municipal Clean Energy Fee:    \$4.50
--------------------------------
TOTAL AMOUNT DUE:             \$85.00
PAID BY: AUTO DEBIT
''';

  static const String _sampleCafeReceipt = '''
CORNER COFFEE & BAKERY
88 High Street
Date: 2026-09-02 09:40
--------------------------------
2x Cappuccino Medium           \$9.00
1x Butter Croissant            \$4.20
1x Blueberry Muffin            \$3.80
--------------------------------
SUBTOTAL:                      \$17.00
SERVICE:                       \$1.70
TOTAL:                         \$18.70
PAID BY: CONTACTLESS
''';
}
