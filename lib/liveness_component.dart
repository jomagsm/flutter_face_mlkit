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
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

enum FaceStepType {
  FACE_STEP_FACEDETECTION,
  FACE_STEP_LIVENESS,
  FACE_STEP_CAPTURING
}

enum FaceLivenessType {
  FACE_ANGLE_LEFT,
  FACE_ANGLE_RIGHT,
  FACE_ANGLE_TOP,
  FACE_ANGLE_BOTTOM
}

class LivenessComponent extends StatefulWidget {
  final Rect? ovalRect;

  final ValueChanged<double>? onLivenessPercentChange;
  final ValueChanged<FaceStepType>? onStepChanged;
  final ValueChanged<String?>? onCapturePhoto;

  final FaceLivenessType livenessType;

  final Widget Function(BuildContext)? footerBuilder;
  final Widget Function(BuildContext)? headerBuilder;

  const LivenessComponent(
      {Key? key,
      this.ovalRect,
      this.livenessType = FaceLivenessType.FACE_ANGLE_LEFT,
      this.onLivenessPercentChange,
      this.headerBuilder,
      this.footerBuilder,
      this.onCapturePhoto,
      this.onStepChanged})
      : super(key: key);

  @override
  _LivenessComponentState createState() => _LivenessComponentState();
}

class _LivenessComponentState extends State<LivenessComponent>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _keyBuilder = GlobalKey();
  Future<void>? _initializeControllerFuture;
  CameraController? _controller;
  int? _faceId;

  late CameraDescription _cameraDescription;
  bool _isDetecting = false;
  bool _isTakePhoto = false;
  FaceDetector? _faceDetector;
  Rect? _customOvalRect;

  Face? _face;

  Path? _ovalPath;
  Paint? _ovalPaint;
  AnimationController? _successImageAnimationController;
  Animation<double>? _successImageAnimation;
  bool _isAnimRun = false;

  FaceStepType _faceStepType = FaceStepType.FACE_STEP_FACEDETECTION;

  void _onPercentChange(double percent) {
    if (widget.onLivenessPercentChange != null) {
      widget.onLivenessPercentChange!(percent);
    }
  }

  void _onStepChange(FaceStepType type) {
    if (widget.onStepChanged != null) {
      widget.onStepChanged!(type);
    }
  }

  void _onCapturePhoto(String? path) {
    if (widget.onCapturePhoto != null) {
      widget.onCapturePhoto!(path);
    }
  }

  Widget _footerBlockBuilder(BuildContext context) {
    if (widget.footerBuilder != null) {
      return widget.footerBuilder!(context);
    } else {
      return const SizedBox(height: 0, width: 0);
    }
  }

  Widget _headerBlockBuilder(BuildContext context) {
    if (widget.headerBuilder != null) {
      return widget.headerBuilder!(context);
    } else {
      return const SizedBox(height: 0, width: 0);
    }
  }

  bool _isShowOvalArea() {
    return _faceStepType == FaceStepType.FACE_STEP_LIVENESS ||
        _faceStepType == FaceStepType.FACE_STEP_CAPTURING;
  }

  bool _isShowAnimationArea() {
    return _faceStepType == FaceStepType.FACE_STEP_CAPTURING;
  }

  bool _isFaceInOval(Face face) {
    var _faceAngle = face.headEulerAngleY!;

    double _facePercentage = _faceAngle * 100.0 / 50.0;
    debugPrint('Face angle percentage = $_facePercentage');

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

    if (_facePercentage < -30.0 || _facePercentage > 30.0) {
      return false;
    }
    debugPrint('-------------------$_facePercentage----------------');
    debugPrint('FACE CONFIRMING = ' +
        faceRect.toString() +
        ' - ' +
        _customOvalRect.toString());

    if (faceRect.left >= 0 &&
        faceRect.top >= _customOvalRect!.top - 30 &&
        faceRect.bottom <= _customOvalRect!.bottom + 30 &&
        faceRect.right <= absoluteImageSize.width) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> _faceDetectingStep(Face face) async {
    setState(() {
      _faceStepType = FaceStepType.FACE_STEP_LIVENESS;
      _onStepChange(_faceStepType);
    });
  }

  Future<void> _faceLivenessStep(Face face) async {
    var _faceAngleX = face.headEulerAngleY;
    var _faceAngleY = face.headEulerAngleZ;
    var _faceEyeLeft = face.leftEyeOpenProbability;
    var _faceEyeRight = face.rightEyeOpenProbability;

    debugPrint(
        '_FACE X = $_faceAngleX; _FACE Z = $_faceAngleY; _FACE LEYE = $_faceEyeLeft; _FACE_REYE = $_faceEyeRight;');

    double? _faceAngle = 0.0;
    if (widget.livenessType == FaceLivenessType.FACE_ANGLE_RIGHT) {
      _faceAngle = Platform.isAndroid
          ? _faceAngleX! < 0.0
              ? _faceAngleX
              : 0.0
          : _faceAngleX! > 0.0
              ? _faceAngleX
              : 0.0;
    } else if (widget.livenessType == FaceLivenessType.FACE_ANGLE_LEFT) {
      _faceAngle = Platform.isAndroid
          ? _faceAngleX! > 0.0
              ? _faceAngleX
              : 0.0
          : _faceAngleX! < 0.0
              ? _faceAngleX
              : 0.0;
    } else if (widget.livenessType == FaceLivenessType.FACE_ANGLE_BOTTOM) {
      _faceAngle = _faceAngleY! > 0.0 ? _faceAngleY * 50 / 16.0 : 0.0;
    } else if (widget.livenessType == FaceLivenessType.FACE_ANGLE_BOTTOM) {
      _faceAngle = _faceAngleY! < 0.0 ? _faceAngleY * 50 / 16.0 : 0.0;
    }

    _faceAngle = _faceAngle.abs();

    _faceAngle = _faceAngle > 50.0 ? 50.0 : _faceAngle;
    double _facePercentage = _faceAngle * 100.0 / 50.0;

    _onPercentChange(_facePercentage);
    if (_facePercentage > 80.0) {
      setState(() {
        _faceStepType = FaceStepType.FACE_STEP_CAPTURING;
        _onStepChange(_faceStepType);
      });
    } else {
      _onPercentChange(0);
    }
  }

  Future<void> _faceCapturingStep(Face face) async {
    if (_isTakePhoto == true) return;
    setState(() {
      _face = face;
    });

    if (_isFaceInOval(face) == true) {
      if (_isEyesClose(face)) {
        _isTakePhoto = true;
        try {
          if (Platform.isAndroid) {
            await _controller!.stopImageStream();
          }
          _successImageAnimationController!.forward();
          setState(() => _isAnimRun = true);
          var tmpDir = await getTemporaryDirectory();
          var rStr = DateTime.now().microsecondsSinceEpoch.toString();
          var imgPath = '${tmpDir.path}/${rStr}_selfie.jpg';
          var imgCopressedPath = '${tmpDir.path}/${rStr}_compressed_selfie.jpg';
          await Future.delayed(const Duration(milliseconds: 300));
          final _temp = await _controller!.takePicture();
          await _temp.saveTo(imgPath);
          LoadingOverlay.showLoadingOverlay(context);
          var compressedFile = await FlutterImageCompress.compressAndGetFile(
              imgPath, imgCopressedPath,
              quality: 75);
          imageCache!.clearLiveImages();
          imageCache!.clear();
          await _controller?.dispose();
          try {
            var faces = await _faceDetector!
                .processImage(InputImage.fromFile(compressedFile!));
            var faceForCheck = faces.first;

            if (_isEyesOpen(faceForCheck) &&
                _faceId == faceForCheck.trackingId &&
                faces.length == 1) {
              _onCapturePhoto(compressedFile.path);
            } else {
              setState(() {
                _faceStepType = FaceStepType.FACE_STEP_FACEDETECTION;
                _successImageAnimationController!.reset();
                _isTakePhoto = false;
                _isAnimRun = false;
                _isDetecting = false;
                _onStepChange(_faceStepType);
                if (Platform.isAndroid) {
                  _initializeCamera();
                }
              });
            }
          } catch (_) {
            _onCapturePhoto(null);
          }
          LoadingOverlay.removeLoadingOverlay();
        } catch (err) {
          LoadingOverlay.removeLoadingOverlay();
          debugPrint(err.toString());
          _isTakePhoto = false;
          _initializeCamera();
        }
      }
    }
  }

  bool _isEyesClose(Face face) {
    debugPrint(
        '\nL | R eye opened probability = ${face.leftEyeOpenProbability} | ${face.rightEyeOpenProbability}\n');
    if (face.leftEyeOpenProbability == null ||
        face.rightEyeOpenProbability == null) return false;
    return (face.rightEyeOpenProbability! < 0.05 &&
        face.leftEyeOpenProbability! < 0.05);
  }

  bool _isEyesOpen(Face face) {
    if (face.leftEyeOpenProbability == null ||
        face.rightEyeOpenProbability == null) return false;
    return (face.rightEyeOpenProbability! > 0.55 &&
        face.leftEyeOpenProbability! > 0.55);
  }

  Future<void> _faceProcessing(Face face) async {
    switch (_faceStepType) {
      case FaceStepType.FACE_STEP_LIVENESS:
        {
          _faceLivenessStep(face);
          break;
        }
      case FaceStepType.FACE_STEP_CAPTURING:
        {
          _faceCapturingStep(face);
          break;
        }
      case FaceStepType.FACE_STEP_FACEDETECTION:
      default:
        {
          _faceDetectingStep(face);
          break;
        }
    }
  }

  @override
  void initState() {
    super.initState();

    _customOvalRect = widget.ovalRect ?? const Rect.fromLTWH(50, 50, 250, 350);
    _ovalPath = Path()..addOval(_customOvalRect!);
    _ovalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = Colors.green;
    _successImageAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _successImageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _successImageAnimationController!,
            curve: Curves.slowMiddle));

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableTracking: true,
        enableClassification: true,
      ),
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraDescription =
        await ScannerUtils.getCamera(CameraLensDirection.front);

    _controller = CameraController(_cameraDescription,
        Platform.isIOS ? ResolutionPreset.low : ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.yuv420, enableAudio: false);
    _initializeControllerFuture = _controller!.initialize();
    if (!mounted) {
      return;
    }
    await _initializeControllerFuture;
    imageCache!.clearLiveImages();
    imageCache!.clear();
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

          List<Face> faces = results as List<Face>;

          try {
            var face = faces.first;
            if (face.trackingId != null) {
              if (_faceId == null) {
                _faceId = face.trackingId!;
              } else if (_faceId != face.trackingId) {
                setState(() {
                  debugPrint(
                      '\n\nTRACKING ID = ${face.trackingId}\nFACE ID = $_faceId');
                  _faceId = null;
                  _faceStepType = FaceStepType.FACE_STEP_LIVENESS;
                  _onStepChange(_faceStepType);
                });
              }
            }
            _faceProcessing(face);
          } catch (_) {}
        },
      ).whenComplete(() => _isDetecting = false);
    });
    setState(() {});
  }

  @override
  void dispose() {
    LoadingOverlay.removeLoadingOverlay();
    _faceDetector?.close().then((_) {
      _controller?.dispose();
    });
    _successImageAnimationController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _faceDetector?.close().then((_) {
        _controller?.dispose();
      });
      _successImageAnimationController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    return Container(
      color: Colors.black,
      child: FutureBuilder<void>(
        key: _keyBuilder,
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller?.value.isInitialized == true) {
            final Size imageSize = Size(
              _controller!.value.previewSize!.height,
              _controller!.value.previewSize!.width,
            );
            return Stack(
              children: <Widget>[
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.previewSize!.height /
                        _controller!.value.previewSize!.width,
                    child: CameraPreview(_controller!),
                  ),
                ),
                _isShowOvalArea()
                    ? CustomPaint(
                        foregroundPainter: FaceDetectorPainter(
                            imageSize, _face, _customOvalRect),
                        child: ClipPath(
                            clipper: OvalClipper(_customOvalRect),
                            child: Transform.scale(
                                scale: _controller!.value.aspectRatio /
                                    deviceRatio,
                                child: Center(
                                    child: Container(color: Colors.black54)))))
                    : const SizedBox(height: 0, width: 0),
                Positioned(
                    top: _customOvalRect!.bottom / 0.9,
                    left: 0,
                    right: 0,
                    child: Container(child: _footerBlockBuilder(context))),
                _isShowAnimationArea()
                    ? AnimatedBuilder(
                        animation: _successImageAnimationController!,
                        builder: (context, child) {
                          return Positioned(
                              child: Opacity(
                                  opacity: _successImageAnimation == null
                                      ? 0.0
                                      : _successImageAnimation!.value,
                                  child: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 52,
                                  )),
                              top: _customOvalRect!.center.dy - 26,
                              left: _customOvalRect!.center.dx - 26);
                        })
                    : const SizedBox(height: 0, width: 0),
                _isShowAnimationArea()
                    ? Positioned(
                        top: 0,
                        left: 0,
                        child: AnimatedDrawing.paths(
                          <Path>[_ovalPath!],
                          paints: <Paint>[_ovalPaint!],
                          animationOrder: PathOrder.byLength(),
                          lineAnimation: LineAnimation.oneByOne,
                          animationCurve: Curves.easeInQuad,
                          scaleToViewport: false,
                          width: _customOvalRect!.width,
                          height: _customOvalRect!.height,
                          duration: const Duration(milliseconds: 400),
                          run: _isAnimRun,
                          onFinish: () => setState(() => _isAnimRun = false),
                        ),
                      )
                    : const SizedBox(height: 0, width: 0),
                Positioned(
                  top: _customOvalRect!.top * 0.1,
                  left: 0,
                  right: 0,
                  bottom: _customOvalRect!.bottom,
                  child: _headerBlockBuilder(context),
                ),
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
}
