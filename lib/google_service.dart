import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// A single route option returned by the Directions API.
class RouteOption {
  final String summary; // e.g. "I-15 N"
  final double miles;
  final double minutes;
  const RouteOption(
      {required this.summary, required this.miles, required this.minutes});
}

class GoogleException implements Exception {
  final String message;
  GoogleException(this.message);
  @override
  String toString() => message;
}

/// Holds the user's Google Maps Platform API key (secure storage) and wraps the
/// Directions API. Phase 2b will add Places (gas prices) using the same key.
class GoogleService extends ChangeNotifier {
  GoogleService._();
  static final GoogleService instance = GoogleService._();

  static const _keyId = 'fuelwise.google_key';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _key;
  bool get connected => _key != null && _key!.isNotEmpty;

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

  Future<List<RouteOption>> directions(
      String origin, String destination) async {
    if (!connected) throw GoogleException('No Google API key set.');
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': origin,
      'destination': destination,
      'alternatives': 'true',
      'key': _key!,
    });

    final http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw GoogleException('Network error reaching Google.');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK') {
      final msg = data['error_message'] as String?;
      throw GoogleException(_friendly(status, msg));
    }

    final routes = <RouteOption>[];
    for (final r in (data['routes'] as List? ?? const [])) {
      double meters = 0, seconds = 0;
      for (final leg in (r['legs'] as List? ?? const [])) {
        meters += ((leg['distance']?['value']) as num? ?? 0).toDouble();
        seconds += ((leg['duration']?['value']) as num? ?? 0).toDouble();
      }
      routes.add(RouteOption(
        summary: (r['summary'] as String?) ?? 'Route',
        miles: meters / 1609.344,
        minutes: seconds / 60.0,
      ));
    }
    if (routes.isEmpty) throw GoogleException('No routes found.');
    return routes;
  }

  String _friendly(String status, String? msg) {
    switch (status) {
      case 'REQUEST_DENIED':
        return 'Key rejected — enable the Directions API and check restrictions.'
            '${msg != null ? '\n$msg' : ''}';
      case 'ZERO_RESULTS':
        return 'No route between those places.';
      case 'NOT_FOUND':
        return "Couldn't find one of those locations.";
      case 'OVER_DAILY_LIMIT':
      case 'OVER_QUERY_LIMIT':
        return 'Google quota exceeded (check billing on the project).';
      case 'INVALID_REQUEST':
        return 'Enter both a start and destination.';
      default:
        return 'Google error: $status';
    }
  }
}
