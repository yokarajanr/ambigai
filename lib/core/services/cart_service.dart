import 'package:flutter/foundation.dart';
import 'product_service.dart';

/// Represents an item in the shopping cart.
class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  double get totalPrice => product.pricePerUnit * quantity;

  Map<String, dynamic> toJson() => {
    'product_id': product.id,
    'product_name': product.name,
    'rate': product.pricePerUnit,
    'quantity': quantity,
    'amount': totalPrice,
  };
}

/// Cart service to manage shopping cart state.
class CartService extends ChangeNotifier {
  /// Business config — change these to adjust cart rules.
  static const double freeDeliveryThreshold = 5000;
  static const double deliveryFee = 500;
  static const int minBrickQuantity = 100;

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);

  // Delivery is free for orders above the threshold
  double get deliveryCharge => subtotal >= freeDeliveryThreshold ? 0 : deliveryFee;

  double get total => subtotal + deliveryCharge;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  /// Add a product to the cart.
  void addItem(Product product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  /// Remove a product from the cart.
  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  /// Update quantity for a specific product.
  void updateQuantity(String productId, int quantity) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  /// Increment quantity by 1.
  void incrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  /// Decrement quantity by 1 (removes if quantity becomes 0).
  void decrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Clear all items from the cart.
  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Get cart items as JSON for order creation.
  List<Map<String, dynamic>> toOrderItems() {
    return _items.map((item) => item.toJson()).toList();
  }
}
