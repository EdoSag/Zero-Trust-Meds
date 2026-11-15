import 'package:flutter/foundation.dart';

import '../data/meds_data.dart';
import '../model/models.dart';
import 'dose_logic.dart';

/// One day of a child's doses, in the child's calendar.
@immutable
class DayStats {
  const DayStats(this.date, this.adherence, this.asNeeded);

  final LocalDate date;

  /// Planned doses that day: given, missed, skipped. Doses still upcoming
  /// or due, and paused ones, aren't counted.
  final Adherence adherence;

  /// As-needed doses given that day.
  final int asNeeded;

  int get total => adherence.counted;
}

/// How one treatment went over the period.
@immutable
class TreatmentStats {
  const TreatmentStats(this.treatment, this.adherence, {this.givenTwice = 0});
  final Treatment treatment;
  final Adherence adherence;

  /// Planned doses logged as given more than once.
  final int givenTwice;
}

/// As-needed doses of one treatment over the period.
@immutable
class AsNeededStats {
  const AsNeededStats(this.treatment, this.given, this.mostInADay);
  final Treatment treatment;
  final int given;
  final int mostInADay;
}

/// What the charts page shows for one child over the last [days] days,
/// today included.
@immutable
class ChildCharts {
  const ChildCharts({
    required this.from,
    required this.to,
    required this.days,
    required this.overall,
    required this.treatments,
    required this.asNeeded,
    this.oneTime = const [],
  });

  factory ChildCharts.of(ChildData c, DateTime nowUtc, {int days = 7}) {
    final to = c.today(nowUtc);
    final from = to.addDays(-(days - 1));
    final perDay = <LocalDate, List<DoseStatus>>{};
    final perTreatment = <TreatmentStats>[];
    final asNeededPerDay = <LocalDate, int>{};
    final asNeeded = <AsNeededStats>[];

    for (final t in c.treatments) {
      if (t.startDate.isAfter(to)) continue;
      final last = t.lastDay;
      if (last != null && last.isBefore(from)) continue;
      if (t.schedule is AsNeeded) {
        final byDay = <LocalDate, int>{};
        for (final l in c.logsOf(t.id)) {
          if (!l.given) continue;
          final day = c.today(l.at);
          if (day.isBefore(from) || day.isAfter(to)) continue;
          byDay[day] = (byDay[day] ?? 0) + 1;
          asNeededPerDay[day] = (asNeededPerDay[day] ?? 0) + 1;
        }
        final given = byDay.values.fold(0, (a, b) => a + b);
        if (given > 0) {
          asNeeded.add(
            AsNeededStats(
              t,
              given,
              byDay.values.reduce((a, b) => a > b ? a : b),
            ),
          );
        }
        continue;
      }
      final statuses = c.dosesOf(t, nowUtc, from: from, to: to);
      for (final s in statuses) {
        (perDay[s.dose.date] ??= []).add(s);
      }
      final a = Adherence.of(statuses);
      if (a.counted > 0) {
        perTreatment.add(
          TreatmentStats(
            t,
            a,
            givenTwice: statuses.where((s) => s.givenTwice).length,
          ),
        );
      }
    }

    final dayStats = [
      for (var d = from; !d.isAfter(to); d = d.addDays(1))
        DayStats(
          d,
          Adherence.of(perDay[d] ?? const []),
          asNeededPerDay[d] ?? 0,
        ),
    ];
    perTreatment.sort(
      (a, b) => a.treatment.medication.name.toLowerCase().compareTo(
        b.treatment.medication.name.toLowerCase(),
      ),
    );
    asNeeded.sort((a, b) => b.given.compareTo(a.given));

    final oneTimeByName = <String, (Medication, int)>{};
    for (final l in c.oneTimeLogs) {
      final day = c.today(l.at);
      if (day.isBefore(from) || day.isAfter(to)) continue;
      final key = l.medication!.name.trim().toLowerCase();
      final seen = oneTimeByName[key];
      // Newest first, so the first seen names the medicine.
      oneTimeByName[key] = (seen?.$1 ?? l.medication!, (seen?.$2 ?? 0) + 1);
    }
    final oneTime = [
      for (final e in oneTimeByName.values) OneTimeStats(e.$1, e.$2),
    ]..sort((a, b) => b.given.compareTo(a.given));

    return ChildCharts(
      from: from,
      to: to,
      days: dayStats,
      overall: Adherence(
        given: dayStats.fold(0, (s, d) => s + d.adherence.given),
        missed: dayStats.fold(0, (s, d) => s + d.adherence.missed),
        skipped: dayStats.fold(0, (s, d) => s + d.adherence.skipped),
      ),
      treatments: perTreatment,
      asNeeded: asNeeded,
      oneTime: oneTime,
    );
  }

  final LocalDate from;
  final LocalDate to;

  /// Oldest first.
  final List<DayStats> days;
  final Adherence overall;
  final List<TreatmentStats> treatments;
  final List<AsNeededStats> asNeeded;

  /// Medicines given once, outside any treatment, most given first.
  final List<OneTimeStats> oneTime;

  /// The tallest day, for scaling the bars.
  int get mostInADay => days.fold(0, (m, d) => d.total > m ? d.total : m);

  int get mostAsNeededInADay =>
      days.fold(0, (m, d) => d.asNeeded > m ? d.asNeeded : m);

  bool get isEmpty =>
      overall.counted == 0 && asNeeded.isEmpty && oneTime.isEmpty;
}

/// One-time doses of one medicine (by name) over the period.
@immutable
class OneTimeStats {
  const OneTimeStats(this.medication, this.given);

  /// The newest dose's medicine.
  final Medication medication;
  final int given;
}

/// One day of a fixed-time treatment's grid: a cell per dose time.
@immutable
class GridRow {
  const GridRow(this.date, this.cells);
  final LocalDate date;

  /// In the order of [TreatmentGrid.times]; null where no dose was
  /// planned that day (before the start, after an early end).
  final List<DoseStatus?> cells;
}

/// A treatment as a calendar grid: days as rows, dose times as columns.
@immutable
class TreatmentGrid {
  const TreatmentGrid(this.treatment, this.times, this.rows);

  /// The last [maxDays] days up to today, and the rest of the course up to
  /// [aheadDays] days ahead, newest first.
  factory TreatmentGrid.of(
    ChildData c,
    Treatment t,
    DateTime nowUtc, {
    int maxDays = 90,
    int aheadDays = 14,
  }) {
    final schedule = t.schedule;
    final times = schedule is FixedTimes
        ? ([...schedule.times]..sort())
        : const <TimeOfDose>[];
    final today = c.today(nowUtc);
    var from = today.addDays(-(maxDays - 1));
    if (from.isBefore(t.startDate)) from = t.startDate;
    var to = today.addDays(aheadDays);
    final last = t.lastDay;
    if (last != null && last.isBefore(to)) to = last;
    final byKey = {
      for (final s in c.dosesOf(t, nowUtc, from: from, to: to))
        '${s.dose.date}|${s.dose.time}': s,
    };
    final rows = <GridRow>[
      for (var d = to; !d.isBefore(from); d = d.addDays(-1))
        GridRow(d, [for (final time in times) byKey['$d|$time']]),
    ];
    return TreatmentGrid(t, times, rows);
  }

  final Treatment treatment;
  final List<TimeOfDose> times;

  /// Newest first.
  final List<GridRow> rows;
}

/// One line of a child's combined timeline: a planned dose with its
/// status, an as-needed dose given, or a one-time dose given.
@immutable
class TimelineEntry {
  const TimelineEntry.planned(DoseStatus this.status)
    : treatment = null,
      log = null;
  const TimelineEntry.asNeeded(Treatment this.treatment, DoseLog this.log)
    : status = null;
  const TimelineEntry.oneTime(DoseLog this.log)
    : status = null,
      treatment = null;

  final DoseStatus? status;
  final Treatment? treatment;
  final DoseLog? log;

  /// Given once, outside any treatment.
  bool get isOneTime => status == null && treatment == null;

  /// The treatment of a planned or as-needed dose (not for a one-time
  /// dose, which has none).
  Treatment get medicine => status?.dose.treatment ?? treatment!;

  Medication get medication =>
      status?.dose.treatment.medication ??
      treatment?.medication ??
      log!.medication!;

  /// When it was planned, or when the dose was given (UTC).
  DateTime get at => status?.dose.at ?? log!.at;
}

/// A day of the combined timeline, in the child's calendar.
@immutable
class TimelineDay {
  const TimelineDay(this.date, this.entries);
  final LocalDate date;

  /// By time.
  final List<TimelineEntry> entries;
}

abstract final class ChildTimeline {
  /// Every medicine's doses over the last [days] days (today's still to
  /// come included), newest day first.
  static List<TimelineDay> of(ChildData c, DateTime nowUtc, {int days = 7}) {
    final to = c.today(nowUtc);
    final from = to.addDays(-(days - 1));
    final byDay = <LocalDate, List<TimelineEntry>>{};
    for (final t in c.treatments) {
      if (t.startDate.isAfter(to)) continue;
      final last = t.lastDay;
      if (last != null && last.isBefore(from)) continue;
      if (t.schedule is AsNeeded) {
        for (final l in c.logsOf(t.id)) {
          if (!l.given) continue;
          final day = c.today(l.at);
          if (day.isBefore(from) || day.isAfter(to)) continue;
          (byDay[day] ??= []).add(TimelineEntry.asNeeded(t, l));
        }
      } else {
        for (final s in c.dosesOf(t, nowUtc, from: from, to: to)) {
          (byDay[s.dose.date] ??= []).add(TimelineEntry.planned(s));
        }
      }
    }
    for (final l in c.oneTimeLogs) {
      final day = c.today(l.at);
      if (day.isBefore(from) || day.isAfter(to)) continue;
      (byDay[day] ??= []).add(TimelineEntry.oneTime(l));
    }
    return [
      for (var d = to; !d.isBefore(from); d = d.addDays(-1))
        if (byDay[d] != null)
          TimelineDay(d, byDay[d]!..sort((a, b) => a.at.compareTo(b.at))),
    ];
  }
}

/// One child's card in the family overview.
@immutable
class ChildOverview {
  const ChildOverview({
    required this.child,
    required this.today,
    required this.week,
  });

  factory ChildOverview.of(ChildData c, DateTime nowUtc) {
    final counts = <DoseState, int>{};
    for (final s in c.doses(c.today(nowUtc), nowUtc)) {
      counts[s.state] = (counts[s.state] ?? 0) + 1;
    }
    return ChildOverview(
      child: c,
      today: counts,
      week: ChildCharts.of(c, nowUtc, days: 7),
    );
  }

  final ChildData child;

  /// Today's planned doses by state.
  final Map<DoseState, int> today;

  /// The last 7 days, today included.
  final ChildCharts week;

  int count(DoseState s) => today[s] ?? 0;

  /// Whether a dose today needs attention (due or missed).
  bool get needsAttention =>
      count(DoseState.due) > 0 || count(DoseState.missed) > 0;
}
