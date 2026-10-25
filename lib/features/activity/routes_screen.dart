import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'activity_row.dart';

/// Every GPS activity on one map. Latest in orange.
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});
  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  String _f = 'all';
  static const _filters = [('all', 'All'), ('run', 'Run'), ('jog', 'Jog'), ('walk', 'Walk'), ('cycle', 'Cycle'), ('swim', 'Swim')];

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Column(children: [
        const XTopBar('Your routes'),
        Expanded(
          child: Loader<Json>(
            key: ValueKey(_f),
            load: () async => Map<String, dynamic>.from(await Api.i.get('activities/?gps=1&sport=$_f') as Map),
            builder: (context, d, reload) {
              final items = d.l('items');
              final routes = [for (final a in items) RouteMap.parse(a['points'])];
              return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Where you moved', style: XT.h1(context)),
                    gap4,
                    Text('${d.i('count')} GPS activities · ${context.app.units.dist(d.d('km'), digits: 1)}. Latest in orange. '
                        'Start and end points stay hidden on shared routes.', style: XT.small(context)),
                  ]),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: XS.gutter), children: [
                    for (final f in _filters) ...[XChip(f.$2, on: _f == f.$1, onTap: () => setState(() => _f = f.$1)), const SizedBox(width: 8)],
                  ]),
                ),
                gap12,
                if (routes.isEmpty)
                  const XEmpty(icon: Icons.place_outlined, title: 'No routes for this sport yet', body: 'Track one from Train.')
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(XS.r3),
                      child: RouteMap(points: routes.first, overlays: routes.skip(1).toList(), height: 300, thin: true),
                    ),
                  ),
                gap8,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                  child: Column(children: [for (final a in items) ActivityRow(a)]),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
