import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

class _StationStat {
  final String name;
  int visits = 0;
  double sumPrice = 0;
  double totalSpent = 0;
  double totalGallons = 0;
  double minPrice = double.infinity;
  double maxPrice = 0;
  double lastPrice = 0;
  DateTime? lastDate;

  _StationStat(this.name);

  double get avgPrice => visits > 0 ? sumPrice / visits : 0;
}

class StationsView extends StatelessWidget {
  const StationsView({super.key});

  List<_StationStat> _aggregate(List<FillUp> fills) {
    final map = <String, _StationStat>{};
    for (final f in fills) {
      final name = f.station?.trim();
      if (name == null || name.isEmpty) continue;
      final s = map.putIfAbsent(name, () => _StationStat(name));
      s.visits++;
      s.sumPrice += f.pricePerGallon;
      s.totalSpent += f.cost;
      s.totalGallons += f.gallons;
      s.minPrice = f.pricePerGallon < s.minPrice ? f.pricePerGallon : s.minPrice;
      s.maxPrice = f.pricePerGallon > s.maxPrice ? f.pricePerGallon : s.maxPrice;
      if (s.lastDate == null || f.date.isAfter(s.lastDate!)) {
        s.lastDate = f.date;
        s.lastPrice = f.pricePerGallon;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => a.avgPrice.compareTo(b.avgPrice));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // Station prices are vehicle-independent, so rank across all fill-ups.
    final stations = _aggregate(Store.instance.fillups);

    if (stations.isEmpty) {
      return _empty(context);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Ranked by average price per gallon',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 13)),
        ),
        for (var i = 0; i < stations.length; i++)
          _stationCard(context, stations[i], best: i == 0 && stations.length > 1),
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
            const Text('🏷️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('No stations yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Add a station name when you log a fill-up and FuelWise will rank '
              'them here by price so you can spot your best-value stops.',
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

  Widget _stationCard(BuildContext context, _StationStat s, {bool best = false}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: best ? cs.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(s.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                      if (best) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Best value',
                              style: TextStyle(
                                  color: cs.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.visits} visit${s.visits == 1 ? '' : 's'} · '
                    'last ${money(s.lastPrice)} · ${money(s.totalSpent)} total',
                    style: TextStyle(color: cs.outline, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(s.avgPrice),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text('avg/gal',
                    style: TextStyle(color: cs.outline, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
