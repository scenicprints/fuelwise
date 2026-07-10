import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

class LogView extends StatelessWidget {
  const LogView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final fills = store.currentFillups;
    final stats = store.statsFor(store.currentVehicleId!);

    if (fills.isEmpty) {
      return _empty(context);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: fills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final f = fills[i];
        final computed = stats.perFill[f.id];
        return _FillCard(fill: f, computed: computed);
      },
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
            const Text('⛽', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('Your fuel log is empty',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Tap + and enter your odometer and gallons each time you fill up. '
              'FuelWise computes MPG and cost per mile for you.',
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
}

class _FillCard extends StatelessWidget {
  final FillUp fill;
  final FillComputed? computed;
  const _FillCard({required this.fill, required this.computed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mpg = computed?.mpg;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showFillUpSheet(context, existing: fill),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(mpg == null ? '—' : mpg.toStringAsFixed(0),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer)),
                    Text('mpg',
                        style: TextStyle(
                            fontSize: 11, color: cs.onPrimaryContainer)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(fmtDate(fill.date),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        if (fill.partial) ...[
                          const SizedBox(width: 6),
                          _tag(context, 'partial'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${num1(fill.gallons)} gal · ${money(fill.pricePerGallon)}/gal · '
                      '${fill.odometer.toStringAsFixed(0)} mi',
                      style: TextStyle(color: cs.outline, fontSize: 13),
                    ),
                    if ((fill.station ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(fill.station!.trim(),
                          style: TextStyle(color: cs.outline, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(money(fill.cost),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer)),
    );
  }
}

/// Opens the add/edit bottom sheet. Pass [existing] to edit.
Future<void> showFillUpSheet(BuildContext context, {FillUp? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FillForm(existing: existing),
  );
}

class _FillForm extends StatefulWidget {
  final FillUp? existing;
  const _FillForm({this.existing});

  @override
  State<_FillForm> createState() => _FillFormState();
}

class _FillFormState extends State<_FillForm> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _odo;
  late TextEditingController _gal;
  late TextEditingController _price;
  late TextEditingController _station;
  bool _partial = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _odo = TextEditingController(text: e != null ? _trim(e.odometer) : '');
    _gal = TextEditingController(text: e != null ? _trim(e.gallons) : '');
    _price =
        TextEditingController(text: e != null ? _trim(e.pricePerGallon) : '');
    _station = TextEditingController(text: e?.station ?? '');
    _partial = e?.partial ?? false;
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _odo.dispose();
    _gal.dispose();
    _price.dispose();
    _station.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', ''));

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final store = Store.instance;
    final e = widget.existing;
    final f = FillUp(
      id: e?.id ?? store.newId(),
      vehicleId: e?.vehicleId ?? store.currentVehicleId!,
      date: _date,
      odometer: _parse(_odo.text)!,
      gallons: _parse(_gal.text)!,
      pricePerGallon: _parse(_price.text)!,
      station: _station.text.trim().isEmpty ? null : _station.text.trim(),
      partial: _partial,
    );
    if (e == null) {
      store.addFillUp(f);
    } else {
      store.updateFillUp(f);
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    Store.instance.deleteFillUp(widget.existing!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final navInset = mq.viewPadding.bottom; // system nav / gesture bar
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, 16 + keyboard + (keyboard > 0 ? 0.0 : navInset)),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing ? 'Edit fill-up' : 'Add fill-up',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                  ),
                  child: Text(fmtDate(_date)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _numField(_odo, 'Odometer', 'mi', requirePos: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numField(_gal, 'Gallons', 'gal', requirePos: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _numField(_price, 'Price per gallon', '\$', requirePos: true),
              const SizedBox(height: 12),
              TextFormField(
                controller: _station,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Station (optional)',
                  hintText: 'e.g. Shell — Main St',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_gas_station, size: 20),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _partial,
                onChanged: (v) => setState(() => _partial = v),
                title: const Text('Partial fill'),
                subtitle: const Text("Didn't fill the tank — excluded from MPG"),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(editing ? 'Save changes' : 'Add fill-up'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              if (editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, String suffix,
      {bool requirePos = false}) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final n = _parse(v ?? '');
        if (n == null) return 'Enter a number';
        if (requirePos && n <= 0) return 'Must be > 0';
        return null;
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }
}
