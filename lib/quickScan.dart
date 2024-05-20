import 'dart:ffi';
import 'package:path_provider/path_provider.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'ble/ble_scanner.dart';
import 'states/OpenViewBLEProvider.dart';
import 'package:provider/provider.dart';

import 'globals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:io';

import 'package:progress_indicators/progress_indicators.dart';

class QuickScanPage extends StatefulWidget {
  @override
  _QuickScanPageState createState() => _QuickScanPageState();
}

class _QuickScanPageState extends State<QuickScanPage> {

  final _scrollController = ScrollController();

  String debugOutput = "";
  int globalDFUProgress = 0;
  late ProgressDialog prDFU;
  bool dfuRunning = false;

  String displayText = "--";
  int _selectedDeviceIndex = 0;

  //PermissionStatus permStatus;

  String _currentDFUDeviceID = "";

  @override
  void initState() {
    super.initState();
  }

  void showLoadingIndicator(String text) {
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

  Widget _buildDeviceList() {
    return Consumer<OpenViewBLEProvider>(builder: (context, patchble, child) {
      return Card(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 32, 8, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                child: Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2.0, 2.0, 8.0, 2.0),
                      child: Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    const Text('Scan for devices',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        )),
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue),
                ),
                onPressed: () async {
                  if (Platform.isAndroid) {
                    bool bleStatusFlag = await patchble.getBleStatus();
                    if (await patchble.checkPermissions(
                            context, bleStatusFlag) ==
                        true) {
                      Provider.of<BleScanner>(context, listen: false)
                          .startScan([], "");
                    } else {}
                  } else {
                    Provider.of<BleScanner>(context, listen: false)
                        .startScan([], "");
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'QuickScan Results',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ),
        Consumer2<BleScannerState, OpenViewBLEProvider>(
            builder: (context, bleScanner, patchBLE, child) {
          return Column(
            children: [
              ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: bleScanner.discoveredDevices.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const Divider(),
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(bleScanner.discoveredDevices[index].name),
                            ],
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("ID: ${bleScanner.discoveredDevices[index].id}" +
                                    "\n" +
                                    "RSSI: ${bleScanner.discoveredDevices[index].rssi}"),
                              ]),
                        ],
                      ),
                      leading: Column(children: [
                        Icon(Icons.bluetooth),
                      ]),
                      /*trailing: BatteryIndicator(
                        batteryFromPhone: false,
                        batteryLevel: bleScanner
                            .discoveredDevices[index].manufacturerData[2],
                        style: BatteryIndicatorStyle.skeumorphism,
                        colorful: true,
                        showPercentNum: true,
                        //mainColor: _color,
                        size: 20,
                        //ratio: _ratio,
                        //showPercentSlide: _showPercentSlide,
                      ),*/
                      /*onTap: () async {

                    },*/
                    );
                  }),
              //_buildCheckforUpdatesButton(bleScanner.discoveredDevices),
            ],
          );
        }),
      ]));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: WiserGlobal.appBackgroundColor,
        appBar: AppBar(
          backgroundColor: hPi4Global.hpi4Color,
          leading:
              Consumer<BleScannerState>(builder: (context, bleScanner, child) {
            return new IconButton(
                icon: new Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  await Provider.of<BleScanner>(context, listen: false)
                      .stopScan();
                  Navigator.of(context).pop();
                });
          }),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Image.asset('assets/proto-online-white.png',
                  fit: BoxFit.fitWidth, height: 30),
            ],
          ),
        ),
        body:Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 10,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  //mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    _buildDeviceList(),

                  ]),
            ),
          ),
        ),
    );
  }
}
