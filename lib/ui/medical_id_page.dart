import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/meds_data.dart';
import '../model/models.dart';
import 'common.dart';
import 'child_page.dart' show scheduleText;
import 'pick_for_keyboard_page.dart' show medicineList, medicineWithDose;

/// One line for the person's page: the allergies, else whether it's
/// filled in.
String medicalIdSummary(BuildContext context, MedicalId id) {
  final l = context.l;
  if (id.isEmpty) return l.medicalIdEmpty;
  return [
    if (id.allergies.isNotEmpty)
      l.medicalIdAllergiesLine(id.allergies.join(', ')),
    if (id.bloodType.isNotEmpty) '${l.bloodType}: ${id.bloodType}',
    if (id.allergies.isEmpty && id.bloodType.isEmpty) l.medicalIdFilledIn,
  ].join(' · ');
}

/// The whole card as plain text, to send to a doctor or a babysitter.
String medicalIdText(BuildContext context, ChildData c, DateTime nowUtc) {
  final l = context.l;
  final id = c.medicalId;
  final meds = medicineList(context, c, nowUtc);
  return [
    l.medicalIdShareTitle(c.child.name),
    if (c.child.birthDate != null)
      l.bornOn(formatLocalDate(context, c.child.birthDate!)),
    if (id.bloodType.isNotEmpty) '${l.bloodType}: ${id.bloodType}',
    '${l.allergies}: ${id.allergies.isEmpty ? l.noneRecorded : id.allergies.join(', ')}',
    if (id.conditions.isNotEmpty)
      '${l.conditions}: ${id.conditions.join(', ')}',
    if (meds.isNotEmpty) '${l.currentMedicines}:\n$meds',
    if (id.notes.trim().isNotEmpty) '${l.medicalNotes}: ${id.notes.trim()}',
    if (id.contacts.isNotEmpty)
      '${l.emergencyContacts}:\n${[for (final x in id.contacts) '${x.name} ${x.phone}'.trim()].join('\n')}',
  ].join('\n');
}

/// A person's Medical ID: allergies first, then conditions, current
/// medicines, blood type, other information and who to call. Every
/// caregiver sees it; admins edit it.
class MedicalIdPage extends ConsumerWidget {
  const MedicalIdPage({super.key, required this.spaceId, this.now});
  final String spaceId;

  /// For tests; the current time otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final c = ref.watch(familyProvider).value?.child(spaceId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.childGone)),
      );
    }
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final id = c.medicalId;
    final theme = Theme.of(context);
    final danger = theme.colorScheme.error;
    final meds = [
      for (final t in c.active(nowUtc))
        if (!t.isPaused && t.runsOn(c.today(nowUtc))) t,
    ];
    Widget section(
      IconData icon,
      String title,
      List<Widget> body, {
      Color? color,
    }) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...body,
        ],
      ),
    );
    Widget lines(List<String> items, {String? empty}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isEmpty && empty != null)
          Text(empty, style: theme.textTheme.bodyMedium),
        for (final s in items) Text(s, style: theme.textTheme.bodyLarge),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.medicalId),
        actions: [
          IconButton(
            tooltip: l.shareMedicalId,
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: medicalIdText(context, c, nowUtc)),
            ),
          ),
          if (c.isAdmin)
            IconButton(
              tooltip: l.editMedicalId,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MedicalIdEditorPage(c: c),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 32),
        children: [
          ListTile(
            leading: ChildAvatar(c.child, radius: 28),
            title: Text(c.child.name, style: theme.textTheme.titleLarge),
            subtitle: c.child.birthDate == null
                ? null
                : Text(l.bornOn(formatLocalDate(context, c.child.birthDate!))),
          ),
          if (id.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(l.medicalIdIntro),
            ),
          section(Icons.warning_amber_rounded, l.allergies, [
            lines(id.allergies, empty: l.noneRecorded),
          ], color: danger),
          section(Icons.monitor_heart_outlined, l.conditions, [
            lines(id.conditions, empty: l.noneRecorded),
          ]),
          section(Icons.medication_outlined, l.currentMedicines, [
            lines([
              for (final t in meds)
                l.insertMedScheduleText(
                  medicineWithDose(context, t.medication),
                  scheduleText(context, t),
                ),
            ], empty: l.noTreatments),
          ]),
          section(Icons.bloodtype_outlined, l.bloodType, [
            Text(
              id.bloodType.isEmpty ? l.bloodTypeUnknown : id.bloodType,
              style: theme.textTheme.bodyLarge,
            ),
          ]),
          if (id.notes.trim().isNotEmpty)
            section(Icons.info_outline, l.medicalNotes, [
              Text(id.notes.trim(), style: theme.textTheme.bodyLarge),
            ]),
          section(Icons.contact_phone_outlined, l.emergencyContacts, [
            if (id.contacts.isEmpty) Text(l.noneRecorded),
          ]),
          for (final x in id.contacts)
            ListTile(
              title: Text(x.name),
              subtitle: Text(x.phone, textDirection: TextDirection.ltr),
              trailing: x.phone.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.callContact(x.name),
                      icon: const Icon(Icons.call_outlined),
                      onPressed: () => launchUrl(
                        Uri(scheme: 'tel', path: x.phone.replaceAll(' ', '')),
                      ),
                    ),
            ),
          if (c.isAdmin && id.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MedicalIdEditorPage(c: c),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.editMedicalId),
              ),
            ),
        ],
      ),
    );
  }
}

class MedicalIdEditorPage extends ConsumerStatefulWidget {
  const MedicalIdEditorPage({super.key, required this.c});
  final ChildData c;

  @override
  ConsumerState<MedicalIdEditorPage> createState() =>
      _MedicalIdEditorPageState();
}

class _MedicalIdEditorPageState extends ConsumerState<MedicalIdEditorPage> {
  late final MedicalId _old = widget.c.medicalId;
  late String _blood = _old.bloodType;
  late final _allergies = TextEditingController(
    text: _old.allergies.join('\n'),
  );
  late final _conditions = TextEditingController(
    text: _old.conditions.join('\n'),
  );
  late final _notes = TextEditingController(text: _old.notes);
  late final List<(TextEditingController, TextEditingController)> _contacts = [
    for (final x in _old.contacts)
      (
        TextEditingController(text: x.name),
        TextEditingController(text: x.phone),
      ),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _allergies.dispose();
    _conditions.dispose();
    _notes.dispose();
    for (final (a, b) in _contacts) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  static List<String> _lines(String s) => [
    for (final x in s.split(RegExp(r'[\n,]')))
      if (x.trim().isNotEmpty) x.trim(),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    final id = MedicalId(
      bloodType: _blood,
      allergies: _lines(_allergies.text),
      conditions: _lines(_conditions.text),
      notes: _notes.text.trim(),
      contacts: [
        for (final (n, p) in _contacts)
          if (n.text.trim().isNotEmpty || p.text.trim().isNotEmpty)
            EmergencyContact(name: n.text.trim(), phone: p.text.trim()),
      ],
      extra: _old.extra,
    );
    try {
      await ref.read(medsActionsProvider).saveMedicalId(widget.c.spaceId, id);
      if (mounted) Navigator.of(context).pop();
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
        title: Text(l.editMedicalId),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.medicalIdIntro),
          const SizedBox(height: 16),
          TextField(
            key: const Key('allergies'),
            controller: _allergies,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.allergies,
              helperText: l.onePerLine,
              prefixIcon: const Icon(Icons.warning_amber_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('conditions'),
            controller: _conditions,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.conditions,
              helperText: l.onePerLine,
              prefixIcon: const Icon(Icons.monitor_heart_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: MedicalId.bloodTypes.contains(_blood) ? _blood : '',
            decoration: InputDecoration(
              labelText: l.bloodType,
              prefixIcon: const Icon(Icons.bloodtype_outlined),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(l.bloodTypeUnknown)),
              for (final b in MedicalId.bloodTypes)
                DropdownMenuItem(
                  value: b,
                  child: Text(b, textDirection: TextDirection.ltr),
                ),
            ],
            onChanged: (v) => setState(() => _blood = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('medicalNotes'),
            controller: _notes,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.medicalNotes,
              helperText: l.medicalNotesHint,
              prefixIcon: const Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.emergencyContacts,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (var i = 0; i < _contacts.length; i++)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _contacts[i].$1,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l.contactName),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _contacts[i].$2,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: l.contactPhone),
                  ),
                ),
                IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    final (a, b) = _contacts.removeAt(i);
                    a.dispose();
                    b.dispose();
                  }),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _contacts.add((
                  TextEditingController(),
                  TextEditingController(),
                )),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l.addEmergencyContact),
            ),
          ),
        ],
      ),
    );
  }
}
