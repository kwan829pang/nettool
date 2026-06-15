import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/speed_test_result.dart';

typedef SpeedProgressCallback = void Function(int transferred, int total);

/// LAN throughput tests over HTTP using in-memory buffers only — no file I/O.
/// Traffic is unencrypted HTTP suitable for trusted LAN testing only.
class InternalSpeedTestService {
  static final Uint8List _uploadChunk = Uint8List(64 * 1024);

  Future<bool> pingHost({
    required String host,
    required int port,
    String? authToken,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final uri = _uri(host: host, port: port, path: '/ping', authToken: authToken);
      final request = await client.getUrl(uri);
      final response = await request.close();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<SpeedMeasureResult> testRead({
    required String host,
    required int port,
    int bytes = 10 * 1024 * 1024,
    String? authToken,
    SpeedProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = HttpClient();
    var received = 0;
    final stopwatch = Stopwatch();

    try {
      final uri = _uri(
        host: host,
        port: port,
        path: '/download',
        authToken: authToken,
        query: {'bytes': '$bytes'},
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      stopwatch.start();

      await for (final chunk in response) {
        if (isCancelled?.call() ?? false) {
          await response.drain();
          break;
        }
        received += chunk.length;
        onProgress?.call(received, bytes);
      }
    } finally {
      stopwatch.stop();
      client.close(force: true);
    }

    return _buildResult(
      host: host,
      port: port,
      direction: SpeedTestDirection.read,
      bytes: received,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<SpeedMeasureResult> testWrite({
    required String host,
    required int port,
    int bytes = 10 * 1024 * 1024,
    String? authToken,
    SpeedProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = HttpClient();
    var sent = 0;
    final stopwatch = Stopwatch();
    const chunkSize = 64 * 1024;

    try {
      final uri = _uri(host: host, port: port, path: '/upload', authToken: authToken);
      final request = await client.postUrl(uri);
      request.contentLength = bytes;
      stopwatch.start();

      while (sent < bytes) {
        if (isCancelled?.call() ?? false) break;
        final toSend = min(chunkSize, bytes - sent);
        request.add(
          toSend == chunkSize
              ? _uploadChunk
              : Uint8List.view(_uploadChunk.buffer, 0, toSend),
        );
        sent += toSend;
        onProgress?.call(sent, bytes);
      }

      final response = await request.close();
      await response.drain();
    } finally {
      stopwatch.stop();
      client.close(force: true);
    }

    return _buildResult(
      host: host,
      port: port,
      direction: SpeedTestDirection.write,
      bytes: sent,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<({SpeedMeasureResult read, SpeedMeasureResult? write})> testBoth({
    required String host,
    required int port,
    int bytes = 10 * 1024 * 1024,
    String? authToken,
    SpeedProgressCallback? onProgress,
    void Function(String phase)? onPhaseChange,
    bool Function()? isCancelled,
  }) async {
    onPhaseChange?.call('Testing read (download from host)…');
    final read = await testRead(
      host: host,
      port: port,
      bytes: bytes,
      authToken: authToken,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    if (isCancelled?.call() ?? false) {
      return (read: read, write: null);
    }

    onPhaseChange?.call('Testing write (upload to host)…');
    final write = await testWrite(
      host: host,
      port: port,
      bytes: bytes,
      authToken: authToken,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    return (read: read, write: write);
  }

  Uri _uri({
    required String host,
    required int port,
    required String path,
    String? authToken,
    Map<String, String>? query,
  }) {
    final params = <String, String>{...?query};
    if (authToken != null) {
      params['token'] = authToken;
    }
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: path,
      queryParameters: params.isEmpty ? null : params,
    );
  }

  SpeedMeasureResult _buildResult({
    required String host,
    required int port,
    required SpeedTestDirection direction,
    required int bytes,
    required int durationMs,
  }) {
    final seconds = durationMs / 1000.0;
    final mbps = seconds > 0 ? (bytes * 8) / (seconds * 1000000) : 0.0;

    return SpeedMeasureResult(
      type: SpeedTestType.internal,
      direction: direction,
      megabitsPerSecond: mbps,
      bytesTransferred: bytes,
      durationMs: durationMs,
      target: '$host:$port',
    );
  }
}
