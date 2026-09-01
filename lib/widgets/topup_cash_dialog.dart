import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/cash_topup.dart';
import '../services/accounting_repository.dart';

class TopUpCashDialog extends StatefulWidget {
  const TopUpCashDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const TopUpCashDialog(),
    );
  }

  @override
  State<TopUpCashDialog> createState() => _TopUpCashDialogState();
}

class _TopUpCashDialogState extends State<TopUpCashDialog> {
  final _amountController = TextEditingController(text: '500.00');
  final _noteController =
      TextEditingController(text: 'Grocery cash float top-up from Joint Account');

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AccountingRepository>();
    final currentUser = repo.currentUser;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
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
                  child: const Icon(Icons.add_card, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top-Up Helper Cash Float',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Disbursed from Family Joint Account',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
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

            // Disbursed By indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Text(currentUser.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disbursed By: ${currentUser.displayName} (${currentUser.roleTypeLabel})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Fund Source: Shared Joint Account Pool',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top-Up Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Top-Up Cash Amount (HK\$)',
                prefixText: 'HK\$ ',
                prefixIcon: Icon(Icons.payments, size: 22),
              ),
            ),
            const SizedBox(height: 10),

            // Quick preset chips
            Wrap(
              spacing: 8,
              children: [200.0, 300.0, 500.0, 800.0, 1000.0].map((preset) {
                return ActionChip(
                  label: Text('+\$${preset.toInt()}'),
                  backgroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFF334155)),
                  onPressed: () {
                    setState(() {
                      _amountController.text = preset.toStringAsFixed(2);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note / Purpose',
                prefixIcon: Icon(Icons.edit_note, size: 22),
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
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm Top-Up'),
                    onPressed: () {
                      final amount =
                          double.tryParse(_amountController.text) ?? 0.0;
                      if (amount <= 0) return;

                      repo.addCashTopUp(
                        CashTopUp(
                          id: const Uuid().v4(),
                          disbursedBy: currentUser,
                          amount: amount,
                          date: DateTime.now(),
                          note: _noteController.text.trim(),
                        ),
                      );

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Successfully topped up HK\$${amount.toStringAsFixed(2)} to Helper Grocery Cash!'),
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
