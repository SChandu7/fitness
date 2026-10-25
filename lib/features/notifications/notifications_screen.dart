import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import '../shell/shell.dart';
import '../social/comments_sheet.dart';

/// Nudges (live, computed from today's data) and Activity (stored notifications).
class NotificationsScreen extends StatefulWidget {
  final int seg;
  const NotificationsScreen({super.key, this.seg = 0});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late int _seg = widget.seg;
  String _f = 'all';
  bool _hasUnread = false;
  Timer? _markRead;

  @override
  void dispose() {
    _markRead?.cancel();
    super.dispose();
  }

  /// Like the prototype: opening Activity marks it read after a moment.
  void _scheduleRead() {
    _markRead?.cancel();
    _markRead = Timer(const Duration(milliseconds: 1500), () async {
      try {
        await Api.i.post('notifications/read/');
        if (mounted) setState(() => _hasUnread = false);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Column(children: [
        const XTopBar('Notifications'),
        Padding(
          padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 4),
          child: Stack(children: [
            XSegment(labels: const ['Nudges', 'Activity'], index: _seg, onPick: (i) => setState(() => _seg = i)),
            if (_hasUnread && _seg == 0) Positioned(right: 18, top: 14, child: XDot(size: 6, color: context.c.orange)),
          ]),
        ),
        Expanded(child: _seg == 0 ? _nudges() : _activity()),
      ]),
    );
  }

  // --------------------------------------------------------------- nudges

  Widget _nudges() => Loader<Json>(
        key: const ValueKey('nudges'),
        load: () async {
          final d = Map<String, dynamic>.from(await Api.i.get('notifications/?seg=nudges') as Map);
          if (mounted && d.i('unread_activity') > 0 != _hasUnread) setState(() => _hasUnread = d.i('unread_activity') > 0);
          return d;
        },
        builder: (context, d, reload) {
          final w = d.m('water');
          return ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 32), children: [
            _WaterCard(water: w, onChanged: reload),
            gap16,
            if (d.b('cleared') || d.l('nudges').isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('All caught up.', style: XT.small(context)))
            else ...[
              Row(children: [
                const Expanded(child: XLabel('Today')),
                XLink('Clear', onTap: () async {
                  final r = await attempt(context, () => Api.i.post('nudges/clear/'));
                  if (r != null) {
                    reload();
                    if (context.mounted) context.app.changed();
                  }
                }),
              ]),
              for (final n in d.l('nudges')) _NudgeRow(n, onDone: reload),
            ],
            gap20,
            const XLabel('When we nudge you'),
            for (final t in d.l('toggles')) _ToggleRow(t['key'] as String, t.s('title'), t.s('sub'), fallback: t.b('on')),
            gap12,
            Text('Reminders arrive as phone notifications once push is switched on for your account. Quiet hours are in Settings.',
                style: XT.small(context)),
          ]);
        },
      );

  // ------------------------------------------------------------- activity

  Widget _activity() => Column(children: [
        XHScroll(padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 10), children: [
          for (final f in const [('all', 'All'), ('social', 'Social'), ('health', 'Health'), ('clubs', 'Clubs')])
            XChip(f.$2, on: _f == f.$1, onTap: () => setState(() => _f = f.$1)),
        ]),
        Expanded(
          child: Loader<Json>(
            key: ValueKey('activity|$_f'),
            load: () async {
              final d = Map<String, dynamic>.from(await Api.i.get('notifications/?seg=activity&f=$_f') as Map);
              if (d.i('unread_activity') > 0) _scheduleRead();
              return d;
            },
            builder: (context, d, reload) {
              final items = d.l('items').where((n) => !(n.s('kind') == 'req' && n.s('state') == 'declined')).toList();
              return ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 32), children: [
                if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('Nothing new here.', style: XT.small(context))),
                for (final n in items) _NotifRow(n, onChanged: reload),
              ]);
            },
          ),
        ),
      ]);
}

class _WaterCard extends StatefulWidget {
  final Json water;
  final Future<void> Function() onChanged;
  const _WaterCard({required this.water, required this.onChanged});
  @override
  State<_WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends State<_WaterCard> {
  int? _glasses;

  Future<void> _set(int n) async {
    final before = _glasses ?? widget.water.i('glasses');
    // Tapping the last filled glass empties it, so you can undo a mis-tap.
    final next = n == before ? n - 1 : n;
    setState(() => _glasses = next);
    try {
      final r = await Api.i.post('water/', {'glasses': next}) as Map;
      if (!mounted) return;
      if ('${r['message']}'.isNotEmpty) context.say('${r['message']}');
      context.app.changed();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _glasses = before);
        context.say(e.message);
      }
    }
  }

  @override
  void didUpdateWidget(_WaterCard old) {
    super.didUpdateWidget(old);
    _glasses = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = widget.water;
    final g = _glasses ?? w.i('glasses');
    final goal = w.i('goal', 8);
    final ml = context.app.catalog.i('glass_ml', 375);
    final left = ((goal - g).clamp(0, 99) * ml / 1000);
    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: XLabel('Hydration')),
          Text(left <= 0 ? 'Goal reached' : '${left.toStringAsFixed(1)} L to go', style: XT.small(context)),
        ]),
        gap8,
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text((g * ml / 1000).toStringAsFixed(1), style: XT.metric(context, 34)),
          const SizedBox(width: 6),
          Text('/ ${(goal * ml / 1000).toStringAsFixed(1)} L', style: XT.small(context)),
        ]),
        gap12,
        Row(children: [
          for (var i = 0; i < goal; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                label: '${i + 1} glasses',
                selected: i < g,
                child: Press(
                  onTap: () => _set(i + 1),
                  child: AnimatedContainer(
                    duration: context.anim(XS.fast),
                    height: 30,
                    decoration: BoxDecoration(
                      color: i < g ? c.ink : c.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: i < g ? null : Border.all(color: c.line),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
        gap12,
        Text('A glass is about $ml ml. Tap one to fill it in.', style: XT.small(context)),
      ]),
    );
  }
}

IconData nudgeIcon(String k) => switch (k) {
      'drop' => Icons.water_drop_outlined,
      'fork' => Icons.restaurant_outlined,
      'flame' => Icons.local_fire_department_outlined,
      'dumbbell' => Icons.fitness_center_rounded,
      'flag' => Icons.flag_outlined,
      'cal' => Icons.calendar_today_outlined,
      'leaf' => Icons.eco_outlined,
      'act' => Icons.monitor_heart_outlined,
      'check' => Icons.check_rounded,
      _ => Icons.notifications_none_rounded,
    };

class _NudgeRow extends StatelessWidget {
  final Json n;
  final Future<void> Function() onDone;
  const _NudgeRow(this.n, {required this.onDone});

  Future<void> _act(BuildContext context) async {
    switch (n.s('action')) {
      case 'left':
        await Go.meal(context, tab: 2);
      case 'water':
        final r = await attempt(context, () => Api.i.post('water/', {'delta': 1}));
        if (r != null && context.mounted) {
          context.say('${(r as Map)['message']}'.isEmpty ? 'Glass logged' : '${r['message']}');
          context.app.changed();
        }
      case 'scan':
        await Go.scan(context);
      case 'streak':
        await Go.streak(context);
      case 'session':
        await Go.session(context, DateTime.now().weekday - 1);
      case 'challenge':
        await Go.challenge(context, n.i('id'));
      case 'progress':
        ShellNav.go(context, 3, profile: 'progress');
        return;
    }
    await onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.gray, shape: BoxShape.circle),
          child: Icon(nudgeIcon(n.s('icon')), size: 19, color: c.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.s('title'), style: XT.h3(context).copyWith(fontSize: 15))),
              Text(n.s('time'), style: XT.small(context).copyWith(fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text(n.s('text'), style: XT.small(context, color: c.ink)),
            const SizedBox(height: 6),
            Press(
              onTap: () => _act(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(n.s('cta'), style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right_rounded, size: 16, color: c.ink),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String k, title, sub;
  final bool fallback;
  const _ToggleRow(this.k, this.title, this.sub, {this.fallback = true});
  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    return XRow(title, sub: sub, trailing: XSwitch(value: app.setting(k, fallback), onChanged: (_) => app.toggleSetting(k, fallback)));
  }
}

class _NotifRow extends StatelessWidget {
  final Json n;
  final Future<void> Function() onChanged;
  const _NotifRow(this.n, {required this.onChanged});

  Future<void> _open(BuildContext context) async {
    final id = n.i('route_id');
    switch (n.s('route')) {
      case 'person':
        if (id > 0) await Go.person(context, id);
      case 'club':
        if (id > 0) await Go.club(context, id);
      case 'challenge':
        if (id > 0) await Go.challenge(context, id);
      case 'fuel':
        await Go.fuel(context);
      case 'recovery':
        await Go.recovery(context);
      case 'scan':
        await Go.scan(context);
      case 'streak':
        await Go.streak(context);
      case 'post':
        if (id > 0) await showComments(context, 'posts/$id');
      case 'activity':
        if (id > 0) await Go.activity(context, id);
      default:
        final a = n.m('actor');
        if (a.isNotEmpty) await Go.person(context, a.i('id'));
    }
  }

  Future<void> _respond(BuildContext context, bool accept) async {
    final r = await attempt(context, () => Api.i.post('notifications/${n.i('id')}/request/', {'accept': accept}));
    if (r != null && context.mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
    }
    await onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final actor = n.m('actor');
    final club = n.m('club');
    final kind = n.s('kind');
    final openReq = kind == 'req' && n.s('state') == 'open';
    final lead = actor.isNotEmpty
        ? XAvatar(actor, size: 44)
        : club.isNotEmpty
            ? XAvatar(club, size: 44, square: true, ink: true)
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.gray, shape: BoxShape.circle),
                child: Icon(nudgeIcon(const {'rec': 'act', 'water': 'drop', 'streak': 'flame', 'fuel': 'fork', 'challenge': 'flag', 'event': 'cal'}[kind] ?? 'check'),
                    size: 20, color: c.ink),
              );
    final name = actor.isNotEmpty ? actor.s('name') : (club.isNotEmpty ? club.s('name') : '');
    final text = n.s('text');
    final starts = name.isNotEmpty && text.startsWith(name);
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lead,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(style: XT.body(context).copyWith(fontSize: 14), children: [
                if (starts) TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: starts ? text.substring(name.length) : text),
                TextSpan(text: '  ${n.s('time')}', style: XT.small(context).copyWith(fontSize: 12)),
              ]),
            ),
            if (openReq) ...[
              gap8,
              Row(children: [
                XButton('Accept', small: true, expand: false, onTap: () => _respond(context, true)),
                const SizedBox(width: 8),
                XButton('Decline', small: true, expand: false, kind: XBtn.secondary, onTap: () => _respond(context, false)),
              ]),
            ],
          ]),
        ),
        if (n.b('unread')) Padding(padding: const EdgeInsets.only(left: 8, top: 8), child: XDot(color: c.orange)),
      ]),
    );
    if (openReq) return row;
    return Semantics(button: true, child: Press(onTap: () => _open(context), child: row));
  }
}
