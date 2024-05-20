import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'ble/ble_scanner.dart';
import 'globals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;

class AboutUsPage extends StatefulWidget {
  @override
  _AboutUsPageState createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {

  final _scrollController = ScrollController();

  @override
  void initState(){
    parseHtml();
    super.initState();
  }

  Future<dom.Document> parseHtml() async {
    return parse(await rootBundle.loadString('assets/aboutUs.html'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        //backgroundColor: WiserGlobal.appBackgroundColor,
      backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: hPi4Global.hpi4Color,
          leading: new IconButton(
              icon: new Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                Navigator.of(context).pop();
              }),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Image.asset('assets/proto-online-white.png',
                  fit: BoxFit.fitWidth, height: 30),
            ],
          ),
        ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 10,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  FutureBuilder<dom.Document>(
                      future: parseHtml(),
                      builder:
                          (BuildContext context, AsyncSnapshot<dom.Document> snapshot) {
                        if (snapshot.hasData) {
                          return Html(data: snapshot.data?.outerHtml);
                        } else {
                          return const Center(
                            child: Text("Loading"),
                          );
                        }
                      }),
                ]),
          ),
        ),
      ),

    );
  }
}
