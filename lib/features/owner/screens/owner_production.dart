import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/services/production_service.dart';
import '../../../core/services/product_service.dart';

/// Full-featured Production Tracking screen shared by Owner & Manufacturing Manager.
class OwnerProduction extends StatefulWidget {
  const OwnerProduction({super.key});

  @override
  State<OwnerProduction> createState() => _OwnerProductionState();
}

class _OwnerProductionState extends State<OwnerProduction> {
  String _selectedPeriod = 'Today';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductionService>().fetchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductionService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text('Production Tracking',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.fetchLogs(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showLogProductionDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Log Production'),
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          body: service.isLoading && service.logs.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => service.fetchLogs(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (service.error != null)
                        _buildErrorBanner(service),
                      _buildKPICards(service),
                      const SizedBox(height: 20),
                      _buildPeriodSelector(),
                      const SizedBox(height: 12),
                      _buildProductSummary(service),
                      const SizedBox(height: 20),
                      _buildRecentLogs(service),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorBanner(ProductionService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(service.error!,
              style: TextStyle(color: Colors.red.shade700))),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => service.clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICards(ProductionService service) {
    return Row(
      children: [
        Expanded(child: _KPICard(
          label: "Today's Output",
          value: NumberFormat('#,###').format(service.todaysTotal),
          icon: Icons.factory_outlined,
          color: Colors.blue,
        )),
        const SizedBox(width: 12),
        Expanded(child: _KPICard(
          label: 'Defects',
          value: NumberFormat('#,###').format(service.todaysDefects),
          icon: Icons.warning_amber_rounded,
          color: service.todaysDefects > 0 ? Colors.orange : Colors.green,
        )),
        const SizedBox(width: 12),
        Expanded(child: _KPICard(
          label: 'Quality',
          value: '${service.todaysQualityRate.toStringAsFixed(1)}%',
          icon: Icons.verified_outlined,
          color: service.todaysQualityRate >= 95
              ? Colors.green
              : service.todaysQualityRate >= 85
                  ? Colors.orange
                  : Colors.red,
        )),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Text('Summary', style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w600)),
        const Spacer(),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Today', label: Text('Today')),
            ButtonSegment(value: 'Week', label: Text('Week')),
            ButtonSegment(value: 'Month', label: Text('Month')),
          ],
          selected: {_selectedPeriod},
          onSelectionChanged: (v) => setState(() => _selectedPeriod = v.first),
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.poppins(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildProductSummary(ProductionService service) {
    final now = DateTime.now();
    DateTime from;
    switch (_selectedPeriod) {
      case 'Week':
        from = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Month':
        from = DateTime(now.year, now.month, 1);
        break;
      default:
        from = DateTime(now.year, now.month, now.day);
    }

    final summary = service.getProductSummary(
      from: from,
      to: now,
    );

    if (summary.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('No production logged for this period.',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
        ),
      );
    }

    final sortedEntries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product-wise Output',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            ...sortedEntries.map((e) {
              final maxQty = sortedEntries.first.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: GoogleFonts.poppins(fontSize: 13)),
                        Text(NumberFormat('#,###').format(e.value),
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: e.value / maxQty,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.deepOrange,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLogs(ProductionService service) {
    // Show last 20 logs
    final recentLogs = service.logs.take(20).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Production Logs',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (recentLogs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.factory_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No production logs yet.',
                        style: GoogleFonts.poppins(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('Tap "Log Production" to start tracking.',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          )
        else
          ...recentLogs.map((log) => _buildLogTile(log)),
      ],
    );
  }

  Widget _buildLogTile(ProductionLog log) {
    final dateStr = DateFormat('dd MMM yyyy').format(log.productionDate);
    final isToday = _isToday(log.productionDate);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isToday ? Colors.deepOrange.shade50 : Colors.grey.shade100,
          child: Icon(Icons.factory_outlined,
              color: isToday ? Colors.deepOrange : Colors.grey.shade600,
              size: 20),
        ),
        title: Text(log.productName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${NumberFormat('#,###').format(log.quantity)} units • $dateStr'
          '${log.defectCount != null && log.defectCount! > 0 ? ' • ${log.defectCount} defects' : ''}',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Log?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await context.read<ProductionService>().deleteLog(log.id);
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showLogProductionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _LogProductionSheet(),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KPICard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for logging new production.
class _LogProductionSheet extends StatefulWidget {
  const _LogProductionSheet();

  @override
  State<_LogProductionSheet> createState() => _LogProductionSheetState();
}

class _LogProductionSheetState extends State<_LogProductionSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProduct;
  final _quantityController = TextEditingController();
  final _defectController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  DateTime _productionDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _defectController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductService>().products;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Log Production',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // Product
              DropdownButtonFormField<String>(
                initialValue: _selectedProduct,
                decoration: const InputDecoration(
                  labelText: 'Product *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: products.map((p) => DropdownMenuItem(
                  value: p.name,
                  child: Text(p.name),
                )).toList(),
                onChanged: (v) => setState(() => _selectedProduct = v),
                validator: (v) => v == null ? 'Select a product' : null,
              ),
              const SizedBox(height: 14),

              // Quantity + Defects row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final n = int.tryParse(v);
                        if (n == null || n <= 0) return 'Enter valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _defectController,
                      decoration: const InputDecoration(
                        labelText: 'Defects',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Date picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _productionDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _productionDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Production Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_productionDate),
                      style: GoogleFonts.poppins()),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Submit
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_isSubmitting ? 'Saving...' : 'Save Production Log'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final productService = context.read<ProductService>();
    final product = productService.products.firstWhere(
      (p) => p.name == _selectedProduct,
    );

    final result = await context.read<ProductionService>().logProduction(
      productName: _selectedProduct!,
      productId: product.id,
      quantity: int.parse(_quantityController.text),
      defectCount: int.tryParse(_defectController.text) ?? 0,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      productionDate: _productionDate,
    );

    if (!mounted) return;

    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Production logged successfully!'),
            backgroundColor: Colors.green),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<ProductionService>().error ?? 'Failed'),
            backgroundColor: Colors.red),
      );
    }
  }
}
