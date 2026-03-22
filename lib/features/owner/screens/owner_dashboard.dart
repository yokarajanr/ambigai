import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/order_service.dart';
import '../../shared/widgets/kpi_card.dart';

/// Owner Dashboard — Full business overview with real-time data.
class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
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

    final pendingDeliveries = orders.where((o) =>
      o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled
    ).length;

    final unpaidOrders = orders.where((o) =>
      o.paymentStatus != PaymentStatus.paid
    ).length;

    final totalRevenue = orders.fold<double>(0, (sum, o) => sum + o.effectiveAmount);

    final pendingAmount = orders
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

            // --- Business Overview ---
            _buildSectionTitle('Business Overview'),
            const SizedBox(height: 12),
            if (orderService.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              KpiCard(
                icon: Icons.receipt_long,
                title: 'Total Orders',
                value: orders.length.toString(),
                accentColor: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 10),
              KpiCard(
                icon: Icons.today,
                title: 'Orders Today',
                value: ordersToday.toString(),
                accentColor: const Color(0xFF06B6D4),
              ),
              const SizedBox(height: 10),
              KpiCard(
                icon: Icons.currency_rupee,
                title: 'Total Revenue',
                value: _formatCurrency(totalRevenue),
                accentColor: const Color(0xFF10B981),
              ),
              const SizedBox(height: 10),
              KpiCard(
                icon: Icons.local_shipping,
                title: 'Pending Deliveries',
                value: '$pendingDeliveries',
                accentColor: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => context.go('/owner/payments'),
                child: KpiCard(
                  icon: Icons.payment,
                  title: 'Unpaid Orders',
                  value: '$unpaidOrders (${_formatCurrency(pendingAmount)})',
                  accentColor: const Color(0xFFF59E0B),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // --- Weekly Orders Trend ---
            if (!orderService.isLoading && orders.isNotEmpty) ...[
              _buildSectionTitle('Last 7 Days'),
              const SizedBox(height: 12),
              _buildWeeklyChart(orders),
              const SizedBox(height: 24),

              // --- Monthly Revenue Chart ---
              _buildSectionTitle('Monthly Revenue'),
              const SizedBox(height: 12),
              _buildMonthlyRevenueChart(orders),
              const SizedBox(height: 24),
            ],

            // --- Recent Orders ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Recent Orders'),
                TextButton(
                  onPressed: () => context.go('/owner/orders'),
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
          () => context.push('/owner/new-order'),
        ),
        const SizedBox(width: 10),
        _quickAction(
          Icons.assessment_outlined,
          'Reports',
          const Color(0xFF10B981),
          () => context.push('/owner/reports'),
        ),
        const SizedBox(width: 10),
        _quickAction(
          Icons.people_outlined,
          'Team',
          const Color(0xFFF59E0B),
          () => context.push('/owner/team'),
        ),
        const SizedBox(width: 10),
        _quickAction(
          Icons.price_change_outlined,
          'Products',
          const Color(0xFF8B5CF6),
          () => context.push('/owner/products'),
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

  // ======= CHARTS =======

  Widget _buildWeeklyChart(List<Order> orders) {
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final spots = <FlSpot>[];
    double maxY = 5;
    for (int i = 0; i < 7; i++) {
      final count = orders.where((o) =>
        o.createdAt.year == days[i].year &&
        o.createdAt.month == days[i].month &&
        o.createdAt.day == days[i].day
      ).length.toDouble();
      spots.add(FlSpot(i.toDouble(), count));
      if (count > maxY) maxY = count;
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY + 2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).clamp(1, 100),
            getDrawingHorizontalLine: (_) => FlLine(
              color: const Color(0xFFF0F0F0),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (maxY / 4).clamp(1, 100),
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                  return Text(
                    dayLabels[days[idx].weekday - 1],
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF3B82F6),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF3B82F6),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyRevenueChart(List<Order> orders) {
    final today = DateTime.now();
    final months = List.generate(6, (i) {
      final m = today.month - 5 + i;
      final y = today.year + (m <= 0 ? -1 : 0);
      final adjustedM = m <= 0 ? m + 12 : m;
      return DateTime(y, adjustedM);
    });

    final monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    double maxY = 10000;
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < 6; i++) {
      final revenue = orders
          .where((o) => o.createdAt.year == months[i].year && o.createdAt.month == months[i].month)
          .fold<double>(0, (sum, o) => sum + o.effectiveAmount);
      if (revenue > maxY) maxY = revenue;

      barGroups.add(
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: revenue,
            color: const Color(0xFF10B981),
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ]),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 4).clamp(1, 10000000),
            getDrawingHorizontalLine: (_) => FlLine(
              color: const Color(0xFFF0F0F0),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: (maxY / 4).clamp(1, 10000000),
                getTitlesWidget: (v, _) => Text(
                  _formatCompact(v),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= 6) return const SizedBox.shrink();
                  return Text(
                    monthLabels[months[idx].month - 1],
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  static String _formatCompact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
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
      case OrderStatus.cancelled: return const Color(0xFFEF4444);
    }
  }

  Color _getPaymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid: return const Color(0xFFE53935);
      case PaymentStatus.partial: return const Color(0xFFF59E0B);
      case PaymentStatus.paid: return const Color(0xFF10B981);
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }
}
