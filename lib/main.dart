import 'package:flutter/material.dart';

import 'store.dart';
import 'models.dart';
import 'log_view.dart';
import 'dashboard_view.dart';
import 'trips_view.dart';
import 'stations_view.dart';
import 'settings_view.dart';
import 'github_sync.dart';
import 'google_service.dart';
import 'update_checker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.instance.load();
  await SyncState.instance.init();
  await RouteService.instance.init();
  runApp(const FuelWiseApp());
}

class FuelWiseApp extends StatelessWidget {
  const FuelWiseApp({super.key});

  static const Color seed = Color(0xFF0F766E); // teal, matches the app icon

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FuelWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _checkedUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_checkedUpdate) {
        _checkedUpdate = true;
        autoCheck(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: const _VehicleSwitcher(),
            actions: [
              IconButton(
                tooltip: 'About & updates',
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            // Fresh (non-const) instances each build so the tabs rebuild when
            // the Store changes (e.g. deleting a saved trip) via ListenableBuilder.
            children: [
              DashboardView(),
              LogView(),
              TripsView(),
              StationsView(),
            ],
          ),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
                  onPressed: () => showFillUpSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Fill-up'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard'),
              NavigationDestination(
                  icon: Icon(Icons.local_gas_station_outlined),
                  selectedIcon: Icon(Icons.local_gas_station),
                  label: 'Log'),
              NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Trips'),
              NavigationDestination(
                  icon: Icon(Icons.sell_outlined),
                  selectedIcon: Icon(Icons.sell),
                  label: 'Stations'),
            ],
          ),
        );
      },
    );
  }
}

class _VehicleSwitcher extends StatelessWidget {
  const _VehicleSwitcher();

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == '__add__') {
          _addVehicleDialog(context);
        } else if (value == '__edit__') {
          _editVehicleDialog(context, store.currentVehicle);
        } else {
          store.selectVehicle(value);
        }
      },
      itemBuilder: (context) => [
        for (final v in store.vehicles)
          PopupMenuItem(
            value: v.id,
            child: Row(
              children: [
                Icon(
                  v.id == store.currentVehicleId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(v.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '__edit__',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Edit current vehicle…'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: '__add__',
          child: Row(
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 10),
              Text('Add vehicle…'),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              store.currentVehicle.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

Future<void> _addVehicleDialog(BuildContext context) async {
  final name = TextEditingController();
  final tank = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add vehicle'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. 2018 Civic',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: tank,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tank size (optional)',
                suffixText: 'gal',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Store.instance.addVehicle(
              name: name.text.trim(),
              tankGallons: double.tryParse(tank.text.trim()),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

Future<void> _editVehicleDialog(BuildContext context, Vehicle v) async {
  final name = TextEditingController(text: v.name);
  final tank = TextEditingController(
      text: v.tankGallons != null ? v.tankGallons.toString() : '');
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit vehicle'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (x) =>
                  (x == null || x.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: tank,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tank size (optional)',
                suffixText: 'gal',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete vehicle?'),
                content: Text('Removes "${v.name}" and its fill-ups.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(c).colorScheme.error),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              Store.instance.deleteVehicle(v.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          child: Text('Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            v.name = name.text.trim();
            v.tankGallons = double.tryParse(tank.text.trim());
            Store.instance.updateVehicle(v);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _Placeholder extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _Placeholder(this.emoji, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.outline)),
          ],
        ),
      ),
    );
  }
}
