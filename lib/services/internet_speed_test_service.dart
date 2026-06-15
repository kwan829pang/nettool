import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/speed_test_result.dart';

typedef SpeedProgressCallback = void Function(int transferred, int total);

class InternetSpeedTestService {
  static const _downloadBase = 'https://speed.cloudflare.com/__down';
  static const _uploadUrl = 'https://speed.cloudflare.com/__up';
  static const _cloudflareTermsUrl = 'https://www.cloudflare.com/website-terms/';

  static const int defaultDownloadBytes = 25 * 1024 * 1024;
  static const int defaultUploadBytes = 10 * 1024 * 1024;
  static const int meteredDownloadBytes = 10 * 1024 * 1024;
  static const int meteredUploadBytes = 5 * 1024 * 1024;

  static String get cloudflareTermsUrl => _cloudflareTermsUrl;

  Future<double> measureLatency({
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final stopwatch = Stopwatch()..start();
      final request = await client.getUrl(
        Uri.parse('$_downloadBase?bytes=0'),
      );
      final response = await request.close();
      await response.timeout(timeout).drain();
      stopwatch.stop();
      if (isCancelled?.call() ?? false) return 0;
      return stopwatch.elapsedMilliseconds.toDouble();
    } finally {
      client.close(force: true);
    }
  }

  Future<SpeedMeasureResult> measureDownload({
    int? bytes,
    SpeedProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final totalBytes = bytes ?? defaultDownloadBytes;
    final client = HttpClient();
    var received = 0;
    final stopwatch = Stopwatch();

    try {
      final request = await client.getUrl(
        Uri.parse('$_downloadBase?bytes=$totalBytes'),
      );
      final response = await request.close();
      stopwatch.start();

      await for (final chunk in response) {
        if (isCancelled?.call() ?? false) break;
        received += chunk.length;
        onProgress?.call(received, totalBytes);
      }
    } finally {
      stopwatch.stop();
      client.close(force: true);
    }

    return _buildResult(
      direction: SpeedTestDirection.read,
      bytes: received,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<SpeedMeasureResult> measureUpload({
    int? bytes,
    SpeedProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final totalBytes = bytes ?? defaultUploadBytes;
    final client = HttpClient();
    var sent = 0;
    final stopwatch = Stopwatch();
    const chunkSize = 64 * 1024;
    final chunk = Uint8List(chunkSize);

    try {
      final request = await client.postUrl(Uri.parse(_uploadUrl));
      request.contentLength = totalBytes;
      stopwatch.start();

      while (sent < totalBytes) {
        if (isCancelled?.call() ?? false) break;
        final toSend = min(chunkSize, totalBytes - sent);
        request.add(chunk.sublist(0, toSend));
        sent += toSend;
        onProgress?.call(sent, totalBytes);
      }

      final response = await request.close();
      await response.drain();
    } finally {
      stopwatch.stop();
      client.close(force: true);
    }

    return _buildResult(
      direction: SpeedTestDirection.write,
      bytes: sent,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<({
    double? latencyMs,
    SpeedMeasureResult? download,
    SpeedMeasureResult? upload,
  })> runFullTest({
    SpeedProgressCallback? onProgress,
    void Function(String phase)? onPhaseChange,
    bool Function()? isCancelled,
    bool metered = false,
  }) async {
    final downloadBytes =
        metered ? meteredDownloadBytes : defaultDownloadBytes;
    final uploadBytes = metered ? meteredUploadBytes : defaultUploadBytes;

    onPhaseChange?.call('Measuring latency…');
    final latency = await measureLatency(isCancelled: isCancelled);
    if (isCancelled?.call() ?? false) {
      return (latencyMs: latency, download: null, upload: null);
    }

    onPhaseChange?.call('Testing download speed…');
    final download = await measureDownload(
      bytes: downloadBytes,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    if (isCancelled?.call() ?? false) {
      return (latencyMs: latency, download: download, upload: null);
    }

    onPhaseChange?.call('Testing upload speed…');
    final upload = await measureUpload(
      bytes: uploadBytes,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    return (latencyMs: latency, download: download, upload: upload);
  }

  SpeedMeasureResult _buildResult({
    required SpeedTestDirection direction,
    required int bytes,
    required int durationMs,
  }) {
    final seconds = durationMs / 1000.0;
    final mbps = seconds > 0 ? (bytes * 8) / (seconds * 1000000) : 0.0;

    return SpeedMeasureResult(
      type: SpeedTestType.internet,
      direction: direction,
      megabitsPerSecond: mbps,
      bytesTransferred: bytes,
      durationMs: durationMs,
      target: 'Internet (Cloudflare)',
    );
  }
}
