import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import '../social/share_sheet.dart';

/// Streak: workout + diet + recovery, rest-day passes, bonus days, squad.
class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('streak/') as Map),
        builder: (context, d, reload) {
          final st = d.m('state');
          final squad = d.l('squad');
          final top = squad.fold<int>(1, (a, s) => s.i('days') > a ? s.i('days') : a);
          return Column(children: [
            XTopBar('Streak', actions: [
              XIconBtn(Icons.ios_share_rounded, tooltip: 'Share streak',
                  onTap: () => showShareSheet(context, kicker: 'STREAK', title: '${d.i('days')}-day streak', sub: 'Workout, diet and recovery, every day', label: 'your streak')),
            ]),
            Expanded(
              child: XPage(children: [
                Text('${d.i('days')}', style: XT.hero(context).copyWith(fontSize: 120)),
                Text('Day streak', style: XT.h2(context)),
                gap4,
                const XLabel('Workout + diet + recovery'),
                gap16,
                Row(children: [
                  for (final w in d.l('week'))
                    Expanded(
                      child: Column(children: [
                        Text(w.s('label').toUpperCase(), style: XT.label(context).copyWith(fontSize: 10)),
                        gap8,
                        _day(context, w.s('status')),
                      ]),
                    ),
                ]),
                gap16,
                XGrid(cols: 2, children: [
                  XStatBox('Best streak', '${d.i('best')} days'),
                  XStatBox('Today', d.s('today')),
                  XStatBox('Rest-day passes', '${d.i('passes_left')} of ${d.i('passes_month')} left'),
                  XStatBox('Bonus from challenges', '+${d.i('bonus')} days'),
                ]),
                if (!st.b('counts')) ...[
                  gap16,
                  if (!st.b('wo')) ...[XButton("Finish today's workout", onTap: () => Go.session(context, d.i('weekday'))), gap8],
                  if (!st.b('diet')) ...[XButton('${st.i('protein_need')} g protein to go', kind: XBtn.secondary, onTap: () => Go.meal(context, tab: 2)), gap8],
                  if (!st.b('rec')) ...[XButton('Do the recovery session', kind: XBtn.secondary, onTap: () => Go.recoverySession(context)), gap8],
                  if (d.i('passes_left') > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: XLink('Use a rest-day pass for today', underline: true, onTap: () async {
                        final ok = await confirmX(context, title: 'Use a rest-day pass?', body: 'Today counts without the workout, diet and recovery. You have ${d.i('passes_left')} left this month.', ok: 'Use pass');
                        if (!ok || !context.mounted) return;
                        final r = await attempt(context, () => Api.i.post('streak/pass/'));
                        if (r != null && context.mounted) {
                          context.say('${(r as Map)['message']}');
                          context.app.changed();
                        }
                      }),
                    ),
                ],
                gap12,
                Text('A day counts when you finish your workout, hit your diet and do the recovery session. Planned rest days count with recovery and diet. '
                    'Miss a day and a rest-day pass covers it, ${d.i('passes_month')} a month.', style: XT.small(context)),
                gap24,
                const XLabel('Squad streaks'),
                gap12,
                for (final s in squad)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      SizedBox(
                        width: 96,
                        child: Text(s.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: XT.small(context, color: c.ink).copyWith(fontWeight: s.b('me') ? FontWeight.w600 : FontWeight.w500)),
                      ),
                      Expanded(child: XBar(s.i('days') / top, color: s.b('me') ? c.orange : c.ink)),
                      SizedBox(width: 40, child: Text('${s.i('days')}d', textAlign: TextAlign.right, style: XT.small(context))),
                    ]),
                  ),
                gap16,
                const XLabel('Last 14 days'),
                gap12,
                XGrid(cols: 7, gap: 6, children: [
                  for (final h in d.l('history'))
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: switch (h.s('status')) { 'done' => c.ink, 'partial' => c.faint, 'today' => c.surface, _ => c.gray },
                        borderRadius: BorderRadius.circular(8),
                        border: h.s('status') == 'today' ? Border.all(color: c.orange, width: 1.5) : null,
                      ),
                    ),
                ]),
                gap12,
                Wrap(spacing: 14, runSpacing: 8, children: [
                  _legend(context, c.ink, 'All done'),
                  _legend(context, c.faint, 'Partial'),
                  _legend(context, c.gray, 'Rest'),
                  _legend(context, c.surface, 'Today', border: c.orange),
                ]),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _day(BuildContext context, String status) {
    final c = context.c;
    final (bg, fg, bd, mark) = switch (status) {
      'done' => (c.ink, c.onInk, c.ink, '✓'),
      'partial' => (c.gray, c.ink, c.line, '½'),
      'rest' => (c.gray, c.muted, c.line, ''),
      'today' => (c.surface, c.orange, c.orange, '•'),
      _ => (c.surface, c.muted, c.line, ''),
    };
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: bd, width: 1.5)),
      child: Text(mark, style: XT.h3(context, color: fg)),
    );
  }

  Widget _legend(BuildContext context, Color col, String l, {Color? border}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3), border: Border.all(color: border ?? context.c.line))),
        const SizedBox(width: 6),
        Text(l, style: XT.small(context)),
      ]);
}
