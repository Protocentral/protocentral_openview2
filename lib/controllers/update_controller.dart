// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../utils/platform_v3.dart';
import 'settings_controller.dart';

/// How this copy of OpenView was distributed.
///
/// Desktop zips built by `.github/workflows/release.yml` are self-distributed
/// through GitHub Releases and have no updater of their own, so they are the
/// only builds that may check for — and point at — a newer GitHub release.
/// Everything else (App Store, Google Play, and any future Flathub / distro
/// package) is updated by its store, and must never be sent to a raw zip.
///
/// CI passes `--dart-define=OV_CHANNEL=github`; the default is deliberately
/// `store`, so a build that forgets the flag stays silent rather than nagging
/// store users. To exercise the flow locally:
///
///     flutter run -d macos --dart-define=OV_CHANNEL=github
class UpdateChannel {
  UpdateChannel._();

  static const _channel = String.fromEnvironment('OV_CHANNEL', defaultValue: 'store');

  /// True only for the GitHub-Release desktop builds.
  static bool get isSelfDistributed =>
      _channel == 'github' && PlatformV3.isDesktop;
}

/// A newer release found on GitHub.
@immutable
class UpdateInfo {
  /// Version without the leading `v`, e.g. `3.3.0`.
  final String version;

  /// Raw Markdown release body (GitHub's generated notes).
  final String notes;

  /// Direct download for this OS/arch, when the release carries a matching
  /// asset. Null falls back to [pageUrl].
  final String? assetUrl;
  final String? assetName;
  final int? assetBytes;

  /// `SHA256SUMS.txt` for this release, when published.
  final String? checksumsUrl;

  /// The release page itself — always present.
  final String pageUrl;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.assetUrl,
    this.assetName,
    this.assetBytes,
    this.checksumsUrl,
    this.publishedAt,
  });

  /// Download size as `48.2 MB`, or null when unknown.
  String? get assetSizeLabel {
    final b = assetBytes;
    if (b == null || b <= 0) return null;
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Best available download target.
  String get downloadUrl => assetUrl ?? pageUrl;
}

enum UpdateStatus { idle, checking, upToDate, available, failed }

/// Checks GitHub Releases for a newer OpenView and tells the user about it.
///
/// This is a *notifier*, not an installer: it never downloads or replaces
/// anything. Silent self-update on desktop needs Developer ID signing +
/// notarization (macOS) and an installer (Windows) first — see
/// `docs/auto-update.md`. Until then, the honest thing is a banner plus a
/// browser download.
///
/// Contract for callers:
/// - [checkAtStartup] is fire-and-forget. It never throws, never blocks first
///   frame, and stays silent when offline, rate-limited, or opted out.
/// - [checkNow] is the explicit Settings button: it ignores the once-a-day
///   cadence and the skipped-version list, and always reports an outcome.
class UpdateController extends ChangeNotifier {
  static const repoOwner = 'Protocentral';
  static const repoName = 'protocentral_openview';

  /// `/releases/latest` excludes prereleases, so a `v3.3.0-rc1` tag never
  /// nags stable users.
  static const _latestReleaseApi =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static const releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  /// One automatic check per day is plenty, and keeps us far below GitHub's
  /// 60 requests/hour unauthenticated limit even on a shared office IP.
  static const _checkInterval = Duration(hours: 24);

  static const _requestTimeout = Duration(seconds: 8);

  final SettingsController _settings;
  final http.Client _client;

  /// [client] is injectable so tests can exercise the whole check flow —
  /// found / up to date / rate-limited / offline — without a network.
  UpdateController({
    required SettingsController settings,
    http.Client? client,
  })  : _settings = settings,
        _client = client ?? http.Client();

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _info;
  String? _error;
  bool _dismissed = false;
  String _currentVersion = '';

  UpdateStatus get status => _status;
  UpdateInfo? get info => _info;
  String? get error => _error;
  bool get isChecking => _status == UpdateStatus.checking;

  /// The version this build reports, for "you have x.y.z" copy.
  String get currentVersion => _currentVersion;

  /// Test-only override for [isSupported]. Widget tests get no `--dart-define`,
  /// so without this the banner can never be rendered in a test.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Whether the Settings card and the banner should exist at all.
  bool get isSupported =>
      debugSupportedOverride ?? UpdateChannel.isSelfDistributed;

  /// Banner visibility: an update we found, not skipped, not dismissed for
  /// this session.
  bool get hasBanner =>
      isSupported && _info != null && !_dismissed &&
      _status == UpdateStatus.available;

  /// Background check from `main`/app start. Honours the user's opt-out, the
  /// 24 h cadence, and any skipped version.
  Future<void> checkAtStartup(String currentVersion) async {
    if (!isSupported) return;
    if (!_settings.autoCheckUpdates) return;

    final last = _settings.lastUpdateCheck;
    if (last != null &&
        DateTime.now().difference(last) < _checkInterval) {
      return;
    }
    await _check(currentVersion, manual: false);
  }

  /// Explicit "Check now". Ignores cadence and the skipped version so the
  /// button always does something visible.
  Future<void> checkNow(String currentVersion) async {
    if (!isSupported) return;
    await _check(currentVersion, manual: true);
  }

  Future<void> _check(String currentVersion, {required bool manual}) async {
    if (_status == UpdateStatus.checking) return;

    _currentVersion = currentVersion;
    _status = UpdateStatus.checking;
    _error = null;
    notifyListeners();

    try {
      final response = await _client.get(
        Uri.parse(_latestReleaseApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          // GitHub rejects API requests without a User-Agent.
          'User-Agent': 'OpenView-desktop',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        // 403 here is almost always the rate limit. Nothing the user can act
        // on, so a background check stays quiet.
        throw HttpException(
            'GitHub returned ${response.statusCode}', uri: Uri.parse(_latestReleaseApi));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final info = parseRelease(json);

      // Always record the attempt, so a repo with no releases (or a malformed
      // tag) doesn't retry on every launch.
      await _settings.markUpdateChecked();

      if (info == null || !isNewer(info.version, currentVersion)) {
        _info = null;
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      if (!manual && _settings.skippedUpdateVersion == info.version) {
        _info = null;
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      _info = info;
      _dismissed = false;
      _status = UpdateStatus.available;
      notifyListeners();
    } catch (e) {
      // Offline, DNS failure, rate limit, malformed JSON — all the same to the
      // user, and none of it is worth interrupting a background check for.
      debugPrint('[OV] update check failed: $e');
      _error = _friendlyError(e);
      _status = UpdateStatus.failed;
      notifyListeners();
    }
  }

  /// Test-only: put the controller in the "update found" state without HTTP.
  @visibleForTesting
  void debugSetAvailable(UpdateInfo info, {String currentVersion = '3.2.0'}) {
    _info = info;
    _currentVersion = currentVersion;
    _dismissed = false;
    _status = UpdateStatus.available;
    notifyListeners();
  }

  /// Hide the banner for this session only; it returns on the next launch.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  /// Never mention this version again (until a newer one appears).
  Future<void> skipCurrentFinding() async {
    final v = _info?.version;
    if (v == null) return;
    // Clear the UI first and persist after — writing the settings file is
    // best-effort (same contract as SettingsController's own setters), and the
    // banner must not linger while it happens.
    _info = null;
    _status = UpdateStatus.upToDate;
    notifyListeners();
    await _settings.setSkippedUpdateVersion(v);
  }

  /// Open the platform asset (or the release page) in the browser.
  /// Returns false when the URL could not be launched.
  Future<bool> openDownload() async {
    final url = _info?.downloadUrl ?? releasesPageUrl;
    return _launch(url);
  }

  Future<bool> openReleasePage() async =>
      _launch(_info?.pageUrl ?? releasesPageUrl);

  Future<bool> openChecksums() async {
    final url = _info?.checksumsUrl;
    if (url == null) return false;
    return _launch(url);
  }

  Future<bool> _launch(String url) async {
    try {
      return await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[OV] could not open $url: $e');
      return false;
    }
  }

  static String _friendlyError(Object e) {
    if (e is SocketException) return 'No network connection.';
    if (e is HttpException) return e.message;
    return 'Could not reach GitHub.';
  }

  // ── Release parsing ───────────────────────────────────────────────────

  /// Turn a `/releases/latest` payload into an [UpdateInfo].
  ///
  /// Returns null for drafts, prereleases, or a tag we can't read as a
  /// version. Static and pure so it is directly testable.
  @visibleForTesting
  static UpdateInfo? parseRelease(Map<String, dynamic> json) {
    if (json['draft'] == true || json['prerelease'] == true) return null;

    final tag = (json['tag_name'] as String?)?.trim();
    if (tag == null || tag.isEmpty) return null;

    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (_parseVersion(version) == null) return null;

    final assets = (json['assets'] as List?) ?? const [];
    final wanted = assetNameForCurrentPlatform();

    Map<String, dynamic>? assetNamed(String? name) {
      if (name == null) return null;
      for (final a in assets) {
        if (a is Map<String, dynamic> && a['name'] == name) return a;
      }
      return null;
    }

    final asset = assetNamed(wanted);
    final checksums = assetNamed('SHA256SUMS.txt');

    return UpdateInfo(
      version: version,
      notes: (json['body'] as String?) ?? '',
      pageUrl: (json['html_url'] as String?) ?? releasesPageUrl,
      assetUrl: asset?['browser_download_url'] as String?,
      assetName: asset?['name'] as String?,
      assetBytes: (asset?['size'] as num?)?.toInt(),
      checksumsUrl: checksums?['browser_download_url'] as String?,
      publishedAt: DateTime.tryParse((json['published_at'] as String?) ?? ''),
    );
  }

  /// Release asset for the running OS/arch.
  ///
  /// These names are produced by the `Package` steps in
  /// `.github/workflows/release.yml` — **if a name changes there, change it
  /// here too**, or the dialog silently degrades to the release page.
  @visibleForTesting
  static String? assetNameForCurrentPlatform({String? overridePlatform, bool? arm64}) {
    final os = overridePlatform ?? Platform.operatingSystem;
    final isArm = arm64 ?? _isArm64;
    return switch (os) {
      'macos' => 'OpenView-macos-universal.zip', // universal binary
      'windows' => 'OpenView-windows-x64.zip',
      'linux' => isArm ? 'OpenView-linux-arm64.zip' : 'OpenView-linux-x64.zip',
      _ => null,
    };
  }

  /// Dart exposes no direct CPU-architecture API; `Platform.version` ends with
  /// the target ABI, e.g. `... on "linux_arm64"`.
  static bool get _isArm64 {
    final v = Platform.version.toLowerCase();
    return v.contains('arm64') || v.contains('aarch64');
  }

  // ── Version comparison ────────────────────────────────────────────────

  /// True when [candidate] is a strictly newer version than [current].
  ///
  /// Build metadata is ignored (`3.2.0+135` and `3.2.0` are the same release),
  /// and a prerelease sorts below its matching release, per semver. Anything
  /// unparseable is treated as "not newer" so a stray tag can never trigger a
  /// bogus prompt.
  @visibleForTesting
  static bool isNewer(String candidate, String current) =>
      compareVersions(candidate, current) > 0;

  /// Semver-ish comparison: negative if [a] < [b], 0 if equal, positive if
  /// [a] > [b]. Unparseable input compares as 0 (unknown → do nothing).
  @visibleForTesting
  static int compareVersions(String a, String b) {
    final va = _parseVersion(a);
    final vb = _parseVersion(b);
    if (va == null || vb == null) return 0;

    for (var i = 0; i < 3; i++) {
      final c = va.core[i].compareTo(vb.core[i]);
      if (c != 0) return c;
    }

    // Equal cores: 3.3.0 beats 3.3.0-rc1; two prereleases compare as strings.
    final pa = va.pre;
    final pb = vb.pre;
    if (pa == null && pb == null) return 0;
    if (pa == null) return 1;
    if (pb == null) return -1;
    return pa.compareTo(pb);
  }

  static _Version? _parseVersion(String raw) {
    // Drop a leading `v` and any `+build` metadata.
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    if (s.isEmpty) return null;

    String? pre;
    final dash = s.indexOf('-');
    if (dash >= 0) {
      pre = s.substring(dash + 1);
      s = s.substring(0, dash);
    }

    final parts = s.split('.');
    if (parts.isEmpty || parts.length > 3) return null;

    final core = <int>[0, 0, 0];
    for (var i = 0; i < parts.length; i++) {
      final n = int.tryParse(parts[i]);
      if (n == null || n < 0) return null;
      core[i] = n;
    }
    return _Version(core, pre);
  }
}

class _Version {
  final List<int> core; // always length 3
  final String? pre;
  const _Version(this.core, this.pre);
}
