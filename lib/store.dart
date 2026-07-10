import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// App state + local persistence. Phase 1 persists to SharedPreferences as a
/// single JSON blob; Phase 7 will layer GitHub sync on top of this same store.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  static const _key = 'fuelwise.state.v1';

  final List<Vehicle> vehicles = [];
  final List<FillUp> fillups = [];
  String? currentVehicleId;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final data = json.decode(raw) as Map<String, dynamic>;
        vehicles
          ..clear()
          ..addAll((data['vehicles'] as List)
              .map((e) => Vehicle.fromJson(e as Map<String, dynamic>)));
        fillups
          ..clear()
          ..addAll((data['fillups'] as List)
              .map((e) => FillUp.fromJson(e as Map<String, dynamic>)));
        currentVehicleId = data['currentVehicleId'] as String?;
      } catch (_) {
        // Corrupt/older payload — fall through to seeding.
      }
    }
    if (vehicles.isEmpty) _seed();
    if (currentVehicleId == null ||
        !vehicles.any((v) => v.id == currentVehicleId)) {
      currentVehicleId = vehicles.first.id;
    }
    notifyListeners();
  }

  void _seed() {
    vehicles.add(Vehicle(
      id: _newId(),
      name: '2023 Accord Hybrid',
      year: 2023,
      make: 'Honda',
      tankGallons: 12.8,
    ));
  }

  Future<void> _save() async {
    await _prefs?.setString(
      _key,
      json.encode({
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
        'fillups': fillups.map((f) => f.toJson()).toList(),
        'currentVehicleId': currentVehicleId,
      }),
    );
  }

  // ---- vehicles ----

  Vehicle get currentVehicle =>
      vehicles.firstWhere((v) => v.id == currentVehicleId,
          orElse: () => vehicles.first);

  void selectVehicle(String id) {
    currentVehicleId = id;
    _save();
    notifyListeners();
  }

  Vehicle addVehicle({
    required String name,
    int? year,
    String? make,
    double? tankGallons,
  }) {
    final v = Vehicle(
        id: _newId(),
        name: name,
        year: year,
        make: make,
        tankGallons: tankGallons);
    vehicles.add(v);
    currentVehicleId = v.id;
    _save();
    notifyListeners();
    return v;
  }

  void updateVehicle(Vehicle v) {
    _save();
    notifyListeners();
  }

  void deleteVehicle(String id) {
    vehicles.removeWhere((v) => v.id == id);
    fillups.removeWhere((f) => f.vehicleId == id);
    if (vehicles.isEmpty) _seed();
    if (currentVehicleId == id) currentVehicleId = vehicles.first.id;
    _save();
    notifyListeners();
  }

  // ---- fill-ups ----

  List<FillUp> fillupsFor(String vehicleId) =>
      fillups.where((f) => f.vehicleId == vehicleId).toList()
        ..sort((a, b) {
          final c = b.date.compareTo(a.date); // newest first
          return c != 0 ? c : b.odometer.compareTo(a.odometer);
        });

  List<FillUp> get currentFillups => fillupsFor(currentVehicleId!);

  VehicleStats statsFor(String vehicleId) =>
      computeStats(fillups.where((f) => f.vehicleId == vehicleId).toList());

  void addFillUp(FillUp f) {
    fillups.add(f);
    _save();
    notifyListeners();
  }

  void updateFillUp(FillUp f) {
    final i = fillups.indexWhere((x) => x.id == f.id);
    if (i >= 0) fillups[i] = f;
    _save();
    notifyListeners();
  }

  void deleteFillUp(String id) {
    fillups.removeWhere((f) => f.id == id);
    _save();
    notifyListeners();
  }

  List<String> get knownStations {
    final s = <String>{};
    for (final f in fillups) {
      final name = f.station?.trim();
      if (name != null && name.isNotEmpty) s.add(name);
    }
    final list = s.toList()..sort();
    return list;
  }

  String newId() => _newId();

  static int _counter = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
}
