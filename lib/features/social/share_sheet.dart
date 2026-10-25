import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/device.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Share anything: story, feed post, a message, the system share sheet (WhatsApp, copy link), a club.
Future<void> showShareSheet(BuildContext context, {required String kicker, required String title, String sub = '', String label = ''}) {
  final text = '$title${sub.isNotEmpty ? ' · $sub' : ''} — on Exerlio';
  Future<void> post(BuildContext ctx, Json body, {bool push = false}) async {
    Navigator.pop(ctx);
    final r = await attempt(context, () => Api.i.post('share/', {'kicker': kicker, 'title': title, 'sub': sub, ...body}));
    if (r != null && context.mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
      if (push && r['thread_id'] != null) Go.thread(context, r['thread_id'] as int);
    }
  }

  return showXSheet(
    context,
    (ctx) => XSheetBody(children: [
      XSheetHead('Share${label.isNotEmpty ? ' $label' : ''}'),
      XGrid(cols: 2, children: [
        XOption(icon: Icons.add_circle_outline_rounded, title: 'Add to story', onTap: () => post(ctx, {'target': 'story'})),
        XOption(icon: Icons.image_outlined, title: 'Post to feed', onTap: () {
          Navigator.pop(ctx);
          Go.compose(context, 'post');
        }),
        XOption(icon: Icons.chat_bubble_outline_rounded, title: 'Send in a message', onTap: () async {
          Navigator.pop(ctx);
          await _pickPerson(context, (id) => post(context, {'target': 'user', 'user_id': id}, push: true));
        }),
        XOption(icon: Icons.link_rounded, title: 'Copy link or WhatsApp', onTap: () {
          Navigator.pop(ctx);
          Sharing.text(text, subject: title);
        }),
        XOption(icon: Icons.groups_outlined, title: 'Share to a club', onTap: () async {
          Navigator.pop(ctx);
          await _pickClub(context, (id) => post(context, {'target': 'club', 'club_id': id}));
        }),
      ]),
    ]),
  );
}

Future<void> _pickPerson(BuildContext context, void Function(int) onPick) async {
  List<Json> people = [];
  try {
    final a = Map<String, dynamic>.from(await Api.i.get('social/?tab=following') as Map).l('items');
    final b = Map<String, dynamic>.from(await Api.i.get('social/?tab=followers') as Map).l('items');
    final seen = <int>{};
    people = [for (final p in [...a, ...b]) if (seen.add(p.i('id'))) p];
  } catch (_) {}
  if (!context.mounted) return;
  await showXSheet(
    context,
    (ctx) => XSheetBody(children: [
      const XSheetHead('Send to'),
      if (people.isEmpty) Text('Follow people to send them things.', style: XT.small(ctx)),
      for (final p in people)
        XRow(p.s('name'), sub: '@${p.s('handle')}', leading: XAvatar(p, size: 40), onTap: () {
          Navigator.pop(ctx);
          onPick(p.i('id'));
        }),
    ]),
  );
}

Future<void> _pickClub(BuildContext context, void Function(int) onPick) async {
  List<Json> mine = [];
  try {
    mine = Map<String, dynamic>.from(await Api.i.get('clubs/') as Map).l('mine');
  } catch (_) {}
  if (!context.mounted) return;
  await showXSheet(
    context,
    (ctx) => XSheetBody(children: [
      const XSheetHead('Share to a club'),
      if (mine.isEmpty) Text('Join a club first.', style: XT.small(ctx)),
      for (final c in mine)
        XRow(c.s('name'), leading: XAvatar({'initial': c.s('initial'), 'name': c.s('name')}, size: 40, square: true), onTap: () {
          Navigator.pop(ctx);
          onPick(c.i('id'));
        }),
    ]),
  );
}
