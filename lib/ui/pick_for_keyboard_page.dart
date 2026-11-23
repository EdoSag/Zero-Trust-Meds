import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meds_data.dart';
import '../model/models.dart';
import 'child_page.dart' show scheduleText;
import 'common.dart';

/// One thing ZT Keyboard can type: what it is and the text.
typedef PickValue = ({IconData icon, String label, String text});

/// The medicine with its dose: "Amoxicillin 5 ml".
String medicineWithDose(BuildContext context, Medication m) {
  final dose = doseText(context, m);
  return dose.isEmpty ? m.name.trim() : '${m.name.trim()} $dose';
}

/// The last dose of [t]'s medicine that was given, if any: from the
/// treatment, or a one-time dose of the same medicine (as the dose checks
/// count them).
DoseLog? lastGiven(ChildData c, Treatment t) {
  DoseLog? last;
  for (final l in c.guardLogsOf(t)) {
    if (l.action != DoseAction.given) continue;
    if (last == null || l.at.isAfter(last.at)) last = l;
  }
  return last;
}

/// What one treatment can hand to the keyboard.
List<PickValue> treatmentValues(
  BuildContext context,
  ChildData c,
  Treatment t,
) {
  final l = context.l;
  final m = t.medication;
  final withDose = medicineWithDose(context, m);
  final last = lastGiven(c, t);
  return [
    if (m.name.trim().isNotEmpty)
      (
        icon: Icons.medication_outlined,
        label: l.insertMedName,
        text: m.name.trim(),
      ),
    if (withDose != m.name.trim())
      (
        icon: Icons.medication_liquid_outlined,
        label: l.insertMedDose,
        text: withDose,
      ),
    (
      icon: Icons.schedule,
      label: l.insertMedSchedule,
      text: l.insertMedScheduleText(withDose, scheduleText(context, t)),
    ),
    if (last != null)
      (
        icon: Icons.check_circle_outline,
        label: l.insertMedLastGiven,
        // A one-time dose says its own amount.
        text: l.insertMedLastGivenText(
          medicineWithDose(context, c.medicineOf(last) ?? m),
          formatWhen(context, last.at),
        ),
      ),
    if (m.notes.trim().isNotEmpty)
      (icon: Icons.notes, label: l.insertMedNotes, text: m.notes.trim()),
  ];
}

/// The treatments of [c] running today: started, not finished (paused
/// ones included).
List<Treatment> running(ChildData c, DateTime nowUtc) {
  final today = c.today(nowUtc);
  return [
    for (final t in c.active(nowUtc))
      if (t.startDate.compareTo(today) <= 0) t,
  ];
}

/// Every running medicine of [c], one per line with its dose and times,
/// for a form or a message to the doctor.
String medicineList(BuildContext context, ChildData c, DateTime nowUtc) => [
  for (final t in running(c, nowUtc))
    context.l.insertMedScheduleText(
      medicineWithDose(context, t.medication),
      scheduleText(context, t),
    ),
].join('\n');

/// Opened by ZT Keyboard's "Insert from ZT apps" key, once the vault is
/// unlocked: the user taps a medicine and then what to type of it, or a
/// person's whole medicine list. Pops with that text, or with nothing when
/// the user goes back. Only the tapped text leaves the app.
class PickForKeyboardPage extends ConsumerStatefulWidget {
  const PickForKeyboardPage({super.key, this.now});

  /// For tests; the current time otherwise.
  final DateTime? now;

  @override
  ConsumerState<PickForKeyboardPage> createState() =>
      _PickForKeyboardPageState();
}

class _PickForKeyboardPageState extends ConsumerState<PickForKeyboardPage> {
  void _send(String text) => Navigator.of(context).pop(text);

  Future<void> _choose(List<PickValue> values) async {
    if (values.isEmpty) return;
    if (values.length == 1) return _send(values.single.text);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final v in values)
                ListTile(
                  leading: Icon(v.icon),
                  title: Text(
                    v.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(v.label),
                  onTap: () => Navigator.of(sheet).pop(v.text),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _send(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final nowUtc = (widget.now ?? DateTime.now()).toUtc();
    final family = ref.watch(familyProvider);
    final children = family.value?.children ?? const <ChildData>[];
    final withMeds = [
      for (final c in children)
        if (running(c, nowUtc).isNotEmpty) c,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.insertIntoKeyboard)),
      body: family.isLoading && children.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
                  child: Text(l.insertPickMedHint),
                ),
                if (withMeds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l.insertNoMedicines,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                for (final c in withMeds) ...[
                  ListTile(
                    title: Text(
                      c.child.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: Text(l.insertMedList),
                    subtitle: Text(
                      medicineList(context, c, nowUtc),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _send(medicineList(context, c, nowUtc)),
                  ),
                  for (final t in running(c, nowUtc))
                    ListTile(
                      leading: const Icon(Icons.medication_outlined),
                      title: Text(medicineWithDose(context, t.medication)),
                      subtitle: Text(
                        scheduleText(context, t),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _choose(treatmentValues(context, c, t)),
                    ),
                  const Divider(),
                ],
              ],
            ),
    );
  }
}
