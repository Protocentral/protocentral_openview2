// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:OpenView/controllers/settings_controller.dart';
import 'package:OpenView/controllers/update_controller.dart';

/// Trimmed shape of a GitHub `/releases/latest` payload.
Map<String, dynamic> _release({
  String tag = 'v3.3.0',
  bool prerelease = false,
  bool draft = false,
  List<String> assetNames = const [
    'OpenView-linux-x64.zip',
    'OpenView-linux-arm64.zip',
    'OpenView-windows-x64.zip',
    'OpenView-macos-universal.zip',
    'SHA256SUMS.txt',
  ],
}) {
  return jsonDecode(jsonEncode({
    'tag_name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'body': '## What\'s Changed\n* Thing by @akw in '
        'https://github.com/Protocentral/protocentral_openview/pull/42\n',
    'html_url':
        'https://github.com/Protocentral/protocentral_openview/releases/tag/$tag',
    'published_at': '2026-09-01T10:00:00Z',
    'assets': [
      for (final n in assetNames)
        {
          'name': n,
          'size': 50331648,
          'browser_download_url':
              'https://github.com/Protocentral/protocentral_openview/releases/download/$tag/$n',
        },
    ],
  })) as Map<String, dynamic>;
}

void main() {
  group('version comparison', () {
    test('detects a newer release', () {
      expect(UpdateController.isNewer('3.3.0', '3.2.0'), isTrue);
      expect(UpdateController.isNewer('3.2.1', '3.2.0'), isTrue);
      expect(UpdateController.isNewer('4.0.0', '3.9.9'), isTrue);
    });

    test('same or older never prompts', () {
      expect(UpdateController.isNewer('3.2.0', '3.2.0'), isFalse);
      expect(UpdateController.isNewer('3.1.9', '3.2.0'), isFalse);
      expect(UpdateController.isNewer('2.9.9', '3.0.0'), isFalse);
    });

    test('build metadata is ignored', () {
      // pubspec reports 3.2.0+135; the tag is v3.2.0 — the same release.
      expect(UpdateController.isNewer('3.2.0', '3.2.0+135'), isFalse);
      expect(UpdateController.isNewer('3.2.1', '3.2.0+135'), isTrue);
    });

    test('a leading v is tolerated on either side', () {
      expect(UpdateController.isNewer('v3.3.0', '3.2.0'), isTrue);
      expect(UpdateController.isNewer('3.2.0', 'v3.2.0'), isFalse);
    });

    test('short versions pad with zeros', () {
      expect(UpdateController.isNewer('3.3', '3.2.9'), isTrue);
      expect(UpdateController.isNewer('4', '3.9.9'), isTrue);
    });

    test('a prerelease sorts below its release', () {
      expect(UpdateController.compareVersions('3.3.0-rc1', '3.3.0'),
          lessThan(0));
      expect(UpdateController.compareVersions('3.3.0', '3.3.0-rc1'),
          greaterThan(0));
      expect(UpdateController.isNewer('3.3.0-rc1', '3.2.0'), isTrue);
    });

    test('unparseable input never triggers a prompt', () {
      expect(UpdateController.isNewer('nightly', '3.2.0'), isFalse);
      expect(UpdateController.isNewer('3.2.0', ''), isFalse);
      expect(UpdateController.isNewer('3.x.0', '3.2.0'), isFalse);
      expect(UpdateController.isNewer('1.2.3.4', '3.2.0'), isFalse);
    });
  });

  group('release parsing', () {
    test('reads version, notes and page URL', () {
      final info = UpdateController.parseRelease(_release())!;
      expect(info.version, '3.3.0'); // leading v stripped
      expect(info.notes, contains('What\'s Changed'));
      expect(info.pageUrl, endsWith('/releases/tag/v3.3.0'));
      expect(info.publishedAt, isNotNull);
    });

    test('picks up SHA256SUMS.txt for verification', () {
      final info = UpdateController.parseRelease(_release())!;
      expect(info.checksumsUrl, endsWith('SHA256SUMS.txt'));
    });

    test('drafts and prereleases are ignored', () {
      expect(UpdateController.parseRelease(_release(draft: true)), isNull);
      expect(UpdateController.parseRelease(_release(prerelease: true)), isNull);
    });

    test('a tag that is not a version is ignored', () {
      expect(UpdateController.parseRelease(_release(tag: 'nightly')), isNull);
      expect(UpdateController.parseRelease(_release(tag: '')), isNull);
    });

    test('a release with no matching asset still offers the page', () {
      final info =
          UpdateController.parseRelease(_release(assetNames: const []))!;
      expect(info.assetUrl, isNull);
      expect(info.downloadUrl, info.pageUrl);
    });

    test('size renders as MB', () {
      final info = UpdateController.parseRelease(_release())!;
      // Only meaningful when this host matched an asset.
      if (info.assetBytes != null) {
        expect(info.assetSizeLabel, '48.0 MB');
      }
    });
  });

  group('asset selection', () {
    // These names must track the Package steps in
    // .github/workflows/release.yml.
    test('maps each desktop platform to its release zip', () {
      expect(
        UpdateController.assetNameForCurrentPlatform(overridePlatform: 'macos'),
        'OpenView-macos-universal.zip',
      );
      expect(
        UpdateController.assetNameForCurrentPlatform(
            overridePlatform: 'windows'),
        'OpenView-windows-x64.zip',
      );
      expect(
        UpdateController.assetNameForCurrentPlatform(
            overridePlatform: 'linux', arm64: false),
        'OpenView-linux-x64.zip',
      );
      expect(
        UpdateController.assetNameForCurrentPlatform(
            overridePlatform: 'linux', arm64: true),
        'OpenView-linux-arm64.zip',
      );
    });

    test('mobile has no self-distributed asset', () {
      expect(
        UpdateController.assetNameForCurrentPlatform(
            overridePlatform: 'android'),
        isNull,
      );
      expect(
        UpdateController.assetNameForCurrentPlatform(overridePlatform: 'ios'),
        isNull,
      );
    });
  });

  group('check flow', () {
    late SettingsController settings;
    var requests = 0;

    setUp(() {
      UpdateController.debugSupportedOverride = true;
      settings = SettingsController();
      requests = 0;
    });

    tearDown(() => UpdateController.debugSupportedOverride = null);

    UpdateController withResponse(http.Response Function() respond) {
      return UpdateController(
        settings: settings,
        client: MockClient((_) async {
          requests++;
          return respond();
        }),
      );
    }

    UpdateController serving({String tag = 'v3.3.0'}) =>
        withResponse(() => http.Response(jsonEncode(_release(tag: tag)), 200));

    test('a newer release becomes available', () async {
      final update = serving();
      await update.checkNow('3.2.0+135');

      expect(update.status, UpdateStatus.available);
      expect(update.info!.version, '3.3.0');
      expect(update.currentVersion, '3.2.0+135');
    });

    test('the same release reports up to date', () async {
      final update = serving(tag: 'v3.2.0');
      await update.checkNow('3.2.0+135');

      expect(update.status, UpdateStatus.upToDate);
      expect(update.info, isNull);
    });

    test('every completed check stamps the clock', () async {
      final update = serving(tag: 'v3.2.0');
      await update.checkNow('3.2.0');
      expect(settings.lastUpdateCheck, isNotNull);
    });

    test('a rate limit fails quietly', () async {
      final update = withResponse(() => http.Response('{}', 403));
      await update.checkNow('3.2.0');

      expect(update.status, UpdateStatus.failed);
      expect(update.error, contains('403'));
      expect(update.info, isNull);
    });

    test('being offline fails quietly', () async {
      final update = withResponse(() => throw const SocketException('down'));
      await update.checkNow('3.2.0');

      expect(update.status, UpdateStatus.failed);
      expect(update.error, 'No network connection.');
    });

    test('startup check honours the opt-out', () async {
      await settings.setAutoCheckUpdates(false);
      final update = serving();
      await update.checkAtStartup('3.2.0');

      expect(requests, 0);
      expect(update.status, UpdateStatus.idle);
    });

    test('startup check runs at most once a day', () async {
      final update = serving();
      await update.checkAtStartup('3.2.0');
      expect(requests, 1);

      await update.checkAtStartup('3.2.0'); // clock was just stamped
      expect(requests, 1);
    });

    test('a skipped version is silent at startup but not on demand', () async {
      await settings.setSkippedUpdateVersion('3.3.0');

      final startup = serving();
      await startup.checkAtStartup('3.2.0');
      expect(startup.status, UpdateStatus.upToDate);
      expect(startup.hasBanner, isFalse);

      final manual = serving();
      await manual.checkNow('3.2.0');
      expect(manual.status, UpdateStatus.available);
      expect(manual.hasBanner, isTrue);
    });

    test('skipping records the version and clears the banner', () async {
      final update = serving();
      await update.checkNow('3.2.0');
      await update.skipCurrentFinding();

      expect(settings.skippedUpdateVersion, '3.3.0');
      expect(update.info, isNull);
      expect(update.hasBanner, isFalse);
    });

    test('store builds never issue a request', () async {
      UpdateController.debugSupportedOverride = null; // default: store
      final update = serving();
      await update.checkNow('3.2.0');
      await update.checkAtStartup('3.2.0');

      expect(requests, 0);
      expect(update.status, UpdateStatus.idle);
    });
  });

  group('distribution channel', () {
    test('defaults to store, so store builds never check', () {
      // No --dart-define under `flutter test`, so this is the default path.
      expect(UpdateChannel.isSelfDistributed, isFalse);
    });
  });
}
