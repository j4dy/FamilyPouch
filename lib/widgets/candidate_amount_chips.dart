import 'package:flutter/material.dart';

class CandidateAmountChips extends StatelessWidget {
  final List<double> candidates;
  final double currentAmount;
  final ValueChanged<double> onAmountSelected;

  const CandidateAmountChips({
    super.key,
    required this.candidates,
    required this.currentAmount,
    required this.onAmountSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            Text(
              'Detected Amounts on Receipt (Tap to auto-fix):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: candidates.map((val) {
            final isSelected = (val - currentAmount).abs() < 0.01;
            return ChoiceChip(
              label: Text('HK\$${val.toStringAsFixed(2)}'),
              selected: isSelected,
              selectedColor: const Color(0xFF6366F1).withOpacity(0.3),
              backgroundColor: const Color(0xFF0F172A),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF818CF8) : Colors.grey.shade300,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
              ),
              onSelected: (_) => onAmountSelected(val),
            );
          }).toList(),
        ),
      ],
    );
  }
}
