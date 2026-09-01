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

  static const Map<String, String> knownMerchants = {
    'wellcome': 'Wellcome Supermarket',
    'parknshop': 'PARKnSHOP Supermarket',
    'marketplace': 'Market Place by Jasons',
    'donki': 'DON DON DONKI',
    'don don donki': 'DON DON DONKI',
    'fairprice': 'NTUC FairPrice',
    'citysuper': 'city\'super',
    'taste': 'TASTE Supermarket',
    'fusion': 'FUSION by PARKnSHOP',
    'watsons': 'Watsons Pharmacy',
    'mannings': 'Mannings Health & Beauty',
    '7-eleven': '7-Eleven',
    '7 eleven': '7-Eleven',
    'circle k': 'Circle K',
    'starbucks': 'Starbucks Coffee',
    'pacific coffee': 'Pacific Coffee',
    'ikea': 'IKEA Home Furnishings',
    'hktvmall': 'HKTVmall',
    'japan home': 'Japan Home Centre (JHC)',
    'jhc': 'Japan Home Centre (JHC)',
    'daiso': 'Daiso Living',
    'clp': 'CLP Power Hong Kong',
    'towngas': 'Towngas Hong Kong',
    'water supplies': 'Water Supplies Dept',
  };

  static const Map<String, String> merchantCategoryMap = {
    'Wellcome Supermarket': 'Groceries',
    'PARKnSHOP Supermarket': 'Groceries',
    'Market Place by Jasons': 'Groceries',
    'DON DON DONKI': 'Groceries',
    'NTUC FairPrice': 'Groceries',
    'city\'super': 'Groceries',
    'TASTE Supermarket': 'Groceries',
    'FUSION by PARKnSHOP': 'Groceries',
    'Watsons Pharmacy': 'Health & Medical',
    'Mannings Health & Beauty': 'Health & Medical',
    '7-Eleven': 'Dining & Takeout',
    'Circle K': 'Dining & Takeout',
    'Starbucks Coffee': 'Dining & Takeout',
    'Pacific Coffee': 'Dining & Takeout',
    'IKEA Home Furnishings': 'Household Supplies',
    'HKTVmall': 'Household Supplies',
    'Japan Home Centre (JHC)': 'Household Supplies',
    'Daiso Living': 'Household Supplies',
    'CLP Power Hong Kong': 'Utilities',
    'Towngas Hong Kong': 'Utilities',
    'Water Supplies Dept': 'Utilities',
  };

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
      confidence: 0.92,
    );
  }

  static String? _detectMerchant(List<String> lines, String rawText) {
    final lower = rawText.toLowerCase();
    for (var entry in knownMerchants.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    // Fallback: Check first 2 lines
    if (lines.isNotEmpty) {
      final first = lines.first;
      if (first.length > 2 && first.length < 40 && !first.contains(RegExp(r'\d{4}'))) {
        return first;
      }
    }
    return null;
  }

  static String _detectCategory(String? merchant, String rawText) {
    if (merchant != null && merchantCategoryMap.containsKey(merchant)) {
      return merchantCategoryMap[merchant]!;
    }
    final lower = rawText.toLowerCase();
    if (lower.contains('supermarket') ||
        lower.contains('grocery') ||
        lower.contains('market') ||
        lower.contains('food') ||
        lower.contains('milk') ||
        lower.contains('fruit') ||
        lower.contains('meat') ||
        lower.contains('vegetable') ||
        lower.contains('rice') ||
        lower.contains('egg')) {
      return 'Groceries';
    }
    if (lower.contains('pharmacy') ||
        lower.contains('clinic') ||
        lower.contains('doctor') ||
        lower.contains('medical') ||
        lower.contains('hospital') ||
        lower.contains('drug') ||
        lower.contains('panadol')) {
      return 'Health & Medical';
    }
    if (lower.contains('cafe') ||
        lower.contains('restaurant') ||
        lower.contains('dining') ||
        lower.contains('coffee') ||
        lower.contains('burger') ||
        lower.contains('pizza') ||
        lower.contains('bakery') ||
        lower.contains('lunch') ||
        lower.contains('dinner')) {
      return 'Dining & Takeout';
    }
    if (lower.contains('clean') ||
        lower.contains('soap') ||
        lower.contains('detergent') ||
        lower.contains('paper towel') ||
        lower.contains('tissue') ||
        lower.contains('hardware') ||
        lower.contains('battery')) {
      return 'Household Supplies';
    }
    if (lower.contains('school') ||
        lower.contains('book') ||
        lower.contains('tuition') ||
        lower.contains('class') ||
        lower.contains('toy') ||
        lower.contains('kids') ||
        lower.contains('baby') ||
        lower.contains('diaper')) {
      return 'Kids & Education';
    }
    if (lower.contains('electric') ||
        lower.contains('water') ||
        lower.contains('gas') ||
        lower.contains('utility') ||
        lower.contains('wifi') ||
        lower.contains('broadband')) {
      return 'Utilities';
    }
    return 'Groceries';
  }

  static DateTime? _detectDate(String rawText) {
    // 1. Match YYYY-MM-DD or YYYY/MM/DD
    final isoRegex = RegExp(r'\b(202[0-9])[-/.](0?[1-9]|1[0-2])[-/.](0?[1-9]|[12][0-9]|3[01])\b');
    final isoMatch = isoRegex.firstMatch(rawText);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // 2. Match DD/MM/YYYY or DD-MM-YYYY
    final dmyRegex = RegExp(r'\b(0?[1-9]|[12][0-9]|3[01])[-/.](0?[1-9]|1[0-2])[-/.](202[0-9])\b');
    final dmyMatch = dmyRegex.firstMatch(rawText);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      final y = int.parse(dmyMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // 3. Match format like "25 Aug 2026" or "Aug 25, 2026"
    final textMonthRegex = RegExp(
        r'\b(0?[1-9]|[12][0-9]|3[01])\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s,]+(202[0-9])\b',
        caseSensitive: false);
    final textMatch = textMonthRegex.firstMatch(rawText);
    if (textMatch != null) {
      try {
        final d = int.parse(textMatch.group(1)!);
        final monthStr = textMatch.group(2)!;
        final y = int.parse(textMatch.group(3)!);
        final dateParsed = DateFormat('d MMM yyyy').parse('$d $monthStr $y');
        return dateParsed;
      } catch (_) {}
    }

    return null;
  }

  static List<double> _extractCandidateAmounts(String rawText) {
    final amountRegex = RegExp(r'(?:HK\$|SGD|\$)?\s*([0-9]{1,5}[.,][0-9]{2})\b');
    final matches = amountRegex.allMatches(rawText);
    final Set<double> numbers = {};

    for (var m in matches) {
      final str = m.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(str);
      if (val != null && val > 0 && val < 50000) {
        numbers.add(val);
      }
    }
    final sorted = numbers.toList()..sort();
    return sorted;
  }

  static double? _detectTotalAmount(List<String> lines, List<double> candidates) {
    // Check lines containing keywords "TOTAL", "GRAND TOTAL", "NET", "AMOUNT DUE"
    final totalKeywords = RegExp(
        r'\b(total|grand\s*total|amount\s*due|net\s*amount|total\s*hkd|balance\s*due|paid)\b',
        caseSensitive: false);

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (totalKeywords.hasMatch(line)) {
        final match = RegExp(r'([0-9]{1,5}[.,][0-9]{2})').firstMatch(line);
        if (match != null) {
          final val = double.tryParse(match.group(1)!.replaceAll(',', '.'));
          if (val != null && val > 0) return val;
        }
        // Sometimes amount is on next line
        if (i + 1 < lines.length) {
          final nextMatch = RegExp(r'([0-9]{1,5}[.,][0-9]{2})').firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            final val = double.tryParse(nextMatch.group(1)!.replaceAll(',', '.'));
            if (val != null && val > 0) return val;
          }
        }
      }
    }

    // Default to the largest reasonable candidate or last candidate
    if (candidates.isNotEmpty) {
      return candidates.last;
    }
    return null;
  }

  static List<ReceiptItem> _detectLineItems(List<String> lines) {
    final List<ReceiptItem> items = [];
    final itemRegex = RegExp(r'^([A-Za-z0-9\s\.\&\-\/\(\)]+?)\s+(?:(\d+)\s*[xX]\s*)?(?:HK\$|\$)?\s*([0-9]+[.,][0-9]{2})$');

    for (var line in lines) {
      final clean = line.trim();
      if (clean.toLowerCase().contains('total') ||
          clean.toLowerCase().contains('subtotal') ||
          clean.toLowerCase().contains('change') ||
          clean.toLowerCase().contains('cash') ||
          clean.toLowerCase().contains('visa') ||
          clean.toLowerCase().contains('mastercard') ||
          clean.toLowerCase().contains('octopus') ||
          clean.toLowerCase().contains('tax') ||
          clean.toLowerCase().contains('discount')) {
        continue;
      }

      final match = itemRegex.firstMatch(clean);
      if (match != null) {
        final name = match.group(1)!.trim();
        final qty = int.tryParse(match.group(2) ?? '1') ?? 1;
        final price = double.tryParse(match.group(3)!.replaceAll(',', '.')) ?? 0.0;
        if (name.length > 2 && price > 0) {
          items.add(ReceiptItem(name: name, price: price, quantity: qty));
        }
      }
    }

    return items;
  }
}
