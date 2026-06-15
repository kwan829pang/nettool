import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/speed_test_result.dart';
import '../services/internal_speed_test_server.dart';
import '../services/internal_speed_test_service.dart';
import '../services/internet_speed_test_service.dart';
import '../services/network_info_service.dart';
import '../theme/app_theme.dart';
import '../utils/network_validation.dart';
import '../utils/user_messages.dart';
import '../widgets/scan_progress_panel.dart';
import '../widgets/speed_result_card.dart';

class SpeedTestPanel extends StatefulWidget {
  const SpeedTestPanel({
    super.key,
    this.isActive = true,
    this.onStatusChange,
  });

  final bool isActive;
  final ValueChanged<String>? onStatusChange;

  @override
  State<SpeedTestPanel> createState() => _SpeedTestPanelState();
}

class _SpeedTestPanelState extends State<SpeedTestPanel> {
  final _internetService = InternetSpeedTestService();
  final _internalService = InternalSpeedTestService();
  final _internalServer = InternalSpeedTestServer();
  final _networkInfoService = NetworkInfoService();

  final _targetController = TextEditingController();
  final _portController = TextEditingController(text: '8765');
  final _serverPortController = TextEditingController(text: '8765');
  final _serverTokenController = TextEditingController();
  final _clientTokenController = TextEditingController();

  int _tabIndex = 0;
  bool _isRunning = false;
  bool _cancelled = false;
  bool _fetchPublicIp = false;
  int _progressCompleted = 0;
  int _progressTotal = 0;
  String? _statusMessage;
  String? _localIp;
  String? _globalIp;
  bool _loadingGlobalIp = false;

  double? _latencyMs;
  SpeedMeasureResult? _downloadResult;
  SpeedMeasureResult? _uploadResult;
  SpeedMeasureResult? _internalReadResult;
  SpeedMeasureResult? _internalWriteResult;

  @override
  void initState() {
    super.initState();
    _loadLocalIp();
    _internalServer.onError = (error) {
      if (!mounted) return;
      _setStatus('Server error — check port availability');
    };
  }

  @override
  void didUpdateWidget(covariant SpeedTestPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive && _internalServer.isRunning) {
      unawaited(_stopServer());
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    _portController.dispose();
    _serverPortController.dispose();
    _serverTokenController.dispose();
    _clientTokenController.dispose();
    unawaited(_internalServer.stop());
    super.dispose();
  }

  void _setStatus(String message) {
    setState(() => _statusMessage = message);
    widget.onStatusChange?.call(message);
  }

  Future<void> _loadLocalIp() async {
    final ip = await _networkInfoService.getLocalIp();
    if (!mounted) return;
    setState(() => _localIp = ip);
  }

  Future<void> _loadGlobalIp() async {
    setState(() {
      _loadingGlobalIp = true;
      _globalIp = null;
    });

    final ip = await _networkInfoService.getPublicIp();
    if (!mounted) return;
    setState(() {
      _loadingGlobalIp = false;
      _globalIp = ip;
    });
  }

  void _copyGlobalIp() {
    if (_globalIp == null) return;
    Clipboard.setData(ClipboardData(text: _globalIp!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $_globalIp'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _copyServerToken() {
    final token = _serverTokenController.text;
    if (token.isEmpty) return;
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied auth token'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  int get _testBytes => 10 * 1024 * 1024;

  void _resetProgress() {
    _progressCompleted = 0;
    _progressTotal = _testBytes;
    _cancelled = false;
  }

  Future<void> _runInternetTest() async {
    if (!await _networkInfoService.hasNetworkConnection()) {
      _setStatus('No network connection detected');
      return;
    }

    setState(() {
      _isRunning = true;
      _resetProgress();
      _latencyMs = null;
      _downloadResult = null;
      _uploadResult = null;
      _statusMessage = 'Starting internet speed test…';
    });
    widget.onStatusChange?.call(_statusMessage!);

    try {
      final metered = await _networkInfoService.isMeteredConnection();
      final result = await _internetService.runFullTest(
        metered: metered,
        onProgress: (transferred, total) {
          if (!mounted) return;
          setState(() {
            _progressCompleted = transferred;
            _progressTotal = total;
          });
        },
        onPhaseChange: (phase) {
          if (!mounted) return;
          _setStatus(phase);
        },
        isCancelled: () => _cancelled,
      );

      if (!mounted) return;
      setState(() {
        _latencyMs = result.latencyMs;
        _downloadResult = result.download;
        _uploadResult = result.upload;
      });
      _setStatus(
        _cancelled
            ? 'Internet test cancelled'
            : 'Internet speed test complete',
      );
    } catch (e) {
      if (!mounted) return;
      _setStatus(UserMessages.forOperation('Internet speed test', e));
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _stopServer() async {
    await _internalServer.stop();
    if (!mounted) return;
    setState(() {
      _serverTokenController.clear();
      _statusMessage = 'Internal speed test server stopped';
    });
    widget.onStatusChange?.call(_statusMessage!);
  }

  Future<void> _toggleServer() async {
    if (_internalServer.isRunning) {
      await _stopServer();
      return;
    }

    final port = NetworkValidation.parsePort(_serverPortController.text);
    if (port == null) {
      _setStatus('Enter a valid server port (1–65535)');
      return;
    }

    try {
      await _internalServer.start(port: port);
      final token = _internalServer.authToken ?? '';
      _serverTokenController.text = token;
      _clientTokenController.text = token;
      _setStatus(
        'Server running on ${_localIp ?? 'localhost'}:$port (LAN accessible — use auth token)',
      );
    } catch (e) {
      _setStatus(UserMessages.forOperation('Server start', e));
    }
  }

  String? _clientAuthToken() {
    final text = _clientTokenController.text.trim();
    return text.isEmpty ? null : text;
  }

  bool _validateInternalTarget() {
    final host = _targetController.text.trim();
    final port = NetworkValidation.parsePort(_portController.text);

    if (host.isEmpty) {
      _setStatus('Enter a target host IP address');
      return false;
    }
    if (!NetworkValidation.isValidTarget(host)) {
      _setStatus('Enter a valid target IP or hostname');
      return false;
    }
    if (port == null) {
      _setStatus('Enter a valid port (1–65535)');
      return false;
    }
    return true;
  }

  Future<void> _runInternalRead() => _runInternalTest(SpeedTestDirection.read);

  Future<void> _runInternalWrite() => _runInternalTest(SpeedTestDirection.write);

  Future<void> _runInternalBoth() async {
    if (!_validateInternalTarget()) return;

    final host = _targetController.text.trim();
    final port = NetworkValidation.parsePort(_portController.text)!;
    final authToken = _clientAuthToken();

    setState(() {
      _isRunning = true;
      _resetProgress();
      _internalReadResult = null;
      _internalWriteResult = null;
      _statusMessage = 'Connecting to $host:$port…';
    });
    widget.onStatusChange?.call(_statusMessage!);

    try {
      final reachable = await _internalService.pingHost(
        host: host,
        port: port,
        authToken: authToken,
      );
      if (!reachable) {
        _setStatus(
          'Cannot reach $host:$port — verify server, port, and auth token',
        );
        return;
      }

      final results = await _internalService.testBoth(
        host: host,
        port: port,
        bytes: _testBytes,
        authToken: authToken,
        onProgress: (transferred, total) {
          if (!mounted) return;
          setState(() {
            _progressCompleted = transferred;
            _progressTotal = total;
          });
        },
        onPhaseChange: (phase) {
          if (!mounted) return;
          _setStatus(phase);
        },
        isCancelled: () => _cancelled,
      );

      if (!mounted) return;
      setState(() {
        _internalReadResult = results.read;
        _internalWriteResult = results.write;
      });
      _setStatus(
        _cancelled
            ? 'Internal test cancelled'
            : 'Internal read/write test complete',
      );
    } catch (e) {
      if (!mounted) return;
      _setStatus(UserMessages.forOperation('Internal speed test', e));
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _runInternalTest(SpeedTestDirection direction) async {
    if (!_validateInternalTarget()) return;

    final host = _targetController.text.trim();
    final port = NetworkValidation.parsePort(_portController.text)!;
    final authToken = _clientAuthToken();

    setState(() {
      _isRunning = true;
      _resetProgress();
      if (direction == SpeedTestDirection.read) {
        _internalReadResult = null;
      } else {
        _internalWriteResult = null;
      }
      _statusMessage = direction == SpeedTestDirection.read
          ? 'Testing read from $host:$port…'
          : 'Testing write to $host:$port…';
    });
    widget.onStatusChange?.call(_statusMessage!);

    try {
      final reachable = await _internalService.pingHost(
        host: host,
        port: port,
        authToken: authToken,
      );
      if (!reachable) {
        _setStatus(
          'Cannot reach $host:$port — verify server, port, and auth token',
        );
        return;
      }

      final result = direction == SpeedTestDirection.read
          ? await _internalService.testRead(
              host: host,
              port: port,
              bytes: _testBytes,
              authToken: authToken,
              onProgress: (transferred, total) {
                if (!mounted) return;
                setState(() {
                  _progressCompleted = transferred;
                  _progressTotal = total;
                });
              },
              isCancelled: () => _cancelled,
            )
          : await _internalService.testWrite(
              host: host,
              port: port,
              bytes: _testBytes,
              authToken: authToken,
              onProgress: (transferred, total) {
                if (!mounted) return;
                setState(() {
                  _progressCompleted = transferred;
                  _progressTotal = total;
                });
              },
              isCancelled: () => _cancelled,
            );

      if (!mounted) return;
      setState(() {
        if (direction == SpeedTestDirection.read) {
          _internalReadResult = result;
        } else {
          _internalWriteResult = result;
        }
      });
      _setStatus(
        _cancelled
            ? 'Internal test cancelled'
            : '${direction == SpeedTestDirection.read ? 'Read' : 'Write'} test complete — ${result.formattedSpeed}',
      );
    } catch (e) {
      if (!mounted) return;
      _setStatus(UserMessages.forOperation('Internal speed test', e));
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _cancel() => setState(() => _cancelled = true);

  void _copyServerAddress() {
    final port = _internalServer.port;
    final address = '${_localIp ?? '127.0.0.1'}:$port';
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $address'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openCloudflareTerms() async {
    final uri = Uri.parse(InternetSpeedTestService.cloudflareTermsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Speed Test',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Measure internet bandwidth or LAN read/write throughput between devices.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.public, size: 18),
                label: Text('Internet'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.home_work_outlined, size: 18),
                label: Text('Internal Network'),
              ),
            ],
            selected: {_tabIndex},
            onSelectionChanged: _isRunning
                ? null
                : (selection) => setState(() => _tabIndex = selection.first),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tabIndex == 0 ? _buildInternetTab() : _buildInternalTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildInternetTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined, color: AppTheme.accentBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tests download and upload speed against Cloudflare\'s public '
                        'speed test endpoints. Traffic is sent to a third-party service.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isRunning)
                      OutlinedButton.icon(
                        onPressed: _cancel,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _runInternetTest,
                        icon: const Icon(Icons.speed),
                        label: const Text('Start Test'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openCloudflareTerms,
                  child: const Text('Cloudflare website terms'),
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _fetchPublicIp,
                  onChanged: _loadingGlobalIp
                      ? null
                      : (value) async {
                          final enabled = value ?? false;
                          setState(() {
                            _fetchPublicIp = enabled;
                            if (!enabled) _globalIp = null;
                          });
                          if (enabled) await _loadGlobalIp();
                        },
                  title: const Text('Look up global IP (third-party lookup)'),
                  subtitle: const Text(
                    'Contacts api.ipify.org or icanhazip.com when enabled',
                  ),
                ),
                if (_fetchPublicIp) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.language, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Global IP:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 8),
                      if (_loadingGlobalIp)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade600,
                          ),
                        )
                      else
                        Text(
                          _globalIp ?? 'Unable to detect',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _globalIp != null
                                    ? AppTheme.accentBlue
                                    : Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                        ),
                      if (_globalIp != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Copy global IP',
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: _copyGlobalIp,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh global IP',
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: _loadingGlobalIp ? null : _loadGlobalIp,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ScanProgressPanel(
          isScanning: _isRunning,
          completed: _progressCompleted,
          total: _progressTotal,
          statusMessage: _statusMessage,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SpeedResultCard(
                label: 'Latency',
                icon: Icons.timer_outlined,
                latencyMs: _latencyMs,
                accentColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpeedResultCard(
                label: 'Download',
                icon: Icons.download,
                result: _downloadResult,
                accentColor: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpeedResultCard(
                label: 'Upload',
                icon: Icons.upload,
                result: _uploadResult,
                accentColor: AppTheme.accentBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInternalTab() {
    final serverPort = NetworkValidation.parsePort(_serverPortController.text) ?? 8765;
    final serverAddress = '${_localIp ?? '127.0.0.1'}:$serverPort';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Internal tests use unencrypted HTTP on your LAN. The server is '
                      'reachable by other devices on the network and requires an auth token.',
                      style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Server (receive endpoint)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Run the server on the machine you want to test against. Share the '
                    'address and auth token with the client device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _serverPortController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          enabled: !_internalServer.isRunning && !_isRunning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _isRunning ? null : _toggleServer,
                        icon: Icon(
                          _internalServer.isRunning
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          _internalServer.isRunning ? 'Stop Server' : 'Start Server',
                        ),
                      ),
                      if (_internalServer.isRunning) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _copyServerAddress,
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(serverAddress),
                        ),
                      ],
                    ],
                  ),
                  if (_internalServer.isRunning) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _serverTokenController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Server auth token',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy auth token',
                          onPressed: _copyServerToken,
                          icon: const Icon(Icons.copy, size: 18),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client (read & write tests)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Read streams data from the target; write sends in-memory data to the target. '
                    'No files are created on either device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _targetController,
                          decoration: const InputDecoration(
                            labelText: 'Target Host',
                            hintText: '192.168.1.10',
                            prefixIcon: Icon(Icons.computer),
                            isDense: true,
                          ),
                          enabled: !_isRunning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          enabled: !_isRunning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Auth token (from target server)',
                      isDense: true,
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    enabled: !_isRunning,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _isRunning ? null : _runInternalRead,
                        icon: const Icon(Icons.download),
                        label: const Text('Test Read'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isRunning ? null : _runInternalWrite,
                        icon: const Icon(Icons.upload),
                        label: const Text('Test Write'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _isRunning ? null : _runInternalBoth,
                        icon: const Icon(Icons.swap_vert),
                        label: const Text('Test Both'),
                      ),
                      const Spacer(),
                      if (_isRunning)
                        OutlinedButton.icon(
                          onPressed: _cancel,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ScanProgressPanel(
            isScanning: _isRunning,
            completed: _progressCompleted,
            total: _progressTotal,
            statusMessage: _statusMessage,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SpeedResultCard(
                  label: 'Read (Download)',
                  icon: Icons.download,
                  result: _internalReadResult,
                  accentColor: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SpeedResultCard(
                  label: 'Write (Upload)',
                  icon: Icons.upload,
                  result: _internalWriteResult,
                  accentColor: AppTheme.accentBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
