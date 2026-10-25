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
  String _type = 'Running';
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
    setState(() => _busy = true);
    try {
      final r = await Api.i.post('clubs/', {
        'name': _name.text.trim(),
        'city': _city.text.trim(),
        'type': _type,
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
            const XLabel('Type'),
            gap8,
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in context.app.catalog.strs('club_types')) XChip(t, on: _type == t, onTap: () => setState(() => _type = t)),
            ]),
            gap16,
            const XLabel('About · optional'),
            gap8,
            XField(controller: _desc, hint: 'When you meet, pace groups, what to bring', maxLines: 3),
            gap16,
            const XLabel('Who can join'),
            gap8,
            XSegment(labels: const ['Anyone', 'I approve'], index: _private ? 1 : 0, onPick: (i) => setState(() => _private = i == 1)),
            if (_err.isNotEmpty) ...[gap12, Row(children: [const XDot(), const SizedBox(width: 8), Text(_err, style: XT.small(context, color: context.c.ink))])],
          ]),
        ),
        XDock(children: [XButton('Create', loading: _busy, onTap: _create)]),
      ]),
    );
  }
}
