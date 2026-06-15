import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'network_scan_panel.dart';
import 'port_scan_panel.dart';
import 'speed_test_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _status = 'Ready';

  static const _destinations = [
    (icon: Icons.lan_outlined, label: 'Network Scan'),
    (icon: Icons.settings_ethernet, label: 'Port Scan'),
    (icon: Icons.speed, label: 'Speed Test'),
  ];

  void _updateStatus(String status) {
    if (_status == status) return;
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width > 900,
            minExtendedWidth: 180,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.wifi_tethering,
                size: 32,
                color: AppTheme.accentBlue,
              ),
            ),
            destinations: _destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon, color: AppTheme.accentBlue),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                _TitleBar(
                  title: _destinations[_selectedIndex].label,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      NetworkScanPanel(onStatusChange: _updateStatus),
                      PortScanPanel(onStatusChange: _updateStatus),
                      SpeedTestPanel(
                        isActive: _selectedIndex == 2,
                        onStatusChange: _updateStatus,
                      ),
                    ],
                  ),
                ),
                _StatusBar(status: _status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.panelBorder)),
      ),
      child: Row(
        children: [
          Text(
            'NetTool',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '›',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppTheme.statusBarBg,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
