import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_role.dart';
import '../models/payment_source.dart';
import '../models/expense.dart';
import '../services/accounting_repository.dart';
import '../widgets/receipt_viewer_dialog.dart';
import 'expense_entry_modal.dart';

class ExpenseListView extends StatefulWidget {
  const ExpenseListView({super.key});

  @override
  State<ExpenseListView> createState() => _ExpenseListViewState();
}

class _ExpenseListViewState extends State<ExpenseListView> {
  String _searchQuery = '';
  UserRole? _filterUser;
  PaymentSource? _filterSource;
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final allExpenses = repo.expenses;

    final filtered = allExpenses.where((e) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchMerchant = e.merchant.toLowerCase().contains(q);
        final matchCategory = e.category.toLowerCase().contains(q);
        final matchDesc = e.description.toLowerCase().contains(q);
        if (!matchMerchant && !matchCategory && !matchDesc) return false;
      }
      if (_filterUser != null && e.payer != _filterUser) return false;
      if (_filterSource != null && e.paymentSource != _filterSource) return false;
      if (_filterCategory != null && e.category != _filterCategory) return false;
      return true;
    }).toList();

    final totalFilteredAmount = filtered.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_a_photo, size: 20),
        label: const Text('Record Expense'),
        onPressed: () => ExpenseEntryModal.show(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header & Total Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expense Ledger & Receipts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Showing ${filtered.length} entries • Total: HK\$${totalFilteredAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by store, description, category...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All Roles'),
                    selected: _filterUser == null,
                    onSelected: (_) => setState(() => _filterUser = null),
                  ),
                  const SizedBox(width: 8),
                  ...UserRole.values.map((role) {
                    final isSel = _filterUser == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Text(role.emoji),
                        label: Text(role.displayName),
                        selected: isSel,
                        selectedColor: role.color.withOpacity(0.25),
                        onSelected: (val) {
                          setState(() => _filterUser = val ? role : null);
                        },
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  const VerticalDivider(width: 1, color: Color(0xFF334155)),
                  const SizedBox(width: 8),
                  ...PaymentSource.values.map((src) {
                    final isSel = _filterSource == src;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(src.icon, size: 14, color: src.color),
                        label: Text(src.shortLabel),
                        selected: isSel,
                        selectedColor: src.color.withOpacity(0.25),
                        onSelected: (val) {
                          setState(() => _filterSource = val ? src : null);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Expense Cards List
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        const Text(
                          'No matching expenses found',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try clearing search or filters.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final exp = filtered[idx];
                  return _buildLedgerCard(context, repo, exp);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerCard(BuildContext context, AccountingRepository repo, Expense exp) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: exp.payer.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: exp.payer.color.withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            child: Text(exp.payer.emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                exp.merchant,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Text(
              'HK\$${exp.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(exp.date),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              Text(
                '• ${exp.category}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              if (exp.isOutOfPocket)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: exp.claimStatus.badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    exp.claimStatus.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: exp.claimStatus.badgeColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exp.description.isNotEmpty) ...[
                  Text(
                    'Notes: ${exp.description}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 12),
                ],

                // Line items
                if (exp.itemizedDetails.isNotEmpty) ...[
                  const Text(
                    'Itemized Receipt Line Items:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                  ),
                  const SizedBox(height: 6),
                  ...exp.itemizedDetails.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('• ${item.quantity > 1 ? '${item.quantity}x ' : ''}${item.name}',
                                style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            Text('HK\$${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                  const Divider(color: Color(0xFF1E293B), height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ReceiptViewerDialog.show(
                          context,
                          title: exp.merchant,
                          subtitle:
                              '${DateFormat('yyyy-MM-dd').format(exp.date)} • Logged by ${exp.payer.displayName}',
                          imageBase64: exp.receiptPhotoBase64,
                        );
                      },
                      icon: const Icon(Icons.zoom_in, size: 16),
                      label: const Text('View Receipt Photo', style: TextStyle(fontSize: 12)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                      tooltip: 'Edit Expense',
                      onPressed: () => ExpenseEntryModal.show(context, expense: exp),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: 'Delete Expense',
                      onPressed: () {
                        repo.deleteExpense(exp.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Expense "${exp.merchant}" deleted')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
