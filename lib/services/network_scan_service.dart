import 'dart:async';
import 'dart:io';

import '../models/host_device.dart';
import '../utils/network_validation.dart';
import 'network_info_service.dart';

typedef ScanProgressCallback = void Function(int completed, int total, String? currentHost);

class NetworkScanService {
  NetworkScanService({NetworkInfoService? networkInfoService})
      : _networkInfoService = networkInfoService ?? NetworkInfoService();

  final NetworkInfoService _networkInfoService;

  Future<List<HostDevice>> scanSubnet({
    required String subnet,
    int concurrency = 32,
    Duration timeout = const Duration(milliseconds: 800),
    ScanProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!NetworkValidation.isDesktopPlatform()) {
      throw UnsupportedError(
        'Subnet scanning via ping is supported on desktop platforms only.',
      );
    }

    final hosts = _networkInfoService.hostsInSubnet(subnet);
    if (hosts.isEmpty) {
      throw ArgumentError('Invalid subnet — only /24 subnets are supported (e.g. 192.168.1.0/24)');
    }

    final results = <HostDevice>[];
    var completed = 0;

    for (var i = 0; i < hosts.length; i += concurrency) {
      if (isCancelled?.call() ?? false) break;

      final batch = hosts.skip(i).take(concurrency).toList();
      for (final ip in batch) {
        if (isCancelled?.call() ?? false) break;

        final device = await _probeHost(ip, timeout);
        completed++;
        onProgress?.call(completed, hosts.length, device.ipAddress);
        if (device.isReachable) {
          results.add(device);
        }
      }
    }

    results.sort((a, b) => _compareIp(a.ipAddress, b.ipAddress));
    return results;
  }

  Future<HostDevice> _probeHost(String ip, Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    final reachable = await _pingHost(ip, timeout);
    stopwatch.stop();

    String? hostname;
    if (reachable) {
      hostname = await _resolveHostname(ip);
    }

    return HostDevice(
      ipAddress: ip,
      isReachable: reachable,
      hostname: hostname,
      responseTimeMs: reachable ? stopwatch.elapsedMilliseconds : null,
    );
  }

  Future<bool> _pingHost(String ip, Duration timeout) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'ping',
          ['-n', '1', '-w', '${timeout.inMilliseconds}', ip],
          runInShell: true,
        );
        return result.exitCode == 0;
      }

      final result = await Process.run(
        'ping',
        ['-c', '1', '-W', '${timeout.inMilliseconds ~/ 1000}', ip],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _resolveHostname(String ip) async {
    try {
      final addresses = await InternetAddress.lookup(ip);
      if (addresses.isEmpty) return null;
      return addresses.first.host;
    } catch (_) {
      return null;
    }
  }

  int _compareIp(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();
    for (var i = 0; i < 4; i++) {
      final diff = aParts[i] - bParts[i];
      if (diff != 0) return diff;
    }
    return 0;
  }
}
