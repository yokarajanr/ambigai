import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/order_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/kpi_card.dart';

/// Office Manager Dashboard — Orders & Customers focus with real-time data.
class OfficeDashboard extends StatefulWidget {
  const OfficeDashboard({super.key});

  @override
  State<OfficeDashboard> createState() => _OfficeDashboardState();
}

class _OfficeDashboardState extends State<OfficeDashboard> {
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

    // Calculate real stats
    final today = DateTime.now();
    final ordersToday = orders.where((o) => 
      o.createdAt.year == today.year &&
      o.createdAt.month == today.month &&
      o.createdAt.day == today.day
    ).length;

    final pendingOrders = orders.where((o) => 
      o.status == OrderStatus.pending || o.status == OrderStatus.confirmed
    ).length;

    final unpaidOrders = orders.where((o) => 
      o.paymentStatus != PaymentStatus.paid
    ).length;

    final unpaidAmount = orders
      .where((o) => o.paymentStatus != PaymentStatus.paid)
      .fold<double>(0, (sum, o) => sum + (o.effectiveAmount - o.amountPaid));

    // Recent orders (last 5)
    final recentOrders = orders.take(5).toList();

    return RefreshIndicator(
      onRefresh: () => orderService.fetchAllOrders(),
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Quick Actions ---
            _buildSectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            _buildQuickActions(context),
            const SizedBox(height: 24),

            // --- Overview ---
            _buildSectionTitle('Today\'s Overview'),
            const SizedBox(height: 12),
            KpiCard(
              icon: Icons.receipt_long,
              title: 'Orders Today',
              value: ordersToday.toString(),
              accentColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 10),
            KpiCard(
              icon: Icons.pending_actions,
              title: 'Pending Delivery',
              value: pendingOrders.toString(),
              accentColor: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => context.push('/office-manager/reports'),
              child: KpiCard(
                icon: Icons.money_off,
                title: 'Unpaid Orders',
                value: '$unpaidOrders (₹${_formatAmount(unpaidAmount)})',
                accentColor: const Color(0xFFE53935),
              ),
            ),
            const SizedBox(height: 10),
            KpiCard(
              icon: Icons.inventory,
              title: 'Total Orders',
              value: orders.length.toString(),
              accentColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 24),

            // --- Recent Orders ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Recent Orders'),
                TextButton(
                  onPressed: () => context.go('/office-manager/orders'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (orderService.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (recentOrders.isEmpty)
              _buildEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                subtitle: 'Tap "New Order" to create your first order.',
              )
            else
              ...recentOrders.map((order) => _buildOrderCard(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _quickAction(
          Icons.add_circle_outline, 
          'New Order', 
          const Color(0xFF3B82F6),
          () => context.push('/office-manager/new-order'),
        ),
        const SizedBox(width: 10),
        _quickAction(
          Icons.list_alt_outlined, 
          'All Orders', 
          const Color(0xFF10B981),
          () => context.go('/office-manager/orders'),
        ),
        const SizedBox(width: 10),
        _quickAction(
          Icons.assessment_outlined, 
          'Reports', 
          const Color(0xFFF59E0B),
          () => context.push('/office-manager/reports'),
        ),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber ?? 'Order',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.status.name,
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  order.customerName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: paymentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.paymentStatus.name,
                  style: TextStyle(fontSize: 10, color: paymentColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.35)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return const Color(0xFFF59E0B);
      case OrderStatus.confirmed: return const Color(0xFF3B82F6);
      case OrderStatus.processing: return const Color(0xFF8B5CF6);
      case OrderStatus.ready: return const Color(0xFF06B6D4);
      case OrderStatus.delivered: return const Color(0xFF10B981);
      case OrderStatus.cancelled: return const Color(0xFFE53935);
    }
  }

  Color _getPaymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid: return const Color(0xFFE53935);
      case PaymentStatus.partial: return const Color(0xFFF59E0B);
      case PaymentStatus.paid: return const Color(0xFF10B981);
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
