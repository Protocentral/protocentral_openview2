import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

import 'plots.dart';
import 'globals.dart';
import 'utils/variables.dart';
import 'ble/ble_scanner.dart';

class FetchLogs extends StatefulWidget {
  FetchLogs({
    Key? key,
    required this.selectedBoard,
    required this.selectedDevice,
    required this.currentDevice,
    required this.fble,
    required this.currConnection,
  }) : super();

  final String selectedBoard;
  final String selectedDevice;
  final DiscoveredDevice currentDevice;
  final FlutterReactiveBle fble;
  final StreamSubscription<ConnectionStateUpdate> currConnection;

  @override
  _FetchLogsState createState() => _FetchLogsState();
}

class _FetchLogsState extends State<FetchLogs> {
  late Stream<List<int>> streamCommand;
  late Stream<List<int>> streamData;

  late StreamSubscription streamCommandSubscription;
  late StreamSubscription streamDataSubscription;

  late QualifiedCharacteristic commandTxCharacteristic;
  late QualifiedCharacteristic dataCharacteristic;

  double displayPercent = 0;
  double globalDisplayPercentOffset = 0;

  List<int> logData = [];

  int globalReceivedData = 0;
  int globalExpectedLength = 1;
  int tappedIndex = 0;
  int totalSessionCount = 0;
  int currentFileDataCounter = 0;
  int checkNoOfWrites = 0;

  StringBuffer buffer = StringBuffer();
  String result = '';

  bool listeningDataStream = false;
  bool listeningUploadStream = false;
  bool listeningConnectionStream = false;
  bool listeningCommandStream = false;
  bool currentFileReceivedComplete = false;

  final _scrollController = ScrollController();

  @override
  void initState() {
    dataCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_DATA),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: widget.currentDevice.id);

    commandTxCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: widget.currentDevice.id);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await fetchLogCount(widget.currentDevice.id, context);
      await fetchLogIndex(widget.currentDevice.id, context);
    });

    super.initState();
  }

  @override
  void dispose() async {
    await closeAllStreams();
    super.dispose();
  }

  Future<void> closeAllStreams() async {
    if (listeningCommandStream) {
      streamCommandSubscription.cancel();
    }
    if (listeningDataStream) {
      streamDataSubscription.cancel();
    }
  }

  bool flagFetching = false;
  bool diasbleButtonsWFetching = false;

  List<LogHeader> logHeaderList = List.empty(growable: true);

  Future<void> startListeningCommand(String deviceID) async {
    listeningCommandStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      streamCommand =
          widget.fble.subscribeToCharacteristic(commandTxCharacteristic);
    });

    streamCommandSubscription = streamCommand.listen((value) async {
      print("CMD Stream: " + value.length.toString());
    });
  }

  bool isTransfering = false;
  bool isFetchIconTap = false;

  void logConsole(String logString) async {
    print("AKW - " + logString);
    debugText += logString;
    debugText += "\n";
  }

  int logIndexNumElements = 0;
  static const int WISER_FILE_HEADER_LEN = 10;

  Future<void> showDownloadSuccessDialog() async {
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
              onPressed: () async {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => WaveFormsPage(
                            selectedBoard: widget.selectedBoard,
                            selectedDevice: widget.selectedDevice,
                            currentDevice: widget.currentDevice,
                            fble: widget.fble,
                            currConnection: widget.currConnection,
                          )),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> writeLogDataToFile(List<int> fileData, int sessionID, int fileNum) async {
      Directory _directory = Directory("");
      String fileUTF8Data = " ";
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

      File file = File('$directory/logdata$sessionID'+'_$fileNum'+'.txt');

      print("Save file");

      await file.writeAsString(utf8.decode(fileData), flush: true);

    print("File exported successfully!");

    await showDownloadSuccessDialog();
  }

  bool logIndexReceived = false;

  Future<void> startListeningData(String deviceID, int sessionID, int sessionSize, int fileNum) async {
    listeningDataStream = true;
    await Future.delayed(Duration(seconds: 1), () async {
      streamData = widget.fble.subscribeToCharacteristic(dataCharacteristic);
    });

    streamDataSubscription = streamData.listen((value) async {
      ByteData bdata = Int8List.fromList(value).buffer.asByteData();
      // print("Data Rx: " + value.toString());
      int _pktType = bdata.getUint8(0);

      if (_pktType == hPi4Global.CES_CMDIF_TYPE_CMD_RSP) {
        int _cmdType = bdata.getUint8(1);
        if (_cmdType == 84) {
          setState(() {
            totalSessionCount = bdata.getUint8(2);
          });

          await streamCommandSubscription.cancel();
          await streamDataSubscription.cancel();
        } else {}
      } else if (_pktType == hPi4Global.CES_CMDIF_TYPE_LOG_IDX) {
        print("Data Rx: " + value.toString());

        LogHeader _mLog = (
          logFileID: bdata.getUint32(1, Endian.little),
          sessionLength: bdata.getUint32(5, Endian.little),
          fileNo: bdata.getUint8(9),
          tmYear: bdata.getUint8(10),
          tmMon: bdata.getUint8(11),
          tmMday: bdata.getUint8(12),
          tmHour: bdata.getUint8(13),
          tmMin: bdata.getUint8(14),
          tmSec: bdata.getUint8(15),
        );

        //print("Log: " + _mLog.toString());
        logHeaderList.add(_mLog);

        if (logHeaderList.length == totalSessionCount) {
          setState(() {
            logIndexReceived = true;
          });

          print("All logs received. Cancel subscription");

          await streamCommandSubscription.cancel();
          await streamDataSubscription.cancel();
        }
      } else if (_pktType == hPi4Global.CES_CMDIF_TYPE_DATA) {
        int pktPayloadSize = value.length - 1; //((value[1] << 8) + value[2]);
        setState(() {
          flagFetching = true;
        });

        logConsole("Data execpted length: " + sessionSize.toString());
        logConsole("Data Rx length: " +value.length.toString() +" | Actual Payload: " +pktPayloadSize.toString());

        currentFileDataCounter += pktPayloadSize;
        globalReceivedData += pktPayloadSize;
        checkNoOfWrites += 1;

        logConsole("no of writes: " + checkNoOfWrites.toString());

         logData.addAll(value.sublist(1, value.length));

        //logConsole("data received: " +logData.toString());

        setState(() {
          displayPercent = globalDisplayPercentOffset +
              (globalReceivedData / globalExpectedLength) * 100.truncate();
          if (displayPercent > 100) {
            displayPercent = 100;
          }
        });

        /*logConsole("File data counter: " +
            currentFileDataCounter.toString() +
            " | Received: " +
            displayPercent.toString() +
            "%");*/

        if (currentFileDataCounter >= (sessionSize)) {
          //logConsole("All data " + currentFileDataCounter.toString() + " received");

          if (currentFileDataCounter > sessionSize) {
            int diffData = currentFileDataCounter - sessionSize;
            /*logConsole("Data received more than expected by: " +
                diffData.toString() +
                " bytes");*/
            //logData.removeRange(expectedLength, currentFileDataCounter);
          }

          await streamCommandSubscription.cancel();
          await streamDataSubscription.cancel();

          await writeLogDataToFile(logData, sessionID, fileNum);

          setState(() {
            flagFetching = false;
            isTransfering = false;
            isFetchIconTap = false;
            diasbleButtonsWFetching = false;
          });

          // Reset all fetch variables
          displayPercent = 0;
          globalDisplayPercentOffset = 0;
          currentFileDataCounter = 0;
          globalReceivedData = 0;
          currentFileReceivedComplete = false;
          logData.clear();
        }
      }
    });
  }

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

  String debugText = "Console Inited...";

  Future<void> fetchLogCount(String deviceID, BuildContext context) async {
    logConsole("Fetch log count initiated");
    showLoadingIndicator("Fetching logs count...", context);
    await startListeningCommand(deviceID);
    await startListeningData(deviceID, 0, 0, 0);
    await Future.delayed(Duration(seconds: 2), () async {
      await sendCommand(hPi4Global.getSessionCount, deviceID);
    });
    Navigator.pop(context);
  }

  Future<void> fetchLogIndex(String deviceID, BuildContext context) async {
    logConsole("Fetch logs initiated");
    showLoadingIndicator("Fetching logs...", context);
    await startListeningCommand(deviceID);
    await startListeningData(deviceID, 0, 0, 0);
    await Future.delayed(Duration(seconds: 2), () async {
      await sendCommand(hPi4Global.sessionLogIndex, deviceID);
      //await _sendCommand(hPi4Global.getSessionCount, deviceID);
    });
    Navigator.pop(context);
    logHeaderList.clear();
  }

  Future<void> deleteLogIndex(
      String deviceID, int sessionID, int fileNum, BuildContext context) async {
    logConsole("Deleted logs initiated");
    showLoadingIndicator("Deleting log...", context);
    await Future.delayed(Duration(seconds: 2), () async {
      List<int> commandFetchLogFile = List.empty(growable: true);
      commandFetchLogFile.addAll(hPi4Global.sessionLogDelete);
      commandFetchLogFile.add((sessionID >> 8) & 0xFF);
      commandFetchLogFile.add(sessionID & 0xFF);
      await sendCommand(commandFetchLogFile, deviceID);
    });
    Navigator.pop(context);
    await fetchLogCount(widget.currentDevice.id, context);
    await fetchLogIndex(widget.currentDevice.id, context);
  }

  Future<void> deleteAllLog(String deviceID, BuildContext context) async {
    logConsole("Deleted logs initiated");
    showLoadingIndicator("Deleting all log...", context);
    await Future.delayed(Duration(seconds: 2), () async {
      List<int> commandFetchAllLog = List.empty(growable: true);
      commandFetchAllLog.addAll(hPi4Global.sessionLogWipeAll);
      await sendCommand(commandFetchAllLog, deviceID);
    });
    Navigator.pop(context);
    await fetchLogCount(widget.currentDevice.id, context);
    await fetchLogIndex(widget.currentDevice.id, context);
  }

  Future<void> fetchLogFile(
      String deviceID, int sessionID, int sessionSize, int fileNum) async {
    logConsole("Fetch logs initiated");
    isTransfering = true;
    await startListeningCommand(deviceID);
    // Session size is in bytes, so multiply by 6 to get the number of data points, add header size
    await startListeningData(deviceID, sessionID, (sessionSize), fileNum);

    // Reset all fetch variables
    globalExpectedLength = sessionSize;
    logData.clear();

    await Future.delayed(Duration(seconds: 2), () async {
      List<int> commandFetchLogFile = List.empty(growable: true);
      commandFetchLogFile.addAll(hPi4Global.sessionFetchLogFile);
      commandFetchLogFile.add((sessionID >> 8) & 0xFF);
      commandFetchLogFile.add(sessionID & 0xFF);
      commandFetchLogFile.add(fileNum);
      await sendCommand(commandFetchLogFile, deviceID);
    });
  }

  Future<void> sendCommand(List<int> commandList, String deviceID) async {
    logConsole(
        "Tx CMD " + commandList.toString() + " 0x" + hex.encode(commandList));

    await widget.fble.writeCharacteristicWithoutResponse(
        commandTxCharacteristic,
        value: commandList);
  }

  Future<void> cancelAction() async {
    if (listeningCommandStream) {
      streamCommandSubscription.cancel();
    }
    if (listeningDataStream) {
      streamDataSubscription.cancel();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => WaveFormsPage(
                selectedBoard: widget.selectedBoard,
                selectedDevice: widget.selectedDevice,
                currentDevice: widget.currentDevice,
                fble: widget.fble,
                currConnection: widget.currConnection,
              )),
    );
  }

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

  String _getFileName(int sessionID, int extension) {
    String ConExtension = "";
    if(extension == 1){
      ConExtension = "_ECG";
    }else if(extension == 2){
      ConExtension = "_PPG";
    }else if(extension == 3){
      ConExtension = "_RESP";
    }else{
      ConExtension = " ";
    }
    String formattedFileName = sessionID.toString() + ConExtension;

    return formattedFileName;
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
                                          title: Column(
                                            children: [
                                              Row(children: [
                                                /*Text(
                                                    "Session ID: " +
                                                        logHeaderList[index].logFileID.toString(),
                                                    style: new TextStyle(
                                                        fontSize: 12)),*/
                                                Text(_getFileName(
                                                        logHeaderList[index]
                                                            .logFileID,
                                                        logHeaderList[index].fileNo),
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
                                                                diasbleButtonsWFetching =
                                                                    true;
                                                                isFetchIconTap =
                                                                    true;
                                                                tappedIndex =
                                                                    index;
                                                              });

                                                              await fetchLogFile(
                                                                widget
                                                                    .currentDevice
                                                                    .id,
                                                                logHeaderList[
                                                                        index]
                                                                    .logFileID,
                                                                logHeaderList[
                                                                        index]
                                                                    .sessionLength,
                                                                logHeaderList[
                                                                index]
                                                                    .fileNo,
                                                              );
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
                                                              deleteLogIndex(
                                                                  widget
                                                                      .currentDevice
                                                                      .id,
                                                                  logHeaderList[
                                                                          index]
                                                                      .logFileID,
                                                                  logHeaderList[
                                                                  index]
                                                                      .fileNo,
                                                                  context);
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

  Widget GetData() {
    if (diasbleButtonsWFetching == false) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: MaterialButton(
          minWidth: 80.0,
          color: hPi4Global.hpi4Color,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              Text('Refresh',
                  style: new TextStyle(fontSize: 16.0, color: Colors.white)),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          onPressed: () async {
            // _sendEndLogtoFlashCommand();
            await fetchLogCount(widget.currentDevice.id, context);
            await fetchLogIndex(widget.currentDevice.id, context);
          },
        ),
      );
    } else {
      return Container();
    }
  }

  Widget DeleteAllData() {
    if (diasbleButtonsWFetching == false) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: MaterialButton(
          minWidth: 80.0,
          color: Colors.red,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.delete,
                color: Colors.white,
              ),
              Text('Delete all',
                  style: new TextStyle(fontSize: 16.0, color: Colors.white)),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          onPressed: () async {
            deleteAllLog(widget.currentDevice.id, context);
          },
        ),
      );
    } else {
      return Container();
    }
  }

  Widget CloseButton() {
    if (flagFetching == false) {
      return Padding(
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
                  'Close ',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          color: Colors.red,
        ),
      );
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: hPi4Global.appBackgroundColor,
        //key: _scaffoldKey,
        appBar: AppBar(
          //backgroundColor: PatchGlobal.patchWebAppBarSecondaryColor,
          backgroundColor: hPi4Global.hpi4Color,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Row(children: <Widget>[
                Image.asset('assets/proto-online-white.png',
                    fit: BoxFit.fitWidth, height: 30),
                // GetData(),
              ]),
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
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GetData(),
                          DeleteAllData(),
                        ],
                      ),
                    ],
                  ),
                ),
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
                          CloseButton(),
                        ],
                      ),
                    ],
                  ),
                ),
              ]));
        })));
  }
}
