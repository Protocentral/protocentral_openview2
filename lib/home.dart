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
import 'sizeConfig.dart';
import 'utils/variables.dart';
import 'ble/ble_scanner.dart';
import 'utils/showTerms.dart';
import 'utils/showPrivacy.dart';
import 'utils/loadingDialog.dart';
import 'states/OpenViewBLEProvider.dart';

late FlutterReactiveBle _fble;
late StreamSubscription<ConnectionStateUpdate> _connection;
late SerialPort _serialPort;

String pcCurrentDeviceID = "";
String pcCurrentDeviceName = "";
String _selectedBoard = 'Healthypi';
String _selectedPort = 'Port';
String selectedPortBoard = 'Healthypi';

bool connectedToDevice = false;

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

  Widget _getPoliciesTile() {
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
    _fble =
        await Provider.of<OpenViewBLEProvider>(context, listen: false).getBLE();

    _connection = _fble.connectToDevice(id: currentDevice.id).listen(
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
                    selectedBoard: _selectedBoard,
                    selectedDevice: pcCurrentDeviceName,
                    currentDevice: currentDevice,
                    fble: _fble,
                    currConnection: _connection,
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
    int recdMTU = await _fble.requestMtu(deviceId: deviceMAC, mtu: 200);
    hPi4Global().logConsole("MTU negotiated: " + recdMTU.toString());
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
                controller: _controller,
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
    if (Platform.isMacOS || Platform.isWindows) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Select Board:",
              style: TextStyle(color: Colors.black, fontSize: 16.0)),
          SizedBox(
            width: 20.0,
          ),
          DropdownButton(
            underline: SizedBox(),
            dropdownColor: hPi4Global.hpi4Color,
            hint: selectedPortBoard == null
                ? Text('Select Board')
                : Text(
                    selectedPortBoard,
                    style:
                        TextStyle(color: hPi4Global.hpi4Color, fontSize: 16.0),
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
            width: 50.0,
          ),
          Text("Select Port:",
              style: TextStyle(color: Colors.black, fontSize: 16.0)),
          SizedBox(
            width: 20.0,
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
            width: 50.0,
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
                      style:
                          new TextStyle(fontSize: 18.0, color: Colors.white)),
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
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => PlotSerialPage(
                        selectedPort: _serialPort,
                        selectedSerialPort: _selectedPort,
                        selectedPortBoard: selectedPortBoard,
                      )));
            },
          ),
          SizedBox(
            width: 30.0,
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
                      style:
                          new TextStyle(fontSize: 18.0, color: Colors.white)),
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
        child: SingleChildScrollView(
          controller: _scrollController,
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
