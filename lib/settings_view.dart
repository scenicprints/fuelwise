import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'github_sync.dart';
import 'google_service.dart';
import 'update_checker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _UpdateState { idle, checking, upToDate, available, error }

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '…';
  _UpdateState _state = _UpdateState.idle;
  UpdateInfo? _info;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final v = await currentVersion();
    if (!mounted) return;
    setState(() => _version = v);
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _UpdateState.checking);
    try {
      final latest = await fetchLatestRelease();
      if (!mounted) return;
      if (latest == null) {
        setState(() => _state = _UpdateState.error);
        return;
      }
      final newer = compareVersions(latest.version, _version) > 0;
      setState(() {
        _info = latest;
        _state = newer ? _UpdateState.available : _UpdateState.upToDate;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _UpdateState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About & Updates')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.local_gas_station,
                  size: 44, color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('FuelWise',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text('Version $_version',
                style: TextStyle(color: cs.outline, fontSize: 15)),
          ),
          const SizedBox(height: 24),
          _updateCard(context),
          const SizedBox(height: 16),
          const _CloudSection(),
          const SizedBox(height: 16),
          const _GoogleSection(),
          const SizedBox(height: 24),
          Text('Your data is signed and updated from GitHub Releases.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _updateCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget content;
    switch (_state) {
      case _UpdateState.checking:
        content = const Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 14),
            Text('Checking for updates…'),
          ],
        );
        break;
      case _UpdateState.upToDate:
        content = Row(
          children: [
            Icon(Icons.check_circle, color: cs.primary),
            const SizedBox(width: 12),
            const Expanded(
                child: Text("You're on the latest version.",
                    style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        );
        break;
      case _UpdateState.error:
        content = Row(
          children: [
            Icon(Icons.cloud_off, color: cs.outline),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Could not reach GitHub. Check your connection.')),
          ],
        );
        break;
      case _UpdateState.available:
        final info = _info!;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Update available: ${info.tag}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
            if ((info.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(info.notes!.trim(),
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => launchDownload(info),
              icon: const Icon(Icons.download),
              label: const Text('Download & install'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            ),
            const SizedBox(height: 6),
            Text(
                'Downloads the new APK — tap it in your notifications to install '
                'over the top.',
                style: TextStyle(color: cs.outline, fontSize: 12)),
          ],
        );
        break;
      case _UpdateState.idle:
        content = const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      color: _state == _UpdateState.available ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            if (_state != _UpdateState.checking &&
                _state != _UpdateState.available) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _check,
                icon: const Icon(Icons.refresh),
                label: const Text('Check for updates'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour < 12 ? 'AM' : 'PM';
  return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
}

class _CloudSection extends StatefulWidget {
  const _CloudSection();

  @override
  State<_CloudSection> createState() => _CloudSectionState();
}

class _CloudSectionState extends State<_CloudSection> {
  final _token = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: SyncState.instance,
      builder: (context, _) {
        final sync = SyncState.instance;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.cloud_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Cloud backup',
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 12),
                if (!sync.connected)
                  ..._disconnected(context, sync)
                else
                  ..._connected(context, sync),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _disconnected(BuildContext context, SyncState sync) {
    final cs = Theme.of(context).colorScheme;
    return [
      Text(
        'Back up your log to your private $kDataRepo repo — versioned history '
        'and restore on any device.',
        style: TextStyle(color: cs.outline, fontSize: 13),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/settings/personal-access-tokens/new'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Create a token'),
        ),
      ),
      TextField(
        controller: _token,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Paste token',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      if (sync.message != null) ...[
        const SizedBox(height: 8),
        Text(sync.message!, style: TextStyle(color: cs.error, fontSize: 12)),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: sync.status == SyncStatus.busy
            ? null
            : () {
                final t = _token.text.trim();
                if (t.isNotEmpty) SyncState.instance.connect(t);
              },
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Connect & back up'),
      ),
    ];
  }

  List<Widget> _connected(BuildContext context, SyncState sync) {
    final cs = Theme.of(context).colorScheme;
    final busy = sync.status == SyncStatus.busy;
    return [
      Row(children: [
        Icon(Icons.check_circle, color: cs.primary, size: 20),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('Connected',
                style: TextStyle(fontWeight: FontWeight.w600))),
        if (busy)
          const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 6),
      Text(
        sync.message ??
            (sync.lastSync != null
                ? 'Last backup: ${_clock(sync.lastSync!)}'
                : 'Auto-backs up when you change data.'),
        style: TextStyle(
            color: sync.status == SyncStatus.error ? cs.error : cs.outline,
            fontSize: 12),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : () => SyncState.instance.push(),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Back up now'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : () => _confirmRestore(context),
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const Text('Restore'),
          ),
        ),
      ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => SyncState.instance.disconnect(),
          child: Text('Disconnect', style: TextStyle(color: cs.error)),
        ),
      ),
    ];
  }

  Future<void> _confirmRestore(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from cloud?'),
        content: const Text(
            'This replaces the data on this device with the latest cloud backup.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok == true) SyncState.instance.pull();
  }
}

class _GoogleSection extends StatefulWidget {
  const _GoogleSection();

  @override
  State<_GoogleSection> createState() => _GoogleSectionState();
}

class _GoogleSectionState extends State<_GoogleSection> {
  final _key = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: GoogleService.instance,
      builder: (context, _) {
        final g = GoogleService.instance;
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.map_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Google Maps',
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 12),
                if (!g.connected) ...[
                  Text(
                    'Adds real driving distances and route comparison on the '
                    'Trips tab (and live gas prices soon). Needs a Google Maps '
                    'Platform API key with the Directions API enabled.',
                    style: TextStyle(color: cs.outline, fontSize: 13),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                            'https://console.cloud.google.com/google/maps-apis/credentials'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Get a key'),
                    ),
                  ),
                  TextField(
                    controller: _key,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Paste API key',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final k = _key.text.trim();
                      if (k.isNotEmpty) GoogleService.instance.connect(k);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Save key'),
                  ),
                ] else ...[
                  Row(children: [
                    Icon(Icons.check_circle, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Key saved',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 6),
                  Text('Route lookup is enabled on the Trips tab.',
                      style: TextStyle(color: cs.outline, fontSize: 12)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => GoogleService.instance.disconnect(),
                      child:
                          Text('Remove key', style: TextStyle(color: cs.error)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
