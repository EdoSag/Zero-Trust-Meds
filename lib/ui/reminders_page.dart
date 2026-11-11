import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meds_data.dart';
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
