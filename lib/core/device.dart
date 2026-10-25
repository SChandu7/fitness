import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:health/health.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'api.dart';

/// Keeps the screen on during a live session (Android + iOS).
class Wakelock {
  static Future<void> set(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {}
  }
}

/// Spoken distance and pace every kilometre (Settings → Voice updates).
class Voice {
  static final _tts = FlutterTts();
  static bool _ready = false;
  static Future<void> say(String text) async {
    try {
      if (!_ready) {
        await _tts.setLanguage('en-IN');
        await _tts.setSpeechRate(0.5);
        _ready = true;
      }
      await _tts.speak(text);
    } catch (_) {}
  }
}

/// System share sheet: WhatsApp, copy link, anything installed.
class Sharing {
  static Future<void> text(String text, {String? subject}) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } catch (_) {}
  }

  static Future<void> file(String name, String contents, {String? subject}) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsString(contents);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: subject));
  }
}

/// Apple Health (iOS) / Health Connect (Android): steps, heart rate, HRV, sleep, SpO₂.
/// Reads the last 8 days, one row per day, and posts it to /vitals/sync/.
class HealthSync {
  static final _health = Health();
  static bool _configured = false;

  static String get provider => Platform.isIOS ? 'appleHealth' : 'healthConnect';

  static List<HealthDataType> get _types => [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        Platform.isIOS ? HealthDataType.HEART_RATE_VARIABILITY_SDNN : HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        Platform.isIOS ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.RESPIRATORY_RATE,
      ];

  static Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Returns null on success, or a plain-English reason it did not work.
  static Future<String?> connect() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return 'Health data works on a phone only.';
    try {
      await _configure();
      if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
        await _health.installHealthConnect();
        return 'Install Health Connect from the Play Store, then tap Connect again.';
      }
      final ok = await _health.requestAuthorization(_types, permissions: _types.map((_) => HealthDataAccess.READ).toList());
      if (!ok) return 'Permission was not given. You can allow it in your phone settings.';
      await sync();
      return null;
    } catch (e) {
      return 'Could not connect to ${Platform.isIOS ? 'Apple Health' : 'Health Connect'}.';
    }
  }

  static Future<int> sync() async {
    await _configure();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    final points = _health.removeDuplicates(await _health.getHealthDataFromTypes(types: _types, startTime: start, endTime: now));
    final days = <String, Map<String, dynamic>>{};
    final hrv = <String, List<num>>{}, rhr = <String, List<num>>{}, spo2 = <String, List<num>>{}, resp = <String, List<num>>{};
    String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    for (final p in points) {
      final v = p.value is NumericHealthValue ? (p.value as NumericHealthValue).numericValue : null;
      final k = key(p.dateTo);
      final d = days.putIfAbsent(k, () => {'date': k});
      switch (p.type) {
        case HealthDataType.SLEEP_ASLEEP || HealthDataType.SLEEP_SESSION:
          d['sleep_min'] = (d['sleep_min'] ?? 0) + p.dateTo.difference(p.dateFrom).inMinutes;
        case HealthDataType.SLEEP_DEEP:
          d['deep_sleep_min'] = (d['deep_sleep_min'] ?? 0) + p.dateTo.difference(p.dateFrom).inMinutes;
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN || HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          if (v != null) hrv.putIfAbsent(k, () => []).add(v);
        case HealthDataType.RESTING_HEART_RATE:
          if (v != null) rhr.putIfAbsent(k, () => []).add(v);
        case HealthDataType.BLOOD_OXYGEN:
          if (v != null) spo2.putIfAbsent(k, () => []).add(v <= 1 ? v * 100 : v);
        case HealthDataType.RESPIRATORY_RATE:
          if (v != null) resp.putIfAbsent(k, () => []).add(v);
        default:
          break;
      }
    }
    int avg(List<num> l) => (l.reduce((a, b) => a + b) / l.length).round();
    for (var i = 0; i <= 7; i++) {
      final day = start.add(Duration(days: i));
      final k = key(day);
      final d = days.putIfAbsent(k, () => {'date': k});
      final end = i == 7 ? now : day.add(const Duration(days: 1));
      try {
        final steps = await _health.getTotalStepsInInterval(day, end);
        if (steps != null) d['steps'] = steps;
      } catch (_) {}
      if (hrv[k] != null) d['hrv_ms'] = avg(hrv[k]!);
      if (rhr[k] != null) d['resting_hr'] = avg(rhr[k]!);
      if (spo2[k] != null) {
        d['spo2'] = avg(spo2[k]!);
        d['spo2_low'] = spo2[k]!.reduce((a, b) => a < b ? a : b).round();
      }
      if (resp[k] != null) d['respiration'] = avg(resp[k]!);
    }
    final rows = days.values.where((d) => d.length > 1).toList();
    if (rows.isEmpty) return 0;
    await Api.i.post('vitals/sync/', {'provider': provider, 'days': rows});
    return rows.length;
  }

  /// Heart-rate samples recorded by a watch during a session (empty if none synced yet).
  static Future<List<int>> heartRate(DateTime from, DateTime to) async {
    try {
      await _configure();
      final pts = await _health.getHealthDataFromTypes(types: [HealthDataType.HEART_RATE], startTime: from, endTime: to);
      pts.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      return [
        for (final p in pts)
          if (p.value is NumericHealthValue) (p.value as NumericHealthValue).numericValue.round()
      ];
    } catch (_) {
      return const [];
    }
  }
}
