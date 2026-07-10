import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class RouteOption {
  final String summary;
  final double miles;
  final double minutes;
  const RouteOption(
      {required this.summary, required this.miles, required this.minutes});
}

class GasStation {
  final String name;
  final String address;
  final double lat;
  final double lon;
  final Map<String, double> prices; // fuel type -> price/gal
  const GasStation({
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    required this.prices,
  });

  double? get regular =>
      prices['REGULAR_UNLEADED'] ?? prices['REGULAR'] ?? prices['UNLEADED'];
}

class RouteException implements Exception {
  final String message;
  RouteException(this.message);
  @override
  String toString() => message;
}

/// Routing + places. Routing works with NO setup (OpenStreetMap fallback).
/// A Google Maps key unlocks Google routing, place autocomplete, and live
/// gas prices (Routes API + Places API New must be allowed on the key).
class RouteService extends ChangeNotifier {
  RouteService._();
  static final RouteService instance = RouteService._();

  static const _keyId = 'fuelwise.google_key';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _key;
  bool get connected => _key != null && _key!.isNotEmpty;

  static const _ua = 'FuelWise/1.0 (personal fuel tracker)';

  Future<void> init() async {
    try {
      _key = await _storage.read(key: _keyId);
    } catch (_) {
      _key = null;
    }
    notifyListeners();
  }

  Future<void> connect(String key) async {
    _key = key.trim();
    await _storage.write(key: _keyId, value: _key);
    notifyListeners();
  }

  Future<void> disconnect() async {
    _key = null;
    await _storage.delete(key: _keyId);
    notifyListeners();
  }

  // ---------- Routing ----------

  Future<List<RouteOption>> route(String origin, String destination) async {
    return connected ? _google(origin, destination) : _osm(origin, destination);
  }

  Future<List<RouteOption>> _google(String origin, String destination) async {
    final uri =
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');
    final http.Response res;
    try {
      res = await http
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': _key!,
                'X-Goog-FieldMask':
                    'routes.distanceMeters,routes.duration,routes.description',
              },
              body: json.encode({
                'origin': {'address': origin},
                'destination': {'address': destination},
                'travelMode': 'DRIVE',
                'computeAlternativeRoutes': true,
              }))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw RouteException('Network error reaching Google.');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = data['error'] as Map<String, dynamic>?;
      throw RouteException(_googleError(res.statusCode, err?['message'] as String?));
    }
    final routes = <RouteOption>[];
    for (final r in (data['routes'] as List? ?? const [])) {
      final meters = ((r['distanceMeters']) as num? ?? 0).toDouble();
      final seconds =
          double.tryParse(((r['duration'] as String?) ?? '0s').replaceAll('s', '')) ??
              0;
      routes.add(RouteOption(
        summary: (r['description'] as String?) ?? 'Route',
        miles: meters / 1609.344,
        minutes: seconds / 60.0,
      ));
    }
    if (routes.isEmpty) throw RouteException('No route found.');
    return routes;
  }

  String _googleError(int code, String? msg) {
    switch (code) {
      case 400:
        return "Couldn't read those places — try \"City, State\".";
      case 401:
      case 403:
        return 'Google key rejected. Check the Routes API is allowed on the key '
            'and billing is on.${msg != null ? '\n$msg' : ''}';
      case 429:
        return 'Google quota exceeded — check billing.';
      default:
        return 'Google error ($code)${msg != null ? ': $msg' : ''}';
    }
  }

  Future<List<RouteOption>> _osm(String origin, String destination) async {
    final o = await geocode(origin);
    final d = await geocode(destination);
    final coords = '${o.lon},${o.lat};${d.lon},${d.lat}';
    final uri = Uri.https(
        'router.project-osrm.org', '/route/v1/driving/$coords',
        {'overview': 'false', 'alternatives': 'true'});
    final http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw RouteException('Network error getting the route.');
    }
    if (res.statusCode != 200) {
      throw RouteException('Routing failed (${res.statusCode}).');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') {
      throw RouteException('No driving route found between those.');
    }
    final routes = <RouteOption>[];
    var i = 1;
    for (final r in (data['routes'] as List? ?? const [])) {
      routes.add(RouteOption(
        summary: 'Option $i',
        miles: ((r['distance']) as num? ?? 0).toDouble() / 1609.344,
        minutes: ((r['duration']) as num? ?? 0).toDouble() / 60.0,
      ));
      i++;
    }
    if (routes.isEmpty) throw RouteException('No route found.');
    return routes;
  }

  // ---------- Geocoding (keyless, OpenStreetMap) ----------

  Future<({double lat, double lon})> geocode(String q) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search',
        {'q': q, 'format': 'json', 'limit': '1', 'countrycodes': 'us'});
    final http.Response res;
    try {
      res = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw RouteException('Network error finding "$q".');
    }
    if (res.statusCode != 200) {
      throw RouteException('Location lookup failed (${res.statusCode}).');
    }
    final list = json.decode(res.body) as List;
    if (list.isEmpty) {
      throw RouteException('Couldn\'t find "$q" — add a city and state.');
    }
    final m = list.first as Map<String, dynamic>;
    return (
      lat: double.parse(m['lat'] as String),
      lon: double.parse(m['lon'] as String),
    );
  }

  // ---------- Google Places (needs key) ----------

  Future<List<String>> autocomplete(String input) async {
    if (!connected || input.trim().length < 3) return const [];
    try {
      final res = await http
          .post(Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': _key!,
              },
              body: json.encode({
                'input': input,
                'includedRegionCodes': ['us'],
              }))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final data = json.decode(res.body) as Map<String, dynamic>;
      final out = <String>[];
      for (final s in (data['suggestions'] as List? ?? const [])) {
        final t = (s['placePrediction']?['text']?['text']) as String?;
        if (t != null && t.isNotEmpty) out.add(t);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<GasStation>> gasNear(double lat, double lon) async {
    if (!connected) {
      throw RouteException('Add your Google Maps key in ℹ️ to see gas prices.');
    }
    final http.Response res;
    try {
      res = await http
          .post(Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
              headers: {
                'Content-Type': 'application/json',
                'X-Goog-Api-Key': _key!,
                'X-Goog-FieldMask':
                    'places.displayName,places.formattedAddress,places.location,places.fuelOptions',
              },
              body: json.encode({
                'includedTypes': ['gas_station'],
                'maxResultCount': 20,
                'locationRestriction': {
                  'circle': {
                    'center': {'latitude': lat, 'longitude': lon},
                    'radius': 8000.0,
                  }
                },
              }))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw RouteException('Network error getting gas prices.');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = (data['error']?['message']) as String?;
      throw RouteException('Gas lookup failed: ${err ?? res.statusCode}');
    }
    final stations = <GasStation>[];
    for (final p in (data['places'] as List? ?? const [])) {
      final prices = <String, double>{};
      for (final fp in (p['fuelOptions']?['fuelPrices'] as List? ?? const [])) {
        final type = fp['type'] as String?;
        final price = fp['price'] as Map<String, dynamic>?;
        if (type != null && price != null) {
          final units = double.tryParse('${price['units'] ?? 0}') ?? 0;
          final nanos = (price['nanos'] as num? ?? 0).toDouble();
          prices[type] = units + nanos / 1e9;
        }
      }
      if (prices.isEmpty) continue; // only stations that actually report prices
      stations.add(GasStation(
        name: (p['displayName']?['text']) as String? ?? 'Gas station',
        address: (p['formattedAddress']) as String? ?? '',
        lat: (p['location']?['latitude'] as num?)?.toDouble() ?? 0,
        lon: (p['location']?['longitude'] as num?)?.toDouble() ?? 0,
        prices: prices,
      ));
    }
    stations.sort((a, b) => (a.regular ?? 9999).compareTo(b.regular ?? 9999));
    return stations;
  }
}
