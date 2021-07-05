import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:drawing_animation/drawing_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/utils/face_detector_painter.dart';
import 'package:flutter_face_mlkit/utils/loading_overlay.dart';
import 'package:flutter_face_mlkit/utils/oval_clipper.dart';
import 'package:flutter_face_mlkit/utils/scanner_utils.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_ml_vision/google_ml_vision.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

class SelfieAutocapture extends StatefulWidget {
  final ValueChanged<String>? onCapturePhoto;
  final Widget Function(BuildContext)? infoBlockBuilder;
  final Rect? ovalRect;

  SelfieAutocapture(
      {this.onCapturePhoto, this.infoBlockBuilder, this.ovalRect});

  @override
  _SelfieAutocaptureState createState() => _SelfieAutocaptureState();
}

class _SelfieAutocaptureState extends State<SelfieAutocapture>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool isCameraReady = false;
  bool _isDetecting = false;
  bool _isTakePhoto = false;
  FaceDetector? _faceDetector;
  Face? _face;
  GlobalKey _keyBuilder = GlobalKey();
  Rect? _customOvalRect;

  late AnimationController _successImageAnimationController;
  Animation<double>? _successImageAnimation;

  BehaviorSubject<Face?>? _faceSubject;

  late CameraDescription _cameraDescription;

  bool _isAnimRun = false;

  Path? _ovalPath;
  Paint? _ovalPaint;

  void _onCapturePhoto(String path) {
    if (widget.onCapturePhoto != null) {
      widget.onCapturePhoto!(path);
    }
  }

  Widget _infoBlockBuilder(BuildContext context) {
    if (widget.infoBlockBuilder != null) {
      return widget.infoBlockBuilder!(context);
    } else {
      return SizedBox(height: 0, width: 0);
    }
  }

  bool _isFaceInOval(Face face) {
    RenderBox box = _keyBuilder.currentContext!.findRenderObject() as RenderBox;
    final Size size = box.size;
    final Size absoluteImageSize = Size(
      _controller!.value.previewSize!.height,
      _controller!.value.previewSize!.width,
    );
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;
    var faceRect = Rect.fromLTRB(
      face.boundingBox.left * scaleX,
      face.boundingBox.top * scaleY,
      face.boundingBox.right * scaleX,
      face.boundingBox.bottom * scaleY,
    );
    if (faceRect.left > _customOvalRect!.left &&
        faceRect.top > _customOvalRect!.top &&
        faceRect.bottom < _customOvalRect!.bottom &&
        faceRect.right < _customOvalRect!.right) {
      return true;
    } else {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _customOvalRect = widget.ovalRect ?? Rect.fromLTWH(50, 50, 250, 350);
    _ovalPath = Path()..addOval(_customOvalRect!);
    _ovalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = Colors.green;
    _successImageAnimationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 250));
    _successImageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _successImageAnimationController,
            curve: Curves.slowMiddle));
    _faceDetector = GoogleVision.instance.faceDetector();
    _faceSubject = BehaviorSubject<Face?>();
    _faceSubject!.stream
        .where((Face? face) {
          return face != null && _isFaceInOval(face);
        })
        .bufferTime(Duration(seconds: 1))
        .listen((faces) async {
          if (_isTakePhoto) return;
          var face = faces.length;

          if (face >= 2) {
            _isTakePhoto = true;
            try {
              await _controller!.stopImageStream();

              _successImageAnimationController.forward();
              setState(() => _isAnimRun = true);

              var tmpDir = await getTemporaryDirectory();
              var rStr = DateTime.now().microsecondsSinceEpoch.toString();
              var imgPath = '${tmpDir.path}/${rStr}_selfie.jpg';
              var imgCopressedPath =
                  '${tmpDir.path}/${rStr}_compressed_selfie.jpg';

              await Future.delayed(Duration(milliseconds: 300));
              var file = await _controller!.takePicture();
              file.saveTo(imgPath);
              LoadingOverlay.showLoadingOverlay(context);
              var compressedFile =
                  await FlutterImageCompress.compressAndGetFile(
                      imgPath, imgCopressedPath,
                      quality: 75);

              LoadingOverlay.removeLoadingOverlay();

              _onCapturePhoto(compressedFile!.path);
            } catch (err) {
              LoadingOverlay.removeLoadingOverlay();
              print(err);
              _isTakePhoto = false;
              _initializeCamera();
            }
          }
        });

    _initializeCamera();
  }

  @override
  void dispose() {
    LoadingOverlay.removeLoadingOverlay();
    _faceDetector?.close().then((_) {
      _controller?.dispose();
    });
    _faceSubject?.close();
    _successImageAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    _cameraDescription =
        await ScannerUtils.getCamera(CameraLensDirection.front);

    _controller = CameraController(_cameraDescription,
        Platform.isIOS ? ResolutionPreset.low : ResolutionPreset.medium);
    _initializeControllerFuture = _controller!.initialize();
    if (!mounted) {
      return;
    }
    await _initializeControllerFuture;

    await _controller!.startImageStream((CameraImage image) {
      if (!mounted) return;
      if (_isDetecting) return;

      _isDetecting = true;

      ScannerUtils.detect(
        image: image,
        detectInImage: _faceDetector!.processImage,
        imageRotation: _cameraDescription.sensorOrientation,
      ).then(
        (dynamic results) {
          if (!mounted) return;

          var faces = results as List<Face>;
          setState(() {
            try {
              _face = faces.first;
            } catch (_) {
              _face = null;
            }
            _faceSubject!.add(_face);
          });
        },
      ).whenComplete(() => _isDetecting = false);
    });
    setState(() {
      isCameraReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    return Container(
        child: FutureBuilder<void>(
      key: _keyBuilder,
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            _controller?.value.isInitialized == true) {
          // If the Future is complete, display the preview.
          final Size imageSize = Size(
            _controller!.value.previewSize!.height,
            _controller!.value.previewSize!.width,
          );

          return Stack(
            children: <Widget>[
              Center(child: CameraPreview(_controller!)),
              CustomPaint(
                  foregroundPainter:
                      FaceDetectorPainter(imageSize, _face, _customOvalRect),
                  child: ClipPath(
                      clipper: OvalClipper(_customOvalRect),
                      child: Transform.scale(
                          scale: _controller!.value.aspectRatio / deviceRatio,
                          child: Center(
                              child: Container(color: Colors.black54))))),
              Positioned(
                  top: _customOvalRect!.bottom + 40,
                  left: 0,
                  right: 0,
                  child: Container(child: _infoBlockBuilder(context))),
              AnimatedBuilder(
                  animation: _successImageAnimationController,
                  builder: (context, child) {
                    return Positioned(
                        child: Opacity(
                            opacity: _successImageAnimation == null
                                ? 0.0
                                : _successImageAnimation!.value,
                            child: Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 52,
                            )),
                        top: _customOvalRect!.center.dy - 26,
                        left: _customOvalRect!.center.dx - 26);
                  }),
              Positioned(
                top: 0,
                left: 0,
                child: AnimatedDrawing.paths(
                  <Path>[_ovalPath!],
                  paints: <Paint>[_ovalPaint!],
                  lineAnimation: LineAnimation.oneByOne,
                  animationCurve: Curves.easeInQuad,
                  scaleToViewport: false,
                  width: _customOvalRect!.width,
                  height: _customOvalRect!.height,
                  duration: Duration(milliseconds: 400),
                  run: _isAnimRun,
                  onFinish: () => setState(() => _isAnimRun = false),
                ),
              )
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
    ));
  }
}
