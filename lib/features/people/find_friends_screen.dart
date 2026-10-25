import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/device.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../shell/shell.dart';
import 'follow_button.dart';

/// Find friends: search people, invite by link, browse clubs.
class FindFriendsScreen extends StatefulWidget {
  const FindFriendsScreen({super.key});
  @override
  State<FindFriendsScreen> createState() => _FindFriendsScreenState();
}

class _FindFriendsScreenState extends State<FindFriendsScreen> {
  String _q = '';
  Timer? _debounce;
  final _search = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = context.app.me.s('handle');
    return XScreen(
      body: Column(children: [
        const XTopBar('Find friends'),
        Expanded(
          child: Loader<Json>(
            key: ValueKey(_q),
            load: () async => Map<String, dynamic>.from(await Api.i.get('people/?q=${Uri.encodeComponent(_q)}') as Map),
            builder: (context, d, reload) => ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 32), children: [
              XField(
                controller: _search,
                hint: 'Search people by name or @handle',
                prefix: Icon(Icons.search_rounded, size: 20, color: context.c.muted),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _q = v.trim()));
                },
              ),
              gap16,
              XGrid(cols: 2, children: [
                XOption(icon: Icons.share_outlined, title: 'Invite', sub: 'WhatsApp or link', onTap: () => Sharing.text(
                    'Train with me on Exerlio. Find me at @$handle.', subject: 'Join me on Exerlio')),
                XOption(icon: Icons.groups_outlined, title: 'Clubs and gyms', sub: 'Same gym or crew', onTap: () => ShellNav.go(context, 2)),
              ]),
              gap20,
              Row(children: [
                Expanded(child: XLabel(_q.isEmpty ? 'Suggested for you' : 'Results')),
                if (_q.isEmpty) Text('Based on your sports', style: XT.small(context)),
              ]),
              if (d.l('items').isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('No one found. Try inviting them.', style: XT.small(context))),
              for (final p in d.l('items')) PersonRow(p),
            ]),
          ),
        ),
      ]),
    );
  }
}
