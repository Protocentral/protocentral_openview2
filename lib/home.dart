import 'dart:io';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:simple_html_css/simple_html_css.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:signal_strength_indicator/signal_strength_indicator.dart';

import 'globals.dart';
import 'quickScan.dart';
import 'plots.dart';
import 'plotSerial.dart';
import 'sizeConfig.dart';
import 'about.dart';
import 'ble/ble_scanner.dart';
import 'states/OpenViewBLEProvider.dart';

late FlutterReactiveBle _fble;
bool connectedToDevice = false;

late StreamSubscription<ConnectionStateUpdate> _connection;

String pcCurrentDeviceID = "";
String pcCurrentDeviceName = "";

String _selectedBoard = 'Healthypi';

String _selectedPort = 'Port';
String selectedPortBoard = 'Healthypi';

late SerialPort _serialPort;

/************** Packet Validation  **********************/
const int CESState_Init = 0;
const int CESState_SOF1_Found = 1;
const int CESState_SOF2_Found = 2;
const int CESState_PktLen_Found = 3;

/*CES CMD IF Packet Format*/
const int CES_CMDIF_PKT_START_1 = 0x0A;
const int CES_CMDIF_PKT_START_2 = 0xFA;
const int CES_CMDIF_PKT_STOP = 0x0B;

/*CES CMD IF Packet Indices*/
const int CES_CMDIF_IND_LEN = 2;
const int CES_CMDIF_IND_LEN_MSB = 3;
const int CES_CMDIF_IND_PKTTYPE = 4;
int CES_CMDIF_PKT_OVERHEAD = 5;

/************** Packet Related Variables **********************/
int pc_rx_state = 0; // To check the state of the packet
int CES_Pkt_Len = 0; // To store the Packet Length Deatils
int CES_Pkt_Pos_Counter = 0;
int CES_Data_Counter = 0; // Packet and data counter
int CES_Pkt_PktType = 0; // To store the Packet Type
int computed_val1 = 0;
int computed_val2 = 0;

var CES_Pkt_Data_Counter = new List.filled(1000, 0, growable: false);
var ces_pkt_ch1_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_ch2_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_ch3_buffer = new List.filled(4, 0, growable: false);

var listOFBoards = {
  'Healthypi',
  'ADS1292R Breakout/Shield',
  'ADS1293 Breakout/Shield',
  'AFE4490 Breakout/Shield',
  'MAX86150 Breakout',
  'Pulse Express',
  'tinyGSR Breakout',
  'MAX30003 ECG Breakout',
  'MAX30001 ECG & BioZ Breakout'
};

class HomePage extends StatefulWidget {
  HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final _scrollController = ScrollController();
  ScrollController _controller = new ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      hPi4Global.hpi4AppVersion = info.version;
    });
  }

  Widget QuickscanListTile(){
    if(Platform.isAndroid || Platform.isIOS){
      return ListTile(
        leading: Icon(Icons.search),
        title: Text('QuickScan'),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => QuickScanPage(),
                  fullscreenDialog: true));
        },
      );
    }else{
      return Container();
    }

  }

  Widget _buildAppDrawer() {
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            child: Image.asset('assets/proto-online-white.png',
                fit: BoxFit.fitWidth, height: 30),
            decoration: BoxDecoration(
              color: hPi4Global.hpi4Color,
            ),
          ),
          QuickscanListTile(),
          ListTile(
            leading: Icon(Icons.info_outlined),
            title: Text('About'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AboutUsPage(),
                      fullscreenDialog: true));
            },
          ),
          Divider(
            color: Colors.black,
          ),
          _getPoliciesTile(),
          ListTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "v " + hPi4Global.hpi4AppVersion + " ",
                  style: new TextStyle(
                    fontSize: 12,
                  ),
                ),
                Text(
                  "© Protocentral Electronics 2020",
                  style: new TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() async {
    String htmlContent = await rootBundle.loadString('assets/privacyPolicy.html');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Privacy Policy"),
          content: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(16.0),
              child: Builder(builder: (context) {
                return RichText(
                    text: HTML.toTextSpan(
                      context,
                      htmlContent,
                      linksCallback: (link) {
                        print("You clicked on $link");
                      },
                      // as name suggests, optionally set the default text style
                      defaultTextStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                      ),
                      overrideStyle: {
                        //"h1": TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                        "strong":
                        TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                        //"p": TextStyle(fontSize: 12.0, color: Colors.black),
                      },
                    ));
              }),
            ),
          ),
          actions: <Widget>[
            new TextButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showTermsDialog() async {
    String htmlContent =
    await rootBundle.loadString('assets/termsAndConditions.html');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Terms of Use"),
          content: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.all(16.0),
              child: Builder(builder: (context) {
                return RichText(
                    text: HTML.toTextSpan(
                      context,
                      htmlContent,
                      linksCallback: (link) {
                        print("You clicked on $link");
                      },

                      // as name suggests, optionally set the default text style
                      defaultTextStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                      ),
                      overrideStyle: {
                        //"h1": TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                        "strong":
                        TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
                        //"p": TextStyle(fontSize: 12.0, color: Colors.black),
                      },
                    ));
              }),
            ),
          ),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new TextButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _getPoliciesTile() {
    return ListTile(
      title: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: OutlinedButton(
              onPressed: () async {
                _launchURL("https://protocentral.com/");
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'protocentral.com', style: new TextStyle(fontSize: 16, color:hPi4Global.hpi4Color)
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: ' Privacy Policy',
                      style: TextStyle(fontSize: 16, color:hPi4Global.hpi4Color),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          _showPrivacyDialog();
                        },
                    ),
                    TextSpan(
                        text: ' | ',
                        style: TextStyle(fontSize: 16, color: Colors.black)),
                    TextSpan(
                      text: 'Terms of use',
                      style: TextStyle(fontSize: 16, color:hPi4Global.hpi4Color),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          _showTermsDialog();
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _launchURL(String _url) async {
    await launch(_url, forceSafariVC: true, forceWebView: true, enableJavaScript: true);
  }

  void logConsole(String logString) async {
    print("AKW - " + logString);
  }

  FutureOr<bool> timeOutConnection(BuildContext context) {
    Navigator.pop(context);
    print("AKW: Connection timed out");
    return false;
  }

  Future<void> connectToDevice(
      BuildContext context, DiscoveredDevice currentDevice) async {
    //showLoadingIndicator("Connecting to device...",context);
    _fble = await Provider.of<OpenViewBLEProvider>(context, listen: false).getBLE();

    _connection = _fble.connectToDevice(id: currentDevice.id).listen(
        (connectionStateUpdate) async {
      logConsole("Connecting device: " + connectionStateUpdate.toString());
      if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.connected) {
        logConsole("Connected !");
        setState(() {
          connectedToDevice = true;
          pcCurrentDeviceID = currentDevice.id;
          pcCurrentDeviceName = currentDevice.name;
        });
        showLoadingIndicator("Connecting to device...", context);
        await _setMTU(currentDevice.id);
        if(connectedToDevice == true){
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_)
                => WaveFormsPage(
                  selectedBoard:_selectedBoard,
                  selectedDevice: pcCurrentDeviceName,
                  currentDevice: currentDevice,
                  fble:_fble,
                  currConnection: _connection,
                )));

        }
      } else if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.disconnected) {
        connectedToDevice = false;
      }
    }, onError: (dynamic error) {
      logConsole("Connect error: " + error.toString());
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

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  Future<void> _setMTU(String deviceMAC) async {
    int recdMTU = await _fble.requestMtu(deviceId: deviceMAC, mtu: 200);
    logConsole("MTU negotiated: " + recdMTU.toString());
    Navigator.pop(context);
  }

  Widget listOfBoardsDropDown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: DropdownButton(
        underline: SizedBox(),
        dropdownColor: hPi4Global.hpi4Color,
        hint: _selectedBoard == null
            ? Text('Select Board')
            : Text(
          _selectedBoard,
          style: TextStyle(color: hPi4Global.hpi4Color, fontSize: 16.0),
        ),
        isExpanded: true,
        iconSize: 30.0,
        style: TextStyle(color: Colors.white, fontSize: 16.0),
        items: listOFBoards.map(
              (val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val),
            );
          },
        ).toList(),
        onChanged: (value) {
          setState(
                () {
              _selectedBoard = value as String;
            },
          );
        },
      ),
    );

  }

  Widget showScanResults() {
    if(Platform.isAndroid || Platform.isIOS){
      return Consumer3<BleScannerState, BleScanner, OpenViewBLEProvider>(
          builder: (context, bleScannerState, bleScanner, wiserBle, child) {
            return Column(mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      MaterialButton(
                          minWidth: 100.0,
                          color: hPi4Global.hpi4Color,
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                              Text('Scan',
                                  style:
                                  new TextStyle(fontSize: 18.0, color: Colors.white)),
                            ],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          onPressed: () async {
                            if (Platform.isAndroid) {
                              bool bleStatusFlag = await wiserBle.getBleStatus();
                              if (await wiserBle.checkPermissions(
                                  context, bleStatusFlag) ==
                                  true) {
                                bleScanner.startScan([], "");
                              } else {
                                //Do not attempt to connect
                              }
                            } else {
                              bleScanner.startScan([], "");
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  listOfBoardsDropDown(),
                  SizedBox(
                      height:600,
                      child:ListView.builder(
                          shrinkWrap: true,
                          physics: const AlwaysScrollableScrollPhysics(), // new
                          controller: _controller,
                          padding: const EdgeInsets.all(8),
                          itemCount: bleScannerState.discoveredDevices.length,
                          itemBuilder: (BuildContext context, int index) {
                            return Card(
                              child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bluetooth),
                                          Text(bleScannerState
                                              .discoveredDevices[index].name),
                                          Padding(
                                            padding:
                                            const EdgeInsets.fromLTRB(8, 0, 8, 0),
                                            child: SignalStrengthIndicator.bars(
                                              value: bleScannerState
                                                  .discoveredDevices.length >
                                                  0
                                                  ? 2 *
                                                  (bleScannerState
                                                      .discoveredDevices[index]
                                                      .rssi +
                                                      100) /
                                                  100
                                                  : 0, //patchBLE.patchRSSI / 100,
                                              size: 25,
                                              barCount: 4,
                                              spacing: 0.2,
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                            const EdgeInsets.fromLTRB(4, 0, 4, 0),
                                            child: connectedToDevice
                                                ? Container()
                                                : MaterialButton(
                                              minWidth: 80.0,
                                              color: hPi4Global.hpi4Color,
                                              child: Row(
                                                children: <Widget>[
                                                  Text('Connect',
                                                      style: new TextStyle(
                                                          fontSize: 16.0,
                                                          color: Colors.white)),
                                                ],
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(8.0),
                                              ),
                                              onPressed: () async {
                                                connectToDevice(
                                                    context,
                                                    bleScannerState
                                                        .discoveredDevices[index]);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]
                              ),
                            );
                          }),
                  ),

                ]);
          });
    }else{
      return Container();
    }

  }

  Widget showSerialPortResult(){
    if(Platform.isMacOS || Platform.isWindows){
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Select Board:",style:
          TextStyle(color: Colors.black, fontSize: 16.0) ),
          SizedBox(
            width:20.0,
          ),
          DropdownButton(
            underline: SizedBox(),
            dropdownColor: hPi4Global.hpi4Color,
            hint: selectedPortBoard == null
                ? Text('Select Board')
                : Text(selectedPortBoard,
              style: TextStyle(color: hPi4Global.hpi4Color, fontSize: 16.0),
            ),
            //isExpanded: true,
            iconSize: 50.0,
            style: TextStyle(color: Colors.white, fontSize: 16.0),
            items: listOFBoards.map(
                  (val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              },
            ).toList(),
            onChanged: (value) {
              setState(
                    () {
                  selectedPortBoard = value as String;
                },
              );
            },
          ),
          SizedBox(
            width:50.0,
          ),
          Text("Select Port:",style:
          TextStyle(color: Colors.black, fontSize: 16.0) ),
          SizedBox(
            width:20.0,
          ),
          DropdownButton(
            underline: SizedBox(),
            dropdownColor: hPi4Global.hpi4Color,
            hint: _selectedPort == null
                ? Text('Select Serial Port')
                : Text(
              _selectedPort,
              style:
              TextStyle(color: hPi4Global.hpi4Color, fontSize: 16.0),
            ),
            //isExpanded: true,
            iconSize: 50.0,
            style: TextStyle(color: Colors.white, fontSize: 16.0),
            items: SerialPort.availablePorts.map(
                  (val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              },
            ).toList(),
            onChanged: (value) {
              setState(
                    () {
                  _selectedPort = value as String;
                },
              );
            },
          ),
          SizedBox(
            width:50.0,
          ),
          MaterialButton(
            minWidth: 100.0,
            color: Colors.green,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                  ),
                  Text('Start',
                      style: new TextStyle(
                          fontSize: 18.0, color: Colors.white)),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            onPressed: () async {
              print("Opening $_selectedPort");
                      _serialPort = SerialPort(_selectedPort);
                      if (!_serialPort.openReadWrite()) {
                        print(SerialPort.lastError);
                      }
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_)
                  => PlotSerialPage(
                    selectedPort:_serialPort,
                      selectedSerialPort: _selectedPort,
                      selectedPortBoard: selectedPortBoard,
                  )));

            },
          ),
          SizedBox(
            width:30.0,
          ),
          MaterialButton(
            minWidth: 100.0,
            color: Colors.red,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.stop,
                    color: Colors.white,
                  ),
                  Text('Stop',
                      style: new TextStyle(
                          fontSize: 18.0, color: Colors.white)),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            onPressed: () async {
              if (_serialPort.isOpen && _serialPort != null) {
                _serialPort.close();
              }
            },
          ),
        ],
      );
    }else{
      return Container();
    }

  }

  Widget _buildConnectionBlock() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              showScanResults(),
              showSerialPortResult(),
            ]),
    );
  }

  Widget _getBottomStatusBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Text(
                "Ver: " + hPi4Global.hpi4AppVersion,
                style: new TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
        backgroundColor: hPi4Global.appBackgroundColor,
        drawer: _buildAppDrawer(),
        appBar: AppBar(
          backgroundColor: hPi4Global.hpi4Color,
          iconTheme: IconThemeData(color: Colors.white),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Image.asset('assets/proto-online-white.png',
                  fit: BoxFit.fitWidth, height: 30),

            ],
          ),
        ),
        body: Scrollbar(
          controller: _scrollController,
          //thumbVisibility: true,
          //trackVisibility: true,
          //thickness: 10,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  //mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    _buildConnectionBlock(),
                  ]),
            ),
          ),
        ),
      bottomNavigationBar: _getBottomStatusBar(),
    );
  }
}
