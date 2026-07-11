import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

class DrivesView extends StatelessWidget {
  const DrivesView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final drives = store.currentDrives;
    final stats = store.driveStatsFor(store.currentVehicleId!);

    if (drives.isEmpty) return _empty(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _cityHighwayCard(context, stats),
        const SizedBox(height: 12),
        if (stats.mpgSeries.length >= 2) ...[
          _trendCard(context, stats),
          const SizedBox(height: 12),
        ],
        ..._frequentSection(context, drives),
        Text('Recent drives',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final d in drives) _driveCard(context, d),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📈', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('No drives logged yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Connect the OBD dongle (🔵 top bar) and drive. FuelWise logs each '
              'drive and works out your real city vs highway MPG.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityHighwayCard(BuildContext context, DriveStats s) {
    final cs = Theme.of(context).colorScheme;
    Widget big(String label, double? mpg, IconData icon) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: cs.outline, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(mpg == null ? '–' : mpg.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text('mpg',
                      style: TextStyle(color: cs.outline, fontSize: 13)),
                ],
              ),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your real MPG',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              big('City', s.cityMpg, Icons.location_city),
              big('Highway', s.highwayMpg, Icons.speed),
            ]),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Overall ${mpg1(s.overallMpg)} mpg',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    '${s.cityMiles.toStringAsFixed(0)} city / '
                    '${s.highwayMiles.toStringAsFixed(0)} hwy mi',
                    style: TextStyle(color: cs.outline, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(BuildContext context, DriveStats s) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MPG trend',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _SparkPainter(
                    data: s.mpgSeries, line: cs.primary, axis: cs.outlineVariant),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 4),
            Text('mpg per drive (oldest → newest)',
                style: TextStyle(color: cs.outline, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _driveCard(BuildContext context, Drive d) {
    final cs = Theme.of(context).colorScheme;
    final mpgText = d.mpg == null
        ? 'mostly electric ⚡'
        : '${d.mpg!.toStringAsFixed(1)} mpg';
    final batt = (d.minBattery != null && d.maxBattery != null)
        ? ' · charge ${d.minBattery!.toStringAsFixed(0)}–${d.maxBattery!.toStringAsFixed(0)}%'
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showDriveDetail(context, d),
        title: Text('${fmtDate(d.start)} · ${d.miles.toStringAsFixed(1)} mi'),
        subtitle: Text(
          '${d.cityMiles.toStringAsFixed(0)} city / ${d.highwayMiles.toStringAsFixed(0)} hwy · '
          '$mpgText$batt',
          style: TextStyle(color: cs.outline, fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => Store.instance.deleteDrive(d.id),
        ),
      ),
    );
  }

  // Groups drives by destination (rounded end coordinate) to surface routes
  // the user repeats — the foundation of "best route" learning.
  List<Widget> _frequentSection(BuildContext context, List<Drive> drives) {
    final groups = <String, List<Drive>>{};
    for (final d in drives) {
      if (d.endLat == null || d.endLon == null) continue;
      final key = '${(d.endLat! * 1000).round()}_${(d.endLon! * 1000).round()}';
      groups.putIfAbsent(key, () => []).add(d);
    }
    final regular = groups.values.where((g) => g.length >= 2).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (regular.isEmpty) return const [];

    final cs = Theme.of(context).colorScheme;
    return [
      Text('Your regular drives',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
          'Same destination, driven repeatedly — route suggestions sharpen as '
          'you log more.',
          style: TextStyle(color: cs.outline, fontSize: 12)),
      const SizedBox(height: 8),
      for (final g in regular) _regularCard(context, g),
      const SizedBox(height: 12),
    ];
  }

  Widget _regularCard(BuildContext context, List<Drive> g) {
    final cs = Theme.of(context).colorScheme;
    double mi = 0, gal = 0;
    for (final d in g) {
      mi += d.miles;
      gal += d.gallons;
    }
    final avgMi = mi / g.length;
    final mpg = gal > 0.01 ? mi / gal : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.repeat),
        title:
            Text('Driven ${g.length}× · ~${avgMi.toStringAsFixed(0)} mi each'),
        subtitle: Text(
            mpg == null ? 'mostly electric ⚡' : 'avg ${mpg.toStringAsFixed(1)} mpg',
            style: TextStyle(color: cs.outline, fontSize: 13)),
      ),
    );
  }
}

String _timeOfDay(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour < 12 ? 'AM' : 'PM';
  return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
}

void _showDriveDetail(BuildContext context, Drive d) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      Widget row(String k, String v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(k, style: TextStyle(color: cs.outline)),
                Flexible(
                  child: Text(v,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
      String seg(double mi, double? mpg) =>
          '${mi.toStringAsFixed(1)} mi · ${mpg == null ? 'electric ⚡' : '${mpg.toStringAsFixed(1)} mpg'}';
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${fmtDate(d.start)} · ${_timeOfDay(d.start)}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            row('Distance', '${d.miles.toStringAsFixed(1)} mi'),
            row('Duration', duration(d.minutes / 60.0)),
            row('Avg speed', '${d.avgMph.toStringAsFixed(0)} mph'),
            const Divider(height: 24),
            row('City', seg(d.cityMiles, d.cityMpg)),
            row('Highway', seg(d.highwayMiles, d.highwayMpg)),
            row('Overall',
                d.mpg == null ? 'mostly electric ⚡' : '${d.mpg!.toStringAsFixed(1)} mpg'),
            const Divider(height: 24),
            row('Fuel used', '${d.gallons.toStringAsFixed(2)} gal'),
            if (d.route.isNotEmpty)
              row('Route', '${d.route.length} GPS points'),
            if (d.minBattery != null && d.maxBattery != null)
              row('Battery charge',
                  '${d.minBattery!.toStringAsFixed(0)}–${d.maxBattery!.toStringAsFixed(0)}%'),
          ],
        ),
      );
    },
  );
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color line;
  final Color axis;
  _SparkPainter({required this.data, required this.line, required this.axis});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    var minV = data.reduce(math.min);
    var maxV = data.reduce(math.max);
    if (maxV - minV < 1) {
      maxV += 1;
      minV -= 1;
    }
    final range = maxV - minV;

    canvas.drawLine(Offset(pad, size.height - pad),
        Offset(size.width - pad, size.height - pad), Paint()..color = axis);

    Offset at(int i) => Offset(
          pad + w * (i / (data.length - 1)),
          pad + h * (1 - (data[i] - minV) / range),
        );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < data.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (var i = 0; i < data.length; i++) {
      canvas.drawCircle(at(i), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.data != data;
}
