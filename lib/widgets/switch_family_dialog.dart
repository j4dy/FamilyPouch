import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/accounting_repository.dart';

class SwitchFamilyDialog extends StatefulWidget {
  const SwitchFamilyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const SwitchFamilyDialog(),
    );
  }

  @override
  State<SwitchFamilyDialog> createState() => _SwitchFamilyDialogState();
}

class _SwitchFamilyDialogState extends State<SwitchFamilyDialog> {
  final _familyCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final repo = context.read<AccountingRepository>();
    _familyCodeController.text = repo.familyId;
  }

  @override
  void dispose() {
    _familyCodeController.dispose();
    super.dispose();
  }

  void _copyFamilyLink(String familyId) {
    final link = 'https://familypouch-live.web.app/?family=$familyId';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Direct link copied: $link'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final currentFamilyId = repo.familyId;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.family_restroom, color: Color(0xFF818CF8), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Family Pouch Workspace', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Each family has its own completely isolated database, receipts ledger, cash float, and cycle split reports.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Family Code / ID',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _familyCodeController,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. j4dy, smith, chan',
                  prefixIcon: const Icon(Icons.tag, size: 18, color: Color(0xFF818CF8)),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a family code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Preset quick switch chips
              Wrap(
                spacing: 8,
                children: ['j4dy', 'demo-family', 'smith'].map((code) {
                  final isCurrent = code == currentFamilyId;
                  return ActionChip(
                    label: Text(code),
                    backgroundColor: isCurrent
                        ? const Color(0xFF6366F1).withOpacity(0.25)
                        : const Color(0xFF0F172A),
                    side: BorderSide(
                      color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF334155),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      setState(() {
                        _familyCodeController.text = code;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Share link box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔗 Shareable Family Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                    const SizedBox(height: 4),
                    Text(
                      'https://familypouch-live.web.app/?family=$currentFamilyId',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy Family Invite Link', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          foregroundColor: const Color(0xFF818CF8),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                        ),
                        onPressed: () => _copyFamilyLink(currentFamilyId),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
          ),
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              final newId = _familyCodeController.text.trim();
              await repo.switchFamily(newId);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Switched to family workspace: $newId'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            }
          },
          child: const Text('Switch Family'),
        ),
      ],
    );
  }
}
