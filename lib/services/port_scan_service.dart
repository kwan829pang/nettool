import 'dart:async';
import 'dart:io';

import '../models/port_result.dart';
import '../utils/network_validation.dart';

typedef PortScanProgressCallback = void Function(int completed, int total, int? currentPort);

class PortScanService {
  static const Map<int, String> commonServices = {
    21: 'FTP',
    22: 'SSH',
    23: 'Telnet',
    25: 'SMTP',
    53: 'DNS',
    80: 'HTTP',
    110: 'POP3',
    143: 'IMAP',
    443: 'HTTPS',
    445: 'SMB',
    3306: 'MySQL',
    3389: 'RDP',
    5432: 'PostgreSQL',
    5900: 'VNC',
    8080: 'HTTP-Alt',
  };

  Future<List<PortResult>> scanPorts({
    required String target,
    required int startPort,
    required int endPort,
    Duration timeout = const Duration(milliseconds: 500),
    int concurrency = NetworkValidation.maxPortScanConcurrency,
    PortScanProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!NetworkValidation.isValidTarget(target)) {
      throw ArgumentError('Invalid target host or IP address');
    }
    if (startPort > endPort ||
        startPort < NetworkValidation.minPort ||
        endPort > NetworkValidation.maxPort) {
      throw ArgumentError('Invalid port range: $startPort-$endPort');
    }

    final portCount = endPort - startPort + 1;
    if (portCount > NetworkValidation.maxPortScanRange) {
      throw ArgumentError(
        'Port range too large (max ${NetworkValidation.maxPortScanRange} ports per scan)',
      );
    }

    final ports = List.generate(portCount, (i) => startPort + i);
    final results = <PortResult>[];
    var completed = 0;
    final effectiveConcurrency = concurrency.clamp(1, NetworkValidation.maxPortScanConcurrency);

    for (var i = 0; i < ports.length; i += effectiveConcurrency) {
      if (isCancelled?.call() ?? false) break;

      final batch = ports.skip(i).take(effectiveConcurrency).toList();
      for (final port in batch) {
        if (isCancelled?.call() ?? false) break;

        final result = await _scanPort(target, port, timeout);
        completed++;
        onProgress?.call(completed, ports.length, result.port);
        results.add(result);
      }
    }

    return results;
  }

  Future<PortResult> _scanPort(String target, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(
        target,
        port,
        timeout: timeout,
      );
      await socket.close();
      return PortResult(
        port: port,
        state: PortState.open,
        service: commonServices[port],
      );
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10061 ||
          e.osError?.errorCode == 111 ||
          e.message.contains('refused')) {
        return PortResult(port: port, state: PortState.closed);
      }
      return PortResult(port: port, state: PortState.filtered);
    } on TimeoutException {
      return PortResult(port: port, state: PortState.closed);
    } catch (_) {
      return PortResult(port: port, state: PortState.filtered);
    }
  }
}
