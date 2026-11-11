import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/meds_data.dart';
import '../logic/dose_logic.dart';
import '../model/models.dart';

/// How this account wants to be reminded. Kept encrypted in the app's own
/// vault, so all the account's phones remind the same way; each caregiver
/// has their own.
@immutable
class ReminderPrefs {
  const ReminderPrefs({
    this.enabled = true,
    this.followUpMinutes = 30,
    this.missedAlerts = true,
    this.lastDayNotice = true,
    this.showNames = true,
    this.mutedChildren = const {},
  });

  factory ReminderPrefs.fromJson(Map<String, Object?>? j) => ReminderPrefs(
    enabled: j?['enabled'] as bool? ?? true,
    followUpMinutes: (j?['followUpMinutes'] as num?)?.toInt() ?? 30,
    missedAlerts: j?['missedAlerts'] as bool? ?? true,
    lastDayNotice: j?['lastDayNotice'] as bool? ?? true,
    showNames: j?['showNames'] as bool? ?? true,
    mutedChildren: {
      for (final s in (j?['mutedChildren'] as List?) ?? const [])
        if (s is String) s,
    },
  );

  static const itemId = 'meds.reminders';

  /// Choices offered for the follow-up; 0 is off.
  static const followUpChoices = [0, 15, 30, 60];

  final bool enabled;

  /// A second reminder this long after a dose that isn't logged yet; 0 is
  /// off. Only sent while the dose is still due, not once it's missed.
  final int followUpMinutes;

  /// An alert when a dose turns missed (the child's "missed after" time).
  final bool missedAlerts;

  /// A notice on the morning of a course's last day.
  final bool lastDayNotice;

  /// Child and medicine names in the notification. Off: "Medicine
  /// reminder", and the names stay in the app. The lock screen never shows
  /// the text either way.
  final bool showNames;

  /// Children (space ids) this account gets no reminders for.
  final Set<String> mutedChildren;

  ReminderPrefs copyWith({
    bool? enabled,
    int? followUpMinutes,
    bool? missedAlerts,
    bool? lastDayNotice,
    bool? showNames,
    Set<String>? mutedChildren,
  }) => ReminderPrefs(
    enabled: enabled ?? this.enabled,
    followUpMinutes: followUpMinutes ?? this.followUpMinutes,
    missedAlerts: missedAlerts ?? this.missedAlerts,
    lastDayNotice: lastDayNotice ?? this.lastDayNotice,
    showNames: showNames ?? this.showNames,
    mutedChildren: mutedChildren ?? this.mutedChildren,
  );

  Map<String, Object?> toJson() => {
    'kind': itemId,
    'enabled': enabled,
    'followUpMinutes': followUpMinutes,
    'missedAlerts': missedAlerts,
    'lastDayNotice': lastDayNotice,
    'showNames': showNames,
    'mutedChildren': mutedChildren.toList()..sort(),
  };
}

enum ReminderKind { dose, followUp, missed, lastDay }

/// The words a reminder uses, in the reader's language. Built on this
/// phone, so each caregiver reads their own language and clock.
abstract interface class ReminderTexts {
  String doseTitle(String child, String medicine);
  String doseBody(String dose, String time);
  String followUpTitle(String child, String medicine);
  String followUpBody(String time);
  String missedTitle(String child, String medicine);
  String missedBody(String time);
  String lastDayTitle(String child, String medicine);
  String get lastDayBody;

  /// Used instead of the titles above when names are hidden.
  String get privateTitle;
  String get privateBody;

  /// "5 ml" for a medicine.
  String doseOf(Medication m);

  /// A UTC instant on this phone's clock ("08:00").
  String timeOf(DateTime utc);
}

/// One notification the OS should show at [at].
@immutable
class MedsReminder {
  const MedsReminder({
    required this.kind,
    required this.spaceId,
    required this.treatmentId,
    required this.at,
    required this.title,
    required this.body,
    this.date,
    this.time,
  });

  final ReminderKind kind;
  final String spaceId;
  final String treatmentId;

  /// The planned dose it's about (none for a last-day notice).
  final LocalDate? date;
  final TimeOfDose? time;

  /// UTC.
  final DateTime at;
  final String title;
  final String body;

  /// "Mark as given" is offered for a dose that can still be given.
  bool get offersGiven => kind != ReminderKind.lastDay;

  String get key =>
      '${kind.name}|$spaceId|$treatmentId|${date ?? ''}|${time ?? ''}|'
      '${at.toUtc().toIso8601String()}';

  int get notificationId => idFor(key);

  /// FNV-1a, so the id is the same on every run (String.hashCode isn't).
  static int idFor(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  /// Only ids reach the OS besides the shown text: enough to find the dose
  /// once the app is unlocked.
  String get payload => ReminderTarget(
    spaceId: spaceId,
    treatmentId: treatmentId,
    date: date,
    time: time,
  ).encode();

  @override
  bool operator ==(Object other) =>
      other is MedsReminder &&
      other.key == key &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(key, title, body);

  @override
  String toString() => 'MedsReminder($key, $title, $body)';
}

/// What a reminder points at, read back from a tap or a button.
@immutable
class ReminderTarget {
  const ReminderTarget({
    required this.spaceId,
    required this.treatmentId,
    this.date,
    this.time,
    this.markGiven = false,
  });

  final String spaceId;
  final String treatmentId;
  final LocalDate? date;
  final TimeOfDose? time;

  /// "Mark as given" was pressed (not just a tap on the reminder).
  final bool markGiven;

  ReminderTarget withMarkGiven() => ReminderTarget(
    spaceId: spaceId,
    treatmentId: treatmentId,
    date: date,
    time: time,
    markGiven: true,
  );

  String encode() => jsonEncode({
    's': spaceId,
    't': treatmentId,
    if (date != null) 'd': date.toString(),
    if (time != null) 'h': time.toString(),
  });

  static ReminderTarget? parse(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final m = jsonDecode(payload) as Map<String, Object?>;
      final s = m['s'], t = m['t'], d = m['d'], h = m['h'];
      if (s is! String || t is! String) return null;
      return ReminderTarget(
        spaceId: s,
        treatmentId: t,
        date: d is String ? LocalDate.parse(d) : null,
        time: h is String ? TimeOfDose.parse(h) : null,
      );
    } on Object {
      return null;
    }
  }
}

abstract final class ReminderPlan {
  /// Dose reminders and last-day notices are set this far ahead, so they
  /// keep coming while the app stays closed.
  static const horizon = Duration(days: 14);

  /// Android keeps at most 500 alarms per app.
  static const max = 400;

  /// Last-day notices come at this time in the child's zone.
  static const lastDayAt = TimeOfDose(9, 0);

  /// The reminders this phone should hold now, soonest first.
  ///
  /// A dose already answered (given or skipped) on this phone's copy gets
  /// none; another caregiver's record cancels them once it syncs here. A
  /// paused course gets none for the paused time.
  static List<MedsReminder> plan(
    Iterable<ChildData> children,
    ReminderPrefs prefs,
    ReminderTexts texts,
    DateTime nowUtc,
  ) {
    if (!prefs.enabled) return const [];
    final until = nowUtc.add(horizon);
    final out = <MedsReminder>[];
    for (final c in children) {
      if (prefs.mutedChildren.contains(c.spaceId)) continue;
      final today = c.today(nowUtc);
      // Yesterday too: a late-night dose's follow-up or missed alert can
      // fall after midnight.
      final from = today.addDays(-1);
      final to = ChildClock.today(c.zone, until);
      for (final t in c.treatments) {
        if (t.lastDay != null && t.lastDay!.isBefore(from)) continue;
        final child = c.child.name;
        final med = t.medication.name;
        String title(String Function(String, String) named) =>
            prefs.showNames ? named(child, med) : texts.privateTitle;
        String body(String text) => prefs.showNames ? text : texts.privateBody;
        MedsReminder make(
          ReminderKind kind,
          DateTime at,
          String title,
          String body, [
          PlannedDose? d,
        ]) => MedsReminder(
          kind: kind,
          spaceId: c.spaceId,
          treatmentId: t.id,
          date: d?.date,
          time: d?.time,
          at: at,
          title: title,
          body: body,
        );

        final logs = c.logsOf(t.id);
        for (final d in ChildClock.planned(t, c.zone, from, to)) {
          if (t.pausedAt(d.at) || logs.any(d.answeredBy)) continue;
          final time = texts.timeOf(d.at);
          void add(ReminderKind kind, DateTime at, String ttl, String bdy) {
            if (at.isAfter(nowUtc) && at.isBefore(until)) {
              out.add(make(kind, at, ttl, bdy, d));
            }
          }

          add(
            ReminderKind.dose,
            d.at,
            title(texts.doseTitle),
            body(texts.doseBody(texts.doseOf(t.medication), time)),
          );
          final followUp = Duration(minutes: prefs.followUpMinutes);
          if (followUp > Duration.zero && followUp < c.missedAfter) {
            add(
              ReminderKind.followUp,
              d.at.add(followUp),
              title(texts.followUpTitle),
              body(texts.followUpBody(time)),
            );
          }
          if (prefs.missedAlerts) {
            add(
              ReminderKind.missed,
              DoseRules.missedAt(d, c.missedAfter),
              title(texts.missedTitle),
              body(texts.missedBody(time)),
            );
          }
        }

        final last = t.lastDay;
        if (prefs.lastDayNotice &&
            last != null &&
            !last.isBefore(today) &&
            // A one-day course needs no notice that it ends today.
            last.isAfter(t.startDate)) {
          final at = ChildClock.instant(c.zone, last, lastDayAt);
          if (!t.pausedAt(at) && at.isAfter(nowUtc) && at.isBefore(until)) {
            out.add(
              make(
                ReminderKind.lastDay,
                at,
                title(texts.lastDayTitle),
                body(texts.lastDayBody),
              ),
            );
          }
        }
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out.length > max ? out.sublist(0, max) : out;
  }

  /// The planned dose a reminder points at, if it's still planned.
  static PlannedDose? doseFor(ChildData c, ReminderTarget target) {
    final t = c.treatments.where((x) => x.id == target.treatmentId);
    final date = target.date, time = target.time;
    if (t.isEmpty || date == null || time == null) return null;
    for (final d in ChildClock.planned(t.first, c.zone, date, date)) {
      if (d.time == time) return d;
    }
    return null;
  }
}
