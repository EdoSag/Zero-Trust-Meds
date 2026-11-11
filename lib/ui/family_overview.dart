import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/meds_data.dart';
import '../logic/charts.dart';
import '../logic/dose_logic.dart';
import 'charts_page.dart';
import 'child_page.dart';
import 'common.dart';

/// With more than one child: a card each, with today's doses by status
/// and the last 7 days of doses given.
class FamilyOverview extends StatelessWidget {
  const FamilyOverview(this.children, {super.key, required this.now});
  final List<ChildData> children;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(context.l.familyOverview),
      for (final c in children) _ChildCard(ChildOverview.of(c, now)),
    ],
  );
}

class _ChildCard extends StatelessWidget {
  const _ChildCard(this.o);
  final ChildOverview o;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final c = o.child;
    final week = o.week;
    final percent = week.overall.percent;
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChildPage(spaceId: c.spaceId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChildAvatar(c.child),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.child.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l.charts,
                    icon: const Icon(Icons.insights_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChartsPage(spaceId: c.spaceId),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final s in const [
                    DoseState.given,
                    DoseState.due,
                    DoseState.missed,
                    DoseState.upcoming,
                  ])
                    if (o.count(s) > 0) _Count(s, o.count(s)),
                  if (o.today.isEmpty)
                    Text(
                      l.nothingToday,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      l.lastSevenDays(
                        percent == null
                            ? '–'
                            : NumberFormat.percentPattern(
                                context.localeName,
                              ).format(percent / 100),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  _WeekStrip(week),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.state, this.count);
  final DoseState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    final look = StatusLook.of(context, state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(look.icon, size: 18, color: look.color),
        const SizedBox(width: 4),
        Text(context.l.todayCount(count, look.label)),
      ],
    );
  }
}

/// Seven small columns, one per day: the share of planned doses given,
/// with an amber mark on a day with a missed dose.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip(this.week);
  final ChildCharts week;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in week.days)
          Semantics(
            label: l.dayBarLabel(
              formatLocalDate(context, d.date),
              d.adherence.given,
              d.adherence.missed,
              d.adherence.skipped,
            ),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 14,
                    child: d.adherence.missed > 0
                        ? Icon(
                            StatusLook.of(context, DoseState.missed).icon,
                            size: 12,
                            color: StatusLook.of(
                              context,
                              DoseState.missed,
                            ).color,
                          )
                        : null,
                  ),
                  Container(
                    width: 10,
                    height: 28,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: d.total == 0
                        ? null
                        : FractionallySizedBox(
                            heightFactor: d.adherence.given / d.total,
                            child: Container(
                              decoration: BoxDecoration(
                                color: StatusLook.of(
                                  context,
                                  DoseState.given,
                                ).color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
