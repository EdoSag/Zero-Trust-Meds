import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meds_data.dart';
import '../model/models.dart';
import '../reminders/reminders.dart';
import 'common.dart';

/// This account's reminder settings: on or off, follow-up, missed-dose
/// alert, last-day notice, names in the text, and which children.
class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final prefs = ref.watch(reminderPrefsProvider).value;
    final children = ref.watch(familyProvider).value?.children ?? const [];
    if (prefs == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.remindersTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    void save(ReminderPrefs p) => saveReminderPrefs(ref, p);
    final on = prefs.enabled;
    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l.remindersOn),
            subtitle: Text(l.remindersOnHint),
            value: on,
            onChanged: (v) async {
              save(prefs.copyWith(enabled: v));
              if (v) {
                await ref.read(reminderSchedulerProvider).requestPermission();
              }
            },
          ),
          ListTile(
            enabled: on,
            leading: const Icon(Icons.update),
            title: Text(l.followUp),
            subtitle: Text(l.followUpHint),
            trailing: DropdownButton<int>(
              value:
                  ReminderPrefs.followUpChoices.contains(prefs.followUpMinutes)
                  ? prefs.followUpMinutes
                  : 30,
              onChanged: on
                  ? (v) => save(prefs.copyWith(followUpMinutes: v ?? 0))
                  : null,
              items: [
                for (final m in ReminderPrefs.followUpChoices)
                  DropdownMenuItem(
                    value: m,
                    child: Text(m == 0 ? l.followUpOff : l.followUpAfter(m)),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.warning_amber_rounded),
            title: Text(l.missedAlerts),
            subtitle: Text(l.missedAlertsHint),
            value: prefs.missedAlerts,
            onChanged: on ? (v) => save(prefs.copyWith(missedAlerts: v)) : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.event_available_outlined),
            title: Text(l.lastDayNotice),
            subtitle: Text(l.lastDayNoticeHint),
            value: prefs.lastDayNotice,
            onChanged: on
                ? (v) => save(prefs.copyWith(lastDayNotice: v))
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime_outlined),
            title: Text(l.quietHours),
            subtitle: Text(
              prefs.hasQuietHours
                  ? l.quietHoursRange(
                      _format(context, prefs.quietFrom!),
                      _format(context, prefs.quietUntil!),
                    )
                  : l.quietHoursOff,
            ),
            value: prefs.hasQuietHours,
            onChanged: on
                ? (v) => save(
                    v
                        ? prefs.copyWith(
                            quietFrom: const TimeOfDose(22, 0),
                            quietUntil: const TimeOfDose(7, 0),
                          )
                        : prefs.copyWith(clearQuietHours: true),
                  )
                : null,
          ),
          if (on && prefs.hasQuietHours)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 56, end: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: l.quietHoursFrom,
                      time: prefs.quietFrom!,
                      onPicked: (t) => save(prefs.copyWith(quietFrom: t)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeButton(
                      label: l.quietHoursUntil,
                      time: prefs.quietUntil!,
                      onPicked: (t) => save(prefs.copyWith(quietUntil: t)),
                    ),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: Text(l.showNamesInReminders),
            subtitle: Text(l.showNamesInRemindersHint),
            value: prefs.showNames,
            onChanged: on ? (v) => save(prefs.copyWith(showNames: v)) : null,
          ),
          if (children.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                l.remindersForChildren,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final c in children)
              CheckboxListTile(
                title: Text(c.child.name),
                value: !prefs.mutedChildren.contains(c.spaceId),
                onChanged: on
                    ? (v) => save(
                        prefs.copyWith(
                          mutedChildren: v ?? true
                              ? ({...prefs.mutedChildren}..remove(c.spaceId))
                              : {...prefs.mutedChildren, c.spaceId},
                        ),
                      )
                    : null,
              ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.remindersHowTheyWork,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String _format(BuildContext context, TimeOfDose t) =>
    TimeOfDay(hour: t.hour, minute: t.minute).format(context);

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onPicked,
  });
  final String label;
  final TimeOfDose time;
  final ValueChanged<TimeOfDose> onPicked;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
    onPressed: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      );
      if (picked != null) onPicked(TimeOfDose(picked.hour, picked.minute));
    },
    child: Text('$label ${_format(context, time)}'),
  );
}
