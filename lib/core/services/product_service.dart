import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Product model for bricks - fetched from Supabase.
class Product {
  final String id;
  final String name;
  final String description;
  final double pricePerUnit;
  final String unit;
  final bool isActive;
  final int displayOrder;
  final int colorValue;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.pricePerUnit,
    this.unit = 'piece',
    this.isActive = true,
    this.displayOrder = 0,
    this.colorValue = 0xFF3B82F6,
    required this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'piece',
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      colorValue: json['color_value'] as int? ?? 0xFF3B82F6,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price_per_unit': pricePerUnit,
    'unit': unit,
    'is_active': isActive,
    'display_order': displayOrder,
    'color_value': colorValue,
  };

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? pricePerUnit,
    String? unit,
    bool? isActive,
    int? displayOrder,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Format price for display
  String get formattedPrice => '₹${pricePerUnit.toStringAsFixed(2)}/$unit';
}

/// Product service for managing brick products with Supabase.
class ProductService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => List.unmodifiable(_products);
  List<Product> get activeProducts => _products.where((p) => p.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all products from Supabase.
  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('products')
          .select()
          .order('display_order', ascending: true);

      _products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load products.';
      debugPrint('Error fetching products: $e');
      
      // Fall back to default products if fetch fails
      _products = _defaultProducts;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update product price (owner only).
  Future<bool> updateProductPrice(String productId, double newPrice) async {
    try {
      await _supabase
          .from('products')
          .update({'price_per_unit': newPrice})
          .eq('id', productId);

      final index = _products.indexWhere((p) => p.id == productId);
      if (index >= 0) {
        _products[index] = _products[index].copyWith(
          pricePerUnit: newPrice,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update price.';
      debugPrint('Error updating price: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update full product details (owner only).
  Future<bool> updateProduct(Product product) async {
    try {
      await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        _products[index] = product.copyWith(updatedAt: DateTime.now());
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update product.';
      debugPrint('Error updating product: $e');
      notifyListeners();
      return false;
    }
  }

  /// Add new product (owner only).
  Future<Product?> addProduct({
    required String name,
    String? description,
    required double pricePerUnit,
    String unit = 'piece',
  }) async {
    try {
      final productData = {
        'name': name,
        'description': description ?? '',
        'price_per_unit': pricePerUnit,
        'unit': unit,
        'is_active': true,
        'display_order': _products.length + 1,
        'color_value': _getNextColor(),
      };

      final response = await _supabase
          .from('products')
          .insert(productData)
          .select()
          .single();

      final newProduct = Product.fromJson(response);
      _products.add(newProduct);
      notifyListeners();
      return newProduct;
    } catch (e) {
      _error = 'Failed to add product.';
      debugPrint('Error adding product: $e');
      notifyListeners();
      return null;
    }
  }

  /// Toggle product active status.
  Future<bool> toggleProductActive(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return false;

    final current = _products[index];
    final newStatus = !current.isActive;

    try {
      await _supabase
          .from('products')
          .update({'is_active': newStatus})
          .eq('id', productId);

      _products[index] = current.copyWith(isActive: newStatus);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update product status.';
      debugPrint('Error toggling product: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get product by ID.
  Product? getById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get product by name.
  Product? getByName(String name) {
    try {
      return _products.firstWhere(
        (p) => p.name.toLowerCase() == name.toLowerCase()
      );
    } catch (_) {
      return null;
    }
  }

  int _getNextColor() {
    const colors = [
      0xFF3B82F6, // Blue
      0xFFEF4444, // Red
      0xFF10B981, // Green
      0xFFF59E0B, // Amber
      0xFF8B5CF6, // Purple
      0xFF06B6D4, // Cyan
    ];
    return colors[_products.length % colors.length];
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Default products (fallback if Supabase fails).
  static final List<Product> _defaultProducts = [
    Product(
      id: 'fly_ash_brick',
      name: 'Fly Ash Bricks',
      description: 'Lightweight, eco-friendly bricks made from fly ash.',
      pricePerUnit: 7,
      unit: 'piece',
      isActive: true,
      displayOrder: 1,
      colorValue: 0xFF3B82F6,
      createdAt: DateTime.now(),
    ),
    Product(
      id: 'interlock_brick',
      name: 'Interlock Bricks',
      description: 'Self-locking bricks that require no mortar.',
      pricePerUnit: 12,
      unit: 'piece',
      isActive: true,
      displayOrder: 2,
      colorValue: 0xFFEF4444,
      createdAt: DateTime.now(),
    ),
    Product(
      id: 'paver_brick',
      name: 'Paver Bricks',
      description: 'Durable paving bricks for driveways and walkways.',
      pricePerUnit: 15,
      unit: 'piece',
      isActive: true,
      displayOrder: 3,
      colorValue: 0xFF10B981,
      createdAt: DateTime.now(),
    ),
    Product(
      id: 'hollow_brick',
      name: 'Hollow Bricks',
      description: 'Lightweight hollow blocks for walls.',
      pricePerUnit: 35,
      unit: 'piece',
      isActive: true,
      displayOrder: 4,
      colorValue: 0xFFF59E0B,
      createdAt: DateTime.now(),
    ),
  ];
}
