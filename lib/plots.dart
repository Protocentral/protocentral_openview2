import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'globals.dart';
import 'home.dart';
import 'sizeConfig.dart';

import 'ble/ble_scanner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'states/OpenViewBLEProvider.dart';
import 'dart:async';
import 'dart:io';


import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class WaveFormsPage extends StatefulWidget {
  WaveFormsPage({Key? key,
    required this.selectedBoard,
    required this.selectedDevice,
    required this.selectedDeviceID,
    required this.fble,
  }) : super();

  final String selectedBoard;
  final String selectedDevice;
  final String selectedDeviceID;
  final FlutterReactiveBle fble;

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

  bool ecgCheckBoxValue = true;
  bool ppgCheckBoxValue = true;
  bool respCheckBoxValue = true;

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

  bool startDataLogging = false;

  int globalHeartRate = 0;
  int globalSpO2 = 0;
  int globalRespRate = 0;
  double globalTemp = 0;
  int _globalBatteryLevel = 50;


  void logConsole(String logString) {
    print("AKW - " + logString);
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    displayWaveforms();

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      subscribeToCharacteristics();
      dataFormatBasedOnBoards();

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
        deviceId: widget.selectedDeviceID);

    RESPCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_RESP_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_ECG_SERVICE),
        deviceId: widget.selectedDeviceID);

    PPGCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HIST),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HRV),
        deviceId: widget.selectedDeviceID);

    BatteryCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_BATT),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_BATT),
        deviceId: widget.selectedDeviceID);

    HRCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HR),
        deviceId: widget.selectedDeviceID);

    SPO2Characteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_SPO2_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_SPO2),
        deviceId: widget.selectedDeviceID);

    TempCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_TEMP_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HEALTH_THERM),
        deviceId: widget.selectedDeviceID);

    HRVRespCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HRV),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HRV),
        deviceId: widget.selectedDeviceID);

    CommandCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERVICE_CMD),
        deviceId: widget.selectedDeviceID);

  }

  void dataFormatBasedOnBoards() async {
    if (widget.selectedBoard == 'ADS1292R Breakout/Shield') {
      _startECG16Listening();
      _startRESP16Listening();
      await _startListeningHR();
      await _startListeningHRVResp();
    } else if (widget.selectedBoard == 'ADS1293 Breakout/Shield') {
      _startECG32Listening();
    } else if (widget.selectedBoard == 'AFE4490 Breakout/Shield') {
      _startPPG32Listening();
      await _startListeningHR();
      await _startListeningSPO2();
    } else if (widget.selectedBoard == 'MAX86150 Breakout') {
      _startECG16Listening();
      _startPPG16Listening();
    } else if (widget.selectedBoard == 'Pulse Express (MAX30102/MAX32664D)') {
      _startPPG16Listening();
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

  void displayWaveforms() {
    if (widget.selectedDevice.toLowerCase().contains("healthypi")) {
      setState(() {
        ecgCheckBoxValue = true;
        ppgCheckBoxValue = true;
        respCheckBoxValue = true;
      });
    } else if (widget.selectedDevice.contains("OpenOx")) {
      setState(() {
        ecgCheckBoxValue = false;
        ppgCheckBoxValue = true;
        respCheckBoxValue = false;
      });
    } else {
      setState(() {
        ecgCheckBoxValue = true;
        ppgCheckBoxValue = true;
        respCheckBoxValue = true;
      });
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
  }

  Future<void> _startListeningBattery() async {
    print("AKW: Started listening to Battery stream");
    listeningBatteryStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamBattery =
          await widget.fble.subscribeToCharacteristic(BatteryCharacteristic);
    });

    streamBatterySubscription = _streamBattery.listen((event) {
      // print("AKW: Rx Battery: " + event.toString());
      setStateIfMounted(() {
        _globalBatteryLevel = event[0];
        print("AKW: Rx Battery: " + event[0].toString());
      });
    });
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
        globalRespRate = event[10];
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
            if(startDataLogging == true){
              ecgDataLog.add(element.toDouble());
            }
          });

          if (ecgDataCounter >= 64 * 6) {
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
            if(startDataLogging == true){
              ecgDataLog.add(element.toDouble());
            }
          });

          if (ecgDataCounter >= 64 * 6) {
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
            if(startDataLogging == true){
              ppgDataLog.add(element.toDouble());
            }
          });

          if (ppgDataCounter >= 64 * 6) {
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
            if(startDataLogging == true){
              ppgDataLog.add(element.toDouble());
            }
          });

          if (ppgDataCounter >= 64 * 6) {
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
            if(startDataLogging == true){
              respDataLog.add(element.toDouble());
            }
          });

          if (respDataCounter >= 128 * 6) {
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
            if(startDataLogging == true){
              respDataLog.add(element.toDouble());
            }
          });

          if (respDataCounter >= 128 * 6) {
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
      barWidth: 4,
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
        //swapAnimationDuration: Duration.zero,
      ),
    );
  }

  Widget displayCharts() {
    if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == false) {
      return buildChart(54, 95, ecgLineData, Colors.green);
    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == false) {
      return buildChart(54, 95, ppgLineData, Colors.yellow);
    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == true) {
      return buildChart(54, 95, respLineData, Colors.blue);
    } else if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == false) {
      return Column(children: [
        buildChart(27, 95, ecgLineData, Colors.green),
        SizedBox(
          height: SizeConfig.blockSizeVertical * 1,
        ),
        buildChart(27, 95, ppgLineData, Colors.yellow),
      ]);
    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == true) {
      return Column(children: [
        buildChart(27, 95, ppgLineData, Colors.yellow),
        SizedBox(
          height: SizeConfig.blockSizeVertical * 1,
        ),
        buildChart(27, 95, respLineData, Colors.blue),
      ]);
    } else if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == true) {
      return Column(children: [
        buildChart(27, 95, ecgLineData, Colors.green),
        SizedBox(
          height: SizeConfig.blockSizeVertical * 1,
        ),
        buildChart(27, 95, respLineData, Colors.blue),
      ]);
    } else {
      return Column(
        children: [
          buildChart(18, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
          buildChart(18, 95, ppgLineData, Colors.yellow),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 1,
          ),
          buildChart(18, 95, respLineData, Colors.blue),
        ],
      );
    }
  }

  Widget displayValues() {
    if (widget.selectedDevice.toLowerCase().contains("healthypi")) {
      return Container(
        height: SizeConfig.blockSizeVertical * 10,
        width: SizeConfig.blockSizeHorizontal * 95,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Heart Rate: " + globalHeartRate.toString() + " bpm",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 15,
              ),
              Text(
                "SPO2: " + globalSpO2.toString() + " %",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 15,
              ),
              Text(
                "Respiration: " + globalRespRate.toString() + " rpm",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 15,
              ),
              Text(
                "Temperature: " + globalTemp.toStringAsPrecision(3) + "\u00b0 C",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (widget.selectedDevice.contains("OpenOx")) {
      return Container(
        height: SizeConfig.blockSizeVertical * 10,
        width: SizeConfig.blockSizeHorizontal * 95,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Heart Rate: " + globalHeartRate.toString() + " bpm",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 15,
              ),
              Text(
                "SPO2: " + globalSpO2.toString() + " %",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              SizedBox(
                width: 15,
              ),
            ],
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  Widget displayHealthyPiCharts() {
    if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == false) {
      return buildChart(54, 95, ecgLineData, Colors.green);
    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == false) {
      return buildChart(54, 95, ppgLineData, Colors.yellow);
    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == true) {
      return buildChart(54, 95, respLineData, Colors.blue);
    } else if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == false) {
      return Column(children: [
        buildChart(27, 95, ecgLineData, Colors.green),
        SizedBox(
          height: SizeConfig.blockSizeVertical * 1,
        ),
        buildChart(27, 95, ppgLineData, Colors.yellow),
      ]);
    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == true) {
      return Column(children: [
        buildChart(27, 95, ppgLineData, Colors.yellow),
        SizedBox(
          height: SizeConfig.blockSizeVertical * 1,
        ),
        buildChart(27, 95, respLineData, Colors.blue),
      ]);
    } else if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == true) {
      return Column(children: [
        buildChart(27, 95, ecgLineData, Colors.green),
        SizedBox(
          height: SizeConfig.blockSizeVertical * 1,
        ),
        buildChart(27, 95, respLineData, Colors.blue),
      ]);
    } else {
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
                        fontSize: 10,
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
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(8, 95, ecgLineData, Colors.green),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 0.2,
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
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child:  Text(globalSpO2.toString() +" %",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(8, 95, ppgLineData, Colors.yellow),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 0.2,
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
                        fontSize: 10,
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
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(8, 95, respLineData, Colors.blue),
          SizedBox(
            height: SizeConfig.blockSizeVertical * 0.2,
          ),
          Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      "TEMPERATURE ",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    color: Colors.transparent,
                    child: Text( globalTemp.toString() + " C",
                      style: TextStyle(
                        fontSize: 18,
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
  }

  Widget displayDeviceName() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Connected To:    " + widget.selectedDevice + " / " + widget.selectedBoard,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharts() {
    if(widget.selectedDevice.toLowerCase().contains("healthypi")){
      return Expanded(
          child: Container(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: SizeConfig.blockSizeVertical * 1,
                    ),
                    displayHealthyPiCharts(),
                  ],
                ),
              )));
    }else{
      return Expanded(
          child: Container(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: SizeConfig.blockSizeVertical * 1,
                    ),
                    displayCharts(),
                    //displayPlots(),
                    SizedBox(
                      height: SizeConfig.blockSizeVertical * 1,
                    ),
                    displayValues(),
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

  Widget displayECGCheckBoxes() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Text("ECG: "),
          Checkbox(
              value: ecgCheckBoxValue,
              activeColor: Colors.green,
              onChanged: (newValue) {
                setState(() {
                  ecgCheckBoxValue = newValue!;
                });
                // print("ecgCheckBoxValue........"+ ecgCheckBoxValue.toString());
              }),
        ],
      ),
    );
  }

  Widget displayPPGCheckBoxes() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Text("PPG: "),
          Checkbox(
              value: ppgCheckBoxValue,
              activeColor: Colors.green,
              onChanged: (newValue) {
                setState(() {
                  ppgCheckBoxValue = newValue!;
                });
                // print("ppgCheckBoxValue........"+ ppgCheckBoxValue.toString());
              }),
        ],
      ),
    );
  }

  Widget displayRESPCheckBoxes() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Text("Resp: "),
          Checkbox(
              value: respCheckBoxValue,
              activeColor: Colors.green,
              onChanged: (newValue) {
                setState(() {
                  respCheckBoxValue = newValue!;
                });
                // print("respCheckBoxValue........"+ respCheckBoxValue.toString());
              }),
        ],
      ),
    );
  }

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
              Text('Stop',
                  style: new TextStyle(fontSize: 18.0, color: Colors.white)),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          onPressed: () async {
            if(startDataLogging == true){
              startDataLogging = false;
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
    logConsole("Log data size: " + ecgData.length.toString());
    logConsole("Log data size: " + ppgData.length.toString());
    logConsole("Log data size: " + respData.length.toString());

    List<List<String>> dataList = []; //Outter List which contains the data List

    List<String> header = [];

    if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == false) {

      header.add("ECG");

      dataList.add(header);

      for (int i = 0; i < (ecgData.length-50); i++) {
        List<String> dataRow = [
          (ecgData[i]).toString(),
        ];
        dataList.add(dataRow);
      }

    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == false) {

      header.add("PPG");

      dataList.add(header);

      for (int i = 0; i < (ppgData.length-50); i++) {
        List<String> dataRow = [
          (ppgData[i]).toString(),
        ];
        dataList.add(dataRow);
      }

    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == true) {

      header.add("RESPIRATION");

      dataList.add(header);

      for (int i = 0; i < (respData.length-50); i++) {
        List<String> dataRow = [
          (respData[i]).toString(),
        ];
        dataList.add(dataRow);
      }

    } else if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == false) {

      header.add("ECG");
      header.add("PPG");

      dataList.add(header);

      for (int i = 0; i < (ecgData.length-50); i++) {
        List<String> dataRow = [
          (ecgData[i]).toString(),
          (ppgData[i]).toString(),
        ];
        dataList.add(dataRow);
      }

    } else if (ecgCheckBoxValue == false &&
        ppgCheckBoxValue == true &&
        respCheckBoxValue == true) {

      header.add("PPG");
      header.add("RESPIRATION");

      dataList.add(header);

      for (int i = 0; i < (ppgData.length-50); i++) {
        List<String> dataRow = [
          (ppgData[i]).toString(),
          (respData[i]).toString(),
        ];
        dataList.add(dataRow);
      }

    } else if (ecgCheckBoxValue == true &&
        ppgCheckBoxValue == false &&
        respCheckBoxValue == true) {

      header.add("ECG");
      header.add("RESPIRATION");

      dataList.add(header);

      for (int i = 0; i < (ecgData.length-50); i++) {
        List<String> dataRow = [
          (ecgData[i]).toString(),
          (respData[i]).toString(),
        ];
        dataList.add(dataRow);
      }

    } else {
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
          await hPi4Global.connection.cancel();
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


  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: WiserGlobal.appBackgroundColor,
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: hPi4Global.hpi4Color,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Image.asset('assets/proto-online-white.png',
                fit: BoxFit.fitWidth, height: 30),
            //displayECGCheckBoxes(),
            //displayPPGCheckBoxes(),
            //displayRESPCheckBoxes(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: MaterialButton(
                minWidth: 80.0,
                color: startDataLogging ? Colors.grey:Colors.white,
                child: Row(
                  children: <Widget>[
                    Text('Start Logging',
                        style: new TextStyle(
                            fontSize: 16.0, color: hPi4Global.hpi4Color)),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                onPressed: () async {
                  setState(() {
                    startDataLogging = true;
                  });
                },
              ),
            ),
            displayDeviceName(),
            displayDisconnectButton(),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _buildCharts(),
            ],
          ),
        ),
      ),
    );
  }
}
