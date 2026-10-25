import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// BMI with a green arrow inside the healthy band, red outside it.
class BmiCard extends StatelessWidget {
  final double weight, height;
  const BmiCard({super.key, required this.weight, required this.height});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = height / 100;
    if (m <= 0 || weight <= 0) return const SizedBox.shrink();
    final b = weight / (m * m);
    final ok = b >= 18.5 && b < 25, high = b >= 25;
    final kg = high ? ((weight - 24.9 * m * m) * 10).ceil() / 10 : ((18.5 * m * m - weight) * 10).ceil() / 10;
    final label = ok
        ? 'Within your healthy limit'
        : high
            ? 'Lose about ${math.max(.1, kg)} kg to reach BMI 24.9'
            : 'Gain about ${math.max(.1, kg)} kg to reach BMI 18.5';
    final col = ok ? c.green : c.red;
    return Semantics(
      label: 'Body mass index ${b.toStringAsFixed(1)}. $label',
      child: XCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: XLabel('Body mass index')),
            Text('Healthy 18.5 to 24.9', style: XT.small(context)),
          ]),
          gap8,
          Row(children: [
            Text(b.toStringAsFixed(1), style: XT.metric(context, 40, color: col)),
            const SizedBox(width: 10),
            Icon(high ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 30, color: col),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: XT.h3(context, color: col).copyWith(fontSize: 15))),
          ]),
        ]),
      ),
    );
  }
}

/// Diet and workout changes from the health questions.
class HealthPlanCard extends StatelessWidget {
  final List<Json> notes;
  const HealthPlanCard(this.notes, {super.key});
  @override
  Widget build(BuildContext context) => XCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          XKicker('Health adjustments', color: context.c.ink),
          gap12,
          if (notes.isEmpty) Text('No conditions or medicines noted. Standard plan.', style: XT.small(context)),
          for (final n in notes) ...[
            Text(n.s('title'), style: XT.h3(context).copyWith(fontSize: 14)),
            gap4,
            Text(n.s('text'), style: XT.small(context)),
            gap12,
          ],
          Text('Starting suggestions, not medical advice. Check them with your doctor.', style: XT.small(context)),
        ]),
      );
}
