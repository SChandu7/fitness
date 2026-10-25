import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import 'follow_button.dart';

/// Followers · Following · Mutuals · Requests.
class SocialListScreen extends StatefulWidget {
  final String tab;
  const SocialListScreen({super.key, this.tab = 'followers'});
  @override
  State<SocialListScreen> createState() => _SocialListScreenState();
}

class _SocialListScreenState extends State<SocialListScreen> {
  late String _tab = widget.tab;
  String _q = '';
  Timer? _debounce;
  final _search = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _post(String path, Json body, Future<void> Function() reload) async {
    final r = await attempt(context, () => Api.i.post(path, body));
    if (r != null && mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        key: ValueKey('$_tab|$_q'),
        load: () async => Map<String, dynamic>.from(await Api.i.get('social/?tab=$_tab&q=${Uri.encodeComponent(_q)}') as Map),
        builder: (context, d, reload) {
          final counts = d.m('counts');
          final items = d.l('items');
          return Column(children: [
            XTopBar(d.s('handle'), actions: [
              XIconBtn(d.b('private') ? Icons.lock_outline_rounded : Icons.public_rounded, tooltip: 'Privacy', onTap: () async {
                await attempt(context, () => context.app.updateMe({'is_private': !d.b('private')}));
                if (context.mounted) {
                  context.say(d.b('private') ? 'Your account is now public' : 'Your account is now private');
                  reload();
                }
              }),
            ]),
            XTabs(
              labels: const ['Followers', 'Following', 'Mutuals', 'Requests'],
              counts: [counts.i('followers'), counts.i('following'), counts.i('mutuals'), counts.i('requests')],
              index: const ['followers', 'following', 'mutuals', 'requests'].indexOf(_tab),
              onPick: (i) => setState(() {
                _tab = const ['followers', 'following', 'mutuals', 'requests'][i];
                _q = '';
                _search.clear();
              }),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 14, XS.gutter, 32), children: [
                if (_tab != 'requests')
                  XField(
                    controller: _search,
                    hint: 'Search by name or @handle',
                    prefix: Icon(Icons.search_rounded, size: 20, color: c.muted),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _q = v.trim()));
                    },
                  )
                else
                  Row(children: [
                    const Expanded(child: XLabel('Want to follow you')),
                    if (items.isNotEmpty) XLink('Confirm all', onTap: () => _post('requests/accept-all/', {}, reload)),
                  ]),
                gap8,
                if (_tab == 'followers' && d.b('private')) Text('Your profile is private. Only these people see your activities and routes.', style: XT.small(context)),
                if (_tab == 'mutuals') Text('People you follow who also follow you back.', style: XT.small(context)),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(_tab == 'requests' ? 'No pending requests.' : 'No one here yet.', style: XT.small(context)),
                  ),
                for (final p in items)
                  PersonRow(
                    p,
                    sub: '@${p.s('handle')}${p.s('sub').isNotEmpty ? ' · ${p.s('sub')}' : ''}',
                    trailing: _tab == 'requests'
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            XButton('Confirm', small: true, expand: false, onTap: () => _post('requests/${p.i('id')}/', {'accept': true}, reload)),
                            const SizedBox(width: 6),
                            XButton('Delete', small: true, expand: false, kind: XBtn.secondary, onTap: () => _post('requests/${p.i('id')}/', {'accept': false}, reload)),
                          ])
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            FollowButton(user: p, followLabel: _tab == 'followers' ? 'Follow back' : 'Follow', onChanged: reload),
                            if (_tab == 'followers')
                              XIconBtn(Icons.close_rounded, tooltip: 'Remove follower', color: c.muted, onTap: () async {
                                final ok = await confirmX(context, title: 'Remove ${p.s('name')}?', body: 'They will not be told.', ok: 'Remove');
                                if (ok && context.mounted) _post('users/${p.i('id')}/remove-follower/', {}, reload);
                              }),
                          ]),
                  ),
                if (_tab == 'requests') ...[
                  gap16,
                  const XLabel('Requests you sent'),
                  gap8,
                  Text(d.strs('sent').isEmpty ? 'No pending requests. Following a private account sends one.' : d.strs('sent').join(', '), style: XT.small(context)),
                  gap16,
                  XNote(
                    label: d.b('private') ? 'Private profile' : 'Public profile',
                    text: d.b('private')
                        ? 'People must request to follow you. Only approved followers see your activities, routes and posts.'
                        : 'Anyone can follow you and see your posts. Switch to private to approve each follower.',
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

/// Re-exported so other screens can open a person from a list row.
void openPerson(BuildContext context, int id) => Go.person(context, id);
