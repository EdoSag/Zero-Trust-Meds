import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/meds_data.dart';
import '../logic/photo.dart';
import '../model/models.dart';
import 'child_page.dart';
import 'common.dart';

const childColors = [
  0xFFF43F5E,
  0xFFF97316,
  0xFFEAB308,
  0xFF22C55E,
  0xFF06B6D4,
  0xFF3B82F6,
  0xFF8B5CF6,
  0xFFEC4899,
];

const missedWindows = [30, 60, 120, 180, 240];

/// Adds a child (a new shared space with you as admin) or edits one.
class ChildEditorPage extends ConsumerStatefulWidget {
  const ChildEditorPage({super.key, this.existing});
  final ChildData? existing;

  @override
  ConsumerState<ChildEditorPage> createState() => _ChildEditorPageState();
}

class _ChildEditorPageState extends ConsumerState<ChildEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.child.name);
  final _myName = TextEditingController();
  LocalDate? _birth;
  late int _color = widget.existing?.child.color ?? childColors.first;
  String? _zone;
  late int _missed = widget.existing?.child.missedAfterMinutes ?? 120;

  /// Small JPEG, base64; encrypted with the rest of the child's profile.
  late String? _photo = widget.existing?.child.photo;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _birth = widget.existing?.child.birthDate;
    _zone = widget.existing?.child.timeZone;
    if (_zone == null) {
      FlutterTimezone.getLocalTimezone()
          .then((z) {
            if (mounted && _zone == null) setState(() => _zone = z.identifier);
          })
          .catchError((Object _) {
            if (mounted && _zone == null) setState(() => _zone = 'UTC');
          });
    }
    ref
        .read(meProvider.future)
        .then((me) {
          if (mounted && _myName.text.isEmpty) _myName.text = me.name;
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _myName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _zone == null) return;
    setState(() => _saving = true);
    final actions = ref.read(medsActionsProvider);
    final child = Child(
      name: _name.text.trim(),
      timeZone: _zone!,
      birthDate: _birth,
      color: _color,
      photo: _photo,
      missedAfterMinutes: _missed,
    );
    try {
      if (_isNew) {
        final myName = _myName.text.trim();
        final me = await ref.read(meProvider.future);
        if (me.name != myName) {
          await actions.saveMe(
            MeProfile(name: myName, disclaimerAccepted: me.disclaimerAccepted),
          );
        }
        final id = await actions.addChild(child, myName: myName);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => ChildPage(spaceId: id)),
        );
      } else {
        await actions.saveChild(widget.existing!.spaceId, child);
        if (mounted) Navigator.of(context).pop();
      }
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, context.l.saveFailedOffline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.addChild : l.editChild),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: _PhotoPicker(
                child: Child(
                  name: _name.text,
                  timeZone: _zone ?? 'UTC',
                  color: _color,
                  photo: _photo,
                ),
                onChanged: (p) => setState(() => _photo = p),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.childName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l.required : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: Text(l.birthDate),
              subtitle: Text(
                _birth == null ? l.optional : formatLocalDate(context, _birth!),
              ),
              onTap: () async {
                final now = DateTime.now();
                final b = _birth;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: b == null
                      ? DateTime(now.year - 3, now.month, now.day)
                      : DateTime(b.year, b.month, b.day),
                  firstDate: DateTime(now.year - 25),
                  lastDate: now,
                );
                if (picked != null) {
                  setState(() => _birth = LocalDate.of(picked));
                }
              },
            ),
            const SizedBox(height: 8),
            Text(l.color, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in childColors)
                  Semantics(
                    selected: c == _color,
                    button: true,
                    label: l.color,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = c),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(c),
                        child: c == _color
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text(l.childTimeZone),
              subtitle: Text(
                _zone == null ? '…' : '${_zone!} · ${l.childTimeZoneHint}',
              ),
              onTap: () async {
                final z = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const _ZonePicker()),
                );
                if (z != null) setState(() => _zone = z);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined),
              title: Text(l.missedAfter),
              subtitle: Text(l.missedAfterHint),
              trailing: DropdownButton<int>(
                value: missedWindows.contains(_missed) ? _missed : 120,
                onChanged: (v) => setState(() => _missed = v ?? 120),
                items: [
                  for (final m in missedWindows)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                        m < 60 ? l.minutesShort(m) : l.hoursShort(m ~/ 60),
                      ),
                    ),
                ],
              ),
            ),
            if (_isNew) ...[
              const Divider(height: 32),
              TextFormField(
                controller: _myName,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l.yourName,
                  helperText: l.yourNameHint,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.required : null,
              ),
              const SizedBox(height: 16),
              Text(
                l.addChildPrivacy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZonePicker extends StatefulWidget {
  const _ZonePicker();

  @override
  State<_ZonePicker> createState() => _ZonePickerState();
}

class _ZonePickerState extends State<_ZonePicker> {
  late final List<String> _all = [
    for (final id in tz.timeZoneDatabase.locations.keys)
      if (id.contains('/') &&
          !id.startsWith('Etc/') &&
          !id.startsWith('US/') &&
          !id.startsWith('SystemV/'))
        id,
  ]..sort();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase().replaceAll(' ', '_');
    final shown = [
      for (final id in _all)
        if (id.toLowerCase().contains(q)) id,
    ];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l.searchZone,
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
      ),
      body: ListView.builder(
        itemCount: shown.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(shown[i].split('/').last.replaceAll('_', ' ')),
          subtitle: Text(shown[i]),
          onTap: () => Navigator.of(context).pop(shown[i]),
        ),
      ),
    );
  }
}

/// The child's photo: taken or picked on the phone, shrunk to a small
/// JPEG, and stored only inside the encrypted profile.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.child, required this.onChanged});
  final Child child;
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file == null) return;
      // The picker's resize keeps EXIF (GPS included) on Android, so the
      // pixels are re-encoded here without any metadata.
      final clean = cleanPhoto(await file.readAsBytes());
      if (clean == null) throw const FormatException('not an image');
      onChanged(base64Encode(clean));
    } on Object {
      if (context.mounted) showSnack(context, context.l.photoFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(
      children: [
        ChildAvatar(child, radius: 44),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => _pick(context, ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l.takePhoto),
            ),
            TextButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l.choosePhoto),
            ),
            if (child.photo != null)
              TextButton.icon(
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.delete_outline),
                label: Text(l.removePhoto),
              ),
          ],
        ),
      ],
    );
  }
}
