import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/payment_source.dart';
import '../models/claim_status.dart';
import '../models/receipt_item.dart';
import '../models/expense.dart';
import '../services/accounting_repository.dart';
import '../services/ocr/receipt_ocr_service.dart';
import '../services/ocr/ocr_result.dart';
import '../services/ocr/receipt_parser_rules.dart';
import '../widgets/candidate_amount_chips.dart';

class ExpenseEntryModal extends StatefulWidget {
  final Expense? existingExpense;

  const ExpenseEntryModal({super.key, this.existingExpense});

  static Future<void> show(BuildContext context, {Expense? expense}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExpenseEntryModal(existingExpense: expense),
    );
  }

  @override
  State<ExpenseEntryModal> createState() => _ExpenseEntryModalState();
}

class _ExpenseEntryModalState extends State<ExpenseEntryModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _descController;
  late DateTime _selectedDate;
  late String _selectedCategory;
  late PaymentSource _selectedPaymentSource;

  List<ReceiptItem> _lineItems = [];
  List<double> _candidateAmounts = [];
  String? _receiptImageBase64;
  String? _rawOcrText;
  String? _uploadedFileName;

  bool _isScanningOcr = false;
  final bool _showRawOcrText = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<AccountingRepository>();
    final isEditing = widget.existingExpense != null;

    if (isEditing) {
      final exp = widget.existingExpense!;
      _merchantController = TextEditingController(text: exp.merchant);
      _amountController = TextEditingController(text: exp.amount.toStringAsFixed(2));
      _descController = TextEditingController(text: exp.description);
      _selectedDate = exp.date;
      _selectedCategory = exp.category;
      _selectedPaymentSource = exp.paymentSource;
      _lineItems = List.from(exp.itemizedDetails);
      _receiptImageBase64 = exp.receiptPhotoBase64;
      _rawOcrText = exp.rawOcrText;
    } else {
      _merchantController = TextEditingController();
      _amountController = TextEditingController();
      _descController = TextEditingController();
      _selectedDate = DateTime.now();
      _selectedCategory = 'Groceries';
      _selectedPaymentSource = repo.currentUser.isEmployer
          ? PaymentSource.jointAccount
          : PaymentSource.groceryCash;
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _uploadedFileName = file.name;
            _receiptImageBase64 =
                'data:image/jpeg;base64,${base64Encode(file.bytes!)}';
            _isScanningOcr = true;
          });

          final ocr = await ReceiptOcrService.processReceiptImage(
            imageBytes: file.bytes,
            fileName: file.name,
          );

          _applyOcrResult(ocr);
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      setState(() => _isScanningOcr = false);
    }
  }

  Future<void> _loadSampleReceipt(String receiptType) async {
    setState(() {
      _isScanningOcr = true;
      _uploadedFileName = '$receiptType-receipt.jpg';
    });

    final ocr = await ReceiptOcrService.processReceiptImage(
      fileName: receiptType,
    );

    _applyOcrResult(ocr);
  }

  void _applyOcrResult(OcrResult ocr) {
    setState(() {
      _isScanningOcr = false;
      _rawOcrText = ocr.rawText;
      if (ocr.merchant != null) {
        _merchantController.text = ocr.merchant!;
      }
      if (ocr.totalAmount != null) {
        _amountController.text = ocr.totalAmount!.toStringAsFixed(2);
      }
      if (ocr.category != null) {
        _selectedCategory = ocr.category!;
      }
      if (ocr.date != null) {
        _selectedDate = ocr.date!;
      }
      _candidateAmounts = ocr.candidateAmounts;
      _lineItems = List.from(ocr.lineItems);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Text('OCR Extracted: ${ocr.merchant ?? 'Receipt'} (HK\$${ocr.totalAmount?.toStringAsFixed(2) ?? '0.00'})'),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addLineItem() {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final priceCtrl = TextEditingController();
        final qtyCtrl = TextEditingController(text: '1');

        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Add Receipt Line Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name', hintText: 'e.g. Fresh Milk'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Unit Price (HK\$)', prefixText: 'HK\$ '),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity', hintText: '1'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0.0;
                final qty = int.tryParse(qtyCtrl.text) ?? 1;

                if (name.isNotEmpty && price > 0) {
                  setState(() {
                    _lineItems.add(ReceiptItem(name: name, price: price, quantity: qty));
                  });
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add Item'),
            ),
          ],
        );
      },
    );
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    final repo = context.read<AccountingRepository>();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid expense amount greater than 0'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ClaimStatus status;

    if (_selectedPaymentSource == PaymentSource.jointAccount ||
        _selectedPaymentSource == PaymentSource.groceryCash) {
      status = ClaimStatus.notApplicable;
    } else {
      status = widget.existingExpense?.claimStatus ?? ClaimStatus.unclaimed;
    }

    final expense = Expense(
      id: widget.existingExpense?.id ?? const Uuid().v4(),
      payer: widget.existingExpense?.payer ?? repo.currentUser,
      amount: amount,
      date: _selectedDate,
      merchant: _merchantController.text.trim().isEmpty
          ? 'Store'
          : _merchantController.text.trim(),
      category: _selectedCategory,
      description: _descController.text.trim(),
      itemizedDetails: _lineItems,
      paymentSource: _selectedPaymentSource,
      claimStatus: status,
      receiptPhotoBase64: _receiptImageBase64,
      rawOcrText: _rawOcrText,
      cycleId: widget.existingExpense?.cycleId ?? repo.selectedCycleId,
    );

    if (widget.existingExpense != null) {
      repo.updateExpense(expense);
    } else {
      repo.addExpense(expense);
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expense of HK\$${amount.toStringAsFixed(2)} saved!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final currentUser = repo.currentUser;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
        maxWidth: 950,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: currentUser.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(currentUser.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingExpense != null ? 'Edit Expense Record' : 'Record Money Spent',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Logged by ${currentUser.displayName} • Receipt Auto-OCR & Review',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
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
          ),
          const Divider(color: Color(0xFF334155), height: 1),

          // Body Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 650;

                    return isWide ? _buildWideLayout() : _buildCompactLayout();
                  },
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saveExpense,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(widget.existingExpense != null ? 'Save Changes' : 'Record Expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Receipt Dropzone & OCR Candidates
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReceiptScannerSection(),
              const SizedBox(height: 16),
              if (_candidateAmounts.isNotEmpty)
                CandidateAmountChips(
                  candidates: _candidateAmounts,
                  currentAmount: double.tryParse(_amountController.text) ?? 0.0,
                  onAmountSelected: (val) {
                    setState(() {
                      _amountController.text = val.toStringAsFixed(2);
                    });
                  },
                ),
              const SizedBox(height: 12),
              _buildRawOcrTextSection(),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: Form Fields & Line Items
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPaymentSourceSelector(),
              const SizedBox(height: 16),
              _buildFormFields(),
              const SizedBox(height: 16),
              _buildLineItemsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildReceiptScannerSection(),
        const SizedBox(height: 14),
        if (_candidateAmounts.isNotEmpty)
          CandidateAmountChips(
            candidates: _candidateAmounts,
            currentAmount: double.tryParse(_amountController.text) ?? 0.0,
            onAmountSelected: (val) {
              setState(() {
                _amountController.text = val.toStringAsFixed(2);
              });
            },
          ),
        const SizedBox(height: 14),
        _buildPaymentSourceSelector(),
        const SizedBox(height: 16),
        _buildFormFields(),
        const SizedBox(height: 16),
        _buildLineItemsSection(),
        const SizedBox(height: 12),
        _buildRawOcrTextSection(),
      ],
    );
  }

  Widget _buildReceiptScannerSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isScanningOcr
              ? const Color(0xFF6366F1)
              : const Color(0xFF334155),
          width: _isScanningOcr ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.document_scanner, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Receipt Photo & OCR Engine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              if (_isScanningOcr)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Upload or Preview Zone
          InkWell(
            onTap: _pickReceiptFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF475569),
                  style: BorderStyle.solid,
                ),
              ),
              alignment: Alignment.center,
              child: _isScanningOcr
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF6366F1)),
                        const SizedBox(height: 12),
                        Text(
                          'Scanning receipt with OCR engine...',
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                        ),
                      ],
                    )
                  : _receiptImageBase64 != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: _buildReceiptThumbnail(_receiptImageBase64!),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _uploadedFileName ?? 'Receipt attached',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const Text('Tap to change',
                                      style: TextStyle(
                                          fontSize: 10, color: Color(0xFF818CF8))),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo,
                                size: 36, color: Color(0xFF6366F1)),
                            const SizedBox(height: 8),
                            const Text(
                              'Take Photo or Upload Receipt',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supports JPG, PNG, PDF • Auto-extracts amount & merchant',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 10),

          // Instant Demo Test Receipts
          Text(
            'Or test with sample store receipts:',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickSampleChip('Wellcome', 'wellcome', Icons.local_grocery_store),
              _buildQuickSampleChip('Watsons', 'watsons', Icons.medication),
              _buildQuickSampleChip('PARKnSHOP', 'parknshop', Icons.shopping_basket),
              _buildQuickSampleChip('CLP Power', 'clp', Icons.bolt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSampleChip(String label, String code, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: const Color(0xFF818CF8)),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: const Color(0xFF1E293B),
      side: const BorderSide(color: Color(0xFF334155)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () => _loadSampleReceipt(code),
    );
  }

  Widget _buildPaymentSourceSelector() {
    final repo = context.watch<AccountingRepository>();
    final currentUser = repo.currentUser;
    final available = PaymentSource.availableSourcesFor(currentUser);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Payment Source / Status',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: currentUser.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'for ${currentUser.displayName}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: currentUser.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: available.map((source) {
            final isSelected = _selectedPaymentSource == source;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedPaymentSource = source;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? source.color.withOpacity(0.15)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? source.color : const Color(0xFF334155),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        source.icon,
                        color: isSelected ? source.color : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isSelected ? Colors.white : Colors.grey.shade300,
                              ),
                            ),
                            Text(
                              source.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<PaymentSource>(
                        value: source,
                        groupValue: _selectedPaymentSource,
                        activeColor: source.color,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPaymentSource = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount & Date in one row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Total Amount (HK\$)',
                  prefixText: 'HK\$ ',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    DateFormat('yyyy-MM-dd').format(_selectedDate),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Merchant Name
        TextFormField(
          controller: _merchantController,
          decoration: const InputDecoration(
            labelText: 'Merchant / Store Name',
            hintText: 'e.g. Wellcome, PARKnSHOP, Watsons',
            prefixIcon: Icon(Icons.storefront, size: 20),
          ),
          validator: (val) => val == null || val.trim().isEmpty ? 'Enter merchant name' : null,
        ),
        const SizedBox(height: 14),

        // Category Dropdown
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.category_outlined, size: 20),
          ),
          dropdownColor: const Color(0xFF1E293B),
          items: ReceiptParserRules.categories.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text(cat),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
        const SizedBox(height: 14),

        // Description / Notes
        TextFormField(
          controller: _descController,
          decoration: const InputDecoration(
            labelText: 'Notes / Description (Optional)',
            hintText: 'e.g. Weekly family grocery run',
            prefixIcon: Icon(Icons.notes, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, size: 18, color: Color(0xFF818CF8)),
              const SizedBox(width: 8),
              Text(
                'Itemized Line Items (${_lineItems.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLineItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (_lineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No line items extracted. Tap "Add Item" to add itemized breakdown.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lineItems.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
              itemBuilder: (context, idx) {
                final item = _lineItems[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      if (item.quantity > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        'HK\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _lineItems.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRawOcrTextSection() {
    if (_rawOcrText == null || _rawOcrText!.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _showRawOcrText,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: const Text(
          'Inspect Raw OCR Text Output',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            color: const Color(0xFF020617),
            child: Text(
              _rawOcrText!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptThumbnail(String dataUri) {
    try {
      if (dataUri.startsWith('data:image')) {
        final base64Str = dataUri.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } else {
        return Image.network(dataUri, fit: BoxFit.cover);
      }
    } catch (_) {
      return Container(
        color: const Color(0xFF334155),
        alignment: Alignment.center,
        child: const Icon(Icons.receipt_long, size: 36),
      );
    }
  }
}
