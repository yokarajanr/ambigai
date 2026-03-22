import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Order status enum.
enum OrderStatus {
  pending,
  confirmed,
  processing,
  ready,
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get dbValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  int get colorValue {
    switch (this) {
      case OrderStatus.pending:
        return 0xFFF59E0B; // Amber
      case OrderStatus.confirmed:
        return 0xFF3B82F6; // Blue
      case OrderStatus.processing:
        return 0xFF8B5CF6; // Purple
      case OrderStatus.ready:
        return 0xFF10B981; // Green
      case OrderStatus.delivered:
        return 0xFF10B981; // Green
      case OrderStatus.cancelled:
        return 0xFFEF4444; // Red
    }
  }

  static OrderStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'ready':
        return OrderStatus.ready;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Payment status enum.
enum PaymentStatus {
  unpaid,
  partial,
  paid,
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.paid:
        return 'Paid';
    }
  }

  String get dbValue {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.partial:
        return 'partial';
      case PaymentStatus.paid:
        return 'paid';
    }
  }

  int get colorValue {
    switch (this) {
      case PaymentStatus.unpaid:
        return 0xFFEF4444; // Red
      case PaymentStatus.partial:
        return 0xFFF59E0B; // Amber
      case PaymentStatus.paid:
        return 0xFF10B981; // Green
    }
  }

  static PaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'unpaid':
        return PaymentStatus.unpaid;
      case 'partial':
        return PaymentStatus.partial;
      case 'paid':
        return PaymentStatus.paid;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

/// Order model - matches Supabase orders table.
class Order {
  final String id;
  final String? orderNumber;        // Auto-generated: ORD-2026-0001
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final double discount;             // Discount applied on payment
  final OrderStatus status;
  final String? dcNumber;           // Delivery Challan number
  final DateTime? deliveryDate;
  final PaymentStatus paymentStatus;
  final double amountPaid;
  final DateTime? paymentDate;
  final String? notes;
  final String? createdBy;          // Which manager created this
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    this.orderNumber,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.items,
    required this.totalAmount,
    this.discount = 0,
    required this.status,
    this.dcNumber,
    this.deliveryDate,
    required this.paymentStatus,
    this.amountPaid = 0,
    this.paymentDate,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String?,
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerPhone: json['customer_phone'] as String?,
      customerAddress: json['customer_address'] as String?,
      items: (json['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      status: OrderStatusExtension.fromString(json['status'] as String? ?? 'pending'),
      dcNumber: json['dc_number'] as String?,
      deliveryDate: json['delivery_date'] != null 
          ? DateTime.parse(json['delivery_date'] as String) 
          : null,
      paymentStatus: PaymentStatusExtension.fromString(json['payment_status'] as String? ?? 'unpaid'),
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      paymentDate: json['payment_date'] != null 
          ? DateTime.parse(json['payment_date'] as String) 
          : null,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_address': customerAddress,
    'items': items,
    'total_amount': totalAmount,
    'discount': discount,
    'status': status.dbValue,
    'dc_number': dcNumber,
    'delivery_date': deliveryDate?.toIso8601String().split('T').first,
    'payment_status': paymentStatus.dbValue,
    'amount_paid': amountPaid,
    'payment_date': paymentDate?.toIso8601String().split('T').first,
    'notes': notes,
  };

  /// Get total quantity of all items.
  int get totalQuantity => items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));

  /// Get the effective amount after discount.
  double get effectiveAmount => totalAmount - discount;

  /// Get balance amount (total - discount - paid).
  double get balanceAmount => effectiveAmount - amountPaid;

  /// Check if fully paid.
  bool get isFullyPaid => amountPaid >= effectiveAmount;

  /// Copy with new values.
  Order copyWith({
    String? id,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<Map<String, dynamic>>? items,
    double? totalAmount,
    double? discount,
    OrderStatus? status,
    String? dcNumber,
    DateTime? deliveryDate,
    PaymentStatus? paymentStatus,
    double? amountPaid,
    DateTime? paymentDate,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      status: status ?? this.status,
      dcNumber: dcNumber ?? this.dcNumber,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentDate: paymentDate ?? this.paymentDate,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Order service for managing orders with Supabase.
class OrderService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  static const int _pageSize = 50;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  // ============================================================
  // FETCH ORDERS
  // ============================================================

  /// Fetch all orders (for staff: owner/managers). Paginated.
  Future<void> fetchAllOrders({bool loadMore = false}) async {
    if (_isLoading) return;
    if (loadMore && !_hasMore) return;

    _isLoading = true;
    _error = null;
    if (!loadMore) {
      _orders = [];
      _hasMore = true;
    }
    notifyListeners();

    try {
      final offset = loadMore ? _orders.length : 0;
      final response = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final fetched = (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();

      if (loadMore) {
        _orders.addAll(fetched);
      } else {
        _orders = fetched;
      }
      _hasMore = fetched.length >= _pageSize;
    } catch (e) {
      _error = 'Failed to load orders. Please try again.';
      debugPrint('Error fetching orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch orders by status.
  Future<void> fetchOrdersByStatus(OrderStatus status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('status', status.dbValue)
          .order('created_at', ascending: false);

      _orders = (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load orders. Please try again.';
      debugPrint('Error fetching orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch orders with pending payments.
  Future<List<Order>> fetchPendingPayments() async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .neq('payment_status', 'paid')
          .eq('status', 'delivered')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending payments: $e');
      return [];
    }
  }

  /// Fetch orders by month (for reporting).
  Future<List<Order>> fetchOrdersByMonth(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59); // Last second of last day

      final response = await _supabase
          .from('orders')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching orders by month: $e');
      return [];
    }
  }

  // ============================================================
  // CREATE ORDER
  // ============================================================

  /// Create a new order (manager enters phone order).
  Future<Order?> createOrder({
    required String customerName,
    String? customerPhone,
    String? customerAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? notes,
    DateTime? orderDate,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _error = 'Please log in to create an order.';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final orderData = {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'items': items,
        'total_amount': totalAmount,
        'status': 'pending',
        'payment_status': 'unpaid',
        'amount_paid': 0,
        'discount': 0,
        'notes': notes,
        'created_by': userId,
        if (orderDate != null) 'created_at': orderDate.toIso8601String(),
      };

      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final newOrder = Order.fromJson(response);
      _orders.insert(0, newOrder);
      notifyListeners();
      return newOrder;
    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('PostgrestException creating order: ${e.message} (code: ${e.code})');
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to create order: $e';
      debugPrint('Error creating order: $e');
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // UPDATE ORDER STATUS
  // ============================================================

  /// Update order status.
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus.dbValue})
          .eq('id', orderId);

      _updateLocalOrder(orderId, (order) => order.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = 'Failed to update order status.';
      debugPrint('Error updating order status: $e');
      notifyListeners();
      return false;
    }
  }

  /// Mark order as delivered with DC number.
  Future<bool> markAsDelivered({
    required String orderId,
    required String dcNumber,
    DateTime? deliveryDate,
  }) async {
    try {
      final updateData = {
        'status': 'delivered',
        'dc_number': dcNumber,
        'delivery_date': (deliveryDate ?? DateTime.now()).toIso8601String().split('T').first,
      };

      await _supabase
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      _updateLocalOrder(orderId, (order) => order.copyWith(
        status: OrderStatus.delivered,
        dcNumber: dcNumber,
        deliveryDate: deliveryDate ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = 'Failed to mark as delivered.';
      debugPrint('Error marking as delivered: $e');
      notifyListeners();
      return false;
    }
  }

  /// Cancel an order.
  Future<bool> cancelOrder(String orderId) async {
    return updateOrderStatus(orderId, OrderStatus.cancelled);
  }

  // ============================================================
  // UPDATE ORDER DETAILS
  // ============================================================

  /// Update order details (edit customer info, items, amount).
  Future<bool> updateOrder({
    required String orderId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    List<Map<String, dynamic>>? items,
    double? totalAmount,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (customerName != null) updateData['customer_name'] = customerName;
      if (customerPhone != null) updateData['customer_phone'] = customerPhone;
      if (customerAddress != null) updateData['customer_address'] = customerAddress;
      if (items != null) updateData['items'] = items;
      if (totalAmount != null) updateData['total_amount'] = totalAmount;
      if (notes != null) updateData['notes'] = notes;

      if (updateData.isEmpty) return true;

      await _supabase
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      _updateLocalOrder(orderId, (order) => order.copyWith(
        customerName: customerName ?? order.customerName,
        customerPhone: customerPhone ?? order.customerPhone,
        customerAddress: customerAddress ?? order.customerAddress,
        items: items ?? order.items,
        totalAmount: totalAmount ?? order.totalAmount,
        notes: notes ?? order.notes,
        updatedAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = 'Failed to update order.';
      debugPrint('Error updating order: $e');
      notifyListeners();
      return false;
    }
  }

  /// Undo delivery - revert status back to confirmed.
  Future<bool> undoDelivery(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'status': 'confirmed',
            'dc_number': null,
            'delivery_date': null,
          })
          .eq('id', orderId);

      _updateLocalOrder(orderId, (order) => Order(
        id: order.id,
        orderNumber: order.orderNumber,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        customerAddress: order.customerAddress,
        items: order.items,
        totalAmount: order.totalAmount,
        discount: order.discount,
        status: OrderStatus.confirmed,
        paymentStatus: order.paymentStatus,
        amountPaid: order.amountPaid,
        paymentDate: order.paymentDate,
        notes: order.notes,
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = 'Failed to undo delivery.';
      debugPrint('Error undoing delivery: $e');
      notifyListeners();
      return false;
    }
  }

  /// Reset payment to zero (also clears discount).
  Future<bool> resetPayment(String orderId) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'amount_paid': 0,
            'discount': 0,
            'payment_status': 'unpaid',
          })
          .eq('id', orderId);

      _updateLocalOrder(orderId, (order) => order.copyWith(
        amountPaid: 0,
        discount: 0,
        paymentStatus: PaymentStatus.unpaid,
        updatedAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = 'Failed to reset payment.';
      debugPrint('Error resetting payment: $e');
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  // UPDATE PAYMENT
  // ============================================================

  /// Update payment status.
  Future<bool> updatePayment({
    required String orderId,
    required double amountPaid,
    double? discount,
    DateTime? paymentDate,
  }) async {
    try {
      // Find order to get effectiveAmount for status calculation
      final idx = _orders.indexWhere((o) => o.id == orderId);
      final existingOrder = idx >= 0 ? _orders[idx] : null;
      final effectiveDiscount = discount ?? existingOrder?.discount ?? 0;
      final effectiveAmt = (existingOrder?.totalAmount ?? 0) - effectiveDiscount;

      PaymentStatus paymentStatus;
      if (amountPaid >= effectiveAmt && effectiveAmt > 0) {
        paymentStatus = PaymentStatus.paid;
      } else if (amountPaid > 0) {
        paymentStatus = PaymentStatus.partial;
      } else {
        paymentStatus = PaymentStatus.unpaid;
      }

      final updateData = <String, dynamic>{
        'amount_paid': amountPaid,
        'payment_status': paymentStatus.dbValue,
        'payment_date': (paymentDate ?? DateTime.now()).toIso8601String().split('T').first,
      };
      if (discount != null) {
        updateData['discount'] = discount;
      }

      await _supabase
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      _updateLocalOrder(orderId, (order) => order.copyWith(
        amountPaid: amountPaid,
        discount: discount ?? order.discount,
        paymentStatus: paymentStatus,
        paymentDate: paymentDate ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = 'Failed to update payment.';
      debugPrint('Error updating payment: $e');
      notifyListeners();
      return false;
    }
  }

  /// Add payment amount (adds to existing amount).
  Future<bool> addPayment({
    required String orderId,
    required double paymentAmount,
    required double currentAmountPaid,
  }) async {
    final newAmountPaid = currentAmountPaid + paymentAmount;
    return updatePayment(
      orderId: orderId,
      amountPaid: newAmountPaid,
    );
  }

  // ============================================================
  // DELETE ORDER
  // ============================================================

  /// Delete an order permanently from the database.
  Future<bool> deleteOrder(String orderId) async {
    try {
      // Use .select() to get back the deleted row(s) — empty list means nothing was deleted
      final deleted = await _supabase
          .from('orders')
          .delete()
          .eq('id', orderId)
          .select();

      if (deleted.isEmpty) {
        // Nothing was deleted — RLS policy may be missing or order doesn't exist
        _error = 'Could not delete. Run this SQL in Supabase SQL Editor:\n'
            'CREATE POLICY "Staff can delete orders" ON public.orders FOR DELETE '
            'USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN (\'owner\', \'office_manager\')));';
        debugPrint('Delete returned empty — RLS policy likely missing for order $orderId');
        notifyListeners();
        return false;
      }

      _orders.removeWhere((o) => o.id == orderId);
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('PostgrestException deleting order: ${e.message} (code: ${e.code})');
      return false;
    } catch (e) {
      _error = 'Failed to delete order: $e';
      debugPrint('Error deleting order: $e');
      return false;
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Update a local order in the list.
  void _updateLocalOrder(String orderId, Order Function(Order) updater) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _orders[index] = updater(_orders[index]);
      notifyListeners();
    }
  }

  /// Get active orders (not delivered or cancelled).
  List<Order> get activeOrders => _orders
      .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
      .toList();

  /// Get past orders (delivered or cancelled).
  List<Order> get pastOrders => _orders
      .where((o) => o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled)
      .toList();

  /// Get orders with pending payments.
  List<Order> get pendingPaymentOrders => _orders
      .where((o) => o.paymentStatus != PaymentStatus.paid && o.status == OrderStatus.delivered)
      .toList();

  /// Get today's orders.
  List<Order> get todaysOrders {
    final today = DateTime.now();
    return _orders.where((o) => 
      o.createdAt.year == today.year &&
      o.createdAt.month == today.month &&
      o.createdAt.day == today.day
    ).toList();
  }

  /// Get total pending amount.
  double get totalPendingAmount => pendingPaymentOrders.fold(
    0, (sum, order) => sum + order.balanceAmount
  );

  /// Search orders by customer name or phone.
  List<Order> searchOrders(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return _orders;
    
    return _orders.where((o) =>
      o.customerName.toLowerCase().contains(q) ||
      (o.customerPhone?.contains(q) ?? false) ||
      (o.orderNumber?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearOrders() {
    _orders = [];
    notifyListeners();
  }

  /// Get unique customer names for autocomplete suggestions.
  List<String> getUniqueCustomerNames() {
    final names = <String>{};
    for (final order in _orders) {
      if (order.customerName.isNotEmpty) {
        names.add(order.customerName);
      }
    }
    return names.toList()..sort();
  }
}
