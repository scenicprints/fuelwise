import 'package:flutter/material.dart';

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
