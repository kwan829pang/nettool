import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// In-memory HTTP endpoint for LAN throughput tests. No files are read or written.
class InternalSpeedTestServer {
  static final Uint8List _zeroChunk = Uint8List(64 * 1024);
  static const int maxDownloadBytes = 25 * 1024 * 1024;
  static const int defaultDownloadBytes = 10 * 1024 * 1024;
  static const int maxConcurrentRequests = 3;

  HttpServer? _server;
  int _port = 8765;
  String? _authToken;
  int _activeRequests = 0;
  void Function(Object error)? onError;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get authToken => _authToken;

  Future<void> start({int port = 8765}) async {
    if (isRunning) return;
    _port = port;
    _authToken = _generateToken();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handleRequest, onError: (error) => onError?.call(error));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _authToken = null;
    _activeRequests = 0;
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  bool _isAuthorized(HttpRequest request) {
    final token = _authToken;
    if (token == null) return false;

    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == 'Bearer $token') return true;

    return request.uri.queryParameters['token'] == token;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!_isAuthorized(request)) {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }

    if (_activeRequests >= maxConcurrentRequests) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }

    _activeRequests++;
    try {
      switch (request.uri.path) {
        case '/ping':
          request.response
            ..headers.contentType = ContentType.json
            ..write('{"status":"ok"}');
          await request.response.close();
        case '/download':
          final bytes = int.tryParse(
                request.uri.queryParameters['bytes'] ?? '',
              ) ??
              defaultDownloadBytes;
          await _streamDownload(
            request,
            bytes.clamp(1024, maxDownloadBytes),
          );
        case '/upload':
          if (request.method == 'POST') {
            await _handleUpload(request);
          } else {
            request.response.statusCode = HttpStatus.methodNotAllowed;
            await request.response.close();
          }
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    } catch (error) {
      onError?.call(error);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    } finally {
      _activeRequests--;
    }
  }

  Future<void> _streamDownload(HttpRequest request, int totalBytes) async {
    request.response.headers.set('content-type', 'application/octet-stream');
    const chunkSize = 64 * 1024;
    var sent = 0;

    while (sent < totalBytes) {
      final toSend =
          totalBytes - sent < chunkSize ? totalBytes - sent : chunkSize;
      request.response.add(
        toSend == chunkSize
            ? _zeroChunk
            : Uint8List.view(_zeroChunk.buffer, 0, toSend),
      );
      sent += toSend;
    }
    await request.response.close();
  }

  Future<void> _handleUpload(HttpRequest request) async {
    var received = 0;
    await for (final data in request) {
      received += data.length;
      if (received > maxDownloadBytes) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        await request.response.close();
        return;
      }
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write('{"bytes":$received}');
    await request.response.close();
  }
}
