import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Name, username, bio, photo and body numbers. Body numbers re-calculate targets on the server.
Future<void> showEditProfile(BuildContext context, {bool photoFirst = false}) =>
    showXSheet(context, (ctx) => _EditProfile(photoFirst: photoFirst));

class _EditProfile extends StatefulWidget {
  final bool photoFirst;
  const _EditProfile({this.photoFirst = false});
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final Json me = context.app.me;
  late final _name = TextEditingController(text: me.s('name'));
  late final _handle = TextEditingController(text: me.s('handle'));
  late final _bio = TextEditingController(text: me.s('bio'));
  late final _weight = TextEditingController(text: me.d('weight_kg').toStringAsFixed(1));
  late final _height = TextEditingController(text: '${me.i('height_cm')}');
  late final _age = TextEditingController(text: '${me.i('age')}');
  bool _saving = false, _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.photoFirst) WidgetsBinding.instance.addPostFrameCallback((_) => _photo());
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _bio, _weight, _height, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _photo() async {
    final src = await showXSheet<ImageSource>(context, (ctx) => XSheetBody(children: [
          const XSheetHead('Profile photo'),
          XRow('Take a photo', leading: const Icon(Icons.photo_camera_outlined), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          XRow('Choose from library', leading: const Icon(Icons.photo_library_outlined), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          gap16,
        ]));
    if (src == null || !mounted) return;
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: src, maxWidth: 800, imageQuality: 85);
    } catch (_) {
      if (mounted) context.say('Allow camera and photo access in your phone settings.');
      return;
    }
    if (x == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final d = await Api.i.upload('me/avatar/', files: {'photo': File(x.path)});
      if (!mounted) return;
      context.app.setMe(Map<String, dynamic>.from(d as Map));
      context.app.changed();
      context.say('Photo updated');
    } on ApiError catch (e) {
      if (mounted) context.say(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final w = double.tryParse(_weight.text.replaceAll(',', '.'));
    final h = int.tryParse(_height.text);
    final a = int.tryParse(_age.text);
    if (_name.text.trim().isEmpty) return setState(() => _error = 'Enter your name.');
    if (w == null || w < 30 || w > 250) return setState(() => _error = 'Weight must be between 30 and 250 kg.');
    if (h == null || h < 120 || h > 230) return setState(() => _error = 'Height must be between 120 and 230 cm.');
    if (a == null || a < 14 || a > 80) return setState(() => _error = 'Age must be between 14 and 80.');
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'handle': _handle.text.trim().toLowerCase().replaceAll('@', ''),
      'bio': _bio.text.trim(),
      'age': a,
      'height_cm': h,
    };
    final weightChanged = (w - me.d('weight_kg')).abs() >= .05;
    try {
      await context.app.updateMe(body);
      // Weight goes through the weight log so trend lines and targets stay in step.
      if (weightChanged) await Api.i.post('weight/', {'kg': double.parse(w.toStringAsFixed(1))});
      if (weightChanged) await context.app.refreshMe();
      if (!mounted) return;
      context.app.changed();
      Navigator.pop(context);
      context.say('Profile saved. Targets updated.');
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    return XSheetBody(children: [
      const XSheetHead('Edit profile'),
      Row(children: [
        XAvatar(app.me, size: 64, ink: true),
        const SizedBox(width: 14),
        XButton(_uploading ? 'Uploading…' : 'Change photo', small: true, expand: false, kind: XBtn.secondary, loading: _uploading, onTap: _photo),
      ]),
      gap16,
      _label('Name'),
      XField(controller: _name, hint: 'Your name'),
      gap12,
      _label('Username'),
      XField(controller: _handle, hint: 'username', prefix: Text('@ ', style: XT.body(context, color: context.c.muted))),
      gap12,
      _label('Bio'),
      XField(controller: _bio, hint: 'What you train for', maxLines: 3),
      gap12,
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Weight kg'), XField(controller: _weight, hint: '74', keyboard: const TextInputType.numberWithOptions(decimal: true))])),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Height cm'), XField(controller: _height, hint: '176', keyboard: TextInputType.number)])),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Age'), XField(controller: _age, hint: '30', keyboard: TextInputType.number)])),
      ]),
      if (_error != null) ...[gap12, Text(_error!, style: XT.small(context, color: context.c.red))],
      gap20,
      XButton('Save', loading: _saving, onTap: _save),
      gap16,
    ]);
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: XLabel(t));
}
