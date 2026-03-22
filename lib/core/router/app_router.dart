import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';

// Owner screens
import '../../features/owner/screens/owner_shell.dart';
import '../../features/owner/screens/owner_dashboard.dart';
import '../../features/owner/screens/owner_production.dart';
import '../../features/owner/screens/owner_inventory.dart';
import '../../features/owner/screens/owner_team.dart';
import '../../features/owner/screens/products_management.dart';

// Office Manager screens
import '../../features/manager/screens/office_manager_shell.dart';
import '../../features/manager/screens/office_dashboard.dart';
import '../../features/manager/screens/order_entry_form.dart';
import '../../features/manager/screens/orders_page.dart';
import '../../features/manager/screens/dc_management_page.dart';
import '../../features/manager/screens/payments_page.dart';
import '../../features/manager/screens/reports_screen.dart';

// Manufacturing Manager screens
import '../../features/manager/screens/manufacturing_manager_shell.dart';
import '../../features/manager/screens/manufacturing_dashboard.dart';

// Customer screens
import '../../features/customer/screens/customer_coming_soon.dart';

// Shared screens
import '../../features/shared/screens/change_password_screen.dart';

/// Returns the home path for a given role
String _homePathForRole(UserRole role) {
  switch (role) {
    case UserRole.owner:
      return '/owner';
    case UserRole.officeManager:
      return '/office-manager';
    case UserRole.manufacturingManager:
      return '/manufacturing-manager';
    case UserRole.customer:
      return '/customer';
  }
}

GoRouter createAppRouter(AuthService authService) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authService,
    redirect: (context, state) {
      final isLoggedIn = authService.isAuthenticated;
      final isOnAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final location = state.matchedLocation;

      // Not logged in and trying to visit a protected page? Go to login.
      if (!isLoggedIn && !isOnAuthPage) {
        return '/login';
      }

      // Already logged in but on login/signup page? Redirect to role-based home.
      if (isLoggedIn && isOnAuthPage) {
        return _homePathForRole(authService.userRole);
      }

      // Legacy /home path — redirect to role-based home
      if (isLoggedIn && location == '/home') {
        return _homePathForRole(authService.userRole);
      }

      // Role guard: prevent accessing routes for a different role
      if (isLoggedIn) {
        final role = authService.userRole;
        final homePath = _homePathForRole(role);

        // If user is accessing a role-specific path that doesn't belong to them
        if ((location.startsWith('/owner') && role != UserRole.owner) ||
            (location.startsWith('/office-manager') && role != UserRole.officeManager) ||
            (location.startsWith('/manufacturing-manager') && role != UserRole.manufacturingManager) ||
            (location.startsWith('/customer') && role != UserRole.customer)) {
          return homePath;
        }
      }

      // Otherwise, stay where you are.
      return null;
    },
    routes: [
      // --- Auth Routes (before login) ---
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        redirect: (_, __) => '/login', // Signup disabled — customer features coming soon
      ),

      // --- Owner Routes (4 tabs + extras via drawer) ---
      ShellRoute(
        builder: (context, state, child) => OwnerShell(child: child),
        routes: [
          GoRoute(
            path: '/owner',
            builder: (context, state) => const OwnerDashboard(),
          ),
          GoRoute(
            path: '/owner/orders',
            builder: (context, state) => const OrdersPage(),
          ),
          GoRoute(
            path: '/owner/dc',
            builder: (context, state) => const DCManagementPage(),
          ),
          GoRoute(
            path: '/owner/payments',
            builder: (context, state) => const PaymentsPage(),
          ),
          GoRoute(
            path: '/owner/new-order',
            builder: (context, state) => const OrderEntryForm(),
          ),
          GoRoute(
            path: '/owner/production',
            builder: (context, state) => const OwnerProduction(),
          ),
          GoRoute(
            path: '/owner/inventory',
            builder: (context, state) => const OwnerInventory(),
          ),
          GoRoute(
            path: '/owner/team',
            builder: (context, state) => const OwnerTeam(),
          ),
          GoRoute(
            path: '/owner/products',
            builder: (context, state) => const ProductsManagement(),
          ),
          GoRoute(
            path: '/owner/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/owner/change-password',
            builder: (context, state) => const ChangePasswordScreen(),
          ),
        ],
      ),

      // --- Office Manager Routes (3 tabs) ---
      ShellRoute(
        builder: (context, state, child) => OfficeManagerShell(child: child),
        routes: [
          GoRoute(
            path: '/office-manager',
            builder: (context, state) => const OfficeDashboard(),
          ),
          GoRoute(
            path: '/office-manager/orders',
            builder: (context, state) => const OrdersPage(),
          ),
          GoRoute(
            path: '/office-manager/dc',
            builder: (context, state) => const DCManagementPage(),
          ),
          GoRoute(
            path: '/office-manager/payments',
            builder: (context, state) => const PaymentsPage(),
          ),
          GoRoute(
            path: '/office-manager/new-order',
            builder: (context, state) => const OrderEntryForm(),
          ),
          GoRoute(
            path: '/office-manager/products',
            builder: (context, state) => const ProductsManagement(),
          ),
          GoRoute(
            path: '/office-manager/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/office-manager/change-password',
            builder: (context, state) => const ChangePasswordScreen(),
          ),
        ],
      ),

      // --- Manufacturing Manager Routes (3 tabs) ---
      ShellRoute(
        builder: (context, state, child) => ManufacturingManagerShell(child: child),
        routes: [
          GoRoute(
            path: '/manufacturing-manager',
            builder: (context, state) => const ManufacturingDashboard(),
          ),
          GoRoute(
            path: '/manufacturing-manager/production',
            builder: (context, state) => const OwnerProduction(),
          ),
          GoRoute(
            path: '/manufacturing-manager/inventory',
            builder: (context, state) => const OwnerInventory(),
          ),
        ],
      ),

      // --- Customer Routes (coming soon) ---
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerComingSoon(),
      ),
    ],
  );
}
