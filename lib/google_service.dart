import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single route option.
class RouteOption {
  final String summary;
  final double miles;
  final double minutes;
  const RouteOption(
      {required this.summary, required this.miles, required this.minutes});
}

class RouteException implements Exception {
  final String message;
  RouteException(this.message);
  @override
  String toString() => message;
}

/// Keyless routing using free OpenStreetMap community services:
/// Nominatim geocodes place names, OSRM computes the driving route.
/// No API key, no billing, no setup — plenty accurate for trip estimates.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  static const _ua = 'FuelWise/1.0 (personal fuel tracker)';

  Future<({double lat, double lon})> _geocode(String q) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'us',
    });
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
      throw RouteException('Couldn\'t find "$q" — try adding a city and state.');
    }
    final m = list.first as Map<String, dynamic>;
    return (
      lat: double.parse(m['lat'] as String),
      lon: double.parse(m['lon'] as String),
    );
  }

  Future<List<RouteOption>> route(String origin, String destination) async {
    final o = await _geocode(origin);
    final d = await _geocode(destination);
    final coords = '${o.lon},${o.lat};${d.lon},${d.lat}';
    final uri = Uri.https(
        'router.project-osrm.org', '/route/v1/driving/$coords', {
      'overview': 'false',
      'alternatives': 'true',
    });

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
      final meters = ((r['distance']) as num? ?? 0).toDouble();
      final seconds = ((r['duration']) as num? ?? 0).toDouble();
      routes.add(RouteOption(
        summary: 'Option $i',
        miles: meters / 1609.344,
        minutes: seconds / 60.0,
      ));
      i++;
    }
    if (routes.isEmpty) throw RouteException('No route found.');
    return routes;
  }
}
