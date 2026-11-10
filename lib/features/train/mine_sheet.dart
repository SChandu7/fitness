import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Totals for a list of {sets, reps, kg} rows.
({int sets, int reps, int volume}) mineTotals(List<Json> ex) {
  var sets = 0, reps = 0;
  var vol = 0.0;
  for (final x in ex) {
    sets += x.i('sets');
    reps += x.i('sets') * x.i('reps');
    vol += x.i('sets') * x.i('reps') * x.d('kg');
  }
  return (sets: sets, reps: reps, volume: vol.round());
}

String kgText(double kg) => kg % 1 == 0 ? '${kg.toInt()}' : kg.toStringAsFixed(1);

/// "Your own workout" on a day: build it, or see what it holds. A saved one is followed instead of Exerlio's plan.
class MineCard extends StatelessWidget {
  final int weekday;
  final String day;
  final Json mine;
  final List<Json> planEx;
  final VoidCallback onChanged;
  const MineCard({super.key, required this.weekday, required this.day, required this.mine, required this.planEx, required this.onChanged});

  Future<void> _edit(BuildContext context) async {
    final changed = await showXSheet<bool>(context, (_) => MineSheet(weekday: weekday, day: day, mine: mine, planEx: planEx));
    if (changed == true) {
      onChanged();
      if (context.mounted) context.app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final has = mine.l('ex').isNotEmpty;
    final head = Row(children: [
      Expanded(child: has ? const XKicker('Your workout · followed') : const XLabel('Your own workout')),
      Semantics(
        button: true,
        label: has ? 'Edit your workout' : 'Add your own workout',
        child: Press(
          onTap: () => _edit(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
            child: Icon(has ? Icons.edit_outlined : Icons.add_rounded, size: 20, color: c.onInk),
          ),
        ),
      ),
    ]);
    if (!has) {
      return XCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          gap8,
          Text("Build the session you actually do, with sets, reps and weight. Once saved, $day follows it instead of Exerlio's plan.",
              style: XT.small(context)),
        ]),
      );
    }
    final ex = mine.l('ex');
    return XCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        head,
        gap8,
        Text(mine.s('name'), style: XT.h3(context)),
        const SizedBox(height: 2),
        Text('${ex.length} exercise${ex.length == 1 ? '' : 's'} · about ${mine.i('mins')} min', style: XT.small(context)),
        gap12,
        XGrid(cols: 2, children: [
          XStatBox('Volume', '${fmtN(mine.i('volume'))} kg', padding: const EdgeInsets.all(12)),
          XStatBox('Sets', fmtN(mine.i('sets')), padding: const EdgeInsets.all(12)),
          XStatBox('Reps', fmtN(mine.i('reps')), padding: const EdgeInsets.all(12)),
          XStatBox('Best est. 1RM', mine.i('best_1rm') > 0 ? '${mine.i('best_1rm')} kg' : '—', padding: const EdgeInsets.all(12)),
        ]),
        gap8,
        for (final x in ex)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.s('name'), style: XT.body(context).copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${x.i('sets')} × ${x.s('reps')} · ${x.d('kg') > 0 ? '${kgText(x.d('kg'))} kg' : 'bodyweight'}', style: XT.small(context)),
                ]),
              ),
              if (x.i('volume') > 0) Text('${fmtN(x.i('volume'))} kg', style: XT.small(context)),
            ]),
          ),
      ]),
    );
  }
}

/// Build or edit the user's own workout for one weekday.
class MineSheet extends StatefulWidget {
  final int weekday;
  final String day;
  final Json mine;
  final List<Json> planEx;
  const MineSheet({super.key, required this.weekday, required this.day, required this.mine, required this.planEx});
  @override
  State<MineSheet> createState() => _MineSheetState();
}

class _MineSheetState extends State<MineSheet> {
  late final _name = TextEditingController(text: widget.mine.s('name'));
  final _n = TextEditingController(), _sets = TextEditingController(), _reps = TextEditingController(), _kg = TextEditingController();
  late final List<Json> _ex = [
    for (final x in widget.mine.l('ex')) {'n': x.s('name'), 'sets': x.i('sets'), 'reps': x.i('reps'), 'kg': x.d('kg')},
  ];
  String _err = '';
  bool _saving = false;

  bool get _had => widget.mine.l('ex').isNotEmpty;

  @override
  void dispose() {
    for (final t in [_name, _n, _sets, _reps, _kg]) {
      t.dispose();
    }
    super.dispose();
  }

  void _add() {
    final n = _n.text.trim();
    final sets = int.tryParse(_sets.text.trim());
    final reps = int.tryParse(_reps.text.trim());
    final kgText = _kg.text.trim().replaceAll(',', '.');
    final kg = kgText.isEmpty ? 0.0 : double.tryParse(kgText);
    String e = '';
    if (n.isEmpty) {
      e = 'Add the exercise name.';
    } else if (sets == null || sets < 1 || sets > 20) {
      e = 'Sets should be between 1 and 20.';
    } else if (reps == null || reps < 1 || reps > 100) {
      e = 'Reps should be between 1 and 100.';
    } else if (kg == null || kg < 0 || kg > 500) {
      e = 'Weight should be between 0 and 500 kg. Leave it blank for bodyweight moves.';
    } else if (_ex.length >= 20) {
      e = 'Keep it to 20 exercises or fewer.';
    }
    if (e.isNotEmpty) return setState(() => _err = e);
    setState(() {
      _err = '';
      _ex.add({'n': n.length > 60 ? n.substring(0, 60) : n, 'sets': sets, 'reps': reps, 'kg': (kg! * 2).round() / 2});
      _n.clear();
      _kg.clear();
    });
  }

  void _fromPlan() {
    setState(() {
      for (final e in widget.planEx.take(20)) {
        _ex.add({
          'n': e.s('name'),
          'sets': e.i('sets', 3).clamp(1, 20),
          'reps': (int.tryParse(e.s('reps').split(RegExp(r'[^0-9]')).first) ?? 10).clamp(1, 100),
          'kg': e.d('load_kg'),
        });
      }
    });
  }

  Future<void> _save() async {
    if (_ex.isEmpty) return setState(() => _err = 'Add at least one exercise.');
    setState(() => _saving = true);
    final r = await attempt(context, () => Api.i.post('train/day/${widget.weekday}/mine/', {'name': _name.text.trim(), 'ex': _ex}));
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) {
      context.say('${(r as Map)['message']}');
      Navigator.pop(context, true);
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    final r = await attempt(context, () => Api.i.delete('train/day/${widget.weekday}/mine/'));
    if (!mounted) return;
    setState(() => _saving = false);
    if (r != null) {
      context.say('${(r as Map)['message']}');
      Navigator.pop(context, true);
    }
  }

  Widget _num(String label, TextEditingController t, String hint, {bool decimal = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: XT.small(context).copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          XField(
            controller: t,
            hint: hint,
            keyboard: TextInputType.numberWithOptions(decimal: decimal),
            action: TextInputAction.next,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = mineTotals(_ex);
    return XSheetBody(children: [
      XSheetHead('${widget.day} workout', sub: "Build the session you actually do. ${widget.day} follows it instead of Exerlio's plan."),
      const XLabel('Name'),
      gap8,
      XField(controller: _name, hint: 'Chest, my way', action: TextInputAction.next),
      gap20,
      const XLabel('Add an exercise'),
      gap8,
      XField(controller: _n, hint: 'Exercise, e.g. Bench press', action: TextInputAction.next),
      gap8,
      Row(children: [
        Expanded(child: _num('Sets', _sets, '3')),
        const SizedBox(width: 8),
        Expanded(child: _num('Reps', _reps, '10')),
        const SizedBox(width: 8),
        Expanded(child: _num('Kg', _kg, '40', decimal: true)),
      ]),
      if (_err.isNotEmpty) ...[gap8, Text(_err, style: XT.small(context, color: c.red))],
      gap12,
      XButton('Add exercise', icon: Icons.add_rounded, kind: XBtn.secondary, onTap: _add),
      if (_ex.isEmpty && widget.planEx.isNotEmpty) ...[
        gap8,
        XButton("Start from Exerlio's plan", icon: Icons.content_copy_rounded, kind: XBtn.ghost, onTap: _fromPlan),
      ],
      gap16,
      XCard(
        muted: true,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: XStat('Sets', fmtN(t.sets), size: 17)),
          Expanded(child: XStat('Reps', fmtN(t.reps), size: 17)),
          Expanded(child: XStat('Volume', fmtN(t.volume), unit: 'kg', size: 17)),
        ]),
      ),
      gap8,
      if (_ex.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('No exercises yet.', style: XT.small(context)))
      else
        for (var k = 0; k < _ex.length; k++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_ex[k].s('n'), style: XT.body(context).copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                      '${_ex[k].i('sets')} × ${_ex[k].i('reps')} · '
                      '${_ex[k].d('kg') > 0 ? '${kgText(_ex[k].d('kg'))} kg · ${fmtN((_ex[k].i('sets') * _ex[k].i('reps') * _ex[k].d('kg')).round())} kg' : 'bodyweight'}',
                      style: XT.small(context)),
                ]),
              ),
              XIconBtn(Icons.close_rounded, tooltip: 'Remove ${_ex[k].s('n')}', onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _ex.removeAt(k));
              }),
            ]),
          ),
      gap20,
      XButton("Save as ${widget.day}'s workout", loading: _saving, onTap: _ex.isEmpty ? null : _save),
      if (_had) ...[
        gap8,
        XButton("Go back to Exerlio's plan", kind: XBtn.secondary, onTap: _saving ? null : _clear),
      ],
    ]);
  }
}
