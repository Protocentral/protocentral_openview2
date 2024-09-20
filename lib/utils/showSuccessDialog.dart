import 'package:flutter/material.dart';
import '../home.dart';

Future<void> showDownloadSuccessDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Downloaded'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 72,
              ),
              Center(
                  child: Text(
                      'File downloaded successfully!. Please check in the downloads')),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Close'),
            onPressed: () {
              Navigator.pop(context);
              /*Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => HomePage(title: 'HealthyPi5')),
              );*/
            },
          ),
        ],
      );
    },
  );
}