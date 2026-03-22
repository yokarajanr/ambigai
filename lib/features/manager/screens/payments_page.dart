import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/order_service.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/theme/app_theme.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String _searchQuery = '';

  final _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<OrderService>().fetchAllOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Order> _filtered(List<Order> orders) {
    var r = orders.where((o) => o.createdAt.year == _selectedYear && o.createdAt.month == _selectedMonth).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      r = r.where((o) =>
        o.customerName.toLowerCase().contains(q) ||
        (o.customerPhone?.contains(q) ?? false) ||
        (o.orderNumber?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return r;
  }

  List<Order> _unpaid(List<Order> orders) => _filtered(orders).where((o) => o.paymentStatus != PaymentStatus.paid && o.amountPaid == 0).toList();
  List<Order> _partial(List<Order> orders) => _filtered(orders).where((o) => o.paymentStatus != PaymentStatus.paid && o.amountPaid > 0).toList();
  List<Order> _paid(List<Order> orders) => _filtered(orders).where((o) => o.paymentStatus == PaymentStatus.paid).toList();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<OrderService>();
    final all = _filtered(svc.orders);
    final unpaid = _unpaid(svc.orders);
    final partial = _partial(svc.orders);
    final paid = _paid(svc.orders);

    final totalAmt = all.fold<double>(0, (s, o) => s + o.effectiveAmount);
    final paidAmt = all.fold<double>(0, (s, o) => s + o.amountPaid);
    final dueAmt = totalAmt - paidAmt;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 46,
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, phone, order#...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),

            // Month filter with Export button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                      items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _months.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final sel = _selectedMonth == i + 1;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMonth = i + 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: sel ? AppTheme.primaryColor : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.center,
                            child: Text(_months[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: sel ? Colors.white : const Color(0xFF64748B))),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Export Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _exportPayments(context.read<OrderService>().orders),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.download_outlined, size: 18, color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ]),
            ),

            // Summary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                _summaryChip('Total', totalAmt, const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _summaryChip('Paid', paidAmt, const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _summaryChip('Due', dueAmt, const Color(0xFFEF4444)),
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
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    Tab(text: 'Unpaid (${unpaid.length})'),
                    Tab(text: 'Partial (${partial.length})'),
                    Tab(text: 'Paid (${paid.length})'),
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
            : TabBarView(controller: _tabController, children: [
                _buildList(unpaid, 'unpaid'),
                _buildList(partial, 'partial'),
                _buildList(paid, 'paid'),
              ]),
        ),
      ]),
    );
  }

  // ──────────────────────────────────
  // SUMMARY CHIP
  // ──────────────────────────────────

  Widget _summaryChip(String label, double amount, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: c.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('₹${_fmt(amount)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }

  // ──────────────────────────────────
  // LIST VIEW
  // ──────────────────────────────────

  Widget _buildList(List<Order> orders, String type) {
    if (orders.isEmpty) {
      return _empty(
        type == 'unpaid' ? Icons.check_circle_outline : type == 'partial' ? Icons.account_balance_wallet_outlined : Icons.payments_outlined,
        type == 'unpaid' ? 'No unpaid orders' : type == 'partial' ? 'No partial payments' : 'No paid orders',
        type == 'unpaid' ? 'All orders have received payment' : type == 'partial' ? 'Orders with partial payment appear here' : 'Paid orders will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<OrderService>().fetchAllOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) => type == 'paid' ? _paidCard(orders[i]) : _unpaidCard(orders[i]),
      ),
    );
  }

  // ──────────────────────────────────
  // UNPAID / PARTIAL CARD
  // ──────────────────────────────────

  Widget _unpaidCard(Order order) {
    final pending = order.effectiveAmount - order.amountPaid;
    final hasPart = order.amountPaid > 0;
    final dateFmt = DateFormat('dd MMM');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Info row
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasPart ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(
                order.customerName.isNotEmpty ? order.customerName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: hasPart ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
                if (hasPart) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                    child: const Text('PARTIAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${order.orderNumber ?? ''} • ${dateFmt.format(order.createdAt)}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${pending.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: hasPart ? const Color(0xFFD97706) : const Color(0xFFDC2626))),
              Text(
                hasPart ? 'Paid ₹${order.amountPaid.toStringAsFixed(0)} / ₹${order.effectiveAmount.toStringAsFixed(0)}' : 'Total: ₹${order.effectiveAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ]),
          ]),
        ),

        // Progress bar for partial
        if (hasPart) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: order.amountPaid / order.effectiveAmount,
              minHeight: 4,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD97706)),
            ),
          ),
        ),

        // Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(children: [
            if (order.customerPhone != null) ...[
              _iconBtn(Icons.phone_rounded, const Color(0xFF10B981), () => _makeCall(order.customerPhone!)),
              const SizedBox(width: 8),
              _iconBtn(Icons.chat_rounded, const Color(0xFF25D366), () => _openMessageApp(order.customerPhone!, order)),
            ],
            if (hasPart) ...[
              const SizedBox(width: 8),
              _iconBtn(Icons.undo_rounded, const Color(0xFFD97706), () => _confirmResetPayment(order)),
            ],
            const Spacer(),
            TextButton(
              onPressed: () => _markFullyPaid(order),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('Mark Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () => _showPaymentDialog(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ──────────────────────────────────
  // PAID CARD (with long-press CRUD)
  // ──────────────────────────────────

  Widget _paidCard(Order order) {
    final dateFmt = DateFormat('dd MMM');
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
          onLongPress: () => _showPaidActions(order),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_circle, size: 20, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(order.orderNumber ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(4)),
                    child: const Text('PAID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                  ),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${order.amountPaid.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF10B981))),
                Text(dateFmt.format(order.paymentDate ?? order.createdAt), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(width: 4),
              const Icon(Icons.more_vert, size: 16, color: Color(0xFFCBD5E1)),
            ]),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────
  // PAID ACTIONS (Edit / Reset)
  // ──────────────────────────────────

  void _showPaidActions(Order order) {
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
          Text('₹${order.amountPaid.toStringAsFixed(0)} paid', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          _actionTile(Icons.edit_outlined, 'Edit Payment Amount', 'Correct the payment amount', const Color(0xFF3B82F6), () {
            Navigator.pop(sheetCtx);
            _showEditPaymentDialog(order);
          }),
          _actionTile(Icons.undo_outlined, 'Reset to Unpaid', 'Clear all payment records', const Color(0xFFD97706), () {
            Navigator.pop(sheetCtx);
            _confirmResetPayment(order);
          }),
          if (order.customerPhone != null)
            _actionTile(Icons.receipt_long_outlined, 'Send Receipt via WhatsApp', 'Share payment confirmation', const Color(0xFF25D366), () {
              Navigator.pop(sheetCtx);
              _sendReceipt(order);
            }),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  // ──────────────────────────────────
  // EDIT PAYMENT DIALOG
  // ──────────────────────────────────

  void _showEditPaymentDialog(Order order) {
    final ctrl = TextEditingController(text: order.amountPaid.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setDlg) {
        final val = double.tryParse(ctrl.text) ?? 0;
        final isLess = val < order.effectiveAmount;

        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Edit Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(order.customerName, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                _infoRow('Order Total', '₹${order.totalAmount.toStringAsFixed(0)}'),
                if (order.discount > 0) _infoRow('Discount', '-₹${order.discount.toStringAsFixed(0)}', color: const Color(0xFF3B82F6)),
                _infoRow('Effective Total', '₹${order.effectiveAmount.toStringAsFixed(0)}'),
                _infoRow('Currently Paid', '₹${order.amountPaid.toStringAsFixed(0)}', color: const Color(0xFF10B981)),
              ]),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setDlg(() {}),
              decoration: InputDecoration(
                labelText: 'Corrected Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
                filled: true, fillColor: const Color(0xFFFAFAFA),
              ),
            ),
            const SizedBox(height: 12),

            // Status preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isLess ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(isLess ? Icons.info_outline : Icons.check_circle_outline, size: 18, color: isLess ? const Color(0xFFD97706) : const Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(
                  isLess ? 'Will become Partial (₹${(order.effectiveAmount - val).toStringAsFixed(0)} remaining)' : 'Will remain Fully Paid',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isLess ? const Color(0xFFB45309) : const Color(0xFF059669)),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: val <= 0 ? null : () async {
                  Navigator.pop(ctx);
                  try {
                    await context.read<OrderService>().updatePayment(
                      orderId: order.id,
                      amountPaid: val,
                    );
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment updated'), backgroundColor: Color(0xFF10B981)));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Update Payment', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ──────────────────────────────────
  // RESET PAYMENT CONFIRMATION
  // ──────────────────────────────────

  void _confirmResetPayment(Order order) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Payment?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'This will reset ${order.customerName}\'s payment to ₹0 (Unpaid).\n\nPreviously paid: ₹${order.amountPaid.toStringAsFixed(0)}',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final ok = await context.read<OrderService>().resetPayment(order.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Payment reset to Unpaid' : 'Failed to reset'),
                backgroundColor: ok ? const Color(0xFFD97706) : Colors.red,
              ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────
  // PAYMENT DIALOG (Record Payment)
  // ──────────────────────────────────

  void _showPaymentDialog(Order order) {
    final pendingAmt = order.effectiveAmount - order.amountPaid;
    final payCtrl = TextEditingController(text: pendingAmt.toStringAsFixed(0));
    final discCtrl = TextEditingController(text: '0');
    double payAmt = pendingAmt;
    double discount = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setDlg) {
        final effectivePending = (pendingAmt - discount).clamp(0, pendingAmt);
        final isFull = payAmt >= effectivePending;
        final finalPay = payAmt > effectivePending ? effectivePending : payAmt;

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Payment - ${order.customerName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                _infoRow('Order Total', '₹${order.totalAmount.toStringAsFixed(0)}'),
                if (order.amountPaid > 0) _infoRow('Already Paid', '₹${order.amountPaid.toStringAsFixed(0)}', color: const Color(0xFF10B981)),
                _infoRow('Pending', '₹${pendingAmt.toStringAsFixed(0)}', color: const Color(0xFFDC2626)),
                if (discount > 0) _infoRow('Discount', '-₹${discount.toStringAsFixed(0)}', color: const Color(0xFF3B82F6)),
              ]),
            ),
            const SizedBox(height: 16),

            // Quick options
            const Text('Quick Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Row(children: [
              _qChip('50%', (pendingAmt * 0.5).roundToDouble(), payAmt, (v) => setDlg(() { payAmt = v; payCtrl.text = v.toStringAsFixed(0); })),
              const SizedBox(width: 8),
              _qChip('75%', (pendingAmt * 0.75).roundToDouble(), payAmt, (v) => setDlg(() { payAmt = v; payCtrl.text = v.toStringAsFixed(0); })),
              const SizedBox(width: 8),
              _qChip('Full', pendingAmt, payAmt, (v) => setDlg(() { payAmt = v; payCtrl.text = v.toStringAsFixed(0); })),
            ]),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: payCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Payment Amount', prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
              ),
              onChanged: (v) {
                setDlg(() {
                  payAmt = double.tryParse(v) ?? 0;
                  if (payAmt > pendingAmt) {
                    payAmt = pendingAmt;
                    payCtrl.text = pendingAmt.toStringAsFixed(0);
                    payCtrl.selection = TextSelection.fromPosition(TextPosition(offset: payCtrl.text.length));
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // Discount (only for full)
            if (isFull) TextField(
              controller: discCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Discount (optional)', prefixText: '₹ ',
                helperText: 'Apply discount on final settlement',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
              ),
              onChanged: (v) => setDlg(() { discount = double.tryParse(v) ?? 0; if (discount > pendingAmt) discount = pendingAmt; }),
            ),
            const SizedBox(height: 16),

            // Status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isFull ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(isFull ? Icons.check_circle : Icons.schedule, size: 20, color: isFull ? const Color(0xFF10B981) : const Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isFull ? 'Full Payment' : 'Partial Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isFull ? const Color(0xFF059669) : const Color(0xFFB45309))),
                  Text(
                    isFull ? 'Order will be marked as Paid' : 'Remaining ₹${(pendingAmt - payAmt).clamp(0, pendingAmt).toStringAsFixed(0)} will be due',
                    style: TextStyle(fontSize: 11, color: isFull ? const Color(0xFF10B981) : const Color(0xFFD97706)),
                  ),
                ])),
              ]),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: payAmt <= 0 ? null : () async {
                  Navigator.pop(ctx);
                  await _processPayment(order, payAmt, discount, isFull);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Pay ₹${finalPay.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ])),
        );
      }),
    );
  }

  Widget _qChip(String label, double amount, double current, Function(double) onTap) {
    final sel = (current - amount).abs() < 1;
    return GestureDetector(
      onTap: () => onTap(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: sel ? AppTheme.primaryColor : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  // ──────────────────────────────────
  // MARK FULLY PAID
  // ──────────────────────────────────

  void _markFullyPaid(Order order) async {
    final pending = order.effectiveAmount - order.amountPaid;
    try {
      await context.read<OrderService>().addPayment(orderId: order.id, paymentAmount: pending, currentAmountPaid: order.amountPaid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${order.customerName} marked as fully paid'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _processPayment(Order order, double payAmt, double discount, bool isFull) async {
    try {
      if (isFull && discount > 0) {
        // Apply discount and mark as fully paid
        final newAmountPaid = order.amountPaid + payAmt - discount;
        await context.read<OrderService>().updatePayment(
          orderId: order.id,
          amountPaid: newAmountPaid,
          discount: discount,
        );
      } else {
        await context.read<OrderService>().addPayment(orderId: order.id, paymentAmount: payAmt, currentAmountPaid: order.amountPaid);
      }
      if (mounted) {
        String msg;
        if (isFull && discount > 0) {
          msg = 'Payment recorded with ₹${discount.toStringAsFixed(0)} discount';
        } else if (isFull) {
          msg = '${order.customerName} - Fully paid!';
        } else {
          msg = '₹${payAmt.toStringAsFixed(0)} partial payment recorded';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ──────────────────────────────────
  // SEND RECEIPT
  // ──────────────────────────────────

  void _sendReceipt(Order order) async {
    final discountLine = order.discount > 0 ? '\nDiscount: ₹${order.discount.toStringAsFixed(0)}' : '';
    final msg = 'Hi ${order.customerName},\n\nPayment receipt from Ambigai Bricks:\nOrder: ${order.orderNumber}\nTotal: ₹${order.totalAmount.toStringAsFixed(0)}$discountLine\nPaid: ₹${order.amountPaid.toStringAsFixed(0)}\nStatus: ✅ Fully Paid\n\nThank you for your business!';
    await _openWhatsApp(order.customerPhone!, msg);
  }

  // ──────────────────────────────────
  // HELPERS
  // ──────────────────────────────────

  Widget _iconBtn(IconData icon, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: c),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String sub, Color c, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: c, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: 14, color: color ?? const Color(0xFF1E293B), fontWeight: FontWeight.w500)),
      ]),
    );
  }

  void _makeCall(String phone) async {
    final clean = _normalizePhoneForDevice(phone);
    if (clean.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid phone number'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final dialUris = <Uri>[
      Uri.parse('tel:$clean'),
      Uri.parse('tel://$clean'),
      Uri.parse('telprompt:$clean'),
    ];

    for (final uri in dialUris) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {
        // Try the next URI scheme.
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer app'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openMessageApp(String phone, Order order) async {
    final waNumber = _normalizePhoneForWhatsApp(phone);
    if (waNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid phone number'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final pending = order.effectiveAmount - order.amountPaid;
    final msg = 'Hi ${order.customerName}, payment reminder for ₹${pending.toStringAsFixed(0)} from Ambigai Bricks.';
    await _launchWhatsApp(waNumber, msg);
  }

  Future<void> _openWhatsApp(String phone, String message) async {
    final waNumber = _normalizePhoneForWhatsApp(phone);
    if (waNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid phone number'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    await _launchWhatsApp(waNumber, message);
  }

  String _normalizePhoneForWhatsApp(String phone) {
    // WhatsApp requires a continuous digit-only international number.
    var digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';

    // Handle local India formats like 0XXXXXXXXXX.
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Default 10-digit local numbers to India country code.
    if (digits.length == 10) {
      digits = '91$digits';
    }

    return digits;
  }

  Future<void> _launchWhatsApp(String waNumber, String message) async {
    final encoded = Uri.encodeComponent(message);
    final uris = <Uri>[
      Uri.parse('https://wa.me/$waNumber?text=$encoded'),
      Uri.parse('https://api.whatsapp.com/send?phone=$waNumber&text=$encoded'),
    ];

    for (final uri in uris) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {
        // Try the next WhatsApp URL format.
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp'), backgroundColor: Colors.red),
      );
    }
  }

  String _normalizePhoneForDevice(String phone) {
    final trimmed = phone.trim();
    final hasPlusPrefix = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    return hasPlusPrefix ? '+$digits' : digits;
  }

  String _fmt(double a) {
    if (a >= 100000) return '${(a / 100000).toStringAsFixed(1)}L';
    if (a >= 1000) return '${(a / 1000).toStringAsFixed(1)}K';
    return a.toStringAsFixed(0);
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

  Future<void> _exportPayments(List<Order> allOrders) async {
    final filtered = _filtered(allOrders);
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payments to export'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    try {
      final fileName = 'Payments_${_months[_selectedMonth - 1]}_$_selectedYear.xlsx';
      await ExcelExportService.exportPaymentsToExcel(
        filtered,
        fileName: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payments exported successfully'), backgroundColor: Color(0xFF10B981)),
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
}
