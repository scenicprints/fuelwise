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

  /// Uses the current Routes API (routes.googleapis.com). The legacy Directions
  /// API is often not enable-able on new Google Cloud projects, so we use this.
  Future<List<RouteOption>> directions(
      String origin, String destination) async {
    if (!connected) throw GoogleException('No Google API key set.');
    final uri =
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes');

    final http.Response res;
    try {
      res = await http
          .post(
            uri,
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
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw GoogleException('Network error reaching Google.');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = data['error'] as Map<String, dynamic>?;
      throw GoogleException(
          _friendly(res.statusCode, err?['message'] as String?));
    }

    final routes = <RouteOption>[];
    for (final r in (data['routes'] as List? ?? const [])) {
      final meters = ((r['distanceMeters']) as num? ?? 0).toDouble();
      final durStr = (r['duration'] as String?) ?? '0s';
      final seconds = double.tryParse(durStr.replaceAll('s', '')) ?? 0;
      routes.add(RouteOption(
        summary: (r['description'] as String?) ?? 'Route',
        miles: meters / 1609.344,
        minutes: seconds / 60.0,
      ));
    }
    if (routes.isEmpty) throw GoogleException('No route found between those.');
    return routes;
  }

  String _friendly(int code, String? msg) {
    switch (code) {
      case 400:
        return "Couldn't read those places — try \"City, State\" for each.";
      case 401:
      case 403:
        return 'Key rejected. Enable the Routes API on your project and make '
            'sure billing is on.${msg != null ? '\n$msg' : ''}';
      case 429:
        return 'Google quota exceeded — check billing on the project.';
      default:
        return 'Google error ($code)${msg != null ? ': $msg' : ''}';
    }
  }
}
