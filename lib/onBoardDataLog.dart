import 'dart:ffi';
import 'dart:io';
import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'package:signal_strength_indicator/signal_strength_indicator.dart';
import 'ble/ble_scanner.dart';

import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'globals.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'states/OpenViewBLEProvider.dart';

import 'dart:async';

import 'dart:typed_data';
import 'home.dart';

import 'package:csv/csv.dart';

typedef LogHeader = ({
  int logFileID,
  int sessionLength,
  int sessionID,
  int sessionType,
  int rampUp,
  int rampDown,
  int platCurr,
  int platTime,
  int tpcsPW,
  int tpcsIPI,
  int tpcsTrainTime,
  int tpcsTrainITI,
  int tmSec,
  int tmMin,
  int tmHour,
  int tmMday,
  int tmMon,
  int tmYear
});

class FetchLogData extends StatefulWidget {
  const FetchLogData(
      {Key? key,
        required this.title,
        //required this.currentDevice,
        //required this.currConnection,
        //required this.fble,
      })
      : super(key: key);

  final String title;
  //final DiscoveredDevice currentDevice;
  //final StreamSubscription<ConnectionStateUpdate> currConnection;
  //final FlutterReactiveBle fble;

  @override
  _FetchLogDataState createState() => _FetchLogDataState();
}

class _FetchLogDataState extends State<FetchLogData> {
  bool streamStarted = false;

  bool pcConnected = false;

  late Stream<List<int>> _streamCommand;
  late Stream<List<int>> _streamData;

  late StreamSubscription _streamCommandSubscription;
  late StreamSubscription _streamDataSubscription;

  late QualifiedCharacteristic commandTxCharacteristic;
  late QualifiedCharacteristic dataCharacteristic;

  double displayPercent = 0;
  double globalDisplayPercentOffset = 0;

  int totalDataCounter = 0;
  int totalUploadDataCounter = 0;
  int totalUploadBytesCounter = 0;

  int dataReceiveCounter = 0;
  int globalTotalFiles = 0;

  int totalSessionCount = 0;

  List<int> currentFileData = [];
  List<String> auditDevice = [];

  int currentFileNumber = 0;
  int currentFileExpectedLength = 0;
  int currentFileDataCounter = 0;
  int fetchedFileLength = 0;
  int fetchedCurrentFilesLength = 0;
  bool currentFileReceivedComplete = false;
  bool fetchingFile = false;

  List<int> logData = [];
  int _globalReceivedData = 0;
  int globalDataCounter = 0;
  double _globalExpectedDataMB = 0;

  String globalDeviceID = "";

  int _globalExpectedLength = 1;
  int tappedIndex = 0;

  bool listeningDataStream = false;
  bool listeningUploadStream = false;
  bool listeningConnectionStream = false;
  bool _listeningCommandStream = false;

  late DiscoveredDevice globalDiscoveredDevice;

  final _scrollController = ScrollController();

  @override
  void initState() {
    // widget.stopScan();
    tappedIndex = 0;

    pcConnected = true;
    connectedToDevice = true;

    /*dataCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD_DATA),
        serviceId: Uuid.parse(hPi4Global.UUID_SERVICE_CMD),
        deviceId: widget.currentDevice.id);
    commandTxCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERVICE_CMD),
        deviceId: widget.currentDevice.id);*/

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      //await _fetchLogCount(widget.currentDevice.id, context);
      //await _fetchLogIndex(widget.currentDevice.id, context);
    });

    super.initState();

    //Wakelock.enable();
  }

  @override
  void dispose() async {
    await closeAllStreams();
    await _disconnect();
    super.dispose();
  }

  Future<void> closeAllStreams() async {
    if (_listeningCommandStream) {
      _streamCommandSubscription.cancel();
    }
    if (listeningDataStream) {
      _streamDataSubscription.cancel();
    }
  }

  bool flagFetching = false;

  bool getFetchStatus() {
    return flagFetching;
  }

  List<int> FilesList = [];

  bool globalFetchInProgress = false;
  int globalFetchTotalFiles = 0;
  int globalFetchCurrentFile = 0;
  String globalFetchCurrentFilename = "";

  List<LogHeader> logHeaderList = List.empty(growable: true);

  int logFileCount = 0;

  Future<void> _startListeningCommand(String deviceID) async {
    /*_listeningCommandStream = true;
    //int nonZeroFiles = 0;

    //int _fetchStartFile = 0;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamCommand = widget.fble.subscribeToCharacteristic(commandTxCharacteristic);
    });

    _streamCommandSubscription = _streamCommand.listen((value) async {
      print("CMD Stream: " + value.length.toString());
    });*/
  }

  Future waitWhile(bool test(), [Duration pollInterval = Duration.zero]) {
    var completer = new Completer();
    check() {
      if (!test()) {
        completer.complete();
      } else {
        new Timer(pollInterval, check);
      }
    }

    check();
    return completer.future;
  }

  bool isTransfering = false;
  bool isFetchIconTap = false;

  void logConsole(String logString) async {
    print("AKW - " + logString);
    debugText += logString;
    debugText += "\n";
  }

  String connUpdate = "";

  int logIndexNumElements = 0;

  static const int WISER_FILE_HEADER_LEN = 28;

  Future<void> _showDownloadSuccessDialog() async {
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
                    child: Text('File downloaded successfully!. Please check in the downloads')),
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

  Future<void> _writeLogDataToFile(List<int> mData, int sessionID) async {
    logConsole("Log data size: " + mData.length.toString());

    ByteData bdata =
    Uint8List.fromList(mData).buffer.asByteData(WISER_FILE_HEADER_LEN);

    int logNumberPoints = ((mData.length - WISER_FILE_HEADER_LEN) ~/ 6);

    //List<String> data1 = ['1', 'Bilal Saeed', '1374934', '912839812'];
    List<List<String>> dataList = []; //Outter List which contains the data List

    List<String> header = [];

    header.add("Session Count");
    header.add("Current (uA)");
    header.add("Impedance (Ohm)");
    dataList.add(header);

    for (int i = 0; i < logNumberPoints; i++) {
      List<String> dataRow = [
        bdata.getUint16((i * 6), Endian.little).toString(),
        bdata.getInt16((i * 6) + 2, Endian.little).toString(),
        bdata.getUint16((i * 6) + 4, Endian.little).toString()
      ];
      dataList.add(dataRow);
    }

    // Code to convert logData to CSV file

    String csv = const ListToCsvConverter().convert(dataList);

    Directory _directory = Directory("");
    if (Platform.isAndroid) {
      // Redirects it to download folder in android
      _directory = Directory("/storage/emulated/0/Download");
    } else {
      _directory = await getApplicationDocumentsDirectory();
    }
    final exPath = _directory.path;
    print("Saved Path: $exPath");
    await Directory(exPath).create(recursive: true);

    final String directory = exPath;

    File file= File('$directory/logdata$sessionID.csv');;
    print("Save file");

    await file.writeAsString(csv);

    print("File exported successfully!");

    await _showDownloadSuccessDialog();

  }

  bool logIndexReceived = false;

  Future<void> _startListeningData(
      String deviceID, int expectedLength, int sessionID) async {
    /*listeningDataStream = true;
    await Future.delayed(Duration(seconds: 1), () async {
      _streamData = widget.fble.subscribeToCharacteristic(dataCharacteristic);
    });

    _streamDataSubscription = _streamData.listen((value) async {
      ByteData bdata = Uint8List.fromList(value).buffer.asByteData();
      print("Data Rx: " + value.toString());
      int _pktType = bdata.getUint8(0);

      if (_pktType == hPi4Global.CES_CMDIF_TYPE_CMD_RSP) {
        int _cmdType = bdata.getUint8(1);
        if (_cmdType == 84) {
          setState(() {
            totalSessionCount = bdata.getUint16(2, Endian.little);
          });
          print("Data Rx count: " + totalSessionCount.toString());

          await _streamCommandSubscription.cancel();
          await _streamDataSubscription.cancel();
        }
      } else if (_pktType == hPi4Global.CES_CMDIF_TYPE_LOG_IDX) {
        //print("Data Rx: " + value.toString());
        print("Data Rx length: " + value.length.toString());

        /*ByteData bdata = Uint8List.fromList(value)
            .buffer
            .asByteData(1); // Frame body starts from 2nd byte
            */

        LogHeader _mLog = (
            logFileID: bdata.getUint16(1, Endian.little),
            sessionID: bdata.getUint8(1), // same as log file id

      sessionLength: bdata.getUint16(3, Endian.little),
      // Session length is at

      //logSessionLength: bdata.getUint16(2, Endian.little),
      // Session ID is at 5
      sessionType: bdata.getUint8(6),
      rampUp: bdata.getUint16(7, Endian.little),
      rampDown: bdata.getUint16(9, Endian.little),
      platCurr: bdata.getUint16(11, Endian.little),
      platTime: bdata.getUint16(13, Endian.little),
      tpcsPW: bdata.getUint16(15, Endian.little),
      tpcsIPI: bdata.getUint16(17, Endian.little),
      tpcsTrainTime: bdata.getUint16(19, Endian.little),
      tpcsTrainITI: bdata.getUint16(21, Endian.little),
      tmYear: bdata.getUint8(23),
      tmMon: bdata.getUint8(24),
      tmMday: bdata.getUint8(25),
      tmHour: bdata.getUint8(26),
      tmMin: bdata.getUint8(27),
      tmSec: bdata.getUint8(28),
      );
      print("Log: " + _mLog.toString());

      logHeaderList.add(_mLog);

      //print("......"+logHeaderList[0].logFileID.toString());

      if (logHeaderList.length == totalSessionCount) {
      setState(() {
      logIndexReceived = true;
      });

      print("All logs received. Cancel subscription");

      await _streamCommandSubscription.cancel();
      await _streamDataSubscription.cancel();
      } else {}
      } else if (_pktType == hPi4Global.CES_CMDIF_TYPE_DATA) {
      int pktPayloadSize = value.length - 1; //((value[1] << 8) + value[2]);

      logConsole("Data Rx length: " +
      value.length.toString() +
      " | Actual Payload: " +
      pktPayloadSize.toString());
      currentFileDataCounter += pktPayloadSize;
      _globalReceivedData += pktPayloadSize;
      logData.addAll(value.sublist(1, value.length));

      setState(() {
      displayPercent = globalDisplayPercentOffset +
      (_globalReceivedData / _globalExpectedLength) * 100.truncate();
      if (displayPercent > 100) {
      displayPercent = 100;
      }
      });

      logConsole("File data counter: " +
      currentFileDataCounter.toString() +
      " | Received: " +
      displayPercent.toString() +
      "%");

      if (currentFileDataCounter >= (expectedLength)) {
      logConsole(
      "All data " + currentFileDataCounter.toString() + " received");

      if (currentFileDataCounter > expectedLength) {
      int diffData = currentFileDataCounter - expectedLength;
      logConsole("Data received more than expected by: " +
      diffData.toString() +
      " bytes");
      //logData.removeRange(expectedLength, currentFileDataCounter);
      }

      await _streamCommandSubscription.cancel();
      await _streamDataSubscription.cancel();

      await _writeLogDataToFile(logData, sessionID);

      //Navigator.pop(context);

      setState(() {
      flagFetching = false;
      isTransfering = false;
      isFetchIconTap = false;
      });

      // Reset all fetch variables
      displayPercent = 0;
      globalDisplayPercentOffset = 0;
      currentFileDataCounter = 0;
      _globalReceivedData = 0;
      currentFileReceivedComplete = false;
      logData.clear();
      }
      }
    });*/
  }

  double fileUploadDisplayPercent = 0;

  double fileExpectedData = 0;

  int uploadcurrentFileNumber = 0;
  int uploadtotalFiles = 0;

  Stopwatch fetchStopwatch = new Stopwatch();

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

  Future<void> _disconnect() async {
   /* //String deviceID = patchCurrentMAC;
    fetchingFile = false;
    try {
      logConsole('Disconnecting ');
      if (connectedToDevice == true) await widget.currConnection.cancel();
    } on Exception catch (e, _) {
      logConsole("Error disconnecting from a device: $e");
    } finally {
      // Since [_connection] subscription is terminated, the "disconnected" state cannot be received and propagated
    }*/
  }

  String debugText = "Console Inited...";

  Widget _getDeviceCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Consumer2<ConnectionStateUpdate, BleScannerState>(builder:
                        (context, connStateUpdate, bleScannerState, child) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                8, 4, 8, 4), // .all(8.0),
                            child: Text(
                              "Connected to Device: " ,
                                  //+ widget.currentDevice.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                //color: Colors.white,
                              ),
                              //textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: MaterialButton(
                              onPressed: () async {
                                /*await _fetchLogCount(
                                    widget.currentDevice.id, context);
                                await _fetchLogIndex(
                                    widget.currentDevice.id, context);*/
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.download,
                                      color: Colors.white,
                                    ),
                                    const Text(
                                      'Fetch refresh',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              color: hPi4Global.hpi4Color,
                            ),
                          ),
                        ],
                      );
                    }),
                  ]))),
    );
  }

  bool _endFetchEnabled = false;

  //late StreamSubscription<ConnectionStateUpdate> _connection;
  bool connectedToDevice = false;

  Future<void> _fetchLogCount(String deviceID, BuildContext context) async {
    logConsole("Fetch log count initiated");
    showLoadingIndicator("Fetching logs count...", context);
    await _startListeningCommand(deviceID);
    await _startListeningData(deviceID, 0, 0);
    await Future.delayed(Duration(seconds: 2), () async {
      await _sendCommand(hPi4Global.getSessionCount, deviceID);
    });
    Navigator.pop(context);
  }

  Future<void> _fetchLogIndex(String deviceID, BuildContext context) async {
    logConsole("Fetch logs initiated");
    showLoadingIndicator("Fetching logs...", context);
    await _startListeningCommand(deviceID);
    await _startListeningData(deviceID, 0, 0);
    await Future.delayed(Duration(seconds: 2), () async {
      await _sendCommand(hPi4Global.sessionLogIndex, deviceID);
      //await _sendCommand(WiserGlobal.getSessionCount, deviceID);
    });
    Navigator.pop(context);
  }

  Future<void> _deleteLogIndex(
      String deviceID, int sessionID, BuildContext context) async {
    logConsole("Deleted logs initiated");
    showLoadingIndicator("Deleting log...", context);
    await Future.delayed(Duration(seconds: 2), () async {
      List<int> commandFetchLogFile = List.empty(growable: true);
      commandFetchLogFile.addAll(hPi4Global.sessionLogDelete);
      commandFetchLogFile.add(sessionID & 0xFF);
      commandFetchLogFile.add((sessionID >> 8) & 0xFF);
      await _sendCommand(commandFetchLogFile, deviceID);
    });
    Navigator.pop(context);
    //await _fetchLogIndex(widget.currentDevice.id, context);
  }

  Future<void> _fetchLogFile(
      String deviceID, int sessionID, int sessionSize) async {
    logConsole("Fetch logs initiated");
    isTransfering = true;
    await _startListeningCommand(deviceID);
    // Session size is in bytes, so multiply by 6 to get the number of data points, add header size
    await _startListeningData(
        deviceID, ((sessionSize * 6) + WISER_FILE_HEADER_LEN), sessionID);

    // Reset all fetch variables
    currentFileDataCounter = 0;
    currentFileReceivedComplete = false;

    _globalExpectedLength = sessionSize;
    logData.clear();

    await Future.delayed(Duration(seconds: 2), () async {
      List<int> commandFetchLogFile = List.empty(growable: true);
      commandFetchLogFile.addAll(hPi4Global.sessionFetchLogFile);
      commandFetchLogFile.add((sessionID >> 8) & 0xFF);
      commandFetchLogFile.add(sessionID & 0xFF);
      await _sendCommand(commandFetchLogFile, deviceID);
    });
  }

  Future<void> _sendCommand(List<int> commandList, String deviceID) async {
    logConsole(
        "Tx CMD " + commandList.toString() + " 0x" + hex.encode(commandList));

    /*await widget.fble.writeCharacteristicWithoutResponse(commandTxCharacteristic,
        value: commandList);*/
  }

  Future<void> cancelAction() async {
    if (_listeningCommandStream) {
      _streamCommandSubscription.cancel();
    }
    if (listeningDataStream) {
      _streamDataSubscription.cancel();
    }
    await _disconnect();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => HomePage(
            title: 'wiser',
          )),
    );
  }

  double count = 0.1;

  String _getFormattedDate(
      int year, int month, int day, int hour, int min, int sec) {
    String formattedDate = hour.toString() +
        ":" +
        min.toString() +
        ":" +
        sec.toString() +
        " " +
        day.toString() +
        "/" +
        month.toString() +
        "/" +
        year.toString();

    return formattedDate;
  }

  Widget _getSessionIDList() {
    return (logIndexReceived == false)
        ? Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: 320,
        height: 100,
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0)),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  "No logs present on device ",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ]),
        ),
      ),
    )
        : Container(
        height: 400,
        child: Scrollbar(
          //isAlwaysShown: true,
          controller: _scrollController,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    "Session logs on device ",
                    style: TextStyle(
                      fontSize: 22,
                      //color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: 15.0,
                  ),
                  ListView.builder(
                    // itemCount: logIndexNumElements,
                      itemCount: totalSessionCount,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (BuildContext context, int index) {
                        return (index >= 0)
                            ? Card(
                            child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.only(
                                      left: 0.0, right: 0.0),
                                  minLeadingWidth: 10,
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: Image.asset(
                                        'assets/wiser_graphics_icon_tdcs.png',
                                        fit: BoxFit.contain),
                                  ),
                                  title: Column(
                                    children: [
                                      Row(children: [
                                        Text(
                                            logHeaderList[index]
                                                .platCurr
                                                .toString() +
                                                " uA",
                                            style: new TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                FontWeight.bold)),
                                      ]),
                                      Row(children: [
                                        Text(
                                            "Ramp-up: " +
                                                logHeaderList[index]
                                                    .rampUp
                                                    .toString() +
                                                " uA/S" +
                                                " | Ramp-down: " +
                                                logHeaderList[index]
                                                    .rampDown
                                                    .toString() +
                                                " uA/S",
                                            style: new TextStyle(
                                                fontSize: 14)),
                                      ]),
                                      Row(children: [
                                        Text(
                                            "Session ID: " +
                                                logHeaderList[index]
                                                    .sessionID
                                                    .toString(),
                                            style: new TextStyle(
                                                fontSize: 12)),
                                      ]),
                                      Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.end,
                                          children: [
                                            Text(
                                                _getFormattedDate(
                                                    logHeaderList[index]
                                                        .tmYear,
                                                    logHeaderList[index]
                                                        .tmMon,
                                                    logHeaderList[index]
                                                        .tmMday,
                                                    logHeaderList[index]
                                                        .tmHour,
                                                    logHeaderList[index]
                                                        .tmMin,
                                                    logHeaderList[index]
                                                        .tmSec),
                                                style: new TextStyle(
                                                    fontSize: 12)),
                                          ]),
                                      Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.end,
                                          children: [
                                            isTransfering
                                                ? Container()
                                                : IconButton(
                                              onPressed:
                                                  () async {
                                                setState(() {
                                                  isFetchIconTap =
                                                  true;
                                                  tappedIndex =
                                                      index;
                                                });

                                               /* await _fetchLogFile(
                                                    widget
                                                        .currentDevice
                                                        .id,
                                                    logHeaderList[
                                                    index]
                                                        .logFileID,
                                                    logHeaderList[
                                                    index]
                                                        .sessionLength);*/
                                              },
                                              icon: Icon(Icons
                                                  .download_rounded),
                                              color: hPi4Global
                                                  .hpi4Color,
                                            ),
                                            isTransfering
                                                ? Container()
                                                : IconButton(
                                              onPressed:
                                                  () async {
                                                /*_deleteLogIndex(
                                                    widget
                                                        .currentDevice
                                                        .id,
                                                    logHeaderList[
                                                    index]
                                                        .logFileID,
                                                    context);*/
                                              },
                                              icon: Icon(
                                                  Icons.delete),
                                              color: hPi4Global
                                                  .hpi4Color,
                                            ),
                                          ]),
                                      isFetchIconTap
                                          ? Visibility(
                                        visible:
                                        tappedIndex == index,
                                        child: Row(
                                          children: [
                                            Padding(
                                              padding:
                                              EdgeInsets.all(
                                                  8.0),
                                              child: SizedBox(
                                                width: 150,
                                                child:
                                                LinearProgressIndicator(
                                                  backgroundColor:
                                                  Colors.blueGrey[
                                                  100],
                                                  //color: Colors.blue,
                                                  value:
                                                  (displayPercent /
                                                      100),
                                                  minHeight: 25,
                                                  semanticsLabel:
                                                  'Receiving Data',
                                                ),
                                              ),
                                            ),
                                            Text(displayPercent
                                                .truncate()
                                                .toString() +
                                                " %"),
                                          ],
                                        ),
                                      )
                                          : Container(),
                                    ],
                                  ),
                                )))
                            : Container();
                      }),
                ],
              ),
            ),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: hPi4Global.appBackgroundColor,
        //key: _scaffoldKey,
        appBar: AppBar(
          //backgroundColor: PatchGlobal.patchWebAppBarSecondaryColor,
          backgroundColor: hPi4Global.hpi4Color,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Image.asset('assets/proto-online-white.png',
                  fit: BoxFit.fitWidth, height: 30),
            ],
          ),
        ),
        body: Center(child: Consumer2<ConnectionStateUpdate, BleScannerState>(
            builder: (context, connStateUpdates, bleScannerState, child) {
              return SingleChildScrollView(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _getDeviceCard(),
                        _getSessionIDList(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: MaterialButton(
                                      onPressed: () async {
                                        await cancelAction();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              Icons.cancel,
                                              color: Colors.white,
                                            ),
                                            const Text(
                                              ' Disconnect & Close ',
                                              style: TextStyle(
                                                  fontSize: 16, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ]));
            })));
  }
}