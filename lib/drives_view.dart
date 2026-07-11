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
        ? ' · battery ${d.minBattery!.toStringAsFixed(0)}–${d.maxBattery!.toStringAsFixed(0)}%'
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
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
