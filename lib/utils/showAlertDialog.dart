import 'package:flutter/material.dart';

Future<void> showAlertDialog(BuildContext context, String alertMessage) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Alert'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 72,
              ),
              Center(
                  child: Text(alertMessage)),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Close'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}