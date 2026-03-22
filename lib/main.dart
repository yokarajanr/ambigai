import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/services/auth_service.dart';
import 'core/services/cart_service.dart';
import 'core/services/order_service.dart';
import 'core/services/product_service.dart';
import 'core/services/production_service.dart';
import 'core/services/inventory_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthService _authService;
  late final CartService _cartService;
  late final OrderService _orderService;
  late final ProductService _productService;
  late final ProductionService _productionService;
  late final InventoryService _inventoryService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _cartService = CartService();
    _orderService = OrderService();
    _productService = ProductService();
    _productionService = ProductionService();
    _inventoryService = InventoryService();
    _router = createAppRouter(_authService);
    
    // Fetch products on app start
    _productService.fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider.value(value: _cartService),
        ChangeNotifierProvider.value(value: _orderService),
        ChangeNotifierProvider.value(value: _productService),
        ChangeNotifierProvider.value(value: _productionService),
        ChangeNotifierProvider.value(value: _inventoryService),
      ],
      child: MaterialApp.router(
        title: 'Ambigai Bricks',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
