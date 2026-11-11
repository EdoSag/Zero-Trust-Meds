import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/meds_data.dart';
import '../logic/charts.dart';
import '../logic/dose_logic.dart';
import '../model/models.dart';
import 'common.dart';
import 'home_page.dart';

/// How a child's doses went: share given, given / missed / skipped per day,
/// each treatment, and as-needed doses. Worked out on the phone from the
/// encrypted records; nothing is sent anywhere to draw it.
class ChartsPage extends ConsumerStatefulWidget {
  const ChartsPage({super.key, required this.spaceId});
  final String spaceId;

  static const periods = [7, 30, 90];

  @override
  ConsumerState<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends ConsumerState<ChartsPage> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final c = ref.watch(familyProvider).value?.child(widget.spaceId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.childGone)),
      );
    }
    final charts = ChildCharts.of(c, readNow(ref), days: _days);
    return Scaffold(
      appBar: AppBar(title: Text(l.chartsFor(c.child.name))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: [
              for (final d in ChartsPage.periods)
                ButtonSegment(value: d, label: Text(l.lastDays(d))),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
          const SizedBox(height: 16),
          if (charts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.chartsEmpty, textAlign: TextAlign.center),
            )
          else ...[
            _Summary(charts),
            if (charts.overall.counted > 0) ...[
              const SizedBox(height: 24),
              Text(
                l.plannedDosesPerDay,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const _Legend(),
              const SizedBox(height: 8),
              _DayBars(charts),
            ],
            if (charts.treatments.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                l.byTreatment,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final t in charts.treatments) _TreatmentRow(t),
            ],
            if (charts.asNeeded.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                l.asNeededGiven,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _AsNeededBars(charts),
              for (final a in charts.asNeeded)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medication_outlined),
                  title: Text(a.treatment.medication.name),
                  subtitle: Text(l.asNeededSummary(a.given, a.mostInADay)),
                ),
            ],
          ],
          const SizedBox(height: 16),
          Text(l.chartsNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _percent(BuildContext context, int? p) => p == null
    ? '–'
    : NumberFormat.percentPattern(context.localeName).format(p / 100);

class _Summary extends StatelessWidget {
  const _Summary(this.charts);
  final ChildCharts charts;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = charts.overall;
    Widget count(DoseState s, int n) {
      final look = StatusLook.of(context, s);
      return Expanded(
        child: Semantics(
          label: '${look.label}: $n',
          excludeSemantics: true,
          child: Column(
            children: [
              Icon(look.icon, color: look.color),
              Text('$n', style: Theme.of(context).textTheme.titleLarge),
              Text(look.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _percent(context, a.percent),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            Text(
              a.counted == 0
                  ? l.noPlannedDosesYet
                  : l.plannedGivenShare(a.given, a.counted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                count(DoseState.given, a.given),
                count(DoseState.missed, a.missed),
                count(DoseState.skipped, a.skipped),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 4,
    children: [
      for (final s in [DoseState.given, DoseState.missed, DoseState.skipped])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              StatusLook.of(context, s).icon,
              size: 16,
              color: StatusLook.of(context, s).color,
            ),
            const SizedBox(width: 4),
            Text(StatusLook.of(context, s).label),
          ],
        ),
    ],
  );
}

/// Day labels under the bars: weekday initials for a week, otherwise only
/// the first day of each week.
String? _dayLabel(BuildContext context, LocalDate d, int days) {
  final date = DateTime(d.year, d.month, d.day);
  if (days <= 7) return DateFormat.E(context.localeName).format(date);
  return date.weekday == DateTime.monday
      ? DateFormat.Md(context.localeName).format(date)
      : null;
}

class _DayBars extends StatelessWidget {
  const _DayBars(this.charts);
  final ChildCharts charts;

  static const height = 140.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final most = charts.mostInADay;
    final looks = {
      for (final s in [DoseState.given, DoseState.missed, DoseState.skipped])
        s: StatusLook.of(context, s),
    };
    final n = charts.days.length;
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in charts.days)
            Expanded(
              child: Tooltip(
                message: l.dayBarLabel(
                  formatLocalDate(context, d.date),
                  d.adherence.given,
                  d.adherence.missed,
                  d.adherence.skipped,
                ),
                triggerMode: TooltipTriggerMode.tap,
                excludeFromSemantics: true,
                child: Semantics(
                  label: l.dayBarLabel(
                    formatLocalDate(context, d.date),
                    d.adherence.given,
                    d.adherence.missed,
                    d.adherence.skipped,
                  ),
                  excludeSemantics: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: n > 30 ? 0.5 : 3,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(n > 30 ? 1 : 4),
                          child: Column(
                            children: [
                              // Top to bottom: skipped, missed, given.
                              for (final (s, count) in [
                                (DoseState.skipped, d.adherence.skipped),
                                (DoseState.missed, d.adherence.missed),
                                (DoseState.given, d.adherence.given),
                              ])
                                if (count > 0)
                                  Container(
                                    height: most == 0
                                        ? 0
                                        : height * count / most,
                                    color: looks[s]!.color.withValues(
                                      alpha: s == DoseState.skipped ? 0.5 : 1,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 24,
                        child: Text(
                          _dayLabel(context, d.date, n) ?? '',
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AsNeededBars extends StatelessWidget {
  const _AsNeededBars(this.charts);
  final ChildCharts charts;

  static const height = 80.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final most = charts.mostAsNeededInADay;
    final color = Theme.of(context).colorScheme.primary;
    final n = charts.days.length;
    return SizedBox(
      height: height + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in charts.days)
            Expanded(
              child: Semantics(
                label: l.asNeededDayLabel(
                  formatLocalDate(context, d.date),
                  d.asNeeded,
                ),
                excludeSemantics: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: n > 30 ? 0.5 : 3,
                      ),
                      child: Container(
                        height: most == 0 ? 0 : height * d.asNeeded / most,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(n > 30 ? 1 : 4),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: Text(
                        _dayLabel(context, d.date, n) ?? '',
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TreatmentRow extends StatelessWidget {
  const _TreatmentRow(this.stats);
  final TreatmentStats stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = stats.adherence;
    final m = stats.treatment.medication;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${m.name} · ${doseText(context, m)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Text(_percent(context, a.percent)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: a.counted == 0 ? 0 : a.given / a.counted,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            // The value must be a number; the words are in the label.
            semanticsLabel:
                '${m.name}: ${l.plannedGivenShare(a.given, a.counted)}',
          ),
          const SizedBox(height: 4),
          Text(
            [
              l.plannedGivenShare(a.given, a.counted),
              if (a.missed > 0) l.missedCount(a.missed),
              if (a.skipped > 0) l.skippedCount(a.skipped),
              if (stats.givenTwice > 0) l.givenTwiceCount(stats.givenTwice),
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
