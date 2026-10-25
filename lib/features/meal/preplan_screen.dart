import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/device.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Eating out later: front-load protein, keep carbs for the event.
class PreplanScreen extends StatefulWidget {
  const PreplanScreen({super.key});
  @override
  State<PreplanScreen> createState() => _PreplanScreenState();
}

class _PreplanScreenState extends State<PreplanScreen> {
  Json? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([Json? body]) async {
    final r = await attempt(context, () => body == null ? Api.i.get('preplan/') : Api.i.put('preplan/', body));
    if (r != null && mounted) setState(() => _d = Map<String, dynamic>.from(r as Map));
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const XScreen(body: Column(children: [XTopBar('Pre-plan'), Expanded(child: XSkeleton())]));
    final c = context.c;
    final opts = context.app.catalog.m('preplan');
    Widget chips(String k, List<String> labels, List<Object> values) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < labels.length; i++) XChip(labels[i], on: '${d[k]}' == '${values[i]}', onTap: () => _load({k: values[i]})),
        ]);
    final hours = [for (final h in (opts['hour'] as List? ?? const [13, 16, 20])) (h as num).toInt()];
    return XScreen(
      body: Column(children: [
        XTopBar('Pre-plan', actions: [XIconBtn(Icons.ios_share_rounded, tooltip: 'Share plan', onTap: () => Sharing.text(d.s('share_text')))]),
        Expanded(
          child: XPage(children: [
            Text('Plan around an outing', style: XT.h1(context)),
            gap8,
            Text('Eating out with friends or family later? Front-load your protein in small portions before you go and keep carbs low, so the event fits your day.',
                style: XT.small(context)),
            gap20,
            const XLabel('Occasion'),
            gap8,
            chips('occasion', opts.strs('occasion'), opts.strs('occasion')),
            gap16,
            const XLabel('With'),
            gap8,
            chips('with_who', opts.strs('with_who'), opts.strs('with_who')),
            gap16,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const XLabel('Time today'),
                  gap8,
                  chips('hour', [for (final h in hours) hourLabel(h)], hours),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const XLabel('Expected meal'),
                  gap8,
                  chips('size', opts.strs('size'), opts.strs('size')),
                ]),
              ),
            ]),
            gap20,
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: c.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const XLabel('The event budget'),
                gap12,
                Row(children: [
                  Expanded(child: XStat('Carbs kept', '${d.i('carbs_kept')} g', size: 19)),
                  Expanded(child: XStat('Est. protein', '${d.i('protein_est')} g', size: 19)),
                  Expanded(child: XStat('Est. energy', '${fmtN(d.i('kcal_est'))} kcal', size: 19)),
                ]),
                gap12,
                Text('Before the event: ${d.i('before')} g protein in divided portions, carbs capped at ${d.i('carb_cap')} g in total.', style: XT.small(context)),
              ]),
            ),
            gap16,
            Row(children: [const Expanded(child: XLabel('Before you go')), Text('${d.i('eaten_protein')} g / ${d.i('before')} g protein', style: XT.small(context))]),
            gap8,
            if (d.l('slots').isEmpty) Text('The event is early. Have a protein-heavy breakfast and keep the rest of the day light.', style: XT.small(context)),
            for (final s in d.l('slots'))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 80,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.s('label'), style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600)),
                      Text(s.s('time'), style: XT.small(context).copyWith(fontSize: 12)),
                    ]),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.s('target'), style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w500)),
                      Text(s.s('idea'), style: XT.small(context)),
                    ]),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 80,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.s('occasion'), style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600)),
                    Text('Today · ${d.s('hour_label')}', style: XT.small(context).copyWith(fontSize: 12)),
                  ]),
                ),
                Expanded(child: Text('Enjoy it. ${d.i('carbs_kept')} g of carbs are already set aside. Your streak still counts.', style: XT.small(context, color: c.ink))),
              ]),
            ),
          ]),
        ),
        XDock(row: true, children: [
          XButton('Share with group', kind: XBtn.secondary, onTap: () => Sharing.text(d.s('share_text'))),
          XButton(d.b('saved') ? 'Plan saved' : 'Save plan', icon: d.b('saved') ? Icons.check_rounded : null, kind: d.b('saved') ? XBtn.secondary : XBtn.primary,
              onTap: () async {
            await _load({'saved': true});
            if (mounted) {
              context.say('Plan saved. Reminders at each meal before ${d.s('hour_label')}.');
              context.app.changed();
            }
          }),
        ]),
      ]),
    );
  }
}
