import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'home.dart';
import 'globals.dart';
import 'utils/charts.dart';
import 'utils/variables.dart';
import 'utils/sizeConfig.dart';
import 'ble/ble_scanner.dart';
import 'utils/logDataToFile.dart';
import 'states/OpenViewBLEProvider.dart';
import 'package:flutter_switch/flutter_switch.dart';

class PlotSerialPage extends StatefulWidget {
  const PlotSerialPage({
    Key? key,
    required this.selectedPort,
    required this.selectedSerialPort,
    required this.selectedPortBoard,
  }) : super();

  final SerialPort selectedPort;
  final String selectedSerialPort;
  final String selectedPortBoard;

  @override
  _PlotSerialPageState createState() => _PlotSerialPageState();
}

class _PlotSerialPageState extends State<PlotSerialPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  Key key = UniqueKey();

  final ecgLineData = <FlSpot>[];
  final ppgLineData = <FlSpot>[];
  final respLineData = <FlSpot>[];

  final ecg1LineData = <FlSpot>[];
  final ecg2LineData = <FlSpot>[];

  List<double> ecgDataLog = [];
  List<double> ppgDataLog = [];
  List<double> respDataLog = [];

  double ecgDataCounter = 0;
  double ppgDataCounter = 0;
  double respDataCounter = 0;

  double ecg1DataCounter = 0;
  double ecg2DataCounter = 0;

  bool startDataLogging = false;
  bool startEEGStreaming = false;

  int globalHeartRate = 0;
  int globalSpO2 = 0;
  int globalRespRate = 0;
  double globalTemp = 0;
  String displaySpO2 = "--";

  final eeg1LineData = <FlSpot>[];
  final eeg2LineData = <FlSpot>[];
  final eeg3LineData = <FlSpot>[];
  final eeg4LineData = <FlSpot>[];
  final eeg5LineData = <FlSpot>[];
  final eeg6LineData = <FlSpot>[];
  final eeg7LineData = <FlSpot>[];
  final eeg8LineData = <FlSpot>[];

  double eeg1DataCounter = 0;
  double eeg2DataCounter = 0;
  double eeg3DataCounter = 0;
  double eeg4DataCounter = 0;
  double eeg5DataCounter = 0;
  double eeg6DataCounter = 0;
  double eeg7DataCounter = 0;
  double eeg8DataCounter = 0;

  final List<String> _selectY1Scale = ['10mm/mV', '5mm/mV', '20mm/mV'];
  String _selectedY1Scale = '10mm/mV';
  String _selectedY2Scale = '10mm/mV';
  String _selectedY3Scale = '10mm/mV';
  String _selectedY4Scale = '10mm/mV';
  String _selectedY5Scale = '10mm/mV';
  String _selectedY6Scale = '10mm/mV';
  String _selectedY7Scale = '10mm/mV';
  String _selectedY8Scale = '10mm/mV';

  bool selectedCH1 = false;
  bool selectedCH2 = false;
  bool selectedCH3 = false;
  bool selectedCH4 = false;
  bool selectedCH5 = false;
  bool selectedCH6 = false;
  bool selectedCH7 = false;
  bool selectedCH8 = false;

  final List<String> _selectChannel = [
    'Ch1',
    'Ch2',
    'Ch3',
    'Ch4',
    'Ch5',
    'Ch6',
    'Ch7',
    'Ch8'
  ];
  String _selectedChannel = 'Ch1';

  /// Configurable window size in seconds for plotting
  static const List<int> _windowSizeOptions = [3, 6, 9, 12];
  int _plotWindowSeconds = 6; // Default value

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    //_startSerialListening();
    startStreaming();
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

  void _showAlertDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Alert'),
          content: const SingleChildScrollView(
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
                      'Invalid Packet Length.',
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
              child: const Text('Ok'),
              onPressed: () async {
                //Navigator.pop(context);
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

  void startStreaming() {
    if (widget.selectedPortBoard == "Healthypi EEG") {
      if (startEEGStreaming == true) {
        _startSerialListening();
      } else {
        //Do Nothing;
      }
    } else {
      _startSerialListening();
    }
  }

  void _startSerialListening() async {
    print("AKW: Started listening to stream");

    final serialStream = SerialPortReader(widget.selectedPort);
    serialStream.stream.listen((event) {
      //print('R: $event');
      for (int i = 0; i < event.length; i++) {
        pcProcessData(event[i]);
      }
    });
  }

  void pcProcessData(int rxch) async {
    switch (pc_rx_state) {
      case CESState_Init:
        if (rxch == CES_CMDIF_PKT_START_1) {
          pc_rx_state = CESState_SOF1_Found;
        }
        break;
      case CESState_SOF1_Found:
        if (rxch == CES_CMDIF_PKT_START_2) {
          pc_rx_state = CESState_SOF2_Found;
        } else {
          pc_rx_state = CESState_Init; //Invalid Packet, reset state to init
        }
        break;
      case CESState_SOF2_Found:
        pc_rx_state = CESState_PktLen_Found;
        CES_Pkt_Len = rxch;
        CES_Pkt_Pos_Counter = CES_CMDIF_IND_LEN;
        CES_Data_Counter = 0;
        CES_ECG_RESP_Data_Counter = 0;
        CES_PPG_Data_Counter = 0;
        break;
      case CESState_PktLen_Found:
        CES_Pkt_Pos_Counter++;
        if (CES_Pkt_Pos_Counter < CES_CMDIF_PKT_OVERHEAD) //Read Header
        {
          if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_LEN_MSB) {
            CES_Pkt_Len = ((rxch << 8) | CES_Pkt_Len);
          } else if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_PKTTYPE) {
            CES_Pkt_PktType = rxch;
          }
        } else if ((CES_Pkt_Pos_Counter >= CES_CMDIF_PKT_OVERHEAD) &&
            (CES_Pkt_Pos_Counter <
                CES_CMDIF_PKT_OVERHEAD + CES_Pkt_Len + 1)) //Read Data
        {
          if (CES_Pkt_PktType == 2) {
            CES_Pkt_Data_Counter[CES_Data_Counter++] =
                (rxch); // Buffer that assigns the data separated from the packet
          } else if (CES_Pkt_PktType == 3) {
            CES_Pkt_ECG_RESP_Data_Counter[CES_ECG_RESP_Data_Counter++] = (rxch);
          } else if (CES_Pkt_PktType == 4) {
            CES_Pkt_PPG_Data_Counter[CES_PPG_Data_Counter++] = (rxch);
          } else {
            // Do nothing
          }
        } else //All data received
        {
          if (rxch == CES_CMDIF_PKT_STOP) {
            if (widget.selectedPortBoard == "Healthypi (USB)") {
              if (CES_Pkt_PktType == 4) {
                for (int i = 0; i < 8; i++) {
                  ces_pkt_ch3_buffer[0] = CES_Pkt_PPG_Data_Counter[(i * 2)];
                  ces_pkt_ch3_buffer[1] = CES_Pkt_PPG_Data_Counter[(i * 2) + 1];
                  int data3 =
                      ces_pkt_ch3_buffer[0] | ces_pkt_ch3_buffer[1] << 8;

                  setStateIfMounted(() {
                    ppgLineData
                        .add(FlSpot(ppgDataCounter++, ((data3).toDouble())));
                    if (startDataLogging == true) {
                      ppgDataLog.add((data3.toSigned(16)).toDouble());
                    }
                  });
                  if (ppgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                    ppgLineData.removeAt(0);
                  }
                }

                setStateIfMounted(() {
                  globalSpO2 = (CES_Pkt_PPG_Data_Counter[16]).toInt();
                  if (globalSpO2 == 25) {
                    displaySpO2 = "--";
                  } else {
                    displaySpO2 = "$globalSpO2 %";
                  }

                  globalTemp = (((CES_Pkt_PPG_Data_Counter[17] |
                                  CES_Pkt_PPG_Data_Counter[18] << 8)
                              .toInt()) /
                          100.00)
                      .toDouble();
                });
              }
              if (CES_Pkt_PktType == 3) {
                for (int i = 0; i < 8; i++) {
                  ces_pkt_ch1_buffer[0] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4)];
                  ces_pkt_ch1_buffer[1] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4) + 1];
                  ces_pkt_ch1_buffer[2] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4) + 2];
                  ces_pkt_ch1_buffer[3] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4) + 3];

                  int data1 = ces_pkt_ch1_buffer[0] |
                      ces_pkt_ch1_buffer[1] << 8 |
                      ces_pkt_ch1_buffer[2] << 16 |
                      ces_pkt_ch1_buffer[3] << 24;

                  setStateIfMounted(() {
                    ecgLineData.add(FlSpot(
                        ecgDataCounter++, ((data1.toSigned(32)).toDouble())));
                    if (startDataLogging == true) {
                      ecgDataLog.add((data1.toSigned(32)).toDouble());
                    }
                  });
                  if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                    ecgLineData.removeAt(0);
                  }
                }

                for (int i = 0; i < 4; i++) {
                  ces_pkt_ch2_buffer[0] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4) + 32];
                  ces_pkt_ch2_buffer[1] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4) + 33];
                  ces_pkt_ch2_buffer[2] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4) + 34];
                  ces_pkt_ch2_buffer[3] =
                      CES_Pkt_ECG_RESP_Data_Counter[(i * 4) + 35];

                  int data2 = ces_pkt_ch2_buffer[0] |
                      ces_pkt_ch2_buffer[1] << 8 |
                      ces_pkt_ch2_buffer[2] << 16 |
                      ces_pkt_ch2_buffer[3] << 24;

                  setStateIfMounted(() {
                    respLineData.add(FlSpot(
                        respDataCounter++, ((data2.toSigned(32)).toDouble())));
                    if (startDataLogging == true) {
                      respDataLog.add((data2.toSigned(32)).toDouble());
                    }
                  });
                  if (respDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                    respLineData.removeAt(0);
                  }
                }

                setStateIfMounted(() {
                  globalHeartRate = (CES_Pkt_ECG_RESP_Data_Counter[48]).toInt();
                  globalRespRate = (CES_Pkt_ECG_RESP_Data_Counter[49]).toInt();
                });
              } else if (CES_Pkt_PktType == 2) {
                ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
                ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];
                ces_pkt_ch1_buffer[2] = CES_Pkt_Data_Counter[2];
                ces_pkt_ch1_buffer[3] = CES_Pkt_Data_Counter[3];

                ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[4];
                ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[5];
                ces_pkt_ch2_buffer[2] = CES_Pkt_Data_Counter[6];
                ces_pkt_ch2_buffer[3] = CES_Pkt_Data_Counter[7];

                ces_pkt_ch3_buffer[0] = CES_Pkt_Data_Counter[9]; //ir
                ces_pkt_ch3_buffer[1] = CES_Pkt_Data_Counter[10];
                ces_pkt_ch3_buffer[2] = CES_Pkt_Data_Counter[11];
                ces_pkt_ch3_buffer[3] = CES_Pkt_Data_Counter[12];

                int data1 = ces_pkt_ch1_buffer[0] |
                    ces_pkt_ch1_buffer[1] << 8 |
                    ces_pkt_ch1_buffer[2] << 16 |
                    ces_pkt_ch1_buffer[3] << 24;
                int data2 = ces_pkt_ch2_buffer[0] |
                    ces_pkt_ch2_buffer[1] << 8 |
                    ces_pkt_ch2_buffer[2] << 16 |
                    ces_pkt_ch2_buffer[3] << 24;
                int data3 = ces_pkt_ch3_buffer[0] |
                    ces_pkt_ch3_buffer[1] << 8 |
                    ces_pkt_ch3_buffer[2] << 16 |
                    ces_pkt_ch3_buffer[3] << 24;

                setStateIfMounted(() {
                  ecgLineData.add(FlSpot(
                      ecgDataCounter++, ((data1.toSigned(32)).toDouble())));
                  respLineData.add(FlSpot(
                      respDataCounter++, (data2.toSigned(32).toDouble())));
                  ppgLineData.add(FlSpot(
                      ppgDataCounter++, (data3.toSigned(32).toDouble())));

                  if (startDataLogging == true) {
                    ecgDataLog.add((data1.toSigned(32)).toDouble());
                    ppgDataLog.add(data3.toDouble());
                    respDataLog.add(data2.toDouble());
                  }

                  globalSpO2 = (CES_Pkt_Data_Counter[19]).toInt();
                  if (globalSpO2 == 25) {
                    displaySpO2 = "--";
                  } else {
                    displaySpO2 = "$globalSpO2 %";
                  }
                  globalHeartRate = (CES_Pkt_Data_Counter[20]).toInt();
                  globalRespRate = (CES_Pkt_Data_Counter[21]).toInt();
                  globalTemp = (((CES_Pkt_Data_Counter[17] |
                                  CES_Pkt_Data_Counter[18] << 8)
                              .toInt()) /
                          100.00)
                      .toDouble();
                });
                if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                  ecgLineData.removeAt(0);
                  ppgLineData.removeAt(0);
                }
                if (respDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                  respLineData.removeAt(0);
                }
              } else {
                if (CES_Pkt_PktType == 2 ||
                    CES_Pkt_PktType == 3 ||
                    CES_Pkt_PktType == 4) {
                  // Do nothing
                } else {
                  if (widget.selectedPort.isOpen) {
                    widget.selectedPort.close();
                    _showAlertDialog();
                  }
                }
              }

              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "Healthypi 6 (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0]; // ecg 1
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];
              ces_pkt_ch1_buffer[2] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch1_buffer[3] = CES_Pkt_Data_Counter[3];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[4]; // ecg 2
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[5];
              ces_pkt_ch2_buffer[2] = CES_Pkt_Data_Counter[6];
              ces_pkt_ch2_buffer[3] = CES_Pkt_Data_Counter[7];

              ces_pkt_ch3_buffer[0] = CES_Pkt_Data_Counter[8]; // ecg 3
              ces_pkt_ch3_buffer[1] = CES_Pkt_Data_Counter[9];
              ces_pkt_ch3_buffer[2] = CES_Pkt_Data_Counter[10];
              ces_pkt_ch3_buffer[3] = CES_Pkt_Data_Counter[11];

              ces_pkt_ch4_buffer[0] = CES_Pkt_Data_Counter[12]; // resp
              ces_pkt_ch4_buffer[1] = CES_Pkt_Data_Counter[13];
              ces_pkt_ch4_buffer[2] = CES_Pkt_Data_Counter[14];
              ces_pkt_ch4_buffer[3] = CES_Pkt_Data_Counter[15];

              ces_pkt_ch5_buffer[0] = CES_Pkt_Data_Counter[16]; // ir
              ces_pkt_ch5_buffer[1] = CES_Pkt_Data_Counter[17];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] << 8 |
                  ces_pkt_ch1_buffer[2] << 16 |
                  ces_pkt_ch1_buffer[3] << 24;

              int data2 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] << 8 |
                  ces_pkt_ch2_buffer[2] << 16 |
                  ces_pkt_ch2_buffer[3] << 24;

              int data3 = ces_pkt_ch3_buffer[0] |
                  ces_pkt_ch3_buffer[1] << 8 |
                  ces_pkt_ch3_buffer[2] << 16 |
                  ces_pkt_ch3_buffer[3] << 24;

              int data4 = ces_pkt_ch4_buffer[0] |
                  ces_pkt_ch4_buffer[1] << 8 |
                  ces_pkt_ch4_buffer[2] << 16 |
                  ces_pkt_ch4_buffer[3] << 24;

              int data5 = ces_pkt_ch5_buffer[0] | ces_pkt_ch5_buffer[1] << 8;

              setStateIfMounted(() {
                ecgLineData.add(FlSpot(
                    ecgDataCounter++, ((data1.toSigned(32)).toDouble())));
                ecg1LineData.add(FlSpot(
                    ecg1DataCounter++, ((data2.toSigned(32)).toDouble())));
                ecg2LineData.add(FlSpot(
                    ecg2DataCounter++, ((data3.toSigned(32)).toDouble())));
                respLineData.add(
                    FlSpot(respDataCounter++, (data4.toSigned(32).toDouble())));
                ppgLineData.add(
                    FlSpot(ppgDataCounter++, (data5.toSigned(16).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add((data1.toSigned(32)).toDouble());
                  ppgDataLog.add(data5.toDouble());
                  respDataLog.add(data4.toDouble());
                }

                if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                  ecgLineData.removeAt(0);
                  ecg1LineData.removeAt(0);
                  ecg2LineData.removeAt(0);
                  ppgLineData.removeAt(0);
                }
                if (respDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                  respLineData.removeAt(0);
                }
              });

              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "Healthypi EEG") {
              ces_pkt_eeg1_buffer[0] = CES_Pkt_Data_Counter[3];
              ces_pkt_eeg1_buffer[1] = CES_Pkt_Data_Counter[4];
              ces_pkt_eeg1_buffer[2] = CES_Pkt_Data_Counter[5];

              ces_pkt_eeg2_buffer[0] = CES_Pkt_Data_Counter[6];
              ces_pkt_eeg2_buffer[1] = CES_Pkt_Data_Counter[7];
              ces_pkt_eeg2_buffer[2] = CES_Pkt_Data_Counter[8];

              ces_pkt_eeg3_buffer[0] = CES_Pkt_Data_Counter[9];
              ces_pkt_eeg3_buffer[1] = CES_Pkt_Data_Counter[10];
              ces_pkt_eeg3_buffer[2] = CES_Pkt_Data_Counter[11];

              ces_pkt_eeg4_buffer[0] = CES_Pkt_Data_Counter[12];
              ces_pkt_eeg4_buffer[1] = CES_Pkt_Data_Counter[13];
              ces_pkt_eeg4_buffer[2] = CES_Pkt_Data_Counter[14];

              ces_pkt_eeg5_buffer[0] = CES_Pkt_Data_Counter[15];
              ces_pkt_eeg5_buffer[1] = CES_Pkt_Data_Counter[16];
              ces_pkt_eeg5_buffer[2] = CES_Pkt_Data_Counter[17];

              ces_pkt_eeg6_buffer[0] = CES_Pkt_Data_Counter[18];
              ces_pkt_eeg6_buffer[1] = CES_Pkt_Data_Counter[19];
              ces_pkt_eeg6_buffer[2] = CES_Pkt_Data_Counter[20];

              ces_pkt_eeg7_buffer[0] = CES_Pkt_Data_Counter[21];
              ces_pkt_eeg7_buffer[1] = CES_Pkt_Data_Counter[22];
              ces_pkt_eeg7_buffer[2] = CES_Pkt_Data_Counter[23];

              ces_pkt_eeg8_buffer[0] = CES_Pkt_Data_Counter[24];
              ces_pkt_eeg8_buffer[1] = CES_Pkt_Data_Counter[25];
              ces_pkt_eeg8_buffer[2] = CES_Pkt_Data_Counter[26];

              int data1 = ces_pkt_eeg1_buffer[0] |
                  ces_pkt_eeg1_buffer[1] << 8 |
                  ces_pkt_eeg1_buffer[2] << 16;

              int data2 = ces_pkt_eeg2_buffer[0] |
                  ces_pkt_eeg2_buffer[1] << 8 |
                  ces_pkt_eeg2_buffer[2] << 16;

              int data3 = ces_pkt_eeg3_buffer[0] |
                  ces_pkt_eeg3_buffer[1] << 8 |
                  ces_pkt_eeg3_buffer[2] << 16;

              int data4 = ces_pkt_eeg4_buffer[0] |
                  ces_pkt_eeg4_buffer[1] << 8 |
                  ces_pkt_eeg4_buffer[2] << 16;

              int data5 = ces_pkt_eeg5_buffer[0] |
                  ces_pkt_eeg5_buffer[1] << 8 |
                  ces_pkt_eeg5_buffer[2] << 16;

              int data6 = ces_pkt_eeg6_buffer[0] |
                  ces_pkt_eeg6_buffer[1] << 8 |
                  ces_pkt_eeg6_buffer[2] << 16;

              int data7 = ces_pkt_eeg7_buffer[0] |
                  ces_pkt_eeg7_buffer[1] << 8 |
                  ces_pkt_eeg7_buffer[2] << 16;

              int data8 = ces_pkt_eeg8_buffer[0] |
                  ces_pkt_eeg8_buffer[1] << 8 |
                  ces_pkt_eeg8_buffer[2] << 16;

              setStateIfMounted(() {
                eeg1LineData.add(
                    FlSpot(eeg1DataCounter++, (data1.toSigned(32).toDouble())));
                eeg2LineData.add(
                    FlSpot(eeg2DataCounter++, (data2.toSigned(32).toDouble())));
                eeg3LineData.add(
                    FlSpot(eeg3DataCounter++, (data3.toSigned(32).toDouble())));
                eeg4LineData.add(
                    FlSpot(eeg4DataCounter++, (data4.toSigned(32).toDouble())));
                eeg5LineData.add(
                    FlSpot(eeg5DataCounter++, (data5.toSigned(32).toDouble())));
                eeg6LineData.add(
                    FlSpot(eeg6DataCounter++, (data6.toSigned(32).toDouble())));
                eeg7LineData.add(
                    FlSpot(eeg7DataCounter++, (data7.toSigned(32).toDouble())));
                eeg8LineData.add(
                    FlSpot(eeg8DataCounter++, (data8.toSigned(32).toDouble())));
              });
              if (eeg1DataCounter >= boardSamplingRate * _plotWindowSeconds) {
                eeg1LineData.removeAt(0);
                eeg2LineData.removeAt(0);
                eeg3LineData.removeAt(0);
                eeg4LineData.removeAt(0);
                eeg5LineData.removeAt(0);
                eeg6LineData.removeAt(0);
                eeg7LineData.removeAt(0);
                eeg8LineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard ==
                "ADS1292R Breakout/Shield (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[3];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              data1 <<= 16;
              data1 >>= 16;

              int data2 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              data2 <<= 16;
              data2 >>= 16;

              computed_val1 = CES_Pkt_Data_Counter[4] |
                  CES_Pkt_Data_Counter[5] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              computed_val1 <<= 16;
              computed_val1 >>= 16;

              computed_val2 = CES_Pkt_Data_Counter[6] |
                  CES_Pkt_Data_Counter[7] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              computed_val2 <<= 16;
              computed_val2 >>= 16;

              setStateIfMounted(() {
                ecgLineData.add(
                    FlSpot(ecgDataCounter++, (data1.toSigned(16).toDouble())));
                respLineData.add(
                    FlSpot(respDataCounter++, (data2.toSigned(16).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  respDataLog.add(data2.toDouble());
                }

                globalHeartRate = (computed_val1).toInt();
                globalRespRate = (computed_val2).toInt();
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
              }
              if (respDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                respLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard ==
                "ADS1293 Breakout/Shield (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];
              ces_pkt_ch1_buffer[2] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch1_buffer[3] = CES_Pkt_Data_Counter[3];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[4];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[5];
              ces_pkt_ch2_buffer[2] = CES_Pkt_Data_Counter[6];
              ces_pkt_ch2_buffer[3] = CES_Pkt_Data_Counter[7];

              ces_pkt_ch3_buffer[0] = CES_Pkt_Data_Counter[8];
              ces_pkt_ch3_buffer[1] = CES_Pkt_Data_Counter[9];
              ces_pkt_ch3_buffer[2] = CES_Pkt_Data_Counter[10];
              ces_pkt_ch3_buffer[3] = CES_Pkt_Data_Counter[11];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] << 8 |
                  ces_pkt_ch1_buffer[2] << 16 |
                  ces_pkt_ch1_buffer[3] << 24;

              int data2 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] << 8 |
                  ces_pkt_ch2_buffer[2] << 16 |
                  ces_pkt_ch2_buffer[3] << 24;

              int data3 = ces_pkt_ch3_buffer[0] |
                  ces_pkt_ch3_buffer[1] << 8 |
                  ces_pkt_ch3_buffer[2] << 16 |
                  ces_pkt_ch3_buffer[3] << 24;
              setStateIfMounted(() {
                ecgLineData.add(FlSpot(
                    ecgDataCounter++, ((data1.toSigned(32)).toDouble())));
                respLineData.add(
                    FlSpot(respDataCounter++, (data2.toSigned(32).toDouble())));
                ppgLineData.add(
                    FlSpot(ppgDataCounter++, (data3.toSigned(32).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add((data1.toSigned(32) / 1000.00).toDouble());
                  ppgDataLog.add(data3.toDouble());
                  respDataLog.add(data2.toDouble());
                }
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
                ppgLineData.removeAt(0);
              }
              if (respDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                respLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard ==
                    "AFE4490 Breakout/Shield (USB)" ||
                widget.selectedPortBoard == "Sensything Ox (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];
              ces_pkt_ch1_buffer[2] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch1_buffer[3] = CES_Pkt_Data_Counter[3];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[4];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[5];
              ces_pkt_ch2_buffer[2] = CES_Pkt_Data_Counter[6];
              ces_pkt_ch2_buffer[3] = CES_Pkt_Data_Counter[7];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] << 8 |
                  ces_pkt_ch1_buffer[2] << 16 |
                  ces_pkt_ch1_buffer[3] << 24;

              int data2 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] << 8 |
                  ces_pkt_ch2_buffer[2] << 16 |
                  ces_pkt_ch2_buffer[3] << 24;

              computed_val1 = CES_Pkt_Data_Counter[8];
              computed_val2 = CES_Pkt_Data_Counter[9];

              setStateIfMounted(() {
                ecgLineData.add(FlSpot(ecgDataCounter++, (data1.toDouble())));
                ppgLineData.add(FlSpot(ppgDataCounter++, (data2.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  ppgDataLog.add(data2.toDouble());
                }

                globalHeartRate = (computed_val2).toInt();
                globalSpO2 = (computed_val1).toInt();
                if (globalSpO2 == 25) {
                  displaySpO2 = "--";
                } else {
                  displaySpO2 = "$globalSpO2 %";
                }
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
                ppgLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "MAX86150 Breakout (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[3];

              ces_pkt_ch3_buffer[0] = CES_Pkt_Data_Counter[4];
              ces_pkt_ch3_buffer[1] = CES_Pkt_Data_Counter[5];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              data1 <<= 16;
              data1 >>= 16;

              int data2 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              data2 <<= 16;
              data2 >>= 16;

              int data3 = ces_pkt_ch3_buffer[0] |
                  ces_pkt_ch3_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              data3 <<= 16;
              data3 >>= 16;

              setStateIfMounted(() {
                ecgLineData.add(
                    FlSpot(ecgDataCounter++, (data1.toSigned(16).toDouble())));
                respLineData.add(FlSpot(respDataCounter++, (data2.toDouble())));
                ppgLineData.add(FlSpot(ppgDataCounter++, (data3.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  ppgDataLog.add(data3.toDouble());
                  respDataLog.add(data2.toDouble());
                }
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
                ppgLineData.removeAt(0);
                respLineData.removeAt(0);
              }

              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "Pulse Express (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[3];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);
              int data2 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);

              setStateIfMounted(() {
                ecgLineData.add(FlSpot(ecgDataCounter++, (data1.toDouble())));
                respLineData.add(FlSpot(respDataCounter++, (data2.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  respDataLog.add(data2.toDouble());
                }
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
                respLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "tinyGSR Breakout (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);

              setStateIfMounted(() {
                ecgLineData.add(
                    FlSpot(ecgDataCounter++, (data1.toSigned(16).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                }
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
              }

              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard ==
                "MAX30003 ECG Breakout (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];
              ces_pkt_ch1_buffer[2] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch1_buffer[3] = CES_Pkt_Data_Counter[3];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[4];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[5];
              ces_pkt_ch2_buffer[2] = CES_Pkt_Data_Counter[6];
              ces_pkt_ch2_buffer[3] = CES_Pkt_Data_Counter[7];

              ces_pkt_ch3_buffer[0] = CES_Pkt_Data_Counter[8];
              ces_pkt_ch3_buffer[1] = CES_Pkt_Data_Counter[9];
              ces_pkt_ch3_buffer[2] = CES_Pkt_Data_Counter[10];
              ces_pkt_ch3_buffer[3] = CES_Pkt_Data_Counter[11];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] << 8 |
                  ces_pkt_ch1_buffer[2] << 16 |
                  ces_pkt_ch1_buffer[3] << 24;

              int computedVal1 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] << 8 |
                  ces_pkt_ch2_buffer[2] << 16 |
                  ces_pkt_ch2_buffer[3] << 24;
              int computedVal2 = ces_pkt_ch3_buffer[0] |
                  ces_pkt_ch3_buffer[1] << 8 |
                  ces_pkt_ch3_buffer[2] << 16 |
                  ces_pkt_ch3_buffer[3] << 24;

              setStateIfMounted(() {
                ecgLineData.add(FlSpot(
                    ecgDataCounter++, ((data1.toSigned(32)).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add((data1.toSigned(32) / 1000.00).toDouble());
                }
                globalHeartRate = (computedVal2).toInt();
                globalRespRate = (computedVal1).toInt();
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard ==
                "MAX30001 ECG & BioZ Breakout (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];
              ces_pkt_ch1_buffer[2] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch1_buffer[3] = CES_Pkt_Data_Counter[3];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[4];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[5];
              ces_pkt_ch2_buffer[2] = CES_Pkt_Data_Counter[6];
              ces_pkt_ch2_buffer[3] = CES_Pkt_Data_Counter[7];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] << 8 |
                  ces_pkt_ch1_buffer[2] << 16 |
                  ces_pkt_ch1_buffer[3] << 24;

              int data2 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] << 8 |
                  ces_pkt_ch2_buffer[2] << 16 |
                  ces_pkt_ch2_buffer[3] << 24;

              setStateIfMounted(() {
                ecgLineData.add(
                    FlSpot(ecgDataCounter++, (data1.toSigned(32).toDouble())));
                ppgLineData.add(
                    FlSpot(ppgDataCounter++, (data2.toSigned(32).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  ppgDataLog.add(data2.toDouble());
                }
              });
              if (ecgDataCounter >= boardSamplingRate * _plotWindowSeconds) {
                ecgLineData.removeAt(0);
                ppgLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            }
          } else {
            pc_rx_state = CESState_Init;
          }
        }
        break;
      default:
        break;
    }
  }

  Widget displayHeartRateValue() {
    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          color: Colors.transparent,
          child: const Text(
            "HEART RATE ",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          color: Colors.transparent,
          child: Text(
            "$globalHeartRate bpm",
            style: const TextStyle(
              fontSize: 20,
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
          child: const Text(
            "RESPIRATION RATE ",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          color: Colors.transparent,
          child: Text(
            "$globalRespRate rpm",
            style: const TextStyle(
              fontSize: 20,
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
          child: const Text(
            "SPO2 ",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          color: Colors.transparent,
          child: Text(
            displaySpO2,
            style: const TextStyle(
              fontSize: 20,
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
          child: const Text(
            "TEMPERATURE ",
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          color: Colors.transparent,
          child: Text(
            "${globalTemp.toStringAsPrecision(3)}\u00b0 C",
            style: const TextStyle(
              fontSize: 20,
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

  Widget displayCharts() {
    if (widget.selectedPortBoard == "Healthypi (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(18, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildPlots().buildChart(18, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
          buildPlots().buildChart(18, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
          displayTemperatureValue(),
        ],
      );
    } else if (widget.selectedPortBoard == "Healthypi 6 (USB)") {
      return Column(
        children: [
          buildPlots().buildChart(13, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(13, 95, ecg1LineData, Colors.yellow),
          sizedBoxForCharts(),
          buildPlots().buildChart(13, 95, ecg2LineData, Colors.orange),
          sizedBoxForCharts(),
          buildPlots().buildChart(13, 95, ppgLineData, Colors.red),
          sizedBoxForCharts(),
          buildPlots().buildChart(13, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedPortBoard == "Healthypi EEG") {
      if (startEEGStreaming == true) {
        return Column(
          children: [
            buildPlots().buildChart(8, 95, eeg1LineData, Colors.green),
            sizedBoxForCharts(),
            buildPlots().buildChart(8, 95, eeg2LineData, Colors.blue),
            sizedBoxForCharts(),
            buildPlots().buildChart(8, 95, eeg3LineData, Colors.yellow),
            sizedBoxForCharts(),
            buildPlots().buildChart(9, 95, eeg4LineData, Colors.green),
            sizedBoxForCharts(),
            buildPlots().buildChart(8, 95, eeg5LineData, Colors.blue),
            sizedBoxForCharts(),
            buildPlots().buildChart(8, 95, eeg6LineData, Colors.yellow),
            sizedBoxForCharts(),
            buildPlots().buildChart(8, 95, eeg7LineData, Colors.green),
            sizedBoxForCharts(),
            buildPlots().buildChart(8, 95, eeg8LineData, Colors.blue),
          ],
        );
      } else {
        return Column(
          children: [
            Row(children: [gainOption(9, 15, 1), ChannelStatus(9, 15, 1)]),
            sizedBoxForCharts(),
            Row(children: [gainOption(9, 15, 2), ChannelStatus(9, 15, 2)]),
            sizedBoxForCharts(),
            Row(children: [gainOption(9, 15, 3), ChannelStatus(9, 15, 3)]),
            sizedBoxForCharts(),
            Row(children: [gainOption(9, 15, 4), ChannelStatus(9, 15, 4)]),
            sizedBoxForCharts(),
            Row(children: [gainOption(9, 15, 5), ChannelStatus(9, 15, 5)]),
            sizedBoxForCharts(),
            Row(children: [gainOption(9, 15, 6), ChannelStatus(9, 15, 6)]),
            sizedBoxForCharts(),
            Row(children: [gainOption(9, 15, 7), ChannelStatus(9, 15, 7)]),
            sizedBoxForCharts(),
            Row(children: [gainOption(9, 15, 8), ChannelStatus(9, 15, 8)]),
          ],
        );
      }
    } else if (widget.selectedPortBoard == "ADS1292R Breakout/Shield (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(29, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
          buildPlots().buildChart(28, 95, respLineData, Colors.blue),
        ],
      );
    } else if (widget.selectedPortBoard == "ADS1293 Breakout/Shield (USB)") {
      return Column(
        children: [
          buildPlots().buildChart(23, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(23, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          buildPlots().buildChart(23, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedPortBoard == "AFE4490 Breakout/Shield (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(30, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildPlots().buildChart(30, 95, ppgLineData, Colors.yellow),
        ],
      );
    } else if (widget.selectedPortBoard == "Sensything Ox (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(30, 95, ecgLineData, Colors.red),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildPlots().buildChart(30, 95, ppgLineData, Colors.yellow),
        ],
      );
    } else if (widget.selectedPortBoard == "MAX86150 Breakout (USB)") {
      return Column(
        children: [
          buildPlots().buildChart(23, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(23, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          buildPlots().buildChart(23, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedPortBoard == "Pulse Express (USB)") {
      return Column(
        children: [
          buildPlots().buildChart(32, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(32, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedPortBoard == "tinyGSR Breakout (USB)") {
      return Column(
        children: [
          buildPlots().buildChart(65, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedPortBoard == "MAX30003 ECG Breakout (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(54, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
        ],
      );
    } else if (widget.selectedPortBoard ==
        "MAX30001 ECG & BioZ Breakout (USB)") {
      return Column(
        children: [
          buildPlots().buildChart(32, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(32, 95, ppgLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else {
      return Container();
    }
  }

  Widget displayDeviceName() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Connected To:    ${widget.selectedSerialPort}/ ${widget.selectedPortBoard}",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharts() {
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
                ],
              ),
            )));
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          onPressed: () async {
            if (widget.selectedPort.isOpen) {
              widget.selectedPort.close();
            }
            if (startDataLogging == true) {
              startDataLogging = false;
              startEEGStreaming = false;
              writeLogDataToFile(ecgDataLog, ppgDataLog, respDataLog, context);
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomePage(title: 'OpenView')),
              );
            }
          },
          child: const Row(
            children: <Widget>[
              Text('Stop',
                  style: TextStyle(fontSize: 18.0, color: Colors.white)),
            ],
          ),
        ),
      );
    });
  }

  Widget displayStartEEGButton() {
    if (widget.selectedPortBoard == "Healthypi EEG") {
      return Consumer3<BleScannerState, BleScanner, OpenViewBLEProvider>(
          builder: (context, bleScannerState, bleScanner, wiserBle, child) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MaterialButton(
            minWidth: 100.0,
            color: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            onPressed: () async {
              if (widget.selectedPort.isOpen) {
                setState(() {
                  startEEGStreaming = true;
                });
                startStreaming();
              }
            },
            child: const Row(
              children: <Widget>[
                Text('Start',
                    style: TextStyle(fontSize: 18.0, color: Colors.white)),
              ],
            ),
          ),
        );
      });
    } else {
      return Container();
    }
  }

  Widget ChannelStatus(int vertical, int horizontal, int channel) {
    return Container(
        height: SizeConfig.blockSizeVertical * vertical,
        width: SizeConfig.blockSizeHorizontal * horizontal,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: <Widget>[
            Text("CH$channel",
                style: const TextStyle(fontSize: 12.0, color: Colors.white)),
            channelSwitch(channel)
          ]),
        ));
  }

  Widget gainOption(int vertical, int horizontal, int channel) {
    return Container(
        height: SizeConfig.blockSizeVertical * vertical,
        width: SizeConfig.blockSizeHorizontal * horizontal,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: <Widget>[
            const Text("Gain:   ",
                style: TextStyle(fontSize: 12.0, color: Colors.white)),
            gainDropdown(channel)
          ]),
        ));
  }

  Widget gainDropdown(int channel) {
    if (channel == 1) {
      return DropdownButton(
        value: _selectedY1Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY1Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    } else if (channel == 2) {
      return DropdownButton(
        value: _selectedY2Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY2Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    } else if (channel == 3) {
      return DropdownButton(
        value: _selectedY3Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY3Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    } else if (channel == 4) {
      return DropdownButton(
        value: _selectedY4Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY4Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    } else if (channel == 5) {
      return DropdownButton(
        value: _selectedY5Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY5Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    } else if (channel == 6) {
      return DropdownButton(
        value: _selectedY6Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY6Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    } else if (channel == 7) {
      return DropdownButton(
        value: _selectedY7Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY7Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    } else if (channel == 8) {
      return DropdownButton(
        value: _selectedY8Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY8Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            value: location,
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
          );
        }).toList(),
      );
    }
    // Default fallback to avoid returning null
    return DropdownButton(
      value: _selectedY1Scale,
      onChanged: (newValue) {
        setState(() {
          _selectedY1Scale = newValue!;
        });
      },
      items: _selectY1Scale.map((location) {
        return DropdownMenuItem(
          value: location,
          child: Text(location,
              style: const TextStyle(fontSize: 14.0, color: Colors.white)),
        );
      }).toList(),
    );
  }

  Widget channelSwitch(int channel) {
    if (channel == 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 4.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH1,
            onToggle: (value) {
              setState(() {
                selectedCH1 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH1',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else if (channel == 2) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 2.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH2,
            onToggle: (value) {
              setState(() {
                selectedCH2 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH2',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else if (channel == 3) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 4.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH3,
            onToggle: (value) {
              setState(() {
                selectedCH3 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH3',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else if (channel == 4) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 4.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH4,
            onToggle: (value) {
              setState(() {
                selectedCH4 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH4',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else if (channel == 5) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 4.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH5,
            onToggle: (value) {
              setState(() {
                selectedCH5 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH5',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else if (channel == 6) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 4.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH6,
            onToggle: (value) {
              setState(() {
                selectedCH6 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH6',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else if (channel == 7) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 4.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH7,
            onToggle: (value) {
              setState(() {
                selectedCH7 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH7',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else if (channel == 8) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlutterSwitch(
            height: 20.0,
            width: 40.0,
            padding: 4.0,
            toggleSize: 15.0,
            borderRadius: 10.0,
            activeColor: Colors.green,
            value: selectedCH8,
            onToggle: (value) {
              setState(() {
                selectedCH8 = value;
              });
            },
          ),
          //SizedBox(height: 12.0,),
          Text(
            'Value : $selectedCH8',
            style: const TextStyle(color: Colors.black, fontSize: 20.0),
          )
        ],
      );
    } else {
      return Container();
    }
  }

  Widget selectChannelOption() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: <Widget>[
        const Text("Channel:   ",
            style: TextStyle(fontSize: 12.0, color: Colors.white)),
        DropdownButton(
          value: _selectedChannel,
          onChanged: (newValue) {
            setState(() {
              _selectedChannel = newValue!;
            });
          },
          items: _selectChannel.map((location) {
            return DropdownMenuItem(
              value: location,
              child: Text(location,
                  style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            );
          }).toList(),
        ),
      ]),
    );
  }

  /// Returns the sampling rate based on the selected board.
  int get boardSamplingRate {
    switch (widget.selectedPortBoard) {
      case "Healthypi (USB)":
      case "Healthypi EEG":
        return 128;
      case "Healthypi 6 (USB)":
        return 250;
      case "ADS1292R Breakout/Shield (USB)":
      case "ADS1293 Breakout/Shield (USB)":
      case "AFE4490 Breakout/Shield (USB)":
      case "Sensything Ox (USB)":
      case "MAX86150 Breakout (USB)":
      case "Pulse Express (USB)":
      case "tinyGSR Breakout (USB)":
      case "MAX30003 ECG Breakout (USB)":
      case "MAX30001 ECG & BioZ Breakout (USB)":
        return 128;
      default:
        return 128; // fallback default
    }
  }

  /// Toolbar widget for controls above the charts
  Widget buildToolbar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Window size dropdown
          Row(
            children: [
              const Text(
                "Window: ",
                style: TextStyle(fontSize: 14.0, color: Colors.white),
              ),
              DropdownButton<int>(
                dropdownColor: hPi4Global.hpi4Color,
                value: _plotWindowSeconds,
                style: const TextStyle(color: Colors.white, fontSize: 14.0),
                underline: Container(height: 1, color: Colors.white),
                items: _windowSizeOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text("$value secs",
                        style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _plotWindowSeconds = newValue!;
                  });
                },
              ),
            ],
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      backgroundColor: hPi4Global.appBackgroundColor,
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: hPi4Global.hpi4Color,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Image.asset('assets/proto-online-white.png',
                fit: BoxFit.fitWidth, height: 30),
            SizedBox(
              width: SizeConfig.blockSizeHorizontal * 5,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: MaterialButton(
                minWidth: 80.0,
                color: startDataLogging ? Colors.grey : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                onPressed: () async {
                  setState(() {
                    startDataLogging = true;
                  });
                },
                child: const Row(
                  children: <Widget>[
                    Text('Start Logging',
                        style: TextStyle(
                            fontSize: 16.0, color: hPi4Global.hpi4Color)),
                  ],
                ),
              ),
            ),
            // --- Window size dropdown removed from here ---
            displayDeviceName(),
            displayStartEEGButton(),
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
              buildToolbar(), // <-- Toolbar added here
              _buildCharts(),
            ],
          ),
        ),
      ),
    );
  }
}
