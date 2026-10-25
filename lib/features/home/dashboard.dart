import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../log/log_sheet.dart';
import '../recovery/checkin_sheet.dart';
import '../routes.dart';
import '../settings/devices_screen.dart';
import '../shared/body_cards.dart';
import '../train/exhaust_card.dart';

/// Home → Dashboard. Everything for today, top to bottom, as in the client's v3 prototype.
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String? _pick;

  Future<Json> _load() async => Map<String, dynamic>.from(await Api.i.get('home/') as Map);

  Future<void> _post(String path, Object body, {String? fallback}) async {
    final r = await attempt(context, () => Api.i.post(path, body));
    if (!mounted || r == null) return;
    final msg = r is Map ? '${r['message'] ?? ''}' : '';
    if (msg.isNotEmpty) {
      context.say(msg);
    } else if (fallback != null) {
      context.say(fallback);
    }
    context.app.changed();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<Json>(
      load: _load,
      skeletonLines: 6,
      builder: (context, d, reload) {
        final sports = d.strs('sports');
        _pick ??= sports.isNotEmpty ? sports.first : 'run';
        return XPage(padding: const EdgeInsets.fromLTRB(XS.gutter, 22, XS.gutter, 40), children: [
          XLabel(d.s('date_label')),
          gap8,
          Text(context.genz ? d.s('greeting_genz') : d.s('greeting'), style: XT.h1(context)),
          gap16,
          if (d.m('exhaust').b('prompt')) ...[_exhaustPrompt(d.m('exhaust')), gap16],
          _streak(d.m('streak')),
          gap16,
          if (d.m('bmi').isNotEmpty) ...[
            BmiCard(weight: context.app.me.d('weight_kg'), height: context.app.me.d('height_cm')),
            gap16,
          ],
          _recovery(d.m('recovery'), d.m('exhaust').b('on')),
          gap24,
          _sportPicker(sports, d.l('library')),
          gap20,
          _plan(d.m('plan')),
          gap16,
          _challenges(d.l('challenges')),
          gap16,
          _tiles(d.m('tiles')),
          gap16,
          _water(d.m('water')),
          gap16,
          _nutrition(d.m('nutrition'), d.m('exhaust').b('on')),
          gap16,
          _preplan(d.m('preplan')),
          if (d.has('heart')) ...[gap16, _heart(d.m('heart'))],
          gap16,
          const ExhaustCard(),
          if (d.has('fuel')) ...[gap16, _fuel(d.m('fuel'))],
        ]);
      },
    );
  }

  Widget _exhaustPrompt(Json e) {
    return XCard(
      dark: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        XKicker('Work is done for today', color: context.c.onInk.withValues(alpha: .72)),
        gap12,
        Text('Long day? Exhaust Mode trims tonight\'s ${e.s('cut')} to ${e.i('mins')} minutes and keeps your streak alive.',
            style: XT.body(context, color: context.c.onInk)),
        gap12,
        Row(children: [
          XButton('Switch on', kind: XBtn.accent, small: true, expand: false, onTap: () => _post('exhaust/', {'on': true})),
          const SizedBox(width: 8),
          XButton('Not today', kind: XBtn.secondary, small: true, expand: false, onTap: () => _post('exhaust/dismiss/', {})),
        ]),
      ]),
    );
  }

  Widget _streak(Json s) {
    final c = context.c;
    final counts = s.b('counts');
    final fg = counts ? c.onInk : c.ink;
    final mutedFg = counts ? c.onInk.withValues(alpha: .7) : c.muted;
    return XCard(
      dark: counts,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_fire_department_outlined, size: 24, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.i('days')}-day streak', style: XT.h3(context, color: fg)),
              Text(counts ? 'Today counts. All three done.' : 'Today counts when all three are done.', style: XT.small(context, color: mutedFg)),
            ]),
          ),
        ]),
        gap16,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final p in s.l('parts'))
            Expanded(
              child: Semantics(
                button: true,
                label: '${p.s('label')}: ${p.s('sub')}',
                child: Press(
                  onTap: () => switch (p.s('route')) {
                    'session' => Go.session(context, DateTime.now().weekday - 1),
                    'scan' => Go.scan(context),
                    _ => Go.recoverySession(context),
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    XCheck(done: p.b('ok'), inverted: counts),
                    gap8,
                    Text(p.s('label'), style: XT.h3(context, color: fg).copyWith(fontSize: 14)),
                    Text(p.s('sub'), style: XT.small(context, color: mutedFg).copyWith(fontSize: 12)),
                  ]),
                ),
              ),
            ),
        ]),
        gap16,
        Row(children: [
          Expanded(
            child: Text('${s.i('bonus') > 0 ? '+${s.i('bonus')} bonus days from challenges. ' : ''}Light +3 · Moderate +5 · Heavy +10 · Extreme +15.',
                style: XT.small(context, color: mutedFg)),
          ),
          const SizedBox(width: 10),
          XButton('See streak', small: true, expand: false, kind: counts ? XBtn.outline : XBtn.secondary, onTap: () => Go.streak(context)),
        ]),
      ]),
    );
  }

  Widget _recovery(Json r, bool exhaust) {
    final c = context.c;
    if (!r.b('available')) {
      return XCard(
        onTap: () => Go.recovery(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const XKicker('Recovery'),
          gap12,
          Text(r.s('title', 'How are you today?'), style: XT.h2(context)),
          gap4,
          Text(r.s('note'), style: XT.small(context)),
          gap16,
          Row(children: [
            XButton('Check in · 3 taps', small: true, expand: false, onTap: () => showCheckinSheet(context)),
            const SizedBox(width: 8),
            XButton('Connect a watch', small: true, expand: false, kind: XBtn.secondary, onTap: () => context.push(const DevicesScreen())),
          ]),
        ]),
      );
    }
    final sample = r.b('is_sample');
    return XCard(
      onTap: () => Go.recovery(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: XKicker(sample ? 'Recovery · sample data' : (r.s('source') == 'checkin' ? 'Recovery · your check-in' : 'Recovery · today'))),
          Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
        ]),
        gap12,
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${r.i('score')}', style: XT.hero(context).copyWith(fontSize: 72)),
          const SizedBox(width: 8),
          Flexible(child: Text('/ 100 · ${exhaust ? 'Exhaust Mode on' : r.s('label')}', style: XT.small(context))),
        ]),
        gap12,
        XBar(r.i('score') / 100, color: c.orange),
        gap12,
        Text(r.s('note'), style: XT.body(context)),
        if (sample) ...[gap8, Text('*Sample values. Connect a device in Settings to use your own recovery data.', style: XT.small(context).copyWith(fontSize: 12))],
        if (r.l('headline').isNotEmpty) ...[
          gap12,
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Row(children: [for (final s in r.l('headline').take(3)) Expanded(child: XStat(s.s('label'), s.s('value'), size: 18))]),
          ),
        ],
      ]),
    );
  }

  Widget _sportPicker(List<String> sports, List<Json> library) {
    final app = context.app;
    final sp = app.sport(_pick!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const XLabel('What are you training today'),
      gap12,
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
          for (final k in sports) ...[XChip(app.sportLabel(k), on: k == _pick, onTap: () => setState(() => _pick = k)), const SizedBox(width: 8)],
          XChip('All sports', on: false, onTap: () => Go.track(context)),
        ]),
      ),
      gap12,
      Text(sp.s('note'), style: XT.small(context, color: context.c.ink)),
      gap12,
      XButton('Start ${sp.s('l').toLowerCase()}', icon: Icons.play_arrow_rounded, onTap: () => Go.startSport(context, _pick!)),
      gap16,
      Row(children: [
        const Expanded(child: XLabel('Or swap for')),
        XLink('Week plan', onTap: () => Go.weekPlan(context)),
      ]),
      gap8,
      SizedBox(
        height: 70,
        child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
          for (final w in library) ...[
            SizedBox(
              width: 150,
              child: XCard(
                muted: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => Go.library(context, w.s('key')),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.s('title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.h3(context).copyWith(fontSize: 14)),
                  const SizedBox(height: 3),
                  Text('${w.s('label')} · ${w.i('mins')} min', style: XT.small(context).copyWith(fontSize: 12)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ]),
      ),
    ]);
  }

  Widget _plan(Json p) {
    final c = context.c;
    final items = p.l('items');
    return XCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Column(children: [
        Row(children: [
          const Expanded(child: XLabel("Today's plan")),
          Text('${p.i('done')} of ${p.i('total')} done', style: XT.small(context)),
        ]),
        gap4,
        for (var i = 0; i < items.length; i++)
          Press(
            onTap: () => _planTap(items[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: c.line))),
              child: Row(children: [
                XCheck(done: items[i].b('done'), next: i == p.i('next')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(items[i].s('title'), style: XT.h3(context).copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(items[i].s('sub'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context)),
                  ]),
                ),
                if (i == p.i('next')) Text('Next', style: XT.small(context, color: c.ink)),
              ]),
            ),
          ),
      ]),
    );
  }

  void _planTap(Json it) {
    switch (it.s('action')) {
      case 'session':
        Go.session(context, it.i('weekday'));
      case 'recovery':
        Go.recoverySession(context);
      case 'quick':
        showQuickMealsSheet(context, slot: it.s('slot'));
      default:
        Go.scan(context, slot: it.s('slot'));
    }
  }

  Widget _challenges(List<Json> list) {
    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: XLabel('Challenges')), XLink('See all', onTap: () => Go.challenges(context))]),
        gap8,
        if (list.isEmpty) Text('Join one to earn bonus streak days.', style: XT.small(context)),
        for (final ch in list) ...[
          Press(
            onTap: () => Go.challenge(context, ch.i('id')),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(ch.s('title'), style: XT.h3(context).copyWith(fontSize: 15))),
                  Text('#${ch.m('me').i('rank')} · ${fmtN(ch.m('me').i('points'))} pts', style: XT.small(context)),
                ]),
                gap8,
                XBar(ch.m('me').d('progress'), color: goalColor(context, ch.m('me').d('progress'))),
                gap8,
                Text('${ch.m('me').s('amount')} · ${ch.m('me').b('done') ? 'Completed' : ch.m('me').s('pace')}', style: XT.small(context)),
              ]),
            ),
          ),
        ],
        gap8,
        Row(children: [
          XButton('Browse challenges', small: true, expand: false, kind: XBtn.secondary, onTap: () => Go.challenges(context)),
          const SizedBox(width: 8),
          XButton('Custom', icon: Icons.add_rounded, small: true, expand: false, kind: XBtn.secondary, onTap: () => Go.newChallenge(context)),
        ]),
      ]),
    );
  }

  Widget _tiles(Json t) {
    Widget tile(String l, String v, [String u = '', VoidCallback? onTap]) => XCard(
          muted: true,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.toUpperCase(), style: XT.label(context).copyWith(fontSize: 10)),
            gap8,
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(v, style: XT.metric(context, 18)),
                if (u.isNotEmpty) ...[const SizedBox(width: 3), Text(u, style: XT.small(context).copyWith(fontSize: 11))],
              ]),
            ),
          ]),
        );
    final steps = t['steps'];
    return XGrid(cols: 4, children: [
      tile('Steps', steps == null ? '—' : fmtN(steps as num), '', steps == null ? () => context.push(const DevicesScreen()) : null),
      tile('Active', fmtN(t.i('active_kcal')), 'kcal'),
      tile('Week', '${t.i('week_done')} / ${t.i('week_total')}'),
      tile('Streak', '${t.i('streak')}', 'days', () => Go.streak(context)),
    ]);
  }

  Widget _water(Json w) {
    final c = context.c;
    final g = w.i('glasses'), goal = w.i('goal');
    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.water_drop_outlined, size: 14, color: c.muted),
          const SizedBox(width: 6),
          const Expanded(child: XLabel('Hydration')),
          Text('$g of $goal glasses', style: XT.small(context)),
        ]),
        gap12,
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(w.d('litres').toStringAsFixed(1), style: XT.metric(context, 32)),
          const SizedBox(width: 6),
          Text('/ ${w.d('goal_l').toStringAsFixed(1)} L', style: XT.small(context)),
        ]),
        gap12,
        Row(children: [
          for (var i = 0; i < goal; i++)
            Expanded(
              child: Semantics(
                button: true,
                label: '${i + 1} glasses',
                child: Press(
                  onTap: () => _post('water/', {'glasses': i + 1 == g ? i : i + 1}),
                  child: AnimatedContainer(
                    duration: context.anim(XS.base),
                    height: 28,
                    margin: EdgeInsets.only(right: i == goal - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                        color: i < g ? (g >= goal * .8 ? c.orange : c.ink) : c.gray, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ),
        ]),
        gap12,
        Text(w.s('line'), style: XT.small(context)),
        gap12,
        Row(children: [
          XButton('Log a glass', icon: Icons.add_rounded, small: true, expand: false, kind: XBtn.secondary,
              onTap: () => _post('water/', {'delta': 1})),
          const SizedBox(width: 8),
          Semantics(
            label: 'Remove a glass',
            child: XButton('', icon: Icons.remove_rounded, small: true, expand: false, kind: XBtn.secondary,
                onTap: g == 0 ? null : () => _post('water/', {'delta': -1})),
          ),
        ]),
      ]),
    );
  }

  Widget _nutrition(Json n, bool exhaust) {
    final c = context.c;
    final e = n.m('eaten'), t = n.m('targets');
    Widget macro(String l, String k) {
      final v = e.i(k), tg = t.i(k);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(l, style: XT.small(context, color: c.ink))), Text('$v / $tg g', style: XT.small(context))]),
          const SizedBox(height: 6),
          XBar(tg == 0 ? 0 : v / tg, color: goalColor(context, tg == 0 ? 0 : v / tg)),
        ]),
      );
    }

    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: XLabel('Nutrition')), Text('${n.i('count')} meals logged', style: XT.small(context))]),
        gap12,
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(fmtN(e.i('kcal')), style: XT.metric(context, 32)),
          const SizedBox(width: 6),
          Text('/ ${fmtN(t.i('kcal'))} kcal', style: XT.small(context)),
        ]),
        gap12,
        macro('Protein', 'protein'),
        macro('Carbs', 'carbs'),
        macro('Fat', 'fat'),
        if (n.l('meals').isNotEmpty)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Column(children: [
              for (final m in n.l('meals'))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.h3(context).copyWith(fontSize: 14)),
                        Text('${m.s('slot')} · ${m.s('time')}', style: XT.small(context).copyWith(fontSize: 12)),
                      ]),
                    ),
                    Text('${m.i('kcal')} kcal · ${m.i('protein')} g', style: XT.small(context)),
                    XIconBtn(Icons.close_rounded, tooltip: 'Remove ${m.s('name')}', onTap: () async {
                      final r = await attempt(context, () => Api.i.delete('meals/${m.i('id')}/'));
                      if (r != null && mounted) {
                        context.say('Meal removed');
                        context.app.changed();
                      }
                    }),
                  ]),
                ),
            ]),
          ),
        gap12,
        XKicker(exhaust ? 'Exhaust Mode · one tap is enough' : 'One-tap meals', dot: exhaust, color: exhaust ? c.ink : null),
        gap8,
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
            for (final q in n.l('quick')) ...[
              XChip(q.s('name'), on: false, onTap: () => _post('meals/', {'source': 'saved', 'food_id': q.i('id')})),
              const SizedBox(width: 8),
            ],
          ]),
        ),
        gap12,
        Text(n.s('line'), style: XT.small(context)),
        gap8,
        Text(n.s('left_line'), style: XT.small(context, color: c.ink)),
        gap12,
        Wrap(spacing: 8, runSpacing: 8, children: [
          XButton('Scan a plate', icon: Icons.document_scanner_outlined, small: true, expand: false, kind: XBtn.secondary, onTap: () => Go.scan(context)),
          XButton('Log manually', small: true, expand: false, kind: XBtn.secondary, onTap: () => showManualMealSheet(context)),
          XButton('What is left', small: true, expand: false, kind: XBtn.secondary, onTap: () => Go.meal(context, tab: 2)),
        ]),
      ]),
    );
  }

  Widget _preplan(Json p) => XCard(
        onTap: () => Go.preplan(context),
        child: Row(children: [
          const Icon(Icons.event_outlined, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.b('saved') ? '${p.s('occasion')} at ${p.s('hour')} · plan saved' : 'Eating out later?', style: XT.h3(context).copyWith(fontSize: 15)),
              const SizedBox(height: 2),
              Text('Pre-plan it: front-load protein, keep carbs for the event', style: XT.small(context)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: context.c.muted),
        ]),
      );

  Widget _heart(Json h) {
    return XCard(
      onTap: () => Go.recovery(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: XLabel('Heart rate · ${h.s('when')}${h.b('is_sample') ? ' · sample' : ''}')),
          Icon(Icons.chevron_right_rounded, size: 18, color: context.c.muted),
        ]),
        gap8,
        Text(h.s('title'), style: XT.h3(context)),
        gap12,
        HrChart(hr: [for (final v in (h['hr'] as List? ?? const [])) v as num], maxHr: h.i('max_hr', 190)),
        gap12,
        Text(h.s('advice'), style: XT.body(context)),
      ]),
    );
  }

  Widget _fuel(Json f) {
    final c = context.c;
    return XCard(
      onTap: () => Go.fuel(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: XKicker(f.s('kicker'))), Icon(Icons.chevron_right_rounded, size: 18, color: c.muted)]),
        gap8,
        Text('${f.s('title')} · ${f.s('when').split(' · ').first}', style: XT.h3(context)),
        gap4,
        Text('${f.s('club')} · ${f.b('added') ? 'Fuel plan added to your days' : 'Fuel plan ready'}', style: XT.small(context)),
        gap8,
        for (final s in f.l('summary'))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Row(children: [
              Expanded(child: Text(s.s('label'), style: XT.small(context, color: c.ink))),
              Text(s.s('value'), style: XT.small(context)),
            ]),
          ),
      ]),
    );
  }
}
