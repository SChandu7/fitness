import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/device.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../activity/activity_row.dart';
import '../log/log_sheet.dart';
import '../notifications/notifications_screen.dart' show nudgeIcon;
import '../onboarding/onboarding_screen.dart';
import '../people/find_friends_screen.dart';
import '../people/social_list_screen.dart';
import '../routes.dart';
import '../settings/settings_screen.dart';
import '../shell/shell.dart';
import '../social/post_card.dart';
import '../social/reels_screen.dart';
import '../social/share_sheet.dart';
import 'edit_profile_sheet.dart';

const _tabs = [('activity', 'Activity'), ('progress', 'Progress'), ('posts', 'Posts'), ('reels', 'Reels'), ('saved', 'Saved'), ('badges', 'Achievements')];

/// Your own profile (the fourth tab).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _loader = GlobalKey<LoaderState<Json>>();

  @override
  void initState() {
    super.initState();
    ShellNav.profileTab.addListener(_tabChanged);
  }

  @override
  void dispose() {
    ShellNav.profileTab.removeListener(_tabChanged);
    super.dispose();
  }

  void _tabChanged() {
    if (!mounted) return;
    setState(() {});
    _loader.currentState?.reload();
  }

  void _pick(String t) => ShellNav.profileTab.value = t;

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final c = context.c;
    final tab = ShellNav.profileTab.value;
    return XScreen(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Semantics(
                  button: true,
                  label: 'Switch interface mode',
                  child: Press(
                    onTap: app.toggleMode,
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(10)),
                      child: Text(app.genz ? 'GEN Z' : 'CLASSIC', style: XT.label(context, color: c.ink).copyWith(fontSize: 10.5)),
                    ),
                  ),
                ),
                Expanded(child: Text(app.me.s('handle'), textAlign: TextAlign.center, style: XT.h3(context).copyWith(fontSize: 16))),
                XIconBtn(Icons.tune_rounded, tooltip: 'Settings', onTap: () => context.push(const SettingsScreen())),
              ]),
            ),
          ),
          Expanded(
            child: Loader<Json>(
              key: _loader,
              load: () async => Map<String, dynamic>.from(await Api.i.get('profile/?tab=${ShellNav.profileTab.value}') as Map),
              builder: (context, d, reload) {
                final u = d.m('user');
                final counts = d.m('counts');
                final stats = d.m('stats');
                final req = d.m('requests');
                final ins = d.m('insights');
                return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      gap8,
                      Row(children: [
                        Semantics(
                          button: true,
                          label: 'Change photo',
                          child: Press(onTap: () => showEditProfile(context, photoFirst: true), child: XAvatar(u, size: 84, ink: true)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(children: [
                            _count(context, counts.i('followers'), 'Followers', 'followers'),
                            _count(context, counts.i('following'), 'Following', 'following'),
                            _count(context, counts.i('mutuals'), 'Mutuals', 'mutuals'),
                          ]),
                        ),
                      ]),
                      gap12,
                      Text(u.s('name'), style: XT.h3(context).copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                      gap4,
                      Text(['@${u.s('handle')}', if (u.s('sports_label').isNotEmpty) u.s('sports_label')].join(' · '), style: XT.small(context)),
                      if (u.s('bio').isNotEmpty) ...[gap4, Text(u.s('bio'), style: XT.body(context))],
                      gap8,
                      Press(
                        onTap: () async {
                          final priv = !u.b('is_private');
                          await attempt(context, () => app.updateMe({'is_private': priv}));
                          if (context.mounted) {
                            context.say(priv ? 'Your profile is private. You approve every follower.' : 'Your profile is public.');
                            reload();
                          }
                        },
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(15)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(u.b('is_private') ? Icons.lock_outline_rounded : Icons.public_rounded, size: 14, color: c.ink),
                            const SizedBox(width: 6),
                            Text(u.b('is_private') ? 'Private profile' : 'Public profile', style: XT.small(context, color: c.ink).copyWith(fontSize: 13)),
                          ]),
                        ),
                      ),
                      if (req.i('count') > 0) ...[
                        gap16,
                        XCard(
                          muted: true,
                          onTap: () => context.push(const SocialListScreen(tab: 'requests')),
                          child: Row(children: [
                            SizedBox(width: 52, child: XFaces(req.l('people'), size: 30)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Follow requests', style: XT.h3(context).copyWith(fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(_reqLine(req), style: XT.small(context)),
                              ]),
                            ),
                            Container(
                              height: 20,
                              constraints: const BoxConstraints(minWidth: 20),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(color: c.orange, borderRadius: BorderRadius.circular(10)),
                              child: Text('${req.i('count')}', style: XT.label(context, color: const Color(0xFF000000)).copyWith(fontSize: 11)),
                            ),
                            Icon(Icons.chevron_right_rounded, color: c.muted),
                          ]),
                        ),
                      ],
                      gap20,
                      Row(children: [
                        Expanded(child: _bigStat(context, '${stats.i('streak')}', 'Streak', () => Go.streak(context))),
                        Expanded(child: _bigStat(context, fmtN(stats.i('workouts')), 'Workouts', () => _pick('activity'))),
                        Expanded(child: _bigStat(context, '${stats.i('challenges')}', 'Challenges', () => _pick('badges'))),
                      ]),
                      gap20,
                      Row(children: [
                        Expanded(child: XButton('Edit profile', small: true, kind: XBtn.secondary, onTap: () => showEditProfile(context))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: XButton('Redo your setup', small: true, kind: XBtn.secondary, onTap: () => context.pushRoot(const OnboardingScreen(redo: true))),
                        ),
                        const SizedBox(width: 8),
                        _square(context, Icons.ios_share_rounded, 'Share profile',
                            () => Sharing.text('Follow my training on Exerlio: @${u.s('handle')}', subject: '${u.s('name')} on Exerlio')),
                        const SizedBox(width: 8),
                        _square(context, Icons.person_add_alt_outlined, 'Find friends', () => context.push(const FindFriendsScreen())),
                      ]),
                      gap16,
                      XCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [const Expanded(child: XKicker('Creator reach · 7 days')), Text('Insights', style: XT.small(context))]),
                          gap12,
                          Row(children: [
                            Expanded(child: XStat('Reached', ins.s('reached', '0'), size: 20)),
                            Expanded(child: XStat('New followers', ins.s('new_followers', '+0'), size: 20)),
                            Expanded(child: XStat('Top post', ins.s('top_post', '—'), size: 15)),
                          ]),
                        ]),
                      ),
                      gap8,
                    ]),
                  ),
                  _TabStrip(tab: tab, onPick: _pick),
                  if (d.s('tab') != tab)
                    const Padding(padding: EdgeInsets.all(XS.gutter), child: XSkeleton(lines: 3))
                  else
                    _body(context, d, tab, reload),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  String _reqLine(Json req) {
    final ppl = req.l('people');
    if (ppl.isEmpty) return '${req.i('count')} people want to follow you';
    final rest = req.i('count') - 1;
    return '${ppl.first.s('name')}${rest > 0 ? ' and $rest other${rest > 1 ? 's' : ''}' : ''} want${rest > 0 ? '' : 's'} to follow you';
  }

  Widget _count(BuildContext context, int n, String label, String tab) => Expanded(
        child: Semantics(
          button: true,
          label: '$n $label',
          child: Press(
            onTap: () => context.push(SocialListScreen(tab: tab)),
            child: Column(children: [
              Text(fmtN(n), style: XT.metric(context, 20)),
              gap4,
              Text(label, style: XT.small(context).copyWith(fontSize: 12)),
            ]),
          ),
        ),
      );

  Widget _bigStat(BuildContext context, String v, String l, VoidCallback onTap) => Press(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: XT.metric(context, 30)),
          XLabel(l),
        ]),
      );

  Widget _square(BuildContext context, IconData i, String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        child: Press(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(border: Border.all(color: context.c.line), borderRadius: BorderRadius.circular(XS.r2)),
            child: Icon(i, size: 18, color: context.c.ink),
          ),
        ),
      );

  Widget _body(BuildContext context, Json d, String tab, Future<void> Function() reload) {
    final pad = const EdgeInsets.symmetric(horizontal: XS.gutter);
    switch (tab) {
      case 'activity':
        final acts = d.l('activities');
        return Padding(
          padding: pad,
          child: Column(children: [
            if (acts.isEmpty)
              XEmpty(icon: Icons.directions_run_rounded, title: 'No activities yet', body: 'Track a run, ride or workout and it shows up here.',
                  action: 'Start tracking', onAction: () => Go.track(context)),
            for (final a in acts) ActivityRow(a),
            gap16,
            XButton('See all your routes', kind: XBtn.secondary, icon: Icons.place_outlined, onTap: () => Go.routes(context)),
          ]),
        );
      case 'progress':
        final p = d.m('progress');
        final weeks = p.l('weeks');
        return Padding(
          padding: pad,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            gap16,
            XCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Expanded(child: XLabel('Training time · 8 weeks')), Text('${p.i('this_week')} min this week', style: XT.small(context))]),
                gap12,
                WeekBars(values: [for (final w in weeks) w.i('minutes')], labels: [for (final w in weeks) w.s('label')]),
              ]),
            ),
            gap20,
            const XLabel('Consistency and body'),
            for (final r in p.l('rows')) XRow(r.s('title'), sub: r.s('sub'), trailing: Text(r.s('value'), style: XT.metric(context, 17))),
            gap12,
            XButton('Log weight', small: true, expand: false, kind: XBtn.secondary, icon: Icons.monitor_weight_outlined, onTap: () async {
              await showWeightSheet(context);
              reload();
            }),
            gap20,
            const XLabel('Personal records'),
            if (p.l('records').isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Lift heavier than before and records appear here.', style: XT.small(context))),
            for (final r in p.l('records')) XRow(r.s('title'), sub: r.s('sub'), trailing: Text(r.s('value'), style: XT.metric(context, 17))),
          ]),
        );
      case 'posts':
        final posts = d.l('posts');
        if (posts.isEmpty) {
          return XEmpty(icon: Icons.image_outlined, title: 'Share your first post', body: 'Workouts, meals, PRs and wins show up here.',
              action: 'Create a post', onAction: () => Go.compose(context, 'post'));
        }
        return Column(children: [for (final p in posts) PostCard(p, onChanged: reload)]);
      case 'reels':
        final reels = d.l('reels');
        if (reels.isEmpty) {
          return XEmpty(icon: Icons.movie_outlined, title: 'No reels yet', body: 'Short clips of your training show up here.',
              action: 'Record a reel', onAction: () => Go.compose(context, 'reel'));
        }
        return _reelGrid(context, reels);
      case 'saved':
        final items = d.l('saved');
        if (items.isEmpty) return const XEmpty(icon: Icons.bookmark_border_rounded, title: 'Nothing saved', body: 'Tap the bookmark on any post or reel to keep it here.');
        final reels = items.where((x) => x.has('duration')).toList();
        return Column(children: [
          for (final p in items.where((x) => !x.has('duration'))) PostCard(p, onChanged: reload),
          if (reels.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 8), child: Align(alignment: Alignment.centerLeft, child: XLabel('Saved reels'))),
            _reelGrid(context, reels),
          ],
        ]);
      default:
        final badges = d.l('badges');
        return Padding(
          padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 0),
          child: XGrid(cols: 3, children: [
            for (final b in badges)
              Opacity(
                opacity: b.b('earned') ? 1 : .45,
                child: XCard(
                  muted: true,
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    height: 108,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(_badgeIcon(b.s('icon')), size: 20),
                      gap8,
                      Expanded(child: Text(b.s('title'), maxLines: 3, overflow: TextOverflow.ellipsis, style: XT.body(context).copyWith(fontSize: 13, fontWeight: FontWeight.w500))),
                      if (b.b('earned'))
                        XLink('Share', onTap: () => showShareSheet(context, kicker: 'ACHIEVEMENT', title: b.s('title'), sub: b.s('sub'), label: 'achievement'))
                      else
                        Text('Locked', style: XT.small(context).copyWith(fontSize: 12)),
                    ]),
                  ),
                ),
              ),
          ]),
        );
    }
  }

  Widget _reelGrid(BuildContext context, List<Json> reels) => Padding(
        padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 0),
        child: XGrid(cols: 3, gap: 4, children: [
          for (var k = 0; k < reels.length; k++)
            Press(
              onTap: () => context.pushRoot(ReelsScreen(reels: reels, start: k)),
              child: ClipRRect(borderRadius: BorderRadius.circular(6), child: ReelPoster(reels[k], height: 170, compact: true)),
            ),
        ]),
      );

  IconData _badgeIcon(String k) => switch (k) {
        'award' => Icons.emoji_events_outlined,
        'users' => Icons.groups_outlined,
        _ => nudgeIcon(k),
      };
}

class _TabStrip extends StatelessWidget {
  final String tab;
  final ValueChanged<String> onPick;
  const _TabStrip({required this.tab, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: XS.gutter),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final t in _tabs)
            Semantics(
              selected: t.$1 == tab,
              button: true,
              child: Press(
                onTap: () => onPick(t.$1),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.$1 == tab ? c.ink : Colors.transparent, width: 2))),
                  child: Text(t.$2,
                      style: XT.body(context, color: t.$1 == tab ? c.ink : c.muted)
                          .copyWith(fontSize: 14, fontWeight: t.$1 == tab ? FontWeight.w600 : FontWeight.w500)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
