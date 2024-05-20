import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'globals.dart';
import 'home.dart';
import 'sizeConfig.dart';

import 'ble/ble_scanner.dart';
import 'states/OpenViewBLEProvider.dart';
import 'package:provider/provider.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class PlotSerialPage extends StatefulWidget {
  PlotSerialPage({Key? key,
    required this.selectedPort,
    required this.selectedSerialPort,
  }) : super();

  final SerialPort selectedPort;
  final String selectedSerialPort;

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

  bool ecgCheckBoxValue = true;
  bool ppgCheckBoxValue = true;
  bool respCheckBoxValue = true;
  bool startDataLogging = false;

  int globalHeartRate = 0;
  int globalSpO2 = 0;
  int globalRespRate = 0;
  double globalTemp = 0;
  String displaySpO2 = "--" ;


  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    displayWaveforms();
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

  void logConsole(String logString) {
    print("AKW - " + logString);
  }


  void _startSerialListening() async {
    print("AKW: Started listening to stream");

    final _serialStream = SerialPortReader(widget.selectedPort);
    _serialStream.stream.listen((event) {
      // print('R: $event');
      for (int i = 0; i < event.length; i++) {
        pcProcessData(event[i]);
      }
    });

  }

  void pcProcessData(int rxch) async {
    //print("received data: "+rxch.toString());
    switch (pc_rx_state) {
      case CESState_Init:
        if (rxch == CES_CMDIF_PKT_START_1)
        {
          pc_rx_state = CESState_SOF1_Found;
        }
        break;
      case CESState_SOF1_Found:
        if (rxch == CES_CMDIF_PKT_START_2){
          pc_rx_state = CESState_SOF2_Found;
        }
        else{
          pc_rx_state = CESState_Init; //Invalid Packet, reset state to init
        }
        break;
      case CESState_SOF2_Found:
      //println("inside 3");
        pc_rx_state = CESState_PktLen_Found;
        CES_Pkt_Len = rxch;
        CES_Pkt_Pos_Counter = CES_CMDIF_IND_LEN;
        CES_Data_Counter = 0;
        break;
      case CESState_PktLen_Found:
      //println("inside 4");
        CES_Pkt_Pos_Counter++;
        if (CES_Pkt_Pos_Counter < CES_CMDIF_PKT_OVERHEAD) //Read Header
            {
          if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_LEN_MSB)
            CES_Pkt_Len = ((rxch << 8) | CES_Pkt_Len);
          else if (CES_Pkt_Pos_Counter == CES_CMDIF_IND_PKTTYPE)
            CES_Pkt_PktType = rxch;
        } else if ((CES_Pkt_Pos_Counter >= CES_CMDIF_PKT_OVERHEAD) &&
            (CES_Pkt_Pos_Counter <
                CES_CMDIF_PKT_OVERHEAD + CES_Pkt_Len + 1)) //Read Data
            {
          if (CES_Pkt_PktType == 2) {
            //print("data received : "+ rxch.toString());
            CES_Pkt_Data_Counter[CES_Data_Counter++] = (rxch); // Buffer that assigns the data separated from the packet
          }
        } else //All data received
            {
          if (rxch == CES_CMDIF_PKT_STOP) {
            //print("data assigned : "+ CES_Pkt_Data_Counter.toString());
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

            int data1 = ces_pkt_ch1_buffer[0] | ces_pkt_ch1_buffer[1] << 8 | ces_pkt_ch1_buffer[2] << 16 | ces_pkt_ch1_buffer[3] << 24;
            int data2 = ces_pkt_ch2_buffer[0] | ces_pkt_ch2_buffer[1]<<8 | ces_pkt_ch2_buffer[2]<<16 | ces_pkt_ch2_buffer[3] <<24;
            int data3 = ces_pkt_ch3_buffer[0] | ces_pkt_ch3_buffer[1]<<8 | ces_pkt_ch3_buffer[2]<<16 | ces_pkt_ch3_buffer[3] <<24;

            setStateIfMounted(() {
              ecgLineData.add(FlSpot(ecgDataCounter++, ((data1.toSigned(32)/1000.00).toDouble())));
              respLineData.add(FlSpot(respDataCounter++, (data2.toDouble())));
              ppgLineData.add(FlSpot(ppgDataCounter++, (data3.toDouble())));

              if(startDataLogging == true){
                ecgDataLog.add((data1.toSigned(32)/1000.00).toDouble());
                ppgDataLog.add(data3.toDouble());
                respDataLog.add(data2.toDouble());
              }

              globalSpO2 =  (CES_Pkt_Data_Counter[19]).toInt();
              if(globalSpO2 == 25){
                displaySpO2 = "--";
              }else{
                displaySpO2 = globalSpO2.toString() +" %";
              }
              globalHeartRate = (CES_Pkt_Data_Counter[20]).toInt();
              globalRespRate = (CES_Pkt_Data_Counter[21]).toInt();
              globalTemp = (((CES_Pkt_Data_Counter[17]| CES_Pkt_Data_Counter[18]<<8).toInt())/100.00).toDouble();
            });
            if (ppgDataCounter >= 64 * 6) {
              ecgLineData.removeAt(0);
              ppgLineData.removeAt(0);
            }
            if (respDataCounter >= 128 * 6) {
              respLineData.removeAt(0);
            }
            pc_rx_state = CESState_Init;
          }else{
            pc_rx_state = CESState_Init;
          }
        }
        break;
      default:
        break;
    }
  }

  void displayWaveforms() {
    setState(() {
      ecgCheckBoxValue = true;
      ppgCheckBoxValue = true;
      respCheckBoxValue = true;
    });
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
          Column(
              children: [
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
                    child: Text( globalHeartRate.toString() + " bpm",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(18, 95, ecgLineData, Colors.green),
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
                    child:  Text(displaySpO2,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(18, 95, ppgLineData, Colors.yellow),
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
                    child: Text( globalRespRate.toString() + " rpm",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
          ),
          buildChart(18, 95, respLineData, Colors.blue),
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
                    child: Text( globalTemp.toString() + " C",
                      style: TextStyle(
                        fontSize: 20,
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
            "Connected To:    "+ widget.selectedSerialPort,
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
                  //displayPlots(),
                  /*SizedBox(
                    height: SizeConfig.blockSizeVertical * 1,
                  ),
                  displayValues(),*/
                ],
              ),
            )));
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
                if (widget.selectedPort.isOpen) {
                  widget.selectedPort.close();
                }
                if(startDataLogging == true){
                  startDataLogging = false;
                  _writeLogDataToFile(ecgDataLog, ppgDataLog,respDataLog);
                }else{
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

    _directory = await getApplicationDocumentsDirectory();

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
              onPressed: () {
                Navigator.pop(context);
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
            SizedBox(
              width: SizeConfig.blockSizeHorizontal * 5,
            ),
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

