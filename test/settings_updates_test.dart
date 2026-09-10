// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:OpenView/controllers/app_info_controller.dart';
import 'package:OpenView/controllers/recordings_browser_controller.dart';
import 'package:OpenView/controllers/settings_controller.dart';
import 'package:OpenView/controllers/update_controller.dart';
import 'package:OpenView/ui/screens/settings_screen.dart';

String _releaseJson(String tag) => jsonEncode({
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'body': '## What\'s Changed\n* A fix\n',
      'html_url':
          'https://github.com/Protocentral/protocentral_openview/releases/tag/$tag',
      'published_at': '2026-09-01T10:00:00Z',
      'assets': const [],
    });

Widget _host(SettingsController settings, UpdateController update,
    AppInfoController appInfo) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<UpdateController>.value(value: update),
      ChangeNotifierProvider<AppInfoController>.value(value: appInfo),
      ChangeNotifierProvider<RecordingsBrowserController>(
          create: (_) => RecordingsBrowserController(settings: settings)),
    ],
    child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
  );
}

void main() {
  late SettingsController settings;
  late AppInfoController appInfo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    settings = SettingsController();
    // Without this the app reports an empty version, every comparison is
    // "unknown", and the check can never find anything.
    PackageInfo.setMockInitialValues(
      appName: 'OpenView',
      packageName: 'com.protocentral.openview',
      version: '3.2.0',
      buildNumber: '135',
      buildSignature: '',
    );
    appInfo = AppInfoController();
    await appInfo.load();
  });

  tearDown(() => UpdateController.debugSupportedOverride = null);

  UpdateController serving(String tag) => UpdateController(
        settings: settings,
        client: MockClient((_) async => http.Response(_releaseJson(tag), 200)),
      );

  testWidgets('About offers Check for updates on self-distributed builds',
      (tester) async {
    UpdateController.debugSupportedOverride = true;
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(settings, serving('v3.2.0'), appInfo));
    await tester.pump();

    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Not checked for updates yet.'), findsOneWidget);
    // The preference lives in its own card; the check does not duplicate it.
    expect(find.text('Check for updates automatically'), findsOneWidget);
    expect(find.text('Check now'), findsNothing);
  });

  testWidgets('store builds get no update UI at all', (tester) async {
    UpdateController.debugSupportedOverride = false;
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(settings, serving('v3.9.0'), appInfo));
    await tester.pump();

    expect(find.text('Check for updates'), findsNothing);
    expect(find.text('Check for updates automatically'), findsNothing);
    // About itself is untouched.
    expect(find.text('ProtoCentral Electronics'), findsOneWidget);
  });

  testWidgets('a check that finds nothing reports it in a snackbar',
      (tester) async {
    UpdateController.debugSupportedOverride = true;
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The published release matches what we are running.
    await tester.pumpWidget(_host(settings, serving('v3.2.0'), appInfo));
    await tester.pump();

    // http completes on the real event loop, which the fake-async test clock
    // does not drive — hence runAsync around the tap.
    await tester.runAsync(() async {
      await tester.tap(find.text('Check for updates'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('OpenView 3.2.0 is the latest release.'), findsOneWidget);
    expect(find.text('You are running the latest release.'), findsOneWidget);
  });

  testWidgets('a check that finds an update opens the release notes',
      (tester) async {
    UpdateController.debugSupportedOverride = true;
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(settings, serving('v9.9.9'), appInfo));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Check for updates'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('OpenView 9.9.9'), findsOneWidget);
    expect(find.text('Skip this version'), findsOneWidget);
  });
}
