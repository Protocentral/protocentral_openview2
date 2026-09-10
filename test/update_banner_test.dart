// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:OpenView/controllers/settings_controller.dart';
import 'package:OpenView/controllers/update_controller.dart';
import 'package:OpenView/ui/widgets/update_banner.dart';

const _info = UpdateInfo(
  version: '3.3.0',
  notes: '## What\'s Changed\n'
      '* Decode pktType 3 absolute skin conductance by @akw in '
      'https://github.com/Protocentral/protocentral_openview/pull/42\n'
      '* Remove USB VID/PID board auto-detection in '
      'https://github.com/Protocentral/protocentral_openview/pull/43\n'
      '\n**Full Changelog**: 3.2.0...3.3.0',
  pageUrl:
      'https://github.com/Protocentral/protocentral_openview/releases/tag/v3.3.0',
  assetUrl: 'https://example.invalid/OpenView-macos-universal.zip',
  assetName: 'OpenView-macos-universal.zip',
  assetBytes: 50331648,
  checksumsUrl: 'https://example.invalid/SHA256SUMS.txt',
);

Widget _host(UpdateController update, {required Size size}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<UpdateController>.value(value: update),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(children: [UpdateBanner(), Expanded(child: SizedBox())]),
        ),
      ),
    ),
  );
}

void main() {
  late UpdateController update;

  setUp(() {
    UpdateController.debugSupportedOverride = true;
    update = UpdateController(settings: SettingsController());
  });

  tearDown(() => UpdateController.debugSupportedOverride = null);

  testWidgets('collapses to nothing when there is no update', (tester) async {
    await tester.pumpWidget(_host(update, size: const Size(1400, 900)));
    expect(find.byType(UpdateBanner), findsOneWidget);
    expect(tester.getSize(find.byType(UpdateBanner)).height, 0);
  });

  testWidgets('shows the version and the current one when available',
      (tester) async {
    update.debugSetAvailable(_info);
    await tester.pumpWidget(_host(update, size: const Size(1400, 900)));

    expect(find.textContaining('OpenView 3.3.0 is available'), findsOneWidget);
    expect(find.textContaining('you have 3.2.0'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow on a narrow window', (tester) async {
    update.debugSetAvailable(_info);
    // Below the 720 dp breakpoint, and below the 900 dp desktop minimum —
    // the banner also renders on phones.
    await tester.pumpWidget(_host(update, size: const Size(400, 800)));
    expect(tester.takeException(), isNull);
    expect(find.byType(UpdateBanner), findsOneWidget);
  });

  testWidgets('dismiss hides the banner for the session', (tester) async {
    update.debugSetAvailable(_info);
    await tester.pumpWidget(_host(update, size: const Size(1400, 900)));

    await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
    await tester.pumpAndSettle();

    expect(find.textContaining('is available'), findsNothing);
    expect(update.status, UpdateStatus.available); // state kept, just hidden
  });

  testWidgets('details dialog renders flattened release notes',
      (tester) async {
    update.debugSetAvailable(_info);
    await tester.pumpWidget(_host(update, size: const Size(1400, 900)));

    await tester.tap(find.text("What's new"));
    await tester.pumpAndSettle();

    expect(find.text('OpenView 3.3.0'), findsOneWidget);
    // Heading markers stripped, bullets rewritten, PR URLs collapsed to #42.
    expect(find.text("What's Changed"), findsOneWidget);
    expect(
      find.textContaining('•  Decode pktType 3 absolute skin conductance'),
      findsOneWidget,
    );
    expect(find.textContaining('#42'), findsOneWidget);
    expect(find.textContaining('https://github.com'), findsNothing);
    // Asset name + size and the checksum link are offered.
    expect(find.textContaining('OpenView-macos-universal.zip'), findsOneWidget);
    expect(find.textContaining('48.0 MB'), findsOneWidget);
    expect(find.text('SHA-256 checksums'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip this version clears the banner', (tester) async {
    update.debugSetAvailable(_info);
    await tester.pumpWidget(_host(update, size: const Size(1400, 900)));

    await tester.tap(find.text("What's new"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this version'));
    await tester.pumpAndSettle();

    expect(find.textContaining('is available'), findsNothing);
    expect(update.info, isNull);
  });
}
