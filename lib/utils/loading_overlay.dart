import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'dart:io' show Platform;

class LoadingOverlay {
  static OverlayEntry? _instanceOfEntry;

  static void showLoadingOverlay(BuildContext context, {String? text}) {

    removeLoadingOverlay();
    _instanceOfEntry = OverlayEntry(
        builder: (context) => Positioned(
              left: 0,
              top: 0,
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.height,
                child: Center(
                    child: Container(                        
                        width: text == null ? 75 : 286,
                        height:  text == null ? 75 : null,
                        child: Card(
                          
                            child: text == null
                                ? Center(
                                    child: Platform.isIOS
                                        ? CupertinoActivityIndicator()
                                        : CircularProgressIndicator())
                                : Row(
                                    children: <Widget>[
                                      Container(
                                        margin: EdgeInsets.only(left: 26, right: 38),
                                        child: Platform.isIOS
                                            ? CupertinoActivityIndicator()
                                            : CircularProgressIndicator(),
                                      ),
                                      Expanded(child: Container(
                                        padding: EdgeInsets.all(8),
                                        child: Text(                                        
                                        text,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          
                                          color: Colors.green),
                                      ))),
                                    ],
                                  )))),
                decoration: BoxDecoration(color: Color(0x0f000000)),
              ),
            ));
    Overlay.of(context)!.insert(_instanceOfEntry!);
  }

  static void removeLoadingOverlay() {
    if (_instanceOfEntry != null) {
      _instanceOfEntry!.remove();
      _instanceOfEntry = null;
    }
  }
}