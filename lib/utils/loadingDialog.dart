import 'package:flutter/material.dart';
import '../globals.dart';

void showLoadingIndicator(String text, BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0))),
            backgroundColor: Colors.black87,
            content: LoadingIndicator(text: text),
          ));
    },
  );
}