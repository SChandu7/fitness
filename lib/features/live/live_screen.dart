import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'live_session.dart';
import 'summary_screen.dart';

/// Live tracking for every sport: sets, GPS, the 16-segment Hyrox race, or a simple counter.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  /// Starts (or reopens) a session. [exercises] come from a plan: {name, sets, reps, load_kg}.
  static Future<void> start(BuildContext context,
      {required String sport, required String title, String planKey = '', int? weekday, List<Json> exercises = const []}) async {
    final running = LiveSession.active.value;
    if (running != null) {
      context.say('${running.title} is still running. Finish it first.');
      await context.push(const LiveScreen());
      return;
    }
    final app = context.app;
    final sp = app.sport(sport);
    final mode = sp.s('mode', 'time');
    final exh = app.me.b('exhaust');
    final s = LiveSession(
      sport: sport,
      mode: exercises.isNotEmpty ? 'sets' : mode,
      title: title,
      planKey: planKey,
      weekday: weekday,
      exhaust: exh,
      exercises: [
        for (final e in exercises)
          LiveEx(e.s('name'), e.i('sets', 3), int.tryParse(e.s('reps').split(RegExp(r'[^0-9]')).first) ?? 10, e.d('load_kg')),
      ],
      hyrox: [for (final h in app.catalog.l('hyrox')) [h.s('label'), h.s('dist')]],
      advice: {for (final e in app.catalog.m('advice').entries) e.key: '${e.value}'},
      voice: app.setting('voice', true),
      autoPause: app.setting('autoPause', true),
      demoGps: app.setting('demoGps', false),
      shareLive: app.setting('liveLoc', false),
    );
    await s.begin();
    app.say('$title started');
    if (context.mounted) await context.push(const LiveScreen());
  }

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  bool _saving = false;
  Map<String, dynamic>? _pending; // finished but not uploaded yet (no connection)

  Future<void> _upload(Map<String, dynamic> payload) async {
    setState(() => _saving = true);
    try {
      final r = await Api.i.post('activities/', payload);
      await PendingActivity.clear();
      if (!mounted) return;
      context.app.changed();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SummaryScreen(result: Map<String, dynamic>.from(r as Map))));
    } on ApiError catch (e) {
      await PendingActivity.keep(payload);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _pending = payload;
      });
      context.say('${e.message} Your workout is saved on this phone.');
    }
  }

  Future<void> _finish(LiveSession s) async {
    if (s.elapsed < 5) {
      await s.discard();
      if (mounted) {
        context.say('Too short to save');
        Navigator.pop(context);
      }
      return;
    }
    setState(() => _saving = true);
    final connected = context.app.me.m('connected');
    final payload = await s.stop(healthConnected: connected.b('appleHealth') || connected.b('healthConnect'));
    await PendingActivity.keep(payload);
    await _upload(payload);
  }

  Future<void> _discard(LiveSession s) async {
    final ok = await confirmX(context, title: 'Discard this workout?', body: 'It will not be saved or count toward your streak.', ok: 'Discard');
    if (!ok) return;
    await s.discard();
    if (mounted) {
      context.say('Workout discarded');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LiveSession?>(
      valueListenable: LiveSession.active,
      builder: (context, s, _) {
        if (s == null && _saving && _pending == null) {
          return XScreen(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.c.ink)),
                gap16,
                Text('Saving your workout', style: XT.small(context)),
              ]),
            ),
          );
        }
        if (s == null && _pending != null) {
          return XScreen(
            body: Column(children: [
              const XTopBar('Not saved yet'),
              Expanded(
                child: XEmpty(
                    icon: Icons.cloud_off_rounded,
                    title: 'Your workout is safe on this phone',
                    body: 'We could not reach the server. Try again when you have a connection. It is also sent automatically next time you open Exerlio.'),
              ),
            ]),
            dock: XDock(children: [XButton('Save again', loading: _saving, onTap: () => _upload(_pending!))]),
          );
        }
        if (s == null) {
          return XScreen(body: Column(children: [const XTopBar('Live'), Expanded(child: XEmpty(icon: Icons.timer_outlined, title: 'No session running', body: 'Start one from Train.'))]));
        }
        return ListenableBuilder(
          listenable: s,
          builder: (context, _) => XScreen(
            body: Column(children: [
              XTopBar(context.app.sportLabel(s.sport), actions: [XIconBtn(Icons.close_rounded, tooltip: 'Discard', onTap: () => _discard(s))]),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 24), children: [
                  _card(s),
                  gap16,
                  ..._extra(s),
                ]),
              ),
            ]),
            dock: XDock(children: _dock(s)),
          ),
        );
      },
    );
  }

  Widget _card(LiveSession s) {
    final c = context.c;
    final on = c.onInk;
    final dim = on.withValues(alpha: .62);
    Widget metric;
    switch (s.mode) {
      case 'hyrox':
        metric = Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text('${s.hyrox[s.seg][0]} · ${s.hyrox[s.seg][1]}', style: XT.metric(context, 20, color: on))),
          Text('${fmtT(s.elapsed - s.segStart)} this segment', style: XT.small(context, color: dim)),
        ]);
      case 'gps':
        final u = context.app.units;
        metric = _grid([
          ('Distance', u.dist(s.km)),
          ('Pace', s.km > .01 ? u.pace(s.elapsed / s.km) : '—'),
          ('Kcal', '${(s.elapsed / 60 * 10 * context.app.me.d('weight_kg', 74) / 74).round()}'),
        ], on, dim);
      case 'sets':
        final e = s.current;
        metric = e == null
            ? Text('All exercises done', style: XT.metric(context, 20, color: on))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('EXERCISE ${s.ex + 1} OF ${s.exercises.length}', style: XT.label(context, color: dim)),
                gap4,
                Text(e.name, style: XT.h2(context, color: on)),
                gap12,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _metric('Set', '${(s.set + 1).toString().padLeft(2, '0')} / ${e.sets.toString().padLeft(2, '0')}', on, dim)),
                  Expanded(child: _metric('Load', e.kg > 0 ? '${fmt1(e.kg)} kg' : 'Body', on, dim, step: (d) => s.adjust('kg', d), what: 'load')),
                  Expanded(child: _metric('Reps', '${e.reps}', on, dim, step: (d) => s.adjust('reps', d), what: 'reps')),
                ]),
              ]);
      default:
        final unit = const {'laps': 'Laps', 'games': 'Games', 'rounds': 'Rounds', 'time': 'Blocks'}[s.mode] ?? 'Rounds';
        metric = Row(children: [
          Expanded(child: Text('$unit: ${s.count}', style: XT.metric(context, 22, color: on))),
          XButton('Add ${unit.toLowerCase().replaceAll(RegExp(r's$'), '')}', icon: Icons.add_rounded, small: true, expand: false, kind: XBtn.outline,
              onTap: s.addCount),
        ]);
    }
    return XCard(
      dark: true,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: XKicker('${s.paused ? (s.autoPaused ? 'Auto-paused' : 'Paused') : 'Live'} · ${s.title}', color: dim)),
          if (s.exhaust) Text('Exhaust Mode', style: XT.small(context, color: dim)),
        ]),
        gap12,
        Text(fmtT(s.elapsed), style: XT.big(context, color: on, size: 64)),
        gap16,
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: on.withValues(alpha: .15)))),
          child: metric,
        ),
        gap16,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: on.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s.restLeft > 0) ...[const Padding(padding: EdgeInsets.only(top: 6), child: XDot()), const SizedBox(width: 10)],
            Expanded(child: Text(s.coach, style: XT.body(context, color: on).copyWith(fontSize: 14))),
          ]),
        ),
        if (s.autoPaused) ...[gap12, XKicker('Auto-paused · you stopped moving', color: dim)],
        if (s.mode == 'gps' && s.shareLive) ...[gap8, XKicker('Sharing live location with followers', color: dim)],
      ]),
    );
  }

  Widget _grid(List<(String, String)> items, Color on, Color dim) => Row(children: [
        for (final i in items) Expanded(child: _metric(i.$1, i.$2, on, dim)),
      ]);

  Widget _metric(String l, String v, Color on, Color dim, {void Function(int)? step, String what = ''}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.toUpperCase(), style: XT.label(context, color: dim)),
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: XT.metric(context, 20, color: on))),
        if (step != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            _stepBtn(Icons.remove_rounded, 'Less $what', () => step(-1), on),
            const SizedBox(width: 6),
            _stepBtn(Icons.add_rounded, 'More $what', () => step(1), on),
          ]),
        ],
      ]);

  Widget _stepBtn(IconData i, String label, VoidCallback onTap, Color on) => Semantics(
        button: true,
        label: label,
        child: Press(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 28,
            decoration: BoxDecoration(border: Border.all(color: on.withValues(alpha: .25)), borderRadius: BorderRadius.circular(8)),
            child: Icon(i, size: 14, color: on),
          ),
        ),
      );

  List<Widget> _extra(LiveSession s) {
    final c = context.c;
    if (s.mode == 'hyrox') {
      return [
        Row(children: [const Expanded(child: XLabel('Splits · 8 runs + 8 stations')), Text('${s.seg + 1} of ${s.hyrox.length}', style: XT.small(context))]),
        gap8,
        for (var i = 0; i < s.hyrox.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              if (i == s.seg) ...[const XDot(), const SizedBox(width: 8)],
              Expanded(
                  child: Text('${s.hyrox[i][0]} · ${s.hyrox[i][1]}',
                      style: XT.small(context, color: i > s.seg ? c.muted : c.ink).copyWith(fontWeight: i == s.seg ? FontWeight.w600 : FontWeight.w400))),
              Text(i < s.segSplits.length ? fmtT(s.segSplits[i]['sec'] as num) : (i == s.seg ? fmtT(s.elapsed - s.segStart) : '—'),
                  style: XT.small(context, color: i > s.seg ? c.muted : c.ink)),
            ]),
          ),
      ];
    }
    if (s.mode == 'gps') {
      return [
        ClipRRect(
          borderRadius: BorderRadius.circular(XS.r3),
          child: RouteMap(points: s.points.length > 1 ? s.points : const [], height: 220, live: true),
        ),
        gap8,
        Text('${s.gpsNote.isEmpty ? 'GPS' : s.gpsNote} · ${context.app.units.dist(s.km)} · start point hidden when shared', style: XT.small(context)),
        if (s.kmSplits.isNotEmpty) ...[
          gap16,
          const XLabel('Splits'),
          for (final k in s.kmSplits)
            XRow('Km ${k['km']}', trailing: Text(fmtT(k['sec'] as num), style: XT.small(context, color: c.ink)), divider: true),
        ],
      ];
    }
    if (s.mode == 'sets' && s.exercises.isNotEmpty) {
      return [
        Row(children: [Expanded(child: XLabel(s.title)), Text('${s.logged.length} sets logged', style: XT.small(context))]),
        gap8,
        for (var k = 0; k < s.exercises.length; k++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              SizedBox(width: 24, child: Text((k + 1).toString().padLeft(2, '0'), style: XT.small(context))),
              Expanded(
                child: Text(s.exercises[k].name,
                    style: XT.small(context, color: k > s.ex ? c.muted : c.ink).copyWith(fontWeight: k == s.ex ? FontWeight.w600 : FontWeight.w400)),
              ),
              Text('${s.exercises[k].done} / ${s.exercises[k].sets}', style: XT.small(context, color: c.ink)),
            ]),
          ),
      ];
    }
    return [
      XNote(text: '${context.app.sport(s.sport).s('note')} Heart rate from a watch is added after you finish when Apple Health or Health Connect is connected.'),
    ];
  }

  List<Widget> _dock(LiveSession s) {
    final out = <Widget>[];
    if (s.mode == 'hyrox') {
      out.add(s.seg < s.hyrox.length - 1
          ? XButton('Next: ${s.hyrox[s.seg + 1][0]}', onTap: s.paused ? null : s.nextSegment)
          : XButton('Finish race', kind: XBtn.accent, loading: _saving, onTap: () => _finish(s)));
    } else if (s.mode == 'sets' && s.exercises.isNotEmpty) {
      if (!s.planDone) {
        out.add(XButton('Complete set ${s.set + 1} of ${s.current!.sets}', onTap: s.paused ? null : s.logSet));
        if (s.restLeft > 0) out.add(XButton('Skip rest', kind: XBtn.ghost, small: true, onTap: s.skipRest));
      } else {
        out.add(XButton('Finish session', kind: XBtn.accent, loading: _saving, onTap: () => _finish(s)));
      }
    }
    final showFinish = !(s.mode == 'hyrox' && s.seg >= s.hyrox.length - 1) && !(s.mode == 'sets' && s.planDone && s.exercises.isNotEmpty);
    out.add(Row(children: [
      Expanded(
        child: XButton(s.paused ? 'Resume' : 'Pause',
            icon: s.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, kind: XBtn.secondary, onTap: s.togglePause),
      ),
      if (showFinish) ...[
        const SizedBox(width: 8),
        Expanded(
          child: XButton('Finish',
              loading: _saving, kind: (s.mode == 'hyrox' || (s.mode == 'sets' && s.exercises.isNotEmpty)) ? XBtn.secondary : XBtn.primary,
              onTap: () => _finish(s)),
        ),
      ],
    ]));
    return out;
  }
}
