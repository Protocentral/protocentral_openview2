import 'dart:async';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'states/OpenViewBLEProvider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'home.dart';
import 'globals.dart';
import 'utils/sizeConfig.dart';
import 'utils/charts.dart';
import 'onBoardDataLog.dart';
import 'ble/ble_scanner.dart';
import 'utils/loadingDialog.dart';
import 'utils/logDataToFile.dart';

class WaveFormsPage extends StatefulWidget {
  WaveFormsPage({
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
  double globalTemp = 0;

  late QualifiedCharacteristic ECGCharacteristic;
  late QualifiedCharacteristic PPGCharacteristic;
  late QualifiedCharacteristic RESPCharacteristic;
  late QualifiedCharacteristic BatteryCharacteristic;
  late QualifiedCharacteristic HRCharacteristic;
  late QualifiedCharacteristic SPO2Characteristic;
  late QualifiedCharacteristic TempCharacteristic;
  late QualifiedCharacteristic HRVRespCharacteristic;
  late QualifiedCharacteristic commandTxCharacteristic;
  late QualifiedCharacteristic dataCharacteristic;

  late StreamSubscription streamBatterySubscription;
  late StreamSubscription streamHRSubscription;
  late StreamSubscription streamSPO2Subscription;
  late StreamSubscription streamHRVRespSubscription;
  late StreamSubscription streamTempSubscription;
  late StreamSubscription streamECGSubscription;
  late StreamSubscription streamPPGSubscription;
  late StreamSubscription streamRESPSubscription;
  late StreamSubscription _streamCommandSubscription;
  late StreamSubscription _streamDataSubscription;

  late Stream<List<int>> _streamECG;
  late Stream<List<int>> _streamPPG;
  late Stream<List<int>> _streamRESP;
  late Stream<List<int>> _streamHR;
  late Stream<List<int>> _streamSPO2;
  late Stream<List<int>> _streamTemp;
  late Stream<List<int>> _streamHRVResp;
  late Stream<List<int>> _streamCommand;
  late Stream<List<int>> _streamData;

  bool listeningECGStream = false;
  bool listeningPPGStream = false;
  bool listeningRESPStream = false;
  bool listeningHRStream = false;
  bool listeningSPO2Stream = false;
  bool listeningTempStream = false;
  bool listeningHRVRespStream = false;
  bool listeningDataStream = false;
  bool listeningUploadStream = false;
  bool listeningConnectionStream = false;
  bool _listeningCommandStream = false;

  bool startAppLogging = false;
  bool startFlashLogging = false;
  bool memoryAvailable = false;
  bool startStreaming = false;
  bool endFlashLoggingResponse = false;
  bool sdCardStatusCheck = false;

  int globalHeartRate = 0;
  int globalSpO2 = 0;
  int globalRespRate = 0;

  String displaySpO2 = "--";

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      subscribeToCharacteristics();
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

    closeAllStreams();

    super.dispose();
  }

  void subscribeToCharacteristics() {
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

    dataCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_DATA),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: widget.currentDevice.id);

    commandTxCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: widget.currentDevice.id);
  }

  void dataFormatBasedOnBoardsSelection() async {
    if (widget.selectedBoard == 'ADS1292R Breakout/Shield') {
      startECG16Listening();
      startRESP16Listening();
      await startListeningHR();
      await startListeningHRVResp();
    } else if (widget.selectedBoard == 'ADS1293 Breakout/Shield') {
      startECG32Listening();
      startPPG16Listening();
      startRESP32Listening();
    } else if (widget.selectedBoard == 'AFE4490 Breakout/Shield') {
      startPPG32Listening();
      await startListeningHR();
      await startListeningSPO2();
    } else if (widget.selectedBoard == 'MAX86150 Breakout') {
      startECG16Listening();
      startPPG16Listening();
    } else if (widget.selectedBoard == 'Pulse Express') {
      startECG32Listening();
      startRESP32Listening();
    } else if (widget.selectedBoard == 'tinyGSR Breakout') {
      startECG16Listening();
    } else if (widget.selectedBoard == 'MAX30003 ECG Breakout') {
      startECG32Listening();
      await startListeningHR();
      await startListeningHRVResp();
    } else if (widget.selectedBoard == 'MAX30001 ECG & BioZ Breakout') {
      startECG32Listening();
      startRESP32Listening();
    } else {
      startECG32Listening();
      startPPG16Listening();
      startRESP32Listening();
      await startListeningHR();
      await startListeningSPO2();
      await startListeningHRVResp();
      await startListeningTemp();
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

  Future<void> startListeningHR() async {
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

  Future<void> startListeningSPO2() async {
    print("AKW: Started listening to SPO2 stream");
    listeningSPO2Stream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamSPO2 =
          await widget.fble.subscribeToCharacteristic(SPO2Characteristic);
    });

    streamSPO2Subscription = _streamSPO2.listen((event) {
      setStateIfMounted(() {
        globalSpO2 = event[1];
        if (globalSpO2 == 25) {
          displaySpO2 = "--";
        } else {
          displaySpO2 = globalSpO2.toString() + " %";
        }
      });
    });
  }

  Future<void> startListeningTemp() async {
    print("AKW: Started listening to Temp stream");
    listeningTempStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamTemp =
          (await widget.fble.subscribeToCharacteristic(TempCharacteristic));
    });

    streamTempSubscription = _streamTemp.listen((event) {
      setStateIfMounted(() {
        Uint8List u8list = Uint8List.fromList(event);
        globalTemp = ((hPi4Global.toInt16(u8list, 0).toDouble()) * 0.01);
      });
    });
  }

  Future<void> startListeningHRVResp() async {
    print("AKW: Started listening to HRVResp stream");
    listeningHRVRespStream = true;

    await Future.delayed(Duration(seconds: 4), () async {
      _streamHRVResp =
          await widget.fble.subscribeToCharacteristic(HRVRespCharacteristic);
    });

    streamHRVRespSubscription = _streamHRVResp.listen((event) {
      setStateIfMounted(() {
        globalRespRate = event[0];
      });
    });
  }

  void startECG16Listening() async {
    print("AKW: Started listening to stream");
    listeningECGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamECG =
          await widget.fble.subscribeToCharacteristic(ECGCharacteristic);
    });

    streamECGSubscription = _streamECG.listen(
      (event) {
        ByteData ecgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int16List ecgList = ecgByteData.buffer.asInt16List();

        ecgList.forEach((element) {
          setStateIfMounted(() {
            ecgLineData.add(FlSpot(ecgDataCounter++, (element.toDouble())));
            if (startAppLogging == true) {
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

  void startECG32Listening() async {
    print("AKW: Started listening to stream");
    listeningECGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamECG =
          await widget.fble.subscribeToCharacteristic(ECGCharacteristic);
    });

    streamECGSubscription = _streamECG.listen(
      (event) {
        ByteData ecgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int32List ecgList = ecgByteData.buffer.asInt32List();

        ecgList.forEach((element) {
          setStateIfMounted(() {
            ecgLineData.add(FlSpot(ecgDataCounter++, (element.toDouble())));
            if (startAppLogging == true) {
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

  void startPPG16Listening() async {
    print("AKW: Started listening to ppg stream");
    listeningPPGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamPPG =
          await widget.fble.subscribeToCharacteristic(PPGCharacteristic);
    });

    streamPPGSubscription = _streamPPG.listen(
      (event) {
        // print("AKW: Rx PPG: " + event.length.toString());
        ByteData ppgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int16List ppgList = ppgByteData.buffer.asInt16List();

        ppgList.forEach((element) {
          setStateIfMounted(() {
            ppgLineData.add(FlSpot(ppgDataCounter++, (element.toDouble())));
            if (startAppLogging == true) {
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

  void startPPG32Listening() async {
    print("AKW: Started listening to ppg stream");
    listeningPPGStream = true;

    await Future.delayed(Duration(seconds: 1), () async {
      _streamPPG =
          await widget.fble.subscribeToCharacteristic(PPGCharacteristic);
    });

    streamPPGSubscription = _streamPPG.listen(
      (event) {
        // print("AKW: Rx PPG: " + event.length.toString());
        ByteData ppgByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int32List ppgList = ppgByteData.buffer.asInt32List();

        ppgList.forEach((element) {
          setStateIfMounted(() {
            ppgLineData.add(FlSpot(ppgDataCounter++, (element.toDouble())));
            if (startAppLogging == true) {
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

  void startRESP16Listening() async {
    print("AKW: Started listening to respiration stream");
    listeningRESPStream = true;
    int i = 0;
    await Future.delayed(Duration(seconds: 1), () async {
      _streamRESP =
          await widget.fble.subscribeToCharacteristic(RESPCharacteristic);
    });

    streamRESPSubscription = _streamRESP.listen(
      (event) {
        ByteData respByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int16List respList = respByteData.buffer.asInt16List();
        respList.forEach((element) {
          setStateIfMounted(() {
            respLineData.add(FlSpot(respDataCounter++, (element.toDouble())));
            if (startAppLogging == true) {
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

  void startRESP32Listening() async {
    print("AKW: Started listening to respiration stream");
    listeningRESPStream = true;
    await Future.delayed(Duration(seconds: 1), () async {
      _streamRESP =
          await widget.fble.subscribeToCharacteristic(RESPCharacteristic);
    });

    streamRESPSubscription = _streamRESP.listen(
      (event) {
        ByteData respByteData = Uint8List.fromList(event).buffer.asByteData(0);
        Int32List respList = respByteData.buffer.asInt32List();
        respList.forEach((element) {
          setStateIfMounted(() {
            respLineData.add(FlSpot(respDataCounter++, (element.toDouble())));
            if (startAppLogging == true) {
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

  Future<void> startListeningData() async {
    print("AKW: Started listening to the response");
    listeningDataStream = true;
    await Future.delayed(Duration(seconds: 1), () async {
      _streamData =
          await widget.fble.subscribeToCharacteristic(dataCharacteristic);
    });

    _streamDataSubscription = _streamData.listen((value) async {
      //print("DataChar Rx: " + value.length.toString());

      if (value.length > 2) {
        print("Data Rx: " + value.toString());

        if (value[0] == 0x03) {
          if (value[1] == 0x55) {
            if (value[2] == 0x32) {
              //print("Availble memory is greater than 25%");
              // _showOverlay(context);
              setState(() {
                memoryAvailable = true;
                startFlashLogging = true;
              });
            } else if (value[2] == 0x31) {
              //print("Availble memory is less than 25%");
              showInsufficientMemoryDialog();
              setState(() {
                memoryAvailable = false;
                startFlashLogging = false;
              });
            }else if(value[2] == 0x58){
              showSDCardNotFoundDialog();
              setState(() {
                sdCardStatusCheck = true;
                memoryAvailable = false;
                startFlashLogging = false;
              });
            }else if(value[2] == 0x59){
              setState(() {
                sdCardStatusCheck = false;
                memoryAvailable = false;
                startFlashLogging = false;
              });
            }
          }
        }
      }
    });
  }

  Widget displayHeartRateValue() {
    return Column(children: [
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
          child: Text(
            globalHeartRate.toString() + " bpm",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget displayRespirationRateValue() {
    return Column(children: [
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
          child: Text(
            globalRespRate.toString() + " rpm",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget displaySpo2Value() {
    return Column(children: [
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
          child: Text(
            displaySpO2,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget displayTemperatureValue() {
    return Column(children: [
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
          child: Text(
            globalTemp.toStringAsPrecision(3) + "\u00b0 C",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget sizedBoxForCharts() {
    return SizedBox(
      height: SizeConfig.blockSizeVertical * 2,
    );
  }

  Widget displayHealthyPiCharts() {
    if (widget.selectedBoard == "ADS1292R Breakout/Shield") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(25, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
          buildPlots().buildChart(25, 95, respLineData, Colors.blue),
        ],
      );
    } else if (widget.selectedBoard == "ADS1293 Breakout/Shield") {
      return Column(
        children: [
          buildPlots().buildChart(15, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(15, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          buildPlots().buildChart(15, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedBoard == "AFE4490 Breakout/Shield") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(50, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          displaySpo2Value(),
        ],
      );
    } else if (widget.selectedBoard == "MAX86150 Breakout") {
      return Column(
        children: [
          buildPlots().buildChart(15, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(15, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          buildPlots().buildChart(15, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedBoard == "Pulse Express") {
      return Column(
        children: [
          buildPlots().buildChart(27, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(27, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedBoard == "tinyGSR Breakout") {
      return Column(
        children: [
          buildPlots().buildChart(54, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedBoard == "MAX30003 ECG Breakout") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(50, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
        ],
      );
    } else if (widget.selectedBoard == "MAX30001 ECG & BioZ Breakout") {
      return Column(
        children: [
          buildPlots().buildChart(27, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(27, 95, ppgLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else {
      return Container();
    }
  }

  Widget displayHealthyPiMoveCharts() {
    return Column(
      children: [
        displayHeartRateValue(),
        buildPlots().buildChart(16, 70, ecgLineData, Colors.green),
        displaySpo2Value(),
        buildPlots().buildChart(17, 70, ppgLineData, Colors.yellow),
        displayRespirationRateValue(),
        buildPlots().buildChart(16, 70, respLineData, Colors.blue),
        displayTemperatureValue(),
      ],
    );
  }

  Widget displayDeviceName() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(children: [
            Text(
              "Connected: " +
                  widget.selectedDevice +
                  " ( " +
                  widget.currentDevice.id +
                  " )",
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
          ]),
        ],
      ),
    );
  }

  Widget displayFlashStatus() {
    if (startFlashLogging == true) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(children: [
              Text(
                "Status: Logging to SD card",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ]),
          ],
        ),
      );
    } else {
      return Container();
    }
  }

  Future<void> showSetTimeDialog() async {
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
                  child: Column(children: <Widget>[
                    Text(
                      'This function will set the time on the HealthyPi Move '
                      'using the time on this mobile device!.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Press OK to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () async {
                Navigator.pop(context);
                sendCurrentDateTime();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showInsufficientMemoryDialog() async {
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
                  Icons.info,
                  color: Colors.red,
                  size: 72,
                ),
                Center(
                  child: Column(children: <Widget>[
                    Text(
                      'Enough memory is not available to log the data.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () async {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => FetchLogs(
                          selectedBoard: widget.selectedBoard,
                          selectedDevice: widget.selectedDevice,
                          currentDevice: widget.currentDevice,
                          fble: widget.fble,
                          currConnection: widget.currConnection,
                        )));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showEndFlashingDialog() async {
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
                  Icons.info,
                  color: Colors.grey,
                  size: 72,
                ),
                Center(
                  child: Column(children: <Widget>[
                    Text(
                      'Data is already logging to flash. ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Do you want end logging or continue with the logging and disconnect from the device ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('End Logging'),
              onPressed: () async {
                // Navigator.pop(context);
                _sendEndLogtoFlashCommand();
                closeAllStreams();
                await _disconnect();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => HomePage(title: 'OpenView')),
                );
              },
            ),
            TextButton(
              child: Text('Disconnect & Continue'),
              onPressed: () async {
                //Navigator.pop(context);
                closeAllStreams();
                await _disconnect();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => HomePage(title: 'OpenView')),
                );
              },
            ),
          ],
        );
      },
    );
  }


  Future<void> showSDCardNotFoundDialog() async {
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
                  Icons.info,
                  color: Colors.red,
                  size: 72,
                ),
                Center(
                  child: Column(children: <Widget>[
                    Text(
                      'SD card is not found.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () async {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showStopStreamingDialog(String displayAlert) async {
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
                  Icons.info,
                  color: Colors.red,
                  size: 72,
                ),
                Center(
                  child: Column(children: <Widget>[
                    Text(
                      displayAlert,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () async {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> sendCurrentDateTime() async {
    /* Send current DataTime to device - Bluetooth Packet format
     | 0 | WISER_CMD_SET_DEVICE_TIME (0x41), | 1 | sec, | 2 | min, | 3 | hour,
     | 4 | mday(day of the month), | 5 | month, | 6 | year */

    List<int> commandDateTimePacket = [];

    var dt = DateTime.now();
    String cdate = DateFormat("yy").format(DateTime.now());
    ByteData sessionParametersLength = new ByteData(8);
    commandDateTimePacket.addAll(hPi4Global.WISER_CMD_SET_DEVICE_TIME);

    sessionParametersLength.setUint8(0, dt.second);
    sessionParametersLength.setUint8(1, dt.minute);
    sessionParametersLength.setUint8(2, dt.hour);
    sessionParametersLength.setUint8(3, dt.day);
    sessionParametersLength.setUint8(4, dt.month);
    sessionParametersLength.setUint8(5, int.parse(cdate));

    Uint8List cmdByteList = sessionParametersLength.buffer.asUint8List(0, 6);
    hPi4Global().logConsole(
        "AKW: Sending DateTime information: " + cmdByteList.toString());
    commandDateTimePacket.addAll(cmdByteList);
    hPi4Global().logConsole(
        "AKW: Sending DateTime Command: " + commandDateTimePacket.toString());
    await widget.fble.writeCharacteristicWithoutResponse(
        commandTxCharacteristic,
        value: commandDateTimePacket);
    print("DateTime Sent");
  }

  Future<void> sendStartSessionCommand() async {
    /* Send current DataTime with start session to device - Bluetooth Packet format
     | 0 | Start Session (0x55), | 1 | sec, | 2 | min, | 3 | hour,
     | 4 | mday(day of the month), | 5 | month, | 6 | year */

    List<int> commandDateTimePacket = [];

    var dt = DateTime.now();
    String cdate = DateFormat("yy").format(DateTime.now());
    ByteData sessionParametersLength = new ByteData(8);
    commandDateTimePacket.addAll(hPi4Global.startSession);

    sessionParametersLength.setUint8(0, dt.second);
    sessionParametersLength.setUint8(1, dt.minute);
    sessionParametersLength.setUint8(2, dt.hour);
    sessionParametersLength.setUint8(3, dt.day);
    sessionParametersLength.setUint8(4, dt.month);
    sessionParametersLength.setUint8(5, int.parse(cdate));

    Uint8List cmdByteList = sessionParametersLength.buffer.asUint8List(0, 6);
    hPi4Global().logConsole(
        "AKW: Sending datetime information with start session: " +
            cmdByteList.toString());
    commandDateTimePacket.addAll(cmdByteList);
    hPi4Global().logConsole(
        "AKW: Sending datetime command with start session: " +
            commandDateTimePacket.toString());
    await widget.fble.writeCharacteristicWithoutResponse(
        commandTxCharacteristic,
        value: commandDateTimePacket);
    print("Command Sent");
  }

  Future<void> _sendEndLogtoFlashCommand() async {
    hPi4Global().logConsole("AKW: Sending end logging flash Command: " +
        hPi4Global.stopSession.toString());
    await widget.fble.writeCharacteristicWithoutResponse(
        commandTxCharacteristic,
        value: hPi4Global.stopSession);

    print("end logging flash command Sent");
  }

  Future<void> _sendSDCardStatusCheckCommand() async {
    hPi4Global().logConsole("AKW: Sending sd card status check Command: " +
        hPi4Global.sdCardStatusCheck.toString());
    await widget.fble.writeCharacteristicWithoutResponse(
        commandTxCharacteristic,
        value: hPi4Global.sdCardStatusCheck);

    print("sd card staus command Sent");
  }


  Future<void> setMTU(String deviceMAC) async {
    int recdMTU = await widget.fble.requestMtu(deviceId: deviceMAC, mtu: 517);
    hPi4Global().logConsole("MTU negotiated: " + recdMTU.toString());
  }


   Widget showSetTime(){
    if(widget.currentDevice.name.contains("healthypi move")){
     return Padding(
       padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
       child: MaterialButton(
         minWidth: 50.0,
         color: Colors.white,
         child: Row(
           children: <Widget>[
             Text('Set Time',
                 style: new TextStyle(
                     fontSize: 16.0, color: Colors.black)),
           ],
         ),
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(8.0),
         ),
         onPressed: () async {
           // _sendCurrentDateTime();
           if(startStreaming == false){
             showSetTimeDialog();
           }else{
             showStopStreamingDialog( 'Please stop streaming to set device time.');
           }

         },
       ),
     );
    }else{
      return Container();
    }

  }

  Widget buildCharts() {
    if (widget.currentDevice.name.contains("healthypi move") ||
        widget.currentDevice.name.contains("healthypi")) {
      return Expanded(
          child: Row(children: <Widget>[
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
                    StartAndStopButton(),
                    LogToAppButton(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: MaterialButton(
                        minWidth: 50.0,
                        //height: 30.0,
                        color: startFlashLogging ? Colors.red : Colors.white,
                        child: Row(
                          children: <Widget>[
                            startFlashLogging?Text('Stop Logging',
                                style: new TextStyle(
                                    fontSize: 16.0, color: Colors.white)):Text('Log to SD card',
                                style: new TextStyle(
                                    fontSize: 16.0, color: Colors.black)),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        onPressed: () async {
                          if (startFlashLogging == true) {
                            _sendEndLogtoFlashCommand();
                            setState(() {
                              startFlashLogging = false;
                            });
                          } else {
                            await Future.delayed(Duration(seconds: 1),
                                () async {
                              await setMTU(widget.currentDevice.id);
                            });
                            await Future.delayed(Duration(seconds: 1),
                                () async {
                              await startListeningData();
                            });
                            await sendStartSessionCommand();

                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: MaterialButton(
                        minWidth: 50.0,
                        color: Colors.white,
                        child: Row(
                          children: <Widget>[
                            Text('Get Logs',
                                style: new TextStyle(
                                    fontSize: 16.0, color: Colors.black)),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        onPressed: () async {
                          if (startStreaming == false) {
                            await Future.delayed(Duration(seconds: 1),
                                    () async {
                                  await setMTU(widget.currentDevice.id);
                                });
                            _sendSDCardStatusCheckCommand();
                            await Future.delayed(Duration(seconds: 1),
                                    () async {
                                  await startListeningData();
                                });
                            if(sdCardStatusCheck == true){
                              showSDCardNotFoundDialog();
                            }else{
                              Navigator.of(context)
                                  .pushReplacement(MaterialPageRoute(
                                  builder: (_) => FetchLogs(
                                    selectedBoard: widget.selectedBoard,
                                    selectedDevice: widget.selectedDevice,
                                    currentDevice: widget.currentDevice,
                                    fble: widget.fble,
                                    currConnection: widget.currConnection,
                                  )));
                            }

                          } else {
                            showStopStreamingDialog('Please stop streaming to view the logs.');
                          }
                        },
                      ),
                    ),
                    showSetTime(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: MaterialButton(
                        minWidth: 50.0,
                        //color: Colors.white,
                        color: Colors.red,
                        child: Row(
                          children: <Widget>[
                            Text('Disconnect',
                                style: new TextStyle(
                                    fontSize: 16.0, color: Colors.black)),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        onPressed: () async {
                          if (startFlashLogging == true &&
                              startAppLogging == false) {
                            startFlashLogging = false;
                            showEndFlashingDialog();
                          } else if (startAppLogging == true &&
                              startFlashLogging == false) {
                            startAppLogging = false;
                            writeLogDataToFile(
                                ecgDataLog, ppgDataLog, respDataLog, context);
                            closeAllStreams();
                            await _disconnect();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => HomePage(title: 'OpenView')),
                            );
                          } else if (startFlashLogging == true &&
                              startAppLogging == true) {
                            startAppLogging = false;
                            startFlashLogging = false;
                            writeLogDataToFile(
                                ecgDataLog, ppgDataLog, respDataLog, context);
                            showEndFlashingDialog();
                          } else {
                            closeAllStreams();
                            await _disconnect();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => HomePage(title: 'OpenView')),
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
      ]));
    } else {
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
            if (startAppLogging == true) {
              startAppLogging = false;
              writeLogDataToFile(ecgDataLog, ppgDataLog, respDataLog, context);
            } else {
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

  Future<void> _disconnect() async {
    try {
      hPi4Global().logConsole('Disconnecting ');
      if (connectedToDevice == true) {
        showLoadingIndicator("Disconnecting....", context);
        await Future.delayed(Duration(seconds: 4), () async {
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
      hPi4Global().logConsole("Error disconnecting from a device: $e");
    } finally {
      // Since [_connection] subscription is terminated, the "disconnected" state cannot be received and propagated
    }
  }

  Widget LogToAppButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: MaterialButton(
        minWidth: 50.0,
        color: startAppLogging ? Colors.grey : Colors.white,
        child: Row(
          children: <Widget>[
            Text('Log to App',
                style: new TextStyle(fontSize: 16.0, color: Colors.black)),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        onPressed: () async {
          if (startStreaming == true) {
            setState(() {
              startAppLogging = true;
            });
          } else {
            showStopStreamingDialog("Please start streaming to log to app");
          }
        },
      ),
    );
  }

  Widget StartAndStopButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: MaterialButton(
        minWidth: 50.0,
        color: startStreaming ? Colors.red : Colors.green,
        child: Row(
          children: <Widget>[
            startStreaming
                ? Text('Stop',
                    style: new TextStyle(fontSize: 16.0, color: Colors.white))
                : Text('Start',
                    style: new TextStyle(fontSize: 16.0, color: Colors.white)),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        onPressed: () async {
          if (startStreaming == false) {
            setState(() {
              startStreaming = true;
            });
            dataFormatBasedOnBoardsSelection();
          } else {
            closeAllStreams();
            ecgLineData.removeAt(0);
            ppgLineData.removeAt(0);
            respLineData.removeAt(0);
            setState(() {
              startStreaming = false;
            });
          }
        },
      ),
    );
  }

  Widget displayAppBarButtons() {
    if (widget.currentDevice.name.contains("healthypi move") ||
        widget.currentDevice.name.contains("healthypi")) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Row(children: <Widget>[
            Image.asset('assets/proto-online-white.png',
                fit: BoxFit.fitWidth, height: 30),
            displayDeviceName(),
            displayFlashStatus(),
          ]),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Column(children: <Widget>[
            Image.asset('assets/proto-online-white.png',
                fit: BoxFit.fitWidth, height: 30),
            displayDeviceName(),
          ]),
          LogToAppButton(),
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
        title: displayAppBarButtons(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              buildCharts(),
              //showPages(),
            ],
          ),
        ),
      ),
    );
  }
}
