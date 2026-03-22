import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/services/inventory_service.dart';
import '../../../core/services/product_service.dart';

/// Full Inventory Management screen shared by Owner & Manufacturing Manager.
class OwnerInventory extends StatefulWidget {
  const OwnerInventory({super.key});

  @override
  State<OwnerInventory> createState() => _OwnerInventoryState();
}

class _OwnerInventoryState extends State<OwnerInventory> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryService>().fetchInventory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text('Inventory',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.fetchInventory(),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddStockDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add / Update Stock'),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          body: service.isLoading && service.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => service.fetchInventory(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (service.error != null)
                        _buildErrorBanner(service),
                      _buildKPICards(service),
                      const SizedBox(height: 20),
                      _buildInventoryList(service),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorBanner(InventoryService service) {
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

  Widget _buildKPICards(InventoryService service) {
    return Row(
      children: [
        Expanded(child: _KPICard(
          label: 'Total Stock',
          value: NumberFormat('#,###').format(service.totalStock),
          icon: Icons.inventory_2_outlined,
          color: Colors.teal,
        )),
        const SizedBox(width: 12),
        Expanded(child: _KPICard(
          label: 'Low Stock',
          value: '${service.lowStockCount}',
          icon: Icons.warning_amber_rounded,
          color: service.lowStockCount > 0 ? Colors.orange : Colors.green,
        )),
        const SizedBox(width: 12),
        Expanded(child: _KPICard(
          label: 'Out of Stock',
          value: '${service.outOfStockCount}',
          icon: Icons.remove_shopping_cart_outlined,
          color: service.outOfStockCount > 0 ? Colors.red : Colors.green,
        )),
      ],
    );
  }

  Widget _buildInventoryList(InventoryService service) {
    if (service.items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('No inventory items yet.',
                    style: GoogleFonts.poppins(color: Colors.grey)),
                const SizedBox(height: 4),
                Text('Tap "Add / Update Stock" to get started.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stock Levels',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...service.items.map((item) => _buildInventoryTile(item)),
      ],
    );
  }

  Widget _buildInventoryTile(InventoryItem item) {
    Color statusColor;
    String statusLabel;
    if (item.isOutOfStock) {
      statusColor = Colors.red;
      statusLabel = 'OUT';
    } else if (item.isLowStock) {
      statusColor = Colors.orange;
      statusLabel = 'LOW';
    } else {
      statusColor = Colors.green;
      statusLabel = 'OK';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Status badge
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(statusLabel,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ),
            const SizedBox(width: 14),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat('#,###').format(item.stockQuantity)} ${item.unit ?? 'units'}'
                    '${item.rawMaterialQty != null ? ' • Raw: ${NumberFormat('#,###').format(item.rawMaterialQty)}' : ''}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (item.notes != null && item.notes!.isNotEmpty)
                    Text(item.notes!,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Quick adjust buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdjustButton(
                  icon: Icons.remove,
                  color: Colors.red,
                  onPressed: () => _showAdjustDialog(item, isAdd: false),
                ),
                const SizedBox(width: 4),
                _AdjustButton(
                  icon: Icons.add,
                  color: Colors.green,
                  onPressed: () => _showAdjustDialog(item, isAdd: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustDialog(InventoryItem item, {required bool isAdd}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? 'Add Stock' : 'Remove Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item.productName} — current: ${NumberFormat('#,###').format(item.stockQuantity)}',
                style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(isAdd ? Icons.add : Icons.remove),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final qty = int.tryParse(controller.text);
              if (qty == null || qty <= 0) return;
              Navigator.pop(ctx);
              final delta = isAdd ? qty : -qty;
              await context.read<InventoryService>().adjustStock(item.id, delta);
            },
            child: Text(isAdd ? 'Add' : 'Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _AddStockSheet(),
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

class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _AdjustButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

/// Bottom sheet for adding/updating stock.
class _AddStockSheet extends StatefulWidget {
  const _AddStockSheet();

  @override
  State<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends State<_AddStockSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProduct;
  final _stockController = TextEditingController();
  final _rawMaterialController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _stockController.dispose();
    _rawMaterialController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductService>().products;
    final inventoryItems = context.watch<InventoryService>().items;
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
              Text('Add / Update Stock',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // Product dropdown
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
                onChanged: (v) {
                  setState(() => _selectedProduct = v);
                  // Pre-fill current stock if exists
                  final existing = inventoryItems.where(
                    (i) => i.productName.toLowerCase() == v?.toLowerCase()
                  );
                  if (existing.isNotEmpty) {
                    _stockController.text = existing.first.stockQuantity.toString();
                    _rawMaterialController.text =
                        existing.first.rawMaterialQty?.toString() ?? '';
                    _notesController.text = existing.first.notes ?? '';
                  }
                },
                validator: (v) => v == null ? 'Select a product' : null,
              ),
              const SizedBox(height: 14),

              // Stock quantity
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity (finished goods) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Enter valid number';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Raw material
              TextFormField(
                controller: _rawMaterialController,
                decoration: const InputDecoration(
                  labelText: 'Raw Material Qty (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grain),
                ),
                keyboardType: TextInputType.number,
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
                label: Text(_isSubmitting ? 'Saving...' : 'Save Stock'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
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

    final success = await context.read<InventoryService>().upsertStock(
      productName: _selectedProduct!,
      productId: product.id,
      stockQuantity: int.parse(_stockController.text),
      rawMaterialQty: int.tryParse(_rawMaterialController.text),
      unit: product.unit,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully!'),
            backgroundColor: Colors.green),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<InventoryService>().error ?? 'Failed'),
            backgroundColor: Colors.red),
      );
    }
  }
}
