import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
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

class PlotSerialPage extends StatefulWidget {
  PlotSerialPage({
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

  bool startDataLogging = false;

  int globalHeartRate = 0;
  int globalSpO2 = 0;
  int globalRespRate = 0;
  double globalTemp = 0;
  String displaySpO2 = "--";

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _startSerialListening();
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

  void _startSerialListening() async {
    print("AKW: Started listening to stream");

    final _serialStream = SerialPortReader(widget.selectedPort);
    _serialStream.stream.listen((event) {
     print('R: $event');
      for (int i = 0; i < event.length; i++) {
        pcProcessData(event[i]);
      }
    });
  }

  void pcProcessData(int rxch) async {
    // print("data receiving:"+rxch.toString());
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
          if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_LEN_MSB)
            CES_Pkt_Len = ((rxch << 8) | CES_Pkt_Len);
          else if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_PKTTYPE)
            CES_Pkt_PktType = rxch;
        } else if ((CES_Pkt_Pos_Counter >= CES_CMDIF_PKT_OVERHEAD) &&
            (CES_Pkt_Pos_Counter < CES_CMDIF_PKT_OVERHEAD + CES_Pkt_Len + 1)) //Read Data
        {
          if (CES_Pkt_PktType == 2) {
            CES_Pkt_Data_Counter[CES_Data_Counter++] = (rxch); // Buffer that assigns the data separated from the packet
          } else if (CES_Pkt_PktType == 3) {
            CES_Pkt_ECG_RESP_Data_Counter[CES_ECG_RESP_Data_Counter++] = (rxch);
          } else if (CES_Pkt_PktType == 4) {
            CES_Pkt_PPG_Data_Counter[CES_PPG_Data_Counter++] = (rxch);
          }else{

          }
        } else //All data received
        {
          if (rxch == CES_CMDIF_PKT_STOP) {
            if (widget.selectedPortBoard == "Healthypi") {
              //print("packet length: " + CES_Pkt_Len.toString());
              //if(CES_Pkt_Len == 69){
              if (CES_Pkt_PktType == 4) {
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
                  if (ecgDataCounter >= 128 * 6) {
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
                  if (respDataCounter >= 256 * 6) {
                    respLineData.removeAt(0);
                  }
                }

                for (int i = 0; i < 8; i++) {
                  ces_pkt_ch3_buffer[0] = CES_Pkt_PPG_Data_Counter[(i * 2) ];
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
                  if (ppgDataCounter >= 128 * 6) {
                    ppgLineData.removeAt(0);
                  }
                }

                setStateIfMounted(() {
                  globalHeartRate = (CES_Pkt_ECG_RESP_Data_Counter[48]).toInt();
                  globalRespRate = (CES_Pkt_ECG_RESP_Data_Counter[49]).toInt();
                  globalSpO2 = (CES_Pkt_PPG_Data_Counter[16]).toInt();
                  if (globalSpO2 == 25) {
                    displaySpO2 = "--";
                  } else {
                    displaySpO2 = globalSpO2.toString() + " %";
                  }

                  globalTemp = (((CES_Pkt_PPG_Data_Counter[17] |
                  CES_Pkt_PPG_Data_Counter[18] << 8)
                      .toInt()) /
                      100.00)
                      .toDouble();
                });
              }
              //else if(CES_Pkt_Len == 20) {
              else if (CES_Pkt_PktType == 2) {
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
                    displaySpO2 = globalSpO2.toString() + " %";
                  }
                  globalHeartRate = (CES_Pkt_Data_Counter[20]).toInt();
                  globalRespRate = (CES_Pkt_Data_Counter[21]).toInt();
                  globalTemp = (((CES_Pkt_Data_Counter[17] |
                                  CES_Pkt_Data_Counter[18] << 8)
                              .toInt()) /
                          100.00)
                      .toDouble();
                });
                if (ecgDataCounter >= 128 * 6) {
                  ecgLineData.removeAt(0);
                  ppgLineData.removeAt(0);
                }
                if (respDataCounter >= 256 * 6) {
                  respLineData.removeAt(0);
                }
              } else {
                //showAlertDialog(context, "Invalid packet length");
                /*showDialog<String>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Alert'),
                    content: const Text('AlertDialog description'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );*/
              }

              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "ADS1292R Breakout/Shield") {
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
                ecgLineData.add(FlSpot(ecgDataCounter++, (data1.toDouble())));
                respLineData.add(FlSpot(respDataCounter++, (data2.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  respDataLog.add(data2.toDouble());
                }

                globalHeartRate = (computed_val1).toInt();
                globalRespRate = (computed_val2).toInt();
              });
              if (ecgDataCounter >= 128 * 6) {
                ecgLineData.removeAt(0);
              }
              if (respDataCounter >= 256 * 6) {
                respLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            }
            else if (widget.selectedPortBoard == "ADS1293 Breakout/Shield") {
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
                respLineData.add(FlSpot(respDataCounter++, (data2.toDouble())));
                ppgLineData.add(FlSpot(ppgDataCounter++, (data3.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add((data1.toSigned(32) / 1000.00).toDouble());
                  ppgDataLog.add(data3.toDouble());
                  respDataLog.add(data2.toDouble());
                }
              });
              if (ecgDataCounter >= 128 * 6) {
                ecgLineData.removeAt(0);
                ppgLineData.removeAt(0);
              }
              if (respDataCounter >= 256 * 6) {
                respLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "AFE4490 Breakout/Shield") {
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
                  displaySpO2 = globalSpO2.toString() + " %";
                }
              });
              if (ecgDataCounter >= 128 * 6) {
                ecgLineData.removeAt(0);
                ppgLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            }
            else if (widget.selectedPortBoard == "MAX86150 Breakout") {
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
                ecgLineData.add(FlSpot(ecgDataCounter++, (data1.toDouble())));
                respLineData.add(FlSpot(respDataCounter++, (data2.toDouble())));
                ppgLineData.add(FlSpot(ppgDataCounter++, (data3.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  ppgDataLog.add(data3.toDouble());
                  respDataLog.add(data2.toDouble());
                }
              });
              if (ecgDataCounter >= 128 * 6) {
                ecgLineData.removeAt(0);
                ppgLineData.removeAt(0);
                respLineData.removeAt(0);
              }

              pc_rx_state = CESState_Init;
            }
            else if (widget.selectedPortBoard == "Pulse Express") {
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
              if (ecgDataCounter >= 128 * 6) {
                ecgLineData.removeAt(0);
                respLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            }
            else if (widget.selectedPortBoard == "tinyGSR Breakout") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];

              int data1 = ces_pkt_ch1_buffer[0] |
                  ces_pkt_ch1_buffer[1] <<
                      8; //reversePacket(CES_Pkt_ECG_Counter, CES_Pkt_ECG_Counter.length-1);

              setStateIfMounted(() {
                ecgLineData.add(FlSpot(ecgDataCounter++, (data1.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                }
              });
              if (ecgDataCounter >= 128 * 6) {
                ecgLineData.removeAt(0);
              }

              pc_rx_state = CESState_Init;
            }
            else if (widget.selectedPortBoard == "MAX30003 ECG Breakout") {
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

              int computed_val1 = ces_pkt_ch2_buffer[0] |
                  ces_pkt_ch2_buffer[1] << 8 |
                  ces_pkt_ch2_buffer[2] << 16 |
                  ces_pkt_ch2_buffer[3] << 24;
              int computed_val2 = ces_pkt_ch3_buffer[0] |
                  ces_pkt_ch3_buffer[1] << 8 |
                  ces_pkt_ch3_buffer[2] << 16 |
                  ces_pkt_ch3_buffer[3] << 24;

              setStateIfMounted(() {
                ecgLineData.add(FlSpot(
                    ecgDataCounter++, ((data1.toSigned(32)).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add((data1.toSigned(32) / 1000.00).toDouble());
                }
                globalHeartRate = (computed_val2).toInt();
                globalRespRate = (computed_val1).toInt();
              });
              if (ecgDataCounter >= 128 * 6) {
                ecgLineData.removeAt(0);
              }
              pc_rx_state = CESState_Init;
            }
            else if (widget.selectedPortBoard ==
                "MAX30001 ECG & BioZ Breakout") {
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
                ecgLineData.add(FlSpot(ecgDataCounter++, (data1.toDouble())));
                ppgLineData.add(FlSpot(ppgDataCounter++, (data2.toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  ppgDataLog.add(data2.toDouble());
                }
              });
              if (ecgDataCounter >= 128 * 6) {
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
          child: Text(
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
            globalHeartRate.toString() + " bpm",
            style: TextStyle(
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
          child: Text(
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
            globalRespRate.toString() + " rpm",
            style: TextStyle(
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
          child: Text(
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
            style: TextStyle(
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
          child: Text(
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
            globalTemp.toStringAsPrecision(3) + "\u00b0 C",
            style: TextStyle(
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
    if (widget.selectedPortBoard == "Healthypi") {
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
    } else if (widget.selectedPortBoard == "ADS1292R Breakout/Shield") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(29, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
          buildPlots().buildChart(28, 95, respLineData, Colors.blue),
        ],
      );
    } else if (widget.selectedPortBoard == "ADS1293 Breakout/Shield") {
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
    } else if (widget.selectedPortBoard == "AFE4490 Breakout/Shield") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(30, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildPlots().buildChart(30, 95, ppgLineData, Colors.yellow),
        ],
      );
    } else if (widget.selectedPortBoard == "MAX86150 Breakout") {
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
    } else if (widget.selectedPortBoard == "Pulse Express") {
      return Column(
        children: [
          buildPlots().buildChart(32, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildPlots().buildChart(32, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedPortBoard == "tinyGSR Breakout") {
      return Column(
        children: [
          buildPlots().buildChart(65, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
        ],
      );
    } else if (widget.selectedPortBoard == "MAX30003 ECG Breakout") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildPlots().buildChart(54, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
        ],
      );
    } else if (widget.selectedPortBoard == "MAX30001 ECG & BioZ Breakout") {
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
            "Connected To:    " +
                widget.selectedSerialPort +
                "/ " +
                widget.selectedPortBoard,
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
            if (widget.selectedPort.isOpen) {
              widget.selectedPort.close();
            }
            if (startDataLogging == true) {
              startDataLogging = false;
              writeLogDataToFile(ecgDataLog, ppgDataLog, respDataLog, context);
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => HomePage(title: 'OpenView')),
              );
            }
          },
        ),
      );
    });
  }

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
