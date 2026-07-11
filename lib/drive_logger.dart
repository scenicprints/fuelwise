import 'package:flutter/foundation.dart';

import 'models.dart';
import 'store.dart';

/// Turns a stream of OBD samples into logged drives. A drive begins on first
/// movement and ends after ~3 minutes stationary (or on disconnect). Distance
/// is integrated from speed, fuel from the airflow sensor (≈0 in EV mode), and
/// each slice is bucketed city vs highway by speed.
class DriveLogger extends ChangeNotifier {
  DriveLogger._();
  static final DriveLogger instance = DriveLogger._();

  static const double _hwyThresholdMph = 45.0;
  static const double _gramsPerGallon = 2820.0; // gasoline, approx
  static const double _stoichAfr = 14.7;
  static const int _stopSeconds = 180;

  bool logging = false;
  DateTime? _start;
  DateTime? _lastSample;
  DateTime? _stoppedSince;

  double cityMiles = 0;
  double highwayMiles = 0;
  double cityGallons = 0;
  double highwayGallons = 0;
  double? _minBatt;
  double? _maxBatt;

  double get miles => cityMiles + highwayMiles;
  double get gallons => cityGallons + highwayGallons;
  double? get mpg => gallons > 0.01 ? miles / gallons : null;

  /// Fed once per OBD poll: speed (mph), airflow (g/s, nullable), battery (%).
  void onSample(double? speedMph, double? mafGps, double? batteryPct) {
    final now = DateTime.now();
    final v = speedMph ?? 0;

    if (!logging) {
      if (v > 1.0) {
        _begin(now);
      } else {
        return;
      }
    }

    final last = _lastSample ?? now;
    var dt = now.difference(last).inMilliseconds / 1000.0;
    if (dt <= 0 || dt > 10) dt = 1.0; // clamp odd gaps / first sample
    _lastSample = now;

    final distInc = v / 3600.0 * dt; // miles this slice
    var galInc = 0.0;
    if (mafGps != null && mafGps > 0) {
      galInc = (mafGps / _stoichAfr) * dt / _gramsPerGallon;
    }

    if (v >= _hwyThresholdMph) {
      highwayMiles += distInc;
      highwayGallons += galInc;
    } else {
      cityMiles += distInc;
      cityGallons += galInc;
    }

    if (batteryPct != null) {
      _minBatt = _minBatt == null || batteryPct < _minBatt! ? batteryPct : _minBatt;
      _maxBatt = _maxBatt == null || batteryPct > _maxBatt! ? batteryPct : _maxBatt;
    }

    if (v < 1.0) {
      _stoppedSince ??= now;
      if (now.difference(_stoppedSince!).inSeconds > _stopSeconds) {
        _end();
      }
    } else {
      _stoppedSince = null;
    }
    notifyListeners();
  }

  void _begin(DateTime now) {
    logging = true;
    _start = now;
    _lastSample = now;
    _stoppedSince = null;
    cityMiles = highwayMiles = cityGallons = highwayGallons = 0;
    _minBatt = _maxBatt = null;
    notifyListeners();
  }

  void _end() {
    final start = _start;
    if (start != null && miles > 0.2) {
      final store = Store.instance;
      store.addDrive(Drive(
        id: store.newId(),
        vehicleId: store.currentVehicleId!,
        start: start,
        end: DateTime.now(),
        cityMiles: cityMiles,
        highwayMiles: highwayMiles,
        cityGallons: cityGallons,
        highwayGallons: highwayGallons,
        minBattery: _minBatt,
        maxBattery: _maxBatt,
      ));
    }
    logging = false;
    _start = null;
    _lastSample = null;
    _stoppedSince = null;
    cityMiles = highwayMiles = cityGallons = highwayGallons = 0;
    _minBatt = _maxBatt = null;
    notifyListeners();
  }

  /// Save the in-progress drive (called when OBD disconnects mid-drive).
  void finalizeIfLogging() {
    if (logging) _end();
  }
}
