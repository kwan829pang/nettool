import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/port_result.dart';
import '../services/port_scan_service.dart';
import '../utils/network_validation.dart';
import '../utils/user_messages.dart';
import '../widgets/authorized_use_dialog.dart';
import '../widgets/results_data_table.dart';
import '../widgets/scan_progress_panel.dart';

class PortScanPanel extends StatefulWidget {
  const PortScanPanel({super.key, this.onStatusChange});

  final ValueChanged<String>? onStatusChange;

  @override
  State<PortScanPanel> createState() => _PortScanPanelState();
}

class _PortScanPanelState extends State<PortScanPanel> {
  final _targetController = TextEditingController();
  final _startPortController = TextEditingController(text: '1');
  final _endPortController = TextEditingController(text: '1024');
  final _portScanService = PortScanService();

  List<PortResult> _results = [];
  bool _isScanning = false;
  bool _cancelScan = false;
  bool _allowExternalTargets = false;
  bool _showOpenOnly = true;
  int _completed = 0;
  int _total = 0;
  int? _currentPort;
  String? _statusMessage;

  @override
  void dispose() {
    _targetController.dispose();
    _startPortController.dispose();
    _endPortController.dispose();
    super.dispose();
  }

  void _setStatus(String message) {
    setState(() => _statusMessage = message);
    widget.onStatusChange?.call(message);
  }

  Future<void> _startScan() async {
    final accepted = await AuthorizedUseDialog.showIfNeeded(context);
    if (!accepted || !mounted) return;

    final target = _targetController.text.trim();
    final startPort = NetworkValidation.parsePort(_startPortController.text);
    final endPort = NetworkValidation.parsePort(_endPortController.text);

    if (target.isEmpty) {
      _setStatus('Enter a target IP address or hostname');
      return;
    }
    if (!NetworkValidation.isValidTarget(target)) {
      _setStatus('Enter a valid IP address or hostname');
      return;
    }
    if (startPort == null || endPort == null) {
      _setStatus('Enter valid port numbers (1–65535)');
      return;
    }
    if (!_allowExternalTargets && !NetworkValidation.isPrivateOrLocalTarget(target)) {
      _setStatus(
        'Target is outside private/local ranges — enable "External targets" if authorized',
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _cancelScan = false;
      _results = [];
      _completed = 0;
      _total = endPort - startPort + 1;
      _statusMessage = 'Scanning $target ports $startPort–$endPort…';
    });
    widget.onStatusChange?.call(_statusMessage!);

    try {
      final results = await _portScanService.scanPorts(
        target: target,
        startPort: startPort,
        endPort: endPort,
        onProgress: (completed, total, currentPort) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
            _currentPort = currentPort;
          });
        },
        isCancelled: () => _cancelScan,
      );

      if (!mounted) return;
      final openCount = results.where((r) => r.isOpen).length;
      _setStatus(
        _cancelScan
            ? 'Scan cancelled — $openCount open port(s)'
            : 'Scan complete — $openCount open port(s)',
      );
      setState(() => _results = results);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      _setStatus(e.message?.toString() ?? 'Invalid port scan input');
    } catch (e) {
      if (!mounted) return;
      _setStatus(UserMessages.forOperation('Port scan', e));
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _cancel() => setState(() => _cancelScan = true);

  void _useCommonPorts() {
    _startPortController.text = '1';
    _endPortController.text = '1024';
  }

  void _useWellKnownPorts() {
    _startPortController.text = '20';
    _endPortController.text = '10000';
  }

  Color _stateColor(PortState state) {
    return switch (state) {
      PortState.open => Colors.green,
      PortState.closed => Colors.grey,
      PortState.filtered => Colors.orange,
    };
  }

  String _stateLabel(PortState state) {
    return switch (state) {
      PortState.open => 'Open',
      PortState.closed => 'Closed',
      PortState.filtered => 'Filtered',
    };
  }

  List<PortResult> get _visibleResults {
    if (_showOpenOnly) {
      return _results.where((r) => r.isOpen).toList();
    }
    return _results;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Port Scan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check which TCP ports are open on a target host. Use only on authorized networks.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _targetController,
                    decoration: const InputDecoration(
                      labelText: 'Target',
                      hintText: '192.168.1.1 or hostname',
                      prefixIcon: Icon(Icons.computer),
                    ),
                    enabled: !_isScanning,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startPortController,
                          decoration: const InputDecoration(
                            labelText: 'Start Port',
                            prefixIcon: Icon(Icons.looks_one_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          enabled: !_isScanning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _endPortController,
                          decoration: const InputDecoration(
                            labelText: 'End Port',
                            prefixIcon: Icon(Icons.looks_two_outlined),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          enabled: !_isScanning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _allowExternalTargets,
                    onChanged: _isScanning
                        ? null
                        : (value) => setState(() => _allowExternalTargets = value ?? false),
                    title: const Text('External targets (non-private IPs)'),
                    subtitle: Text(
                      'Max ${NetworkValidation.maxPortScanRange} ports per scan',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _isScanning ? null : _useCommonPorts,
                        child: const Text('1–1024'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _isScanning ? null : _useWellKnownPorts,
                        child: const Text('20–10000'),
                      ),
                      const Spacer(),
                      FilterChip(
                        label: const Text('Open only'),
                        selected: _showOpenOnly,
                        onSelected: _isScanning
                            ? null
                            : (value) => setState(() => _showOpenOnly = value),
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
                          onPressed: _startScan,
                          icon: const Icon(Icons.search),
                          label: const Text('Start Scan'),
                        ),
                    ],
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
            currentItem: _currentPort?.toString(),
            statusMessage: _statusMessage,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ResultsDataTable(
              emptyMessage: _showOpenOnly
                  ? 'No open ports found yet. Start a port scan.'
                  : 'No results yet. Start a port scan.',
              searchHint: 'Search by port, state, or service…',
              columns: const [
                DataColumn(label: Text('Port')),
                DataColumn(label: Text('State')),
                DataColumn(label: Text('Service')),
              ],
              rowData: _visibleResults.map((result) {
                final state = _stateLabel(result.state);
                return TableRowData(
                  searchText:
                      '${result.port} $state ${result.service ?? ''}',
                  row: DataRow(
                    cells: [
                      DataCell(Text(result.port.toString())),
                      DataCell(
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: _stateColor(result.state),
                            ),
                            const SizedBox(width: 6),
                            Text(state),
                          ],
                        ),
                      ),
                      DataCell(Text(result.service ?? '—')),
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
