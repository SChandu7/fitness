import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// A library workout: what is in it, then Start.
class LibraryScreen extends StatelessWidget {
  final String planKey;
  const LibraryScreen({super.key, required this.planKey});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('library/$planKey/') as Map),
        builder: (context, w, reload) => Column(children: [
          const XTopBar('Workout'),
          Expanded(
            child: XPage(children: [
              XKicker(w.s('label')),
              gap8,
              Text(w.s('title'), style: XT.h1(context)),
              gap16,
              XGrid(cols: 3, children: [
                XStatBox('Time', '${w.i('mins')} min'),
                XStatBox('Energy', '${w.i('kcal')} kcal'),
                XStatBox('Structure', w.s('structure')),
              ]),
              gap16,
              if (w.s('note').isNotEmpty) Text(w.s('note'), style: XT.body(context)),
              for (var k = 0; k < w.l('exercises').length; k++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text((k + 1).toString().padLeft(2, '0'), style: XT.small(context))),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(w.l('exercises')[k].s('name'), style: XT.h3(context).copyWith(fontSize: 15)),
                        Text(
                            '${w.l('exercises')[k].s('detail')}${w.l('exercises')[k].d('load_kg') > 0 ? ' · ${w.l('exercises')[k].d('load_kg').round()} kg' : ''}',
                            style: XT.small(context)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
          XDock(children: [XButton('Start workout', onTap: () => Go.startLibrary(context, w))]),
        ]),
      ),
    );
  }
}
