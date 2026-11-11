import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meds_data.dart';
import '../model/models.dart';
import 'common.dart';
import 'home_page.dart';

/// Sets up (or changes) a course of one medicine for a child: which
/// medicine, when each day, from which day and for how many days.
class TreatmentEditorPage extends ConsumerStatefulWidget {
  const TreatmentEditorPage({super.key, required this.spaceId, this.existing});
  final String spaceId;
  final Treatment? existing;

  @override
  ConsumerState<TreatmentEditorPage> createState() =>
      _TreatmentEditorPageState();
}

class _TreatmentEditorPageState extends ConsumerState<TreatmentEditorPage> {
  final _form = GlobalKey<FormState>();
  late final Treatment? _t = widget.existing;
  late final _medName = TextEditingController(text: _t?.medication.name);
  late final _amount = TextEditingController(
    text: _t?.medication.amount == null ? '' : _trim(_t!.medication.amount!),
  );
  late final _unit = TextEditingController(text: _t?.medication.unit);
  late final _notes = TextEditingController(text: _t?.medication.notes);
  late MedForm _formKind = _t?.medication.form ?? MedForm.liquid;
  late bool _asNeeded = _t?.schedule is AsNeeded;
  late List<TimeOfDose> _times = switch (_t?.schedule) {
    FixedTimes(:final times) => [...times],
    _ => TimeSlot.defaultsFor(2),
  };
  late final _interval = TextEditingController(
    text: switch (_t?.schedule) {
      AsNeeded(:final minIntervalMinutes) => _trim(minIntervalMinutes / 60),
      _ => '6',
    },
  );
  late final _max = TextEditingController(
    text: switch (_t?.schedule) {
      AsNeeded(:final maxPer24h) => maxPer24h?.toString() ?? '',
      _ => '4',
    },
  );
  late final _days = TextEditingController(
    text: _t == null ? '7' : _t.days?.toString() ?? '',
  );
  LocalDate? _start;
  bool _saving = false;

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [
      _medName,
      _amount,
      _unit,
      _notes,
      _interval,
      _max,
      _days,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickFromList(Medication m) => setState(() {
    _medName.text = m.name;
    _amount.text = m.amount == null ? '' : _trim(m.amount!);
    _unit.text = m.unit;
    _notes.text = m.notes;
    _formKind = m.form;
  });

  Future<void> _save(ChildData c) async {
    if (!_form.currentState!.validate()) return;
    final l = context.l;
    final DoseSchedule schedule;
    if (_asNeeded) {
      final hours = double.tryParse(_interval.text.replaceAll(',', '.')) ?? 0;
      schedule = AsNeeded(
        minIntervalMinutes: (hours * 60).round(),
        maxPer24h: int.tryParse(_max.text),
      );
    } else {
      if (_times.isEmpty) {
        showSnack(context, l.addATime);
        return;
      }
      schedule = FixedTimes([..._times]..sort());
    }
    setState(() => _saving = true);
    final start = _start ?? _t?.startDate ?? c.today(DateTime.now().toUtc());
    final days = int.tryParse(_days.text);
    final t = Treatment(
      id: _t?.id ?? '',
      medication: Medication(
        id: _t?.medication.id ?? '',
        name: _medName.text.trim(),
        form: _formKind,
        amount: double.tryParse(_amount.text.replaceAll(',', '.')),
        unit: _unit.text.trim(),
        notes: _notes.text.trim(),
      ),
      schedule: schedule,
      startDate: start,
      days: days != null && days > 0 ? days : null,
      pauses: _t?.pauses ?? const [],
      endedOn: _t?.endedOn,
    );
    try {
      final fromTomorrow = await ref
          .read(medsActionsProvider)
          .saveTreatment(c, t, c.today(DateTime.now().toUtc()));
      if (!mounted) return;
      if (fromTomorrow) showSnack(context, l.newTimesFromTomorrow);
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, l.saveFailedOffline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final family = ref.watch(familyProvider).value;
    final c = family?.child(widget.spaceId);
    if (family == null || c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.childGone)),
      );
    }
    final start = _start ?? _t?.startDate ?? c.today(readNow(ref));
    final days = int.tryParse(_days.text);
    final meds = family.medications;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t == null ? l.addTreatmentFor(c.child.name) : l.editTreatment,
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(c),
            child: Text(l.save),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.medicine, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (meds.isNotEmpty && _t == null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in meds)
                    ChoiceChip(
                      label: Text('${m.name} · ${doseText(context, m)}'),
                      selected:
                          m.name == _medName.text.trim() && m.form == _formKind,
                      onSelected: (_) => _pickFromList(m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _medName,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.medicineName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l.required : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MedForm>(
              initialValue: _formKind,
              decoration: InputDecoration(labelText: l.medicineForm),
              items: [
                for (final f in MedForm.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text(formLabel(context, f)),
                  ),
              ],
              onChanged: (f) => setState(() => _formKind = f ?? _formKind),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(labelText: l.doseAmount),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: InputDecoration(
                      labelText: l.doseUnit,
                      hintText: l.formUnit(_formKind.name),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: InputDecoration(
                labelText: l.medicineNotes,
                hintText: l.medicineNotesHint,
              ),
            ),
            const SizedBox(height: 24),
            Text(l.when, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.fixedTimes)),
                ButtonSegment(value: true, label: Text(l.asNeeded)),
              ],
              selected: {_asNeeded},
              onSelectionChanged: (s) => setState(() => _asNeeded = s.first),
            ),
            const SizedBox(height: 12),
            if (!_asNeeded) ...[
              Row(
                children: [
                  Expanded(child: Text(l.timesPerDay(_times.length))),
                  IconButton(
                    tooltip: l.fewerTimes,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _times.length <= 1
                        ? null
                        : () => setState(
                            () => _times = TimeSlot.defaultsFor(
                              _times.length - 1,
                            ),
                          ),
                  ),
                  IconButton(
                    tooltip: l.moreTimes,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _times.length >= 8
                        ? null
                        : () => setState(
                            () => _times = TimeSlot.defaultsFor(
                              _times.length + 1,
                            ),
                          ),
                  ),
                ],
              ),
              for (var i = 0; i < _times.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay(hour: _times[i].hour, minute: _times[i].minute),
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                  ),
                  subtitle: Text(slotLabel(context, TimeSlot.of(_times[i]))),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _times[i].hour,
                        minute: _times[i].minute,
                      ),
                    );
                    if (picked != null) {
                      setState(
                        () =>
                            _times[i] = TimeOfDose(picked.hour, picked.minute),
                      );
                    }
                  },
                ),
              Text(
                l.timesInZone(c.child.timeZone),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _interval,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: l.minHoursBetween),
                      validator: (v) =>
                          double.tryParse((v ?? '').replaceAll(',', '.')) ==
                              null
                          ? l.required
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l.maxPer24h,
                        hintText: l.optional,
                      ),
                      validator: (v) =>
                          v != null &&
                              v.isNotEmpty &&
                              (int.tryParse(v) ?? 0) < 1
                          ? l.atLeastOne
                          : null,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(l.howLong, style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l.startDate),
              subtitle: Text(formatLocalDate(context, start)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(start.year, start.month, start.day),
                  firstDate: DateTime(start.year - 1),
                  lastDate: DateTime(start.year + 1, 12, 31),
                );
                if (picked != null) {
                  setState(() => _start = LocalDate.of(picked));
                }
              },
            ),
            TextFormField(
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.numberOfDays,
                helperText: days != null && days > 0
                    ? l.lastDayIs(
                        formatLocalDate(context, start.addDays(days - 1)),
                      )
                    : l.ongoing,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
