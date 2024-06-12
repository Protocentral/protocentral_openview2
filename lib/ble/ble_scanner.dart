import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:meta/meta.dart';
import 'package:provider/provider.dart';

import 'reactive_state.dart';

class BleScanner implements ReactiveState<BleScannerState> {
  BleScanner({
    required FlutterReactiveBle ble,
    required Function(String message) logMessage,
  })  : _ble = ble,
        _logMessage = logMessage;

  final FlutterReactiveBle _ble;
  final void Function(String message) _logMessage;
  final StreamController<BleScannerState> _stateStreamController =
      StreamController();

  final _devices = <DiscoveredDevice>[];

  int patchBatteryLevel = 0;
  int patchRecordingStatus = 0;
  bool patchRecordingFlag = false;
  double patchRecordingProgress = 0;
  String patchRecordingStatusString = "Not recording";
  String patchCurrentMAC = "";

  @override
  Stream<BleScannerState> get state => _stateStreamController.stream;

  void startScan(List<Uuid> serviceIds, String deviceID) {
    print('Start ble discovery');
    print("AKW: Looking for dev: " + deviceID);
    _devices.clear();
    _subscription?.cancel();
    _subscription =
        _ble.scanForDevices(withServices: serviceIds).listen((device) {
      final knownDeviceIndex = _devices.indexWhere((d) => d.id == device.id);
      if (knownDeviceIndex >= 0) {
        _devices[knownDeviceIndex] = device;
      } else {
        if (device.name.contains(" ")||device.name.contains("-")||device.name.contains("_")) {
          _devices.add(device);
        }
        //_devices.add(device);
      }

      _pushState();
    }, onError: (Object e) => _logMessage('Device scan fails with error: $e'));
    _pushState();
  }

  void connect(String deviceID) {
    _ble
        .connectToAdvertisingDevice(
      id: deviceID,
      withServices: [],
      prescanDuration: const Duration(seconds: 5),
      connectionTimeout: const Duration(seconds: 2),
    )
        .listen((connectionState) {
      print("AKW: Connect device: " + connectionState.toString());
    }, onError: (dynamic error) {
      // Handle a possible error
      print("AKW: Connect error: " + error.toString());
    });
  }

  void _pushState() {
    _stateStreamController.add(
      BleScannerState(
        discoveredDevices: _devices,
        scanIsInProgress: _subscription != null,
      ),
    );
  }

  Future<void> stopScan() async {
    _logMessage('Stop ble discovery');

    await _subscription?.cancel();
    _subscription = null;
    print('Stop ble discovery');
    _pushState();
  }

  Future<void> dispose() async {
    await _stateStreamController.close();
  }

  StreamSubscription? _subscription;
}

@immutable
class BleScannerState {
  const BleScannerState({
    required this.discoveredDevices,
    required this.scanIsInProgress,
  });

  final List<DiscoveredDevice> discoveredDevices;
  final bool scanIsInProgress;
}
