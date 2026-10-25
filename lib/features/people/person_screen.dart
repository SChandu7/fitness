import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import '../social/post_card.dart';
import 'follow_button.dart';

/// Someone else's profile. Private accounts stay locked until they approve you.
class PersonScreen extends StatelessWidget {
  final int userId;
  const PersonScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('users/$userId/') as Map),
        builder: (context, d, reload) {
          final u = d.m('user');
          final counts = d.m('counts');
          final rec = d.m('recent');
          final rel = d.m('relationship');
          final pts = RouteMap.parse(rec['points']);
          return Column(children: [
            XTopBar('@${u.s('handle')}', actions: [
              XIconBtn(Icons.more_horiz_rounded, tooltip: 'More', onTap: () => showXSheet(context, (ctx) => XSheetBody(children: [
                    gap8,
                    XRow(d.b('muted') ? 'Unmute' : 'Mute', sub: 'Hide their posts from your feed', onTap: () async {
                      Navigator.pop(ctx);
                      final r = await attempt(context, () => Api.i.post('users/$userId/mute/'));
                      if (r != null && context.mounted) {
                        context.say('${(r as Map)['message']}');
                        reload();
                      }
                    }),
                    if (d.b('follows_you'))
                      XRow('Remove follower', sub: 'They will not be told', onTap: () async {
                        Navigator.pop(ctx);
                        final r = await attempt(context, () => Api.i.post('users/$userId/remove-follower/'));
                        if (r != null && context.mounted) {
                          context.say('${(r as Map)['message']}');
                          reload();
                        }
                      }),
                  ]))),
            ]),
            Expanded(
              child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      XAvatar(u, size: 84, ink: true),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(children: [
                          _count(context, counts.i('followers'), 'Followers'),
                          _count(context, counts.i('following'), 'Following'),
                          _count(context, counts.i('workouts'), 'Workouts'),
                        ]),
                      ),
                    ]),
                    gap12,
                    Row(children: [
                      Flexible(child: NameWithLock(u, style: XT.h3(context).copyWith(fontSize: 16, fontWeight: FontWeight.w600))),
                      if (d.b('follows_you')) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: c.gray, borderRadius: BorderRadius.circular(4)),
                          child: Text('Follows you', style: XT.small(context).copyWith(fontSize: 11)),
                        ),
                      ],
                    ]),
                    gap4,
                    Text(u.s('tagline'), style: XT.small(context)),
                    if (u.s('bio').isNotEmpty && u.s('bio') != u.s('tagline')) ...[gap4, Text(u.s('bio'), style: XT.body(context))],
                    if (d.s('mutual_line').isNotEmpty) ...[gap4, Text(d.s('mutual_line'), style: XT.small(context))],
                    gap16,
                    Row(children: [
                      Expanded(child: FollowButton(user: {...u, ...rel}, full: true, onChanged: reload)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: XButton('Message', small: true, kind: XBtn.secondary, onTap: () async {
                          if (!d.b('can_message')) {
                            context.say('You can message ${u.s('name').split(' ').first} once you follow each other.');
                            return;
                          }
                          final r = await attempt(context, () => Api.i.post('threads/start/', {'user_id': userId}));
                          if (r != null && context.mounted) Go.thread(context, (r as Map)['thread_id'] as int);
                        }),
                      ),
                    ]),
                    gap24,
                  ]),
                ),
                if (!d.b('visible'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter, vertical: 24),
                    child: Column(children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.ink, width: 1.5)),
                        child: const Icon(Icons.lock_outline_rounded, size: 28),
                      ),
                      gap12,
                      Text('This account is private', style: XT.h3(context)),
                      gap4,
                      Text(d.s('locked_line'), textAlign: TextAlign.center, style: XT.small(context)),
                    ]),
                  )
                else ...[
                  if (d['streak'] != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 16),
                      child: XCard(muted: true, child: Row(children: [
                        const Icon(Icons.local_fire_department_outlined, size: 20),
                        const SizedBox(width: 10),
                        Text('${d.i('streak')}-day streak', style: XT.h3(context).copyWith(fontSize: 15)),
                      ])),
                    ),
                  if (rec.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                      child: Press(
                        onTap: () => Go.activity(context, rec.i('id')),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const XLabel('Recent activity'),
                          gap12,
                          Row(children: [Expanded(child: XLabel(rec.s('sport_label'))), Text(rec.s('when'), style: XT.small(context))]),
                          gap4,
                          Text(rec.s('title'), style: XT.h3(context)),
                          gap12,
                          Row(children: [for (final s in rec.l('stats').take(3)) Expanded(child: XStat(s.s('label'), s.s('value'), size: 17))]),
                          if (pts.length > 2) ...[
                            gap12,
                            ClipRRect(borderRadius: BorderRadius.circular(XS.r3), child: RouteMap(points: pts, height: 180, seed: rec.i('id'))),
                          ],
                          gap16,
                        ]),
                      ),
                    ),
                  for (final p in d.l('posts')) PostCard(p, onChanged: reload),
                  if (rec.isEmpty && d.l('posts').isEmpty)
                    const XEmpty(icon: Icons.directions_run_rounded, title: 'Nothing shared yet', body: 'Their activities and posts show up here.'),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _count(BuildContext context, int n, String label) => Expanded(
        child: Column(children: [
          FittedBox(child: Text(n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : fmtN(n), style: XT.metric(context, 20))),
          gap4,
          Text(label, style: XT.small(context).copyWith(fontSize: 12)),
        ]),
      );
}
