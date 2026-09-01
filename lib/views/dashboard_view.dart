import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../models/expense.dart';
import '../services/accounting_repository.dart';
import '../widgets/receipt_viewer_dialog.dart';
import '../widgets/topup_cash_dialog.dart';
import 'expense_entry_modal.dart';

class DashboardView extends StatelessWidget {
  final ValueChanged<int> onNavigateTab;

  const DashboardView({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final currentUser = repo.currentUser;
    final report = repo.generateCycleReport();
    final recentExpenses = repo.expenses.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting & Active Role Hero Banner
          _buildRoleHeroBanner(context, repo, currentUser),
          const SizedBox(height: 20),

          // Primary Financial KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final isMedium = constraints.maxWidth > 550;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildJointSpendCard(report)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCashFloatCard(context, repo, currentUser)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildOutOfPocketSplitCard(context, report, onNavigateTab)),
                  ],
                );
              } else if (isMedium) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildJointSpendCard(report)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildCashFloatCard(context, repo, currentUser)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildOutOfPocketSplitCard(context, report, onNavigateTab),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildJointSpendCard(report),
                    const SizedBox(height: 12),
                    _buildCashFloatCard(context, repo, currentUser),
                    const SizedBox(height: 12),
                    _buildOutOfPocketSplitCard(context, report, onNavigateTab),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Action Shortcuts & Alerts Row
          _buildQuickActionButtons(context, repo, currentUser),
          const SizedBox(height: 24),

          // Recent Expenses Ledger Section
          _buildRecentExpensesSection(context, repo, recentExpenses),
        ],
      ),
    );
  }

  Widget _buildRoleHeroBanner(
      BuildContext context, AccountingRepository repo, UserRole currentUser) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                currentUser.color.withOpacity(0.2),
                const Color(0xFF1E293B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: currentUser.color.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(currentUser.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Text(
                          'Hello, ${currentUser.displayName}!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: currentUser.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            currentUser.roleTypeLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUser.isEmployer
                          ? 'You can log joint/out-of-pocket spending, top-up grocery float, and settle claims.'
                          : 'You can record grocery cash spending and submit out-of-pocket claims.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => ExpenseEntryModal.show(context),
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: const Text('Record Spend'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: currentUser.color.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Text(currentUser.emoji, style: const TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Hello, ${currentUser.displayName}!',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: currentUser.color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  currentUser.roleTypeLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser.isEmployer
                                ? 'You can log joint/out-of-pocket spending, top-up grocery float, and settle claims with bank transfer proof.'
                                : 'You can record grocery cash spending with receipt OCR and submit out-of-pocket reimbursement claims.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => ExpenseEntryModal.show(context),
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Text('Record Spend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildJointSpendCard(dynamic report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance,
                      color: Color(0xFF818CF8), size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Joint Account Spend',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'HK\$${report.totalJointSpend.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Shared 50/50 family fund • No claims needed',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashFloatCard(
      BuildContext context, AccountingRepository repo, UserRole currentUser) {
    final balance = repo.helperGroceryCashBalance;
    final totalSpent = repo.totalHelperGroceryCashSpent;
    final totalTopUps = repo.totalCashTopUpsAmount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
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
                  child: const Icon(Icons.payments,
                      color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Helper Grocery Cash Float',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (currentUser.isEmployer)
                  InkWell(
                    onTap: () => TopUpCashDialog.show(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '+ Top Up',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'HK\$${balance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Spent: HK\$${totalSpent.toStringAsFixed(2)} / Top-ups: HK\$${totalTopUps.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutOfPocketSplitCard(
      BuildContext context, dynamic report, ValueChanged<int> onNavigateTab) {
    final action = report.settlementAction;

    return Card(
      child: InkWell(
        onTap: () => onNavigateTab(4), // Navigate to Cycle Split tab
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pie_chart,
                        color: Color(0xFFF59E0B), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'End-of-Cycle Split',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'HK\$${(report.totalParentsOutOfPocket as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action['message'] as String,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFBBF24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons(
      BuildContext context, AccountingRepository repo, UserRole currentUser) {
    final pendingCount = repo.pendingClaims.length;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onNavigateTab(1), // Ledger tab
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('View All Receipts'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onNavigateTab(2), // Claims tab
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.approval, size: 18),
            ),
            label: Text(
              currentUser.isEmployer ? 'Settle Claims' : 'My Claims',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onNavigateTab(4), // Split tab
            icon: const Icon(Icons.calculate, size: 18),
            label: const Text('Bill Split Report'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentExpensesSection(BuildContext context,
      AccountingRepository repo, List<Expense> expenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, size: 20, color: Color(0xFF818CF8)),
            const SizedBox(width: 8),
            const Text(
              'Recent Expense Feed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => onNavigateTab(1),
              child: const Text('View All →'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (expenses.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No expenses recorded yet. Tap "Record Spend" to start.'),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final exp = expenses[idx];
              return _buildExpenseListTile(context, exp);
            },
          ),
      ],
    );
  }

  Widget _buildExpenseListTile(BuildContext context, Expense exp) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: InkWell(
          onTap: () {
            ReceiptViewerDialog.show(
              context,
              title: exp.merchant,
              subtitle:
                  '${DateFormat('yyyy-MM-dd').format(exp.date)} • Logged by ${exp.payer.displayName}',
              imageBase64: exp.receiptPhotoBase64,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: exp.payer.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: exp.payer.color.withOpacity(0.4),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              exp.payer.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                exp.merchant,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Text(
              'HK\$${exp.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                DateFormat('MMM dd').format(exp.date),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${exp.category}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: exp.paymentSource.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  exp.paymentSource.shortLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: exp.paymentSource.color,
                  ),
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          ReceiptViewerDialog.show(
            context,
            title: exp.merchant,
            subtitle:
                '${DateFormat('yyyy-MM-dd').format(exp.date)} • Logged by ${exp.payer.displayName} (${exp.paymentSource.displayName})',
            imageBase64: exp.receiptPhotoBase64,
          );
        },
      ),
    );
  }
}
