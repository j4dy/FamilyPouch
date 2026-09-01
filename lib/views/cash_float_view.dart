import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/payment_source.dart';
import '../services/accounting_repository.dart';
import '../widgets/topup_cash_dialog.dart';
import '../widgets/receipt_viewer_dialog.dart';

class CashFloatView extends StatelessWidget {
  const CashFloatView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final currentUser = repo.currentUser;

    final balance = repo.helperGroceryCashBalance;
    final totalTopUps = repo.totalCashTopUpsAmount;
    final totalSpent = repo.totalHelperGroceryCashSpent;
    final topUps = repo.cashTopUps;
    final cashExpenses = repo.expenses
        .where((e) => e.payer.isHelper && e.paymentSource == PaymentSource.groceryCash)
        .toList();

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
                      'Helper Grocery Cash Float Manager',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Track cash given to helper for wet market & supermarket groceries.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              if (currentUser.isEmployer)
                ElevatedButton.icon(
                  onPressed: () => TopUpCashDialog.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_card, size: 18),
                  label: const Text('Top Up Float'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Big Float Status Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('🧑‍🍳', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 8),
                        Text(
                          'Current Available Grocery Cash',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFA7F3D0)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Held in Cash Pouch',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6EE7B7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'HK\$${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF047857)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Disbursed Top-Ups',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          const SizedBox(height: 2),
                          Text('HK\$${totalTopUps.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6EE7B7))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Grocery Cash Spent',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          const SizedBox(height: 2),
                          Text('HK\$${totalSpent.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFCA5A5))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two Column Ledger: Top-ups & Cash Spend
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 750;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopUpsSection(context, topUps)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCashExpensesSection(context, cashExpenses)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTopUpsSection(context, topUps),
                    const SizedBox(height: 20),
                    _buildCashExpensesSection(context, cashExpenses),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpsSection(BuildContext context, List<dynamic> topUps) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.arrow_downward, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 6),
                const Text('Cash-In Top-Ups (from Joint Acct)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text('${topUps.length} entries',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 12),
            if (topUps.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No top-ups logged yet.')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topUps.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 12),
                itemBuilder: (context, idx) {
                  final t = topUps[idx];
                  return Row(
                    children: [
                      Text(t.disbursedBy.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Given by ${t.disbursedBy.displayName}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              '${DateFormat('yyyy-MM-dd').format(t.date)}${t.note.isNotEmpty ? ' • ${t.note}' : ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+HK\$${t.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashExpensesSection(BuildContext context, List<dynamic> cashExpenses) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 6),
                const Text('Cash Spent on Groceries',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text('${cashExpenses.length} receipts',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 12),
            if (cashExpenses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No cash expenses logged.')),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cashExpenses.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 12),
                itemBuilder: (context, idx) {
                  final exp = cashExpenses[idx];
                  return InkWell(
                    onTap: () {
                      ReceiptViewerDialog.show(
                        context,
                        title: exp.merchant,
                        subtitle: '${DateFormat('yyyy-MM-dd').format(exp.date)} • Grocery Cash',
                        imageBase64: exp.receiptPhotoBase64,
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_outlined, size: 18, color: Color(0xFF818CF8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp.merchant,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                '${DateFormat('yyyy-MM-dd').format(exp.date)} • ${exp.category}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '-HK\$${exp.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
