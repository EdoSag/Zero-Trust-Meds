import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meds_data.dart';
import '../model/models.dart';
import 'common.dart';
import 'medicine_name_field.dart';
import 'dose_actions.dart';

/// Opens the one-time dose form for [spaceId] (or the first child).
Future<void> openOneTimeDose(BuildContext context, {String? spaceId}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OneTimeDosePage(spaceId: spaceId),
      ),
    );

/// Logs a medicine given once, outside any treatment: Nurofen for a fever,
/// a cream for a sting. Who it was given to, what, how much, when (now by
/// default) and why. Any caregiver can log one.
class OneTimeDosePage extends ConsumerStatefulWidget {
  const OneTimeDosePage({super.key, this.spaceId});

  /// The person it was given to; null lets the caregiver pick.
  final String? spaceId;

  @override
  ConsumerState<OneTimeDosePage> createState() => _OneTimeDosePageState();
}

class _OneTimeDosePageState extends ConsumerState<OneTimeDosePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _unit = TextEditingController();
  final _reason = TextEditingController();
  late String? _spaceId = widget.spaceId;
  MedForm _formKind = MedForm.other;
  String _medId = '';

  /// Null: now, when Log is pressed.
  DateTime? _at;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _unit.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _pick(Medication m) => setState(() {
    _medId = m.id;
    _name.text = m.name;
    _formKind = m.form;
    // Plain digits, no grouping: "1,000" would be read back as 1.
    _amount.text = m.amount == null ? '' : _plain(m.amount!);
    _unit.text = m.unit;
  });

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Medicines to pick from: the family list, this person's medicines and
  /// those given once before, each once.
  List<Medication> _suggestions(FamilyData family, ChildData c) {
    final seen = <String, Medication>{};
    for (final m in [
      for (final l in c.oneTimeLogs) l.medication!,
      ...c.medications,
      ...family.medications,
    ]) {
      seen.putIfAbsent(m.name.trim().toLowerCase(), () => m);
    }
    return seen.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _save(ChildData c) async {
    if (!_form.currentState!.validate()) return;
    final l = context.l;
    setState(() => _saving = true);
    final actions = ref.read(medsActionsProvider);
    final name = _name.text.trim();
    try {
      final log = await actions.logOneTimeDose(
        c,
        medication: Medication(
          id: _medId,
          name: name,
          form: _formKind,
          amount: double.tryParse(_amount.text.replaceAll(',', '.')),
          unit: _unit.text.trim(),
        ),
        at: _at ?? DateTime.now().toUtc(),
        reason: _reason.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l.loggedGiven(name, c.child.name)),
            duration: const Duration(seconds: 6),
            persist: false,
            action: SnackBarAction(
              label: l.undo,
              onPressed: () => actions.deleteLog(c, log),
            ),
          ),
        );
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
    final children = family?.children ?? const <ChildData>[];
    // A person picked (or passed in) who is gone now: never fall back to
    // someone else, or the dose would land in their history.
    final c = _spaceId == null
        ? children.firstOrNull
        : family?.child(_spaceId!);
    if (family == null || c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.childGone)),
      );
    }
    final suggestions = _suggestions(family, c);
    final at = _at ?? DateTime.now().toUtc();
    final last = c.lastGivenNamed(_name.text, at);
    final reasons = [l.reasonFever, l.reasonPain, l.reasonCold];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.oneTimeDoseTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(c),
            child: Text(l.logDose),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.logOneTimeDoseHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (children.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: c.spaceId,
                decoration: InputDecoration(labelText: l.doseFor),
                items: [
                  for (final x in children)
                    DropdownMenuItem(
                      value: x.spaceId,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChildAvatar(x.child, radius: 12),
                          const SizedBox(width: 8),
                          Text(x.child.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _spaceId = v),
              ),
              const SizedBox(height: 16),
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ChildAvatar(c.child),
                title: Text(c.child.name),
                subtitle: Text(l.doseFor),
              ),
            Text(l.medicine, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (suggestions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in suggestions)
                    ChoiceChip(
                      label: Text(
                        m.amount == null && m.unit.isEmpty
                            ? m.name
                            : '${m.name} · ${doseText(context, m)}',
                      ),
                      selected:
                          m.name.trim().toLowerCase() ==
                          _name.text.trim().toLowerCase(),
                      onSelected: (_) => _pick(m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            MedicineNameField(
              fieldKey: const Key('oneTimeName'),
              controller: _name,
              family: suggestions,
              onChanged: () => setState(() => _medId = ''),
              onSaved: _pick,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('oneTimeAmount'),
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
                    key: const Key('oneTimeUnit'),
                    controller: _unit,
                    decoration: InputDecoration(
                      labelText: l.doseUnit,
                      hintText: l.formUnit(_formKind.name),
                    ),
                  ),
                ),
              ],
            ),
            if (last != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text(
                    l.lastGivenNamed(
                      c.medicineOf(last)?.name ?? _name.text.trim(),
                      c.nameOf(last.byUserId),
                      formatWhen(context, last.at),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(l.givenAtTime),
              subtitle: Text(
                _at == null ? l.givenNow : formatWhen(context, _at!),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await pickDoseTime(context, at);
                if (picked != null) setState(() => _at = picked);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in reasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: _reason.text.trim() == r,
                    onSelected: (_) => setState(() => _reason.text = r),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('oneTimeReason'),
              controller: _reason,
              decoration: InputDecoration(labelText: l.doseReason),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(c),
              icon: const Icon(Icons.check),
              label: Text(l.logDose),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-time dose in a today list or history: medicine, amount, who gave
/// it when, and why. Tapping it offers changing the time or undoing it.
class OneTimeDoseRow extends ConsumerWidget {
  const OneTimeDoseRow(this.c, this.log, {super.key, this.showDay = false});
  final ChildData c;
  final DoseLog log;

  /// Show the day as well as the time (for lists beyond today).
  final bool showDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final m = log.medication!;
    final when = showDay
        ? formatWhen(context, log.at)
        : formatTime(context, log.at);
    return ListTile(
      dense: true,
      leading: const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
      title: Text(
        m.amount == null && m.unit.isEmpty
            ? m.name
            : '${m.name} · ${doseText(context, m)}',
      ),
      subtitle: Text(
        [
          l.oneTime,
          l.givenBy(c.nameOf(log.byUserId), when),
          if (log.reason.isNotEmpty) log.reason,
        ].join(' · '),
      ),
      onTap: () => showOneTimeDoseSheet(context, ref, c, log),
    );
  }
}

Future<void> showOneTimeDoseSheet(
  BuildContext context,
  WidgetRef ref,
  ChildData c,
  DoseLog log,
) {
  final l = context.l;
  final actions = ref.read(medsActionsProvider);
  final m = log.medication!;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              m.amount == null && m.unit.isEmpty
                  ? m.name
                  : '${m.name} · ${doseText(ctx, m)}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            subtitle: Text(
              [
                l.oneTime,
                l.givenBy(c.nameOf(log.byUserId), formatWhen(ctx, log.at)),
                if (log.reason.isNotEmpty) log.reason,
              ].join(' · '),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: Text(l.changeTime),
            onTap: () async {
              Navigator.pop(ctx);
              final at = await pickDoseTime(context, log.at);
              if (at != null) await actions.updateLog(c, log.copyWith(at: at));
            },
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: Text(l.undoRecord),
            onTap: () {
              Navigator.pop(ctx);
              unawaited(actions.deleteLog(c, log));
              showSnack(
                context,
                l.recordRemoved,
                actionLabel: l.undo,
                onAction: () => actions.updateLog(c, log),
              );
            },
          ),
        ],
      ),
    ),
  );
}
