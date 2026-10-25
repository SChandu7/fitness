import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// One challenge: progress, log today, leaderboard (points), invite, share, chat.
class ChallengeScreen extends StatelessWidget {
  final int id;
  const ChallengeScreen({super.key, required this.id});

  Future<void> _act(BuildContext context, String path, {bool pop = false}) async {
    final r = await attempt(context, () => Api.i.post('challenges/$id/$path'));
    if (r != null && context.mounted) {
      final m = (r as Map)['message'];
      if (m != null) context.say('$m');
      context.app.changed();
      if (pop) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('challenges/$id/') as Map),
        builder: (context, ch, reload) {
          final m = ch.m('me');
          final joined = ch.b('joined');
          final board = ch.l('board');
          return Column(children: [
            XTopBar('Challenge', actions: [XIconBtn(Icons.person_add_alt_outlined, tooltip: 'Invite friends', onTap: () => showInviteSheet(context, id, ch.s('title')))]),
            Expanded(
              child: XPage(children: [
                XLabel(ch.s('meta')),
                gap8,
                Text(ch.s('title'), style: XT.h1(context)),
                gap4,
                Text('${fmtN(ch.i('people'))} joined · by ${ch.s('host')}${ch.s('note').isNotEmpty ? ' · ${ch.s('note')}' : ''}', style: XT.small(context)),
                gap8,
                Row(children: [XIntensity(ch.s('intensity')), const SizedBox(width: 6), Expanded(child: Text('· finish for +${ch.i('bonus')} streak days', style: XT.small(context, color: c.ink)))]),
                gap16,
                if (joined)
                  XCard(
                    dark: m.b('done'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: m.b('done') ? XKicker('Completed', color: c.onInk.withValues(alpha: .7)) : XLabel('Day ${m.i('day')} of ${ch.i('days')}')),
                        Text('${fmtN(m.i('points'))} pts', style: XT.small(context, color: m.b('done') ? c.onInk.withValues(alpha: .7) : null)),
                      ]),
                      gap8,
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text('${m.i('pct')}', style: XT.hero(context, color: m.b('done') ? c.onInk : null).copyWith(fontSize: 72)),
                        const SizedBox(width: 4),
                        Text('%', style: XT.small(context)),
                      ]),
                      gap8,
                      XBar(m.d('progress'), color: m.d('progress') >= 1 ? c.orange : (m.b('done') ? c.onInk : c.ink)),
                      gap8,
                      Text('${m.s('amount')} · ${m.s('pace')}', style: XT.small(context, color: m.b('done') ? c.onInk.withValues(alpha: .7) : null)),
                      if (!m.b('done') && !m.b('over')) ...[
                        gap12,
                        XButton(m.s('log_label'), onTap: m.b('can_log') ? () => _act(context, 'log/') : null),
                        if (ch.b('auto')) ...[gap8, Text('Workouts you track in Exerlio count automatically.', style: XT.small(context))],
                      ],
                    ]),
                  )
                else
                  XNote(
                    label: 'What it takes',
                    text: ch.s('per_day'),
                    child: XButton('Join challenge', onTap: () => _act(context, 'join/')),
                  ),
                gap20,
                Row(children: [const Expanded(child: XLabel('Leaderboard')), Text('Points', style: XT.small(context))]),
                gap8,
                if (board.isEmpty) Text('Invite friends to fill the leaderboard.', style: XT.small(context)),
                for (final r in board)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: r.b('me') ? c.gray : null, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      SizedBox(width: 22, child: Text('${r.i('rank')}', style: XT.h3(context).copyWith(fontSize: 15))),
                      XAvatar({'initial': r.s('initial'), 'name': r.s('name')}, size: 36, ink: r.i('rank') == 1 && !r.b('me')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.s('name'), style: XT.h3(context).copyWith(fontSize: 15)),
                          Text(r.s('amount'), style: XT.small(context).copyWith(fontSize: 12)),
                        ]),
                      ),
                      if (r.b('can_nudge')) ...[
                        XButton('Nudge', small: true, expand: false, kind: XBtn.secondary, onTap: () => _act(context, 'nudge/${r.i('user_id')}/')),
                        const SizedBox(width: 8),
                      ],
                      Text(fmtN(r.i('points')), style: XT.h3(context).copyWith(fontSize: 15)),
                    ]),
                  ),
                gap8,
                Text('10 points for every 1% of the goal, 20 for every day you log, 250 for finishing.', style: XT.small(context)),
                gap20,
                Row(children: [
                  Expanded(child: XButton('Invite', icon: Icons.person_add_alt_outlined, kind: XBtn.secondary, small: true, onTap: () => showInviteSheet(context, id, ch.s('title')))),
                  const SizedBox(width: 8),
                  Expanded(child: XButton('Share', icon: Icons.send_outlined, kind: XBtn.secondary, small: true, onTap: () => _act(context, 'share/'))),
                  if (ch.s('type') != 'individual' && joined) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: XButton('Chat', icon: Icons.chat_bubble_outline_rounded, kind: XBtn.secondary, small: true, onTap: () async {
                        final r = await attempt(context, () => Api.i.post('challenges/$id/chat/'));
                        if (r != null && context.mounted) Go.thread(context, (r as Map)['thread_id'] as int);
                      }),
                    ),
                  ],
                ]),
                if (joined && !m.b('done')) ...[
                  gap12,
                  Center(
                    child: XLink('Leave challenge', underline: true, onTap: () async {
                      final ok = await confirmX(context, title: 'Leave this challenge?', body: 'Your progress and points are removed.', ok: 'Leave');
                      if (ok && context.mounted) _act(context, 'leave/', pop: true);
                    }),
                  ),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

/// Pick friends (people you follow or who follow you) to join the leaderboard.
Future<void> showInviteSheet(BuildContext context, int id, String title) async {
  Json d;
  try {
    d = Map<String, dynamic>.from(await Api.i.get('challenges/$id/invite/') as Map);
  } on ApiError catch (e) {
    if (context.mounted) context.say(e.message);
    return;
  }
  if (!context.mounted) return;
  final picked = <int>{};
  final people = d.l('people');
  return showXSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => XSheetBody(children: [
        XSheetHead('Invite to $title', sub: 'Friends you invite join your leaderboard.'),
        if (people.isEmpty) Text('Follow people first, then invite them here.', style: XT.small(ctx)),
        for (final p in people)
          XRow(p.s('name'),
              sub: p.b('in') ? 'Already in' : p.s('tagline'),
              leading: XAvatar(p, size: 36),
              trailing: p.b('in') ? null : XCheck(done: picked.contains(p.i('id'))),
              onTap: p.b('in') ? null : () => set(() => picked.contains(p.i('id')) ? picked.remove(p.i('id')) : picked.add(p.i('id')))),
        gap16,
        XButton('Send invites${picked.isEmpty ? '' : ' · ${picked.length}'}', onTap: picked.isEmpty ? null : () async {
          Navigator.pop(ctx);
          final r = await attempt(context, () => Api.i.post('challenges/$id/invite/', {'user_ids': picked.toList()}));
          if (r != null && context.mounted) {
            context.say('${(r as Map)['message']}');
            context.app.changed();
          }
        }),
      ]),
    ),
  );
}
