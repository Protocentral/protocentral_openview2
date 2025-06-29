import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../globals.dart';
import 'showSuccessDialog.dart';


Future<void> writeLogDataToFile(List<double> ecgData, List<double> ppgData, List<double> respData, BuildContext context) async {
  //hPi4Global().logConsole("Log data size: " + ecgData.length.toString());
  //hPi4Global().logConsole("Log data size1: " + ppgData.length.toString());
  //hPi4Global().logConsole("Log data size2: " + respData.length.toString());

  List<List<String>> ecgDataList = []; //Outter List which contains the data List
  List<List<String>> ppgDataList = []; //Outter List which contains the data List
  List<List<String>> respDataList = []; //Outter List which contains the data List

  List<String> ecgHeader = [];
  List<String> ppgHeader = [];
  List<String> respHeader = [];

  ecgHeader.add("ECG");
  respHeader.add("RESPIRATION");
  ppgHeader.add("PPG");

  ecgDataList.add(ecgHeader);
  ppgDataList.add(ppgHeader);
  respDataList.add(respHeader);

  for (int i = 0; i < (ecgData.length)-10; i++) {
    List<String> dataRow = [
      (ecgData[i]).toString(),
      //(respData[i]).toString(),
      //(ppgData[i]).toString(),
    ];
    ecgDataList.add(dataRow);
  }

  for (int i = 0; i < (ppgData.length)-10; i++) {
    List<String> dataRow = [
      (ppgData[i]).toString(),
    ];
    ppgDataList.add(dataRow);
  }

  for (int i = 0; i < (respData.length)-10; i++) {
    List<String> dataRow = [
      (respData[i]).toString(),
    ];
    respDataList.add(dataRow);
  }


  // Code to convert logData to CSV file
  String ecgCSV = const ListToCsvConverter().convert(ecgDataList);
  String ppgCSV = const ListToCsvConverter().convert(ppgDataList);
  String respCSV = const ListToCsvConverter().convert(respDataList);

  final String logFileTime = DateTime.now().millisecondsSinceEpoch.toString();

  Directory? _directory = Directory("");

  if (Platform.isAndroid) {
    // Redirects it to download folder in android
    _directory = Directory("/storage/emulated/0/Download");
  } else {
    //_directory = await getApplicationDocumentsDirectory();
    //_directory = await getTemporaryDirectory();
     _directory = await getDownloadsDirectory();
  }

  final exPath = _directory?.path;
  print("Saved Path: $exPath");
  await Directory(exPath!).create(recursive: true);


  final String directory = exPath;

  File file = File('$directory/logfromAppECG$logFileTime.csv');
  print("Save file");

  await file.writeAsString(ecgCSV);

  File file1 = File('$directory/logfromAppPPG$logFileTime.csv');
  print("Save file 1");

  await file1.writeAsString(ppgCSV);

  File file2 = File('$directory/logfromAppResp$logFileTime.csv');
  print("Save file 1");

  await file2.writeAsString(respCSV);


  print("File exported successfully!");

  await showDownloadSuccessDialog(context);
}
