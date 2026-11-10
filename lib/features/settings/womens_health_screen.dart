import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Opt-in women's health support: life stage, cycle phase, energy, symptoms, a health rest day that
/// excuses the workout part of the streak, and six daily habits. Female profiles only; nothing is shared.
class WomensHealthScreen extends StatefulWidget {
  const WomensHealthScreen({super.key});
  @override
  State<WomensHealthScreen> createState() => _WomensHealthScreenState();
}

class _WomensHealthScreenState extends State<WomensHealthScreen> {
  Json? _d;
  String _err = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('women/');
      if (mounted) setState(() => _d = Map<String, dynamic>.from(r as Map));
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  Future<void> _post(String path, Json body) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await attempt(context, () => Api.i.post(path, body));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) return;
    final m = Map<String, dynamic>.from(r as Map);
    setState(() => _d = m);
    if (m.s('message').isNotEmpty) context.say(m.s('message'));
    context.app.changed();
  }

  Json get _today => _d!.m('today');
  Json get _opts => _d!.m('options');

  Widget _chips(List<Json> opts, String current, ValueChanged<String> pick) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts) XChip(o.s('label'), on: current == o.s('key'), onTap: () => pick(current == o.s('key') ? '' : o.s('key'))),
      ]);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Column(children: [
        const XTopBar("Women's health"),
        Expanded(
          child: _d == null
              ? (_err.isNotEmpty ? XError(_err, onRetry: () => setState(() {
                    _err = '';
                    _load();
                  })) : const Padding(padding: EdgeInsets.all(XS.gutter), child: XSkeleton()))
              : ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 32), children: _body(c)),
        ),
      ]),
    );
  }

  List<Widget> _body(XC c) {
    final d = _d!;
    final on = d.b('enabled');
    final stage = d.s('stage', 'unsure');
    final habitsDone = _today.strs('habits');
    final total = d.i('habits_total', 6);
    return [
      XCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const XKicker('Personal wellness support'),
          gap8,
          Text('Train with your body, not against it.', style: XT.h2(context)),
          gap8,
          Text('Optional, private support for your cycle, perimenopause or menopause, energy and recovery. '
              'Nothing here is shared or shown on your profile.', style: XT.small(context)),
          gap16,
          XButton(on ? "Pause women's health support" : "Turn on women's health support",
              kind: on ? XBtn.secondary : XBtn.primary, loading: _busy, onTap: () => _post('women/', {'enabled': !on})),
        ]),
      ),
      if (on) ...[
        gap20,
        const XLabel('Your life stage'),
        gap8,
        _chips(_opts.l('stages'), stage, (v) => _post('women/', {'stage': v.isEmpty ? 'unsure' : v})),
        if (stage == 'cycle') ...[
          gap20,
          const XLabel('Cycle phase today · optional'),
          gap8,
          _chips(_opts.l('phases'), _today.s('phase'), (v) => _post('women/day/', {'phase': v})),
          gap8,
          Text('Cycles vary from person to person and month to month. This is your own check-in, not a prediction.',
              style: XT.small(context)),
        ],
        gap20,
        const XLabel('Energy today'),
        gap8,
        _chips(_opts.l('energy'), _today.s('energy'), (v) => _post('women/day/', {'energy': v})),
        gap20,
        const XLabel('Symptoms today · pick any'),
        gap8,
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in _opts.strs('symptoms'))
            XChip(s, on: _today.strs('symptoms').contains(s), check: true, onTap: () {
              final l = List<String>.from(_today.strs('symptoms'));
              l.contains(s) ? l.remove(s) : l.add(s);
              _post('women/day/', {'symptoms': l});
            }),
        ]),
        gap20,
        XCard(
          muted: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const XLabel('A health rest day'),
            gap8,
            Text('Your workout can wait today.', style: XT.h3(context)),
            gap4,
            Text('If you feel weak, dizzy, unusually tired or uncomfortable, skip training. A health rest day keeps your streak: '
                'the workout part is excused, and diet and recovery still count.', style: XT.small(context)),
            gap12,
            XButton(_today.b('rest_day') ? 'Health rest day is on · undo' : 'Take a health rest day today',
                kind: _today.b('rest_day') ? XBtn.secondary : XBtn.primary,
                icon: _today.b('rest_day') ? Icons.check_rounded : null,
                onTap: () => _post('women/day/', {'rest_day': !_today.b('rest_day')})),
          ]),
        ),
        gap20,
        XCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: XLabel('Daily habits')),
              Text('${habitsDone.length} / $total', style: XT.h3(context)),
            ]),
            gap8,
            XBar(habitsDone.length / total, color: c.orange),
            gap8,
            Text(d.b('pcos_support')
                ? 'Steady meals, protein, fibre, sleep and movement are the habits most linked with PCOS/PCOD symptoms. Pick what feels manageable.'
                : 'Even on rest days, keep looking after yourself. These are gentle habits, not pass or fail.',
                style: XT.small(context)),
            gap8,
            for (final h in _opts.l('habits'))
              XRow(h.s('label'),
                  leading: XCheck(done: habitsDone.contains(h.s('key'))),
                  trailing: Text(habitsDone.contains(h.s('key')) ? 'Done' : 'Mark done', style: XT.small(context)),
                  onTap: () {
                    final l = List<String>.from(habitsDone);
                    l.contains(h.s('key')) ? l.remove(h.s('key')) : l.add(h.s('key'));
                    _post('women/day/', {'habits': l});
                  }),
          ]),
        ),
        gap20,
        XCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const XLabel('Last 7 days'),
            gap12,
            SizedBox(
              height: 92,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final w in d.l('week'))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Container(
                          height: 60 * (w.i('habits') / total).clamp(.06, 1.0),
                          decoration: BoxDecoration(
                            color: w.b('today') ? c.orange : c.ink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(w.s('day'), style: XT.small(context, color: w.b('today') ? c.ink : null).copyWith(fontSize: 12)),
                        if (w.b('rest')) const XDot(size: 5) else const SizedBox(height: 5),
                      ]),
                    ),
                  ),
              ]),
            ),
            gap8,
            Text('Bars show how many of the six habits you checked each day. A dot marks a health rest day.', style: XT.small(context)),
          ]),
        ),
        gap20,
        XRow('PCOS / PCOD habit support', sub: 'Shows habit guidance for PCOS or PCOD',
            trailing: XSwitch(value: d.b('pcos_support'), onChanged: (v) => _post('women/', {'pcos_support': v}))),
        gap16,
        Text('Exerlio offers habit awareness only. It does not diagnose or treat anything. Severe pain, very heavy bleeding, '
            'fainting or symptoms that worry you need a doctor.', style: XT.small(context)),
      ],
    ];
  }
}
