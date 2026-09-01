import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/reimbursement_claim.dart';
import '../services/accounting_repository.dart';

class SettleClaimDialog extends StatefulWidget {
  final ReimbursementClaim claim;

  const SettleClaimDialog({super.key, required this.claim});

  static Future<void> show(BuildContext context, ReimbursementClaim claim) {
    return showDialog(
      context: context,
      builder: (ctx) => SettleClaimDialog(claim: claim),
    );
  }

  @override
  State<SettleClaimDialog> createState() => _SettleClaimDialogState();
}

class _SettleClaimDialogState extends State<SettleClaimDialog> {
  final _refController = TextEditingController(text: 'FPS-TRANSFER-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final _noteController = TextEditingController(text: 'Transferred from Joint Account');
  String? _transferProofBase64;
  String? _proofFileName;

  Future<void> _pickTransferProof() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _proofFileName = file.name;
            _transferProofBase64 =
                'data:image/jpeg;base64,${base64Encode(file.bytes!)}';
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking transfer proof: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AccountingRepository>();

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proceed Claim Reimbursement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Claim by ${widget.claim.claimant.displayName} • HK\$${widget.claim.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 28),

            // Summary Callout
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reimbursement Total',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'HK\$${widget.claim.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Funded by Joint Account',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transfer Reference Input
            TextFormField(
              controller: _refController,
              decoration: const InputDecoration(
                labelText: 'Bank Transfer / FPS Reference No.',
                hintText: 'e.g. FPS-889021-99',
                prefixIcon: Icon(Icons.tag, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Settlement Notes',
                hintText: 'Optional notes...',
                prefixIcon: Icon(Icons.notes, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Transfer Screenshot Evidence
            const Text(
              'Transfer Photo Evidence (Proof of Payment):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            InkWell(
              onTap: _pickTransferProof,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _transferProofBase64 != null
                        ? const Color(0xFF10B981)
                        : const Color(0xFF334155),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _transferProofBase64 != null
                          ? Icons.check_circle
                          : Icons.add_a_photo_outlined,
                      color: _transferProofBase64 != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _proofFileName != null
                            ? 'Screenshot: $_proofFileName'
                            : 'Upload Bank Transfer Screenshot / Slip',
                        style: TextStyle(
                          fontSize: 13,
                          color: _transferProofBase64 != null
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _pickTransferProof,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: Text(_transferProofBase64 != null ? 'Change' : 'Browse'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirm Settle'),
                    onPressed: () {
                      repo.settleClaim(
                        claimId: widget.claim.id,
                        transferProofPhotoBase64: _transferProofBase64 ??
                            'data:image/jpeg;base64,mockTransferProof',
                        transferReference: _refController.text.trim(),
                        notes: _noteController.text.trim(),
                      );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Claim for HK\$${widget.claim.totalAmount.toStringAsFixed(2)} marked as Settled!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
