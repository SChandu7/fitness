import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import '../shared/body_cards.dart';
import 'day_sheet.dart';
import 'exhaust_card.dart';
import 'injury_sheet.dart';

/// Train → Plan: the week, swaps, muscle coverage, strains, library.
class PlanTab extends StatefulWidget {
  const PlanTab({super.key});
  @override
  State<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<PlanTab> {
  int? _picked; // week-card rearranging

  Future<void> _schedule(Json body) async {
    final r = await attempt(context, () => Api.i.post('schedule/', body));
    if (r != null && mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<Json>(
      load: () async => Map<String, dynamic>.from(await Api.i.get('train/plan/') as Map),
      builder: (context, d, reload) {
        final week = d.l('week');
        return XPage(padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 40), children: [
          const XLabel('This week'),
          gap8,
          Text('${d.i('n_workouts')} workouts, ${d.i('rest_days')} rest day${d.i('rest_days') == 1 ? '' : 's'}', style: XT.h1(context)),
          gap4,
          Text('Tap a day to swap its cut with another day or change it.', style: XT.small(context)),
          gap16,
          if (d.l('health_notes').isNotEmpty) ...[HealthPlanCard(d.l('health_notes')), gap16],
          _strip(week),
          gap16,
          Row(children: [const Expanded(child: XLabel('Workout days per week')), Text('${d.i('rest_days')} rest', style: XT.small(context))]),
          gap8,
          XSegment(
            ink: true,
            labels: const ['3', '4', '5', '6', '7'],
            index: (d.i('n_workouts') - 3).clamp(0, 4),
            onPick: (i) async {
              if (i + 3 == d.i('n_workouts')) return;
              final ok = await confirmX(context,
                  title: 'Switch to ${i + 3} workout days?', body: 'Your week resets to the standard ${i + 3}-day plan. You can swap days after.', ok: 'Switch');
              if (ok) _schedule({'action': 'template', 'days': i + 3});
            },
          ),
          if (d.i('n_workouts') == 7) ...[gap8, Text('Day 7 is easy mobility, so your body still gets a recovery day.', style: XT.small(context))],
          gap16,
          _today(d.m('today')),
          gap24,
          _cards(week),
          gap16,
          const ExhaustCard(full: true),
          gap16,
          _coverage(d),
          gap16,
          _injuries(d),
          gap24,
          _library(d.l('library')),
          gap16,
          const XNote(label: 'Why rest days are in your week',
              text: 'Muscle repairs and gets stronger on rest days, not during the workout. On a rest day your streak counts with the recovery session and your diet.'),
        ]);
      },
    );
  }

  Widget _strip(List<Json> week) {
    final c = context.c;
    return Row(children: [
      for (final w in week)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              button: true,
              label: '${w.s('day')}: ${w.s('label')}${w.b('done') ? ', done' : ''}',
              child: Press(
                onTap: () => showDaySheet(context, w.i('i')),
                child: Container(
                  height: 78,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                  decoration: BoxDecoration(
                    color: w.b('rest') ? c.gray : c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: w.b('today') ? c.ink : c.line, width: w.b('today') ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(w.s('day').toUpperCase(), style: XT.label(context, color: w.b('today') ? c.ink : null).copyWith(fontSize: 10)),
                    FittedBox(child: Text(w.s('short'), style: XT.small(context, color: w.b('rest') ? c.muted : c.ink).copyWith(fontWeight: FontWeight.w500, fontSize: 11.5))),
                    w.b('done')
                        ? Icon(Icons.check_rounded, size: 14, color: c.ink)
                        : (w.b('today') && !w.b('rest') ? const XDot(size: 6) : const SizedBox(height: 14)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _today(Json t) {
    final rest = t.s('key') == 'rest';
    final ex = t.l('ex');
    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: XKicker('Today · ${t.s('day')}')),
          if (t.b('exhaust')) Text('Exhaust Mode', style: XT.small(context, color: context.c.ink)),
        ]),
        gap12,
        if (rest) ...[
          Text('Rest day', style: XT.h2(context)),
          gap4,
          Text('Your streak counts today when you do the recovery session and hit your diet. Sleep, walk, eat well.', style: XT.small(context)),
          gap16,
          XButton(t.b('rec_done') ? 'Recovery done' : 'Start recovery session',
              icon: t.b('rec_done') ? Icons.check_rounded : null, kind: t.b('rec_done') ? XBtn.secondary : XBtn.primary,
              onTap: () => Go.recoverySession(context)),
        ] else ...[
          Text(t.s('label'), style: XT.h2(context)),
          gap4,
          Text('${t.i('mins')} min · ${ex.where((e) => !e.b('skip')).length} exercises${t.b('done') ? ' · done' : ''}', style: XT.small(context)),
          gap8,
          for (final e in ex.take(4)) ExerciseRow(e),
          gap12,
          Row(children: [
            Expanded(child: XButton('Swap today', icon: Icons.swap_horiz_rounded, kind: XBtn.secondary, onTap: () => showDaySheet(context, t.i('weekday')))),
            const SizedBox(width: 8),
            Expanded(child: XButton('Open session', onTap: () => Go.session(context, t.i('weekday')))),
          ]),
        ],
      ]),
    );
  }

  Widget _cards(List<Json> week) {
    final c = context.c;
    final rest = week.where((w) => w.b('rest')).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: XLabel('Your week as cards')), Text('${7 - rest} workout · $rest rest', style: XT.small(context))]),
      gap8,
      Text(_picked != null
          ? 'Now tap the day to swap with ${week[_picked!].s('day')} (${week[_picked!].s('label').toLowerCase()}).'
          : 'Tap a card, then tap another day to swap them. Arrows move a card one day. Tap the pencil to change what a day trains.',
          style: XT.small(context)),
      gap12,
      for (final w in week) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Press(
              onTap: () {
                final i = w.i('i');
                if (_picked == null) return setState(() => _picked = i);
                if (_picked == i) return setState(() => _picked = null);
                final j = _picked!;
                setState(() => _picked = null);
                _schedule({'action': 'swap', 'i': i, 'j': j});
              },
              child: AnimatedContainer(
                duration: context.anim(XS.fast),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _picked == w.i('i') ? c.ink : (w.b('rest') ? c.gray : c.surface),
                  borderRadius: BorderRadius.circular(XS.r3),
                  border: Border.all(
                      color: _picked == w.i('i') || w.b('today') ? c.ink : c.line,
                      width: _picked == w.i('i') ? 2 : (w.b('today') ? 1.5 : 1)),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 40,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.s('day').toUpperCase(),
                          style: XT.label(context, color: _picked == w.i('i') ? c.onInk : null).copyWith(fontWeight: FontWeight.w600)),
                      if (w.b('today')) ...[const SizedBox(height: 4), const XDot(size: 6)],
                    ]),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.s('label'), style: XT.h3(context, color: _picked == w.i('i') ? c.onInk : c.ink).copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(w.s('sub'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: XT.small(context, color: _picked == w.i('i') ? c.onInk.withValues(alpha: .72) : c.muted).copyWith(fontSize: 12)),
                    ]),
                  ),
                  if (w.b('done')) Icon(Icons.check_rounded, size: 16, color: _picked == w.i('i') ? c.onInk : c.ink),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Column(children: [
            _mini(Icons.keyboard_arrow_up_rounded, 'Move ${w.s('day')} up', w.i('i') == 0 ? null : () => _schedule({'action': 'swap', 'i': w.i('i'), 'j': w.i('i') - 1})),
            _mini(Icons.edit_outlined, 'Change ${w.s('day')}', () => showDaySheet(context, w.i('i'))),
            _mini(Icons.keyboard_arrow_down_rounded, 'Move ${w.s('day')} down', w.i('i') == 6 ? null : () => _schedule({'action': 'swap', 'i': w.i('i'), 'j': w.i('i') + 1})),
          ]),
        ]),
        gap8,
      ],
    ]);
  }

  Widget _mini(IconData i, String label, VoidCallback? onTap) => Semantics(
        button: true,
        label: label,
        child: Press(
          onTap: onTap,
          child: SizedBox(width: 34, height: 26, child: Icon(i, size: 18, color: onTap == null ? context.c.gray2 : context.c.ink)),
        ),
      );

  Widget _coverage(Json d) {
    final missing = d.strs('missing');
    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: XLabel('Muscles this week')), Text('${d.i('covered')} of ${d.i('groups_total')} covered', style: XT.small(context))]),
        gap12,
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final g in d.l('coverage')) XChip(g.i('n') > 0 ? '${g.s('group')} · ${g.i('n')}×' : g.s('group'), on: false, dashed: g.i('n') == 0),
        ]),
        gap12,
        Text(missing.isEmpty
            ? 'Every major group is covered. Swap days freely, the week stays balanced.'
            : '${missing.join(', ')} ${missing.length > 1 ? 'are' : 'is'} not in this week. Change a cut so nothing gets skipped.',
            style: XT.small(context, color: missing.isEmpty ? null : context.c.ink)),
      ]),
    );
  }

  Widget _injuries(Json d) {
    final list = d.l('injuries');
    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: XLabel('Strains and sprains')),
          if (list.isNotEmpty) Text('${d.i('adapted')} exercise${d.i('adapted') == 1 ? '' : 's'} adapted', style: XT.small(context)),
        ]),
        gap8,
        if (list.isEmpty) Text('Tell Exerlio about a strain or sprain and every session swaps out the moves that load it.', style: XT.small(context)),
        for (final j in list)
          XRow(
            '${j.s('area_label')}${j.s('side').isNotEmpty ? ' · ${j.s('side')}' : ''}',
            sub: '${j.s('level_label')}${j.s('note').isNotEmpty ? ' · ${j.s('note')}' : ''}',
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: context.c.gray, shape: BoxShape.circle),
              child: const Icon(Icons.bolt_rounded, size: 18),
            ),
            trailing: XButton('Healed', small: true, expand: false, kind: XBtn.secondary, onTap: () async {
              final r = await attempt(context, () => Api.i.post('injuries/${j.i('id')}/heal/'));
              if (r != null && mounted) {
                context.say('${(r as Map)['message']}');
                context.app.changed();
              }
            }),
          ),
        gap8,
        XButton('Add a strain or sprain', icon: Icons.add_rounded, small: true, expand: false, kind: XBtn.secondary, onTap: () => showInjurySheet(context)),
        gap8,
        Text('Sharp pain, swelling, numbness or pain at rest: stop and see a doctor or physio.', style: XT.small(context)),
      ]),
    );
  }

  Widget _library(List<Json> list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const XLabel('Workout library'),
        gap4,
        for (final w in list)
          XRow(
            w.s('title'),
            sub: '${w.s('label')} · ${w.i('mins')} min · ${w.i('kcal')} kcal',
            onTap: () => Go.library(context, w.s('key')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              XButton('View', small: true, expand: false, kind: XBtn.secondary, onTap: () => Go.library(context, w.s('key'))),
              const SizedBox(width: 6),
              XButton('Start', small: true, expand: false, onTap: () async {
                final r = await attempt(context, () => Api.i.get('library/${w.s('key')}/'));
                if (r != null && mounted) Go.startLibrary(context, Map<String, dynamic>.from(r as Map));
              }),
            ]),
          ),
      ]);
}

/// One exercise line: name, sets × reps, why it was adapted.
class ExerciseRow extends StatelessWidget {
  final Json e;
  const ExerciseRow(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final skip = e.b('skip');
    return Opacity(
      opacity: skip ? .55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.s('name'), style: XT.h3(context).copyWith(fontSize: 15, decoration: skip ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Text.rich(TextSpan(children: [
                TextSpan(text: e.s('detail')),
                if (e.d('load_kg') > 0 && !skip) TextSpan(text: ' · ${e.d('load_kg') % 1 == 0 ? e.d('load_kg').toInt() : e.d('load_kg')} kg'),
                if (e.s('why').isNotEmpty) TextSpan(text: ' · ${e.s('why')}', style: TextStyle(color: c.ink)),
              ]), style: XT.small(context)),
            ]),
          ),
          if (e.b('adapted')) const XDot(),
        ]),
      ),
    );
  }
}
