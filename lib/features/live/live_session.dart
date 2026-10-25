import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/device.dart';
import '../../core/format.dart';

/// One exercise in a live sets session.
class LiveEx {
  String name;
  int sets, reps, done;
  double kg;
  LiveEx(this.name, this.sets, this.reps, this.kg, [this.done = 0]);
  Map<String, dynamic> toJson() => {'n': name, 's': sets, 'r': reps, 'kg': kg, 'd': done};
  static LiveEx fromJson(Map m) => LiveEx('${m['n']}', m['s'] as int, m['r'] as int, (m['kg'] as num).toDouble(), m['d'] as int);
}

/// A running session. Survives leaving the screen and app restarts (saved to device storage).
class LiveSession extends ChangeNotifier {
  static const _kStore = 'exerlio.live';
  static final active = ValueNotifier<LiveSession?>(null);

  final String sport, mode, title, planKey;
  final int? weekday;
  final bool exhaust;
  final List<LiveEx> exercises;
  final List<List<String>> hyrox; // [label, distance]
  final Map<String, String> advice;
  final bool voice, autoPause, demoGps, shareLive;

  DateTime startedAt;
  int pausedMs = 0;
  DateTime? pausedAt;
  bool autoPaused = false;
  final List<Map<String, dynamic>> logged = [];
  int ex = 0, set = 0;
  DateTime? restUntil;
  final List<List<double>> points = [];
  double distanceM = 0;
  final List<Map<String, dynamic>> kmSplits = [];
  int _lastKmSec = 0;
  int seg = 0, segStart = 0;
  final List<Map<String, dynamic>> segSplits = [];
  int count = 0;
  String coach = 'Warm up for the first few minutes. Easy breathing, you should be able to talk.';
  String gpsNote = '';

  Timer? _tick;
  StreamSubscription<Position>? _gps;
  DateTime _lastMove = DateTime.now();
  double _demoHeading = math.Random().nextDouble() * math.pi * 2;

  LiveSession({
    required this.sport,
    required this.mode,
    required this.title,
    this.planKey = '',
    this.weekday,
    this.exhaust = false,
    List<LiveEx>? exercises,
    this.hyrox = const [],
    this.advice = const {},
    this.voice = true,
    this.autoPause = true,
    this.demoGps = false,
    this.shareLive = false,
    DateTime? startedAt,
  })  : exercises = exercises ?? [],
        startedAt = startedAt ?? DateTime.now();

  bool get paused => pausedAt != null;
  int get elapsed {
    final end = pausedAt ?? DateTime.now();
    return math.max(0, (end.difference(startedAt).inMilliseconds - pausedMs) ~/ 1000);
  }

  int get restLeft => restUntil == null ? 0 : math.max(0, restUntil!.difference(DateTime.now()).inSeconds);
  double get km => distanceM / 1000;
  bool get planDone => exercises.isNotEmpty && ex >= exercises.length;
  LiveEx? get current => ex < exercises.length ? exercises[ex] : null;

  // ---------------------------------------------------------------- lifecycle
  Future<void> begin() async {
    active.value = this;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    await Wakelock.set(true);
    if (mode == 'gps') await _startGps();
    if (shareLive) {
      try {
        await Api.i.post('live/', {'sport': sport});
      } catch (_) {}
    }
    save();
    notifyListeners();
  }

  Future<void> _startGps() async {
    if (demoGps) {
      gpsNote = 'Demo GPS · simulated route';
      return;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        gpsNote = 'Location is off. Turn it on to record your route.';
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        gpsNote = 'Location permission is off. Time is still recorded.';
        return;
      }
      final LocationSettings settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 4,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'Exerlio is recording your activity',
                notificationText: 'Distance, pace and route are being tracked.',
                enableWakeLock: true,
                setOngoing: true,
              ))
          : Platform.isIOS
              ? AppleSettings(
                  accuracy: LocationAccuracy.best,
                  distanceFilter: 4,
                  activityType: ActivityType.fitness,
                  pauseLocationUpdatesAutomatically: false,
                  allowBackgroundLocationUpdates: true,
                  showBackgroundLocationIndicator: true)
              : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 4);
      gpsNote = 'GPS';
      _gps = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition, onError: (_) {
        gpsNote = 'GPS signal lost. Time is still recorded.';
        notifyListeners();
      });
    } catch (_) {
      gpsNote = 'GPS is not available on this device.';
    }
  }

  void _onPosition(Position p) {
    if (p.accuracy > 35) return; // ignore poor fixes
    final next = [p.latitude, p.longitude];
    if (points.isNotEmpty) {
      final d = Geolocator.distanceBetween(points.last[0], points.last[1], p.latitude, p.longitude);
      if (d < 3) return;
      if (paused && !autoPaused) return;
      if (autoPaused) _resumeAuto();
      distanceM += d;
    }
    points.add(next);
    _lastMove = DateTime.now();
    _checkKm();
    save();
  }

  void _demoStep() {
    final speed = {'run': 3.3, 'jog': 2.6, 'cycle': 7.0, 'walk': 1.4, 'trek': 1.2, 'openwater': 0.9}[sport] ?? 3.0;
    final step = speed * (0.85 + math.Random().nextDouble() * .3);
    _demoHeading += (math.Random().nextDouble() - .5) * .35;
    final last = points.isEmpty ? [16.3067, 80.4365] : points.last;
    final dLat = math.sin(_demoHeading) * step / 110540;
    final dLon = math.cos(_demoHeading) * step / (111320 * math.cos(last[0] * math.pi / 180));
    if (points.isEmpty) points.add(last);
    points.add([last[0] + dLat, last[1] + dLon]);
    distanceM += step;
    _lastMove = DateTime.now();
    _checkKm();
  }

  void _checkKm() {
    final k = distanceM ~/ 1000;
    if (k > kmSplits.length) {
      final sec = elapsed - _lastKmSec;
      _lastKmSec = elapsed;
      kmSplits.add({'km': k, 'sec': sec});
      if (voice) Voice.say('$k kilometre${k > 1 ? 's' : ''}. ${_spokenPace(elapsed / km)} per kilometre.');
    }
  }

  String _spokenPace(double secPerKm) {
    final m = secPerKm ~/ 60, s = (secPerKm % 60).round();
    return '$m minutes $s seconds';
  }

  void _onTick() {
    if (!paused) {
      if (mode == 'gps' && demoGps) _demoStep();
      if (mode == 'gps' && autoPause && !demoGps && points.isNotEmpty && DateTime.now().difference(_lastMove).inSeconds > 12) {
        autoPaused = true;
        pausedAt = DateTime.now();
      }
      _updateCoach();
    }
    if (elapsed % 10 == 0) save();
    notifyListeners();
  }

  void _resumeAuto() {
    if (pausedAt != null) pausedMs += DateTime.now().difference(pausedAt!).inMilliseconds;
    pausedAt = null;
    autoPaused = false;
  }

  void _updateCoach() {
    final t = elapsed;
    if (restLeft > 0) {
      coach = 'Rest ${fmtT(restLeft)}. Next set when the timer ends and your breathing settles.';
      return;
    }
    if (t < 300 && mode != 'sets') return;
    if (mode == 'hyrox') {
      final label = hyrox[seg][0];
      coach = advice[label] ?? (label.startsWith('Run') ? 'Run steady. Save something for the next station.' : '$label: settle in for 20 seconds before you push.');
    } else if (mode == 'gps' && t % 30 == 0 && km > .05) {
      coach = exhaust ? 'Exhaust Mode: keep it conversational. Zone 2 only today.' : 'Holding ${fmtT(t / km)} per km. Relax your shoulders, quick light steps.';
    } else if (mode == 'sets' && current != null && t % 20 == 0) {
      coach = 'Stop 2 to 3 reps before failure. Clean reps beat heavy ones.';
    } else if ((mode == 'rounds' || mode == 'games' || mode == 'laps' || mode == 'time') && t % 30 == 0) {
      coach = 'Good work. Breathe out longer than you breathe in between efforts.';
    }
  }

  // ---------------------------------------------------------------- actions
  void togglePause() {
    if (paused) {
      _resumeAuto();
      _lastMove = DateTime.now();
    } else {
      pausedAt = DateTime.now();
    }
    save();
    notifyListeners();
  }

  void adjust(String k, int dir) {
    final e = current;
    if (e == null) return;
    if (k == 'kg') {
      e.kg = math.max(0, e.kg + 2.5 * dir);
    } else {
      e.reps = math.max(1, e.reps + dir);
    }
    save();
    notifyListeners();
  }

  void logSet() {
    final e = current;
    if (e == null) return;
    logged.add({'n': e.name, 'kg': e.kg, 'reps': e.reps});
    e.done++;
    set++;
    restUntil = DateTime.now().add(Duration(seconds: exhaust ? 120 : 90));
    if (set >= e.sets) {
      ex++;
      set = 0;
      coach = ex < exercises.length ? 'Next: ${exercises[ex].name}. Start when the rest timer ends.' : 'All done. Cool down with 3 minutes of easy walking, then finish.';
    } else {
      coach = 'Rest. Next set when the timer ends.';
    }
    save();
    notifyListeners();
  }

  void skipRest() {
    restUntil = null;
    notifyListeners();
  }

  void nextSegment() {
    segSplits.add({'label': hyrox[seg][0], 'dist': hyrox[seg][1], 'sec': elapsed - segStart});
    segStart = elapsed;
    if (seg < hyrox.length - 1) seg++;
    coach = '${hyrox[seg][0]}: settle in for 20 seconds before you push.';
    save();
    notifyListeners();
  }

  void addCount() {
    count++;
    save();
    notifyListeners();
  }

  /// Stops sensors and returns the payload for POST /activities/.
  Future<Map<String, dynamic>> stop({required bool healthConnected}) async {
    _tick?.cancel();
    await _gps?.cancel();
    await Wakelock.set(false);
    if (shareLive) {
      try {
        await Api.i.delete('live/');
      } catch (_) {}
    }
    final secs = elapsed;
    if (mode == 'hyrox' && segSplits.length == seg) {
      segSplits.add({'label': hyrox[seg][0], 'dist': hyrox[seg][1], 'sec': secs - segStart});
    }
    if (mode == 'gps' && km - kmSplits.length > .05) {
      kmSplits.add({'km': kmSplits.length + 1, 'sec': secs - _lastKmSec, 'partial': true});
    }
    var hr = <int>[];
    if (healthConnected) hr = await HealthSync.heartRate(startedAt, DateTime.now());
    final pts = points.length > 3000 ? [for (var i = 0; i < points.length; i += (points.length / 3000).ceil()) points[i]] : points;
    await clear();
    return {
      'sport': sport,
      'title': title,
      'seconds': math.max(5, secs),
      'distance_m': distanceM.round(),
      'count': count,
      'sets': logged,
      'splits': mode == 'hyrox' ? segSplits : kmSplits,
      'points': pts,
      'hr': hr,
      'plan_key': planKey,
      'weekday': weekday,
      'exhaust': exhaust,
    };
  }

  Future<void> discard() async {
    _tick?.cancel();
    await _gps?.cancel();
    await Wakelock.set(false);
    if (shareLive) {
      try {
        await Api.i.delete('live/');
      } catch (_) {}
    }
    await clear();
  }

  Future<void> clear() async {
    active.value = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kStore);
  }

  // ---------------------------------------------------------------- storage
  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStore, jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => {
        'sport': sport, 'mode': mode, 'title': title, 'plan': planKey, 'wd': weekday, 'exh': exhaust,
        'ex': exercises.map((e) => e.toJson()).toList(), 'hy': hyrox, 'adv': advice, 'voice': voice, 'ap': autoPause,
        'demo': demoGps, 'share': shareLive, 'start': startedAt.toIso8601String(), 'pms': pausedMs,
        'pat': pausedAt?.toIso8601String(), 'auto': autoPaused, 'log': logged, 'i': ex, 'set': set, 'pts': points,
        'dist': distanceM, 'kms': kmSplits, 'lks': _lastKmSec, 'seg': seg, 'ss': segStart, 'segs': segSplits, 'n': count,
      };

  /// Resume a session left running when the app was closed.
  static Future<LiveSession?> restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kStore);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final s = LiveSession(
        sport: m['sport'] as String,
        mode: m['mode'] as String,
        title: m['title'] as String,
        planKey: m['plan'] as String? ?? '',
        weekday: m['wd'] as int?,
        exhaust: m['exh'] == true,
        exercises: [for (final e in (m['ex'] as List)) LiveEx.fromJson(e as Map)],
        hyrox: [for (final h in (m['hy'] as List)) [for (final x in h as List) '$x']],
        advice: Map<String, String>.from(m['adv'] as Map),
        voice: m['voice'] == true,
        autoPause: m['ap'] == true,
        demoGps: m['demo'] == true,
        shareLive: m['share'] == true,
        startedAt: DateTime.parse(m['start'] as String),
      );
      s.pausedMs = m['pms'] as int;
      s.pausedAt = m['pat'] == null ? DateTime.now() : DateTime.parse(m['pat'] as String);
      s.autoPaused = false;
      s.logged.addAll([for (final x in m['log'] as List) Map<String, dynamic>.from(x as Map)]);
      s.ex = m['i'] as int;
      s.set = m['set'] as int;
      s.points.addAll([for (final x in m['pts'] as List) [for (final v in x as List) (v as num).toDouble()]]);
      s.distanceM = (m['dist'] as num).toDouble();
      s.kmSplits.addAll([for (final x in m['kms'] as List) Map<String, dynamic>.from(x as Map)]);
      s._lastKmSec = m['lks'] as int;
      s.seg = m['seg'] as int;
      s.segStart = m['ss'] as int;
      s.segSplits.addAll([for (final x in m['segs'] as List) Map<String, dynamic>.from(x as Map)]);
      s.count = m['n'] as int;
      s.coach = 'Paused while the app was closed. Tap Resume when you are ready.';
      await s.begin();
      return s;
    } catch (_) {
      await p.remove(_kStore);
      return null;
    }
  }
}


/// A finished workout that could not be uploaded yet. Sent on the next app start.
class PendingActivity {
  static const _k = 'exerlio.pending_activity';
  static Future<void> keep(Map<String, dynamic> payload) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(payload));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k);
  }

  /// Returns the saved activity response, or null if nothing was pending / it failed again.
  static Future<Map<String, dynamic>?> flush() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return null;
    try {
      final r = await Api.i.post('activities/', jsonDecode(raw));
      await p.remove(_k);
      return Map<String, dynamic>.from(r as Map);
    } on ApiError catch (e) {
      if (e.status == 400) await p.remove(_k); // invalid, never retry
      return null;
    } catch (_) {
      return null;
    }
  }
}
