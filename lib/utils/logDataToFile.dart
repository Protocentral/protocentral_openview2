import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../globals.dart';
import 'showSuccessDialog.dart';


Future<void> writeLogDataToFile(List<double> ecgData, List<double> ppgData, List<double> respData, BuildContext context) async {
  hPi4Global().logConsole("Log data size: " + ecgData.length.toString());

  List<List<String>> dataList = []; //Outter List which contains the data List

  List<String> header = [];
  header.add("ECG");
  header.add("RESPIRATION");
  header.add("PPG");

  dataList.add(header);

  for (int i = 0; i < (ecgData.length - 50); i++) {
    List<String> dataRow = [
      (ecgData[i]).toString(),
      (respData[i]).toString(),
      (ppgData[i]).toString(),
    ];
    dataList.add(dataRow);
  }

  // Code to convert logData to CSV file
  String csv = const ListToCsvConverter().convert(dataList);
  final String logFileTime = DateTime.now().millisecondsSinceEpoch.toString();

  Directory _directory = Directory("");

  if (Platform.isAndroid) {
    // Redirects it to download folder in android
    _directory = Directory("/storage/emulated/0/Download");
  } else {
    _directory = await getApplicationDocumentsDirectory();
  }

  final exPath = _directory.path;
  print("Saved Path: $exPath");
  await Directory(exPath).create(recursive: true);

  final String directory = exPath;

  File file = File('$directory/logdatafromApp$logFileTime.csv');
  print("Save file");

  await file.writeAsString(csv);

  print("File exported successfully!");

  await showDownloadSuccessDialog(context);
}