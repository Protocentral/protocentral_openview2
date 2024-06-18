import 'dart:ffi';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'globals.dart';
import 'home.dart';
import 'sizeConfig.dart';

import 'ble/ble_scanner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'states/OpenViewBLEProvider.dart';
import 'dart:async';
import 'dart:io';
import 'onBoardDataLog.dart';


import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
//import 'package:mcumgr_flutter/mcumgr_flutter.dart';

class WaveFormsPage extends StatefulWidget {
  WaveFormsPage({Key? key,
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
  _WaveFormsPageState createState() => _WaveFormsPageState();
}

class _WaveFormsPageState extends State<WaveFormsPage> {
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  Key key = UniqueKey();

  final ecgLineData = <FlSpot>[];
  final ppgLineData = <FlSpot>[];
  final respLineData = <FlSpot>[];

  List<double> ecgDataLog = [];
  List<double> ppgDataLog = [];
  List<double> respDataLog = [];

  double ecgDataCounter = 0;
  double ppgDataCounter = 0;
  double respDataCounter = 0;

  late QualifiedCharacteristic CommandCharacteristic;
  late QualifiedCharacteristic ECGCharacteristic;
  late QualifiedCharacteristic PPGCharacteristic;
  late QualifiedCharacteristic RESPCharacteristic;
  late QualifiedCharacteristic BatteryCharacteristic;
  late QualifiedCharacteristic HRCharacteristic;
  late QualifiedCharacteristic SPO2Characteristic;
  late QualifiedCharacteristic TempCharacteristic;
  late QualifiedCharacteristic HRVRespCharacteristic;

  late StreamSubscription streamBatterySubscription;
  late StreamSubscription streamHRSubscription;
  late StreamSubscription streamSPO2Subscription;
  late StreamSubscription streamHRVRespSubscription;
  late StreamSubscription streamTempSubscription;
  late StreamSubscription streamECGSubscription;
  late StreamSubscription streamPPGSubscription;
  late StreamSubscription streamRESPSubscription;

  late Stream<List<int>> _streamECG;
  late Stream<List<int>> _streamPPG;
  late Stream<List<int>> _streamRESP;
  late Stream<List<int>> _streamBattery;
  late Stream<List<int>> _streamHR;
  late Stream<List<int>> _streamSPO2;
  late Stream<List<int>> _streamTemp;
  late Stream<List<int>> _streamHRVResp;

  bool listeningECGStream = false;
  bool listeningPPGStream = false;
  bool listeningRESPStream = false;
  bool listeningBatteryStream = false;
  bool listeningHRStream = false;
  bool listeningSPO2Stream = false;
  bool listeningTempStream = false;
  bool listeningHRVRespStream = false;

  bool startAppLogging = false;
  bool startFlashLogging = false;
  bool startStreaming = false;

  int globalHeartRate = 0;
  int globalSpO2 = 0;
  int globalRespRate = 0;
  double globalTemp = 0;
  int _globalBatteryLevel = 50;

  String displaySpO2 = "--" ;

  late Stream<List<int>> _streamCommand;
  late Stream<List<int>> _streamData;

  late StreamSubscription _streamCommandSubscription;
  late StreamSubscription _streamDataSubscription;

  late QualifiedCharacteristic commandTxCharacteristic;
  late QualifiedCharacteristic dataCharacteristic;

  bool listeningDataStream = false;
  bool listeningUploadStream = false;
  bool listeningConnectionStream = false;
  bool _listeningCommandStream = false;

 /* final managerFactory: UpdateManagerFactory = FirmwareUpdateManagerFactory()
// `deviceId` is a String with the device's MAC address (on Android) or UUID (on iOS)
  final updateManager = await managerFactory.getUpdateManager(deviceId);
// call `setup` before using the manager
  final updateStream = updateManager.setup();*/

  void logConsole(String logString) {
    print("AKW - " + logString);
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      subscribeToCharacteristics();
     // dataFormatBasedOnBoards();

    });
  }

  @override
  dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    ecgLineData.clear();
    ppgLineData.clear();
    respLineData.clear();

    super.dispose();
  }

  void subscribeToCharacteristics(){
    ECGCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_ECG_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_ECG_SERVICE),
        deviceId: widget.currentDevice.id);

    RESPCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_RESP_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_ECG_SERVICE),
        deviceId: widget.currentDevice.id);

    PPGCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HIST),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HRV),
        deviceId: widget.currentDevice.id);

    BatteryCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_BATT),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_BATT),
        deviceId: widget.currentDevice.id);

    HRCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HR),
        deviceId: widget.currentDevice.id);

    SPO2Characteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_SPO2_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_SPO2),
        deviceId: widget.currentDevice.id);

    TempCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_TEMP_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HEALTH_THERM),
        deviceId: widget.currentDevice.id);

    HRVRespCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HRV),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HRV),
        deviceId: widget.currentDevice.id);

    CommandCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERVICE_CMD),
        deviceId: widget.currentDevice.id);

    dataCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_DATA),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: widget.currentDevice.id);

    commandTxCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: widget.currentDevice.id);

  }

  void dataFormatBasedOnBoards() async {
    if (widget.selectedBoard == 'ADS1292R Breakout/Shield') {
      _startECG16Listening();
      _startRESP16Listening();
      await _startListeningHR();
      await _startListeningHRVResp();
    } else if (widget.selectedBoard == 'ADS1293 Breakout/Shield') {
      _startECG32Listening();
      _startPPG16Listening();
      _startRESP32Listening();
    } else if (widget.selectedBoard == 'AFE4490 Breakout/Shield') {
      _startPPG32Listening();
      await _startListeningHR();
      await _startListeningSPO2();
    } else if (widget.selectedBoard == 'MAX86150 Breakout') {
      _startECG16Listening();
      _startPPG16Listening();
    } else if (widget.selectedBoard == 'Pulse Express') {
      _startECG32Listening();
      _startRESP32Listening();
    } else if (widget.selectedBoard == 'tinyGSR Breakout') {
      _startECG16Listening();
    } else if (widget.selectedBoard == 'MAX30003 ECG Breakout') {
      _startECG32Listening();
      await _startListeningHR();
      await _startListeningHRVResp();
    } else if (widget.selectedBoard == 'MAX30001 ECG & BioZ Breakout') {
      _startECG32Listening();
      _startRESP32Listening();
    } else {
      _startECG32Listening();
      _startPPG16Listening();
      _startRESP32Listening();
      await _startListeningHR();
      await _startListeningSPO2();
      await _startListeningHRVResp();
      await _startListeningTemp();
    }
  }

  void closeAllStreams() async {
    if (listeningECGStream == true) {
      await streamECGSubscription.cancel();
    }

    if (listeningPPGStream == true) {
      await streamPPGSubscription.cancel();
    }

    if (listeningRESPStream == true) {
      await streamRESPSubscription.cancel();
    }

    if (listeningHRVRespStream == true) {
      await streamHRVRespSubscription.cancel();
    }

    if (listeningBatteryStream == true) {
      await streamBatterySubscription.cancel();
    }

    if (listeningHRStream == true) {
      await streamHRSubscription.cancel();
    }

    if (listeningSPO2Stream == true) {
      await streamSPO2Subscription.cancel();
    }

    if (listeningTempStream == true) {
      await streamTempSubscription.cancel();
    }

    if (_listeningCommandStream) {
      _streamCommandSubscription.cancel();
    }

    if (listeningDataStream) {
      _streamDataSubscription.cancel();
    }
  }

  Future<void> _startListeningHR() async {
    print("AKW: Started listening to HR stream");
    listeningHRStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamHR = await widget.fble.subscribeToCharacteristic(HRCharacteristic);
    });

    streamHRSubscription = _streamHR.listen((event) {
      //print("AKW: Rx Heart Rate: " + event.toString());
      setStateIfMounted(() {
        globalHeartRate = event[1];
        // print("AKW: Rx Heart Rate: " + event[1].toString());
      });
    });
  }

  Future<void> _startListeningSPO2() async {
    print("AKW: Started listening to SPO2 stream");
    listeningSPO2Stream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamSPO2 = await widget.fble.subscribeToCharacteristic(SPO2Characteristic);
    });

    streamSPO2Subscription = _streamSPO2.listen((event) {
      //print("AKW: Rx SPO2: " + event.toString());
      setStateIfMounted(() {
        globalSpO2 = event[1];
        if(globalSpO2 == 25){
          displaySpO2 = "--";
        }else{
          displaySpO2 = globalSpO2.toString() +" %";
        }
        //print("AKW: Rx SPO2: " + event[1].toString());
      });
    });
  }

  Future<void> _startListeningTemp() async {
    print("AKW: Started listening to Temp stream");
    listeningTempStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamTemp = (await widget.fble.subscribeToCharacteristic(TempCharacteristic));
    });

    streamTempSubscription = _streamTemp.listen((event) {
      //print("AKW: Rx Temperature: " + event.toString());
      setStateIfMounted(() {
        //globalTemp = event[0];
        Uint8List u8list = Uint8List.fromList(event);
        globalTemp = ((toInt16(u8list, 0).toDouble()) * 0.01);
      });
    });
  }

  int toInt16(Uint8List byteArray, int index) {
    ByteBuffer buffer = byteArray.buffer;
    ByteData data = new ByteData.view(buffer);
    int short = data.getInt16(index, Endian.little);
    return short;
  }

  Future<void> _startListeningHRVResp() async {
    print("AKW: Started listening to HRVResp stream");
    listeningHRVRespStream = true;

    await Future.delayed(Duration(seconds: 4), () async {
      _streamHRVResp =
          await widget.fble.subscribeToCharacteristic(HRVRespCharacteristic);
    });

    streamHRVRespSubscription = _streamHRVResp.listen((event) {
      //print("AKW: Rx Respiration Rate: " + event.toString());
      setStateIfMounted(() {
        globalRespRate = event[0];
        //print("AKW: Rx Respiration Rate: " + event[10].toString());
      });
    });
  }

  void _startECG16Listening() async {
    print("AKW: Started listening to stream");
    listeningECGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamECG = await widget.fble.subscribeToCharacteristic(ECGCharacteristic);
    });

    streamECGSubscription = _streamECG.listen(
      (event) {
        ByteData ecgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int16List ecgList = ecgByteData.buffer.asInt16List();

        ecgList.forEach((element) {
          setStateIfMounted(() {
            ecgLineData.add(FlSpot(ecgDataCounter++, (element.toDouble())));
            if(startAppLogging == true){
              ecgDataLog.add(element.toDouble());
            }
          });

          if (ecgDataCounter >= 128 * 6) {
            ecgLineData.removeAt(0);
          }
        });
      },
      onError: (Object error) {
        // Handle a possible error
        print("Error while monitoring data characteristic \n$error");
      },
      cancelOnError: true,
    );
  }

  void _startECG32Listening() async {
    print("AKW: Started listening to stream");
    listeningECGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamECG = await widget.fble.subscribeToCharacteristic(ECGCharacteristic);
    });

    streamECGSubscription = _streamECG.listen(
      (event) {
        //print("AKW: Rx ECG: " + event.length.toString());
        ByteData ecgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        //Int16List ecgList = ecgByteData.buffer.asInt16List();
        Int32List ecgList = ecgByteData.buffer.asInt32List();

        ecgList.forEach((element) {
          setStateIfMounted(() {
            ecgLineData.add(FlSpot(ecgDataCounter++, (element.toDouble())));
            if(startAppLogging == true){
              ecgDataLog.add(element.toDouble());
            }
          });

          if (ecgDataCounter >= 128 * 6) {
            ecgLineData.removeAt(0);
          }
        });
      },
      onError: (Object error) {
        // Handle a possible error
        print("Error while monitoring data characteristic \n$error");
      },
      cancelOnError: true,
    );
  }

  void _startPPG16Listening() async {
    print("AKW: Started listening to ppg stream");
    listeningPPGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamPPG = await widget.fble.subscribeToCharacteristic(PPGCharacteristic);
    });

    streamPPGSubscription = _streamPPG.listen(
      (event) {
        // print("AKW: Rx PPG: " + event.length.toString());
        ByteData ppgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int16List ppgList = ppgByteData.buffer.asInt16List();

        ppgList.forEach((element) {
          setStateIfMounted(() {
            ppgLineData.add(FlSpot(ppgDataCounter++, (element.toDouble())));
            if(startAppLogging == true){
              ppgDataLog.add(element.toDouble());
            }
          });

          if (ppgDataCounter >= 128 * 3) {
            ppgLineData.removeAt(0);
          }
        });
      },
      onError: (Object error) {
        // Handle a possible error
        print("Error while monitoring data characteristic \n$error");
      },
      cancelOnError: true,
    );
  }

  void _startPPG32Listening() async {
    print("AKW: Started listening to ppg stream");
    listeningPPGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamPPG = await widget.fble.subscribeToCharacteristic(PPGCharacteristic);
    });

    streamPPGSubscription = _streamPPG.listen(
      (event) {
        // print("AKW: Rx PPG: " + event.length.toString());
        ByteData ppgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int32List ppgList = ppgByteData.buffer.asInt32List();

        ppgList.forEach((element) {
          setStateIfMounted(() {
            ppgLineData.add(FlSpot(ppgDataCounter++, (element.toDouble())));
            if(startAppLogging == true){
              ppgDataLog.add(element.toDouble());
            }
          });

          if (ppgDataCounter >= 128 * 6) {
            ppgLineData.removeAt(0);
          }
        });
      },
      onError: (Object error) {
        // Handle a possible error
        print("Error while monitoring data characteristic \n$error");
      },
      cancelOnError: true,
    );
  }

  void _startRESP16Listening() async {
    print("AKW: Started listening to respiration stream");
    listeningRESPStream = true;
    int i = 0;
    await Future.delayed(Duration(seconds: 1), () async {
      _streamRESP = await widget.fble.subscribeToCharacteristic(RESPCharacteristic);
    });

    streamRESPSubscription = _streamRESP.listen(
      (event) {
        ByteData respByteData =
            Uint8List.fromList(event).buffer.asByteData(0);
        Int16List respList = respByteData.buffer.asInt16List();
        respList.forEach((element) {
          setStateIfMounted(() {
            respLineData.add(FlSpot(respDataCounter++, (element.toDouble())));
            if(startAppLogging == true){
              respDataLog.add(element.toDouble());
            }
          });

          if (respDataCounter >= 256 * 6) {
            respLineData.removeAt(0);
          }
        });
      },
      onError: (Object error) {
        // Handle a possible error
        print("Error while monitoring data characteristic \n$error");
      },
      cancelOnError: true,
    );
  }

  void _startRESP32Listening() async {
    print("AKW: Started listening to respiration stream");
    listeningRESPStream = true;
    int i = 0;
    await Future.delayed(Duration(seconds: 1), () async {
      _streamRESP = await widget.fble.subscribeToCharacteristic(RESPCharacteristic);
    });

    streamRESPSubscription = _streamRESP.listen(
      (event) {
        //print("AKW: Rx RESP: " + event.length.toString());

        ByteData respByteData =
            Uint8List.fromList(event).buffer.asByteData(0);
        Int32List respList = respByteData.buffer.asInt32List();
        //print("AKW: Rx RESP: " + event.toString());
        //print("AKW: Rx RESP1: " + respList.toString());
        respList.forEach((element) {
          setStateIfMounted(() {
            respLineData.add(FlSpot(respDataCounter++, (element.toDouble())));
            if(startAppLogging == true){
              respDataLog.add(element.toDouble());
            }
          });

          if (respDataCounter >= 256 * 6) {
            respLineData.removeAt(0);
          }
        });
      },
      onError: (Object error) {
        // Handle a possible error
        print("Error while monitoring data characteristic \n$error");
      },
      cancelOnError: true,
    );
  }

  LineChartBarData currentLine(List<FlSpot> points, Color plotcolor) {
    return LineChartBarData(
      spots: points,
      dotData: FlDotData(
        show: false,
      ),
      gradient: LinearGradient(
        colors: [plotcolor, plotcolor],
        //stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  buildChart(int vertical, int horizontal, List<FlSpot> source, Color plotColor){
    return Container(
      height: SizeConfig.blockSizeVertical * vertical,
      width: SizeConfig.blockSizeHorizontal * horizontal,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(enabled: false),
          clipData: FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            drawHorizontalLine: false,
          ),
          borderData: FlBorderData(
            show: false,
            //border: Border.all(color: const Color(0xff37434d)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            currentLine(source,plotColor),
          ],
        ),
        swapAnimationDuration: Duration.zero,
      ),
    );
  }

  Widget displayHealthyPiCharts() {
    if(widget.selectedBoard == "Healthypi"){
      return Column(
        children: [
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 2,
                    child: Text(
                      "HEART RATE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 3.5,
                    child: Text( globalHeartRate.toString() + " bpm",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(17, 95, ecgLineData, Colors.green),
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 2,
                    child: Text(
                      "SPO2 ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 3.5,
                    child:  Text(displaySpO2,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(17, 95, ppgLineData, Colors.yellow),
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 2,
                    child: Text(
                      "RESPIRATION RATE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 3.5,
                    child: Text( globalRespRate.toString() + " rpm",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(16, 95, respLineData, Colors.blue),
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 2,
                    child: Text(
                      "TEMPERATURE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    height: SizeConfig.blockSizeVertical * 3.5,
                    child: Text( globalTemp.toStringAsPrecision(3) + "\u00b0 C",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
        ],
      );
    }
    else if(widget.selectedBoard == "ADS1292R Breakout/Shield"){
      return Column(
        children: [
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      "HEART RATE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text( globalHeartRate.toString() + " bpm",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(25, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      "RESPIRATION RATE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text( globalRespRate.toString() + " rpm",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(25, 95, respLineData, Colors.blue),
        ],
      );
    }
    else if(widget.selectedBoard == "ADS1293 Breakout/Shield"){
      return Column(
        children: [
          buildChart(15, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 2,
          ),
          buildChart(15, 95, ppgLineData, Colors.yellow),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 2,
          ),
          buildChart(15, 95, respLineData, Colors.blue),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 2,
          ),
        ],
      );
    }
    else if(widget.selectedBoard == "AFE4490 Breakout/Shield"){
      return Column(
        children: [
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      "HEART RATE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text( globalHeartRate.toString() + " bpm",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(50, 95, ppgLineData, Colors.yellow),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      "SPO2 ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child:  Text(displaySpO2,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
        ],
      );
    }
    else if(widget.selectedBoard == "MAX86150 Breakout"){
      return Column(
        children: [
          buildChart(15, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 2,
          ),
          buildChart(15, 95, ppgLineData, Colors.yellow),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 2,
          ),
          buildChart(15, 95, respLineData, Colors.blue),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 2,
          ),
        ],
      );
    }
    else if(widget.selectedBoard == "Pulse Express"){
      return Column(
        children: [
          buildChart(27, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
          buildChart(27, 95, respLineData, Colors.blue),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
        ],
      );
    }
    else if(widget.selectedBoard == "tinyGSR Breakout"){
      return Column(
        children: [
          buildChart(54, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
        ],
      );
    }
    else if(widget.selectedBoard == "MAX30003 ECG Breakout"){
      return Column(
        children: [
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      "HEART RATE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text( globalHeartRate.toString() + " bpm",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(50, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      "RESPIRATION RATE ",
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text( globalRespRate.toString() + " rpm",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
        ],
      );
    }
    else if(widget.selectedBoard == "MAX30001 ECG & BioZ Breakout"){
      return Column(
        children: [
          buildChart(27, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
          buildChart(27, 95, ppgLineData, Colors.blue),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
        ],
      );
    }
    else{
      return Container();
    }
  }

  Widget displayHealthyPiMoveCharts(){
    return Column(
      children: [
        Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 2,
                  child: Text(
                    "HEART RATE ",
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 3.5,
                  child: Text( globalHeartRate.toString() + " bpm",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ]
        ),
        buildChart(17, 70, ecgLineData, Colors.green),
        Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 2,
                  child: Text(
                    "SPO2 ",
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 3.5,
                  child:  Text(displaySpO2,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ]
        ),
        buildChart(17, 70, ppgLineData, Colors.yellow),
        Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 2,
                  child: Text(
                    "RESPIRATION RATE ",
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 3.5,
                  child: Text( globalRespRate.toString() + " rpm",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ]
        ),
        buildChart(16, 70, respLineData, Colors.blue),
        Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 2,
                  child: Text(
                    "TEMPERATURE ",
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: Colors.transparent,
                  height: SizeConfig.blockSizeVertical * 3.5,
                  child: Text( globalTemp.toStringAsPrecision(3) + "\u00b0 C",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ]
        ),

      ],
    );
  }

  Widget displayDeviceName() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
              children: [
                Text(
                  "Connected: " + widget.selectedDevice + " ( " + widget.currentDevice.id +" )",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Board: " + widget.selectedBoard,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ]
          ),

        ],
      ),
    );
  }

  late OverlayEntry overlayEntry1;
  bool overlayFlag = false;

  void _showOverlay(BuildContext context) async {
    // Declaring and Initializing OverlayState and
    // OverlayEntry objects
    OverlayState overlayState = Overlay.of(context);
    //OverlayEntry overlayEntry1;
    overlayEntry1 = OverlayEntry(builder: (context) {
      // You can return any widget you like here
      // to be displayed on the Overlay
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
              child: Text('data logging in the app...',
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

    // Awaiting for 3 seconds
    //await Future.delayed(Duration(seconds: 3));

  }

  Future<void> _showSetTimeDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Set Time'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Icon(
                  Icons.info,
                  color: Colors.black,
                  size: 50,
                ),
                Center(
                    child: Column(
                        children: <Widget>[
                          Text('This function will set the time on the HealthyPi Move '
                              'using the time on this mobile device!.',
                            style: TextStyle(fontSize: 16, color: Colors.black,),),
                          Text('Press OK to continue',style: TextStyle(fontSize: 16, color: Colors.black,),),
                        ]
                    ),
                    ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () async{
                Navigator.pop(context);
                _sendCurrentDateTime();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCommandSentDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sent'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 72,
                ),
                Center(
                  child: Column(
                      children: <Widget>[
                        Text('Command sent',style: TextStyle(fontSize: 16, color: Colors.black,),),
                      ]
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () async{
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendCurrentDateTime() async {
    /* Send current DataTime to device - Bluetooth Packet format

     | Byte  | Value
     ----------------
     | 0 | WISER_CMD_SET_DEVICE_TIME (0x41)
     | 1 | sec
     | 2 | min
     | 3 | hour
     | 4 | mday(day of the month)
     | 5 | month
     | 6 | year

     */

    List<int> commandDateTimePacket = [];

    var dt = DateTime.now();
    String cdate = DateFormat("yy").format(DateTime.now());
    /*print(cdate);
    print(dt.month);
    print(dt.day);
    print(dt.hour);
    print(dt.minute);
    print(dt.second);*/

    ByteData sessionParametersLength = new ByteData(8);
    commandDateTimePacket.addAll(hPi4Global.WISER_CMD_SET_DEVICE_TIME);

    sessionParametersLength.setUint8(0, dt.second);
    sessionParametersLength.setUint8(1, dt.minute);
    sessionParametersLength.setUint8(2, dt.hour);
    sessionParametersLength.setUint8(3, dt.day);
    sessionParametersLength.setUint8(4, dt.month);
    sessionParametersLength.setUint8(5, int.parse(cdate));

    Uint8List cmdByteList = sessionParametersLength.buffer.asUint8List(0, 6);

    logConsole("AKW: Sending DateTime information: " + cmdByteList.toString());

    commandDateTimePacket.addAll(cmdByteList);

    logConsole("AKW: Sending DateTime Command: " + commandDateTimePacket.toString());
    await widget.fble.writeCharacteristicWithoutResponse(commandTxCharacteristic,
        value: commandDateTimePacket);

    print("DateTime Sent");

    _showCommandSentDialog();
  }

  Widget _buildCharts() {
    if(widget.currentDevice.name.contains("healthypi move")){
      //if(widget.currentDevice.name.contains("healthypi")||widget.currentDevice.name.contains("WISER")){
      return Expanded(
          child: Row(
              children: <Widget>[
                ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                        //color: Colors.white,
                        color: Colors.transparent,
                        width: SizeConfig.blockSizeHorizontal * 20,
                        child: Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: Column(
                            children: <Widget>[
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: MaterialButton(
                                  minWidth: 60.0,
                                  //height: 30.0,
                                  color: startStreaming ? Colors.red:Colors.green,
                                  child: Row(
                                    children: <Widget>[
                                      startStreaming ? Text('Stop stream',
                                          style: new TextStyle(fontSize: 16.0, color: Colors.black))
                                          : Text('Start stream', style: new TextStyle(
                                          fontSize: 16.0, color: Colors.black)),
                                    ],
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8.0),
                                  ),
                                  onPressed: () async {
                                    if(startStreaming == false){
                                      setState((){
                                        startStreaming = true;
                                      });
                                      dataFormatBasedOnBoards();
                                    }else{
                                      closeAllStreams();
                                      ecgLineData.clear();
                                      ppgLineData.clear();
                                      respLineData.clear();
                                      setState((){
                                        startStreaming = false;
                                      });
                                    }
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: MaterialButton(
                                  minWidth: 60.0,
                                  //height: 30.0,
                                  color: Colors.white,
                                  child: Row(
                                    children: <Widget>[
                                      Text('Log to APP',style: new TextStyle(
                                          fontSize: 16.0, color: Colors.black)),
                                    ],
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8.0),
                                  ),
                                  onPressed: () async {
                                    setState(() {
                                      startAppLogging = true;
                                    });
                                    _showOverlay(context);
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: MaterialButton(
                                  minWidth: 60.0,
                                  //height: 30.0,
                                  color: Colors.white,
                                  child: Row(
                                    children: <Widget>[
                                      Text('Log to Flash',style: new TextStyle(
                                          fontSize: 16.0, color: Colors.black)),
                                    ],
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8.0),
                                  ),
                                  onPressed: () async {
                                    Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(builder: (_)
                                        => Fetchlogs(
                                          selectedBoard:widget.selectedBoard,
                                          selectedDevice: widget.selectedDevice,
                                          currentDevice: widget.currentDevice,
                                          fble:widget.fble,
                                          currConnection: widget.currConnection,
                                        )));
                                  },
                                ),
                              ),
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: MaterialButton(
                                  minWidth: 60.0,
                                  color: Colors.white,
                                  child: Row(
                                    children: <Widget>[
                                      Text('Set Time',style: new TextStyle(
                                          fontSize: 16.0, color: Colors.black)),
                                    ],
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8.0),
                                  ),
                                  onPressed: () async {
                                   // _sendCurrentDateTime();
                                    _showSetTimeDialog();
                                  },
                                ),
                              ),
                              /*Padding(
                                padding:
                                const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: MaterialButton(
                                  minWidth: 60.0,
                                  color: Colors.white,
                                  child: Row(
                                    children: <Widget>[
                                      Text('Update DFU',style: new TextStyle(
                                          fontSize: 16.0, color: Colors.black)),
                                    ],
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8.0),
                                  ),
                                  onPressed: () async {

                                  },
                                ),
                              ),*/
                              Padding(
                                padding:
                                const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                child: MaterialButton(
                                  minWidth: 60.0,
                                  //color: Colors.white,
                                  color: Colors.red,
                                  child: Row(
                                    children: <Widget>[
                                      Text('Disconnect',style: new TextStyle(
                                          fontSize: 16.0, color: Colors.black)),
                                    ],
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(8.0),
                                  ),
                                  onPressed: () async {
                                    if(overlayFlag == true){
                                      overlayFlag = false;
                                      overlayEntry1.remove();
                                    }
                                    if(startAppLogging == true){
                                      startAppLogging = false;
                                      _writeLogDataToFile(ecgDataLog, ppgDataLog,respDataLog);
                                    }else{
                                      closeAllStreams();
                                      await _disconnect();
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(builder: (_) => HomePage(title: 'OpenView')),
                                      );
                                    }
                                  },
                                ),
                              ),

                            ],
                          ),
                        )),
                ),
                SizedBox(
                  width: SizeConfig.blockSizeHorizontal * 1,
                ),
                Container(
                    color: Colors.black,
                    width: SizeConfig.blockSizeHorizontal * 76,
                    child: Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: Column(
                        children: <Widget>[
                          displayHealthyPiMoveCharts(),
                        ],
                      ),
                    )),
              ]
          )
        );
    }else{
      return Expanded(
          child: Container(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: Column(
                  children: <Widget>[
                    displayHealthyPiCharts(),
                  ],
                ),
              )));
    }

  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
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

  Widget displayDisconnectButton() {
    return Consumer3<BleScannerState, BleScanner, OpenViewBLEProvider>(
        builder: (context, bleScannerState, bleScanner, wiserBle, child) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: MaterialButton(
          minWidth: 100.0,
          color: Colors.red,
          child: Row(
            children: <Widget>[
              Text('Disconnect',
                  style: new TextStyle(fontSize: 18.0, color: Colors.white)),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          onPressed: () async {
            if(startAppLogging == true){
              startAppLogging = false;
              _writeLogDataToFile(ecgDataLog, ppgDataLog,respDataLog);
            }else{
              closeAllStreams();
              await _disconnect();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomePage(title: 'OpenView')),
              );
            }
          },
        ),
      );
    });
  }

  Future<void> _writeLogDataToFile(List<double> ecgData, List<double> ppgData, List<double> respData) async {
    //logConsole("Log data size: " + ecgData.length.toString());
    //logConsole("Log data size: " + ppgData.length.toString());
    //logConsole("Log data size: " + respData.length.toString());

    List<List<String>> dataList = []; //Outter List which contains the data List

    List<String> header = [];

    header.add("ECG");
    header.add("PPG");
    header.add("RESPIRATION");

    dataList.add(header);

    for (int i = 0; i < (ecgData.length-50); i++) {
      List<String> dataRow = [
        (ecgData[i]).toString(),
        (ppgData[i]).toString(),
        (respData[i]).toString(),
      ];
      dataList.add(dataRow);
    }


    // Code to convert logData to CSV file
    String csv = const ListToCsvConverter().convert(dataList);
    final String logFileTime = DateTime.now().millisecondsSinceEpoch.toString();

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

    File file= File('$directory/openview-log-$logFileTime.csv');
    print("Save file");

    await file.writeAsString(csv);

    print("File exported successfully!");

    await _showDownloadSuccessDialog();

  }

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
              onPressed: () async{
                //Navigator.pop(context);
                closeAllStreams();
                await _disconnect();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => HomePage(title: 'HealthyPi5')),
                );

              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _disconnect() async {
    try {
      logConsole('Disconnecting ');
      if (connectedToDevice == true) {
        showLoadingIndicator("Disconnecting....", context);
        await Future.delayed(Duration(seconds: 6), () async {
          await widget.currConnection.cancel();
          setState(() {
            connectedToDevice = false;
            pcCurrentDeviceID = "";
            pcCurrentDeviceName = "";
          });
        });
        //Navigator.pop(context);
      }
    } on Exception catch (e, _) {
      logConsole("Error disconnecting from a device: $e");
    } finally {
      // Since [_connection] subscription is terminated, the "disconnected" state cannot be received and propagated
    }
  }

  Widget LogToAppButton(){
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: MaterialButton(
        minWidth: 80.0,
        color: startAppLogging ? Colors.grey:Colors.white,
        child: Row(
          children: <Widget>[
            Text('Log to App',
                style: new TextStyle(
                    fontSize: 16.0, color: hPi4Global.hpi4Color)),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        onPressed: () async {
          setState(() {
            startAppLogging = true;
          });
        },
      ),
    );
  }

  Widget LogToFlashButton(){
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: MaterialButton(
        minWidth: 80.0,
        color: startAppLogging ? Colors.grey:Colors.white,
        child: Row(
          children: <Widget>[
            Text('Log to Flash',
                style: new TextStyle(
                    fontSize: 16.0, color: hPi4Global.hpi4Color)),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        onPressed: () async {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_)
              => Fetchlogs(
                selectedBoard:widget.selectedBoard,
                selectedDevice: widget.selectedDevice,
                currentDevice: widget.currentDevice,
                fble:widget.fble,
                currConnection: widget.currConnection,
              )));

        },
      ),
    );
  }

  Widget StartAndStopButton(){
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: MaterialButton(
        minWidth: 80.0,
        color: startStreaming ? Colors.red:Colors.green,
        child: Row(
          children: <Widget>[
            startStreaming ? Text('Stop',
                style: new TextStyle(fontSize: 16.0, color: Colors.white))
                : Text('Start', style: new TextStyle(
                fontSize: 16.0, color: Colors.white)),

          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        onPressed: () async {
          if(startStreaming == false){
            setState((){
              startStreaming = true;
            });
            dataFormatBasedOnBoards();
          }else{
            closeAllStreams();
            ecgLineData.clear();
            ppgLineData.clear();
            respLineData.clear();
            setState((){
              startStreaming = false;
            });
          }
        },
      ),
    );
  }

   Widget displayAppBarButtons(){
    if(widget.currentDevice.name.contains("healthypi move")){
     //if(widget.currentDevice.name.contains("healthypi")||widget.currentDevice.name.contains("WISER")){
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Row(
              children: <Widget>[
                Image.asset('assets/proto-online-white.png',
                    fit: BoxFit.fitWidth, height: 30),
                displayDeviceName(),
              ]
          ),
        ],
      );
    }else{
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Column(
              children: <Widget>[
                Image.asset('assets/proto-online-white.png',
                    fit: BoxFit.fitWidth, height: 30),
                displayDeviceName(),

              ]
          ),
          LogToAppButton(),
          //LogToFlashButton(),
          StartAndStopButton(),
          displayDisconnectButton(),
        ],
      );
    }
  }

  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: hPi4Global.appBackgroundColor,
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: hPi4Global.hpi4Color,
          automaticallyImplyLeading: false,
        title:  displayAppBarButtons(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildCharts(),
              //showPages(),
            ],
          ),
        ),
      ),
    );
  }
}