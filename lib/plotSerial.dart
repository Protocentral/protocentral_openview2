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
import 'package:flutter/src/foundation/change_notifier.dart';

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

  final ValueNotifier<List<FlSpot>> ecgLineData1 = ValueNotifier([]);
  final ValueNotifier<List<FlSpot>> ppgLineData1 = ValueNotifier([]);
  final ValueNotifier<List<FlSpot>> respLineData1 = ValueNotifier([]);
  final ValueNotifier<List<FlSpot>> ecg1LineData1 = ValueNotifier([]);
  final ValueNotifier<List<FlSpot>> ecg2LineData1 = ValueNotifier([]);

  bool startDataLogging = false;
  bool startEEGStreaming = false;

  int globalHeartRate = 0;
  int globalSpO2 = 0;
  int globalRespRate = 0;
  double globalTemp = 0;
  String displaySpO2 = "--";

  /// Configurable window size in seconds for plotting
  static const List<int> _windowSizeOptions = [3, 6, 9, 12];
  int _plotWindowSeconds = 6; // Default value

  // Add these counters to your _PlotSerialPageState class:
  int ecgUpdateCounter = 0;
  int ppgUpdateCounter = 0;
  int respUpdateCounter = 0;

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
    if (!mounted) return;
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

    try {
      // Check if port is open, if not, try to open it
      if (!widget.selectedPort.isOpen) {
        if (!widget.selectedPort.openReadWrite()) {
          throw SerialPortError('Device not configured');
        }
      }

      final serialStream = SerialPortReader(widget.selectedPort);
      serialStream.stream.listen(
            (event) {
          for (int i = 0; i < event.length; i++) {
            pcProcessData(event[i]);
          }
        },
        onError: (error) {
          print('Serial stream error: $error');
          _showSerialPortErrorDialog(error.toString());
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('SerialPort exception: $e');
      _showSerialPortErrorDialog(e.toString());
    }
  }

  // Add this helper to show a dialog for serial port errors
  void _showSerialPortErrorDialog(String errorMsg) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Serial Port Error'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Icon(
                  Icons.error,
                  color: Colors.red,
                  size: 72,
                ),
                Center(
                  child: Column(children: <Widget>[
                    Text(
                      errorMsg,
                      style: const TextStyle(
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

  int updateInterval = 125; // Only update every 64 new points

  /// Helper method to manage data window size for regular List<FlSpot>
  /// Keep enough data for smooth scrolling but not excessive memory usage
  void _manageDataWindow(List<FlSpot> dataList, double windowSizeInSamples) {
    // Keep 2x the window size to ensure smooth scrolling and avoid gaps
    double bufferSize = windowSizeInSamples * 2.0;
    while (dataList.length > bufferSize) {
      dataList.removeAt(0);
    }
  }

  /// Helper method to manage data window size for ValueNotifier<List<FlSpot>>
  void _manageValueNotifierWindow(ValueNotifier<List<FlSpot>> notifier, double windowSizeInSamples) {
    // Keep 2x the window size to ensure smooth scrolling and avoid gaps
    double bufferSize = windowSizeInSamples * 2.0;
    while (notifier.value.length > bufferSize) {
      notifier.value.removeAt(0);
    }
  }

  /// Get the proper X-axis range for continuous streaming
  List<double> _getCurrentXAxisRange(List<FlSpot> data) {
    if (data.isEmpty) {
      return [0, _plotWindowSeconds.toDouble() * boardSamplingRate];
    }

    print("..........."+boardSamplingRate.toString());

    double latestX = data.last.x;
    double windowSizeInSamples = _plotWindowSeconds.toDouble() * boardSamplingRate;

    // For continuous streaming, show the most recent data
    double maxX = latestX;
    double minX = maxX - windowSizeInSamples;

    // Ensure we don't go below 0
    if (minX < 0) {
      minX = 0;
      maxX = windowSizeInSamples;
    }

    return [minX, maxX];
  }

  /// Get filtered data for the current streaming window
  List<FlSpot> _getWindowedData(List<FlSpot> fullData) {
    if (fullData.isEmpty) return [];

    List<double> range = _getCurrentXAxisRange(fullData);
    double minX = range[0];
    double maxX = range[1];

    return fullData.where((point) => point.x >= minX && point.x <= maxX).toList();
  }

  /// Build chart with streaming window data and proper X-axis range
  Widget buildStreamingChart(int height, int width, List<FlSpot> data, Color color) {
    if (data.isEmpty) {
      return buildPlots().buildChart(height, width, [], color);
    }

    List<FlSpot> windowedData = _getWindowedData(data);
    List<double> xAxisRange = _getCurrentXAxisRange(data);

    // Pass the x-axis range to your chart building method
    return buildPlots().buildChartWithRange(height, width, windowedData, color, xAxisRange[0], xAxisRange[1]);
  }

  /// Build chart for ValueNotifier with streaming
  Widget buildStreamingChartFromNotifier(int height, int width, ValueNotifier<List<FlSpot>> notifier, Color color) {
    return ValueListenableBuilder<List<FlSpot>>(
      valueListenable: notifier,
      builder: (context, points, child) {
        if (points.isEmpty) {
          return buildPlots().buildChart(height, width, [], color);
        }

        List<FlSpot> windowedData = _getWindowedData(points);
        List<double> xAxisRange = _getCurrentXAxisRange(points);

        return buildPlots().buildChartWithRange(height, width, windowedData, color, xAxisRange[0], xAxisRange[1]);
      },
    );
  }

  /// Updated toolbar with proper window size change handling
  Widget buildToolbar() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
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
                    // No need to reset scrolling - it will automatically adjust
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
                    ppgLineData.add(FlSpot(ppgDataCounter++, ((data3).toDouble())));

                    if (startDataLogging == true) {
                      ppgDataLog.add((data3.toSigned(32)).toDouble());
                    }
                  });

                  // Apply corrected window size management
                  double windowSizeInSamples = boardSamplingRate * _plotWindowSeconds.toDouble();
                  _manageDataWindow(ppgLineData, windowSizeInSamples);
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
                    ecgLineData.add(FlSpot(ecgDataCounter++, ((data1.toSigned(32)).toDouble())));
                    if (startDataLogging == true) {
                      ecgDataLog.add((data1.toSigned(32)).toDouble());
                    }
                  });

                  // Apply corrected window size management
                  double windowSizeInSamples = boardSamplingRate * _plotWindowSeconds.toDouble();
                  _manageDataWindow(ecgLineData, windowSizeInSamples);
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
                    respLineData.add(FlSpot(respDataCounter++, ((data2.toSigned(32)).toDouble())));

                    if (startDataLogging == true) {
                      respDataLog.add((data2.toSigned(32)).toDouble());
                    }
                  });

                  // Apply corrected window size management
                  double windowSizeInSamples = boardSamplingRate * _plotWindowSeconds.toDouble();
                  _manageDataWindow(respLineData, windowSizeInSamples);

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

                // Apply window size management
                double windowSizeInSamples = boardSamplingRate * _plotWindowSeconds.toDouble();
                _manageDataWindow(ecgLineData, windowSizeInSamples);
                _manageDataWindow(ppgLineData, windowSizeInSamples);
                _manageDataWindow(respLineData, windowSizeInSamples);

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

              // Apply window size management
              _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
              _manageDataWindow(ppgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
              _manageDataWindow(respLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

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

              // Apply window size management
              _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
              _manageDataWindow(ppgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

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

              // Apply window size management
              _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
              _manageDataWindow(ppgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
              _manageDataWindow(respLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

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

              // Apply window size management
              _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
              _manageDataWindow(respLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

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

              // Apply window size management
              _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

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

              // Apply window size management
              _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

              pc_rx_state = CESState_Init;
            } else if (widget.selectedPortBoard == "MAX30001 ECG & BioZ Breakout (USB)") {
              ces_pkt_ch1_buffer[0] = CES_Pkt_Data_Counter[0];
              ces_pkt_ch1_buffer[1] = CES_Pkt_Data_Counter[1];
              ces_pkt_ch1_buffer[2] = CES_Pkt_Data_Counter[2];
              ces_pkt_ch1_buffer[3] = CES_Pkt_Data_Counter[3];

              ces_pkt_ch2_buffer[0] = CES_Pkt_Data_Counter[4];
              ces_pkt_ch2_buffer[1] = CES_Pkt_Data_Counter[5];
              ces_pkt_ch2_buffer[2] = CES_Pkt_Data_Counter[6];
              ces_pkt_ch2_buffer[3] = CES_Pkt_Data_Counter[7];

              int ch2DataTag = CES_Pkt_Data_Counter[8]; // <<<< GETTING THE TAG

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
                    FlSpot(ecgDataCounter++, data1.toSigned(32).toDouble())
                );
                // ONLY ADD PPG DATA if tag is 0
                if (ch2DataTag == 0) {
                  ppgLineData.add(
                      FlSpot(ppgDataCounter++, data2.toSigned(32).toDouble())
                  );
                }
                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  ppgDataLog.add(data2.toDouble());
                }
              });

              /*setStateIfMounted(() {
                ecgLineData.add(
                    FlSpot(ecgDataCounter++, (data1.toSigned(32).toDouble())));
                ppgLineData.add(
                    FlSpot(ppgDataCounter++, (data2.toSigned(32).toDouble())));

                if (startDataLogging == true) {
                  ecgDataLog.add(data1.toDouble());
                  ppgDataLog.add(data2.toDouble());
                }
              });*/

              // Apply window size management
              _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
              _manageDataWindow(ppgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

              pc_rx_state = CESState_Init;
            }
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
            ces_pkt_ch5_buffer[2] = CES_Pkt_Data_Counter[18];
            ces_pkt_ch5_buffer[3] = CES_Pkt_Data_Counter[19];

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

            int data5 = ces_pkt_ch5_buffer[0] |
            ces_pkt_ch5_buffer[1] << 8 |
            ces_pkt_ch5_buffer[2] << 16 |
            ces_pkt_ch5_buffer[3] << 24;

            ecgLineData1.value.add(
                FlSpot(ecgDataCounter++, ((data1.toSigned(32)).toDouble())));

            ecg1LineData1.value.add(
                FlSpot(ecg1DataCounter++, ((data2.toSigned(32)).toDouble())));

            ecg2LineData1.value.add(
                FlSpot(ecg2DataCounter++, ((data3.toSigned(32)).toDouble())));

            respLineData1.value.add(
                FlSpot(respDataCounter++, (data4.toSigned(32).toDouble())));

            if (CES_Pkt_Data_Counter[24] == 0) {
              // Invalid data
            } else {
              ppgLineData1.value.add(FlSpot(
                  ppgDataCounter++, (data5.toUnsigned(32).toDouble())));
            }

            if (ecgDataCounter % updateInterval == 0) {
              ecgLineData1.notifyListeners();
              ecg1LineData1.notifyListeners();
              ecg2LineData1.notifyListeners();
              respLineData1.notifyListeners();
              ppgLineData1.notifyListeners();
            }

            globalHeartRate = (CES_Pkt_ECG_RESP_Data_Counter[25] |
            CES_Pkt_Data_Counter[26] << 8)
                .toInt();
            globalRespRate = (CES_Pkt_ECG_RESP_Data_Counter[28]).toInt();
            globalSpO2 = (CES_Pkt_Data_Counter[27]).toInt();
            globalTemp =
                (((CES_Pkt_Data_Counter[29] | CES_Pkt_Data_Counter[30] << 8)
                    .toInt()) /
                    100.00)
                    .toDouble();

            // Apply window size management for ValueNotifiers
            double maxWindowSize = boardSamplingRate * _plotWindowSeconds.toDouble();
            _manageValueNotifierWindow(ecgLineData1, maxWindowSize);
            _manageValueNotifierWindow(ecg1LineData1, maxWindowSize);
            _manageValueNotifierWindow(ecg2LineData1, maxWindowSize);
            _manageValueNotifierWindow(ppgLineData1, maxWindowSize);
            _manageValueNotifierWindow(respLineData1, maxWindowSize);

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

            // Apply window size management
            _manageDataWindow(ecgLineData, boardSamplingRate * _plotWindowSeconds.toDouble());
            _manageDataWindow(respLineData, boardSamplingRate * _plotWindowSeconds.toDouble());

            pc_rx_state = CESState_Init;
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
      height: SizeConfig.blockSizeVertical * 1,
    );
  }

  Widget displayCharts(String selectedPortBoard) {
    if (selectedPortBoard == "Healthypi (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildStreamingChart(17, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildStreamingChart(17, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
          buildStreamingChart(17, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
          displayTemperatureValue(),
        ],
      );
    } else if (selectedPortBoard == "Healthypi 6 (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildStreamingChartFromNotifier(10, 95, ecgLineData1, Colors.green),
          buildStreamingChartFromNotifier(10, 95, ecg1LineData1, Colors.yellow),
          buildStreamingChartFromNotifier(10, 95, ecg2LineData1, Colors.orange),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildStreamingChartFromNotifier(9, 95, ppgLineData1, Colors.red),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
          buildStreamingChartFromNotifier(9, 95, respLineData1, Colors.blue),
          sizedBoxForCharts(),
          displayTemperatureValue(),
        ],
      );
    }  else if (selectedPortBoard == "ADS1292R Breakout/Shield (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildStreamingChart(29, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
          buildStreamingChart(28, 95, respLineData, Colors.blue),
        ],
      );
    } else if (selectedPortBoard == "ADS1293 Breakout/Shield (USB)") {
      return Column(
        children: [
          buildStreamingChart(23, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildStreamingChart(23, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          buildStreamingChart(23, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (selectedPortBoard == "AFE4490 Breakout/Shield (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildStreamingChart(30, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildStreamingChart(30, 95, ppgLineData, Colors.yellow),
        ],
      );
    } else if (selectedPortBoard == "Sensything Ox (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildStreamingChart(30, 95, ecgLineData, Colors.red),
          sizedBoxForCharts(),
          displaySpo2Value(),
          buildStreamingChart(30, 95, ppgLineData, Colors.yellow),
        ],
      );
    } else if (selectedPortBoard == "MAX86150 Breakout (USB)") {
      return Column(
        children: [
          buildStreamingChart(23, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildStreamingChart(23, 95, ppgLineData, Colors.yellow),
          sizedBoxForCharts(),
          buildStreamingChart(23, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (selectedPortBoard == "Pulse Express (USB)") {
      return Column(
        children: [
          buildStreamingChart(32, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildStreamingChart(32, 95, respLineData, Colors.blue),
          sizedBoxForCharts(),
        ],
      );
    } else if (selectedPortBoard == "tinyGSR Breakout (USB)") {
      return Column(
        children: [
          buildStreamingChart(65, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
        ],
      );
    } else if (selectedPortBoard == "MAX30003 ECG Breakout (USB)") {
      return Column(
        children: [
          displayHeartRateValue(),
          buildStreamingChart(54, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          displayRespirationRateValue(),
        ],
      );
    } else if (selectedPortBoard == "MAX30001 ECG & BioZ Breakout (USB)") {
      return Column(
        children: [
          buildStreamingChart(32, 95, ecgLineData, Colors.green),
          sizedBoxForCharts(),
          buildStreamingChart(32, 95, ppgLineData, Colors.blue),
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
                  displayCharts(widget.selectedPortBoard),
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

  /// Returns the sampling rate based on the selected board.
  int get boardSamplingRate {
    switch (widget.selectedPortBoard) {
      case "Healthypi (USB)":
        return 128;
      case "Healthypi 6 (USB)":
        return 500;
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
        child: Container(
          color: Colors.black,
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
      ),
    );
  }
}