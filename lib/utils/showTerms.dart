import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_html_css/simple_html_css.dart';

void showTermsDialog(BuildContext context) async {
  String htmlContent =
  await rootBundle.loadString('assets/termsAndConditions.html');

  showDialog(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return AlertDialog(
        title: new Text("Terms of Use"),
        content: SingleChildScrollView(
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.all(16.0),
            child: Builder(builder: (context) {
              return RichText(
                  text: HTML.toTextSpan(
                    context,
                    htmlContent,
                    linksCallback: (link) {
                      print("You clicked on $link");
                    },

                    // as name suggests, optionally set the default text style
                    defaultTextStyle: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                    overrideStyle: {
                      //"h1": TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                      "strong":
                      TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                      //"p": TextStyle(fontSize: 12.0, color: Colors.black),
                    },
                  ));
            }),
          ),
        ),
        actions: <Widget>[
          // usually buttons at the bottom of the dialog
          new TextButton(
            child: new Text("Close"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
