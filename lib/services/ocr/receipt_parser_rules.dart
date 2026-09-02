import 'package:intl/intl.dart';
import '../../models/receipt_item.dart';
import 'ocr_result.dart';

class ReceiptParserRules {
  static const List<String> categories = [
    'Groceries',
    'Household Supplies',
    'Dining & Takeout',
    'Kids & Education',
    'Health & Medical',
    'Utilities',
    'Transportation',
    'Home Maintenance',
    'Other'
  ];

  static OcrResult parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? merchant = _detectMerchant(lines, rawText);
    String category = _detectCategory(merchant, rawText);
    DateTime date = _detectDate(rawText) ?? DateTime.now();
    List<double> candidates = _extractCandidateAmounts(rawText);
    double? totalAmount = _detectTotalAmount(lines, candidates);
    List<ReceiptItem> lineItems = _detectLineItems(lines);

    return OcrResult(
      rawText: rawText,
      merchant: merchant ?? (lines.isNotEmpty ? lines.first : 'Local Store'),
      totalAmount: totalAmount ?? (candidates.isNotEmpty ? candidates.last : 0.0),
      candidateAmounts: candidates,
      date: date,
      category: category,
      lineItems: lineItems,
      confidence: 0.95,
    );
  }

  /// Universal Shop / Merchant Name detection
  /// Extracts the business/store name from the top header lines of any receipt worldwide.
  static String? _detectMerchant(List<String> lines, String rawText) {
    final skipPatterns = [
      RegExp(r'^(tax invoice|invoice|receipt|sales receipt|customer copy|merchant copy|order #|order no|ticket|bill)', caseSensitive: false),
      RegExp(r'^(welcome|thank you|thanks for shopping|have a nice day|welcome to)', caseSensitive: false),
      RegExp(r'^(tel:|phone:|call:|fax:|www\.|http|https:|email:|web:)', caseSensitive: false),
      RegExp(r'^(date:|time:|cashier:|terminal:|register:|pos:|store #|table:|guest:)', caseSensitive: false),
      RegExp(r'^(gst reg|vat reg|tax id|ein:|tin:|reg no|abn:)', caseSensitive: false),
      RegExp(r'^[\-\=\*\.\#\_]{3,}$'),
      RegExp(r'^\d+$'), // Only numbers
      RegExp(r'^\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}'), // Dates
    ];

    // Inspect the first 5 lines
    for (int i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i].trim();
      if (line.length < 2) continue;

      bool shouldSkip = false;
      for (var pattern in skipPatterns) {
        if (pattern.hasMatch(line)) {
          shouldSkip = true;
          break;
        }
      }

      // If line contains price only (e.g. $12.50) or addresses with # only
      if (RegExp(r'^[\$\€\£\¥\₹]?\s*\d+(\.\d{2})?$').hasMatch(line)) {
        shouldSkip = true;
      }

      if (!shouldSkip && line.contains(RegExp(r'[a-zA-Z\u4e00-\u9fa5]'))) {
        // Clean leading/trailing punctuation
        return line.replaceAll(RegExp(r'^[\*\#\-\s]+|[\*\#\-\s]+$'), '').trim();
      }
    }

    return lines.isNotEmpty ? lines.first : null;
  }

  /// Universal category detection based on generic item/receipt keywords
  static String _detectCategory(String? merchant, String rawText) {
    final lower = '${merchant ?? ''} $rawText'.toLowerCase();

    // Groceries / Supermarket
    if (lower.contains('supermarket') ||
        lower.contains('grocery') ||
        lower.contains('groceries') ||
        lower.contains('market') ||
        lower.contains('produce') ||
        lower.contains('bakery') ||
        lower.contains('meat') ||
        lower.contains('foods') ||
        lower.contains('fresh') ||
        lower.contains('fruit') ||
        lower.contains('vegetable') ||
        lower.contains('milk') ||
        lower.contains('bread') ||
        lower.contains('organic')) {
      return 'Groceries';
    }

    // Health & Medical / Pharmacy
    if (lower.contains('pharmacy') ||
        lower.contains('chemist') ||
        lower.contains('drugstore') ||
        lower.contains('medical') ||
        lower.contains('clinic') ||
        lower.contains('hospital') ||
        lower.contains('doctor') ||
        lower.contains('health') ||
        lower.contains('medicine') ||
        lower.contains('panadol') ||
        lower.contains('paracetamol') ||
        lower.contains('prescription') ||
        lower.contains('vitamins')) {
      return 'Health & Medical';
    }

    // Dining & Takeout / Restaurants
    if (lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('coffee') ||
        lower.contains('bistro') ||
        lower.contains('diner') ||
        lower.contains('pizzeria') ||
        lower.contains('burger') ||
        lower.contains('kitchen') ||
        lower.contains('takeout') ||
        lower.contains('takeaway') ||
        lower.contains('bar') ||
        lower.contains('tea') ||
        lower.contains('fast food')) {
      return 'Dining & Takeout';
    }

    // Utilities / Bills
    if (lower.contains('electric') ||
        lower.contains('electricity') ||
        lower.contains('power') ||
        lower.contains('water') ||
        lower.contains('gas') ||
        lower.contains('utility') ||
        lower.contains('utilities') ||
        lower.contains('broadband') ||
        lower.contains('telecom') ||
        lower.contains('internet') ||
        lower.contains('mobile bill')) {
      return 'Utilities';
    }

    // Household Supplies / Hardware
    if (lower.contains('household') ||
        lower.contains('hardware') ||
        lower.contains('home centre') ||
        lower.contains('home center') ||
        lower.contains('furnishing') ||
        lower.contains('cleaning') ||
        lower.contains('detergent') ||
        lower.contains('living') ||
        lower.contains('department store')) {
      return 'Household Supplies';
    }

    // Transportation
    if (lower.contains('petrol') ||
        lower.contains('gasoline') ||
        lower.contains('fuel') ||
        lower.contains('taxi') ||
        lower.contains('uber') ||
        lower.contains('grab') ||
        lower.contains('parking') ||
        lower.contains('metro') ||
        lower.contains('subway') ||
        lower.contains('train') ||
        lower.contains('bus fare')) {
      return 'Transportation';
    }

    // Kids & Education
    if (lower.contains('school') ||
        lower.contains('tuition') ||
        lower.contains('stationery') ||
        lower.contains('bookstore') ||
        lower.contains('books') ||
        lower.contains('toys') ||
        lower.contains('kids') ||
        lower.contains('baby')) {
      return 'Kids & Education';
    }

    return 'Groceries';
  }

  /// Universal Total Amount Detection
  /// Finds keywords like Total, Grand Total, Net, Amount Due, etc.
  static double? _detectTotalAmount(List<String> lines, List<double> candidates) {
    final totalKeywords = RegExp(
      r'(total amount due|total amount|grand total|net amount|amount due|balance due|total to pay|total due|total bill|total|net total|montant total|importe total|gesamtbetrag|總計|合計|金額)',
      caseSensitive: false,
    );

    // Scan lines from bottom up (since total is usually near the bottom)
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (totalKeywords.hasMatch(line)) {
        // Look for amount on this line
        final amountMatch = RegExp(r'[\$\€\£\¥\₹]?\s*(\d{1,4}(?:,\d{3})*\.\d{2})').firstMatch(line);
        if (amountMatch != null) {
          final str = amountMatch.group(1)!.replaceAll(',', '');
          final val = double.tryParse(str);
          if (val != null && val > 0) return val;
        }

        // If amount is on the next line (e.g. "TOTAL\n $45.20")
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          final nextMatch = RegExp(r'[\$\€\£\¥\₹]?\s*(\d{1,4}(?:,\d{3})*\.\d{2})').firstMatch(nextLine);
          if (nextMatch != null) {
            final str = nextMatch.group(1)!.replaceAll(',', '');
            final val = double.tryParse(str);
            if (val != null && val > 0) return val;
          }
        }
      }
    }

    // If no keyword match, choose the largest candidate amount (standard total rule)
    if (candidates.isNotEmpty) {
      final sorted = List<double>.from(candidates)..sort();
      return sorted.last;
    }

    return null;
  }

  /// Extracts all numerical currency amounts for candidate chips
  static List<double> _extractCandidateAmounts(String text) {
    final amountPattern = RegExp(r'[\$\€\£\¥\₹]?\s*(\d{1,4}(?:,\d{3})*\.\d{2})\b');
    final matches = amountPattern.allMatches(text);
    final Set<double> results = {};

    for (var match in matches) {
      final raw = match.group(1)!.replaceAll(',', '');
      final val = double.tryParse(raw);
      if (val != null && val > 0 && val < 50000) {
        results.add(val);
      }
    }

    final list = results.toList();
    list.sort();
    return list;
  }

  /// Universal Date Detection
  static DateTime? _detectDate(String text) {
    // YYYY-MM-DD or YYYY/MM/DD
    final isoPattern = RegExp(r'\b(20\d{2})[\-\/\.](0?[1-9]|1[0-2])[\-\/\.](0?[1-9]|[12]\d|3[01])\b');
    final isoMatch = isoPattern.firstMatch(text);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // DD/MM/YYYY or DD-MM-YYYY
    final dmyPattern = RegExp(r'\b(0?[1-9]|[12]\d|3[01])[\-\/\.](0?[1-9]|1[0-2])[\-\/\.](20\d{2})\b');
    final dmyMatch = dmyPattern.firstMatch(text);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      final y = int.parse(dmyMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // Month Name Date: 28 Aug 2026 or Aug 28, 2026
    final monthNamePattern = RegExp(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s\.\,]+(\d{1,2})[\s\.\,]+(20\d{2})\b', caseSensitive: false);
    final monthMatch = monthNamePattern.firstMatch(text);
    if (monthMatch != null) {
      try {
        final raw = '${monthMatch.group(1)} ${monthMatch.group(2)} ${monthMatch.group(3)}';
        return DateFormat('MMM d yyyy').parse(raw);
      } catch (_) {}
    }

    return null;
  }

  /// Universal itemized line item parser
  static List<ReceiptItem> _detectLineItems(List<String> lines) {
    final List<ReceiptItem> items = [];
    final itemLinePattern = RegExp(r'^(\d+x)?\s*([A-Za-z0-9\s\u4e00-\u9fa5\-\/\.\%]+?)\s+[\$\€\£\¥\₹]?\s*(\d+\.\d{2})$');

    for (var line in lines) {
      final match = itemLinePattern.firstMatch(line);
      if (match != null) {
        final qtyStr = match.group(1);
        int qty = 1;
        if (qtyStr != null) {
          qty = int.tryParse(qtyStr.replaceAll('x', '')) ?? 1;
        }
        final name = match.group(2)!.trim();
        final price = double.tryParse(match.group(3)!) ?? 0.0;

        // Ignore summary lines
        final nameLower = name.toLowerCase();
        if (nameLower.contains('total') ||
            nameLower.contains('subtotal') ||
            nameLower.contains('tax') ||
            nameLower.contains('discount') ||
            nameLower.contains('change') ||
            nameLower.contains('cash')) {
          continue;
        }

        if (name.length > 2 && price > 0) {
          items.add(ReceiptItem(name: name, price: price, quantity: qty));
        }
      }
    }

    return items;
  }
}
