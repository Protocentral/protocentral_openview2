// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/update_controller.dart';
import '../../theme/app_spacing.dart';

/// Slim "a newer OpenView is available" strip, shown above the page body in
/// [AdaptiveScaffold].
///
/// Collapses to nothing unless [UpdateController.hasBanner] — which is false
/// on store builds, when the user opted out, when the version was skipped, and
/// once dismissed for the session.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateController>();
    if (!update.hasBanner) return const SizedBox.shrink();

    final info = update.info!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final message = Text.rich(
      TextSpan(children: [
        TextSpan(
          text: 'OpenView ${info.version} is available',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onPrimaryContainer,
          ),
        ),
        if (update.currentVersion.isNotEmpty)
          TextSpan(
            text: '  ·  you have ${update.currentVersion}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
            ),
          ),
      ]),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );

    final actions = [
      TextButton(
        onPressed: () => showUpdateDetailsDialog(context),
        child: const Text("What's new"),
      ),
      FilledButton.icon(
        onPressed: () => _download(context, update),
        icon: const Icon(Icons.download, size: 18),
        label: const Text('Download'),
      ),
      IconButton(
        tooltip: 'Dismiss until next launch',
        icon: const Icon(Icons.close, size: 18),
        onPressed: update.dismiss,
      ),
    ];

    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.system_update_alt,
                size: 20, color: scheme.onPrimaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: message),
            if (narrow)
              // Keep the strip one line tall on small windows: the dialog
              // carries every action anyway.
              ...[
                IconButton(
                  tooltip: 'Update details',
                  icon: const Icon(Icons.download, size: 18),
                  onPressed: () => showUpdateDetailsDialog(context),
                ),
                IconButton(
                  tooltip: 'Dismiss until next launch',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: update.dismiss,
                ),
              ]
            else
              ...actions,
          ],
        ),
      ),
    );
  }
}

Future<void> _download(BuildContext context, UpdateController update) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await update.openDownload();
  if (!ok) {
    messenger.showSnackBar(SnackBar(
      content: Text('Could not open the browser — '
          '${UpdateController.releasesPageUrl}'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

/// Run an explicit "Check for updates" and report the outcome, the way a
/// desktop app's About box does: the update sheet when there is something, a
/// snackbar when there isn't.
///
/// Ignores the daily cadence and any skipped version — the user asked.
Future<void> runManualUpdateCheck(
    BuildContext context, String currentVersion) async {
  final update = context.read<UpdateController>();
  final messenger = ScaffoldMessenger.of(context);

  await update.checkNow(currentVersion);
  if (!context.mounted) return;

  switch (update.status) {
    case UpdateStatus.available:
      await showUpdateDetailsDialog(context);
    case UpdateStatus.upToDate:
      messenger.showSnackBar(SnackBar(
        content: Text(currentVersion.isEmpty
            ? 'OpenView is up to date.'
            : 'OpenView $currentVersion is the latest release.'),
        behavior: SnackBarBehavior.floating,
      ));
    case UpdateStatus.failed:
      messenger.showSnackBar(SnackBar(
        content: Text(update.error ?? 'Could not check for updates.'),
        behavior: SnackBarBehavior.floating,
      ));
    case UpdateStatus.idle:
    case UpdateStatus.checking:
      break; // another check is already in flight
  }
}

/// Release notes + download / skip actions.
Future<void> showUpdateDetailsDialog(BuildContext context) {
  final update = context.read<UpdateController>();
  final info = update.info;
  if (info == null) return Future.value();

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      final published = info.publishedAt;
      final size = info.assetSizeLabel;

      return AlertDialog(
        icon: const Icon(Icons.system_update_alt),
        title: Text('OpenView ${info.version}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (published != null)
                    DateFormat.yMMMMd().format(published.toLocal()),
                  if (info.assetName != null)
                    size == null ? info.assetName! : '${info.assetName!} · $size',
                ].join('  ·  '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: _ReleaseNotes(markdown: info.notes),
                ),
              ),
              if (info.checksumsUrl != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: update.openChecksums,
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('SHA-256 checksums'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await update.skipCurrentFinding();
            },
            child: const Text('Skip this version'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (!context.mounted) return;
              await _download(context, update);
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
          ),
        ],
      );
    },
  );
}

/// GitHub's generated notes, rendered as readable text.
///
/// The body is Markdown and OpenView has no Markdown renderer (and this does
/// not warrant a new dependency), so headings, bullets and emphasis are
/// flattened line by line. PR links collapse to `#123` — the auto-generated
/// notes are otherwise mostly URL.
class _ReleaseNotes extends StatelessWidget {
  final String markdown;
  const _ReleaseNotes({required this.markdown});

  static final _prLink =
      RegExp(r'https://github\.com/[\w.-]+/[\w.-]+/pull/(\d+)');
  static final _emphasis = RegExp(r'\*\*|__|`');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = markdown.trim().split('\n');

    if (markdown.trim().isEmpty) {
      return Text('No release notes were published.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant));
    }

    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.sm));
        continue;
      }

      var text = line.replaceAllMapped(_prLink, (m) => '#${m[1]}');

      if (text.startsWith('#')) {
        text = text.replaceFirst(RegExp(r'^#+\s*'), '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Text(text.replaceAll(_emphasis, ''),
              style: theme.textTheme.titleSmall),
        ));
        continue;
      }

      final bullet = RegExp(r'^\s*[-*+]\s+');
      if (bullet.hasMatch(text)) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: 2),
          child: Text('•  ${text.replaceFirst(bullet, '').replaceAll(_emphasis, '')}',
              style: theme.textTheme.bodySmall),
        ));
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text.replaceAll(_emphasis, ''),
            style: theme.textTheme.bodySmall),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}
