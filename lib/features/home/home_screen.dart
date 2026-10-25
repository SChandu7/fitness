import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../create/create_sheet.dart';
import '../messages/messages_screens.dart';
import '../notifications/notifications_screen.dart';
import '../shell/shell.dart';
import '../social/feed_view.dart';
import '../social/stories.dart';
import 'dashboard.dart';

/// Home: top bar, stories, Dashboard / Social.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Json _unread = {};
  int _seen = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = context.appWatch.version;
    if (v != _seen) {
      _seen = v;
      _loadUnread();
    }
  }

  Future<void> _loadUnread() async {
    try {
      final r = await Api.i.get('unread/');
      if (mounted) setState(() => _unread = Map<String, dynamic>.from(r as Map));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: SizedBox(
            height: 52,
            child: Row(children: [
              XIconBtn(Icons.add_rounded, tooltip: 'Create', onTap: () => showCreateSheet(context)),
              const Expanded(child: Center(child: Wordmark(size: 16))),
              XIconBtn(Icons.chat_bubble_outline_rounded,
                  tooltip: 'Messages', badge: _unread.i('messages'), onTap: () async {
                await context.push(const MessagesScreen());
                _loadUnread();
              }),
              XIconBtn(Icons.notifications_none_rounded,
                  tooltip: 'Notifications and nudges', dot: _unread.i('notifications') > 0, onTap: () async {
                await context.push(const NotificationsScreen());
                _loadUnread();
              }),
            ]),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: ShellNav.homeTab,
            builder: (context, tab, _) => NestedScrollView(
              headerSliverBuilder: (context, _) => [
                const SliverToBoxAdapter(child: StoriesRow()),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                    padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                    child: Row(children: [
                      _tab('Dashboard', 0, tab),
                      const SizedBox(width: 24),
                      _tab('Social', 1, tab, dot: tab == 0),
                    ]),
                  ),
                ),
              ],
              body: tab == 0 ? const Dashboard() : const FeedView(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _tab(String label, int i, int tab, {bool dot = false}) {
    final c = context.c;
    final on = i == tab;
    return Semantics(
      selected: on,
      button: true,
      child: Press(
        onTap: () => ShellNav.homeTab.value = i,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? c.ink : Colors.transparent, width: 2))),
          child: Row(children: [
            Text(label, style: XT.h3(context, color: on ? c.ink : c.muted).copyWith(fontSize: 15, fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
            if (dot) ...[const SizedBox(width: 6), const XDot(size: 6)],
          ]),
        ),
      ),
    );
  }
}
