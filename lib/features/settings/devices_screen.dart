import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/device.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Connected devices. Apple Health (iPhone) and Health Connect (Android) are real;
/// Garmin, Fitbit, Strava and straps reach Exerlio through those two hubs for now.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  String? _busy;

  bool _onThisPhone(String platform) {
    if (kIsWeb) return false;
    if (platform == 'ios') return Platform.isIOS;
    if (platform == 'android') return Platform.isAndroid;
    return true;
  }

  Future<void> _connect(Json d, Future<void> Function() reload) async {
    final key = d.s('key');
    setState(() => _busy = key);
    try {
      final problem = await HealthSync.connect();
      if (!mounted) return;
      if (problem != null) {
        context.say(problem);
      } else {
        context.say('${d.s('name')} connected. Recovery now uses your own data.');
        context.app.changed();
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    await reload();
  }

  Future<void> _sync(Json d, Future<void> Function() reload) async {
    setState(() => _busy = d.s('key'));
    try {
      final n = await HealthSync.sync();
      if (mounted) {
        context.say(n == 0 ? 'No new health data yet. Wear your watch and sync again later.' : 'Synced $n days');
        context.app.changed();
      }
    } catch (_) {
      if (mounted) context.say('Could not read health data. Check permissions in your phone settings.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    await reload();
  }

  Future<void> _disconnect(Json d, Future<void> Function() reload) async {
    final ok = await confirmX(context,
        title: 'Disconnect ${d.s('name')}?', body: 'Synced health data is removed from Exerlio. You can connect again any time.', ok: 'Disconnect');
    if (!ok || !mounted) return;
    final r = await attempt(context, () => Api.i.post('devices/${d.s('key')}/', {'connected': false}));
    if (r != null && mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
    }
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Column(children: [
        const XTopBar('Connected devices'),
        Expanded(
          child: Loader<Json>(
            load: () async => Map<String, dynamic>.from(await Api.i.get('devices/') as Map),
            builder: (context, d, reload) {
              final hub = Platform.isIOS ? 'Apple Health' : 'Health Connect';
              return ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 32), children: [
                Text('Bring your data with you.', style: XT.h1(context)),
                gap8,
                Text('Connect $hub so Exerlio can use your steps, heart rate, HRV, sleep and SpO₂ for recovery and live sessions.',
                    style: XT.small(context)),
                if (d.s('last_sync').isNotEmpty) ...[gap8, Text('Last synced day: ${d.s('last_sync')}', style: XT.small(context))],
                gap16,
                for (final dev in d.l('items').where((x) => _onThisPhone(x.s('platform'))))
                  _row(context, dev, reload, hub),
                gap20,
                XNote(
                  label: 'Data control',
                  text: 'Exerlio only reads health data. It never writes to $hub and never publishes health data on its own. '
                      'Disconnecting deletes the synced copy from your account.',
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, Json d, Future<void> Function() reload, String hub) {
    final c = context.c;
    final key = d.s('key');
    final on = d.b('connected');
    final real = d.b('available');
    final busy = _busy == key;
    final icon = switch (key) { 'strap' => Icons.favorite_border_rounded, 'strava' => Icons.route_outlined, _ => Icons.monitor_heart_outlined };
    Widget action;
    if (!real) {
      action = Text('Via $hub', style: XT.small(context));
    } else if (on) {
      action = Row(mainAxisSize: MainAxisSize.min, children: [
        XButton('Sync', small: true, expand: false, kind: XBtn.secondary, loading: busy, onTap: () => _sync(d, reload)),
        XIconBtn(Icons.link_off_rounded, tooltip: 'Disconnect', color: c.muted, onTap: () => _disconnect(d, reload)),
      ]);
    } else {
      action = XButton('Connect', small: true, expand: false, loading: busy, onTap: () => _connect(d, reload));
    }
    return XRow(
      d.s('name'),
      sub: real ? d.s('detail') : '${d.s('detail')}. Turn on ${d.s('name')} sync inside $hub and it flows in here.',
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: c.gray, shape: BoxShape.circle),
        child: Stack(alignment: Alignment.center, children: [
          Icon(icon, size: 19, color: c.ink),
          if (on) Positioned(right: 4, top: 4, child: XDot(size: 8, color: c.orange)),
        ]),
      ),
      trailing: action,
    );
  }
}
