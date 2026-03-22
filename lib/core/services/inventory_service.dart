import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single inventory item (stock level for a product).
class InventoryItem {
  final String id;
  final String productName;
  final String? productId;
  final int stockQuantity; // finished goods on-hand
  final int? rawMaterialQty; // raw material units (e.g. clay bags)
  final String? unit;
  final String? notes;
  final DateTime updatedAt;
  final DateTime createdAt;

  InventoryItem({
    required this.id,
    required this.productName,
    this.productId,
    required this.stockQuantity,
    this.rawMaterialQty,
    this.unit,
    this.notes,
    required this.updatedAt,
    required this.createdAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      productName: json['product_name'] as String? ?? 'Unknown',
      productId: json['product_id'] as String?,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      rawMaterialQty: json['raw_material_qty'] as int?,
      unit: json['unit'] as String?,
      notes: json['notes'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isLowStock => stockQuantity < 500;
  bool get isOutOfStock => stockQuantity <= 0;
}

/// Inventory service for managing stock levels.
class InventoryService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<InventoryItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<InventoryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalStock => _items.fold(0, (sum, i) => sum + i.stockQuantity);
  int get lowStockCount => _items.where((i) => i.isLowStock && !i.isOutOfStock).length;
  int get outOfStockCount => _items.where((i) => i.isOutOfStock).length;

  /// Fetch all inventory items.
  Future<void> fetchInventory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('inventory')
          .select()
          .order('product_name', ascending: true);

      _items = (response as List)
          .map((json) => InventoryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load inventory.';
      debugPrint('Error fetching inventory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add or update stock for a product.
  Future<bool> upsertStock({
    required String productName,
    String? productId,
    required int stockQuantity,
    int? rawMaterialQty,
    String? unit,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if product already exists in inventory (prefer ID match, fall back to name)
      final existing = productId != null
          ? _items.where((i) => i.productId == productId).toList()
          : _items.where(
              (i) => i.productName.toLowerCase() == productName.toLowerCase()
            ).toList();

      if (existing.isNotEmpty) {
        // Update existing
        await _supabase
            .from('inventory')
            .update({
              'stock_quantity': stockQuantity,
              'raw_material_qty': rawMaterialQty,
              'unit': unit,
              'notes': notes,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing.first.id);
      } else {
        // Insert new
        await _supabase
            .from('inventory')
            .insert({
              'product_name': productName,
              'product_id': productId,
              'stock_quantity': stockQuantity,
              'raw_material_qty': rawMaterialQty,
              'unit': unit,
              'notes': notes,
            });
      }

      await fetchInventory();
      return true;
    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('PostgrestException upserting stock: ${e.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to update stock: $e';
      debugPrint('Error upserting stock: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adjust stock quantity by delta (positive = add, negative = subtract).
  Future<bool> adjustStock(String inventoryId, int delta, {String? notes}) async {
    try {
      final item = _items.firstWhere((i) => i.id == inventoryId);
      final newQty = (item.stockQuantity + delta).clamp(0, 999999999);

      await _supabase
          .from('inventory')
          .update({
            'stock_quantity': newQty,
            'notes': notes ?? item.notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', inventoryId);

      await fetchInventory();
      return true;
    } catch (e) {
      _error = 'Failed to adjust stock.';
      debugPrint('Error adjusting stock: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete an inventory record.
  Future<bool> deleteItem(String inventoryId) async {
    try {
      await _supabase
          .from('inventory')
          .delete()
          .eq('id', inventoryId);

      _items.removeWhere((i) => i.id == inventoryId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete inventory item.';
      debugPrint('Error deleting inventory: $e');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
