import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../shared/body_cards.dart';

/// Setup steps after the account exists (steps 2–15 of 15).
/// Used for first-time setup and for "Redo your setup" from Profile.
const _steps = ['goal', 'sports', 'exp', 'weight', 'height', 'body', 'food', 'health', 'meds', 'days', 'time', 'sleep', 'privacy', 'ready'];
const kSetupTotal = 15;

/// Back arrow, progress bar and "02 / 15".
class ObHeader extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  const ObHeader({super.key, required this.step, this.onBack});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        onBack == null ? const SizedBox(width: 44) : XIconBtn(Icons.chevron_left_rounded, tooltip: 'Back', onTap: onBack!),
        Expanded(child: XBar(step / kSetupTotal, height: 4, color: c.ink)),
        SizedBox(
          width: 60,
          child: Text('${step.toString().padLeft(2, '0')} / $kSetupTotal', textAlign: TextAlign.center, style: XT.small(context)),
        ),
      ]),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  final bool redo;
  const OnboardingScreen({super.key, this.redo = false});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _i = 0;
  String _err = '';
  bool _busy = false;
  Json? _preview;
  late Json d;
  final _other = TextEditingController();
  final _meds = TextEditingController();

  @override
  void initState() {
    super.initState();
    final me = context.app.me;
    d = {
      'goal': me.s('goal', 'active'),
      'sports': widget.redo ? me.strs('sports') : <String>[],
      'experience': me.s('experience', 'intermediate'),
      'weight_kg': me.d('weight_kg', 70),
      'height_cm': me.i('height_cm', 170),
      'age': me.i('age', 25),
      'sex': me.s('sex', 'na'),
      'allergies': me.strs('allergies'),
      'conditions': me.strs('conditions'),
      'days_per_week': me.i('days_per_week', 4).clamp(2, 6),
      'session_minutes': me.i('session_minutes', 45),
      'sleep': me.s('sleep', '78'),
      'is_private': me.b('is_private'),
    };
    _other.text = me.s('allergy_other');
    _meds.text = me.s('medications');
  }

  @override
  void dispose() {
    _other.dispose();
    _meds.dispose();
    super.dispose();
  }

  String get step => _steps[_i];
  Json get catalog => context.app.catalog;

  Json _payload() => {
        ...d,
        'weight_kg': (d['weight_kg'] as num).toStringAsFixed(1),
        'allergy_other': _other.text.trim(),
        'medications': _meds.text.trim(),
      };

  void _set(String k, Object v, {bool auto = false}) {
    setState(() {
      d[k] = v;
      _err = '';
    });
    if (auto) Future.delayed(const Duration(milliseconds: 220), () => mounted && step != 'ready' ? _next() : null);
  }

  Future<void> _next() async {
    if (step == 'sports' && (d['sports'] as List).isEmpty) return setState(() => _err = 'Pick at least one sport.');
    if (step == 'body' && !((d['age'] as int) >= 14 && (d['age'] as int) <= 80)) return setState(() => _err = 'Age should be between 14 and 80.');
    if (step == 'ready') return _finish();
    if (_steps[_i + 1] == 'ready') {
      setState(() => _busy = true);
      try {
        final r = await Api.i.post('onboarding/preview/', _payload());
        _preview = Map<String, dynamic>.from(r as Map);
      } on ApiError catch (e) {
        setState(() {
          _busy = false;
          _err = e.message;
        });
        return;
      }
      _busy = false;
    }
    setState(() {
      _i++;
      _err = '';
    });
  }

  void _back() {
    if (_i == 0) {
      if (widget.redo) Navigator.pop(context);
      return;
    }
    setState(() {
      _i--;
      _err = '';
    });
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      final r = await Api.i.post('onboarding/', _payload()) as Map;
      if (!mounted) return;
      final app = context.app;
      final nav = Navigator.of(context);
      app.setMe(Map<String, dynamic>.from(r['user'] as Map));
      app.changed();
      app.say(widget.redo ? 'Plan updated. Targets recalculated.' : 'Plan saved. Welcome in, ${app.me.s('name').split(' ').first}.');
      if (widget.redo) nav.pop();
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choice = const ['goal', 'exp', 'days', 'time', 'sleep'].contains(step);
    final sports = (d['sports'] as List).length;
    final label = switch (step) {
      'sports' => sports > 0 ? 'Continue with $sports' : 'Pick at least one',
      'ready' => widget.redo ? 'Save my plan' : 'Go to my dashboard',
      _ => 'Continue',
    };
    return PopScope(
      canPop: widget.redo && _i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: XScreen(
        body: Column(children: [
          ObHeader(step: _i + 2, onBack: (_i > 0 || widget.redo) ? _back : null),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.anim(XS.base),
              child: ListView(
                key: ValueKey(step),
                padding: const EdgeInsets.fromLTRB(XS.gutter, 22, XS.gutter, 24),
                children: [..._body(), if (_err.isNotEmpty) ...[gap12, _error(_err)]],
              ),
            ),
          ),
        ]),
        dock: XDock(children: [
          XButton(choice ? 'Continue' : label, loading: _busy, onTap: step == 'sports' && sports == 0 ? null : _next),
        ]),
      ),
    );
  }

  Widget _error(String t) => Row(children: [const XDot(), const SizedBox(width: 8), Expanded(child: Text(t, style: XT.small(context, color: context.c.ink)))]);

  List<Widget> _q(String t, [String? h]) => [Text(t, style: XT.h1(context)), if (h != null) ...[gap4, Text(h, style: XT.small(context))], gap20];

  List<Widget> _choices(String field, List<(Object, String, String?)> opts, {bool auto = true}) => [
        for (final o in opts) ...[
          XChoice(title: o.$2, sub: o.$3, on: '${d[field]}' == '${o.$1}', onTap: () => _set(field, o.$1, auto: auto)),
          gap8,
        ],
      ];

  List<Widget> _slider(String field, int min, int max, String unit, {bool decimal = false}) {
    final v = (d[field] as num).toDouble().clamp(min.toDouble(), max.toDouble());
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(decimal ? v.toStringAsFixed(1) : '${v.round()}', style: XT.hero(context)),
        const SizedBox(width: 8),
        Text(unit, style: XT.small(context)),
      ]),
      gap8,
      SliderTheme(
        data: SliderThemeData(
            activeTrackColor: context.c.ink, inactiveTrackColor: context.c.gray, thumbColor: context.c.ink, overlayColor: Colors.transparent),
        child: Slider(
          value: v,
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: decimal ? (max - min) * 2 : max - min,
          semanticFormatterCallback: (x) => '${decimal ? x.toStringAsFixed(1) : x.round()} $unit',
          onChanged: (x) => _set(field, decimal ? (x * 2).round() / 2 : x.round()),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('$min $unit', style: XT.small(context)),
        Text('$max $unit', style: XT.small(context)),
      ]),
    ];
  }

  List<Widget> _toggleChips(String field, List<String> opts) {
    final list = List<String>.from(d[field] as List);
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in opts)
          XChip(k, on: list.contains(k), check: true, onTap: () {
            list.contains(k) ? list.remove(k) : list.add(k);
            _set(field, list);
          }),
      ]),
      gap12,
      Align(
        alignment: Alignment.centerLeft,
        child: XButton(list.isEmpty ? (field == 'allergies' ? 'I have none' : 'No conditions') : 'Clear all',
            small: true, expand: false, kind: XBtn.secondary, onTap: () => _set(field, <String>[])),
      ),
    ];
  }

  List<Widget> _body() {
    final c = context.c;
    switch (step) {
      case 'goal':
        return [
          ..._q('What are you here for?', 'You can change this any time.'),
          ..._choices('goal', [for (final g in catalog.l('goals')) (g.s('key'), g.s('label'), null)]),
        ];
      case 'sports':
        final list = List<String>.from(d['sports'] as List);
        return [
          ..._q('How do you like to move?', 'Pick everything you play or train. Exerlio tracks each one its own way.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in catalog.l('sports'))
              XChip(s.s('l'), on: list.contains(s.s('key')), check: true, onTap: () {
                list.contains(s.s('key')) ? list.remove(s.s('key')) : list.add(s.s('key'));
                _set('sports', list);
              }),
          ]),
        ];
      case 'exp':
        return [
          ..._q('Where are you starting from?', 'Honest answers make better plans.'),
          ..._choices('experience', [for (final g in catalog.l('levels')) (g.s('key'), g.s('label'), null)]),
        ];
      case 'weight':
        return [..._q('What do you weigh?', 'Used for calorie, protein and water targets.'), ..._slider('weight_kg', 40, 140, 'kg', decimal: true)];
      case 'height':
        return [
          ..._q('How tall are you?', 'Last body question, nearly.'),
          ..._slider('height_cm', 140, 210, 'cm'),
          gap20,
          BmiCard(weight: (d['weight_kg'] as num).toDouble(), height: (d['height_cm'] as num).toDouble()),
        ];
      case 'body':
        return [
          ..._q('Age and sex', 'Sets your heart-rate zones and calorie estimate. Only you see this.'),
          ..._slider('age', 14, 80, 'years'),
          gap20,
          const XLabel('Sex'),
          gap8,
          XSegment(
            ink: true,
            labels: const ['Male', 'Female', 'Prefer not to say'],
            index: const ['male', 'female', 'na'].indexOf('${d['sex']}').clamp(0, 2),
            onPick: (i) => _set('sex', const ['male', 'female', 'na'][i]),
          ),
        ];
      case 'food':
        return [
          ..._q('Any allergies or food intolerances?', 'We will warn you on every meal scan if a plate contains them.'),
          ..._toggleChips('allergies', catalog.strs('allergies')),
          gap20,
          const XLabel('Other allergy or intolerance'),
          gap8,
          XField(controller: _other, hint: 'e.g. sesame, or leave blank'),
        ];
      case 'health':
        return [
          ..._q('Do you have any of these conditions?', 'Pick all that apply. This changes your diet limits and workout plan. Only you see this.'),
          ..._toggleChips('conditions', catalog.strs('conditions')),
        ];
      case 'meds':
        return [
          ..._q('Are you taking any medicines?', 'Write the names, or leave blank. Your doctor sets the doses, not this app.'),
          const XLabel('Medicines'),
          gap8,
          XField(controller: _meds, hint: 'e.g. metformin, aspirin, or leave blank'),
        ];
      case 'days':
        return [
          ..._q('How many days a week?', 'Consistency beats volume every time. Rest days are built in.'),
          ..._choices('days_per_week', [for (final n in [2, 3, 4, 5, 6]) (n, '$n days', null)]),
        ];
      case 'time':
        return [
          ..._q('How long per session?', 'We size the plan to the time you have.'),
          ..._choices('session_minutes', [(20, '20 min', null), (30, '30 min', null), (45, '45 min', null), (60, '60 min or more', null)]),
        ];
      case 'sleep':
        return [
          ..._q('How much sleep do you get?', 'Drives your recovery score.'),
          ..._choices('sleep', [for (final g in catalog.l('sleep')) (g.s('key'), g.s('label'), null)]),
        ];
      case 'privacy':
        return [
          ..._q('Who sees your training?'),
          XChoice(icon: Icons.public_rounded, title: 'Public', sub: 'Anyone can follow you. Good for creators, coaches and clubs.',
              on: d['is_private'] != true, onTap: () => _set('is_private', false)),
          gap8,
          XChoice(icon: Icons.lock_outline_rounded, title: 'Private', sub: 'Only people you approve see your activities, routes and posts.',
              on: d['is_private'] == true, onTap: () => _set('is_private', true)),
          gap16,
          const XNote(label: 'Find your people', text: 'After setup, search for friends, clubs and gyms from Profile → Find friends.'),
        ];
      case 'ready':
        final p = _preview ?? {};
        final t = p.m('targets');
        final name = context.app.me.s('name', 'friend').split(' ').first;
        return [
          const XKicker('Your plan'),
          gap8,
          Text(widget.redo ? 'Your updated plan, $name.' : 'Your plan is ready, $name.', style: XT.h1(context)),
          gap4,
          Text('Built from your goal, ${d['days_per_week']} days a week and ${d['session_minutes']} minute sessions.', style: XT.small(context)),
          gap20,
          XGrid(cols: 2, children: [
            XStatBox('Daily calories', '${t.i('kcal')}', unit: 'kcal'),
            XStatBox('Protein', '${t.i('protein')}', unit: 'g'),
            XStatBox('Water', '${t.d('water_l')}', unit: 'L'),
            XStatBox('Max heart rate', '${p.i('max_hr')}', unit: 'bpm'),
          ]),
          gap12,
          BmiCard(weight: (d['weight_kg'] as num).toDouble(), height: (d['height_cm'] as num).toDouble()),
          gap12,
          HealthPlanCard(p.l('health_notes')),
          gap12,
          for (final r in [
            ['Goal', p.s('goal_label')],
            ['Sports', p.s('sports_label')],
            ['Starting point', '${(d['weight_kg'] as num).toStringAsFixed(1)} kg · ${d['height_cm']} cm'],
            ['Food alerts', p.s('food_alerts')],
            ['Week', p.s('week_label')],
          ])
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 110, child: Text(r[0], style: XT.small(context))),
                Expanded(child: Text(r[1], style: XT.h3(context).copyWith(fontSize: 15))),
              ]),
            ),
          gap16,
          Text('A day counts toward your streak when you finish a workout, hit your diet and do the recovery session. '
              'You get ${p.i('passes', 2)} rest-day passes a month.', style: XT.body(context)),
        ];
    }
    return const [];
  }
}
