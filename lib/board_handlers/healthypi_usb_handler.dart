import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/variables.dart';
import '../utils/charts.dart';
import '../utils/sizeConfig.dart';
import 'board_handler.dart';

class HealthyPiUSBHandler extends BoardHandler {
  @override
  String get boardName => 'Healthypi (USB)';

  int ppgDataCounter = 0;
  int ecgDataCounter = 0;
  int respDataCounter = 0;
  
  @override
  void processPacketData({
    required List<int> packetData,
    required List<int> ecgRespData,
    required List<int> ppgData,
    required int packetType,
    required Function(BoardDataUpdate) onDataUpdate,
  }) {
    if (packetType == 4) {
      _processPPGData(ppgData, onDataUpdate);
    } else if (packetType == 3) {
      _processECGRespData(ecgRespData, onDataUpdate);
    } else if (packetType == 2) {
      _processGeneralData(packetData, onDataUpdate);
    }
  }
  
  void _processPPGData(List<int> ppgData, Function(BoardDataUpdate) onDataUpdate) {
    List<FlSpot> newPpgData = [];
    
    for (int i = 0; i < 8; i++) {
      final buffer = [ppgData[i * 2], ppgData[(i * 2) + 1]];
      final data = buffer[0] | buffer[1] << 8;
      newPpgData.add(FlSpot(ppgDataCounter++ as double, data.toDouble()));
    }
    
    final spO2 = ppgData[16];
    final temp = ((ppgData[17] | ppgData[18] << 8) / 100.0);
    
    onDataUpdate(BoardDataUpdate(
      ppgData: newPpgData,
      spO2: spO2,
      temperature: temp,
      displaySpO2: spO2 == 25 ? "--" : "$spO2 %",
    ));
  }
  
  void _processECGRespData(List<int> ecgRespData, Function(BoardDataUpdate) onDataUpdate) {
    List<FlSpot> newEcgData = [];
    List<FlSpot> newRespData = [];
    
    // Process ECG data (8 samples)
    for (int i = 0; i < 8; i++) {
      final buffer = [
        ecgRespData[i * 4],
        ecgRespData[(i * 4) + 1],
        ecgRespData[(i * 4) + 2],
        ecgRespData[(i * 4) + 3]
      ];
      final data = buffer[0] | buffer[1] << 8 | buffer[2] << 16 | buffer[3] << 24;
      newEcgData.add(FlSpot(ecgDataCounter++ as double, data.toSigned(32).toDouble()));
    }
    
    // Process Respiration data (4 samples)
    for (int i = 0; i < 4; i++) {
      final buffer = [
        ecgRespData[(i * 4) + 32],
        ecgRespData[(i * 4) + 33],
        ecgRespData[(i * 4) + 34],
        ecgRespData[(i * 4) + 35]
      ];
      final data = buffer[0] | buffer[1] << 8 | buffer[2] << 16 | buffer[3] << 24;
      newRespData.add(FlSpot(respDataCounter++ as double, data.toSigned(32).toDouble()));
    }
    
    onDataUpdate(BoardDataUpdate(
      ecgData: newEcgData,
      respData: newRespData,
      heartRate: ecgRespData[48],
      respRate: ecgRespData[49],
    ));
  }
  
  void _processGeneralData(List<int> packetData, Function(BoardDataUpdate) onDataUpdate) {
    // Implementation for packet type 2
    // ...existing code...
  }
  
  @override
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
  }) {
    return Column(
      children: [
        _buildHeartRateDisplay(heartRate),
        buildPlots().buildChart(18, 95, ecgData, Colors.green),
        SizedBox(height: SizeConfig.blockSizeVertical * 2),
        _buildSpO2Display(displaySpO2),
        buildPlots().buildChart(18, 95, ppgData, Colors.yellow),
        SizedBox(height: SizeConfig.blockSizeVertical * 2),
        _buildRespRateDisplay(respRate),
        buildPlots().buildChart(18, 95, respData, Colors.blue),
        SizedBox(height: SizeConfig.blockSizeVertical * 2),
        _buildTemperatureDisplay(temperature),
      ],
    );
  }
  
  Widget _buildHeartRateDisplay(int heartRate) {
    return Column(children: [
      const Text("HEART RATE", style: TextStyle(fontSize: 12, color: Colors.white)),
      Text("$heartRate bpm", style: const TextStyle(fontSize: 20, color: Colors.white)),
    ]);
  }
  
  Widget _buildSpO2Display(String displaySpO2) {
    return Column(children: [
      const Text("SpO₂", style: TextStyle(fontSize: 12, color: Colors.white)),
      Text(displaySpO2, style: const TextStyle(fontSize: 20, color: Colors.white)),
    ]);
  }

  Widget _buildRespRateDisplay(int respRate) {
    return Column(children: [
      const Text("RESP RATE", style: TextStyle(fontSize: 12, color: Colors.white)),
      Text("$respRate rpm", style: const TextStyle(fontSize: 20, color: Colors.white)),
    ]);
  }

  Widget _buildTemperatureDisplay(double temperature) {
    return Column(children: [
      const Text("TEMPERATURE", style: TextStyle(fontSize: 12, color: Colors.white)),
      Text("${temperature.toStringAsFixed(1)} °C", style: const TextStyle(fontSize: 20, color: Colors.white)),
    ]);
  }

  // Other display methods...
}