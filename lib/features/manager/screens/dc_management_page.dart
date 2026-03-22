import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/services/order_service.dart';
import '../../../core/theme/app_theme.dart';

class DCManagementPage extends StatefulWidget {
  const DCManagementPage({super.key});

  @override
  State<DCManagementPage> createState() => _DCManagementPageState();
}

class _DCManagementPageState extends State<DCManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchAllOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Order> _search(List<Order> orders) {
    if (_searchQuery.isEmpty) return orders;
    final q = _searchQuery.toLowerCase();
    return orders.where((o) =>
      o.customerName.toLowerCase().contains(q) ||
      (o.customerPhone?.contains(q) ?? false) ||
      (o.orderNumber?.toLowerCase().contains(q) ?? false) ||
      (o.dcNumber?.toLowerCase().contains(q) ?? false) ||
      (o.customerAddress?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  List<Order> _filterByMonth(List<Order> orders) {
    return orders.where((o) =>
      o.createdAt.year == _selectedYear &&
      o.createdAt.month == _selectedMonth
    ).toList();
  }

  List<Order> _pending(List<Order> orders) => _search(_filterByMonth(orders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).toList()));
  List<Order> _delivered(List<Order> orders) => _search(_filterByMonth(orders.where((o) => o.status == OrderStatus.delivered).toList()));

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<OrderService>();
    final pending = _pending(svc.orders);
    final delivered = _delivered(svc.orders);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, DC#, address...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 13),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              // Month & Year Selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  // Year Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      underline: const SizedBox(),
                      items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                          .map((year) => DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              ))
                          .toList(),
                      onChanged: (year) {
                        if (year != null) setState(() => _selectedYear = year);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Month Dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: List.generate(12, (i) => i + 1)
                            .map((month) => DropdownMenuItem(
                                  value: month,
                                  child: Text(_monthNames[month - 1]),
                                ))
                            .toList(),
                        onChanged: (month) {
                          if (month != null) setState(() => _selectedMonth = month);
                        },
                      ),
                    ),
                  ),
                ]),
              ),
              // Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFF1E293B),
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: [
                      Tab(text: 'Pending (${pending.length})'),
                      Tab(text: 'Delivered (${delivered.length})'),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          // Content
          Expanded(
            child: svc.isLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingList(pending),
                    _buildDeliveredList(delivered),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────
  // PENDING LIST
  // ──────────────────────────────────

  Widget _buildPendingList(List<Order> orders) {
    if (orders.isEmpty) return _empty(Icons.check_circle_outline, 'All caught up!', 'No pending deliveries');
    return RefreshIndicator(
      onRefresh: () => context.read<OrderService>().fetchAllOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) => _pendingCard(orders[i]),
      ),
    );
  }

  Widget _pendingCard(Order order) {
    String items = order.items.map((i) {
      final name = (i['product_name'] as String? ?? i['brick_type'] as String? ?? 'Bricks').split(' ').first;
      return '${i['quantity']} $name';
    }).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Info
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.local_shipping_outlined, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis)),
                Text(order.orderNumber ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 4),
              Text(items, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              if (order.customerAddress != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(order.customerAddress!, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ])),
          ]),
        ),
        // Action
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMarkDeliveredDialog(order),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('Mark as Delivered', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ──────────────────────────────────
  // DELIVERED LIST
  // ──────────────────────────────────

  Widget _buildDeliveredList(List<Order> orders) {
    if (orders.isEmpty) return _empty(Icons.local_shipping_outlined, 'No deliveries yet', 'Delivered orders appear here');
    final dateFmt = DateFormat('dd MMM yyyy');
    return RefreshIndicator(
      onRefresh: () => context.read<OrderService>().fetchAllOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) {
          final order = orders[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD1FAE5)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onLongPress: () => _showDeliveredActions(order),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.check, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (order.dcNumber != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(4)),
                            child: Text('DC: ${order.dcNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(order.orderNumber ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                      if (order.deliveryDate != null)
                        Text(dateFmt.format(order.deliveryDate!), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ]),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────
  // MARK DELIVERED DIALOG
  // ──────────────────────────────────

  void _showMarkDeliveredDialog(Order order) {
    final dcCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setDlg) {
        final dateFmt = DateFormat('dd MMM yyyy');
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Mark as Delivered', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(order.customerName, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 20),

            // DC Number
            TextField(
              controller: dcCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'DC Number *',
                hintText: 'e.g., DC-001',
                prefixIcon: const Icon(Icons.receipt_outlined, size: 20, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
              ),
            ),
            const SizedBox(height: 12),

            // Delivery Date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now());
                if (picked != null) setDlg(() => selectedDate = picked);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0E0E0))),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  Text(dateFmt.format(selectedDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: () async {
                  if (dcCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter DC number'), backgroundColor: Colors.orange));
                    return;
                  }
                  Navigator.pop(ctx);
                  final ok = await context.read<OrderService>().markAsDelivered(orderId: order.id, dcNumber: dcCtrl.text.trim(), deliveryDate: selectedDate);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'Marked as delivered' : 'Failed'),
                      backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
                    ));
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
            ]),
          ]),
        );
      }),
    );
  }

  // ──────────────────────────────────
  // DELIVERED ACTIONS (Edit DC / Undo)
  // ──────────────────────────────────

  void _showDeliveredActions(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(order.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (order.dcNumber != null) Text('DC: ${order.dcNumber}', style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          _actionTile(Icons.edit_outlined, 'Edit DC Number', 'Change the delivery challan number', const Color(0xFF3B82F6), () {
            Navigator.pop(sheetCtx);
            _showEditDCDialog(order);
          }),
          _actionTile(Icons.undo_outlined, 'Undo Delivery', 'Revert back to confirmed status', const Color(0xFFD97706), () {
            Navigator.pop(sheetCtx);
            _confirmUndo(order);
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  void _showEditDCDialog(Order order) {
    final dcCtrl = TextEditingController(text: order.dcNumber ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Edit DC Number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: dcCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'DC Number',
              prefixIcon: const Icon(Icons.receipt_outlined, size: 20, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
              filled: true, fillColor: const Color(0xFFFAFAFA),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(sheetCtx);
                await context.read<OrderService>().markAsDelivered(orderId: order.id, dcNumber: dcCtrl.text.trim(), deliveryDate: order.deliveryDate);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DC number updated'), backgroundColor: Color(0xFF10B981)));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Update DC', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmUndo(Order order) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Undo Delivery?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('This will revert ${order.customerName}\'s order back to Confirmed status and clear the DC number.', style: const TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('No', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await context.read<OrderService>().undoDelivery(order.id);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Delivery undone' : 'Failed'), backgroundColor: ok ? const Color(0xFFD97706) : Colors.red));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _empty(IconData icon, String title, String sub) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(50)), child: Icon(icon, size: 48, color: const Color(0xFF94A3B8))),
      const SizedBox(height: 20),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      const SizedBox(height: 8),
      Text(sub, style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
    ]));
  }
}
