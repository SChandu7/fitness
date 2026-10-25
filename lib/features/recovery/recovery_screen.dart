import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../settings/devices_screen.dart';
import '../social/share_sheet.dart';
import 'checkin_sheet.dart';

/// Recovery: score, vitals, the last session's heart rate, muscle readiness, spike guidance.
class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('recovery/') as Map),
        builder: (context, r, reload) {
          final ses = r.m('session');
          final exhaust = r.b('exhaust');
          return Column(children: [
            XTopBar('Recovery', actions: [
              if (r.b('available'))
                XIconBtn(Icons.ios_share_rounded, tooltip: 'Share', onTap: () => showShareSheet(context, kicker: 'RECOVERY', title: '${r.i('score')} / 100', sub: r.s('label'))),
            ]),
            Expanded(
              child: XPage(children: [
                if (r.b('available')) ...[
                  XKicker(r.b('is_sample') ? 'Recovery rate · sample data' : 'Recovery rate · today'),
                  gap8,
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('${r.i('score')}', style: XT.hero(context).copyWith(fontSize: 112)),
                    const SizedBox(width: 8),
                    Text('/ 100', style: XT.small(context)),
                  ]),
                  gap8,
                  XBar(r.i('score') / 100, color: c.orange),
                  gap12,
                  Text(r.s('note'), style: XT.body(context)),
                  if (r.b('is_sample')) ...[gap8, Text('Sample values until you connect a device.', style: XT.small(context))],
                  gap16,
                  XGrid(cols: 2, children: [for (final s in r.l('stats')) XStatBox(s.s('label'), s.s('value'), sub: s.s('sub'))]),
                ] else ...[
                  Text(r.s('title', 'How are you today?'), style: XT.h1(context)),
                  gap8,
                  Text(r.s('note'), style: XT.body(context, color: c.muted)),
                  gap16,
                  XButton('Check in · 3 taps', onTap: () => showCheckinSheet(context)),
                  gap8,
                  XButton('Connect a watch', kind: XBtn.secondary, onTap: () => context.push(const DevicesScreen())),
                ],
                if (ses.isNotEmpty) ...[
                  gap16,
                  XCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      XLabel('Heart rate · ${ses.s('label')}${ses.b('is_sample') ? ' · sample' : ''}'),
                      gap8,
                      Text(ses.l('struggles').isEmpty
                          ? 'No moments above 92% of max'
                          : '${ses.l('struggles').length} moment${ses.l('struggles').length > 1 ? 's' : ''} pushed you past 92%', style: XT.h2(context)),
                      gap12,
                      HrChart(hr: [for (final v in (ses['hr'] as List? ?? const [])) v as num], maxHr: r.i('max_hr', 190), height: 150),
                      gap12,
                      ZoneRow([for (final z in (ses['zones'] as List? ?? const [])) (z as num).toInt()]),
                    ]),
                  ),
                  if (ses.l('struggles').isNotEmpty) ...[
                    gap16,
                    const XLabel('Where you struggled'),
                    gap8,
                    for (var i = 0; i < ses.l('struggles').length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: c.orange, shape: BoxShape.circle),
                            child: Text('${i + 1}', style: XT.small(context, color: const Color(0xFF000000)).copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${ses.l('struggles')[i].s('label')} · min ${ses.l('struggles')[i].i('min')} · ${ses.l('struggles')[i].i('hr')} bpm',
                                  style: XT.h3(context).copyWith(fontSize: 15)),
                              gap4,
                              Text(ses.l('struggles')[i].s('advice'), style: XT.small(context)),
                            ]),
                          ),
                        ]),
                      ),
                  ],
                ],
                gap16,
                XCard(
                  muted: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    XLabel('When your heart rate spikes', color: c.ink),
                    gap12,
                    for (final s in r.l('spike'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 74, child: Text(s.s('title'), style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600))),
                          Expanded(child: Text(s.s('text'), style: XT.small(context, color: c.ink))),
                        ]),
                      ),
                  ]),
                ),
                gap16,
                XCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Expanded(child: XLabel('Ready to load')), Text('48 h view', style: XT.small(context))]),
                    gap12,
                    for (final m in r.l('muscles')) ...[
                      Row(children: [
                        Expanded(child: Text(m.s('label'), style: XT.small(context, color: c.ink))),
                        Text('${m.i('pct')}%${m.s('full_by').isNotEmpty ? ' · full by ${m.s('full_by')}' : ''}', style: XT.small(context)),
                      ]),
                      const SizedBox(height: 6),
                      XBar(m.i('pct') / 100, color: goalColor(context, m.i('pct') / 100)),
                      gap12,
                    ],
                  ]),
                ),
                gap16,
                XCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.bedtime_outlined, size: 20), const SizedBox(width: 10), Expanded(child: Text('Why rest days count', style: XT.h3(context)))]),
                    gap8,
                    Text('Muscle and heart adapt while you rest, not while you train. Two hard days in a row on low recovery make the next session worse, not better. '
                        'Exhaust Mode keeps you moving without digging the hole deeper.', style: XT.small(context, color: c.ink)),
                    gap12,
                    XButton(exhaust ? 'Exhaust Mode is on · turn off' : 'Turn on Exhaust Mode for today', kind: exhaust ? XBtn.secondary : XBtn.primary,
                        onTap: () async {
                      final res = await attempt(context, () => Api.i.post('exhaust/', {'on': !exhaust}));
                      if (res != null && context.mounted) {
                        context.say('${(res as Map)['message']}');
                        await context.app.refreshMe();
                        if (context.mounted) context.app.changed();
                      }
                    }),
                  ]),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
