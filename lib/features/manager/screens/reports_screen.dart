import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/services/order_service.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/theme/app_theme.dart';

/// Reports Screen - Month-wise order and payment tracking.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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

  List<Order> _getFilteredOrders(List<Order> orders) {
    return orders.where((o) =>
      o.createdAt.year == _selectedYear &&
      o.createdAt.month == _selectedMonth
    ).toList();
  }

  List<Order> _getPendingPayments(List<Order> orders) {
    return orders.where((o) =>
      o.createdAt.year == _selectedYear &&
      o.createdAt.month == _selectedMonth &&
      o.paymentStatus != PaymentStatus.paid
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<OrderService>();
    final allOrders = orderService.orders;
    final filteredOrders = _getFilteredOrders(allOrders);
    final pendingPayments = _getPendingPayments(allOrders);

    // Stats for selected month
    final totalOrders = filteredOrders.length;
    final totalAmount = filteredOrders.fold<double>(0, (sum, o) => sum + o.effectiveAmount);
    final collectedAmount = filteredOrders.fold<double>(0, (sum, o) => sum + o.amountPaid);
    final pendingAmount = totalAmount - collectedAmount;
    final deliveredOrders = filteredOrders.where((o) => o.status == OrderStatus.delivered).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onSelected: (value) {
              if (value == 'csv') {
                _exportCsv(filteredOrders);
              } else if (value == 'excel') {
                _exportExcel(filteredOrders);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'csv',
                child: Row(children: [
                  Icon(Icons.description_outlined, size: 18, color: Colors.grey),
                  SizedBox(width: 10),
                  Text('Export as CSV'),
                ]),
              ),
              const PopupMenuItem<String>(
                value: 'excel',
                child: Row(children: [
                  Icon(Icons.table_chart_outlined, size: 18, color: Colors.green),
                  SizedBox(width: 10),
                  Text('Export as Excel'),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Pending Payments'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month/Year Selector
          _buildMonthSelector(),

          // Summary Cards
          _buildSummaryCards(totalOrders, totalAmount, collectedAmount, pendingAmount, deliveredOrders),

          // Tab Content
          Expanded(
            child: orderService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrdersList(filteredOrders),
                      _buildPendingPaymentsList(pendingPayments),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
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
          const SizedBox(width: 12),

          // Today Button
          TextButton(
            onPressed: () {
              setState(() {
                _selectedYear = DateTime.now().year;
                _selectedMonth = DateTime.now().month;
              });
            },
            child: const Text('Today'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int totalOrders, double totalAmount, double collected, double pending, int delivered) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              _summaryCard('Orders', totalOrders.toString(), Icons.receipt_long, const Color(0xFF3B82F6)),
              const SizedBox(width: 10),
              _summaryCard('Delivered', delivered.toString(), Icons.local_shipping, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryCard('Total', '₹${_formatAmount(totalAmount)}', Icons.account_balance_wallet, const Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
              _summaryCard('Collected', '₹${_formatAmount(collected)}', Icons.payments, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.money_off, color: Color(0xFFE53935), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Amount',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      Text(
                        '₹${_formatAmount(pending)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState(
        'No orders in ${_monthNames[_selectedMonth - 1]} $_selectedYear',
        'Orders will appear here when created.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildPendingPaymentsList(List<Order> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState(
        'All payments collected!',
        'No pending payments for ${_monthNames[_selectedMonth - 1]} $_selectedYear.',
      );
    }

    // Sort by pending amount descending
    orders.sort((a, b) => 
      (b.effectiveAmount - b.amountPaid).compareTo(a.effectiveAmount - a.amountPaid)
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildPendingCard(orders[index]),
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                Text(
                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${order.effectiveAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                'Paid: ₹${order.amountPaid.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: order.paymentStatus == PaymentStatus.paid
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Order order) {
    final pendingAmount = order.effectiveAmount - order.amountPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline, color: Color(0xFFE53935)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (order.customerPhone != null)
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse('tel:${order.customerPhone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 12, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          order.customerPhone!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  order.orderNumber ?? 'Order',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${pendingAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE53935),
                ),
              ),
              Text(
                'of ₹${order.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: const Color(0xFF10B981).withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Future<void> _exportCsv(List<Order> orders) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    final dateFormat = DateFormat('dd-MM-yyyy');

    // Build CSV data
    final headers = [
      'Order No', 'Customer', 'Phone', 'Order Date', 'Status',
      'Total Amount', 'Discount', 'Net Amount', 'Paid', 'Balance',
      'Payment Status', 'DC Number', 'Delivery Date', 'Items',
    ];

    final rows = orders.map((o) => [
      o.orderNumber ?? '',
      o.customerName,
      o.customerPhone ?? '',
      dateFormat.format(o.createdAt),
      o.status.displayName,
      o.totalAmount.toStringAsFixed(2),
      o.discount.toStringAsFixed(2),
      o.effectiveAmount.toStringAsFixed(2),
      o.amountPaid.toStringAsFixed(2),
      o.balanceAmount.toStringAsFixed(2),
      o.paymentStatus.displayName,
      o.dcNumber ?? '',
      o.deliveryDate != null ? dateFormat.format(o.deliveryDate!) : '',
      o.items.map((i) => '${i['product_name'] ?? 'Brick'} x${i['quantity']}').join('; '),
    ]).toList();

    final csvData = const CsvEncoder().convert([headers, ...rows]);

    try {
      final fileName = 'Orders_${_monthNames[_selectedMonth - 1]}_$_selectedYear.csv';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(csvData),
              mimeType: 'text/csv',
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          text: 'Orders Report - ${_monthNames[_selectedMonth - 1]} $_selectedYear',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  Future<void> _exportExcel(List<Order> orders) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }

    try {
      final fileName = 'Orders_${_monthNames[_selectedMonth - 1]}_$_selectedYear.xlsx';
      await ExcelExportService.exportOrdersToExcel(
        orders,
        fileName: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orders exported to Excel successfully'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
