import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/host_device.dart';
import '../services/network_info_service.dart';
import '../services/network_scan_service.dart';
import '../utils/network_validation.dart';
import '../utils/user_messages.dart';
import '../widgets/authorized_use_dialog.dart';
import '../widgets/results_data_table.dart';
import '../widgets/scan_progress_panel.dart';

class NetworkScanPanel extends StatefulWidget {
  const NetworkScanPanel({super.key, this.onStatusChange});

  final ValueChanged<String>? onStatusChange;

  @override
  State<NetworkScanPanel> createState() => _NetworkScanPanelState();
}

class _NetworkScanPanelState extends State<NetworkScanPanel> {
  final _subnetController = TextEditingController();
  final _networkInfoService = NetworkInfoService();
  final _networkScanService = NetworkScanService();

  List<HostDevice> _hosts = [];
  bool _isScanning = false;
  bool _cancelScan = false;
  int _completed = 0;
  int _total = 0;
  String? _currentHost;
  String? _statusMessage;
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  @override
  void dispose() {
    _subnetController.dispose();
    super.dispose();
  }

  void _setStatus(String message) {
    setState(() => _statusMessage = message);
    widget.onStatusChange?.call(message);
  }

  Future<void> _loadNetworkInfo() async {
    final ip = await _networkInfoService.getLocalIp();
    if (!mounted) return;

    setState(() {
      _localIp = ip;
      if (ip != null) {
        final subnet = _networkInfoService.subnetFromIp(ip);
        if (subnet != null && _subnetController.text.isEmpty) {
          _subnetController.text = subnet;
        }
      }
    });
  }

  Future<void> _startScan() async {
    final accepted = await AuthorizedUseDialog.showIfNeeded(context);
    if (!accepted || !mounted) return;

    final subnet = _subnetController.text.trim();
    if (subnet.isEmpty) {
      _setStatus('Enter a subnet (e.g. 192.168.1.0/24)');
      return;
    }
    if (!NetworkValidation.isValidSubnet(subnet)) {
      _setStatus('Invalid subnet — use /24 format (e.g. 192.168.1.0/24)');
      return;
    }

    if (!NetworkValidation.isDesktopPlatform()) {
      _setStatus('Network scan is available on desktop platforms only');
      return;
    }

    final hosts = _networkInfoService.hostsInSubnet(subnet);
    if (hosts.isEmpty) {
      _setStatus('Invalid subnet format');
      return;
    }

    setState(() {
      _isScanning = true;
      _cancelScan = false;
      _hosts = [];
      _completed = 0;
      _total = hosts.length;
      _statusMessage = 'Discovering devices on $subnet…';
    });
    widget.onStatusChange?.call(_statusMessage!);

    try {
      final results = await _networkScanService.scanSubnet(
        subnet: subnet,
        onProgress: (completed, total, currentHost) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
            _currentHost = currentHost;
          });
        },
        isCancelled: () => _cancelScan,
      );

      if (!mounted) return;
      setState(() => _hosts = results);
      _setStatus(
        _cancelScan
            ? 'Scan cancelled — ${results.length} device(s) found'
            : 'Found ${results.length} device(s)',
      );
    } catch (e) {
      if (!mounted) return;
      _setStatus(UserMessages.forOperation('Network scan', e));
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _cancel() {
    setState(() => _cancelScan = true);
  }

  void _copyIp(String ip) {
    Clipboard.setData(ClipboardData(text: ip));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $ip'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktopOnly = !NetworkValidation.isDesktopPlatform();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Network Scan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Discover active devices on your local /24 subnet. Use only on authorized networks.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          if (_localIp != null) ...[
            const SizedBox(height: 8),
            Text(
              'This machine: $_localIp',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
          ],
          if (desktopOnly) ...[
            const SizedBox(height: 8),
            Text(
              'Subnet scanning via ping is supported on desktop platforms only.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade800,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _subnetController,
                      decoration: const InputDecoration(
                        labelText: 'Subnet',
                        hintText: '192.168.1.0/24',
                        prefixIcon: Icon(Icons.lan_outlined),
                      ),
                      enabled: !_isScanning && !desktopOnly,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isScanning)
                    OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: desktopOnly ? null : _startScan,
                      icon: const Icon(Icons.radar),
                      label: const Text('Start Scan'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ScanProgressPanel(
            isScanning: _isScanning,
            completed: _completed,
            total: _total,
            currentItem: _currentHost,
            statusMessage: _statusMessage,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ResultsDataTable(
              emptyMessage: 'No devices found yet. Start a network scan.',
              searchHint: 'Search by IP, hostname, or status…',
              columns: const [
                DataColumn(label: Text('IP Address')),
                DataColumn(label: Text('Hostname')),
                DataColumn(label: Text('Response')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rowData: _hosts.map((host) {
                final status = host.isReachable ? 'Online' : 'Offline';
                final response = host.responseTimeMs != null
                    ? '${host.responseTimeMs} ms'
                    : '';
                return TableRowData(
                  searchText:
                      '${host.ipAddress} ${host.hostname ?? ''} $status $response',
                  row: DataRow(
                    cells: [
                      DataCell(Text(host.ipAddress)),
                      DataCell(Text(host.hostname ?? '—')),
                      DataCell(Text(response.isEmpty ? '—' : response)),
                      DataCell(
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color:
                                  host.isReachable ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(status),
                          ],
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'Copy IP',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () => _copyIp(host.ipAddress),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
