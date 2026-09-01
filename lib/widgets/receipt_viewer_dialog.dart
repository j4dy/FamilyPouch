import 'dart:convert';
import 'package:flutter/material.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String title;
  final String? imageBase64;
  final String? subtitle;

  const ReceiptViewerDialog({
    super.key,
    required this.title,
    this.imageBase64,
    this.subtitle,
  });

  static void show(
    BuildContext context, {
    required String title,
    String? imageBase64,
    String? subtitle,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ReceiptViewerDialog(
        title: title,
        imageBase64: imageBase64,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
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
            const Divider(color: Color(0xFF334155), height: 24),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: const Color(0xFF0F172A),
                  alignment: Alignment.center,
                  child: imageBase64 != null && imageBase64!.isNotEmpty
                      ? _buildImage(imageBase64!)
                      : _buildPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String dataUri) {
    try {
      if (dataUri.startsWith('data:image')) {
        final base64Str = dataUri.split(',').last;
        final bytes = base64Decode(base64Str);
        return InteractiveViewer(
          maxScale: 4.0,
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      } else {
        return InteractiveViewer(
          maxScale: 4.0,
          child: Image.network(
            dataUri,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      }
    } catch (_) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_outlined, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 12),
          const Text(
            'Receipt Evidence Document',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Scanned and verified for accounting audit trail.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
