import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';

class hPi4Global {
  static const String UUID_SERV_DIS = "0000180a-0000-1000-8000-00805f9b34fb";
  static const String UUID_SERV_BATT = "0000180f-0000-1000-8000-00805f9b34fb";
  static const String UUID_SERV_HR = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String UUID_SERV_SPO2 = "00001822-0000-1000-8000-00805f9b34fb";

  static const String UUID_SERV_HRV = "cd5c7491-4448-7db8-ae4c-d1da8cba36d0";
  static const String UUID_CHAR_HRV = "cd5ca86f-4448-7db8-ae4c-d1da8cba36d0";
  static const String UUID_CHAR_HIST = "cd5c1525-4448-7db8-ae4c-d1da8cba36d0";

  static const String UUID_SERVICE_CMD = "01bf7492-970f-8d96-d44d-9023c47faddc";

  static const String UUID_SERV_CMD_DATA = "01bf7492-970f-8d96-d44d-9023c47faddc";
  static const String UUID_CHAR_CMD = "01bf1528-970f-8d96-d44d-9023c47faddc";
  static const String UUID_CHAR_DATA = "01bf1527-970f-8d96-d44d-9023c47faddc";

  static const String UUID_ECG_SERVICE = "00001122-0000-1000-8000-00805f9b34fb";
  static const String UUID_ECG_CHAR = "00001424-0000-1000-8000-00805f9b34fb";
  static const String UUID_RESP_CHAR = "babe4a4c-7789-11ed-a1eb-0242ac120002";

  static const String UUID_SERV_STREAM_2 =
      "cd5c7491-4448-7db8-ae4c-d1da8cba36d0";
  static const String UUID_STREAM_2 = "01bf1525-970f-8d96-d44d-9023c47faddc";

  static const String UUID_CHAR_HR = "00002a37-0000-1000-8000-00805f9b34fb";
  static const String UUID_SPO2_CHAR = "00002a5e-0000-1000-8000-00805f9b34fb";
  static const String UUID_TEMP_CHAR = "00002a6e-0000-1000-8000-00805f9b34fb";

  static const String UUID_CHAR_ACT = "000000a2-0000-1000-8000-00805f9b34fb";
  static const String UUID_CHAR_BATT = "00002a19-0000-1000-8000-00805f9b34fb";
  static const String UUID_DIS_FW_REVISION =
      "00002a26-0000-1000-8000-00805f9b34fb";
  static const String UUID_SERV_HEALTH_THERM =
      "00001809-0000-1000-8000-00805f9b34fb";

  static const TextStyle eventStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white);
  static const TextStyle cardTextStyle =
      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white);
  static const TextStyle cardValueTextStyle =
      TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white);

  static const TextStyle cardBlackTextStyle =
      TextStyle(fontSize: 20, color: Colors.black);

  static const TextStyle eventsWhite =
      TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white);

  static const Color hpi4Color = Color(0xFF125871);
  static Color appBackgroundColor = Colors.grey.shade300;

  static String hpi4AppVersion = "";
  static String hpi4AppBuildNumber = "";

  static const List<int> sessionLogIndex = [0x50];
  static const List<int> sessionFetchLogFile = [0x51];
  static const List<int> sessionLogDelete = [0x52];
  //static const List<int> sessionLogWipeAll = [0x53];
  static const List<int> getSessionCount = [0x54];

  static const List<int> startSession = [0x55];
  static const List<int> stopSession = [0x56];

  static const int CES_CMDIF_TYPE_LOG_IDX = 0x05;
  static const int CES_CMDIF_TYPE_DATA = 0x02;
  static const int CES_CMDIF_TYPE_CMD_RSP = 0x06;

  static const List<int> WISER_CMD_SET_DEVICE_TIME = [0x41];

  static int toInt16(Uint8List byteArray, int index) {
    ByteBuffer buffer = byteArray.buffer;
    ByteData data = new ByteData.view(buffer);
    int short = data.getInt16(index, Endian.little);
    return short;
  }

  void logConsole(String logString) {
    print("AKW - " + logString);
  }

  void launchURL(String _url) async {
    await launch(_url,
        forceSafariVC: true, forceWebView: true, enableJavaScript: true);
  }

  FutureOr<bool> timeOutConnection(BuildContext context) {
    Navigator.pop(context);
    print("AKW: Connection timed out");
    return false;
  }

}

class BatteryLevelPainter extends CustomPainter {
  final int _batteryLevel;
  final int _batteryState;

  BatteryLevelPainter(this._batteryLevel, this._batteryState);

  @override
  void paint(Canvas canvas, Size size) {
    Paint getPaint(
        {Color color = Colors.black,
        PaintingStyle style = PaintingStyle.stroke}) {
      return Paint()
        ..color = color
        ..strokeWidth = 1.0
        ..style = style;
    }

    final double batteryRight = size.width - 4.0;

    final RRect batteryOutline = RRect.fromLTRBR(
        0.0, 0.0, batteryRight, size.height, Radius.circular(3.0));

    // Battery body
    canvas.drawRRect(
      batteryOutline,
      getPaint(),
    );

    // Battery nub
    canvas.drawRect(
      Rect.fromLTWH(batteryRight, (size.height / 2.0) - 5.0, 4.0, 10.0),
      getPaint(style: PaintingStyle.fill),
    );

    // Fill rect
    canvas.clipRect(Rect.fromLTWH(
        0.0, 0.0, batteryRight * _batteryLevel / 100.0, size.height));

    Color indicatorColor;
    if (_batteryLevel < 15) {
      indicatorColor = Colors.red;
    } else if (_batteryLevel < 30) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.green;
    }

    canvas.drawRRect(
        RRect.fromLTRBR(0.5, 0.5, batteryRight - 0.5, size.height - 0.5,
            Radius.circular(3.0)),
        getPaint(style: PaintingStyle.fill, color: indicatorColor));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    final BatteryLevelPainter old = oldDelegate as BatteryLevelPainter;
    return old._batteryLevel != _batteryLevel ||
        old._batteryState != _batteryState;
  }
}

class LoadingIndicator extends StatelessWidget {
  LoadingIndicator({this.text = ''});

  final String text;

  @override
  Widget build(BuildContext context) {
    var displayedText = text;

    return Container(
        padding: EdgeInsets.all(16),
        color: Colors.black.withOpacity(0.7),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _getLoadingIndicator(),
              _getHeading(context),
              _getText(displayedText)
            ]));
  }

  Padding _getLoadingIndicator() {
    return Padding(
        child: Container(
            child: SpinKitCircle(
              color: Colors.blue,
              size: 32.0,
            ),
            width: 32,
            height: 32),
        padding: EdgeInsets.only(bottom: 16));
  }

  Widget _getHeading(context) {
    return Padding(
        child: Text(
          'Please wait…',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        padding: EdgeInsets.only(bottom: 4));
  }

  Text _getText(String displayedText) {
    return Text(
      displayedText,
      style: TextStyle(color: Colors.white, fontSize: 14),
      textAlign: TextAlign.center,
    );
  }
}
