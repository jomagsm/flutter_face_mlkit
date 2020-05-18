import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_face_mlkit/camera_view.dart';
import 'package:flutter_face_mlkit/flutter_face_mlkit.dart';

void main() {
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _photoPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter ML Kit FaceDetector'),
      ),
      body: ListView(
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                RaisedButton(child: Text('Start Camera'), onPressed: () async {
                  var result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CameraScreen()));
                  if (result != null && result is String) {
                    setState(() {
                      _photoPath = result;
                    });
                  }
                }),
                RaisedButton(child: Text('Start face Camera'), onPressed: () async {
                  var result = await Navigator.push(context, MaterialPageRoute(builder: (context) => CameraFaceScreen()));
                  if (result != null && result is String) {
                    setState(() {
                      _photoPath = result;
                    });
                  }
                }),
                
                _photoPath != null
                    ? Image.file(File(_photoPath))
                    : SizedBox(
                        height: 0,
                        width: 0,
                      ),
              ],
            ),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MakeCapture'),
      ),
      body: CameraView(
        onError: print,
        onCapture: (path) {
          if (path != null) {
            print(path);
            Navigator.pop(context, path);
          }
        },
        overlayBuilder: (context) {
          return Center(child: Container(color: Colors.green, width: 50, height: 50));
        },
        captureButtonBuilder: (context, onCapture) {
          return Container( color: Colors.red, child: Center(child: RaisedButton(onPressed: () => onCapture(), child: Text('BTN'),)));
        },
      )
    );
  }
}

class CameraFaceScreen extends StatefulWidget {
  @override
  _CameraFaceScreenState createState() => _CameraFaceScreenState();
}

class _CameraFaceScreenState extends State<CameraFaceScreen> {
  
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var ovalRect = Rect.fromLTWH(((size.width / 2) - (250 / 2)), 50, 250, 350);

    return Scaffold(
      appBar: AppBar(
        title: Text('MakeCapture'),
      ),
      body: SelfieAutocapture(
        ovalRect: ovalRect,
        infoBlockBuilder: (BuildContext context) =>
            Center(child: Text('Поместите лицо в овал', style: TextStyle(
              fontSize: 18,
              color: Colors.white
            ),)),
        onCapturePhoto: (path) {
          if (path != null) {
            print(path);
            Navigator.pop(context, path);
          }
        },
      ),
      
    );
  }
}
