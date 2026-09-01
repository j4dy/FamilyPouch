import '../../models/receipt_item.dart';

class OcrResult {
  final String rawText;
  final String? merchant;
  final double? totalAmount;
  final List<double> candidateAmounts;
  final DateTime? date;
  final String? category;
  final List<ReceiptItem> lineItems;
  final double confidence;

  OcrResult({
    required this.rawText,
    this.merchant,
    this.totalAmount,
    this.candidateAmounts = const [],
    this.date,
    this.category,
    this.lineItems = const [],
    this.confidence = 0.90,
  });

  OcrResult copyWith({
    String? rawText,
    String? merchant,
    double? totalAmount,
    List<double>? candidateAmounts,
    DateTime? date,
    String? category,
    List<ReceiptItem>? lineItems,
    double? confidence,
  }) {
    return OcrResult(
      rawText: rawText ?? this.rawText,
      merchant: merchant ?? this.merchant,
      totalAmount: totalAmount ?? this.totalAmount,
      candidateAmounts: candidateAmounts ?? this.candidateAmounts,
      date: date ?? this.date,
      category: category ?? this.category,
      lineItems: lineItems ?? this.lineItems,
      confidence: confidence ?? this.confidence,
    );
  }
}
