import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meds_data.dart';
import '../logic/dose_logic.dart';
import '../model/models.dart';
import 'common.dart';

/// Logs [treatment] as given now (for [slot] when it's a planned dose).
/// Warns first about a double dose or an as-needed dose too soon, and
/// offers Undo after.
Future<void> giveDose(
  BuildContext context,
  WidgetRef ref,
  ChildData c,
  Treatment treatment, {
  PlannedDose? slot,
  DateTime? at,
}) async {
  final when = (at ?? DateTime.now()).toUtc();
  final warnings = DoseGuard.beforeGiving(
    t: treatment,
    logs: c.logsOf(treatment.id),
    at: when,
    slot: slot,
  );
  if (warnings.isNotEmpty) {
    if (!context.mounted) return;
    final ok = await _confirmWarnings(context, c, treatment, warnings);
    if (!ok) return;
  }
  final actions = ref.read(medsActionsProvider);
  final log = await actions.logDose(
    c,
    treatment: treatment,
    at: when,
    slot: slot,
  );
  if (!context.mounted) return;
  showSnack(
    context,
    context.l.loggedGiven(treatment.medication.name, c.child.name),
    actionLabel: context.l.undo,
    onAction: () => actions.deleteLog(c, log),
  );
}

Future<bool> _confirmWarnings(
  BuildContext context,
  ChildData c,
  Treatment t,
  List<DoseWarning> warnings,
) async {
  final l = context.l;
  final lines = <String>[
    for (final w in warnings)
      switch (w) {
        AlreadyGiven(:final logs) => l.warnAlreadyGiven(
          c.nameOf(logs.last.byUserId),
          formatWhen(context, logs.last.at),
        ),
        TooSoon(:final last, :final nextAllowed) => l.warnTooSoon(
          formatWhen(context, last.at),
          formatWhen(context, nextAllowed),
        ),
        MaxReached(:final count, :final nextAllowed) => l.warnMaxReached(
          count,
          formatWhen(context, nextAllowed),
        ),
      },
  ];
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, size: 36),
      title: Text(l.warnTitle(t.medication.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Text(line),
            ),
          Text(l.warnCheck, style: Theme.of(ctx).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.dontGive),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: Text(l.giveAnyway),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Picks a time today (or earlier) on this phone's clock.
Future<DateTime?> pickDoseTime(
  BuildContext context,
  DateTime initialUtc,
) async {
  final local = initialUtc.toLocal();
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: local.isAfter(now) ? now : local,
    firstDate: now.subtract(const Duration(days: 60)),
    lastDate: now,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(local),
  );
  if (time == null) return null;
  final picked = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  return (picked.isAfter(now) ? now : picked).toUtc();
}

Future<String?> askSkipReason(BuildContext context) {
  final l = context.l;
  final controller = TextEditingController();
  final reasons = [
    l.reasonAsleep,
    l.reasonVomited,
    l.reasonRefused,
    l.reasonDoctor,
  ];
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.skipTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final r in reasons)
                  ActionChip(
                    label: Text(r),
                    onPressed: () => setState(() => controller.text = r),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: l.skipReason),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l.skip),
          ),
        ],
      ),
    ),
  );
}

/// Everything that can be done with one planned dose: give, give at
/// another time, skip, and for records already made, change the time or
/// undo. Shows who logged what.
Future<void> showDoseSheet(
  BuildContext context,
  WidgetRef ref,
  ChildData c,
  DoseStatus status,
) {
  final l = context.l;
  final t = status.dose.treatment;
  final actions = ref.read(medsActionsProvider);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              '${t.medication.name} · ${doseText(ctx, t.medication)}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            subtitle: Text(
              l.plannedFor(c.child.name, formatWhen(ctx, status.dose.at)),
            ),
            trailing: StatusChip(status.state, twice: status.givenTwice),
          ),
          if (t.medication.notes.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(t.medication.notes),
            ),
          for (final log in status.logs)
            ListTile(
              leading: Icon(log.given ? Icons.check : Icons.block),
              title: Text(
                log.given
                    ? l.givenBy(c.nameOf(log.byUserId), formatWhen(ctx, log.at))
                    : l.skippedBy(
                        c.nameOf(log.byUserId),
                        formatWhen(ctx, log.at),
                      ),
              ),
              subtitle: log.reason.isEmpty ? null : Text(log.reason),
              trailing: PopupMenuButton<String>(
                tooltip: l.more,
                onSelected: (v) async {
                  Navigator.pop(ctx);
                  if (v == 'time') {
                    final at = await pickDoseTime(context, log.at);
                    if (at != null) {
                      await actions.updateLog(c, log.copyWith(at: at));
                    }
                  } else if (v == 'undo') {
                    await actions.deleteLog(c, log);
                    if (context.mounted) {
                      showSnack(
                        context,
                        l.recordRemoved,
                        actionLabel: l.undo,
                        onAction: () => actions.updateLog(c, log),
                      );
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'time', child: Text(l.changeTime)),
                  PopupMenuItem(value: 'undo', child: Text(l.undoRecord)),
                ],
              ),
            ),
          if (status.state != DoseState.paused) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(status.givenLogs.isEmpty ? l.markGiven : l.giveAgain),
              onTap: () {
                Navigator.pop(ctx);
                giveDose(context, ref, c, t, slot: status.dose);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(l.givenAtOtherTime),
              onTap: () async {
                Navigator.pop(ctx);
                final at = await pickDoseTime(context, status.dose.at);
                if (at != null && context.mounted) {
                  await giveDose(context, ref, c, t, slot: status.dose, at: at);
                }
              },
            ),
            if (status.logs.isEmpty)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l.skipDose),
                onTap: () async {
                  Navigator.pop(ctx);
                  final reason = await askSkipReason(context);
                  if (reason == null) return;
                  await actions.logDose(
                    c,
                    treatment: t,
                    at: DateTime.now(),
                    slot: status.dose,
                    action: DoseAction.skipped,
                    reason: reason,
                  );
                },
              ),
          ],
        ],
      ),
    ),
  );
}
