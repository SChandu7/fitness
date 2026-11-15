import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Keep in step with `version:` in pubspec.yaml (test/track_test.dart checks it).
const String kAppVersion = '3.3.0';

/// First-party usage events: which screens people open and which features they use,
/// so the team can see how Exerlio is used. Sent only to our own server
/// (`track/`), never to third parties. No message text, food names or health values
/// are ever recorded: only event names, screen names and small counters.
class Track {
  Track._();
  static final Track i = Track._();

  static const _kDevice = 'exerlio.device';
  static const _kQueue = 'exerlio.track.queue';
  static const _sessionGap = Duration(minutes: 30);
  static const _maxQueue = 500;

  SharedPreferences? _prefs;
  final List<Map<String, dynamic>> _queue = [];
  String _device = '';
  String _session = '';
  DateTime _foregroundAt = DateTime.now();
  DateTime? _backgroundAt;
  String _lastScreen = '';
  bool _sending = false;
  bool _ready = false;

  @visibleForTesting
  List<Map<String, dynamic>> get pending => List.unmodifiable(_queue);

  @visibleForTesting
  static String normPath(String path) => _norm(path);

  String get _platform => Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : Platform.operatingSystem;

  Future<void> init(SharedPreferences prefs) async {
    if (_ready) return;
    _prefs = prefs;
    _device = prefs.getString(_kDevice) ?? '';
    if (_device.isEmpty) {
      _device = _id();
      await prefs.setString(_kDevice, _device);
    }
    final saved = prefs.getString(_kQueue);
    if (saved != null) {
      try {
        _queue.addAll([for (final e in jsonDecode(saved) as List) Map<String, dynamic>.from(e as Map)]);
      } catch (_) {}
    }
    _ready = true;
    _newSession();
    event('app_open', props: {'cold': true});
    Timer.periodic(const Duration(seconds: 20), (_) => flush()); // lives as long as the app
    Api.i.onResult = _fromApi;
  }

  String _id() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  void _newSession() {
    _session = _id();
    _foregroundAt = DateTime.now();
    _lastScreen = '';
  }

  /// Records one event. Cheap and never throws.
  void event(String name, {String screen = '', Map<String, Object?> props = const {}}) {
    if (!_ready) return;
    _queue.add({
      'name': name,
      'screen': screen,
      'props': props,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'session_id': _session,
    });
    if (_queue.length > _maxQueue) _queue.removeRange(0, _queue.length - _maxQueue);
    _persist();
    if (_queue.length >= 40) flush();
  }

  void screen(String name) {
    if (name.isEmpty || name == _lastScreen) return;
    _lastScreen = name;
    event('screen_view', screen: name);
    if (name == 'ProScreen') event('paywall_view');
    if (name == 'SupportScreen') event('support_open');
    if (name == 'ScanScreen') event('scan_start');
  }

  void lifecycle(AppLifecycleState s) {
    if (!_ready) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) {
      if (_backgroundAt != null) return;
      _backgroundAt = DateTime.now();
      event('app_background', props: {'secs': DateTime.now().difference(_foregroundAt).inSeconds});
      flush();
    } else if (s == AppLifecycleState.resumed && _backgroundAt != null) {
      final away = DateTime.now().difference(_backgroundAt!);
      _backgroundAt = null;
      if (away > _sessionGap) _newSession();
      _foregroundAt = DateTime.now();
      event('app_open', props: {'cold': false});
    }
  }

  void _persist() {
    try {
      _prefs?.setString(_kQueue, jsonEncode(_queue));
    } catch (_) {}
  }

  Future<void> flush() async {
    if (!_ready || _sending || _queue.isEmpty) return;
    _sending = true;
    final batch = _queue.take(100).toList();
    try {
      await Api.i.post('track/', {
        'device_id': _device,
        'session_id': _session,
        'platform': _platform,
        'app_version': kAppVersion,
        'events': batch,
      });
      _queue.removeRange(0, batch.length);
      _persist();
    } catch (_) {
      // offline or server busy: keep them and try on the next tick
    } finally {
      _sending = false;
    }
  }

  /// Turns successful API calls into feature events, so an event means the action really happened.
  void _fromApi(String method, String path, Object? body, Object? result) {
    if (path.startsWith('track/')) return;
    final b = body is Map ? body : const {};
    final r = result is Map ? result : const {};
    if (method == 'ERROR') {
      event('api_error', props: {'path': _norm(path), 'code': r['code'] ?? 0});
      return;
    }
    if (method != 'POST') return;
    final p = _norm(path);
    final name = switch (p) {
      'auth/register/' => 'signup',
      'auth/login/' => 'login',
      'onboarding/' => 'onboarding_done',
      'activities/' => b.containsKey('points') ? 'live_finish' : 'workout_done',
      'meals/scan/' => 'scan_result',
      'meals/' => b['source'] == 'scan' ? 'scan_saved' : 'meal_logged',
      'water/' => 'water_logged',
      'checkin/' => 'checkin_done',
      'recovery/session/' => b['complete'] == true ? 'recovery_done' : '',
      'stories/#/view/' => 'story_view',
      'stories/' => 'story_create',
      'posts/' => 'post_create',
      'reels/' => 'reel_create',
      'reels/#/view/' => 'reel_view',
      'posts/#/like/' || 'reels/#/like/' || 'stories/#/like/' => 'like',
      'posts/#/comments/' || 'reels/#/comments/' => 'comment',
      'users/#/follow/' => 'follow',
      'clubs/#/join/' => 'club_join',
      'challenges/#/join/' => 'challenge_join',
      'threads/#/' || 'threads/start/' => 'message_send',
      'support/' => 'ticket_create',
      'women/day/' => 'women_checkin',
      'train/event/' => 'event_prep_set',
      'day/focus/' => 'focus_set',
      'train/day/#/mine/' => 'mine_saved',
      _ => '',
    };
    if (name.isEmpty) return;
    final props = <String, Object?>{};
    if (name == 'live_finish' || name == 'workout_done') {
      props['sport'] = '${b['sport'] ?? ''}';
      final m = b['distance_m'];
      if (m is num && m > 0) props['km'] = (m / 100).round() / 10;
    }
    if (name == 'scan_result') props['items'] = (r['items'] is List) ? (r['items'] as List).length : null;
    event(name, props: props);
  }

  /// "posts/42/like/" -> "posts/#/like/"; drops any query string.
  static String _norm(String path) => path.split('?').first.replaceAll(RegExp(r'/\d+(?=/)'), '/#');
}

/// Records a screen view whenever a named route is pushed (context.push names routes by widget type).
class TrackObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final n = route.settings.name;
    if (n != null && n != '/') Track.i.screen(n);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final n = previousRoute?.settings.name;
    if (n != null && n != '/') Track.i.screen(n);
  }
}
