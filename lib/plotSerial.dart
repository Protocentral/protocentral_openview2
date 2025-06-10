import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'board_handlers/board_handler.dart';
import 'board_handlers/board_registry.dart';
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

  List<String> _selectY1Scale = ['10mm/mV', '5mm/mV', '20mm/mV'];
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

  List<String> _selectChannel = [
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
          pc_rx_state = CESState_Init;
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
        if (CES_Pkt_Pos_Counter < CES_CMDIF_PKT_OVERHEAD) {
          if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_LEN_MSB) {
            CES_Pkt_Len = ((rxch << 8) | CES_Pkt_Len);
          } else if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_PKTTYPE) {
            CES_Pkt_PktType = rxch;
          }
        } else if ((CES_Pkt_Pos_Counter >= CES_CMDIF_PKT_OVERHEAD) &&
            (CES_Pkt_Pos_Counter < CES_CMDIF_PKT_OVERHEAD + CES_Pkt_Len + 1)) {
          if (CES_Pkt_PktType == 2) {
            CES_Pkt_Data_Counter[CES_Data_Counter++] = (rxch);
          } else if (CES_Pkt_PktType == 3) {
            CES_Pkt_ECG_RESP_Data_Counter[CES_ECG_RESP_Data_Counter++] = (rxch);
          } else if (CES_Pkt_PktType == 4) {
            CES_Pkt_PPG_Data_Counter[CES_PPG_Data_Counter++] = (rxch);
          }
        } else {
          if (rxch == CES_CMDIF_PKT_STOP) {
            _processBoardData();
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

  void _processBoardData() {
    final handler = BoardRegistry.getHandler(widget.selectedPortBoard);
    if (handler != null) {
      handler.processPacketData(
        packetData: CES_Pkt_Data_Counter,
        ecgRespData: CES_Pkt_ECG_RESP_Data_Counter,
        ppgData: CES_Pkt_PPG_Data_Counter,
        packetType: CES_Pkt_PktType,
        onDataUpdate: _handleBoardDataUpdate,
      );
    } else {
      // Handle unknown board or show error
      if (widget.selectedPort.isOpen) {
        widget.selectedPort.close();
        _showAlertDialog();
      }
    }
  }

  void _handleBoardDataUpdate(BoardDataUpdate update) {
    setStateIfMounted(() {
      if (update.ecgData != null) {
        ecgLineData.addAll(update.ecgData!);
        if (startDataLogging) {
          ecgDataLog.addAll(update.ecgData!.map((spot) => spot.y));
        }
        while (ecgLineData.length > 128 * 6) {
          ecgLineData.removeAt(0);
        }
      }

      if (update.ppgData != null) {
        ppgLineData.addAll(update.ppgData!);
        if (startDataLogging) {
          ppgDataLog.addAll(update.ppgData!.map((spot) => spot.y));
        }
        while (ppgLineData.length > 128 * 6) {
          ppgLineData.removeAt(0);
        }
      }

      // Handle other data types...

      if (update.heartRate != null) globalHeartRate = update.heartRate!;
      if (update.spO2 != null) globalSpO2 = update.spO2!;
      if (update.respRate != null) globalRespRate = update.respRate!;
      if (update.temperature != null) globalTemp = update.temperature!;
      if (update.displaySpO2 != null) displaySpO2 = update.displaySpO2!;
    });
  }

  Widget displayCharts() {
    final handler = BoardRegistry.getHandler(widget.selectedPortBoard);
    if (handler != null) {
      return handler.buildChartLayout(
        ecgData: ecgLineData,
        ppgData: ppgLineData,
        respData: respLineData,
        eegData: [
          eeg1LineData,
          eeg2LineData,
          eeg3LineData,
          eeg4LineData,
          eeg5LineData,
          eeg6LineData,
          eeg7LineData,
          eeg8LineData
        ],
        heartRate: globalHeartRate,
        spO2: globalSpO2,
        respRate: globalRespRate,
        temperature: globalTemp,
        displaySpO2: displaySpO2,
      );
    }
    return Container();
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
            globalHeartRate.toString() + " bpm",
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
            globalRespRate.toString() + " rpm",
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
            globalTemp.toStringAsPrecision(3) + "\u00b0 C",
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
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
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
          );
        }).toList(),
      );
    } else {
      return DropdownButton(
        value: _selectedY1Scale,
        onChanged: (newValue) {
          setState(() {
            _selectedY1Scale = newValue!;
          });
        },
        items: _selectY1Scale.map((location) {
          return DropdownMenuItem(
            child: Text(location,
                style: const TextStyle(fontSize: 14.0, color: Colors.white)),
            value: location,
          );
        }).toList(),
      );
    }
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
              _buildCharts(),
            ],
          ),
        ),
      ),
    );
  }
}
