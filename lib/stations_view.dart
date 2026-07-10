import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';
import 'store.dart';
import 'google_service.dart';

class _StationStat {
  final String name;
  int visits = 0;
  double sumPrice = 0;
  double totalSpent = 0;
  double minPrice = double.infinity;
  double maxPrice = 0;
  double lastPrice = 0;
  DateTime? lastDate;

  _StationStat(this.name);
  double get avgPrice => visits > 0 ? sumPrice / visits : 0;
}

class StationsView extends StatefulWidget {
  const StationsView({super.key});

  @override
  State<StationsView> createState() => _StationsViewState();
}

class _StationsViewState extends State<StationsView> {
  final _place = TextEditingController();
  List<GasStation>? _gas;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _place.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loc = await RouteService.instance.geocode(q);
      final stations = await RouteService.instance.gasNear(loc.lat, loc.lon);
      if (!mounted) return;
      setState(() {
        _gas = stations;
        _loading = false;
        _error = stations.isEmpty
            ? 'No stations reporting prices near there.'
            : null;
      });
    } on RouteException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong.';
        _loading = false;
      });
    }
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _error = 'Turn on location services to use this.';
          _loading = false;
        });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied — type a place instead.';
          _loading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final stations =
          await RouteService.instance.gasNear(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _gas = stations;
        _loading = false;
        _error =
            stations.isEmpty ? 'No stations reporting prices near you.' : null;
      });
    } on RouteException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not get your location.';
        _loading = false;
      });
    }
  }

  List<_StationStat> _aggregate(List<FillUp> fills) {
    final map = <String, _StationStat>{};
    for (final f in fills) {
      final name = f.station?.trim();
      if (name == null || name.isEmpty) continue;
      final s = map.putIfAbsent(name, () => _StationStat(name));
      s.visits++;
      s.sumPrice += f.pricePerGallon;
      s.totalSpent += f.cost;
      s.minPrice =
          f.pricePerGallon < s.minPrice ? f.pricePerGallon : s.minPrice;
      s.maxPrice =
          f.pricePerGallon > s.maxPrice ? f.pricePerGallon : s.maxPrice;
      if (s.lastDate == null || f.date.isAfter(s.lastDate!)) {
        s.lastDate = f.date;
        s.lastPrice = f.pricePerGallon;
      }
    }
    return map.values.toList()
      ..sort((a, b) => a.avgPrice.compareTo(b.avgPrice));
  }

  @override
  Widget build(BuildContext context) {
    final logged = _aggregate(Store.instance.fillups);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _gasCard(context),
        const SizedBox(height: 20),
        Text('Your stations',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (logged.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Add a station name when you log a fill-up and your stations get '
              'ranked here by the price you actually paid.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 13),
            ),
          )
        else ...[
          const SizedBox(height: 8),
          for (var i = 0; i < logged.length; i++)
            _loggedCard(context, logged[i],
                best: i == 0 && logged.length > 1),
        ],
      ],
    );
  }

  Widget _gasCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final connected = RouteService.instance.connected;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.local_gas_station, color: cs.primary),
              const SizedBox(width: 10),
              Text('Live gas prices',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 10),
            if (!connected)
              Text(
                'Add your Google Maps key in the ℹ️ menu to see current gas '
                'prices near any place.',
                style: TextStyle(color: cs.outline, fontSize: 13),
              )
            else ...[
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _place,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      labelText: 'City, ZIP, or area',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Find'),
                ),
              ]),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _useMyLocation,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Use my location'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
              ],
              if (_gas != null && _gas!.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < _gas!.length; i++)
                  _gasTile(context, _gas![i],
                      cheapest: i == 0 && _gas![i].regular != null),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _gasTile(BuildContext context, GasStation s, {bool cheapest = false}) {
    final cs = Theme.of(context).colorScheme;
    final others = s.prices.entries
        .where((e) => e.value != s.regular)
        .map((e) => '${_fuelLabel(e.key)} ${money(e.value)}')
        .take(3)
        .join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cheapest ? cs.primaryContainer : null,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(s.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  if (cheapest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Cheapest',
                          style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                if (s.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(s.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.outline, fontSize: 12)),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(others,
                      style: TextStyle(color: cs.outline, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(s.regular != null ? money(s.regular!) : '—',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(s.regular != null ? 'regular' : 'no price',
                  style: TextStyle(color: cs.outline, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  String _fuelLabel(String type) {
    switch (type) {
      case 'MIDGRADE':
        return 'Mid';
      case 'PREMIUM':
        return 'Prem';
      case 'DIESEL':
        return 'Diesel';
      default:
        return type
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceFirst('regular unleaded', 'Reg');
    }
  }

  Widget _loggedCard(BuildContext context, _StationStat s, {bool best = false}) {
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
                  Text(s.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
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
