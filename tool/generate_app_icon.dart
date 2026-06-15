import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

const _accentBlue = Color(0xFF0078D4);
const _iconSize = 1024.0;
const _glyphSize = 640.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _IconGeneratorApp());
}

class _IconGeneratorApp extends StatefulWidget {
  const _IconGeneratorApp();

  @override
  State<_IconGeneratorApp> createState() => _IconGeneratorAppState();
}

class _IconGeneratorAppState extends State<_IconGeneratorApp> {
  final _boundaryKey = GlobalKey();
  var _step = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStep());
  }

  Future<void> _runStep() async {
    await _waitForPaint();

    final bytes = await _capturePng();
    final iconDir = Directory('assets/icon');
    await iconDir.create(recursive: true);

    if (_step == 0) {
      final path = 'assets/icon/app_icon.png';
      await File(path).writeAsBytes(bytes);
      stdout.writeln('Created $path');
      setState(() => _step = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _runStep());
      return;
    }

    final foregroundPath = 'assets/icon/app_icon_foreground.png';
    await File(foregroundPath).writeAsBytes(bytes);
    stdout.writeln('Created $foregroundPath');

    await _writeLinuxIcons(File('assets/icon/app_icon.png').readAsBytesSync());
    stdout.writeln('Created Linux icon set');

    exit(0);
  }

  Future<void> _waitForPaint() async {
    for (var i = 0; i < 4; i++) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<Uint8List> _capturePng() async {
    final context = _boundaryKey.currentContext;
    if (context == null) {
      throw StateError('Icon preview is not ready');
    }

    final boundary = context.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _writeLinuxIcons(Uint8List pngBytes) async {
    final source = img.decodePng(pngBytes);
    if (source == null) return;

    for (final size in [16, 32, 48, 128, 256, 512]) {
      final resized = img.copyResize(source, width: size, height: size);
      final file = File(
        'linux/icons/hicolor/${size}x$size/apps/net_tool.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(img.encodePng(resized));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        type: MaterialType.transparency,
        child: Center(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: _step == 0 ? const _FullAppIcon() : const _ForegroundAppIcon(),
          ),
        ),
      ),
    );
  }
}

class _FullAppIcon extends StatelessWidget {
  const _FullAppIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _iconSize,
      height: _iconSize,
      decoration: BoxDecoration(
        color: _accentBlue,
        borderRadius: BorderRadius.circular(180),
      ),
      child: const Icon(
        Icons.wifi_tethering,
        size: _glyphSize,
        color: Colors.white,
      ),
    );
  }
}

class _ForegroundAppIcon extends StatelessWidget {
  const _ForegroundAppIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _iconSize,
      height: _iconSize,
      child: Center(
        child: Icon(
          Icons.wifi_tethering,
          size: _glyphSize,
          color: Colors.white,
        ),
      ),
    );
  }
}
