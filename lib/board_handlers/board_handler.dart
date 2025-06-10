import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

abstract class BoardHandler {
  String get boardName;
  
  void processPacketData({
    required List<int> packetData,
    required List<int> ecgRespData,
    required List<int> ppgData,
    required int packetType,
    required Function(BoardDataUpdate) onDataUpdate,
  });
  
  Widget buildChartLayout({
    required List<FlSpot> ecgData,
    required List<FlSpot> ppgData,
    required List<FlSpot> respData,
    required List<List<FlSpot>> eegData,
    required int heartRate,
    required int spO2,
    required int respRate,
    required double temperature,
    required String displaySpO2,
  });
}

class BoardDataUpdate {
  final List<FlSpot>? ecgData;
  final List<FlSpot>? ppgData;
  final List<FlSpot>? respData;
  final List<List<FlSpot>>? eegData;
  final int? heartRate;
  final int? spO2;
  final int? respRate;
  final double? temperature;
  final String? displaySpO2;
  
  BoardDataUpdate({
    this.ecgData,
    this.ppgData,
    this.respData,
    this.eegData,
    this.heartRate,
    this.spO2,
    this.respRate,
    this.temperature,
    this.displaySpO2,
  });
}