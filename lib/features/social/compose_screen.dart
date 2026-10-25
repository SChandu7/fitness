import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../clubs/new_club_screen.dart';
import '../shell/shell.dart';

/// New post, reel, story or club event.
class ComposeScreen extends StatefulWidget {
  final String type; // post | reel | story | event
  final int? clubId;
  const ComposeScreen({super.key, required this.type, this.clubId});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _text = TextEditingController();
  final _title = TextEditingController();
  final _place = TextEditingController();
  File? _media;
  Json? _activity;
  bool _attach = false;
  final Set<String> _att = {};
  String _aud = 'everyone';
  String _err = '';
  bool _busy = false;
  List<Json> _adminClubs = [];
  int? _club;
  DateTime _when = DateTime.now().add(const Duration(days: 3)).copyWith(hour: 6, minute: 0, second: 0, millisecond: 0);

  String get type => widget.type;

  @override
  void initState() {
    super.initState();
    _club = widget.clubId;
    if (type == 'post') _loadActivity();
    if (type == 'event') _loadClubs();
  }

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    try {
      final r = Map<String, dynamic>.from(await Api.i.get('train/track/') as Map);
      final rec = r.l('recent');
      if (rec.isNotEmpty && mounted) setState(() => _activity = rec.first);
    } catch (_) {}
  }

  Future<void> _loadClubs() async {
    try {
      final r = Map<String, dynamic>.from(await Api.i.get('clubs/') as Map);
      final admin = r.l('items').where((c) => c.b('is_admin')).toList();
      if (mounted) {
        setState(() {
          _adminClubs = admin;
          _club ??= admin.isNotEmpty ? admin.first.i('id') : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _pick({bool video = false, ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    try {
      final x = video
          ? await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 90))
          : await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (x != null && mounted) setState(() => _media = File(x.path));
    } catch (_) {
      if (mounted) context.say(source == ImageSource.camera ? 'Camera is not available. Allow camera access in Settings.' : 'Could not open your photos.');
    }
  }

  Future<void> _publish() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      String msg;
      switch (type) {
        case 'post':
          if (_text.text.trim().isEmpty && _media == null && !_attach && _att.isEmpty) throw const ApiError('Write something, add a photo or attach a workout.');
          final fields = {
            'body': _text.text.trim(),
            'audience': _aud,
            if (_club != null) 'club_id': '$_club',
            if (_attach && _activity != null) 'activity_id': '${_activity!.i('id')}',
            if (_att.isNotEmpty) 'attachments': _att.join(','),
          };
          final r = await Api.i.upload('posts/', fields: fields, files: {if (_media != null) 'photo': _media!}) as Map;
          msg = '${r['message']}';
        case 'reel':
          if (_media == null) throw const ApiError('Record a clip first.');
          final r = await Api.i.upload('reels/', fields: {'title': _text.text.trim()}, files: {'video': _media!}) as Map;
          msg = '${r['message']}';
        case 'story':
          if (_media == null) throw const ApiError('Take a photo first.');
          final r = await Api.i.upload('stories/', fields: {'text': _text.text.trim()}, files: {'photo': _media!}) as Map;
          msg = '${r['message']}';
        default:
          if (_club == null) throw const ApiError('Create a club first to host events.');
          if (_title.text.trim().isEmpty) throw const ApiError('Give the event a name.');
          final r = await Api.i.post('events/', {
            'club_id': _club,
            'title': _title.text.trim(),
            'starts_at': _when.toUtc().toIso8601String(),
            'place': _place.text.trim(),
            'details': _text.text.trim(),
          }) as Map;
          msg = '${r['message']}';
      }
      if (!mounted) return;
      context.say(msg);
      context.app.changed();
      Navigator.pop(context);
      if (type == 'post' && _club == null || type == 'reel') ShellNav.homeTab.value = 1;
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(context: context, initialDate: _when, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final titles = {'post': 'New post', 'reel': 'New reel', 'story': 'New story', 'event': 'New club event'};
    final cta = {'post': 'Publish', 'reel': 'Publish', 'story': 'Share to story', 'event': 'Publish event'}[type]!;
    return XScreen(
      body: Column(children: [
        XTopBar(titles[type]!),
        Expanded(child: XPage(children: [..._body(), if (_err.isNotEmpty) ...[gap12, _error()]])),
        XDock(children: [XButton(cta, loading: _busy, onTap: _publish)]),
      ]),
    );
  }

  Widget _error() => Row(children: [const XDot(), const SizedBox(width: 8), Expanded(child: Text(_err, style: XT.small(context, color: context.c.ink)))]);

  List<Widget> _body() {
    final c = context.c;
    final clubName = _club == null ? '' : _adminClubs.firstWhere((x) => x.i('id') == _club, orElse: () => {}).s('name');
    switch (type) {
      case 'reel':
      case 'story':
        final reel = type == 'reel';
        return [
          Press(
            onTap: () => _pick(video: reel, source: ImageSource.camera),
            child: Container(
              height: reel ? 340 : 380,
              decoration: BoxDecoration(color: const Color(0xFF000000), borderRadius: BorderRadius.circular(16)),
              child: _media != null && !reel
                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_media!, fit: BoxFit.cover, width: double.infinity))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _media != null
                          ? const Icon(Icons.check_rounded, size: 32, color: Color(0xFFFFFFFF))
                          : Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFFFFF), width: 3)),
                              child: Container(decoration: BoxDecoration(color: reel ? c.orange : const Color(0xFFFFFFFF), shape: BoxShape.circle)),
                            ),
                      gap12,
                      Text(_media != null ? (reel ? 'Clip ready' : 'Photo ready') : 'Tap to ${reel ? 'record' : 'take a photo'}',
                          style: XT.small(context, color: const Color(0xB8FFFFFF))),
                    ]),
            ),
          ),
          gap8,
          Align(
            alignment: Alignment.centerLeft,
            child: XLink(reel ? 'Or pick a video from your phone' : 'Or pick a photo from your phone', onTap: () => _pick(video: reel)),
          ),
          gap12,
          XField(controller: _text, hint: reel ? 'Title, e.g. My sled push setup' : 'Add text on your story'),
        ];
      case 'event':
        if (_adminClubs.isEmpty && widget.clubId == null) {
          return [
            XEmpty(
              icon: Icons.groups_outlined,
              title: 'Create a club first',
              body: 'Events are hosted from a club or page you run.',
              action: 'Start a club',
              onAction: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const NewClubScreen())),
            ),
          ];
        }
        return [
          if (clubName.isNotEmpty) ...[XKicker('Posting to $clubName'), gap16],
          if (_adminClubs.length > 1) ...[
            const XLabel('Club'),
            gap8,
            Wrap(spacing: 8, runSpacing: 8, children: [for (final cl in _adminClubs) XChip(cl.s('name'), on: _club == cl.i('id'), onTap: () => setState(() => _club = cl.i('id')))]),
            gap16,
          ],
          const XLabel('Event name'),
          gap8,
          XField(controller: _title, hint: 'e.g. Saturday hill repeats'),
          gap16,
          const XLabel('When'),
          gap8,
          XRow('${_weekday(_when)} ${_when.day}/${_when.month} · ${hourLabel(_when.hour).replaceAll(' ', ':${_when.minute.toString().padLeft(2, '0')} ')}',
              trailing: const Icon(Icons.edit_calendar_outlined, size: 20), onTap: _pickWhen),
          gap8,
          const XLabel('Where'),
          gap8,
          XField(controller: _place, hint: 'Meeting point'),
          gap16,
          XField(controller: _text, hint: 'Details, pace groups, what to bring', maxLines: 4),
        ];
      default:
        return [
          if (widget.clubId != null) ...[const XKicker('Posting to your club'), gap16],
          XField(controller: _text, hint: 'How did it go?', maxLines: 5, autofocus: true),
          gap12,
          if (_media != null) ...[
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_media!, height: 220, width: double.infinity, fit: BoxFit.cover)),
              Positioned(
                right: 8,
                top: 8,
                child: Material(color: const Color(0x99000000), shape: const CircleBorder(), child: IconButton(
                    onPressed: () => setState(() => _media = null), icon: const Icon(Icons.close_rounded, color: Color(0xFFFFFFFF)), tooltip: 'Remove photo')),
              ),
            ]),
            gap12,
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            XButton(_media != null ? 'Photo added' : 'Add photo', icon: _media != null ? Icons.check_rounded : Icons.image_outlined, small: true, expand: false,
                kind: XBtn.secondary, onTap: () => _pick()),
            XButton('Camera', icon: Icons.camera_alt_outlined, small: true, expand: false, kind: XBtn.secondary, onTap: () => _pick(source: ImageSource.camera)),
            if (_activity != null)
              XButton(_attach ? 'Workout attached' : 'Attach workout', icon: _attach ? Icons.check_rounded : Icons.monitor_heart_outlined, small: true, expand: false,
                  kind: XBtn.secondary, onTap: () => setState(() => _attach = !_attach)),
          ]),
          if (_attach && _activity != null) ...[
            gap12,
            XCard(muted: true, child: Row(children: [
              Expanded(child: XStat('Workout', _activity!.s('title'), size: 15)),
              Expanded(child: XStat('Time', _activity!.s('time'), size: 15)),
            ])),
          ],
          gap20,
          const XLabel('Attach'),
          for (final o in const [('activity', 'Activity', Icons.monitor_heart_outlined), ('streak', 'Achievement', Icons.local_fire_department_outlined),
            ('challenge', 'Challenge', Icons.flag_outlined), ('pb', 'Personal record', Icons.emoji_events_outlined)])
            XRow(o.$2,
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.gray, shape: BoxShape.circle), child: Icon(o.$3, size: 16)),
                trailing: XCheck(done: _att.contains(o.$1)),
                onTap: () => setState(() => _att.contains(o.$1) ? _att.remove(o.$1) : _att.add(o.$1))),
          if (widget.clubId == null) ...[
            gap20,
            const XLabel('Who can see it'),
            gap8,
            XSegment(labels: const ['Everyone', 'Followers', 'My clubs'], index: const ['everyone', 'followers', 'clubs'].indexOf(_aud),
                onPick: (i) => setState(() => _aud = const ['everyone', 'followers', 'clubs'][i])),
          ],
        ];
    }
  }

  String _weekday(DateTime d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
}
