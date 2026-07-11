import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// App state + local persistence. Phase 1 persists to SharedPreferences as a
/// single JSON blob; a later phase layers GitHub sync on top of this same store.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  static const _key = 'fuelwise.state.v1';

  final List<Vehicle> vehicles = [];
  final List<FillUp> fillups = [];
  final List<Trip> trips = [];
  final List<Drive> drives = [];
  String? currentVehicleId;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        _applyState(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt/older payload — fall through to seeding.
      }
    }
    _ensureInvariants();
    notifyListeners();
  }

  /// Full serializable snapshot — used for local save and cloud sync.
  Map<String, dynamic> toStateJson() => {
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
        'fillups': fillups.map((f) => f.toJson()).toList(),
        'trips': trips.map((t) => t.toJson()).toList(),
        'drives': drives.map((d) => d.toJson()).toList(),
        'currentVehicleId': currentVehicleId,
      };

  void _applyState(Map<String, dynamic> data) {
    vehicles
      ..clear()
      ..addAll((data['vehicles'] as List? ?? const [])
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>)));
    fillups
      ..clear()
      ..addAll((data['fillups'] as List? ?? const [])
          .map((e) => FillUp.fromJson(e as Map<String, dynamic>)));
    trips
      ..clear()
      ..addAll((data['trips'] as List? ?? const [])
          .map((e) => Trip.fromJson(e as Map<String, dynamic>)));
    drives
      ..clear()
      ..addAll((data['drives'] as List? ?? const [])
          .map((e) => Drive.fromJson(e as Map<String, dynamic>)));
    currentVehicleId = data['currentVehicleId'] as String?;
  }

  void _ensureInvariants() {
    if (vehicles.isEmpty) _seed();
    if (currentVehicleId == null ||
        !vehicles.any((v) => v.id == currentVehicleId)) {
      currentVehicleId = vehicles.first.id;
    }
  }

  /// Replace local state with a snapshot (e.g. restored from the cloud).
  void loadFromJson(Map<String, dynamic> data) {
    _applyState(data);
    _ensureInvariants();
    _save();
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
    await _prefs?.setString(_key, json.encode(toStateJson()));
  }

  // ---- vehicles ----

  Vehicle get currentVehicle => vehicles.firstWhere(
      (v) => v.id == currentVehicleId,
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

  /// The passed vehicle is the stored instance edited in place; just persist.
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

  // ---- trips ----

  List<Trip> get savedTrips =>
      trips.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void addTrip(Trip t) {
    trips.add(t);
    _save();
    notifyListeners();
  }

  void deleteTrip(String id) {
    trips.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }

  // ---- drives (auto-logged from OBD) ----

  List<Drive> drivesFor(String vehicleId) =>
      drives.where((d) => d.vehicleId == vehicleId).toList()
        ..sort((a, b) => b.start.compareTo(a.start));

  List<Drive> get currentDrives => drivesFor(currentVehicleId!);

  DriveStats driveStatsFor(String vehicleId) =>
      computeDriveStats(drives.where((d) => d.vehicleId == vehicleId).toList());

  void addDrive(Drive d) {
    drives.add(d);
    _save();
    notifyListeners();
  }

  void deleteDrive(String id) {
    drives.removeWhere((d) => d.id == id);
    _save();
    notifyListeners();
  }

  String newId() => _newId();

  static int _counter = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
}
