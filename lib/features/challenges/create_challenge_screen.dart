import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Custom challenge: activity, goal type, target, type, start, length, invites. Intensity is worked out live.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});
  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  String cat = 'Running', kind = 'total', type = 'group', starts = 'Today', vis = 'friends';
  int days = 7;
  final _target = TextEditingController(text: '50');
  final _name = TextEditingController();
  final Set<int> _with = {};
  List<Json> _friends = [];
  String _err = '';
  bool _busy = false;

  static const _dayCats = {'Consistency', 'Protein days'};
  static const _int = ['Light', 'Moderate', 'Heavy', 'Extreme'];
  static const _bonus = {'Light': 3, 'Moderate': 5, 'Heavy': 10, 'Extreme': 15};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final r = await Api.i.get('social/?tab=following') as Map;
      final f = await Api.i.get('social/?tab=followers') as Map;
      final seen = <int>{};
      final all = <Json>[];
      for (final p in [...(r['items'] as List), ...(f['items'] as List)]) {
        final m = Map<String, dynamic>.from(p as Map);
        if (seen.add(m.i('id'))) all.add(m);
      }
      if (mounted) setState(() => _friends = all);
    } catch (_) {}
  }

  Json get units => context.app.catalog.m('ch_units');
  bool get forced => cat == 'Steps' || _dayCats.contains(cat);
  double get target => _dayCats.contains(cat) ? 1 : (double.tryParse(_target.text.trim()) ?? 0);

  /// Same thresholds as the server (catalog.intensity_for).
  String _intensity() {
    if (_dayCats.contains(cat)) return _int[days < 7 ? 0 : days < 14 ? 1 : days < 21 ? 2 : 3];
    final k = forced ? 'daily' : kind;
    final per = k == 'daily' ? target : target / days;
    final th = const {
          'Running': [3, 6, 10],
          'Cycling': [15, 30, 50],
          'Swimming': [0.5, 1, 2],
          'Walking': [4, 8, 12],
          'Steps': [6000, 10000, 15000],
          'Workouts': [0.4, 0.6, 0.85],
          'Active minutes': [20, 40, 60],
        }[cat] ??
        const [1, 2, 3];
    var lv = per < th[0] ? 0 : per < th[1] ? 1 : per < th[2] ? 2 : 3;
    if (k == 'daily' && lv < 3 && days >= 14) lv++;
    return _int[lv];
  }

  String _defaultName() {
    final u = units.s(cat);
    if (cat == 'Consistency') return '$days-day consistency';
    if (cat == 'Protein days') return 'Protein goal, $days days';
    return (forced ? 'daily' : kind) == 'daily' ? '${fmt1(target)} $u every day' : '${fmt1(target)} $u in $days days';
  }

  void _setCat(String v) {
    final defaults = context.app.catalog.m('ch_default_target');
    setState(() {
      cat = v;
      kind = (v == 'Active minutes' || v == 'Steps' || _dayCats.contains(v)) ? 'daily' : 'total';
      _target.text = '${defaults.m(kind)[v] ?? 1}';
      _err = '';
    });
  }

  void _setKind(String v) {
    final defaults = context.app.catalog.m('ch_default_target');
    setState(() {
      kind = v;
      final t = defaults.m(v)[cat];
      if (t != null) _target.text = '$t';
    });
  }

  Future<void> _create() async {
    if (!(target > 0)) return setState(() => _err = 'Set a target above zero.');
    setState(() => _busy = true);
    try {
      final r = await Api.i.post('challenges/', {
        'category': cat,
        'kind': forced ? 'daily' : kind,
        'target': target,
        'days': days,
        'type': type,
        'starts': starts,
        'name': _name.text.trim(),
        'visibility': vis,
        'invite': type == 'group' ? _with.toList() : [],
      }) as Map;
      if (!mounted) return;
      context.say('${r['message']}');
      context.app.changed();
      Navigator.pop(context);
      Go.challenge(context, r['id'] as int);
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = _intensity();
    final per = (forced ? 'daily' : kind) == 'daily' ? target : target / days;
    return XScreen(
      body: Column(children: [
        const XTopBar('Custom challenge'),
        Expanded(
          child: XPage(children: [
            const XLabel('Activity'),
            gap8,
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in context.app.catalog.strs('ch_categories')) XChip(k, on: cat == k, onTap: () => _setCat(k)),
            ]),
            if (!forced) ...[
              gap16,
              const XLabel('Goal type'),
              gap8,
              XSegment(labels: const ['Total', 'Every day'], index: kind == 'total' ? 0 : 1, onPick: (i) => _setKind(i == 0 ? 'total' : 'daily')),
            ],
            gap16,
            if (_dayCats.contains(cat))
              XNote(text: cat == 'Protein days'
                  ? 'Every day: hit your protein goal. Rest days do not count against it.'
                  : 'Every day: workout, diet and recovery session done. The same rule as your streak.')
            else ...[
              XLabel('Target · ${units.s(cat)} ${(forced ? 'daily' : kind) == 'daily' ? 'per day' : 'in total'}'),
              gap8,
              XField(controller: _target, keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => _err = '')),
            ],
            gap16,
            const XLabel('Type'),
            gap8,
            XSegment(labels: const ['Group · one board', 'Individual · just you'], index: type == 'group' ? 0 : 1, onPick: (i) => setState(() => type = i == 0 ? 'group' : 'individual')),
            gap16,
            const XLabel('Starts'),
            gap8,
            XSegment(labels: const ['Today', 'Monday'], index: starts == 'Today' ? 0 : 1, onPick: (i) => setState(() => starts = i == 0 ? 'Today' : 'Monday')),
            gap16,
            const XLabel('Length'),
            gap8,
            XSegment(labels: const ['7 days', '14 days', '21 days', '30 days'], index: const [7, 14, 21, 30].indexOf(days), onPick: (i) => setState(() => days = const [7, 14, 21, 30][i])),
            gap16,
            const XLabel('Name · optional'),
            gap8,
            XField(controller: _name, hint: _defaultName()),
            gap16,
            XNote(
              text: '',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                XIntensity(it),
                gap8,
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Finishing earns '),
                  TextSpan(text: '+${_bonus[it]} streak days', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(text: '.'),
                ]), style: XT.body(context)),
                gap4,
                Text(_dayCats.contains(cat)
                    ? (cat == 'Protein days' ? 'Hit your protein goal every day for $days days.' : 'Workout, diet and recovery every day for $days days.')
                    : 'About ${fmt1(per)} ${units.s(cat)} a day for $days days.', style: XT.small(context)),
              ]),
            ),
            if (type == 'group') ...[
              gap16,
              const XLabel('Invite friends'),
              if (_friends.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Follow people to invite them.', style: XT.small(context))),
              for (final p in _friends)
                XRow(p.s('name'),
                    leading: XAvatar(p, size: 36),
                    trailing: XCheck(done: _with.contains(p.i('id'))),
                    onTap: () => setState(() => _with.contains(p.i('id')) ? _with.remove(p.i('id')) : _with.add(p.i('id')))),
              gap16,
              const XLabel('Who can join'),
              gap8,
              XSegment(labels: const ['People I invite', 'Anyone'], index: vis == 'friends' ? 0 : 1, onPick: (i) => setState(() => vis = i == 0 ? 'friends' : 'public')),
            ],
            if (_err.isNotEmpty) ...[gap12, Row(children: [const XDot(), const SizedBox(width: 8), Text(_err, style: XT.small(context, color: context.c.ink))])],
          ]),
        ),
        XDock(children: [XButton('Create challenge', loading: _busy, onTap: _create)]),
      ]),
    );
  }
}
