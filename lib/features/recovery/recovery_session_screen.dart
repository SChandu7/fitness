import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// The 10-minute recovery session: one of the three parts of a streak day.
class RecoverySessionScreen extends StatefulWidget {
  const RecoverySessionScreen({super.key});
  @override
  State<RecoverySessionScreen> createState() => _RecoverySessionScreenState();
}

class _RecoverySessionScreenState extends State<RecoverySessionScreen> {
  Json? _d;
  Set<int> _done = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await attempt(context, () => Api.i.get('recovery/session/'));
    if (r != null && mounted) {
      setState(() {
        _d = Map<String, dynamic>.from(r as Map);
        _done = {for (final x in (_d!['done'] as List)) (x as num).toInt()};
      });
    }
  }

  Future<void> _toggle(int k) async {
    setState(() => _done.contains(k) ? _done.remove(k) : _done.add(k));
    await attempt(context, () => Api.i.post('recovery/session/', {'steps': _done.toList()}));
  }

  Future<void> _complete() async {
    if (_d!.b('completed')) return Navigator.pop(context);
    setState(() => _busy = true);
    final r = await attempt(context, () => Api.i.post('recovery/session/', {'steps': _done.toList(), 'complete': true}));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const XScreen(body: Column(children: [XTopBar('Recovery session'), Expanded(child: XSkeleton())]));
    final steps = d.l('steps');
    final n = _done.length, all = steps.length;
    final completed = d.b('completed');
    return XScreen(
      body: Column(children: [
        const XTopBar('Recovery session'),
        Expanded(
          child: XPage(children: [
            const XKicker('10 minutes'),
            gap8,
            Text('Wind down and recover', style: XT.h1(context)),
            gap4,
            Text('One of the three things that make today count: workout, diet, recovery.', style: XT.small(context)),
            gap16,
            XBar(all == 0 ? 0 : n / all, color: n == all ? context.c.orange : context.c.ink),
            gap8,
            for (var k = 0; k < steps.length; k++)
              XRow(steps[k].s('title'), sub: steps[k].s('detail'), leading: XCheck(done: _done.contains(k)), onTap: () => _toggle(k)),
            if (completed) ...[gap16, const XNote(text: 'Done for today.')],
          ]),
        ),
        XDock(children: [
          XButton(completed ? 'Completed today' : (n == all ? 'Complete recovery session' : 'Mark complete · $n of $all steps'),
              kind: completed ? XBtn.secondary : XBtn.primary, loading: _busy, onTap: _complete),
        ]),
      ]),
    );
  }
}
