import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/utils/loading_overlay.dart';
import 'package:flutter_face_mlkit/utils/scanner_utils.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

typedef Widget OverlayBuilder(BuildContext context);
typedef Widget CaptureButtonBuilder(
    BuildContext context, VoidCallback onCapture);

enum CameraLensType { CAMERA_FRONT, CAMERA_BACK }

class CameraView extends StatefulWidget {
  final CameraLensType cameraLensType;
  final OverlayBuilder? overlayBuilder;
  final CaptureButtonBuilder? captureButtonBuilder;
  final ValueChanged? onError;
  final ValueChanged? onCapture;

  CameraView(
      {this.cameraLensType = CameraLensType.CAMERA_BACK,
      this.captureButtonBuilder,
      this.overlayBuilder,
      this.onCapture,
      this.onError});

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _cameraController;
  Future? _cameraInitializer;
  bool _isTakePhoto = false;

  Future<void> _initializeCamera() async {
    CameraDescription cameraDesc = await ScannerUtils.getCamera(
        _getCameraLensDirection(widget.cameraLensType));

    _cameraController = CameraController(cameraDesc,
        Platform.isIOS ? ResolutionPreset.medium : ResolutionPreset.medium);

    try {
      _cameraInitializer = _cameraController!.initialize();

      await _cameraInitializer;
    } catch (err) {
      print(err);
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _takePhoto() async {
    try {
      if (_isTakePhoto) return;
      _isTakePhoto = true;
      var tmpDir = await getTemporaryDirectory();
      var rStr = DateTime.now().microsecondsSinceEpoch.toString();
      var imgPath = '${tmpDir.path}/${rStr}_photo.jpg';
      var imgCopressedPath = '${tmpDir.path}/${rStr}_compressed_photo.jpg';

      await Future.delayed(Duration(milliseconds: 300));
      var imgFile = await _cameraController!.takePicture();
      await imgFile.saveTo(imgPath);
      LoadingOverlay.showLoadingOverlay(context);
      var compressedFile = await FlutterImageCompress.compressAndGetFile(
          imgPath, imgCopressedPath,
          quality: 75);

      LoadingOverlay.removeLoadingOverlay();
      _isTakePhoto = false;
      _onCapture(compressedFile!.path);
    } catch (err) {
      _isTakePhoto = false;
      _onError(err);
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      _initializeCamera();
    } catch (err) {
      _onError(err);
    }
  }

  @override
  void dispose() {
    LoadingOverlay.removeLoadingOverlay();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Container(
      child: FutureBuilder(
        future: _cameraInitializer,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _cameraController?.value.isInitialized == true) {
            return Stack(
              children: <Widget>[
                Center(child: CameraPreview(_cameraController!)),
                _overlayBuilder(context),
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: _captureButtonBuilder(context, _takePhoto))
              ],
            );
          }
          if (snapshot.hasError) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Center(
                  child: Text(
                    'Произошла ошибка при инициализации камеры. Возможно вы не дали нужные разрешения!',
                    textAlign: TextAlign.center,
                  ),
                )
              ],
            );
          }
          return SizedBox(height: 0, width: 0);
        },
      ),
    );
  }

  Widget _overlayBuilder(context) {
    if (widget.overlayBuilder != null) {
      return widget.overlayBuilder!(context);
    } else {
      return SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget _captureButtonBuilder(BuildContext context, VoidCallback onCapture) {
    if (widget.captureButtonBuilder != null) {
      return widget.captureButtonBuilder!(context, onCapture);
    } else {
      return SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  void _onError(error) {
    if (widget.onError != null) {
      widget.onError!(error);
    }
  }

  void _onCapture(path) {
    if (widget.onCapture != null) {
      widget.onCapture!(path);
    }
  }

  CameraLensDirection _getCameraLensDirection(CameraLensType type) {
    switch (type) {
      case CameraLensType.CAMERA_FRONT:
        return CameraLensDirection.front;
      case CameraLensType.CAMERA_BACK:
      default:
        return CameraLensDirection.back;
    }
  }
}
