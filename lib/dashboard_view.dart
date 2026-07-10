import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _statSeed = DateTime.now().millisecondsSinceEpoch;

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final vehicle = store.currentVehicle;
    final fills = store.currentFillups;
    final stats = store.statsFor(vehicle.id);

    if (fills.isEmpty) {
      return _empty(context);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _statGrid(context, stats),
        const SizedBox(height: 12),
        _trendCard(context, stats),
        const SizedBox(height: 12),
        _randomStatCard(context, vehicle, fills, stats),
        const SizedBox(height: 12),
        _quickNumbers(context, stats),
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
            const Text('📊', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('No data yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Add a few fill-ups on the Log tab and your efficiency, trends, '
              'and stats show up here.',
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

  Widget _statGrid(BuildContext context, VehicleStats s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _statTile(context, 'Avg efficiency', mpg1(s.avgMpg), 'mpg'),
        _statTile(context, 'Cost / mile',
            s.costPerMile == null ? '–' : money(s.costPerMile!), ''),
        _statTile(context, 'Last fill', mpg1(s.lastMpg), 'mpg'),
        _statTile(context, 'Total spent', money(s.totalSpent), ''),
      ],
    );
  }

  Widget _statTile(BuildContext context, String label, String value,
      String unit) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(color: cs.outline, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit,
                      style: TextStyle(color: cs.outline, fontSize: 13)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(BuildContext context, VehicleStats s) {
    final cs = Theme.of(context).colorScheme;
    final series = s.mpgSeries;

    Widget body;
    if (series.length < 2) {
      body = SizedBox(
        height: 120,
        child: Center(
          child: Text('Log a couple more fill-ups to see your trend.',
              style: TextStyle(color: cs.outline)),
        ),
      );
    } else {
      body = SizedBox(
        height: 160,
        child: CustomPaint(
          painter: _MpgChartPainter(
            data: series,
            line: cs.primary,
            fill: cs.primary.withValues(alpha: 0.15),
            dot: cs.primary,
            axis: cs.outlineVariant,
            label: cs.outline,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    String trend = '—';
    if (series.length >= 2) {
      final delta = series.last - series.first;
      final pct = series.first == 0 ? 0 : (delta / series.first) * 100;
      trend = '${delta >= 0 ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}%';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Efficiency trend',
                    style: Theme.of(context).textTheme.titleMedium),
                if (series.length >= 2)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(trend,
                        style: TextStyle(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            body,
            const SizedBox(height: 4),
            Text('mpg per fill-up',
                style: TextStyle(color: cs.outline, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _randomStatCard(BuildContext context, Vehicle vehicle,
      List<FillUp> fills, VehicleStats s) {
    final cs = Theme.of(context).colorScheme;
    final facts = _funFacts(vehicle, fills, s);
    final fact = facts.isEmpty
        ? 'Keep logging — fun stats appear as your history grows.'
        : facts[math.Random(_statSeed).nextInt(facts.length)];

    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(fact,
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 15,
                      height: 1.3)),
            ),
            IconButton(
              tooltip: 'Another stat',
              onPressed: () => setState(
                  () => _statSeed = DateTime.now().microsecondsSinceEpoch),
              icon: Icon(Icons.casino_outlined, color: cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _funFacts(Vehicle v, List<FillUp> fills, VehicleStats s) {
    final facts = <String>[];
    final tank = v.tankGallons;

    if (s.totalGallonsAll > 0) {
      facts.add(
          "You've pumped ${s.totalGallonsAll.toStringAsFixed(0)} gallons into ${v.name}.");
      if (tank != null && tank > 0) {
        facts.add(
            'That fuel is about ${(s.totalGallonsAll / tank).toStringAsFixed(0)} full tanks.');
      }
    }
    if (s.totalMiles > 0) {
      facts.add(
          'Total distance logged: ${s.totalMiles.toStringAsFixed(0)} miles.');
      final aroundEarth = s.totalMiles / 24901.0 * 100;
      if (aroundEarth >= 1) {
        facts.add(
            "That's ${aroundEarth.toStringAsFixed(1)}% of the way around the Earth. 🌍");
      }
    }
    if (s.avgMpg != null && tank != null && tank > 0) {
      facts.add(
          'At ${mpg1(s.avgMpg)} mpg, a full tank takes you ~${(s.avgMpg! * tank).toStringAsFixed(0)} miles.');
    }
    if (s.costPerMile != null) {
      facts.add(
          'A 100-mile trip costs you about ${money(s.costPerMile! * 100)} in fuel.');
    }
    if (s.avgPricePerGallon != null) {
      facts.add(
          "You've averaged ${money(s.avgPricePerGallon!)} per gallon so far.");
    }
    if (s.mpgSeries.isNotEmpty) {
      final best = s.mpgSeries.reduce(math.max);
      final worst = s.mpgSeries.reduce(math.min);
      facts.add('Your best tank hit ${best.toStringAsFixed(1)} mpg. 🏆');
      if (s.mpgSeries.length > 1) {
        facts.add('Thirstiest tank: ${worst.toStringAsFixed(1)} mpg.');
      }
    }
    if (fills.length >= 2) {
      final prices = fills.map((f) => f.pricePerGallon).toList();
      facts.add(
          'Cheapest gas you found: ${money(prices.reduce(math.min))}/gal. Priciest: ${money(prices.reduce(math.max))}/gal.');
    }
    // spend per month
    if (fills.length >= 2 && s.totalSpent > 0) {
      final dates = fills.map((f) => f.date).toList()..sort();
      final days = dates.last.difference(dates.first).inDays;
      if (days >= 20) {
        final perMonth = s.totalSpent / (days / 30.0);
        facts.add('You spend about ${money(perMonth)} a month on fuel.');
      }
    }
    return facts;
  }

  Widget _quickNumbers(BuildContext context, VehicleStats s) {
    final cs = Theme.of(context).colorScheme;
    Widget row(String k, String val) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: TextStyle(color: cs.outline)),
              Text(val, style: const TextStyle(fontWeight: FontWeight.w600)),
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
            Text('Quick numbers',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            row('Total distance', '${s.totalMiles.toStringAsFixed(0)} mi'),
            row('Total fuel',
                '${s.totalGallonsAll.toStringAsFixed(1)} gal'),
            row('Avg price / gal',
                s.avgPricePerGallon == null ? '–' : money(s.avgPricePerGallon!)),
            row('Fill-ups logged', '${s.count}'),
          ],
        ),
      ),
    );
  }
}

class _MpgChartPainter extends CustomPainter {
  final List<double> data;
  final Color line;
  final Color fill;
  final Color dot;
  final Color axis;
  final Color label;

  _MpgChartPainter({
    required this.data,
    required this.line,
    required this.fill,
    required this.dot,
    required this.axis,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const leftPad = 34.0;
    const rightPad = 8.0;
    const topPad = 10.0;
    const bottomPad = 18.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    double minV = data.reduce(math.min);
    double maxV = data.reduce(math.max);
    if (maxV - minV < 1) {
      maxV += 1;
      minV -= 1;
    }
    final range = maxV - minV;

    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1;

    // horizontal guide lines + y labels (min, mid, max)
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var g = 0; g <= 2; g++) {
      final v = minV + range * (g / 2);
      final y = topPad + chartH * (1 - (v - minV) / range);
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width - rightPad, y), axisPaint);
      tp.text = TextSpan(
          text: v.toStringAsFixed(0),
          style: TextStyle(color: label, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }

    Offset pointAt(int i) {
      final x = leftPad + chartW * (i / (data.length - 1));
      final y = topPad + chartH * (1 - (data[i] - minV) / range);
      return Offset(x, y);
    }

    // fill under line
    final fillPath = Path()..moveTo(leftPad, topPad + chartH);
    for (var i = 0; i < data.length; i++) {
      final p = pointAt(i);
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(leftPad + chartW, topPad + chartH);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = fill);

    // line
    final linePath = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < data.length; i++) {
      final p = pointAt(i);
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    // dots
    final dotPaint = Paint()..color = dot;
    for (var i = 0; i < data.length; i++) {
      canvas.drawCircle(pointAt(i), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MpgChartPainter old) =>
      old.data != data || old.line != line;
}
