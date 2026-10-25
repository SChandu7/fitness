import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import 'new_club_screen.dart';

/// Clubs tab: your clubs, search, types, every club and space.
class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});
  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  String _type = 'All';
  String _q = '';
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(XS.gutter, 4, 8, 0),
          child: SizedBox(
            height: 52,
            child: Row(children: [
              Expanded(child: Text(context.appWatch.tab('Clubs'), style: XT.h3(context).copyWith(fontSize: 17))),
              XIconBtn(Icons.add_rounded, tooltip: 'Start a club', onTap: () => context.push(const NewClubScreen())),
            ]),
          ),
        ),
        Expanded(
          child: Loader<Json>(
            key: ValueKey('$_type|$_q'),
            load: () async => Map<String, dynamic>.from(
                await Api.i.get('clubs/?type=${Uri.encodeComponent(_type)}&q=${Uri.encodeComponent(_q)}') as Map),
            builder: (context, d, reload) => ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 12),
                child: XField(
                  controller: _search,
                  hint: 'Search clubs, crews, gyms',
                  prefix: Icon(Icons.search_rounded, size: 20, color: context.c.muted),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _q = v.trim()));
                  },
                ),
              ),
              if (d.l('mine').isNotEmpty) ...[
                const Padding(padding: EdgeInsets.symmetric(horizontal: XS.gutter), child: XLabel('Your clubs')),
                gap12,
                SizedBox(
                  height: 92,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: XS.gutter), children: [
                    for (final c in d.l('mine'))
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Press(
                          onTap: () => Go.club(context, c.i('id')),
                          child: SizedBox(
                            width: 72,
                            child: Column(children: [
                              XAvatar({'initial': c.s('initial'), 'name': c.s('name')}, size: 64, square: true, ink: true),
                              const SizedBox(height: 6),
                              Text(c.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: context.c.ink).copyWith(fontSize: 11.5)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
                gap12,
              ],
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: XS.gutter), children: [
                  for (final t in d.strs('types')) ...[XChip(t, on: _type == t, onTap: () => setState(() => _type = t)), const SizedBox(width: 8)],
                ]),
              ),
              gap8,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                child: Column(children: [
                  if (d.l('items').isEmpty) const XEmpty(icon: Icons.groups_outlined, title: 'No clubs match', body: 'Start one for your crew.'),
                  for (final c in d.l('items')) ClubRow(c),
                ]),
              ),
              gap16,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
                child: XCard(
                  onTap: () => context.push(const NewClubScreen()),
                  child: Row(children: [
                    const Icon(Icons.add_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Start a club or page', style: XT.h3(context).copyWith(fontSize: 15)),
                        Text('For crews, gyms, coaches and event organisers', style: XT.small(context)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.c.muted),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// List row with logo, name, type · members · city and the join button.
class ClubRow extends StatelessWidget {
  final Json c;
  const ClubRow(this.c, {super.key});
  @override
  Widget build(BuildContext context) => XRow(
        c.s('name'),
        sub: '${c.s('type')} · ${fmtN(c.i('members'))} members · ${c.s('city')}',
        leading: XAvatar({'initial': c.s('initial'), 'name': c.s('name')}, size: 48, square: true),
        trailing: JoinButton(c),
        onTap: () => Go.club(context, c.i('id')),
      );
}

/// Join / Joined / Ask to join / Requested.
class JoinButton extends StatefulWidget {
  final Json club;
  final bool full;
  final String joinLabel;
  const JoinButton(this.club, {super.key, this.full = false, this.joinLabel = 'Join'});
  @override
  State<JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<JoinButton> {
  late bool joined = widget.club.b('joined'), requested = widget.club.b('requested');
  bool busy = false;

  @override
  void didUpdateWidget(JoinButton old) {
    super.didUpdateWidget(old);
    joined = widget.club.b('joined');
    requested = widget.club.b('requested');
  }

  Future<void> _tap() async {
    if (joined) {
      final ok = await confirmX(context, title: 'Leave ${widget.club.s('name')}?', body: 'You can join again any time.', ok: 'Leave');
      if (!ok) return;
    }
    setState(() => busy = true);
    final r = await attempt(context, () => Api.i.post('clubs/${widget.club.i('id')}/join/'));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      final m = r as Map;
      setState(() {
        joined = m['joined'] == true;
        requested = m['requested'] == true;
      });
      context.say('${m['message']}');
      context.app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = joined ? 'Joined' : requested ? 'Requested' : (widget.club.b('is_private') ? 'Ask to join' : widget.joinLabel);
    return XButton(label, small: true, expand: widget.full, loading: busy, kind: joined || requested ? XBtn.secondary : XBtn.primary, onTap: _tap);
  }
}
