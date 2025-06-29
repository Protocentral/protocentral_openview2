import 'dart:io';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:signal_strength_indicator/signal_strength_indicator.dart';

import 'plots.dart';
import 'about.dart';
import 'globals.dart';
import 'quickScan.dart';
import 'plotSerial.dart';
import 'utils/sizeConfig.dart';
import 'utils/variables.dart';
import 'ble/ble_scanner.dart';
import 'utils/showTerms.dart';
import 'utils/showPrivacy.dart';
import 'utils/loadingDialog.dart';
import 'states/OpenViewBLEProvider.dart';

late FlutterReactiveBle fble;
late StreamSubscription<ConnectionStateUpdate> connection;
late SerialPort serialPort;

String pcCurrentDeviceID = "";
String pcCurrentDeviceName = "";
String selectedBLEBoard = 'Healthypi (BLE)';
String selectedBLEPortBoard = 'Healthypi (BLE)';

String selectedUSBBoard = 'Healthypi (USB)';
String selectedUSBPort = 'Port';
String selectedUSBPortBoard = 'Healthypi (USB)';

bool connectedToDevice = false;

class HomePage extends StatefulWidget {
  HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final scrollController = ScrollController();
  ScrollController controller = new ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    initPackageInfo();
  }

  Future<void> initPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      hPi4Global.hpi4AppVersion = info.version;
    });
  }

  Widget QuickscanListTile() {
    if (Platform.isAndroid || Platform.isIOS) {
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
    } else {
      return Container();
    }
  }

  Widget buildAppDrawer() {
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
          getPoliciesTile(),
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

  Widget getPoliciesTile() {
    return ListTile(
      title: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: OutlinedButton(
              onPressed: () async {
                hPi4Global().launchURL("https://protocentral.com/");
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('protocentral.com',
                        style: new TextStyle(
                            fontSize: 16, color: hPi4Global.hpi4Color)),
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
                      style:
                          TextStyle(fontSize: 16, color: hPi4Global.hpi4Color),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          showPrivacyDialog(context);
                        },
                    ),
                    TextSpan(
                        text: ' | ',
                        style: TextStyle(fontSize: 16, color: Colors.black)),
                    TextSpan(
                      text: 'Terms of use',
                      style:
                          TextStyle(fontSize: 16, color: hPi4Global.hpi4Color),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          showTermsDialog(context);
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

  Future<void> connectToDevice(
      BuildContext context, DiscoveredDevice currentDevice) async {
    fble =
        await Provider.of<OpenViewBLEProvider>(context, listen: false).getBLE();

    connection = fble.connectToDevice(id: currentDevice.id).listen(
        (connectionStateUpdate) async {
      hPi4Global()
          .logConsole("Connecting device: " + connectionStateUpdate.toString());
      if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.connected) {
        hPi4Global().logConsole("Connected !");
        setState(() {
          connectedToDevice = true;
          pcCurrentDeviceID = currentDevice.id;
          pcCurrentDeviceName = currentDevice.name;
        });
        showLoadingIndicator("Connecting to device...", context);
        await _setMTU(currentDevice.id);
        if (connectedToDevice == true) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => WaveFormsPage(
                    selectedBoard: selectedBLEBoard,
                    selectedDevice: pcCurrentDeviceName,
                    currentDevice: currentDevice,
                    fble: fble,
                    currConnection: connection,
                  )));
        }
      } else if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.disconnected) {
        connectedToDevice = false;
      }
    }, onError: (dynamic error) {
      hPi4Global().logConsole("Connect error: " + error.toString());
    });
  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  Future<void> _setMTU(String deviceMAC) async {
    int recdMTU = await fble.requestMtu(deviceId: deviceMAC, mtu: 200);
    hPi4Global().logConsole("MTU negotiated: " + recdMTU.toString());
    Navigator.pop(context);
  }

  Widget listOfBoardsDropDown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: DropdownButton(
        underline: SizedBox(),
        dropdownColor: hPi4Global.hpi4Color,
        hint: selectedBLEBoard.isEmpty
            ? Text('Select Board')
            : Text(
                selectedBLEBoard,
                style: TextStyle(color: hPi4Global.hpi4Color, fontSize: 16.0),
              ),
        isExpanded: false,
        iconSize: 30.0,
        style: TextStyle(color: Colors.white, fontSize: 16.0),
        items: listOFBLEBoards.map(
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
              selectedBLEBoard = value as String;
            },
          );
        },
      ),
    );
  }

  Widget showScanResults() {
    if (Platform.isAndroid || Platform.isIOS) {
      return Consumer3<BleScannerState, BleScanner, OpenViewBLEProvider>(
          builder: (context, bleScannerState, bleScanner, wiserBle, child) {
        return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
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
                          style: new TextStyle(
                              fontSize: 18.0, color: Colors.white)),
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
            height: 600,
            child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(), // new
                controller: controller,
                padding: const EdgeInsets.all(8),
                itemCount: bleScannerState.discoveredDevices.length,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bluetooth),
                            Text(bleScannerState.discoveredDevices[index].name),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                              child: SignalStrengthIndicator.bars(
                                value:
                                    bleScannerState.discoveredDevices.length > 0
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
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
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
                    ]),
                  );
                }),
          ),
        ]);
      });
    } else {
      return Container();
    }
  }

  Widget showSerialPortResult() {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return Column(
        children: [
          // First row: Board and Port selection
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10.0,
            runSpacing: 8.0,
            children: [
              Text("Select Board:",
                  style: TextStyle(color: Colors.black, fontSize: 14.0)),
              DropdownButton(
                underline: SizedBox(),
                dropdownColor: hPi4Global.hpi4Color,
                hint: selectedUSBPortBoard.isEmpty
                    ? Text('Select Board')
                    : Text(
                        selectedUSBPortBoard,
                        style:
                            TextStyle(color: hPi4Global.hpi4Color, fontSize: 14.0),
                      ),
                isExpanded: false,
                iconSize: 30.0,
                style: TextStyle(color: Colors.white, fontSize: 14.0),
                items: listOFUSBBoards.map(
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
                      selectedUSBPortBoard = value as String;
                    },
                  );
                },
              ),
              Text("Select Port:",
                  style: TextStyle(color: Colors.black, fontSize: 14.0)),
              DropdownButton(
                underline: SizedBox(),
                dropdownColor: hPi4Global.hpi4Color,
                hint: selectedUSBPort.isEmpty
                    ? Text('Select Serial Port')
                    : Text(
                      selectedUSBPort,
                        style:
                            TextStyle(color: hPi4Global.hpi4Color, fontSize: 14.0),
                      ),
                isExpanded: false,
                iconSize: 30.0,
                style: TextStyle(color: Colors.white, fontSize: 14.0),
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
                     selectedUSBPort = value as String;
                    },
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 10.0),
          // Second row: Action buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 15.0,
            runSpacing: 8.0,
            children: [
              MaterialButton(
                minWidth: 80.0,
                color: Colors.green,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 18.0,
                      ),
                      SizedBox(width: 4.0),
                      Text('Start',
                          style:
                              new TextStyle(fontSize: 16.0, color: Colors.white)),
                    ],
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                onPressed: () async {
                  print("Opening $selectedUSBPort");
                  
                  if (selectedUSBPort.isEmpty || selectedUSBPort == 'Port') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please select a serial port first'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  try {
                    serialPort = SerialPort(selectedUSBPort);
                    if (!serialPort.openReadWrite()) {
                      print(SerialPort.lastError);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to open serial port: ${SerialPort.lastError}'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }
                    
                    // Configure baud rate based on selected board
                    if(selectedUSBPortBoard == "Healthypi (USB)"){
                      serialPort.config.baudRate = 115200;
                    }else if(selectedUSBPortBoard == "MAX86150 Breakout"){
                      serialPort.config.baudRate = 57600;
                    } else if(selectedUSBPortBoard == "Healthypi 6 (USB)") {
                      serialPort.config.baudRate = 921600;
                    } else {
                      serialPort.config.baudRate = 57600;
                    }
                    
                    // Navigate to plot page
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => PlotSerialPage(
                              selectedPort: serialPort,
                              selectedSerialPort: selectedUSBPort,
                              selectedPortBoard: selectedUSBPortBoard,
                            )));
                  } catch (e) {
                    print('Error opening serial port: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening serial port: $e'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              MaterialButton(
                minWidth: 80.0,
                color: Colors.red,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 18.0,
                      ),
                      SizedBox(width: 4.0),
                      Text('Stop',
                          style:
                              new TextStyle(fontSize: 16.0, color: Colors.white)),
                    ],
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                onPressed: () async {
                  if (serialPort.isOpen) {
                    serialPort.close();
                  }
                },
              ),
            ],
          ),
        ],
      );
    } else {
      return Container();
    }
  }

  Widget _buildConnectionBlock() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child:
          Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
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
      drawer: buildAppDrawer(),
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
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
