import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The public code repo whose GitHub Releases we check for new APKs.
const String kRepo = 'scenicprints/fuelwise';

class UpdateInfo {
  final String version; // "0.2.0"
  final String tag; // "v0.2.0"
  final String? apkUrl;
  final String releaseUrl;
  final String? notes;

  UpdateInfo({
    required this.version,
    required this.tag,
    required this.apkUrl,
    required this.releaseUrl,
    this.notes,
  });
}

String _stripV(String s) {
  s = s.trim();
  return s.startsWith('v') ? s.substring(1) : s;
}

/// Returns >0 if [a] is newer than [b], 0 if equal, <0 if older.
int compareVersions(String a, String b) {
  List<int> parse(String s) {
    s = _stripV(s).split('+').first.split('-').first;
    final parts = s.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }

  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}

Future<String> currentVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}

Future<UpdateInfo?> fetchLatestRelease() async {
  final res = await http
      .get(
        Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      )
      .timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) return null;

  final data = json.decode(res.body) as Map<String, dynamic>;
  final tag = (data['tag_name'] as String?) ?? '';
  String? apkUrl;
  for (final a in (data['assets'] as List? ?? const [])) {
    final name = (a['name'] as String?) ?? '';
    if (name.toLowerCase().endsWith('.apk')) {
      apkUrl = a['browser_download_url'] as String?;
      break;
    }
  }
  return UpdateInfo(
    version: _stripV(tag),
    tag: tag,
    apkUrl: apkUrl,
    releaseUrl: (data['html_url'] as String?) ??
        'https://github.com/$kRepo/releases',
    notes: data['body'] as String?,
  );
}

/// Returns update info only when a newer release exists. Never throws.
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final current = await currentVersion();
    final latest = await fetchLatestRelease();
    if (latest == null) return null;
    return compareVersions(latest.version, current) > 0 ? latest : null;
  } catch (_) {
    return null;
  }
}

/// Silent launch check — only surfaces UI when an update is available.
Future<void> autoCheck(BuildContext context) async {
  final info = await checkForUpdate();
  if (info != null && context.mounted) {
    await showUpdateDialog(context, info);
  }
}

/// Manual check from the menu — gives feedback either way.
Future<void> manualCheck(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
      const SnackBar(content: Text('Checking for updates…')));
  final current = await currentVersion();
  final latest = await fetchLatestRelease();
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();

  if (latest == null) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Could not reach GitHub. Check your connection.')));
    return;
  }
  if (compareVersions(latest.version, current) > 0) {
    await showUpdateDialog(context, latest);
  } else {
    messenger.showSnackBar(
        SnackBar(content: Text("You're on the latest version (v$current).")));
  }
}

/// Opens the APK download (or release page) in the browser to install.
Future<void> launchDownload(UpdateInfo info) async {
  final url = info.apkUrl ?? info.releaseUrl;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FuelWise ${info.tag} is ready to install.'),
          if ((info.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(info.notes!.trim(),
                    style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () async {
            final url = info.apkUrl ?? info.releaseUrl;
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Download'),
        ),
      ],
    ),
  );
}
