// Usage events: version stays in step with pubspec, API calls map to the right events,
// and nothing typed by the user ends up in an event.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness/core/api.dart';
import 'package:fitness/core/track.dart';

void main() {
  test('kAppVersion matches pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':')[1].trim().split('+').first, kAppVersion);
  });

  test('paths are normalised', () {
    expect(Track.normPath('posts/42/like/'), 'posts/#/like/');
    expect(Track.normPath('threads/7/'), 'threads/#/');
    expect(Track.normPath('train/day/3/mine/?x=1'), 'train/day/#/mine/');
  });

  test('successful calls become events, typed text never does', () async {
    SharedPreferences.setMockInitialValues({});
    await Track.i.init(await SharedPreferences.getInstance());
    final report = Api.i.onResult!;
    report('POST', 'posts/42/like/', {}, {});
    report('POST', 'threads/9/', {'text': 'my private message'}, {});
    report('POST', 'activities/', {'sport': 'run', 'distance_m': 5230, 'points': []}, {});
    report('POST', 'meals/', {'source': 'scan', 'name': 'Masala dosa'}, {});
    report('POST', 'recovery/session/', {'steps': [0]}, {});
    report('POST', 'recovery/session/', {'steps': [0, 1], 'complete': true}, {});
    report('GET', 'home/', null, {});
    report('ERROR', 'meals/scan/', null, {'code': 502});
    report('POST', 'track/', {}, {});

    final names = Track.i.pending.map((e) => e['name']).toList();
    expect(names, containsAllInOrder(['app_open', 'like', 'message_send', 'live_finish', 'scan_saved', 'recovery_done', 'api_error']));
    expect(names.where((n) => n == 'recovery_done').length, 1, reason: 'only the completed session counts');
    final live = Track.i.pending.firstWhere((e) => e['name'] == 'live_finish');
    expect((live['props'] as Map)['km'], 5.2);
    final all = Track.i.pending.toString();
    expect(all.contains('my private message'), isFalse);
    expect(all.contains('Masala dosa'), isFalse);
    expect(Track.i.pending.every((e) => (e['session_id'] as String).length == 32), isTrue);
  });
}
