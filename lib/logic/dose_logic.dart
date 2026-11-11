import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../model/models.dart';

/// One planned dose of a fixed-time treatment: a day and a time in the
/// child's zone, and the instant that is.
@immutable
class PlannedDose {
  const PlannedDose({
    required this.treatment,
    required this.date,
    required this.time,
    required this.at,
  });

  final Treatment treatment;
  final LocalDate date;
  final TimeOfDose time;

  /// UTC. Every phone shows it in its own local time.
  final DateTime at;

  String get key => '${treatment.id}|$date|$time';

  bool answeredBy(DoseLog l) => l.answers(treatment.id, date, time);
}

/// Turns dates and wall-clock times in the child's zone into instants.
///
/// Daylight saving: a time that doesn't exist on the night the clocks go
/// forward (02:30 when 02:00 jumps to 03:00) moves to just after the jump;
/// a time that happens twice when they go back counts once, at its first
/// occurrence. Either way every planned dose happens exactly once.
abstract final class ChildClock {
  static DateTime instant(tz.Location zone, LocalDate d, TimeOfDose t) {
    final wanted = DateTime.utc(d.year, d.month, d.day, t.hour, t.minute);
    bool lands(DateTime c) {
      final back = tz.TZDateTime.from(c, zone);
      return back.year == d.year &&
          back.month == d.month &&
          back.day == d.day &&
          back.hour == t.hour &&
          back.minute == t.minute;
    }

    // The zone's offset well before and well after the wanted wall time
    // (offsets never change twice within a day).
    final before = tz.TZDateTime.from(
      wanted.subtract(const Duration(hours: 14)),
      zone,
    ).timeZoneOffset;
    final after = tz.TZDateTime.from(
      wanted.add(const Duration(hours: 14)),
      zone,
    ).timeZoneOffset;
    final valid = [
      for (final o in {before, after})
        if (lands(wanted.subtract(o))) wanted.subtract(o),
    ]..sort();
    // Clocks went back: the earlier of the two. Normal day: the only one.
    if (valid.isNotEmpty) return valid.first;
    // In the gap when clocks go forward: the wall time never happens. The
    // offset from before the jump lands just after it (02:30 -> 03:30).
    return wanted.subtract(before);
  }

  /// The child's calendar day at [nowUtc].
  static LocalDate today(tz.Location zone, DateTime nowUtc) =>
      LocalDate.of(tz.TZDateTime.from(nowUtc, zone));

  /// Planned doses of [t] from [from] to [to] (both included).
  static List<PlannedDose> planned(
    Treatment t,
    tz.Location zone,
    LocalDate from,
    LocalDate to,
  ) {
    final schedule = t.schedule;
    if (schedule is! FixedTimes) return const [];
    final out = <PlannedDose>[];
    var day = from.isBefore(t.startDate) ? t.startDate : from;
    final last = t.lastDay;
    final end = last != null && last.isBefore(to) ? last : to;
    while (!day.isAfter(end)) {
      for (final time in schedule.times) {
        out.add(
          PlannedDose(
            treatment: t,
            date: day,
            time: time,
            at: instant(zone, day, time),
          ),
        );
      }
      day = day.addDays(1);
    }
    return out;
  }
}

/// What the home screen and charts say about a planned dose. Each has an
/// icon and a label besides its colour.
enum DoseState { upcoming, due, given, missed, skipped, paused }

@immutable
class DoseStatus {
  const DoseStatus(this.dose, this.state, this.logs);

  final PlannedDose dose;
  final DoseState state;

  /// The records answering this dose, oldest first.
  final List<DoseLog> logs;

  List<DoseLog> get givenLogs => [
    for (final l in logs)
      if (l.given) l,
  ];

  /// Two caregivers both logged it as given: said loudly, never hidden.
  bool get givenTwice => givenLogs.length > 1;
}

abstract final class DoseRules {
  /// A dose shows as due from this long before its time.
  static const dueEarly = Duration(minutes: 30);

  static DoseStatus statusOf(
    PlannedDose dose,
    Iterable<DoseLog> logs,
    DateTime nowUtc, {
    required Duration missedAfter,
  }) {
    final mine = [
      for (final l in logs)
        if (dose.answeredBy(l)) l,
    ]..sort((a, b) => a.at.compareTo(b.at));
    final DoseState state;
    if (mine.any((l) => l.given)) {
      state = DoseState.given;
    } else if (mine.isNotEmpty) {
      state = DoseState.skipped;
    } else if (dose.treatment.pausedAt(dose.at)) {
      state = DoseState.paused;
    } else if (nowUtc.isBefore(dose.at.subtract(dueEarly))) {
      state = DoseState.upcoming;
    } else if (nowUtc.isBefore(dose.at.add(missedAfter))) {
      state = DoseState.due;
    } else {
      state = DoseState.missed;
    }
    return DoseStatus(dose, state, mine);
  }

  /// When a dose becomes missed, for the missed-dose alert.
  static DateTime missedAt(PlannedDose dose, Duration missedAfter) =>
      dose.at.add(missedAfter);
}

/// A reason to stop and confirm before logging a dose as given.
sealed class DoseWarning {
  const DoseWarning();
}

/// This planned dose is already logged as given.
class AlreadyGiven extends DoseWarning {
  const AlreadyGiven(this.logs);
  final List<DoseLog> logs;
}

/// An as-needed medicine given too recently.
class TooSoon extends DoseWarning {
  const TooSoon({required this.last, required this.nextAllowed});
  final DoseLog last;
  final DateTime nextAllowed;
}

/// An as-needed medicine already at its most for 24 hours.
class MaxReached extends DoseWarning {
  const MaxReached({
    required this.count,
    required this.max,
    required this.nextAllowed,
  });
  final int count;
  final int max;
  final DateTime nextAllowed;
}

abstract final class DoseGuard {
  /// Warnings before logging [t] as given at [at] (for [slot] when it is a
  /// planned dose). Empty: go ahead.
  static List<DoseWarning> beforeGiving({
    required Treatment t,
    required Iterable<DoseLog> logs,
    required DateTime at,
    PlannedDose? slot,
  }) {
    final given = [
      for (final l in logs)
        if (l.treatmentId == t.id && l.given) l,
    ]..sort((a, b) => a.at.compareTo(b.at));
    final out = <DoseWarning>[];
    if (slot != null) {
      final same = [
        for (final l in given)
          if (slot.answeredBy(l)) l,
      ];
      if (same.isNotEmpty) out.add(AlreadyGiven(same));
    }
    final schedule = t.schedule;
    if (schedule is AsNeeded) {
      final gap = Duration(minutes: schedule.minIntervalMinutes);
      // Doses logged on either side count: a time corrected backwards can
      // land just before another one.
      final near = [
        for (final l in given)
          if (l.at.difference(at).abs() < gap) l,
      ];
      if (gap > Duration.zero && near.isNotEmpty) {
        final last = near.last;
        out.add(TooSoon(last: last, nextAllowed: last.at.add(gap)));
      }
      final max = schedule.maxPer24h;
      if (max != null && max > 0) {
        final count = _fullWindow(given, at, max);
        if (count != null) {
          // The first time from here on at which one more dose fits: only
          // when a logged dose leaves a 24 hour window can that change.
          final candidates = [
            for (final l in given)
              if (l.at.add(_day).isAfter(at)) l.at.add(_day),
          ];
          out.add(
            MaxReached(
              count: count,
              max: max,
              nextAllowed: candidates.firstWhere(
                (c) => _fullWindow(given, c, max) == null,
              ),
            ),
          );
        }
      }
    }
    return out;
  }

  static const _day = Duration(hours: 24);

  /// How many doses are already in a 24 hour window that a dose at [at]
  /// would overfill, or null when it fits. The windows are the 24 hours up
  /// to [at] and, for a time in the past, the 24 hours up to each dose
  /// logged after it: this one counts in those too. [given] is sorted.
  static int? _fullWindow(List<DoseLog> given, DateTime at, int max) {
    final ends = [
      at,
      for (final l in given)
        if (l.at.isAfter(at) && l.at.isBefore(at.add(_day))) l.at,
    ];
    for (final end in ends) {
      final count = given
          .where((l) => l.at.isAfter(end.subtract(_day)) && !l.at.isAfter(end))
          .length;
      if (count >= max) return count;
    }
    return null;
  }

  /// For an as-needed medicine: when the next dose is allowed (now when it
  /// already is).
  static DateTime nextAllowed(
    Treatment t,
    Iterable<DoseLog> logs,
    DateTime nowUtc,
  ) {
    final warnings = beforeGiving(t: t, logs: logs, at: nowUtc);
    var next = nowUtc;
    for (final w in warnings) {
      final candidate = switch (w) {
        TooSoon(:final nextAllowed) => nextAllowed,
        MaxReached(:final nextAllowed) => nextAllowed,
        AlreadyGiven() => nowUtc,
      };
      if (candidate.isAfter(next)) next = candidate;
    }
    return next;
  }
}

/// What saving an edited treatment did with its times.
enum TimesEdit {
  /// Saved as edited.
  saved,

  /// The new times start tomorrow, in a new course.
  fromTomorrow,

  /// The course has no days left, so its times stayed as they were.
  kept,
}

/// How an edit to a treatment is saved without rewriting what was logged.
abstract final class TreatmentEdit {
  /// Records answer a dose by its day and time, so changing the times of a
  /// course that has records would turn given doses into missed ones. Then
  /// the old course ends today and a new one with the new times starts
  /// tomorrow, for the days that are left. A course with no days left
  /// (its last day, or already finished) keeps its times and takes the
  /// other changes. Otherwise the edit is saved as it is.
  static List<Treatment> plan({
    required Treatment? old,
    required Treatment edited,
    required LocalDate today,
    required bool hasLogs,
  }) {
    if (old == null ||
        !hasLogs ||
        old.startDate.isAfter(today) ||
        _same(old.schedule, edited.schedule) ||
        // As-needed doses have no planned times for records to answer.
        (old.schedule is AsNeeded && edited.schedule is AsNeeded)) {
      return [edited];
    }
    final last = edited.lastDay;
    if (last != null && !last.isAfter(today)) {
      return [edited.copyWith(schedule: old.schedule)];
    }
    final tomorrow = today.addDays(1);
    return [
      old.copyWith(endedOn: today, medication: edited.medication),
      Treatment(
        id: '',
        medication: edited.medication,
        schedule: edited.schedule,
        startDate: tomorrow,
        days: last == null ? null : tomorrow.daysUntil(last) + 1,
      ),
    ];
  }

  static bool _same(DoseSchedule a, DoseSchedule b) =>
      a.toJson().toString() == b.toJson().toString();
}

/// Given, missed and skipped doses over a period, and the share given.
@immutable
class Adherence {
  const Adherence({this.given = 0, this.missed = 0, this.skipped = 0});

  factory Adherence.of(Iterable<DoseStatus> statuses) {
    var given = 0, missed = 0, skipped = 0;
    for (final s in statuses) {
      switch (s.state) {
        case DoseState.given:
          given++;
        case DoseState.missed:
          missed++;
        case DoseState.skipped:
          skipped++;
        case DoseState.upcoming || DoseState.due || DoseState.paused:
          break;
      }
    }
    return Adherence(given: given, missed: missed, skipped: skipped);
  }

  final int given;
  final int missed;
  final int skipped;

  int get counted => given + missed + skipped;

  /// 0-100, or null when no dose is due yet.
  int? get percent => counted == 0 ? null : (given * 100 / counted).round();
}
