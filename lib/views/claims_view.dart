import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../models/claim_status.dart';
import '../models/reimbursement_claim.dart';
import '../models/expense.dart';
import '../services/accounting_repository.dart';
import '../widgets/receipt_viewer_dialog.dart';
import '../widgets/settle_claim_dialog.dart';

class ClaimsView extends StatefulWidget {
  const ClaimsView({super.key});

  @override
  State<ClaimsView> createState() => _ClaimsViewState();
}

class _ClaimsViewState extends State<ClaimsView> {
  final Set<String> _selectedUnclaimedExpenseIds = {};
  final _claimNoteController = TextEditingController();

  @override
  void dispose() {
    _claimNoteController.dispose();
    super.dispose();
  }

  void _submitClaimBatch(AccountingRepository repo) {
    if (_selectedUnclaimedExpenseIds.isEmpty) return;

    repo.submitReimbursementClaim(
      expenseIds: _selectedUnclaimedExpenseIds.toList(),
      notes: _claimNoteController.text.trim().isEmpty
          ? 'Out-of-pocket reimbursement claim'
          : _claimNoteController.text.trim(),
    );

    setState(() {
      _selectedUnclaimedExpenseIds.clear();
      _claimNoteController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reimbursement claim submitted for employer review!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final currentUser = repo.currentUser;
    final unclaimedExpenses = repo.unclaimedExpensesForCurrentUser;
    final allClaims = repo.claims;

    final pendingClaims = allClaims.where((c) => c.status == ClaimStatus.pendingApproval).toList();
    final settledClaims = allClaims.where((c) => c.status == ClaimStatus.settled).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Out-of-Pocket Claims & Reimbursements',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      currentUser.isEmployer
                          ? 'Review claims submitted by helper/employers & settle with transfer proof.'
                          : 'Select your out-of-pocket expenses to submit for employer reimbursement.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 1: Helper / Current User Unclaimed Out-of-Pocket Batch Creator
          if (unclaimedExpenses.isNotEmpty) ...[
            _buildUnclaimedBatchCreator(context, repo, unclaimedExpenses),
            const SizedBox(height: 24),
          ],

          // Section 2: Pending Approval Claims
          _buildPendingClaimsSection(context, repo, pendingClaims, currentUser),
          const SizedBox(height: 24),

          // Section 3: Settled History Claims
          _buildSettledClaimsSection(context, repo, settledClaims),
        ],
      ),
    );
  }

  Widget _buildUnclaimedBatchCreator(BuildContext context,
      AccountingRepository repo, List<Expense> unclaimed) {
    final totalSelected = unclaimed
        .where((e) => _selectedUnclaimedExpenseIds.contains(e.id))
        .fold(0.0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_add_check, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text(
                'Submit Out-of-Pocket Expenses for Claim',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedUnclaimedExpenseIds.length == unclaimed.length) {
                      _selectedUnclaimedExpenseIds.clear();
                    } else {
                      _selectedUnclaimedExpenseIds.addAll(unclaimed.map((e) => e.id));
                    }
                  });
                },
                child: Text(
                  _selectedUnclaimedExpenseIds.length == unclaimed.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...unclaimed.map((exp) {
            final isChecked = _selectedUnclaimedExpenseIds.contains(exp.id);
            return CheckboxListTile(
              value: isChecked,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFFF59E0B),
              title: Text(exp.merchant, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${DateFormat('yyyy-MM-dd').format(exp.date)} • ${exp.category}'),
              secondary: Text(
                'HK\$${exp.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedUnclaimedExpenseIds.add(exp.id);
                  } else {
                    _selectedUnclaimedExpenseIds.remove(exp.id);
                  }
                });
              },
            );
          }),
          const Divider(color: Color(0xFF334155), height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _claimNoteController,
                  decoration: const InputDecoration(
                    hintText: 'Claim description/notes...',
                    prefixIcon: Icon(Icons.edit_note, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selectedUnclaimedExpenseIds.isEmpty
                    ? null
                    : () => _submitClaimBatch(repo),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                icon: const Icon(Icons.send, size: 18),
                label: Text('Submit Claim (HK\$${totalSelected.toStringAsFixed(2)})'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingClaimsSection(BuildContext context, AccountingRepository repo,
      List<ReimbursementClaim> pending, UserRole currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pending_actions, color: Color(0xFFA78BFA), size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'Pending Claims Awaiting Reimbursement (${pending.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pending.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text('No pending claims awaiting approval.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final claim = pending[idx];
              return _buildClaimCard(context, repo, claim, currentUser);
            },
          ),
      ],
    );
  }

  Widget _buildSettledClaimsSection(BuildContext context, AccountingRepository repo,
      List<ReimbursementClaim> settled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'Settled Reimbursement History (${settled.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (settled.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text('No claims settled yet.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: settled.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final claim = settled[idx];
              return _buildClaimCard(context, repo, claim, repo.currentUser);
            },
          ),
      ],
    );
  }

  Widget _buildClaimCard(BuildContext context, AccountingRepository repo,
      ReimbursementClaim claim, UserRole currentUser) {
    final isSettled = claim.isSettled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(claim.claimant.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Claim by ${claim.claimant.displayName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Submitted: ${DateFormat('yyyy-MM-dd HH:mm').format(claim.submittedAt)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                Text(
                  'HK\$${claim.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            if (claim.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Note: ${claim.notes}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
              ),
            ],
            const Divider(color: Color(0xFF334155), height: 20),

            // Settle / Evidence Details
            if (isSettled) ...[
              Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reimbursed by ${claim.settledBy?.displayName ?? 'Joint Account'} • Ref: ${claim.transferReference ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (claim.transferProofPhotoBase64 != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        ReceiptViewerDialog.show(
                          context,
                          title: 'Bank Transfer Proof',
                          subtitle: 'Ref: ${claim.transferReference} • ${claim.claimant.displayName}',
                          imageBase64: claim.transferProofPhotoBase64,
                        );
                      },
                      icon: const Icon(Icons.image, size: 14),
                      label: const Text('View Transfer Proof', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Awaiting Bank Transfer from Joint Account',
                      style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  if (currentUser.isEmployer)
                    ElevatedButton.icon(
                      onPressed: () => SettleClaimDialog.show(context, claim),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Settle & Upload Proof', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
