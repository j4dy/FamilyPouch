import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../services/accounting_repository.dart';
import 'switch_family_dialog.dart';

class UserSwitchBanner extends StatelessWidget {
  const UserSwitchBanner({super.key});

  void _showClearConfirmDialog(BuildContext context, AccountingRepository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Clear All Records?'),
          ],
        ),
        content: Text(
          'This will permanently erase all expenses, cash top-ups, and claims for family "${repo.familyId}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await repo.clearAllData();
              if (context.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data has been cleared! Starting fresh.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final currentUser = repo.currentUser;
    final familyId = repo.familyId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF334155).withOpacity(0.6),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;

          return Row(
            children: [
              // Logo / Brand
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                  ),
                ),
                child: const Text(
                  '👛',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              if (!isSmall)
                const Text(
                  'FamilyPouch',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),

              const SizedBox(width: 8),

              // Active Family Workspace Chip
              InkWell(
                onTap: () => SwitchFamilyDialog.show(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.home, size: 13, color: Color(0xFF818CF8)),
                      const SizedBox(width: 4),
                      Text(
                        familyId,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF818CF8)),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // User Switcher Segmented Control
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: UserRole.values.map((role) {
                    final isSelected = role == currentUser;
                    return InkWell(
                      onTap: () => repo.switchUser(role),
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 6 : 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? role.color.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: isSelected
                              ? Border.all(color: role.color, width: 1.2)
                              : Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              role.emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (!isSmall) ...[
                              const SizedBox(width: 4),
                              Text(
                                role.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(width: 6),

              // Options Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'switch_family') {
                    SwitchFamilyDialog.show(context);
                  } else if (val == 'clear') {
                    _showClearConfirmDialog(context, repo);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'switch_family',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 18, color: Color(0xFF818CF8)),
                        SizedBox(width: 8),
                        Text('Switch Family Workspace', style: TextStyle(fontSize: 13, color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Clear Family Data', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
