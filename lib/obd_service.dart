import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum ObdStatus { idle, scanning, connecting, connected, error }

/// Talks to an ELM327 OBD-II dongle over BLE (e.g. Vgate iCar Pro BLE 4.0).
/// BETA: connection/PID behaviour varies by dongle + car, so it keeps a live
/// diagnostics log to make tuning easy. No car data is read until connected.
class ObdService extends ChangeNotifier {
  ObdService._();
  static final ObdService instance = ObdService._();

  ObdStatus status = ObdStatus.idle;
  String? message;
  final List<ScanResult> found = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _write;
  BluetoothCharacteristic? _notify;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  // Live readings
  double? speedMph;
  int? rpm;
  double? fuelLevelPct;
  double? instantMpg;

  final List<String> log = [];
  final StringBuffer _buf = StringBuffer();
  Completer<String>? _pending;

  void _log(String s) {
    log.insert(0, s);
    if (log.length > 80) log.removeLast();
  }

  Future<void> scan() async {
    found.clear();
    status = ObdStatus.scanning;
    message = null;
    notifyListeners();
    try {
      if (!(await FlutterBluePlus.isSupported)) {
        _fail('Bluetooth not supported on this phone.');
        return;
      }
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        found
          ..clear()
          ..addAll(results.where((r) =>
              r.device.platformName.isNotEmpty ||
              r.advertisementData.advName.isNotEmpty));
        notifyListeners();
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
      if (status == ObdStatus.scanning) {
        status = ObdStatus.idle;
        notifyListeners();
      }
    } catch (e) {
      _fail('Scan failed: $e');
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    status = ObdStatus.connecting;
    message = null;
    _device = device;
    notifyListeners();
    try {
      await FlutterBluePlus.stopScan();
      await device.connect(timeout: const Duration(seconds: 15));
      final services = await device.discoverServices();
      for (final s in services) {
        for (final c in s.characteristics) {
          if (_write == null &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            _write = c;
          }
          if (_notify == null &&
              (c.properties.notify || c.properties.indicate)) {
            _notify = c;
          }
        }
      }
      if (_write == null || _notify == null) {
        _fail('No compatible OBD channel found on that device.');
        return;
      }
      await _notify!.setNotifyValue(true);
      _notifySub = _notify!.onValueReceived.listen(_onData);
      status = ObdStatus.connected;
      _log('Connected to ${device.platformName}');
      notifyListeners();
      await _init();
      _startPolling();
    } catch (e) {
      _fail('Connect failed: $e');
    }
  }

  void _onData(List<int> data) {
    _buf.write(String.fromCharCodes(data));
    if (_buf.toString().contains('>')) {
      final full = _buf.toString();
      _buf.clear();
      _log('< ${full.replaceAll(RegExp(r'[\r\n]'), ' ').trim()}');
      final p = _pending;
      _pending = null;
      p?.complete(full);
    }
  }

  Future<String> _send(String cmd,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final w = _write;
    if (w == null) return '';
    _pending = Completer<String>();
    _buf.clear();
    _log('> $cmd');
    await w.write('$cmd\r'.codeUnits,
        withoutResponse: w.properties.writeWithoutResponse);
    return _pending!.future.timeout(timeout, onTimeout: () {
      _pending = null;
      return '';
    });
  }

  Future<void> _init() async {
    await _send('ATZ', timeout: const Duration(seconds: 6));
    await Future.delayed(const Duration(milliseconds: 400));
    await _send('ATE0'); // echo off
    await _send('ATL0'); // linefeeds off
    await _send('ATH0'); // headers off
    await _send('ATSP0'); // auto-detect protocol

    // The first real query makes the adapter search for and LOCK the car's
    // protocol — that can take several seconds. Be patient and never fire
    // another command into it, or it reports "SEARCHING... STOPPED".
    _log('Establishing link to the car…');
    for (var attempt = 0; attempt < 4; attempt++) {
      final r = await _send('0100', timeout: const Duration(seconds: 12));
      if (_parse(r, '4100').isNotEmpty) {
        _log('Link established.');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
    _pollLoop();
  }

  // Strictly sequential polling — the next command only goes out after the
  // previous one has fully returned, so nothing interrupts the adapter.
  Future<void> _pollLoop() async {
    while (status == ObdStatus.connected) {
      await _pollOnce();
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _pollOnce() async {
    if (status != ObdStatus.connected) return;
    try {
      final sp = _parse(await _send('010D'), '410D');
      if (sp.isNotEmpty) speedMph = sp[0] * 0.621371;

      final rp = _parse(await _send('010C'), '410C');
      if (rp.length >= 2) rpm = ((rp[0] * 256) + rp[1]) ~/ 4;

      final fl = _parse(await _send('012F'), '412F');
      if (fl.isNotEmpty) fuelLevelPct = fl[0] * 100 / 255;

      final fr = _parse(await _send('015E'), '415E');
      if (fr.length >= 2) {
        final lph = ((fr[0] * 256) + fr[1]) / 20.0; // litres/hour
        final galph = lph / 3.785411784;
        final mph = speedMph ?? 0;
        if (mph == 0) {
          instantMpg = 0;
        } else if (galph > 0.05) {
          instantMpg = mph / galph;
        }
      }
      notifyListeners();
    } catch (_) {
      // transient read error — keep polling
    }
  }

  /// Returns the data bytes that follow [header] in an OBD hex response.
  List<int> _parse(String resp, String header) {
    final cleaned = resp.replaceAll(RegExp(r'[\s>]'), '').toUpperCase();
    final idx = cleaned.indexOf(header);
    if (idx < 0) return const [];
    final hex = cleaned.substring(idx + header.length);
    final bytes = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      final b = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (b == null) break;
      bytes.add(b);
    }
    return bytes;
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _scanSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _write = null;
    _notify = null;
    speedMph = null;
    rpm = null;
    fuelLevelPct = null;
    instantMpg = null;
    status = ObdStatus.idle;
    _log('Disconnected');
    notifyListeners();
  }

  void _fail(String msg) {
    status = ObdStatus.error;
    message = msg;
    _log('! $msg');
    notifyListeners();
  }
}
