import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/accounting_repository.dart';
import '../widgets/user_switch_banner.dart';
import 'dashboard_view.dart';
import 'expense_list_view.dart';
import 'claims_view.dart';
import 'cash_float_view.dart';
import 'cycle_split_view.dart';
import 'expense_entry_modal.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _onNavigateTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountingRepository>();
    final pendingCount = repo.pendingClaims.length;

    final tabs = [
      DashboardView(onNavigateTab: _onNavigateTab),
      const ExpenseListView(),
      const ClaimsView(),
      const CashFloatView(),
      const CycleSplitView(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top User Switcher Header Bar
            const UserSwitchBanner(),

            // Main Content Area with Navigation
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 800;

                  if (isDesktop) {
                    return Row(
                      children: [
                        NavigationRail(
                          backgroundColor: const Color(0xFF0F172A),
                          selectedIndex: _currentIndex,
                          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                          labelType: NavigationRailLabelType.all,
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: FloatingActionButton.small(
                              backgroundColor: const Color(0xFF6366F1),
                              child: const Icon(Icons.add_a_photo, size: 20),
                              onPressed: () => ExpenseEntryModal.show(context),
                            ),
                          ),
                          destinations: [
                            const NavigationRailDestination(
                              icon: Icon(Icons.dashboard_outlined),
                              selectedIcon: Icon(Icons.dashboard, color: Color(0xFF818CF8)),
                              label: Text('Dashboard', style: TextStyle(fontSize: 12)),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.receipt_long_outlined),
                              selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF818CF8)),
                              label: Text('Ledger', style: TextStyle(fontSize: 12)),
                            ),
                            NavigationRailDestination(
                              icon: Badge(
                                isLabelVisible: pendingCount > 0,
                                label: Text('$pendingCount'),
                                child: const Icon(Icons.approval_outlined),
                              ),
                              selectedIcon: Badge(
                                isLabelVisible: pendingCount > 0,
                                label: Text('$pendingCount'),
                                child: const Icon(Icons.approval, color: Color(0xFF818CF8)),
                              ),
                              label: const Text('Claims', style: TextStyle(fontSize: 12)),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.payments_outlined),
                              selectedIcon: Icon(Icons.payments, color: Color(0xFF10B981)),
                              label: Text('Cash Float', style: TextStyle(fontSize: 12)),
                            ),
                            const NavigationRailDestination(
                              icon: Icon(Icons.pie_chart_outline),
                              selectedIcon: Icon(Icons.pie_chart, color: Color(0xFFF59E0B)),
                              label: Text('Cycle Split', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: tabs[_currentIndex],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return tabs[_currentIndex];
                  }
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) return const SizedBox.shrink();

          return NavigationBar(
            backgroundColor: const Color(0xFF0F172A),
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            indicatorColor: const Color(0xFF6366F1).withOpacity(0.3),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: Color(0xFF818CF8)),
                label: 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF818CF8)),
                label: 'Ledger',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.approval_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.approval, color: Color(0xFF818CF8)),
                ),
                label: 'Claims',
              ),
              const NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments, color: Color(0xFF10B981)),
                label: 'Cash',
              ),
              const NavigationDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart, color: Color(0xFFF59E0B)),
                label: 'Split',
              ),
            ],
          );
        },
      ),
    );
  }
}
