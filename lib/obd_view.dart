import 'package:flutter/material.dart';

import 'obd_service.dart';

class ObdScreen extends StatelessWidget {
  const ObdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ObdService.instance,
      builder: (context, _) {
        final obd = ObdService.instance;
        return Scaffold(
          appBar: AppBar(title: const Text('Live data (OBD)')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _beta(context),
              const SizedBox(height: 12),
              if (obd.status == ObdStatus.connected)
                ..._connected(context, obd)
              else
                ..._disconnected(context, obd),
              const SizedBox(height: 16),
              _logCard(context, obd),
            ],
          ),
        );
      },
    );
  }

  Widget _beta(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.science_outlined, color: cs.onSecondaryContainer, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Beta: plug the dongle into your car (ignition on), then Scan. If it '
            'misbehaves, screenshot the diagnostics below and send it over.',
            style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12.5),
          ),
        ),
      ]),
    );
  }

  List<Widget> _disconnected(BuildContext context, ObdService obd) {
    final cs = Theme.of(context).colorScheme;
    final scanning = obd.status == ObdStatus.scanning;
    return [
      if (obd.message != null) ...[
        Text(obd.message!, style: TextStyle(color: cs.error)),
        const SizedBox(height: 8),
      ],
      FilledButton.icon(
        onPressed: scanning ? null : () => obd.scan(),
        icon: scanning
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.bluetooth_searching),
        label: Text(scanning ? 'Scanning…' : 'Scan for dongle'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      const SizedBox(height: 12),
      if (obd.found.isEmpty && !scanning)
        Text('No devices yet — tap Scan with the dongle powered.',
            style: TextStyle(color: cs.outline, fontSize: 13))
      else
        for (final r in obd.found)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : r.advertisementData.advName),
              subtitle: Text(r.device.remoteId.str,
                  style: const TextStyle(fontSize: 11)),
              trailing: FilledButton(
                onPressed: () => obd.connect(r.device),
                child: const Text('Connect'),
              ),
            ),
          ),
    ];
  }

  List<Widget> _connected(BuildContext context, ObdService obd) {
    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          _tile(context, 'Speed',
              obd.speedMph == null ? '–' : obd.speedMph!.toStringAsFixed(0),
              'mph'),
          _tile(context, 'Instant MPG',
              obd.instantMpg == null ? '–' : obd.instantMpg!.toStringAsFixed(1),
              'mpg'),
          _tile(context, 'RPM', obd.rpm?.toString() ?? '–', ''),
          _tile(
              context,
              'Fuel level',
              obd.fuelLevelPct == null
                  ? '–'
                  : obd.fuelLevelPct!.toStringAsFixed(0),
              '%'),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => obd.disconnect(),
        icon: const Icon(Icons.bluetooth_disabled),
        label: const Text('Disconnect'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      ),
    ];
  }

  Widget _tile(BuildContext context, String label, String value, String unit) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: cs.outline, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: TextStyle(color: cs.outline, fontSize: 13)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _logCard(BuildContext context, ObdService obd) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.terminal),
        title: const Text('Diagnostics'),
        subtitle: Text('${obd.log.length} lines',
            style: TextStyle(color: cs.outline, fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (obd.log.isEmpty)
            Text('Nothing yet.', style: TextStyle(color: cs.outline))
          else
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  obd.log.join('\n'),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
