import 'user_role.dart';

class CashTopUp {
  final String id;
  final UserRole disbursedBy;
  final double amount;
  final String currency;
  final DateTime date;
  final String note;
  final String? proofPhotoBase64;

  CashTopUp({
    required this.id,
    required this.disbursedBy,
    required this.amount,
    this.currency = 'HKD',
    required this.date,
    this.note = '',
    this.proofPhotoBase64,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'disbursedBy': disbursedBy.name,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        'note': note,
        'proofPhotoBase64': proofPhotoBase64,
      };

  factory CashTopUp.fromJson(Map<String, dynamic> json) => CashTopUp(
        id: json['id'] as String,
        disbursedBy: UserRole.fromString(json['disbursedBy'] as String),
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'HKD',
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String? ?? '',
        proofPhotoBase64: json['proofPhotoBase64'] as String?,
      );
}
