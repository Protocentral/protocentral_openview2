import 'package:flutter/cupertino.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../globals.dart';

class SubscribeToCharacters extends ChangeNotifier{

  late QualifiedCharacteristic CommandCharacteristic;
  late QualifiedCharacteristic ECGCharacteristic;
  late QualifiedCharacteristic PPGCharacteristic;
  late QualifiedCharacteristic RESPCharacteristic;
  late QualifiedCharacteristic BatteryCharacteristic;
  late QualifiedCharacteristic HRCharacteristic;
  late QualifiedCharacteristic SPO2Characteristic;
  late QualifiedCharacteristic TempCharacteristic;
  late QualifiedCharacteristic HRVRespCharacteristic;
  late QualifiedCharacteristic commandTxCharacteristic;
  late QualifiedCharacteristic dataCharacteristic;

  Future<void> subscribeToCharacteristics(String currentDeviceID) async {
    ECGCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_ECG_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_ECG_SERVICE),
        deviceId: currentDeviceID);

    RESPCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_RESP_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_ECG_SERVICE),
        deviceId: currentDeviceID);

    PPGCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HIST),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HRV),
        deviceId: currentDeviceID);

    HRCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HR),
        deviceId: currentDeviceID);

    SPO2Characteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_SPO2_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_SPO2),
        deviceId: currentDeviceID);

    TempCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_TEMP_CHAR),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HEALTH_THERM),
        deviceId: currentDeviceID);

    HRVRespCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_HRV),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_HRV),
        deviceId: currentDeviceID);

    CommandCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERVICE_CMD),
        deviceId: currentDeviceID);

    dataCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_DATA),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: currentDeviceID);

    commandTxCharacteristic = QualifiedCharacteristic(
        characteristicId: Uuid.parse(hPi4Global.UUID_CHAR_CMD),
        serviceId: Uuid.parse(hPi4Global.UUID_SERV_CMD_DATA),
        deviceId: currentDeviceID);
  }
}
