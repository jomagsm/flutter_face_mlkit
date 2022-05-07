import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/flutter_face_mlkit.dart';
import 'package:flutter_face_mlkit/utils/loading_overlay.dart';
import 'package:flutter_face_mlkit/utils/passport_data_recognizer.dart';
import 'package:flutter_face_mlkit/utils/scanner_utils.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

typedef OverlayBuilder = Widget Function(BuildContext context);
typedef CaptureButtonBuilder = Widget Function(
    BuildContext context, VoidCallback onCapture);

enum CameraLensType { CAMERA_FRONT, CAMERA_BACK }

class CameraView extends StatefulWidget {
  const CameraView(
      {Key? key,
      this.cameraLensType = CameraLensType.CAMERA_BACK,
      this.captureButtonBuilder,
      this.overlayBuilder,
      this.onCapture,
      this.onPassportDataRecognized,
      this.onError})
      : super(key: key);

  final CameraLensType cameraLensType;
  final OverlayBuilder? overlayBuilder;
  final CaptureButtonBuilder? captureButtonBuilder;
  final ValueChanged? onError;
  final ValueChanged<PassportData>? onCapture;
  final ValueChanged? onPassportDataRecognized;

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  Future? _cameraInitializer;
  bool _isTakePhoto = false;
  bool _isDetecting = false;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final passportDataAnalyzer = PassportDataAnalyzer();

  Future<void> _initializeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    CameraDescription cameraDesc = await ScannerUtils.getCamera(
        _getCameraLensDirection(widget.cameraLensType));
    _cameraController =
        CameraController(cameraDesc, ResolutionPreset.high, enableAudio: false);
    imageCache!.clearLiveImages();
    imageCache!.clear();
    try {
      _cameraInitializer = _cameraController!.initialize();
      await _cameraInitializer;
      startRecognizer();
    } catch (err) {
      debugPrint(err.toString());
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
      if (Platform.isAndroid && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      var tmpDir = await getTemporaryDirectory();
      var rStr = DateTime.now().microsecondsSinceEpoch.toString();
      var imgPath = '${tmpDir.path}/${rStr}_photo.png';

      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      final _temp = await _cameraController!.takePicture();
      await _temp.saveTo(imgPath);
      LoadingOverlay.showLoadingOverlay(context);
      await Future.delayed(const Duration(milliseconds: 300));
      LoadingOverlay.removeLoadingOverlay();
      _isTakePhoto = false;

      _onCapture(PassportData(
          imgPath,
          passportDataAnalyzer.identificationNumber,
          passportDataAnalyzer.paperNumber));
    } catch (err) {
      // await _cameraController!.setAutoFocus(true);
      LoadingOverlay.removeLoadingOverlay();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> startRecognizer() async {
    _cameraController!.startImageStream((image) {
      if (_isDetecting) return;
      if (!mounted) {
        return;
      }
      _isDetecting = true;
      ScannerUtils.detect(
        image: image,
        detectInImage: _recognizer.processImage,
        imageRotation: _cameraController!.description.sensorOrientation,
      ).then((dynamic results) {
        if (!mounted) {
          return;
        }
        var result = (results as RecognizedText);
        for (TextBlock block in result.blocks) {
          for (TextLine line in block.lines) {
            String text = line.text.trim();
            if (text.length == 30 && text.startsWith('IDKGZ')) {
              String mPaperNumber = text.substring(5, 14);
              String mInn = text.substring(15, 29);
              if (passportDataAnalyzer.isIdentificationNumber(mInn)) {
                passportDataAnalyzer.addIdentificationNumber(mInn);
              }
              if (passportDataAnalyzer.isPassportNumber(mPaperNumber)) {
                passportDataAnalyzer.addPassportNUmber(mPaperNumber);
              }
            }
          }
        }
      }).whenComplete(() => _isDetecting = false);
    });
  }

  void disposeRecognizer() {
    _recognizer.close().then((_) {
      _cameraController?.dispose();
      _cameraController = null;
    });
  }

  @override
  void dispose() {
    LoadingOverlay.removeLoadingOverlay();
    disposeRecognizer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: FutureBuilder(
        future: _cameraInitializer,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _cameraController?.value.isInitialized == true) {
            return Stack(
              children: <Widget>[
                Center(
                    child: AspectRatio(
                        aspectRatio:
                            _cameraController!.value.previewSize!.height /
                                _cameraController!.value.previewSize!.width,
                        child: CameraPreview(_cameraController!))),
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
              children: const [
                Center(
                  child: Text(
                    'Произошла ошибка при инициализации камеры. Возможно вы не дали нужные разрешения!',
                    textAlign: TextAlign.center,
                  ),
                )
              ],
            );
          }
          return const SizedBox(height: 0, width: 0);
        },
      ),
    );
  }

  Widget _overlayBuilder(context) {
    if (widget.overlayBuilder != null) {
      return widget.overlayBuilder!(context);
    } else {
      return const SizedBox(
        height: 0,
        width: 0,
      );
    }
  }

  Widget _captureButtonBuilder(BuildContext context, VoidCallback onCapture) {
    if (widget.captureButtonBuilder != null) {
      return widget.captureButtonBuilder!(context, onCapture);
    } else {
      return const SizedBox(
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

  void _onCapture(PassportData data) {
    if (widget.onCapture != null) {
      widget.onCapture!(data);
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
