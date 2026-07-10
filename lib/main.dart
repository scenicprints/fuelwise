import 'package:flutter/material.dart';

void main() => runApp(const FuelWiseApp());

/// FuelWise — fuel efficiency tracker + trip planner.
/// Phase 1 milestone: a themed app shell that proves the CI -> APK pipeline.
/// Real features (log, dashboard, trips, stations) fill in the placeholder pages.
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

  static const List<_Destination> _destinations = [
    _Destination('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '📊'),
    _Destination('Log', Icons.local_gas_station_outlined,
        Icons.local_gas_station, '⛽'),
    _Destination('Trips', Icons.map_outlined, Icons.map, '🗺️'),
    _Destination('Stations', Icons.sell_outlined, Icons.sell, '🏷️'),
  ];

  @override
  Widget build(BuildContext context) {
    final dest = _destinations[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(dest.label),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dest.emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(dest.label,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Coming soon',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String emoji;
  const _Destination(this.label, this.icon, this.selectedIcon, this.emoji);
}
