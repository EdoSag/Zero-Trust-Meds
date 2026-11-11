import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/meds_data.dart';
import '../l10n/generated/app_localizations.dart';
import '../model/models.dart';
import '../ui/common.dart';
import 'reminder_plan.dart';
import 'reminder_scheduler.dart';

export 'reminder_plan.dart';
export 'reminder_scheduler.dart';

/// This account's reminder settings (see [ReminderPrefs]).
final reminderPrefsProvider = FutureProvider<ReminderPrefs>((ref) async {
  ref.watch(medsRevisionProvider);
  ref.watch(ztSyncControllerProvider);
  final store = await ref.watch(ztLocalStoreProvider.future);
  final item = await store.get(ReminderPrefs.itemId);
  return ReminderPrefs.fromJson(
    item == null || item.deleted ? null : item.json,
  );
});

Future<void> saveReminderPrefs(WidgetRef ref, ReminderPrefs prefs) async {
  await ref
      .read(ztSyncControllerProvider.notifier)
      .save(ReminderPrefs.itemId, prefs.toJson());
  ref.read(medsRevisionProvider.notifier).bump();
}

/// Asks for notification permission once there's something to remind
/// about, the way the other Zero-Trust apps do.
Future<void> askReminderPermission(WidgetRef ref) async {
  try {
    final prefs = await ref.read(reminderPrefsProvider.future);
    if (!prefs.enabled) return;
    await ref.read(reminderSchedulerProvider).requestPermission();
  } on Object {
    // No notifications on this platform: nothing to ask.
  }
}

/// Reminder text from the app's strings, with times on this phone's clock.
class L10nReminderTexts implements ReminderTexts {
  L10nReminderTexts(this.context) : l = context.l;
  final BuildContext context;
  final AppL10n l;

  @override
  String doseTitle(String child, String medicine) =>
      l.reminderDoseTitle(child, medicine);
  @override
  String doseBody(String dose, String time) => l.reminderDoseBody(dose, time);
  @override
  String followUpTitle(String child, String medicine) =>
      l.reminderFollowUpTitle(child, medicine);
  @override
  String followUpBody(String time) => l.reminderFollowUpBody(time);
  @override
  String missedTitle(String child, String medicine) =>
      l.reminderMissedTitle(child, medicine);
  @override
  String missedBody(String time) => l.reminderMissedBody(time);
  @override
  String lastDayTitle(String child, String medicine) =>
      l.reminderLastDayTitle(child, medicine);
  @override
  String get lastDayBody => l.reminderLastDayBody;
  @override
  String get privateTitle => l.reminderPrivateTitle;
  @override
  String get privateBody => l.reminderPrivateBody;
  @override
  String doseOf(Medication m) => doseText(context, m);
  @override
  String timeOf(DateTime utc) => formatTime(context, utc);

  ReminderChannelTexts get channel => ReminderChannelTexts(
    channelName: l.reminderChannel,
    channelDescription: l.reminderChannelHint,
    markGiven: l.markGiven,
  );
}
