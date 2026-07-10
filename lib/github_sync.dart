import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'store.dart';

/// Private repo that stores the user's data as a single JSON file.
const String kDataRepo = 'scenicprints/fuelwise-data';
const String kDataPath = 'data.json';

enum SyncStatus { idle, busy, ok, error }

/// Backs the app's data up to a private GitHub repo (versioned backup +
/// cross-device restore). The PAT lives in secure storage; the store is the
/// source of truth locally and pushes are debounced on change.
class SyncState extends ChangeNotifier {
  SyncState._();
  static final SyncState instance = SyncState._();

  static const _tokenKey = 'fuelwise.gh_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  bool get connected => _token != null && _token!.isNotEmpty;

  SyncStatus status = SyncStatus.idle;
  DateTime? lastSync;
  String? message;

  Timer? _debounce;
  bool _suppress = false;

  Future<void> init() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    Store.instance.addListener(_onStoreChanged);
    notifyListeners();
  }

  void _onStoreChanged() {
    if (!connected || _suppress) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => push(silent: true));
  }

  Future<void> connect(String token) async {
    _token = token.trim();
    await _storage.write(key: _tokenKey, value: _token);
    notifyListeners();
    await push();
  }

  Future<void> disconnect() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
    status = SyncStatus.idle;
    message = null;
    notifyListeners();
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Uri get _contentUri =>
      Uri.parse('https://api.github.com/repos/$kDataRepo/contents/$kDataPath');

  Future<String?> _remoteSha() async {
    final res = await http.get(_contentUri, headers: _headers);
    if (res.statusCode == 200) {
      return (json.decode(res.body) as Map<String, dynamic>)['sha'] as String?;
    }
    return null; // 404 => file not created yet
  }

  Future<bool> push({bool silent = false}) async {
    if (!connected) return false;
    status = SyncStatus.busy;
    message = null;
    if (!silent) notifyListeners();
    try {
      final sha = await _remoteSha();
      final content =
          base64.encode(utf8.encode(json.encode(Store.instance.toStateJson())));
      final res = await http.put(
        _contentUri,
        headers: _headers,
        body: json.encode({
          'message': 'FuelWise backup ${DateTime.now().toIso8601String()}',
          'content': content,
          if (sha != null) 'sha': sha,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        status = SyncStatus.ok;
        lastSync = DateTime.now();
        message = 'Backed up';
        notifyListeners();
        return true;
      }
      status = SyncStatus.error;
      message = _explain(res.statusCode);
      notifyListeners();
      return false;
    } catch (_) {
      status = SyncStatus.error;
      message = 'Network error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> pull() async {
    if (!connected) return false;
    status = SyncStatus.busy;
    message = null;
    notifyListeners();
    try {
      final res = await http.get(_contentUri, headers: _headers);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final b64 = (data['content'] as String).replaceAll('\n', '');
        final decoded = utf8.decode(base64.decode(b64));
        final state = json.decode(decoded) as Map<String, dynamic>;
        _suppress = true;
        Store.instance.loadFromJson(state);
        _suppress = false;
        status = SyncStatus.ok;
        lastSync = DateTime.now();
        message = 'Restored from cloud';
        notifyListeners();
        return true;
      }
      if (res.statusCode == 404) {
        status = SyncStatus.error;
        message = 'No cloud backup found yet';
        notifyListeners();
        return false;
      }
      status = SyncStatus.error;
      message = _explain(res.statusCode);
      notifyListeners();
      return false;
    } catch (_) {
      status = SyncStatus.error;
      message = 'Network error';
      notifyListeners();
      return false;
    }
  }

  String _explain(int code) {
    switch (code) {
      case 401:
        return 'Token rejected (401) — check it has Contents access.';
      case 403:
        return 'Forbidden (403) — token lacks permission on the repo.';
      case 404:
        return 'Repo/path not found (404) — is the token scoped to $kDataRepo?';
      default:
        return 'GitHub error ($code)';
    }
  }
}
