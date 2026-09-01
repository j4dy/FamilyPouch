import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../services/accounting_repository.dart';
import '../widgets/receipt_viewer_dialog.dart';

class CycleSplitView extends StatelessWidget {
  const CycleSplitView({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final currentUser = repo.currentUser;
    final cycles = repo.cycles;
    final currentCycle = repo.currentCycle;
    final report = repo.generateCycleReport();
    final action = report.settlementAction;

    final cycleExpenses = repo.currentCycleExpenses;
    final motherExpenses = cycleExpenses.where((e) => e.payer == UserRole.mother).toList();
    final fatherExpenses = cycleExpenses.where((e) => e.payer == UserRole.father).toList();
    final helperExpenses = cycleExpenses.where((e) => e.payer == UserRole.helper).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Cycle Selector
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End-of-Cycle Bill Splitting Engine',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Reconciliation between employers (Mother & Father) and Joint Account.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: repo.selectedCycleId,
                    dropdownColor: const Color(0xFF1E293B),
                    items: cycles.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(
                              c.isClosed ? Icons.lock : Icons.lock_open,
                              size: 16,
                              color: c.isClosed ? Colors.grey : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Text(c.title, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) repo.selectCycle(val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Settlement Action Card (Big Highlight)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.balance, color: Color(0xFFA5B4FC), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'NET EMPLOYER SETTLEMENT STATEMENT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFFA5B4FC),
                          ),
                        ),
                      ],
                    ),
                    if (currentCycle.isClosed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('CYCLE CLOSED & SETTLED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                      )
                    else if (currentUser.isEmployer)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFA5B4FC)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () {
                          repo.closeSettlementCycle(currentCycle.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cycle closed and finalized!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock, size: 14),
                        label: const Text('Finalize Cycle', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  action['message'] as String,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Out-of-Pocket Balance: Mother spent HK\$${report.totalMotherOutOfPocket.toStringAsFixed(2)} vs Father spent HK\$${report.totalFatherOutOfPocket.toStringAsFixed(2)} • Equal share: HK\$${report.parentEqualShare.toStringAsFixed(2)} each.',
                  style: TextStyle(fontSize: 12, color: Colors.indigo.shade200),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4-Quadrant KPI Breakdown Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 750;

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: _buildMetricCard('Total Family Spending', report.totalFamilySpend, Icons.account_tree, const Color(0xFF6366F1))),
                    const SizedBox(width: 14),
                    Expanded(child: _buildMetricCard('Joint Account Direct', report.totalJointSpend, Icons.account_balance, const Color(0xFF3B82F6))),
                    const SizedBox(width: 14),
                    Expanded(child: _buildMetricCard('Mother Out-of-Pocket', report.totalMotherOutOfPocket, Icons.woman, const Color(0xFFEC4899))),
                    const SizedBox(width: 14),
                    Expanded(child: _buildMetricCard('Father Out-of-Pocket', report.totalFatherOutOfPocket, Icons.man, const Color(0xFF0EA5E9))),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard('Total Spend', report.totalFamilySpend, Icons.account_tree, const Color(0xFF6366F1))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMetricCard('Joint Account', report.totalJointSpend, Icons.account_balance, const Color(0xFF3B82F6))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard('Mother OOP', report.totalMotherOutOfPocket, Icons.woman, const Color(0xFFEC4899))),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMetricCard('Father OOP', report.totalFatherOutOfPocket, Icons.man, const Color(0xFF0EA5E9))),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // User-by-User Spending Breakdown Ledger
          const Text(
            'Cycle Spending Breakdown by Member',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildUserSpendAccordion(context, '👩 Mother', UserRole.mother, motherExpenses),
          const SizedBox(height: 12),
          _buildUserSpendAccordion(context, '👨 Father', UserRole.father, fatherExpenses),
          const SizedBox(height: 12),
          _buildUserSpendAccordion(context, '🧑‍🍳 Helper', UserRole.helper, helperExpenses),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, double amount, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'HK\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSpendAccordion(
      BuildContext context, String title, UserRole role, List<dynamic> expenses) {
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Card(
      child: ExpansionTile(
        initiallyExpanded: expenses.isNotEmpty,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: role.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(role.emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${expenses.length} receipts • Total: HK\$${total.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: expenses.isEmpty
                ? const Center(child: Text('No expenses recorded this cycle.'))
                : Column(
                    children: expenses.map((exp) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.receipt, size: 18, color: Color(0xFF818CF8)),
                              onPressed: () {
                                ReceiptViewerDialog.show(
                                  context,
                                  title: exp.merchant,
                                  subtitle: '${DateFormat('yyyy-MM-dd').format(exp.date)} • ${exp.category}',
                                  imageBase64: exp.receiptPhotoBase64,
                                );
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(exp.merchant, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(
                                    '${DateFormat('yyyy-MM-dd').format(exp.date)} • ${exp.paymentSource.shortLabel} • ${exp.category}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'HK\$${exp.amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
