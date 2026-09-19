import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/domain/models/models.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

/// Form screen for creating or editing a billing entry.
/// Pass an [entry] to edit an existing one; omit to create new.
class BillEditScreen extends StatefulWidget {
  final BillingEntry? entry;

  const BillEditScreen({super.key, this.entry});

  @override
  State<BillEditScreen> createState() => _BillEditScreenState();
}

class _BillEditScreenState extends State<BillEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _dueDateController;

  late BillingType _selectedType;
  late BillingCycle? _selectedCycle;
  DateTime? _selectedDueDate;

  bool _isLoading = false;
  String? _errorMessage;

  static const List<BillingCycle> _cycles = [
    BillingCycle.daily,
    BillingCycle.weekly,
    BillingCycle.biweekly,
    BillingCycle.monthly,
    BillingCycle.quarterly,
    BillingCycle.yearly,
  ];

  static const Map<BillingCycle, String> _cycleLabels = {
    BillingCycle.daily: 'Daily',
    BillingCycle.weekly: 'Weekly',
    BillingCycle.biweekly: 'Bi-weekly',
    BillingCycle.monthly: 'Monthly',
    BillingCycle.quarterly: 'Quarterly',
    BillingCycle.yearly: 'Yearly',
  };


  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _amountController = TextEditingController(
      text: widget.entry != null
          ? widget.entry!.amountDue.toStringAsFixed(2)
          : '',
    );
    _selectedType = widget.entry?.type ?? BillingType.bill;
    _selectedCycle = widget.entry?.cycle;
    _selectedDueDate = widget.entry?.nextDueDate;
    _dueDateController = TextEditingController(
      text: _selectedDueDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDueDate!)
          : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.isEmpty) return;
    if (amount == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'title': title,
        'amount_due': amount,
        'item_type': _selectedType.name,
        'billing_cycle': _selectedCycle?.name,
        'next_due_date': _selectedDueDate?.toIso8601String(),
        'is_active': true,
      };

      late final dynamic response;
      if (widget.entry == null) {
        payload['id'] = _uuid.v4();
        response = await ApiClient.dio.post(
          '/billing',
          data: payload,
        );
      } else {
        response = await ApiClient.dio.put(
          '/billing/${widget.entry!.id}',
          data: payload,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.entry == null ? 'Bill added successfully' : 'Bill updated successfully',
              ),
              backgroundColor: AppColors.resolved(context),
            ),
          );
        }
      } else {
        throw Exception('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markPaid() async {
    if (widget.entry == null) return;

    setState(() => _isLoading = true);
    try {
      final resp = await ApiClient.dio.post('/billing/${widget.entry!.id}/paid');
      if (resp.statusCode == 200 && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marked as paid'),
            backgroundColor: AppColors.resolved(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as paid: $e'),
            backgroundColor: AppColors.urgent(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text(
          'Are you sure you want to delete "${widget.entry!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.urgent(context)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ApiClient.dio.delete('/billing/${widget.entry!.id}');
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bill deleted'),
            backgroundColor: AppColors.urgent(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppColors.urgent(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final accentColor = AppColors.accent(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight,
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Bill' : 'Edit Bill'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type toggle: Bill vs Subscription
            _buildTypeToggle(accentColor),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.attach_money),
                suffixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Amount is required';
                if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Due date picker
            TextFormField(
              controller: _dueDateController,
              decoration: const InputDecoration(
                labelText: 'Next Due Date',
                prefixIcon: Icon(Icons.calendar_today),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              readOnly: true,
              onTap: _selectDueDate,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Due date is required';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Billing cycle dropdown
            DropdownButtonFormField<BillingCycle?>(
              initialValue: _selectedCycle,
              decoration: const InputDecoration(
                labelText: 'Billing Cycle',
                prefixIcon: Icon(Icons.refresh),
              ),
              hint: const Text('Select cycle'),
              items: [
                const DropdownMenuItem<BillingCycle?>(
                  value: null,
                  child: Text('One-time'),
                ),
                ..._cycles.map((cycle) => DropdownMenuItem(
                      value: cycle,
                      child: Text(_cycleLabels[cycle] ?? cycle.name),
                    )),
              ],
              onChanged: (value) {
                setState(() => _selectedCycle = value);
              },
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.urgent(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppColors.urgent(context)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Mark Paid button (edit mode only)
            if (widget.entry != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _markPaid,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Paid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.resolved(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.urgent(context),
                    side: BorderSide(color: AppColors.urgent(context)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(Color accentColor) {
    return Row(
      children: [
        const Text('Type:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeChip(
            label: 'Bill',
            selected: _selectedType == BillingType.bill,
            onTap: () => setState(() => _selectedType = BillingType.bill),
            accentColor: accentColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TypeChip(
            label: 'Subscription',
            selected: _selectedType == BillingType.subscription,
            onTap: () => setState(() => _selectedType = BillingType.subscription),
            accentColor: accentColor,
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accentColor : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? accentColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
