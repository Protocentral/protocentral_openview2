import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

class ShowOverlay{

  late OverlayEntry overlayEntry1;
  bool overlayFlag = false;

  void showOverlay(BuildContext context) async {
    // Declaring and Initializing OverlayState andOverlayEntry objects
    OverlayState overlayState = Overlay.of(context);
    //OverlayEntry overlayEntry1;
    overlayEntry1 = OverlayEntry(builder: (context) {
      // You can return any widget you like here to be displayed on the Overlay
      overlayFlag = true;
      return Positioned(
        left: MediaQuery.of(context).size.width * 0.3,
        top: MediaQuery.of(context).size.height * 0.2,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(MediaQuery.of(context).size.height * 0.03),
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.1,
            //color: Colors.white.withOpacity(0.3),
            color: Colors.white,
            child: Material(
              color: Colors.transparent,
              child: Text('data logging to the Flash...',
                  style: TextStyle(
                      fontSize: MediaQuery.of(context).size.height * 0.03,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ),
          ),
        ),
      );
    });

    // Inserting the OverlayEntry into the Overlay
    overlayState.insertAll([overlayEntry1]);
  }

}