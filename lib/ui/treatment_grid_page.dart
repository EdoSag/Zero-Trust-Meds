import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/meds_config.dart';
import '../data/meds_data.dart';
import '../logic/charts.dart';
import '../logic/dose_logic.dart';
import '../model/models.dart';
import 'common.dart';
import 'dose_actions.dart';
import 'home_page.dart';

/// One medicine as a calendar: days as rows, dose times as columns, each
/// cell an icon (never colour alone). Tapping a cell shows who gave it and
/// when. As-needed medicines list the times given each day instead.
class TreatmentGridPage extends ConsumerWidget {
  const TreatmentGridPage({
    super.key,
    required this.spaceId,
    required this.treatmentId,
  });
  final String spaceId;
  final String treatmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final c = ref.watch(familyProvider).value?.child(spaceId);
    final t = c?.treatments.where((x) => x.id == treatmentId).firstOrNull;
    if (c == null || t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.childGone)),
      );
    }
    final now = readNow(ref);
    final grid = TreatmentGrid.of(c, t, now);
    final m = t.medication;
    return Scaffold(
      appBar: AppBar(title: Text('${m.name} · ${doseText(context, m)}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(
              l.gridIntro(c.child.name),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (grid.times.isNotEmpty) _Header(grid.times, c),
          const Divider(height: 1),
          Expanded(
            child: grid.rows.isEmpty
                ? Center(child: Text(l.chartsEmpty))
                : ListView.builder(
                    itemCount: grid.rows.length,
                    itemBuilder: (context, i) {
                      final row = grid.rows[i];
                      return grid.times.isEmpty
                          ? _AsNeededRow(c, t, row.date)
                          : _GridRow(c, row, isToday: row.date == c.today(now));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

const _dateWidth = 92.0;

class _Header extends StatelessWidget {
  const _Header(this.times, this.c);
  final List<TimeOfDose> times;
  final ChildData c;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      child: Row(
        children: [
          const SizedBox(width: _dateWidth),
          for (final time in times)
            Expanded(
              child: Column(
                children: [
                  Text(
                    slotLabel(context, TimeSlot.of(time)),
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay(hour: time.hour, minute: time.minute),
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                    style: style,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GridRow extends ConsumerWidget {
  const _GridRow(this.c, this.row, {required this.isToday});
  final ChildData c;
  final GridRow row;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = formatLocalDate(context, row.date);
    return Container(
      color: isToday
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: _dateWidth,
            child: Text(
              day,
              style: isToday
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
          ),
          for (final s in row.cells)
            Expanded(
              child: s == null
                  ? const SizedBox(height: 48)
                  : _Cell(c, s, day: day),
            ),
        ],
      ),
    );
  }
}

class _Cell extends ConsumerWidget {
  const _Cell(this.c, this.s, {required this.day});
  final ChildData c;
  final DoseStatus s;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final look = StatusLook.of(context, s.state);
    final icon = s.givenTwice ? Icons.error_outline : look.icon;
    final color = s.givenTwice ? missedAmber : look.color;
    final label = s.givenTwice ? l.statusGivenTwice : look.label;
    final given = s.givenLogs;
    final who = given.isEmpty
        ? null
        : l.givenBy(
            c.nameOf(given.first.byUserId),
            formatWhen(context, given.first.at),
          );
    return Semantics(
      button: true,
      label: [
        l.cellLabel(day, formatTime(context, s.dose.at), label),
        ?who,
      ].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showDoseSheet(context, ref, c, s),
        child: SizedBox(
          height: 48,
          child: Center(child: Icon(icon, color: color)),
        ),
      ),
    );
  }
}

class _AsNeededRow extends StatelessWidget {
  const _AsNeededRow(this.c, this.t, this.date);
  final ChildData c;
  final Treatment t;
  final LocalDate date;

  @override
  Widget build(BuildContext context) {
    final logs = [
      for (final l in c.logsOf(t.id))
        if (l.given && c.today(l.at) == date) l,
    ]..sort((a, b) => a.at.compareTo(b.at));
    return ListTile(
      leading: SizedBox(
        width: _dateWidth - 16,
        child: Text(formatLocalDate(context, date)),
      ),
      title: logs.isEmpty
          ? Text('–', style: Theme.of(context).textTheme.bodySmall)
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final log in logs)
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      context.l.givenBy(
                        c.nameOf(log.byUserId),
                        formatTime(context, log.at),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
