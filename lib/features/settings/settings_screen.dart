import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/device.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/forgot_screen.dart';
import '../people/social_list_screen.dart';
import '../profile/edit_profile_sheet.dart';
import '../routes.dart';
import '../shared/pickers.dart';
import 'devices_screen.dart';
import 'womens_health_screen.dart';

/// Settings: every row is wired to the server (users.settings JSON or a real field).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _Row {
  final String title, sub;
  final Widget Function(BuildContext) build;
  const _Row(this.title, this.sub, this.build);
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _q = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- rows

  _Row _toggle(String k, String t, String s, {bool fallback = true}) => _Row(t, s, (context) {
        final app = context.appWatch;
        return XRow(t, sub: s, trailing: XSwitch(value: app.setting(k, fallback), onChanged: (_) => app.toggleSetting(k, fallback)));
      });

  _Row _link(String t, String s, VoidCallback Function(BuildContext) onTap, {String Function(AppState)? value}) => _Row(t, s, (context) {
        final app = context.appWatch;
        return XRow(t,
            sub: s,
            chevron: true,
            trailing: value == null ? null : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(value(app), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: context.c.ink)),
            ),
            onTap: onTap(context));
      });

  /// A setting with a fixed list of options (from /catalog/ settings_options).
  _Row _pick(String k, String t, String s, String fallback, {String Function(String)? show}) => _link(t, s, (context) => () async {
        final app = context.app;
        final opts = (app.catalog.m('settings_options')[k] as List?)?.map((e) => '$e').toList() ?? [fallback];
        final cur = app.settingStr(k, fallback);
        final v = await showXSheet<String>(context, (ctx) => XSheetBody(children: [
              XSheetHead(t, sub: s),
              for (final o in opts) XChoice(title: show?.call(o) ?? o, on: o == cur, onTap: () => Navigator.pop(ctx, o)),
              gap16,
            ]));
        if (v == null || v == cur) return;
        await app.setSetting(k, k == 'restDays' ? int.parse(v) : v);
        if (k == 'restDays' || k == 'diet') app.changed();
      }, value: (app) => show?.call(app.settingStr(k, fallback)) ?? app.settingStr(k, fallback));

  /// (title, subtitle, icon, rows). Each becomes its own page; search looks across all of them.
  List<(String, String, IconData, List<_Row>)> _sections(AppState app) {
    final T = app.me.m('targets');
    final u = app.units;
    final female = app.me.s('sex') == 'female';
    return [
      ('Personal profile', 'Your details, goals and health', Icons.person_outline_rounded, [
        _link('Name and photo', 'How friends recognise you', (c) => () => showEditProfile(c), value: (a) => a.me.s('name')),
        _link('Username', 'Your handle across Exerlio', (c) => () => showEditProfile(c), value: (a) => '@${a.me.s('handle')}'),
        _link('Age, height and weight', 'Used for your targets and heart-rate zones', (c) => () => showEditProfile(c), value: (_) => 'Edit'),
        _link('Fitness goals', 'What you are training for', (c) => () => _goals(c), value: (a) => a.me.s('goal_label')),
        _link('Health conditions', 'Shapes your diet limits and plan', (c) => () => _conditions(c),
            value: (a) => a.me.strs('conditions').isEmpty ? 'None' : '${a.me.strs('conditions').length} added'),
        if (female)
          _link("Women's health", 'Cycle, life stage and rest-day support', (c) => () => c.push(const WomensHealthScreen()), value: (_) => 'Open'),
        _link('Email and password', 'Sign-in details', (c) => () => c.push(ForgotScreen(prefill: c.app.me.s('email', c.app.me.s('mobile')))),
            value: (a) => a.me.s('email', a.me.s('mobile'))),
      ]),
      ('Preferences', 'Look, language and units', Icons.tune_rounded, [
        _link('Interface mode', app.genz ? 'Gen Z · expressive copy and motion' : 'Classic · clean and focused', (c) => () => c.app.toggleMode(),
            value: (a) => a.genz ? 'Gen Z' : 'Classic'),
        _pick('units', 'Units', 'Weight, distance and volume', 'Metric'),
        _pick('lang', 'Language', 'More languages are coming', 'English (India)'),
        _pick('textSize', 'Text size', 'Applies across the app', 'Default'),
        _toggle('night', 'Night mode', 'Dark surfaces, easier on the eyes in low light', fallback: false),
        _toggle('nightAuto', 'Night mode from 9 pm to 6 am', 'Switches on automatically at night', fallback: false),
        _toggle('reduceMotion', 'Reduce motion', 'Fewer animations and transitions', fallback: false),
        _toggle('haptics', 'Haptics', 'A tap when something lands'),
      ]),
      ('Connected devices', 'Apple Health, Health Connect, Garmin and Strava', Icons.watch_outlined, [
        _link('Devices and apps', 'Steps, workouts, heart rate and sleep', (c) => () => c.push(const DevicesScreen()), value: (_) => 'Manage'),
      ]),
      ('Goals and targets', 'Calories, protein, water and training days', Icons.flag_outlined, [
        _link('Daily calories', 'Adjusts with your training load', (c) => () => showEditProfile(c), value: (_) => '${fmtN(T.i('kcal'))} kcal'),
        _link('Protein goal', 'Part of your daily streak', (c) => () => showEditProfile(c), value: (_) => '${T.i('protein')} g'),
        _link('Water goal', '${T.i('glasses')} glasses a day', (c) => () => showEditProfile(c), value: (_) => u.volume(T.d('water_l'))),
        _link('Training days', 'What we plan your week around', (c) => () => Go.weekPlan(c), value: (a) => '${a.me.i('days_per_week')} a week'),
        _toggle('adapt', 'Adapt goals automatically', 'Raises targets on heavy training days'),
        _Row('Suggest Exhaust Mode', 'After a long work day or poor recovery', (context) {
          final app = context.appWatch;
          return XRow('Suggest Exhaust Mode', sub: 'After a long work day or poor recovery',
              trailing: XSwitch(value: app.me.b('exhaust_auto', true), onChanged: (v) => attempt(context, () => app.updateMe({'exhaust_auto': v}))));
        }),
        _link('Work day ends', 'Used to suggest lighter sessions on late days', (c) => () async {
          final app = c.app;
          final v = await showXSheet<int>(c, (ctx) => XSheetBody(children: [
                const XSheetHead('Work day ends'),
                for (var h = 14; h <= 23; h++) XChoice(title: hourLabel(h), on: app.me.i('work_end_hour') == h, onTap: () => Navigator.pop(ctx, h)),
                gap16,
              ]));
          if (v != null && c.mounted) await attempt(c, () => app.updateMe({'work_end_hour': v}));
        }, value: (a) => a.me.s('work_end_label')),
      ]),
      ('Streaks and challenges', 'What counts, passes and friends', Icons.local_fire_department_outlined, [
        _Row('What counts as a day', 'Workout, diet and recovery session',
            (context) => XRow('What counts as a day', sub: 'Workout, diet and recovery session', trailing: Text('All three', style: XT.small(context, color: context.c.ink)))),
        _pick('restDays', 'Rest-day passes a month', 'Missed days that do not break the streak', '2'),
        _toggle('friendsAdd', 'Let friends add you to challenges', 'Without asking first', fallback: false),
        _toggle('allowNudges', 'Allow nudges', 'Friends can prod you when you slip'),
        _link('Challenge history', 'Everything you have entered', (c) => () => Go.challenges(c)),
      ]),
      ('Nutrition and scanning', 'Food alerts, portions and saved meals', Icons.restaurant_outlined, [
        _toggle('confirmScan', 'Confirm before logging', 'Review the plate the scanner found'),
        _toggle('showVitamins', 'Show vitamins and minerals', 'On every scan result'),
        _pick('portion', 'Portion sizes', 'How the scanner estimates by default', 'Medium'),
        _pick('diet', 'Dietary needs', 'Flags anything you avoid', 'None'),
        _link('Food alerts', 'Allergies, intolerances and sensitivities', (c) => () => _allergies(c),
            value: (a) => a.me.strs('allergies').isEmpty ? 'None' : '${a.me.strs('allergies').length} added'),
        _link('Saved meals', 'Log a regular meal in one tap', (c) => () => Go.meal(c, tab: 1)),
      ]),
      ('Notifications', 'Reminders, activity and quiet hours', Icons.notifications_none_rounded, [
        _toggle('nHyd', 'Hydration reminders', 'Every 2 hours, 9 am to 8 pm'),
        _toggle('nDiet', 'Diet goal check-in', 'At 4 pm if protein is behind'),
        _toggle('nStreak', 'Streak at risk', 'One hour before your bedtime'),
        _toggle('nWorkout', 'Workout reminders', 'On the days you have planned'),
        _toggle('nFriend', 'Friend activity', 'When someone beats your score'),
        _toggle('nMsgs', 'Messages and nudges', 'From friends only'),
        _toggle('nWeekly', 'Weekly summary', 'Sunday evening'),
        _pick('quiet', 'Quiet hours', 'Nothing arrives in this window', '22:00 – 07:00'),
      ]),
      ('Privacy and safety', 'What you share and who sees it', Icons.shield_outlined, [
        _link('Account privacy', app.me.b('is_private') ? 'Private · you approve every follower' : 'Public · anyone can follow', (c) => () async {
          final a = c.app;
          final priv = !a.me.b('is_private');
          final r = await attempt(c, () => a.updateMe({'is_private': priv}));
          if (r != null && c.mounted) c.say(priv ? 'Your profile is private' : 'Your profile is public');
        }, value: (a) => a.me.b('is_private') ? 'Private' : 'Public'),
        _link('Who can message you', 'Everyone, or only people who follow you back', (c) => () async {
          final a = c.app;
          final v = await showXSheet<String>(c, (ctx) => XSheetBody(children: [
                const XSheetHead('Who can message you'),
                XChoice(title: 'Everyone', sub: 'Anyone on Exerlio', on: a.me.s('message_policy') == 'everyone', onTap: () => Navigator.pop(ctx, 'everyone')),
                XChoice(title: 'Mutual followers', sub: 'People you follow who follow you back', on: a.me.s('message_policy') != 'everyone', onTap: () => Navigator.pop(ctx, 'mutual')),
                gap16,
              ]));
          if (v != null && c.mounted) await attempt(c, () => a.updateMe({'message_policy': v}));
        }, value: (a) => a.me.s('message_policy') == 'everyone' ? 'Everyone' : 'Mutuals'),
        _link('Follow requests', 'People waiting for your approval', (c) => () => c.push(const SocialListScreen(tab: 'requests'))),
        _toggle('showStreak', 'Show your streak', 'Friends see it on your profile'),
        _toggle('shareMeals', 'Share scanned meals', 'Off by default, meals stay private', fallback: false),
        _toggle('showWeight', 'Show weight and body composition', 'Never shown in the feed', fallback: false),
        _toggle('showGym', 'Show where you trained', 'Gym name on shared workouts'),
        _link('Health data', 'How Exerlio uses health information', (c) => () => _explain(c, 'Health data', const [
              'Conditions, medicines, cycle check-ins and device data are optional. You choose what to add.',
              'They are used only to shape your own plan and targets, never for advertising.',
              'Health and cycle details are never shown on your profile or in the feed.',
              'Connected apps can be disconnected at any time under Connected devices.',
            ])),
        _link('Community safety', 'Reporting, muting and messages', (c) => () => _explain(c, 'Community safety', const [
              'Use the menu on any post or reel to report it or mute the person.',
              'Choose who can message you above: everyone, or only mutual followers.',
              'A private profile means you approve every follower.',
              'Reports are reviewed by the Exerlio team.',
            ])),
        _link('Export your data', 'Everything you have logged, as CSV', (c) => () => _export(c)),
        _link('Terms and privacy policy', 'What we collect and the rules for using Exerlio',
            (c) => () => _info(c, 'Terms and privacy', 'What we collect, how we use it, and the rules for using Exerlio.', 'https://api.chandus7.in/api/exerlio/v1/legal/')),
      ]),
      ('Data and offline', 'Your information and offline use', Icons.storage_outlined, [
        _link('Export your data', 'Everything you have logged, as CSV', (c) => () => _export(c)),
        _toggle('offline', 'Offline mode', 'Keep workouts available without signal', fallback: false),
      ]),
      ('Subscription', 'Exerlio Pro', Icons.workspace_premium_outlined, [
        _link('Exerlio Pro', 'Body composition trends and custom macros', (c) => () => c.push(const ProScreen()),
            value: (a) => a.me.b('is_pro') ? 'Pro' : 'Free plan'),
      ]),
      ('Support', 'Help, feedback and policies', Icons.help_outline_rounded, [
        _link('Help centre', 'Guides and common questions', (c) => () => _info(c, 'Help centre', 'Contact details and answers to common questions.', 'https://api.chandus7.in/api/exerlio/v1/legal/#support')),
        _link('Report a problem', 'Something broken or wrong', (c) => () => _report(c)),
        _link('Terms and privacy', 'The long version', (c) => () => _info(c, 'Terms and privacy', 'What we collect, how we use it, and the rules for using Exerlio.', 'https://api.chandus7.in/api/exerlio/v1/legal/')),
      ]),
    ];
  }

  // -------------------------------------------------------------- actions

  Future<void> _allergies(BuildContext context) async {
    final app = context.app;
    var picked = app.me.strs('allergies');
    final other = TextEditingController(text: app.me.s('allergy_other'));
    final ok = await showXSheet<bool>(context, (ctx) => StatefulBuilder(
          builder: (ctx, set) => XSheetBody(children: [
            const XSheetHead('Food alerts', sub: 'The meal scanner flags matching foods before you log them.'),
            FoodAlertPicker(catalog: app.catalog, picked: picked, other: other, onChanged: (v) => set(() => picked = v)),
            gap20,
            XButton('Save', onTap: () => Navigator.pop(ctx, true)),
            gap16,
          ]),
        ));
    if (ok == true && context.mounted) {
      final r = await attempt(context,
          () => app.updateMe({'allergies': picked, 'allergy_other': picked.contains('Other') ? other.text.trim() : ''}));
      if (r != null && context.mounted) context.say('Food alerts saved');
    }
    other.dispose();
  }

  Future<void> _conditions(BuildContext context) async {
    final app = context.app;
    var picked = app.me.strs('conditions');
    final other = TextEditingController(text: app.me.s('condition_other'));
    final ok = await showXSheet<bool>(context, (ctx) => StatefulBuilder(
          builder: (ctx, set) => XSheetBody(children: [
            const XSheetHead('Health conditions', sub: 'Only you see these.'),
            ConditionPicker(catalog: app.catalog, picked: picked, other: other, onChanged: (v) => set(() => picked = v)),
            gap20,
            XButton('Save', onTap: () => Navigator.pop(ctx, true)),
            gap16,
          ]),
        ));
    if (ok == true && context.mounted) {
      if (picked.contains('Other') && other.text.trim().isEmpty) {
        context.say('Tell us about your other condition, or untick Other.');
      } else {
        final r = await attempt(context,
            () => app.updateMe({'conditions': picked, 'condition_other': picked.contains('Other') ? other.text.trim() : ''}));
        if (r != null && context.mounted) context.say('Health conditions saved. Targets updated.');
      }
    }
    other.dispose();
  }

  Future<void> _goals(BuildContext context) async {
    final app = context.app;
    var picked = app.me.strs('goals');
    final other = TextEditingController(text: app.me.s('goal_other'));
    final ok = await showXSheet<bool>(context, (ctx) => StatefulBuilder(
          builder: (ctx, set) => XSheetBody(children: [
            const XSheetHead('Fitness goals', sub: 'Choose all that apply. The first one sets your calorie target.'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in app.catalog.l('goals'))
                XChip(g.s('label'), on: picked.contains(g.s('key')), check: true,
                    onTap: () => set(() => picked = toggleExclusive(picked, g.s('key'), const ['unsure']))),
            ]),
            if (picked.contains('other')) ...[gap16, const XLabel('Your goal'), gap8, XField(controller: other, hint: 'e.g. climb Kilimanjaro')],
            gap20,
            XButton('Save', onTap: () => Navigator.pop(ctx, true)),
            gap16,
          ]),
        ));
    if (ok == true && context.mounted) {
      if (picked.isEmpty) {
        context.say('Choose at least one goal.');
      } else if (picked.contains('other') && other.text.trim().isEmpty) {
        context.say('Tell us your goal in a few words, or untick Other.');
      } else {
        final r = await attempt(context, () => app.updateMe({'goals': picked, 'goal_other': other.text.trim()}));
        if (r != null && context.mounted) context.say('Goals saved. Targets updated.');
      }
    }
    other.dispose();
  }

  Future<void> _explain(BuildContext context, String title, List<String> lines) => showXSheet(context, (ctx) => XSheetBody(children: [
        XSheetHead(title),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 7), child: XDot(size: 6)),
              const SizedBox(width: 10),
              Expanded(child: Text(l, style: XT.body(ctx))),
            ]),
          ),
        gap8,
      ]));

  Future<void> _export(BuildContext context) async {
    context.say('Preparing your export…');
    try {
      final csv = await Api.i.text('me/export/');
      await Sharing.file('exerlio-${context.app.me.s('handle')}.csv', csv, subject: 'My Exerlio data');
    } on ApiError catch (e) {
      if (context.mounted) context.say(e.message);
    } catch (_) {
      if (context.mounted) context.say('Could not create the file on this phone.');
    }
  }

  Future<void> _report(BuildContext context) async {
    final text = TextEditingController();
    final send = await showXSheet<bool>(context, (ctx) => XSheetBody(children: [
          const XSheetHead('Report a problem', sub: 'What happened, and what did you expect? Short is fine.'),
          XField(controller: text, hint: 'The scan button did nothing on the meal screen…', maxLines: 5),
          gap16,
          XButton('Send', onTap: () => Navigator.pop(ctx, true)),
          gap16,
        ]));
    if (send == true && context.mounted) {
      final r = await attempt(context, () => Api.i.post('report/', {'kind': 'app', 'reason': text.text.trim()}));
      if (r != null && context.mounted) context.say('${(r as Map)['message']}');
    }
    text.dispose();
  }

  Future<void> _info(BuildContext context, String title, String body, String url) => showXSheet(context, (ctx) => XSheetBody(children: [
        XSheetHead(title),
        Text(body, style: XT.body(ctx)),
        gap16,
        XButton('Open', icon: Icons.open_in_new_rounded, onTap: () async {
          Navigator.pop(ctx);
          if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && context.mounted) {
            context.say('Could not open the link');
          }
        }),
        gap8,
        XButton('Copy link', kind: XBtn.secondary, icon: Icons.link_rounded, onTap: () {
          Clipboard.setData(ClipboardData(text: url));
          Navigator.pop(ctx);
          context.say('Link copied');
        }),
        gap16,
      ]));

  Future<void> _logout() async {
    final ok = await confirmX(context, title: 'Log out?', body: 'Your data stays on your account.', ok: 'Log out');
    if (!ok || !mounted) return;
    final app = context.app;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    await app.logout();
  }

  Future<void> _delete() async {
    final ok = await confirmX(context,
        title: 'Delete your account?', body: 'Everything you have logged is removed. This cannot be undone.', ok: 'Delete account');
    if (!ok || !mounted) return;
    final app = context.app;
    try {
      await Api.i.delete('me/');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      await app.logout(silent: true);
      app.say('Your account was deleted');
    } on ApiError catch (e) {
      if (mounted) context.say(e.message);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final c = context.c;
    final q = _q.toLowerCase();
    final all = _sections(app);
    final hits = [
      for (final s in all)
        for (final r in s.$4)
          if (q.isNotEmpty && (r.title.toLowerCase().contains(q) || r.sub.toLowerCase().contains(q) || s.$1.toLowerCase().contains(q))) r,
    ];
    return XScreen(
      body: Column(children: [
        const XTopBar('Settings'),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 32), children: [
            Row(children: [
              XAvatar(app.me, size: 52, ink: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.me.s('name'), style: XT.h3(context).copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(app.me.s('email', '@${app.me.s('handle')}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context)),
                ]),
              ),
              XChip(app.genz ? 'GEN Z' : 'CLASSIC', on: false, onTap: app.toggleMode),
            ]),
            gap16,
            XField(
              controller: _search,
              hint: 'Search settings',
              prefix: Icon(Icons.search_rounded, size: 20, color: c.muted),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            gap8,
            if (q.isNotEmpty) ...[
              if (hits.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('No settings match "$_q".', style: XT.small(context))),
              for (final r in hits) r.build(context),
            ] else
              for (final s in all)
                XRow(s.$1,
                    sub: s.$2,
                    chevron: true,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.gray, borderRadius: BorderRadius.circular(XS.r2)),
                      child: Icon(s.$3, size: 20, color: c.ink),
                    ),
                    onTap: () => s.$1 == 'Connected devices'
                        ? context.push(const DevicesScreen())
                        : context.push(_SettingsPage(title: s.$1, sub: s.$2, rows: s.$4))),
            gap24,
            XButton('Log out', kind: XBtn.secondary, onTap: _logout),
            gap8,
            XButton('Delete account', kind: XBtn.secondary, onTap: _delete),
            gap12,
            Text('Exerlio 3.2', textAlign: TextAlign.center, style: XT.small(context)),
          ]),
        ),
      ]),
    );
  }
}

/// One settings category on its own page.
class _SettingsPage extends StatelessWidget {
  final String title, sub;
  final List<_Row> rows;
  const _SettingsPage({required this.title, required this.sub, required this.rows});
  @override
  Widget build(BuildContext context) {
    context.appWatch;
    return XScreen(
      body: Column(children: [
        XTopBar(title),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 32), children: [
            Text(sub, style: XT.small(context)),
            gap8,
            for (final r in rows) r.build(context),
          ]),
        ),
      ]),
    );
  }
}

/// Exerlio Pro. Store billing is not wired yet, so the button explains that honestly.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final c = context.c;
    final pro = app.me.b('is_pro');
    return XScreen(
      dock: XDock(children: [
        XButton(pro ? 'Pro is on' : 'Start Pro', icon: pro ? Icons.check_rounded : null, kind: pro ? XBtn.secondary : XBtn.accent, onTap: () {
          context.say(pro ? 'Pro is on for this account' : 'Pro checkout opens with the store release. Everything else stays free.');
        }),
        gap8,
        Text(pro ? 'Manage your plan in the App Store or Play Store.' : 'Billing goes through the App Store or Play Store.',
            textAlign: TextAlign.center, style: XT.small(context)),
      ]),
      body: Column(children: [
        const XTopBar('Exerlio Pro'),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 32), children: [
            XCard(
              dark: true,
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                XKicker('Exerlio Pro', color: c.onInk),
                gap12,
                Text('More signal.\nLess guessing.', style: XT.display(context, color: c.onInk)),
                gap12,
                Text('Go deeper on body composition, nutrition and progress without adding noise to your day.', style: XT.small(context, color: c.onInk.withValues(alpha: .72))),
              ]),
            ),
            gap20,
            const XLabel('Included'),
            for (final f in app.catalog.l('pro_features'))
              XRow(f.s('title'), sub: f.s('detail'), leading: const XCheck(done: true)),
            gap16,
            Text('Exerlio stays free for tracking, streaks, challenges and community.', style: XT.small(context)),
          ]),
        ),
      ]),
    );
  }
}
