import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/charts.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// List row: mini route (or sport icon), title, day, one-line summary.
class ActivityRow extends StatelessWidget {
  final Json a;
  const ActivityRow(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pts = RouteMap.parse(a['points']);
    final icon = switch (a.s('sport')) {
      'pool' || 'openwater' => Icons.pool_rounded,
      'strength' || 'crossfit' => Icons.fitness_center_rounded,
      'cycle' => Icons.directions_bike_rounded,
      'walk' || 'trek' => Icons.directions_walk_rounded,
      'run' || 'jog' => Icons.directions_run_rounded,
      'yoga' => Icons.self_improvement_rounded,
      _ => Icons.monitor_heart_outlined,
    };
    return XRow(
      a.s('title'),
      sub: a.s('line'),
      onTap: () => Go.activity(context, a.i('id')),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 64,
          height: 52,
          child: pts.length > 2 ? RouteMap(points: pts, height: 52, thin: true, seed: a.i('id')) : Container(color: c.gray, child: Icon(icon, size: 20, color: c.ink)),
        ),
      ),
      trailing: Text(a.s('day'), style: XT.small(context).copyWith(fontSize: 12)),
    );
  }
}
