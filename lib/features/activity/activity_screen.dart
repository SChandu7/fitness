import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import '../social/share_sheet.dart';

/// One saved activity: route coloured by pace or heart rate, vitals, splits.
class ActivityScreen extends StatefulWidget {
  final int id;
  const ActivityScreen({super.key, required this.id});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _by = 0; // route, pace, heart rate

  List<double>? _colors(List<List<double>> pts, Json a) {
    if (_by == 0 || pts.length < 2) return null;
    if (_by == 2) {
      final hr = [for (final v in (a['hr'] as List? ?? const [])) (v as num).toDouble()];
      if (hr.isEmpty) return null;
      final mx = a.i('max_hr', 190);
      return [for (var i = 0; i < pts.length; i++) ((hr[(i / pts.length * hr.length).floor().clamp(0, hr.length - 1)] / mx - .6) / .35).clamp(0.0, 1.0)];
    }
    final splits = a.l('splits');
    if (splits.isEmpty) return null;
    final paces = [for (final s in splits) s.d('sec') / math.max(.05, s.b('partial') ? (a.d('distance_km') % 1) : 1)];
    final lo = paces.reduce(math.min), hi = paces.reduce(math.max);
    return [
      for (var i = 0; i < pts.length; i++)
        () {
          final p = paces[(i / pts.length * paces.length).floor().clamp(0, paces.length - 1)];
          return hi - lo < 1 ? .5 : 1 - (p - lo) / (hi - lo); // faster = higher
        }()
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('activities/${widget.id}/') as Map),
        builder: (context, a, reload) {
          final pts = RouteMap.parse(a['points']);
          final gps = pts.length > 2;
          final hr = [for (final v in (a['hr'] as List? ?? const [])) v as num];
          final spo2 = [for (final v in (a['spo2'] as List? ?? const [])) v as num];
          final splits = a.l('splits');
          final hyrox = a.l('hyrox');
          final cycle = a.s('sport') == 'cycle';
          final units = context.app.units;
          final best = splits.isEmpty ? 0.0 : splits.map((s) => s.d('sec')).reduce(math.min);
          return Column(children: [
            XTopBar(a.s('sport_label'), actions: [
              XIconBtn(Icons.ios_share_rounded, tooltip: 'Share activity', onTap: () => showShareSheet(context,
                  kicker: a.s('sport_label').toUpperCase(), title: a.s('title'), sub: a.s('line'))),
            ]),
            Expanded(
              child: ListView(padding: const EdgeInsets.only(top: 4, bottom: 32), children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    XKicker('${a.s('sport_label')} · ${a.s('when')}'),
                    gap8,
                    Text(a.s('title'), style: XT.h1(context)),
                    if (a.b('is_sample')) ...[gap4, Text('Sample data · demo route and vitals', style: XT.small(context))],
                  ]),
                ),
                if (gps) ...[
                  gap16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(XS.r3),
                        child: RouteMap(points: pts, height: 250, colors: _colors(pts, a), kmMarks: true, distanceKm: a.d('distance_km')),
                      ),
                      gap12,
                      Row(children: [
                        Text('Colour by', style: XT.small(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: XSegment(
                            height: 32,
                            labels: ['Route', cycle ? 'Speed' : 'Pace', 'Heart rate'],
                            index: _by,
                            onPick: (i) {
                              if (i == 2 && hr.isEmpty) {
                                context.say('No heart rate on this activity. Connect a watch to record it.');
                                return;
                              }
                              setState(() => _by = i);
                            },
                          ),
                        ),
                      ]),
                      gap8,
                      Wrap(spacing: 14, runSpacing: 6, children: _by == 0
                          ? [_legend(Icons.circle, 'Start'), _legend(Icons.square, 'Finish')]
                          : [
                              _bar(c.faint, _by == 2 ? 'Easy' : 'Slower'),
                              _bar(c.ink, 'Steady'),
                              _bar(c.orange, _by == 2 ? 'Hard' : 'Faster'),
                            ]),
                    ]),
                  ),
                ],
                gap16,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                  child: XGrid(cols: 2, children: [for (final s in a.l('stats')) XStatBox(s.s('label'), s.s('value'))]),
                ),
                if (hr.length > 3) ...[
                  gap16,
                  _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Expanded(child: XLabel('Heart rate')), Text('avg ${a.i('hr_avg')} · max ${a.i('hr_max')} bpm', style: XT.small(context))]),
                    gap12,
                    XLineChart(hr, min: 80, max: a.i('max_hr', 190) + 4.0, threshold: a.i('max_hr', 190) * .9, thresholdLabel: '90% of max',
                        semantics: 'Heart rate over the activity'),
                    gap12,
                    ZoneRow([for (final z in (a['zones'] as List? ?? const [])) (z as num).toInt()]),
                  ])),
                ] else if (!a.b('is_sample')) ...[
                  gap16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: const XNote(text: 'No heart rate on this session. Connect Apple Health or Health Connect in Settings and your watch data is added after each session.'),
                  ),
                ],
                if (spo2.length > 3) ...[
                  gap16,
                  _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Expanded(child: XLabel('Blood oxygen · SpO₂')), Text('lowest ${spo2.reduce(math.min)}%', style: XT.small(context))]),
                    gap12,
                    XLineChart(spo2, min: 88, max: 100, threshold: 92, thresholdLabel: '92%', semantics: 'SpO2 over the activity'),
                    gap8,
                    Text(spo2.reduce(math.min) < 92
                        ? 'Dipped below 92% during the hardest efforts. If you felt dizzy or breathless, ease off and get it checked.'
                        : 'Stayed above 92% the whole session. Normal during exercise.', style: XT.small(context)),
                  ])),
                ],
                if (splits.length > 1) ...[
                  gap16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: Column(children: [
                      Row(children: [const Expanded(child: XLabel('Splits')), Text(cycle ? 'speed per km' : 'pace per km', style: XT.small(context))]),
                      gap8,
                      for (final s in splits)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                          child: Row(children: [
                            SizedBox(width: 40, child: Text('${s.i('km')}${s.b('partial') ? '*' : ''}', style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600))),
                            Container(
                              width: s.d('sec') > 0 ? (best / s.d('sec') * 110) : 0,
                              height: 6,
                              decoration: BoxDecoration(color: s.d('sec') == best ? c.orange : c.ink, borderRadius: BorderRadius.circular(3)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(cycle ? '${(3600 / math.max(1, s.d('sec'))).toStringAsFixed(1)} km/h' : units.pace(s.d('sec')),
                                  style: XT.small(context, color: c.ink)),
                            ),
                            if (s.i('hr') > 0) Text('${s.i('hr')} bpm', style: XT.small(context)),
                          ]),
                        ),
                    ]),
                  ),
                ],
                if (hyrox.isNotEmpty) ...[
                  gap16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: Column(children: [
                      Row(children: [const Expanded(child: XLabel('Splits · 8 runs + 8 stations')), Text('${hyrox.length} of 16', style: XT.small(context))]),
                      gap8,
                      for (final s in hyrox)
                        XRow('${s.s('label')} · ${s.s('dist')}', trailing: Text(fmtT(s.d('sec')), style: XT.small(context, color: c.ink))),
                    ]),
                  ),
                ],
                if (a.l('sets').isNotEmpty) ...[
                  gap16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      XLabel('Sets · ${a.l('sets').length}'),
                      gap8,
                      for (final s in a.l('sets'))
                        XRow(s.s('n'), trailing: Text('${s.d('kg') > 0 ? '${fmt1(s.d('kg'))} kg × ' : ''}${s.i('reps')}', style: XT.small(context, color: c.ink))),
                    ]),
                  ),
                ],
                if (a.l('struggles').isNotEmpty) ...[
                  gap16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const XLabel('Where you struggled'),
                      gap8,
                      for (final s in a.l('struggles'))
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${s.s('label')} · min ${s.i('min')} · ${s.i('hr')} bpm', style: XT.h3(context).copyWith(fontSize: 15)),
                            gap4,
                            Text(s.s('advice'), style: XT.small(context)),
                          ]),
                        ),
                    ]),
                  ),
                ],
                if (gps) ...[
                  gap16,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: XButton('See all your routes', icon: Icons.place_outlined, kind: XBtn.secondary, onTap: () => Go.routes(context)),
                  ),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _card(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: XS.gutter), child: XCard(child: child));

  Widget _legend(IconData i, String l) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 10, color: context.c.ink),
        const SizedBox(width: 6),
        Text(l, style: XT.small(context)),
      ]);

  Widget _bar(Color col, String l) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 4, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(l, style: XT.small(context)),
      ]);
}
