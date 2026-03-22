import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/app_drawer.dart';

/// Manufacturing Manager shell — Scaffold with BottomNavigationBar + Drawer.
/// Tabs: Dashboard, Production, Inventory
class ManufacturingManagerShell extends StatefulWidget {
  final Widget child;

  const ManufacturingManagerShell({super.key, required this.child});

  @override
  State<ManufacturingManagerShell> createState() =>
      _ManufacturingManagerShellState();
}

class _ManufacturingManagerShellState extends State<ManufacturingManagerShell> {
  static const double _desktopBreakpoint = 1000;

  int _currentIndex = 0;

  static const _tabs = [
    '/manufacturing-manager',
    '/manufacturing-manager/production',
    '/manufacturing-manager/inventory',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateIndex();
  }

  void _updateIndex() {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexOf(location);
    if (index != -1 && index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      context.go(_tabs[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Ambigai Bricks'),
        centerTitle: !isDesktop,
        automaticallyImplyLeading: !isDesktop,
      ),
      drawer: isDesktop ? null : const AppDrawer(),
      body: isDesktop
          ? Row(
              children: [
                const AppDrawer(embedded: true),
                Container(width: 1, color: const Color(0xFFE2E8F0)),
                Expanded(
                  child: Column(
                    children: [
                      _buildDesktopTopTabs(),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ],
            )
          : widget.child,
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              backgroundColor: Colors.white,
              indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.precision_manufacturing_outlined),
                  selectedIcon: Icon(Icons.precision_manufacturing),
                  label: 'Production',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Inventory',
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopTopTabs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildDesktopTabChip(0, Icons.dashboard_outlined, 'Dashboard'),
          _buildDesktopTabChip(1, Icons.precision_manufacturing_outlined, 'Production'),
          _buildDesktopTabChip(2, Icons.inventory_2_outlined, 'Inventory'),
        ],
      ),
    );
  }

  Widget _buildDesktopTabChip(int index, IconData icon, String label) {
    final sel = _currentIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primaryColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppTheme.primaryColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: sel ? AppTheme.primaryColor : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                color: sel ? AppTheme.primaryColor : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
