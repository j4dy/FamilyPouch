import 'user_role.dart';
import 'payment_source.dart';
import 'claim_status.dart';
import 'receipt_item.dart';

class Expense {
  final String id;
  final UserRole payer;
  final double amount;
  final String currency;
  final DateTime date;
  final String merchant;
  final String category;
  final String description;
  final List<ReceiptItem> itemizedDetails;
  final PaymentSource paymentSource;
  final ClaimStatus claimStatus;
  final String? receiptPhotoBase64;
  final String? rawOcrText;
  final String? claimId;
  final String? cycleId;

  Expense({
    required this.id,
    required this.payer,
    required this.amount,
    this.currency = 'HKD',
    required this.date,
    required this.merchant,
    required this.category,
    this.description = '',
    this.itemizedDetails = const [],
    required this.paymentSource,
    required this.claimStatus,
    this.receiptPhotoBase64,
    this.rawOcrText,
    this.claimId,
    this.cycleId,
  });

  bool get isOutOfPocket => paymentSource == PaymentSource.outOfPocket;
  bool get isFromJointAccount => paymentSource == PaymentSource.jointAccount;
  bool get isFromGroceryCash => paymentSource == PaymentSource.groceryCash;

  Expense copyWith({
    String? id,
    UserRole? payer,
    double? amount,
    String? currency,
    DateTime? date,
    String? merchant,
    String? category,
    String? description,
    List<ReceiptItem>? itemizedDetails,
    PaymentSource? paymentSource,
    ClaimStatus? claimStatus,
    String? receiptPhotoBase64,
    String? rawOcrText,
    String? claimId,
    String? cycleId,
  }) {
    return Expense(
      id: id ?? this.id,
      payer: payer ?? this.payer,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      description: description ?? this.description,
      itemizedDetails: itemizedDetails ?? this.itemizedDetails,
      paymentSource: paymentSource ?? this.paymentSource,
      claimStatus: claimStatus ?? this.claimStatus,
      receiptPhotoBase64: receiptPhotoBase64 ?? this.receiptPhotoBase64,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      claimId: claimId ?? this.claimId,
      cycleId: cycleId ?? this.cycleId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'payer': payer.name,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        'merchant': merchant,
        'category': category,
        'description': description,
        'itemizedDetails': itemizedDetails.map((i) => i.toJson()).toList(),
        'paymentSource': paymentSource.name,
        'claimStatus': claimStatus.name,
        'receiptPhotoBase64': receiptPhotoBase64,
        'rawOcrText': rawOcrText,
        'claimId': claimId,
        'cycleId': cycleId,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        payer: UserRole.fromString(json['payer'] as String),
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'HKD',
        date: DateTime.parse(json['date'] as String),
        merchant: json['merchant'] as String? ?? 'Store',
        category: json['category'] as String? ?? 'Groceries',
        description: json['description'] as String? ?? '',
        itemizedDetails: (json['itemizedDetails'] as List<dynamic>?)
                ?.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        paymentSource:
            PaymentSource.fromString(json['paymentSource'] as String),
        claimStatus: ClaimStatus.fromString(json['claimStatus'] as String),
        receiptPhotoBase64: json['receiptPhotoBase64'] as String?,
        rawOcrText: json['rawOcrText'] as String?,
        claimId: json['claimId'] as String?,
        cycleId: json['cycleId'] as String?,
      );
}
