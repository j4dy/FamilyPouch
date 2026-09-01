import 'user_role.dart';
import 'claim_status.dart';

class ReimbursementClaim {
  final String id;
  final UserRole claimant;
  final List<String> expenseIds;
  final double totalAmount;
  final String currency;
  final DateTime submittedAt;
  final DateTime? settledAt;
  final UserRole? settledBy;
  final String? transferProofPhotoBase64;
  final String? transferReference;
  final ClaimStatus status;
  final String notes;

  ReimbursementClaim({
    required this.id,
    required this.claimant,
    required this.expenseIds,
    required this.totalAmount,
    this.currency = 'HKD',
    required this.submittedAt,
    this.settledAt,
    this.settledBy,
    this.transferProofPhotoBase64,
    this.transferReference,
    required this.status,
    this.notes = '',
  });

  bool get isSettled => status == ClaimStatus.settled;

  ReimbursementClaim copyWith({
    String? id,
    UserRole? claimant,
    List<String>? expenseIds,
    double? totalAmount,
    String? currency,
    DateTime? submittedAt,
    DateTime? settledAt,
    UserRole? settledBy,
    String? transferProofPhotoBase64,
    String? transferReference,
    ClaimStatus? status,
    String? notes,
  }) {
    return ReimbursementClaim(
      id: id ?? this.id,
      claimant: claimant ?? this.claimant,
      expenseIds: expenseIds ?? this.expenseIds,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      submittedAt: submittedAt ?? this.submittedAt,
      settledAt: settledAt ?? this.settledAt,
      settledBy: settledBy ?? this.settledBy,
      transferProofPhotoBase64:
          transferProofPhotoBase64 ?? this.transferProofPhotoBase64,
      transferReference: transferReference ?? this.transferReference,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'claimant': claimant.name,
        'expenseIds': expenseIds,
        'totalAmount': totalAmount,
        'currency': currency,
        'submittedAt': submittedAt.toIso8601String(),
        'settledAt': settledAt?.toIso8601String(),
        'settledBy': settledBy?.name,
        'transferProofPhotoBase64': transferProofPhotoBase64,
        'transferReference': transferReference,
        'status': status.name,
        'notes': notes,
      };

  factory ReimbursementClaim.fromJson(Map<String, dynamic> json) =>
      ReimbursementClaim(
        id: json['id'] as String,
        claimant: UserRole.fromString(json['claimant'] as String),
        expenseIds: (json['expenseIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        totalAmount: (json['totalAmount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'HKD',
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        settledAt: json['settledAt'] != null
            ? DateTime.parse(json['settledAt'] as String)
            : null,
        settledBy: json['settledBy'] != null
            ? UserRole.fromString(json['settledBy'] as String)
            : null,
        transferProofPhotoBase64: json['transferProofPhotoBase64'] as String?,
        transferReference: json['transferReference'] as String?,
        status: ClaimStatus.fromString(json['status'] as String),
        notes: json['notes'] as String? ?? '',
      );
}
