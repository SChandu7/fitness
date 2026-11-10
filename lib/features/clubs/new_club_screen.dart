import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Start a club or page: name, city, type, who can join.
class NewClubScreen extends StatefulWidget {
  const NewClubScreen({super.key});
  @override
  State<NewClubScreen> createState() => _NewClubScreenState();
}

class _NewClubScreenState extends State<NewClubScreen> {
  final _name = TextEditingController();
  late final _city = TextEditingController(text: context.app.me.s('location', 'Guntur'));
  final _desc = TextEditingController();
  final List<String> _sports = [];
  bool _private = false, _busy = false;
  String _err = '';

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return setState(() => _err = 'Give your club a name.');
    if (_sports.isEmpty) return setState(() => _err = 'Pick at least one sport or activity.');
    setState(() => _busy = true);
    try {
      final r = await Api.i.post('clubs/', {
        'name': _name.text.trim(),
        'city': _city.text.trim(),
        'sports': _sports,
        'is_private': _private,
        'description': _desc.text.trim(),
      }) as Map;
      if (!mounted) return;
      context.say('${r['message']}');
      context.app.changed();
      Navigator.pop(context);
      Go.club(context, r['id'] as int);
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Column(children: [
        const XTopBar('New club or page'),
        Expanded(
          child: XPage(children: [
            const XLabel('Name'),
            gap8,
            XField(controller: _name, hint: 'e.g. Brodipet Morning Runners', onChanged: (_) => setState(() => _err = '')),
            gap16,
            const XLabel('City or area'),
            gap8,
            XField(controller: _city, hint: 'City'),
            gap16,
            Row(children: [
              const Expanded(child: XLabel('Sports and activities')),
              Text(_sports.isEmpty ? 'Pick all that apply' : '${_sports.length} selected',
                  style: XT.small(context, color: _sports.isEmpty ? null : context.c.ink)),
            ]),
            gap8,
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in context.app.catalog.strs('club_sports'))
                XChip(t, on: _sports.contains(t), check: true, onTap: () => setState(() {
                      _sports.contains(t) ? _sports.remove(t) : (_sports.length < 15 ? _sports.add(t) : null);
                      _err = '';
                    })),
            ]),
            gap16,
            const XLabel('About · optional'),
            gap8,
            XField(controller: _desc, hint: 'When you meet, pace groups, what to bring', maxLines: 3),
            gap16,
            const XLabel('Who can join'),
            gap8,
            XChoice(icon: Icons.public_rounded, title: 'Anyone', sub: 'Open to everyone. People join straight away.',
                on: !_private, onTap: () => setState(() => _private = false)),
            gap8,
            XChoice(icon: Icons.verified_user_outlined, title: 'I approve', sub: 'People ask to join and you accept them.',
                on: _private, onTap: () => setState(() => _private = true)),
            if (_err.isNotEmpty) ...[gap12, Row(children: [const XDot(), const SizedBox(width: 8), Text(_err, style: XT.small(context, color: context.c.ink))])],
          ]),
        ),
        XDock(children: [XButton('Create', loading: _busy, onTap: _create)]),
      ]),
    );
  }
}
