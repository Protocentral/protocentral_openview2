import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../globals.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';

class OpenViewBLEProvider extends ChangeNotifier {
  OpenViewBLEProvider({required FlutterReactiveBle ble}) : _ble = ble;

  final FlutterReactiveBle _ble;
  String patchCurrentDeviceName = "";
  DateTime patchLastSeen = DateTime(1800);

  bool connectedToDevice = false;

  DeviceConnectionState currentConnState = DeviceConnectionState.disconnected;

  late StreamSubscription<ConnectionStateUpdate> _connection;

  String devConsoleStatus = "--";

  bool flagCommandSubStarted = false;
  bool flagDataSubStarted = false;

  StreamSubscription? _subscription;


  void logConsole(String logString) {
    print("AKW - " + logString);
    //devConsoleStatus = logString;
    //notifyListeners();
  }

  Future<FlutterReactiveBle> getBLE() async {
    return _ble;
  }

  bool flagLooking = false;

  bool getLookingStatus() {
    return flagLooking;
  }

  bool getBleStatus() {
    if (_ble.status == BleStatus.poweredOff) {
      return true;
    } else {
      return false;
    }
  }

  Future waitWhile(bool test(), [Duration pollInterval = Duration.zero]) {
    var completer = new Completer();
    check() {
      if (!test()) {
        completer.complete();
      } else {
        new Timer(pollInterval, check);
      }
    }

    check();
    return completer.future;
  }

  Future<void> stopScan() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _showPermissionOffDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions required'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Icon(
                  Icons.location_disabled_rounded,
                  color: Colors.red,
                  size: 48,
                ),
                Center(
                    child: Text(
                        'Patch needs permission to use location serviceto scan for Bluetooth Devices.')),
                Center(
                    child: Text(
                        'Please allow permission when prompted. Location will NOT be used for any tracking')),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLocationOffDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Service Required'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Icon(
                  Icons.location_disabled_rounded,
                  color: Colors.red,
                  size: 48,
                ),
                Center(
                    child: Text(
                        'You need to turn on location services on your device to scan for Bluetooth Devices.')),
                Center(
                    child: Text(
                        'Patch cannot proceed without location enabled. Please enable and retry.')),
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

  Future<bool> checkPermissions(context, bool bleStatusFlag) async {
    if (!await Permission.location.isGranted) {
      await Permission.location.request();
    }

    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }

    if (!await Permission.bluetoothScan.isGranted) {
      await Permission.bluetoothScan.request();
    }

    if (!await Permission.bluetoothConnect.isGranted) {
      await Permission.bluetoothConnect.request();
    }

    bool _locationServiceEnabled;
    bool _bluetoothServiceEnabled = false;
    bool _permBluetoothEnabled = false;
    bool _permLocationEnabled = false;
    //PermissionStatus _permissionGranted;
    //LocationData _locationData;

    var locationStatus = await Permission.location.status;
    if (locationStatus.isDenied) {
      print("Permission is denied.");
      _showPermissionOffDialog(context);
    } else if (locationStatus.isGranted) {
      print("Permission is already granted.");
      _permLocationEnabled = true;
    } else if (locationStatus.isPermanentlyDenied) {
      //permission is permanently denied.
      print("Permission is permanently denied");
      _showPermissionOffDialog(context);
      await Permission.bluetoothScan.request();
      //await Permission.locationAlways.request();
    } else if (locationStatus.isRestricted) {
      //permission is OS restricted.
      print("Permission is OS restricted.");
      _showPermissionOffDialog(context);
    }

    var bluetoothStatus = await Permission.bluetoothScan.status;
    if (bluetoothStatus.isDenied) {
      print("Permission is denied.");
      _showPermissionOffDialog(context);
    } else if (bluetoothStatus.isGranted) {
      print("Permission is already granted.");
      _permBluetoothEnabled = true;
    } else if (bluetoothStatus.isPermanentlyDenied) {
      //permission is permanently denied.
      print("Permission is permanently denied");
      _showPermissionOffDialog(context);
      await Permission.bluetoothScan.request();
      //await Permission.locationAlways.request();
    } else if (bluetoothStatus.isRestricted) {
      //permission is OS restricted.
      print("Permission is OS restricted.");
      _showPermissionOffDialog(context);
    }

    if (bleStatusFlag) {
      print('bluetooth is OFF');
      //_bluetoothServiceEnabled = false;
      BluetoothEnable.enableBluetooth;
    } else {
      print('bluetooth is ON');
      _bluetoothServiceEnabled = true;
    }

    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_locationServiceEnabled) {
      //AKW: User rejected to turn on location. Display dialog
      _showLocationOffDialog(context);
      return false;
    }

    if (_permLocationEnabled == true &&
        _permBluetoothEnabled == true &&
        _locationServiceEnabled == true &&
        _bluetoothServiceEnabled == true) {
      return true;
    }

    return false;
  }

  Future<bool> connect(String deviceID) async {
    bool retval = false;
    //await refreshScan();

    await Future.delayed(Duration(seconds: 4), () async {
      if (deviceID != "") {
        retval = await connectLowLevel(deviceID);
      } else {
        logConsole("Invalid MAC $deviceID . Device not found");
        retval = false;
      }
    });
    return retval;
  }

  Future<bool> connectLowLevel(String deviceID) async {
    bool retval = false;
    logConsole('Initiated connection to device: $deviceID');

    _connection = _ble.connectToDevice(id: deviceID).listen((connectionStateUpdate) {
      currentConnState = connectionStateUpdate.connectionState;
      notifyListeners();
      logConsole("Connect device: " + connectionStateUpdate.toString());
      if (connectionStateUpdate.connectionState ==
          DeviceConnectionState.connected) {
        logConsole("Connected !");
        connectedToDevice = true;
        retval = true;
      }
      //if(connectionState.failure.code.toString();)
    }, onError: (dynamic error) {
      logConsole("Connect error: " + error.toString());
    });
    return retval;
  }

  Future<void> disconnect() async {
    //String deviceID = patchCurrentMAC;
    try {
      logConsole('Disconnecting ');
      if (connectedToDevice == true) await _connection.cancel();
    } on Exception catch (e, _) {
      logConsole("Error disconnecting from a device: $e");
    } finally {
      // Since [_connection] subscription is terminated, the "disconnected" state cannot be received and propagated
      /*_deviceConnectionController.add(
        ConnectionStateUpdate(
          deviceId: deviceID,
          connectionState: DeviceConnectionState.disconnected,
          failure: null,
        ),
      );*/

    }
  }

  Future<bool> patchStartConnecting(
      bool connectToDevice, String deviceID) async {
    bool retval = false;
    logConsole("connecting to.... " + deviceID);
    if (connectToDevice == true) {
      await connect(deviceID);
    }

    await Future.delayed(Duration(seconds: 2), () async {
      if (connectedToDevice == true) {

        await patchSetMTU(deviceID);
        logConsole("connected.....: " + deviceID);
        retval = true;
      } else {
        logConsole("Device not connected");
        retval = false;
      }
    });
    return retval;
  }

  Future<void> patchConnect(String deviceID) async {
    logConsole("Connection initiated to : " + deviceID);

    await Future.delayed(Duration(seconds: 2), () async {
      await connect(deviceID);
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
              //content: LoadingIndicator(text: text),
            ));
      },
    );
  }

  Future<void> patchSetMTU(String deviceMAC) async {
    int recdMTU = await _ble.requestMtu(deviceId: deviceMAC, mtu: 230);
    logConsole("MTU negotiated: " + recdMTU.toString());
  }


}
