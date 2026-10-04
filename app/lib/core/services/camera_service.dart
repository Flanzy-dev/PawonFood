import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CameraStatus { ready, denied, unavailable }

/// Live camera for listing photos. Camera only: there is deliberately no gallery picker anywhere in the app.
abstract class AppCamera {
  Future<CameraStatus> start();
  Widget buildPreview();
  Future<String> capture();
  Future<CameraStatus> flip();
  bool get flashOn;
  Future<void> toggleFlash();
  Future<void> dispose();
}

class DeviceCamera implements AppCamera {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  var _index = 0;
  var _flash = false;

  @override
  bool get flashOn => _flash;

  @override
  Future<CameraStatus> start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return CameraStatus.unavailable;
      _index = math.max(0, _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back));
      return await _open();
    } on CameraException catch (e) {
      return _statusFor(e);
    }
  }

  CameraStatus _statusFor(CameraException e) => e.code.toLowerCase().contains('denied') ? CameraStatus.denied : CameraStatus.unavailable;

  Future<CameraStatus> _open() async {
    await _controller?.dispose();
    final c = CameraController(_cameras[_index], ResolutionPreset.high, enableAudio: false);
    _controller = c;
    try {
      await c.initialize();
      await c.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
      return CameraStatus.ready;
    } on CameraException catch (e) {
      return _statusFor(e);
    }
  }

  @override
  Widget buildPreview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    final size = c.value.previewSize!; // reported in landscape
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: size.height, height: size.width, child: CameraPreview(c)),
      ),
    );
  }

  @override
  Future<String> capture() async {
    final file = await _controller!.takePicture();
    return file.path;
  }

  @override
  Future<CameraStatus> flip() async {
    if (_cameras.length < 2) return CameraStatus.ready;
    _index = (_index + 1) % _cameras.length;
    return _open();
  }

  @override
  Future<void> toggleFlash() async {
    _flash = !_flash;
    try {
      await _controller?.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
    } on CameraException {
      _flash = false; // front cameras have no flash
    }
  }

  @override
  Future<void> dispose() async => _controller?.dispose();
}

/// Creates the camera for the share flow. Tests override this with a fake.
final cameraFactoryProvider = Provider<AppCamera Function()>((ref) => DeviceCamera.new);
