import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Rolling number picker for weight, height and age. Values step by [step] between [min] and [max].
class NumberWheel extends StatefulWidget {
  final double value, min, max, step;
  final String unit, label;
  final ValueChanged<double> onChanged;
  const NumberWheel({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.label,
    required this.onChanged,
    this.step = 1,
  });
  @override
  State<NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<NumberWheel> {
  late final FixedExtentScrollController _ctrl = FixedExtentScrollController(initialItem: _index(widget.value));
  int get _count => ((widget.max - widget.min) / widget.step).round() + 1;
  int _index(double v) => ((v.clamp(widget.min, widget.max) - widget.min) / widget.step).round();
  double _at(int i) => widget.min + i * widget.step;
  String _fmt(double v) => widget.step < 1 ? v.toStringAsFixed(1) : v.round().toString();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _nudge(int dir) {
    final i = (_ctrl.selectedItem + dir).clamp(0, _count - 1);
    _ctrl.animateToItem(i, duration: context.anim(XS.base), curve: XS.ease);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final selected = _index(widget.value);
    return Semantics(
      label: widget.label,
      value: '${_fmt(widget.value)} ${widget.unit}',
      increasedValue: '${_fmt((widget.value + widget.step).clamp(widget.min, widget.max))} ${widget.unit}',
      decreasedValue: '${_fmt((widget.value - widget.step).clamp(widget.min, widget.max))} ${widget.unit}',
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      child: XCard(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(children: [
          SizedBox(
            height: 200,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: c.gray,
                  borderRadius: BorderRadius.circular(XS.r3),
                  border: Border.all(color: c.orange.withValues(alpha: .35)),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: _ctrl,
                itemExtent: 64,
                diameterRatio: 1.6,
                perspective: .004,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  HapticFeedback.selectionClick();
                  widget.onChanged(_at(i));
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _count,
                  builder: (context, i) {
                    final on = i == selected;
                    return Center(
                      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text(_fmt(_at(i)),
                            style: on ? XT.metric(context, 48) : XT.metric(context, 26, color: c.faint)),
                        if (on) ...[const SizedBox(width: 8), Text(widget.unit, style: XT.h3(context, color: c.orange))],
                      ]),
                    );
                  },
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Row(children: [
              Text('${_fmt(widget.min)} ${widget.unit}', style: XT.small(context).copyWith(fontSize: 12)),
              Expanded(child: Text('Scroll to set', textAlign: TextAlign.center, style: XT.small(context).copyWith(fontSize: 12))),
              Text('${_fmt(widget.max)} ${widget.unit}', style: XT.small(context).copyWith(fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Toggle a value in a multi-select where some options ([exclusive]) must stand alone.
List<String> toggleExclusive(List<String> current, String v, List<String> exclusive) {
  final out = List<String>.from(current);
  if (out.contains(v)) return out..remove(v);
  if (exclusive.contains(v)) return [v];
  return out
    ..removeWhere(exclusive.contains)
    ..add(v);
}

/// Grouped food alerts: allergies, intolerances, other. "None" and "Not sure" stand alone; "Other" opens a text field.
class FoodAlertPicker extends StatelessWidget {
  final Json catalog;
  final List<String> picked;
  final TextEditingController other;
  final ValueChanged<List<String>> onChanged;
  const FoodAlertPicker({super.key, required this.catalog, required this.picked, required this.other, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final groups = catalog.l('allergy_groups');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final g in groups) ...[
        XLabel(g.s('title')),
        gap8,
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in g.strs('items'))
            XChip(a, on: picked.contains(a), check: true,
                onTap: () => onChanged(toggleExclusive(picked, a, const ['None', 'Not sure']))),
        ]),
        gap16,
      ],
      if (picked.contains('Other')) ...[
        const XLabel('Tell us what to watch for'),
        gap8,
        XField(controller: other, hint: 'e.g. sesame, kiwi'),
        gap12,
      ],
      Text('Meal scans flag foods that match your allergies. Intolerances such as FODMAP or histamine cannot be seen in a photo, '
          'so check how food was made. With a severe allergy, always confirm ingredients with whoever made the food.',
          style: XT.small(context)),
    ]);
  }
}

/// Health conditions, with "No conditions" and "Not sure" standing alone and "Other" opening a text field.
class ConditionPicker extends StatelessWidget {
  final Json catalog;
  final List<String> picked;
  final TextEditingController other;
  final ValueChanged<List<String>> onChanged;
  const ConditionPicker({super.key, required this.catalog, required this.picked, required this.other, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final all = catalog.strs('conditions');
    const exclusive = ['No conditions', 'Not sure'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in all.where((x) => !exclusive.contains(x)))
          XChip(a, on: picked.contains(a), check: true, onTap: () => onChanged(toggleExclusive(picked, a, exclusive))),
      ]),
      gap16,
      const XLabel('Or'),
      gap8,
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in exclusive)
          XChip(a, on: picked.contains(a), check: true, onTap: () => onChanged(toggleExclusive(picked, a, exclusive))),
      ]),
      if (picked.contains('Other')) ...[
        gap16,
        const XLabel('Tell us about it'),
        gap8,
        XField(controller: other, hint: 'Your condition', maxLines: 3),
      ],
      gap16,
      Text('Used to adjust general activity and nutrition guidance. Exerlio does not diagnose or treat anything and does not '
          'replace advice from your doctor.', style: XT.small(context)),
    ]);
  }
}
