import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

class TripsView extends StatefulWidget {
  const TripsView({super.key});

  @override
  State<TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<TripsView> {
  final _distance = TextEditingController();
  final _mpg = TextEditingController();
  final _price = TextEditingController();
  final _speed = TextEditingController(text: '60');
  final _tank = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillFromVehicle();
    for (final c in [_distance, _mpg, _price, _speed, _tank]) {
      c.addListener(() => setState(() {}));
    }
  }

  void _prefillFromVehicle() {
    final store = Store.instance;
    final v = store.currentVehicle;
    final s = store.statsFor(v.id);
    _mpg.text = (s.avgMpg ?? 44).toStringAsFixed(0);
    _price.text = (s.avgPricePerGallon ?? 3.50).toStringAsFixed(2);
    if (v.tankGallons != null) _tank.text = v.tankGallons!.toStringAsFixed(1);
  }

  @override
  void dispose() {
    for (final c in [_distance, _mpg, _price, _speed, _tank]) {
      c.dispose();
    }
    super.dispose();
  }

  double _p(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  Trip _currentTrip({String label = 'Trip'}) => Trip(
        id: Store.instance.newId(),
        label: label,
        distance: _p(_distance),
        mpg: _p(_mpg),
        pricePerGallon: _p(_price),
        speedMph: _p(_speed),
        tankGallons: _tank.text.trim().isEmpty ? null : _p(_tank),
        createdAt: DateTime.now(),
      );

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final hasDistance = _p(_distance) > 0;
    final trip = _currentTrip();
    final saved = store.savedTrips;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan a road trip',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Prefilled from your log — change anything.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 13)),
                const SizedBox(height: 14),
                _field(_distance, 'Trip distance', 'mi'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_mpg, 'Efficiency', 'mpg')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_price, 'Fuel price', '\$/gal')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_speed, 'Avg speed', 'mph')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_tank, 'Tank size', 'gal')),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (hasDistance) _resultCard(context, trip),
        if (hasDistance) const SizedBox(height: 8),
        if (hasDistance)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => _saveTrip(context),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save trip'),
            ),
          ),
        if (saved.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Saved trips',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final t in saved) _savedTile(context, t),
        ],
      ],
    );
  }

  Widget _field(TextEditingController c, String label, String suffix) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _resultCard(BuildContext context, Trip t) {
    final cs = Theme.of(context).colorScheme;
    Widget tile(String label, String value, String unit) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: cs.outline, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(value,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(unit,
                        style: TextStyle(color: cs.outline, fontSize: 12)),
                  ],
                ],
              ),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estimate',
                style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [
              tile('Fuel needed', num1(t.gallons), 'gal'),
              tile('Fuel cost', money(t.fuelCost), ''),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              tile('Drive time', duration(t.hours), ''),
              tile('Fuel stops', '${t.stops}',
                  t.tankGallons == null ? '(set tank)' : ''),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _savedTile(BuildContext context, Trip t) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(t.label),
        subtitle: Text(
            '${t.distance.toStringAsFixed(0)} mi · ${num1(t.gallons)} gal · '
            '${money(t.fuelCost)} · ${duration(t.hours)}',
            style: TextStyle(color: cs.outline, fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => Store.instance.deleteTrip(t.id),
        ),
        onTap: () => _loadTrip(t),
      ),
    );
  }

  void _loadTrip(Trip t) {
    _distance.text = t.distance.toStringAsFixed(0);
    _mpg.text = t.mpg.toStringAsFixed(0);
    _price.text = t.pricePerGallon.toStringAsFixed(2);
    _speed.text = t.speedMph.toStringAsFixed(0);
    _tank.text = t.tankGallons?.toStringAsFixed(1) ?? '';
    setState(() {});
  }

  Future<void> _saveTrip(BuildContext context) async {
    final label = TextEditingController(
        text: '${_distance.text.trim()} mi trip');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save trip'),
        content: TextField(
          controller: label,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, label.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      Store.instance.addTrip(_currentTrip(label: name));
    }
  }
}
