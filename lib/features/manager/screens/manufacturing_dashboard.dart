import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/order_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/kpi_card.dart';

/// Manufacturing Manager Dashboard — Production & Stock focus, wired to real data.
class ManufacturingDashboard extends StatefulWidget {
  const ManufacturingDashboard({super.key});

  @override
  State<ManufacturingDashboard> createState() => _ManufacturingDashboardState();
}

class _ManufacturingDashboardState extends State<ManufacturingDashboard> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchAllOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<OrderService>();
    final orders = orderService.orders;

    // Real KPI calculations
    final today = DateTime.now();
    final todaysOrders = orders.where((o) =>
      o.createdAt.year == today.year &&
      o.createdAt.month == today.month &&
      o.createdAt.day == today.day
    ).toList();

    final pendingDeliveries = orders.where((o) =>
      o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled
    ).length;

    final totalBricksOnOrder = orders
      .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
      .fold<int>(0, (sum, o) => sum + o.totalQuantity);

    // Product-wise breakdown from active orders
    final productQuantities = <String, int>{};
    for (final order in orders.where((o) => o.status != OrderStatus.cancelled)) {
      for (final item in order.items) {
        final name = (item['product_name'] ?? item['brick_type'] ?? 'Unknown') as String;
        final qty = item['quantity'] as int? ?? 0;
        productQuantities[name] = (productQuantities[name] ?? 0) + qty;
      }
    }

    // Filter by search
    final filteredOrders = _searchQuery.isEmpty ? todaysOrders : todaysOrders.where((o) =>
      o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (o.orderNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();

    return RefreshIndicator(
      onRefresh: () => orderService.fetchAllOrders(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Search ---
            _buildHeader(),
            const SizedBox(height: 20),

            // --- KPIs ---
            _buildSectionTitle('Overview'),
            const SizedBox(height: 12),
            KpiCard(
              icon: Icons.receipt_long,
              title: 'Today\'s Orders',
              value: '${todaysOrders.length}',
              accentColor: const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 10),
            KpiCard(
              icon: Icons.local_shipping,
              title: 'Pending Deliveries',
              value: '$pendingDeliveries',
              accentColor: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 10),
            KpiCard(
              icon: Icons.inventory_2,
              title: 'Bricks on Order',
              value: _formatNumber(totalBricksOnOrder),
              accentColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 24),

            // --- Product-wise demand ---
            if (productQuantities.isNotEmpty) ...[
              _buildSectionTitle('Product-Wise Demand (All Time)'),
              const SizedBox(height: 12),
              ...productQuantities.entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.view_module, color: Color(0xFF3B82F6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Text(_formatNumber(e.value), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
                    const Text(' pcs', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              )),
              const SizedBox(height: 24),
            ],

            // --- Today's Orders ---
            _buildSectionTitle('Today\'s Orders (${filteredOrders.length})'),
            const SizedBox(height: 12),
            if (filteredOrders.isEmpty)
              _buildEmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No orders today',
                subtitle: 'New orders will appear here as they are created.',
              )
            else
              ...filteredOrders.map((order) => _buildOrderCard(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search orders...',
        hintStyle: TextStyle(color: AppTheme.primaryColor.withValues(alpha: 0.6), fontSize: 15),
        prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor, size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.15))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.15))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppTheme.primaryColor, width: 2)),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
      onChanged: (v) => setState(() => _searchQuery = v),
    );
  }

  Widget _buildOrderCard(Order order) {
    final items = order.items.map((i) {
      final name = (i['product_name'] ?? i['brick_type'] ?? 'Bricks') as String;
      return '${i['quantity']} $name';
    }).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Color(order.status.colorValue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, color: Color(order.status.colorValue), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(items, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(order.status.colorValue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(order.status.displayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(order.status.colorValue))),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary));
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(children: [
        Icon(icon, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.35)),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.65))),
      ]),
    );
  }
}
