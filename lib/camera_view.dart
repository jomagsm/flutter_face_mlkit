import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_better_camera/camera.dart';
import 'package:flutter_face_mlkit/utils/loading_overlay.dart';
import 'package:flutter_face_mlkit/utils/passport_data.dart';
import 'package:flutter_face_mlkit/utils/passport_data_recognizer.dart';
import 'package:flutter_face_mlkit/utils/scanner_utils.dart';
import 'package:google_ml_vision/google_ml_vision.dart';
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
  final ValueChanged<PassportData>? onCapture;
  final ValueChanged? onPassportDataRecognized;

  CameraView(
      {this.cameraLensType = CameraLensType.CAMERA_BACK,
      this.captureButtonBuilder,
      this.overlayBuilder,
      this.onCapture,
      this.onPassportDataRecognized,
      this.onError});

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _cameraController;
  Future? _cameraInitializer;
  bool _isTakePhoto = false;
  bool _isDetecting = false;
  final TextRecognizer _recognizer = GoogleVision.instance.textRecognizer();
  final PassportDataAnalyzer passportDataAnalyzer = PassportDataAnalyzer();

  Future<void> _initializeCamera() async {
    CameraDescription cameraDesc = await ScannerUtils.getCamera(
        _getCameraLensDirection(widget.cameraLensType));
    _cameraController =
        CameraController(cameraDesc, ResolutionPreset.high, enableAudio: false);

    try {
      _cameraInitializer = _cameraController!.initialize();
      await _cameraInitializer;
      startRecognizer();
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
      if (Platform.isAndroid && _cameraController!.value.isStreamingImages!) {
        await _cameraController!.stopImageStream();
        await Future.delayed(Duration(milliseconds: 500));
      }

      var tmpDir = await getTemporaryDirectory();
      var rStr = DateTime.now().microsecondsSinceEpoch.toString();
      var imgPath = '${tmpDir.path}/${rStr}_photo.jpg';

      if (Platform.isAndroid) {
        await Future.delayed(Duration(milliseconds: 300));
      }
      await _cameraController!.takePicture(imgPath);
      LoadingOverlay.showLoadingOverlay(context);
      await Future.delayed(Duration(milliseconds: 300));
      LoadingOverlay.removeLoadingOverlay();
      _isTakePhoto = false;

      _onCapture(PassportData(
          imgPath,
          passportDataAnalyzer.identificationNumber,
          passportDataAnalyzer.paperNumber));

      if (Platform.isAndroid) {
        await _cameraController!.setAutoFocus(true);
      }
    } catch (err) {
      await _cameraController!.setAutoFocus(true);
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
        imageRotation: _cameraController!.description.sensorOrientation!,
      ).then((dynamic results) {
        if (!mounted) {
          return;
        }
        var result = (results as VisionText);
        for (TextBlock block in result.blocks) {
          for (TextLine line in block.lines) {
            if (line.text != null) {
              var text = line.text!.trim();
              if(text.length == 30 && text.startsWith('IDKGZ')){
                print(text);
                var mPaperNumber = text.substring(5,14);
                var mInn = text.substring(15,29);
                if(passportDataAnalyzer.isIdentificationNumber(mInn)){
                  passportDataAnalyzer.addIdentificationNumber(mInn);
                }
                if (passportDataAnalyzer.isPassportNumber(mPaperNumber)) {
                  passportDataAnalyzer.addPassportNUmber(mPaperNumber);
                }
              }
              if (passportDataAnalyzer.isIdentificationNumber(text)) {
                passportDataAnalyzer.addIdentificationNumber(text);
              }
              if (passportDataAnalyzer.isPassportNumber(text)) {
                passportDataAnalyzer.addPassportNUmber(text);
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
      child: FutureBuilder(
        future: _cameraInitializer,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _cameraController?.value.isInitialized == true) {
            return Stack(
              children: <Widget>[
                Center(
                    child: Container(
                        child: AspectRatio(
                            aspectRatio: _cameraController!.value.aspectRatio,
                            child: CameraPreview(_cameraController!)))),
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
