import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Train → Challenges: Active · Discover · Yours, with streak-day rewards by intensity.
class ChallengesTab extends StatefulWidget {
  const ChallengesTab({super.key});
  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  String _tab = 'active';
  String _cat = 'All';

  @override
  Widget build(BuildContext context) {
    return Loader<Json>(
      key: ValueKey('$_tab$_cat'),
      load: () async => Map<String, dynamic>.from(await Api.i.get('challenges/?tab=$_tab&cat=${Uri.encodeComponent(_cat)}') as Map),
      builder: (context, d, reload) {
        final counts = d.m('counts');
        final items = d.l('items');
        return XPage(padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 40), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.genz ? 'Battles' : 'Challenges', style: XT.h1(context)),
                gap4,
                Text('Finish one to earn bonus streak days. The harder it is, the more you earn.', style: XT.small(context)),
              ]),
            ),
            const SizedBox(width: 12),
            XButton('Create', icon: Icons.add_rounded, small: true, expand: false, onTap: () => Go.newChallenge(context)),
          ]),
          gap16,
          XGrid(cols: 4, children: [
            for (final it in d.l('intensity'))
              XCard(
                muted: true,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(child: XIntensity(it.s('key'))),
                  gap8,
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('+${it.i('days')}', style: XT.metric(context, 18)),
                    const SizedBox(width: 3),
                    Text('days', style: XT.small(context).copyWith(fontSize: 11)),
                  ]),
                ]),
              ),
          ]),
          gap16,
          XSegment(
            labels: ['Active ${counts.i('active')}', 'Discover ${counts.i('discover')}', 'Yours ${counts.i('yours')}'],
            index: const ['active', 'discover', 'yours'].indexOf(_tab),
            onPick: (i) => setState(() => _tab = const ['active', 'discover', 'yours'][i]),
          ),
          gap16,
          if (_tab == 'discover') ...[
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
                for (final f in d.strs('filters')) ...[XChip(f, on: _cat == f, onTap: () => setState(() => _cat = f)), const SizedBox(width: 8)],
              ]),
            ),
            gap12,
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  switch (_tab) {
                    'active' => 'You are not in a challenge yet. Discover one or create your own.',
                    'discover' => 'Nothing new here. Make your own.',
                    _ => 'Challenges you create show up here.',
                  },
                  style: XT.small(context)),
            ),
          for (final ch in items) ...[ch.b('joined') ? MyChallengeCard(ch) : ChallengeCard(ch, onJoined: reload), gap10],
          if (d.l('completed').isNotEmpty) ...[
            gap8,
            const XLabel('Completed'),
            gap8,
            for (final ch in d.l('completed')) ...[MyChallengeCard(ch), gap10],
          ],
        ]);
      },
    );
  }
}

const gap10 = SizedBox(height: 10);

/// A challenge you are not in yet.
class ChallengeCard extends StatelessWidget {
  final Json ch;
  final Future<void> Function()? onJoined;
  const ChallengeCard(this.ch, {super.key, this.onJoined});

  @override
  Widget build(BuildContext context) {
    return XCard(
      onTap: () => Go.challenge(context, ch.i('id')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (ch.b('invited')) ...[const XKicker('You are invited'), gap8],
        XLabel(ch.s('meta')),
        gap6,
        Text(ch.s('title'), style: XT.h3(context)),
        gap4,
        Text('${fmtN(ch.i('people'))} joined · by ${ch.s('host')}', style: XT.small(context)),
        gap12,
        Row(children: [
          XIntensity(ch.s('intensity')),
          const SizedBox(width: 6),
          Expanded(child: Text('· +${ch.i('bonus')} streak days', style: XT.small(context, color: context.c.ink))),
          XButton('Join', small: true, expand: false, onTap: () async {
            final r = await attempt(context, () => Api.i.post('challenges/${ch.i('id')}/join/'));
            if (r != null && context.mounted) {
              context.say('${(r as Map)['message']}');
              context.app.changed();
            }
          }),
        ]),
      ]),
    );
  }
}

const gap6 = SizedBox(height: 6);

/// A challenge you are in: day, rank, points, progress, pace.
class MyChallengeCard extends StatelessWidget {
  final Json ch;
  const MyChallengeCard(this.ch, {super.key});

  @override
  Widget build(BuildContext context) {
    final m = ch.m('me');
    return XCard(
      onTap: () => Go.challenge(context, ch.i('id')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: m.b('done') ? const XKicker('Completed') : XLabel('Day ${m.i('day')} of ${ch.i('days')}')),
          Text('#${m.i('rank')} · ${fmtN(m.i('points'))} pts', style: XT.small(context)),
        ]),
        gap8,
        Text(ch.s('title'), style: XT.h3(context)),
        gap8,
        XBar(m.d('progress'), color: goalColor(context, m.d('progress'))),
        gap8,
        Text('${m.s('amount')} · ${m.s('pace')}', style: XT.small(context)),
      ]),
    );
  }
}
