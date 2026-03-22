import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/app_drawer.dart';

/// Office Manager shell — responsive navigation for mobile + desktop.
class OfficeManagerShell extends StatefulWidget {
  final Widget child;

  const OfficeManagerShell({super.key, required this.child});

  @override
  State<OfficeManagerShell> createState() => _OfficeManagerShellState();
}

class _OfficeManagerShellState extends State<OfficeManagerShell> {
  static const double _desktopBreakpoint = 1000;

  int _currentIndex = 0;
  final List<int> _tabHistory = [0];

  static const _tabs = [
    '/office-manager',
    '/office-manager/orders',
    '/office-manager/dc',
    '/office-manager/payments',
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
      setState(() {
        _tabHistory.add(index);
        _currentIndex = index;
      });
      context.go(_tabs[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    return PopScope(
      canPop: _tabHistory.length <= 1 && _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_tabHistory.length > 1) {
            _tabHistory.removeLast();
            final prevIndex = _tabHistory.last;
            setState(() => _currentIndex = prevIndex);
            context.go(_tabs[prevIndex]);
          } else {
            setState(() => _currentIndex = 0);
            context.go(_tabs[0]);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            'Ambigai Bricks',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3),
          ),
          centerTitle: !isDesktop,
          automaticallyImplyLeading: !isDesktop,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF1F5F9)),
          ),
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
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
                        _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
                        _buildNavItem(2, Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'DC'),
                        _buildNavItem(3, Icons.payments_outlined, Icons.payments_rounded, 'Payments'),
                      ],
                    ),
                  ),
                ),
              ),
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
          _buildDesktopTabChip(0, Icons.dashboard_outlined, 'Home'),
          _buildDesktopTabChip(1, Icons.receipt_long_outlined, 'Orders'),
          _buildDesktopTabChip(2, Icons.local_shipping_outlined, 'DC'),
          _buildDesktopTabChip(3, Icons.payments_outlined, 'Payments'),
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
          border: Border.all(
            color: sel ? AppTheme.primaryColor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          ),
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

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final sel = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sel ? activeIcon : icon, color: sel ? AppTheme.primaryColor : const Color(0xFF94A3B8), size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: sel ? 16 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
