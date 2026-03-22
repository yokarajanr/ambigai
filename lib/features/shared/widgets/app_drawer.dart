import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// Common Drawer widget that reads authService.userRole and shows
/// role-appropriate menu items. Reused across all dashboards.
class AppDrawer extends StatelessWidget {
  final bool embedded;

  const AppDrawer({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final role = authService.userRole;

    final content = SafeArea(
      child: Column(
        children: [
          // --- Header: Logo + User info + Role badge ---
          _buildHeader(context, authService, role),

          const Divider(height: 1),

          // --- Menu items filtered by role ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildMenuItems(context, role),
            ),
          ),

          const Divider(height: 1),

          // --- Bottom: Profile, Settings, Logout ---
          _buildBottomSection(context, authService),
        ],
      ),
    );

    if (embedded) {
      return Container(
        width: 300,
        color: Colors.white,
        child: content,
      );
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: content,
    );
  }

  Widget _buildHeader(BuildContext context, AuthService authService, UserRole role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
      ),
      child: Row(
        children: [
          // Ambigai logo
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/logo.png',
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Ambigai Bricks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, UserRole role) {
    switch (role) {
      case UserRole.owner:
        return [
          _menuTile(context, Icons.dashboard_outlined, 'Dashboard', '/owner'),
          _menuTile(context, Icons.receipt_long_outlined, 'Orders', '/owner/orders'),
          _menuTile(context, Icons.local_shipping_outlined, 'Delivery (DC)', '/owner/dc'),
          _menuTile(context, Icons.payments_outlined, 'Payments', '/owner/payments'),
          _menuTile(context, Icons.assessment_outlined, 'Reports', '/owner/reports'),
          const Divider(height: 16, indent: 20, endIndent: 20),
          _menuTile(context, Icons.add_circle_outline, 'New Order', '/owner/new-order'),
          _menuTile(context, Icons.price_change_outlined, 'Brick Prices', '/owner/products'),
          _menuTile(context, Icons.group_outlined, 'Team Members', '/owner/team'),
          const Divider(height: 16, indent: 20, endIndent: 20),
          _menuTile(context, Icons.precision_manufacturing_outlined, 'Production', '/owner/production'),
          _menuTile(context, Icons.inventory_2_outlined, 'Inventory', '/owner/inventory'),
          const Divider(height: 16, indent: 20, endIndent: 20),
          _menuTile(context, Icons.lock_outline, 'Change Password', '/owner/change-password'),
        ];
      case UserRole.officeManager:
        return [
          _menuTile(context, Icons.dashboard_outlined, 'Dashboard', '/office-manager'),
          _menuTile(context, Icons.receipt_long_outlined, 'Orders', '/office-manager/orders'),
          _menuTile(context, Icons.local_shipping_outlined, 'Delivery (DC)', '/office-manager/dc'),
          _menuTile(context, Icons.payments_outlined, 'Payments', '/office-manager/payments'),
          _menuTile(context, Icons.assessment_outlined, 'Reports', '/office-manager/reports'),
          const Divider(height: 16, indent: 20, endIndent: 20),
          _menuTile(context, Icons.add_circle_outline, 'New Order', '/office-manager/new-order'),
          _menuTile(context, Icons.price_change_outlined, 'Brick Prices', '/office-manager/products'),
          const Divider(height: 16, indent: 20, endIndent: 20),
          _menuTile(context, Icons.lock_outline, 'Change Password', '/office-manager/change-password'),
        ];
      case UserRole.manufacturingManager:
        return [
          _menuTile(context, Icons.dashboard_outlined, 'Dashboard', '/manufacturing-manager'),
          _menuTile(context, Icons.precision_manufacturing_outlined, 'Production', '/manufacturing-manager/production'),
          _menuTile(context, Icons.inventory_2_outlined, 'Inventory', '/manufacturing-manager/inventory'),
        ];
      case UserRole.customer:
        return [
          _menuTile(context, Icons.storefront_outlined, 'Shop', '/customer'),
          _menuTile(context, Icons.receipt_long_outlined, 'My Orders', '/customer/orders'),
          _menuTile(context, Icons.shopping_cart_outlined, 'Cart', '/customer/cart'),
        ];
    }
  }

  Widget _menuTile(BuildContext context, IconData icon, String label, String route) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    final isActive = currentLocation == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppTheme.primaryColor : AppTheme.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? AppTheme.primaryColor : AppTheme.textPrimary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      selected: isActive,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: () {
        if (!embedded) {
          Navigator.of(context).pop(); // close drawer
        }
        if (!isActive) context.go(route);
      },
    );
  }

  Widget _buildBottomSection(BuildContext context, AuthService authService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, size: 22, color: AppTheme.errorColor),
            title: const Text(
              'Logout',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.errorColor,
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            onTap: () {
              if (!embedded) {
                Navigator.of(context).pop();
              }
              authService.signOut();
            },
          ),
        ],
      ),
    );
  }
}
