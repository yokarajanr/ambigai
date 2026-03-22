import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/order_service.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/theme/app_theme.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchAllOrders();
    });
  }

  List<Order> _filterOrders(List<Order> orders) {
    // First filter by selected month
    var filtered = orders.where((o) =>
      o.createdAt.year == _selectedMonth.year &&
      o.createdAt.month == _selectedMonth.month
    ).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((o) =>
        o.customerName.toLowerCase().contains(q) ||
        (o.orderNumber?.toLowerCase().contains(q) ?? false) ||
        (o.customerPhone?.contains(q) ?? false)
      ).toList();
    }
    if (_statusFilter != 'all') {
      filtered = filtered.where((o) => o.status.dbValue == _statusFilter).toList();
    }
    return filtered;
  }

  void _goToPrevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<OrderService>();
    final orders = _filterOrders(orderService.orders);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(orderService),
          Expanded(
            child: orderService.isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : RefreshIndicator(
                    onRefresh: () => orderService.fetchAllOrders(),
                    child: orders.isEmpty
                      ? _buildEmptyMonthState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: orders.length,
                          itemBuilder: (_, i) => _buildOrderCard(orders[i]),
                        ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final location = GoRouterState.of(context).matchedLocation;
          final prefix = location.startsWith('/owner') ? '/owner' : '/office-manager';
          context.push('$prefix/new-order');
        },
        backgroundColor: AppTheme.primaryColor,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _goToPrevMonth,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: AppTheme.primaryColor,
            splashRadius: 22,
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialEntryMode: DatePickerEntryMode.calendarOnly,
              );
              if (picked != null) {
                setState(() => _selectedMonth = DateTime(picked.year, picked.month));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(monthLabel,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor)),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _isCurrentMonth ? null : _goToNextMonth,
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: _isCurrentMonth ? Colors.grey.shade300 : AppTheme.primaryColor,
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonthState() {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    return ListView(
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),
              Text('No orders in $monthLabel',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              const Text('Try selecting a different month',
                  style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(OrderService svc) {
    // Count based on selected month's orders (after month filter, before search/status)
    final monthOrders = svc.orders.where((o) =>
      o.createdAt.year == _selectedMonth.year &&
      o.createdAt.month == _selectedMonth.month
    ).toList();
    final counts = {
      'all': monthOrders.length,
      'pending': monthOrders.where((o) => o.status == OrderStatus.pending).length,
      'delivered': monthOrders.where((o) => o.status == OrderStatus.delivered).length,
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Month selector
          _buildMonthSelector(),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search orders...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 13),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _exportCurrentOrders,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.download_outlined, size: 18, color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              children: [
                _filterChip('All', 'all', counts['all'] ?? 0),
                _filterChip('Pending', 'pending', counts['pending'] ?? 0),
                _filterChip('Delivered', 'delivered', counts['delivered'] ?? 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCurrentOrders() async {
    final orderService = context.read<OrderService>();
    final filteredOrders = _filterOrders(orderService.orders);

    if (filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    final monthLabel = DateFormat('MMM_yyyy').format(_selectedMonth);
    final statusSuffix = _statusFilter == 'all' ? 'All' : _statusFilter;
    final fileName = 'Orders_${monthLabel}_$statusSuffix.xlsx';

    try {
      await ExcelExportService.exportOrdersToExcel(filteredOrders, fileName: fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orders exported successfully'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _filterChip(String label, String value, int count) {
    final sel = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? AppTheme.primaryColor : const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF64748B))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sel ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : const Color(0xFF64748B))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final dateFormat = DateFormat('dd MMM');
    int totalQty = 0;
    String itemsSummary = '';
    for (var item in order.items) {
      totalQty += (item['quantity'] as int? ?? 0);
    }
    if (order.items.isNotEmpty) {
      itemsSummary = '${order.items.first['product_name'] ?? order.items.first['brick_type'] ?? 'Bricks'}';
      if (order.items.length > 1) itemsSummary += ' +${order.items.length - 1}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOrderSheet(order),
          onLongPress: () => _showQuickActions(order),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Row 1: Name + Status
                Row(
                  children: [
                    _avatar(order),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('${order.orderNumber ?? '#'} · ${dateFormat.format(order.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    _statusBadge(order.status),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                // Row 2: Items + Qty + Amount
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 15, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Expanded(child: Text(itemsSummary, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Text('$totalQty pcs', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showInvoiceOptions(order),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF7C3AED)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  ],
                ),
                // Payment warning
                if (order.paymentStatus != PaymentStatus.paid && order.status == OrderStatus.delivered) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: order.amountPaid > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(order.amountPaid > 0 ? Icons.schedule : Icons.warning_amber_rounded, size: 13, color: order.amountPaid > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Text(
                          order.amountPaid > 0
                            ? 'Partial: ₹${order.amountPaid.toStringAsFixed(0)} / ₹${order.totalAmount.toStringAsFixed(0)}'
                            : 'Payment due: ₹${order.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: order.amountPaid > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(Order order) {
    final c = _statusColor(order.status);
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Center(child: Text(order.customerName.isNotEmpty ? order.customerName[0].toUpperCase() : '?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c))),
    );
  }

  Widget _statusBadge(OrderStatus s) {
    final colors = {
      OrderStatus.pending: (const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      OrderStatus.confirmed: (const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
      OrderStatus.processing: (const Color(0xFFEDE9FE), const Color(0xFF7C3AED)),
      OrderStatus.ready: (const Color(0xFFCFFAFE), const Color(0xFF0891B2)),
      OrderStatus.delivered: (const Color(0xFFD1FAE5), const Color(0xFF059669)),
      OrderStatus.cancelled: (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
    };
    final (bg, fg) = colors[s] ?? (const Color(0xFFF1F5F9), const Color(0xFF64748B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(s.displayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending: return const Color(0xFFD97706);
      case OrderStatus.confirmed: return const Color(0xFF2563EB);
      case OrderStatus.processing: return const Color(0xFF7C3AED);
      case OrderStatus.ready: return const Color(0xFF0891B2);
      case OrderStatus.delivered: return const Color(0xFF059669);
      case OrderStatus.cancelled: return const Color(0xFFDC2626);
    }
  }

  // ──────────────────────────────────
  // QUICK ACTIONS (Long Press)
  // ──────────────────────────────────

  void _showQuickActions(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(order.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(order.orderNumber ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),

            _actionTile(Icons.edit_outlined, 'Edit Order', 'Change customer info, items, amount', const Color(0xFF3B82F6), () {
              Navigator.pop(sheetCtx);
              _showEditDialog(order);
            }),
            if (order.status != OrderStatus.cancelled)
              _actionTile(Icons.cancel_outlined, 'Cancel Order', 'Mark as cancelled', const Color(0xFFEF4444), () {
                Navigator.pop(sheetCtx);
                _confirmCancel(order);
              }),
            _actionTile(Icons.delete_outline, 'Delete Order', 'Permanently remove this order', const Color(0xFFDC2626), () {
              Navigator.pop(sheetCtx);
              _confirmDelete(order);
            }),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
      contentPadding: EdgeInsets.zero,
    );
  }

  // ──────────────────────────────────
  // EDIT ORDER DIALOG
  // ──────────────────────────────────

  void _showEditDialog(Order order) {
    final nameCtrl = TextEditingController(text: order.customerName);
    final phoneCtrl = TextEditingController(text: order.customerPhone ?? '');
    final addressCtrl = TextEditingController(text: order.customerAddress ?? '');
    final notesCtrl = TextEditingController(text: order.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Edit Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(order.orderNumber ?? '', style: const TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 20),

              _editField(nameCtrl, 'Customer Name', Icons.person_outline),
              const SizedBox(height: 12),
              _editField(phoneCtrl, 'Phone Number', Icons.phone_outlined, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _editField(addressCtrl, 'Address', Icons.location_on_outlined, maxLines: 2),
              const SizedBox(height: 12),
              _editField(notesCtrl, 'Notes', Icons.note_outlined, maxLines: 2),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        final svc = context.read<OrderService>();
                        final ok = await svc.updateOrder(
                          orderId: order.id,
                          customerName: nameCtrl.text.trim(),
                          customerPhone: phoneCtrl.text.trim(),
                          customerAddress: addressCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok ? 'Order updated' : 'Update failed'),
                            backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboard, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ──────────────────────────────────
  // ──────────────────────────────────
  // CONFIRM CANCEL / DELETE
  // ──────────────────────────────────

  void _confirmCancel(Order order) {
    _confirmAction(
      title: 'Cancel Order?',
      message: 'Are you sure you want to cancel ${order.customerName}\'s order?',
      confirmLabel: 'Yes, Cancel',
      confirmColor: const Color(0xFFEF4444),
      onConfirm: () async {
        await context.read<OrderService>().cancelOrder(order.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled'), backgroundColor: Color(0xFFEF4444)));
      },
    );
  }

  void _confirmDelete(Order order) {
    _confirmAction(
      title: 'Delete Order?',
      message: 'This will permanently remove ${order.customerName}\'s order and all related data (payment, DC, status). This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: const Color(0xFFDC2626),
      onConfirm: () async {
        final svc = context.read<OrderService>();
        final ok = await svc.deleteOrder(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? 'Order deleted permanently'
                : (svc.error ?? 'Failed to delete order')),
            backgroundColor: ok ? const Color(0xFFDC2626) : Colors.red,
            duration: Duration(seconds: ok ? 2 : 5),
          ));
          if (!ok) {
            debugPrint('Delete failed — error: ${svc.error}');
          }
        }
      },
    );
  }

  void _confirmAction({required String title, required String message, required String confirmLabel, required Color confirmColor, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(message, style: const TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('No', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            onPressed: () { Navigator.pop(dialogCtx); onConfirm(); },
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────
  // ORDER DETAILS SHEET
  // ──────────────────────────────────

  void _showOrderSheet(Order order) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(order.orderNumber ?? 'Order', style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(order.customerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        ])),
                        _statusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        if (order.customerPhone != null) _infoRow(Icons.phone_outlined, order.customerPhone!),
                        if (order.customerAddress != null) _infoRow(Icons.location_on_outlined, order.customerAddress!),
                        _infoRow(Icons.calendar_today_outlined, dateFormat.format(order.createdAt)),
                        if (order.dcNumber != null) _infoRow(Icons.local_shipping_outlined, 'DC: ${order.dcNumber}'),
                        if (order.notes != null && order.notes!.isNotEmpty) _infoRow(Icons.note_outlined, order.notes!),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Items
                    const Text('Order Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    ...order.items.map((item) => Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${item['product_name'] ?? item['brick_type'] ?? 'Brick'}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          Text('${item['quantity']} × ₹${item['rate'] ?? item['price_per_unit'] ?? 0}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ])),
                        Text('₹${item['amount'] ?? item['total_price'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ]),
                    )),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text('₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.primaryColor)),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Payment info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: order.paymentStatus == PaymentStatus.paid ? const Color(0xFFD1FAE5) : order.amountPaid > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(
                          order.paymentStatus == PaymentStatus.paid ? Icons.check_circle : order.amountPaid > 0 ? Icons.schedule : Icons.pending,
                          size: 20,
                          color: order.paymentStatus == PaymentStatus.paid ? const Color(0xFF059669) : order.amountPaid > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(order.paymentStatus == PaymentStatus.paid ? 'Fully Paid' : order.amountPaid > 0 ? 'Partially Paid' : 'Unpaid',
                            style: TextStyle(fontWeight: FontWeight.w600, color: order.paymentStatus == PaymentStatus.paid ? const Color(0xFF059669) : order.amountPaid > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626))),
                          if (order.paymentStatus != PaymentStatus.paid)
                            Text('Paid: ₹${order.amountPaid.toStringAsFixed(0)} | Due: ₹${(order.totalAmount - order.amountPaid).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ])),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(child: _sheetAction(Icons.edit_outlined, 'Edit', const Color(0xFF3B82F6), () { Navigator.pop(sheetCtx); _showEditDialog(order); })),
                        const SizedBox(width: 8),
                        Expanded(child: _sheetAction(Icons.receipt_long_outlined, 'Invoice', const Color(0xFF8B5CF6), () { Navigator.pop(sheetCtx); _showInvoiceOptions(order); })),
                        const SizedBox(width: 8),
                        if (order.status != OrderStatus.cancelled)
                          Expanded(child: _sheetAction(Icons.cancel_outlined, 'Cancel', const Color(0xFFEF4444), () { Navigator.pop(sheetCtx); _confirmCancel(order); })),
                        if (order.status != OrderStatus.cancelled)
                          const SizedBox(width: 8),
                        Expanded(child: _sheetAction(Icons.delete_outline, 'Delete', const Color(0xFFDC2626), () { Navigator.pop(sheetCtx); _confirmDelete(order); })),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────
  // INVOICE SHARING
  // ──────────────────────────────────

  void _showInvoiceOptions(Order order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Share Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.copy, color: Color(0xFF4CAF50)),
              ),
              title: const Text('Copy to Clipboard'),
              subtitle: const Text('Copy invoice text for manual sharing'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: InvoiceService.generateTextInvoice(order)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice copied to clipboard!'), backgroundColor: Color(0xFF4CAF50)),
                );
              },
            ),
            if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.chat, color: Color(0xFF25D366)),
                ),
                title: const Text('Send via WhatsApp'),
                subtitle: Text('Send to ${order.customerPhone}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  var opened = false;
                  for (final uri in InvoiceService.generateWhatsAppUris(order)) {
                    try {
                      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (ok) {
                        opened = true;
                        break;
                      }
                    } catch (_) {
                      // Try fallback URL format.
                    }
                  }
                  if (!opened && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open WhatsApp'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            // Preview option
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEDE7F6),
                child: Icon(Icons.preview, color: Color(0xFF7C4DFF)),
              ),
              title: const Text('Preview Invoice'),
              subtitle: const Text('View formatted invoice text'),
              onTap: () {
                Navigator.pop(ctx);
                _showInvoicePreview(order);
              },
            ),
            // PDF Invoice
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFCE4EC),
                child: Icon(Icons.picture_as_pdf, color: Color(0xFFE53935)),
              ),
              title: const Text('Share as PDF'),
              subtitle: const Text('Generate and share professional PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await PdfInvoiceService.shareInvoice(order);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoicePreview(Order order) {
    final invoiceText = InvoiceService.generateTextInvoice(order);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            const Text('Invoice Preview', style: TextStyle(fontSize: 16)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invoiceText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              invoiceText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _sheetAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 17, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF475569)))),
      ]),
    );
  }
}
