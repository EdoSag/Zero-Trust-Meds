import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/logic/charts.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/ui/charts_page.dart';
import 'package:zerotrust_meds/ui/home_page.dart';

import 'support/phone.dart';

const amox = Medication(
  id: 'med-1',
  name: 'Amoxicillin',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);
const fever = Medication(
  id: 'med-2',
  name: 'Paracetamol',
  form: MedForm.liquid,
  amount: 7.5,
  unit: 'ml',
);

DoseLog log(
  String id,
  String treatment,
  DateTime at, {
  String? date,
  TimeOfDose? time,
  DoseAction action = DoseAction.given,
}) => DoseLog(
  id: id,
  treatmentId: treatment,
  action: action,
  at: at,
  byUserId: mum,
  slotDate: date == null ? null : LocalDate.parse(date),
  slotTime: time,
);

/// Noa: Amoxicillin 08:00 and 20:00 from 10 Jan for 7 days, Paracetamol as
/// needed, and an old course that ended before the period.
Future<ChildData> noa() async {
  final server = InMemorySpaceServer();
  final phone = await Phone(server, mum, 1).start();
  final space = await phone.spaces.create(myName: 'Mum');
  await space.save(
    Child.itemId,
    const Child(name: 'Noa', timeZone: 'UTC').toJson(),
  );
  final items = <String, Map<String, Object?>>{
    't1': Treatment(
      id: 't1',
      medication: amox,
      schedule: const FixedTimes([TimeOfDose(8, 0), TimeOfDose(20, 0)]),
      startDate: LocalDate.parse('2026-01-10'),
      days: 7,
    ).toJson(),
    'old': Treatment(
      id: 'old',
      medication: const Medication(id: 'med-3', name: 'Old drops'),
      schedule: const FixedTimes([TimeOfDose(9, 0)]),
      startDate: LocalDate.parse('2025-12-01'),
      days: 5,
    ).toJson(),
    'p1': Treatment(
      id: 'p1',
      medication: fever,
      schedule: const AsNeeded(minIntervalMinutes: 360, maxPer24h: 4),
      startDate: LocalDate.parse('2026-01-01'),
    ).toJson(),
  };
  final morning = const TimeOfDose(8, 0), evening = const TimeOfDose(20, 0);
  for (final l in [
    log(
      'd1',
      't1',
      DateTime.utc(2026, 1, 10, 8),
      date: '2026-01-10',
      time: morning,
    ),
    log(
      'd2',
      't1',
      DateTime.utc(2026, 1, 10, 20),
      date: '2026-01-10',
      time: evening,
    ),
    // Given twice by two caregivers.
    log(
      'd3',
      't1',
      DateTime.utc(2026, 1, 11, 8),
      date: '2026-01-11',
      time: morning,
    ),
    log(
      'd4',
      't1',
      DateTime.utc(2026, 1, 11, 8, 5),
      date: '2026-01-11',
      time: morning,
    ),
    log(
      'd5',
      't1',
      DateTime.utc(2026, 1, 11, 20),
      date: '2026-01-11',
      time: evening,
      action: DoseAction.skipped,
    ),
    // 12 Jan 08:00 not logged: missed by 16:00. 20:00 still to come.
    log('a1', 'p1', DateTime.utc(2026, 1, 11, 9)),
    log('a2', 'p1', DateTime.utc(2026, 1, 11, 17)),
    log('a3', 'p1', DateTime.utc(2026, 1, 12, 7)),
    log('a0', 'p1', DateTime.utc(2026, 1, 1, 7)),
  ]) {
    items['dose/${l.id}'] = log(
      'dose/${l.id}',
      l.treatmentId,
      l.at,
      date: l.slotDate?.toString(),
      time: l.slotTime,
      action: l.action,
    ).toJson();
  }
  for (final e in items.entries) {
    await space.save(e.key, e.value);
  }
  await phone.spaces.sync(space);
  return (await phone.child(space.id))!;
}

final now = DateTime.utc(2026, 1, 12, 16);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('a week: given, missed and skipped per day; doses to come and old '
      'courses left out', () async {
    final c = await noa();
    final charts = ChildCharts.of(c, now, days: 7);
    expect(charts.from, LocalDate.parse('2026-01-06'));
    expect(charts.to, LocalDate.parse('2026-01-12'));
    expect(charts.days.length, 7);
    final byDay = {
      for (final d in charts.days)
        d.date.toString(): (
          d.adherence.given,
          d.adherence.missed,
          d.adherence.skipped,
          d.asNeeded,
        ),
    };
    expect(byDay['2026-01-06'], (0, 0, 0, 0));
    expect(byDay['2026-01-10'], (2, 0, 0, 0));
    expect(byDay['2026-01-11'], (1, 0, 1, 2));
    expect(byDay['2026-01-12'], (0, 1, 0, 1));
    expect(charts.overall.given, 3);
    expect(charts.overall.missed, 1);
    expect(charts.overall.skipped, 1);
    expect(charts.overall.percent, 60);
    expect(charts.mostInADay, 2);

    expect(charts.treatments.map((t) => t.treatment.id), ['t1']);
    expect(charts.treatments.single.givenTwice, 1);
    expect(charts.asNeeded.single.given, 3);
    expect(charts.asNeeded.single.mostInADay, 2);
    expect(charts.mostAsNeededInADay, 2);
  });

  test('a longer period reaches older as-needed doses', () async {
    final c = await noa();
    final charts = ChildCharts.of(c, now, days: 30);
    expect(charts.days.length, 30);
    expect(charts.asNeeded.single.given, 4);
    // The old course ended 5 Dec, before 14 Dec.
    expect(charts.treatments.map((t) => t.treatment.id), ['t1']);
    expect(ChildCharts.of(c, now, days: 90).treatments.length, 2);
  });

  testWidgets('the charts page draws every period without overflowing', (
    tester,
  ) async {
    // Semantics on: screen readers get a label for every bar.
    final semantics = tester.ensureSemantics();
    late ChildData c;
    await tester.runAsync(() async => c = await noa());
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWith((ref) => Stream.value(now)),
          familyProvider.overrideWith(
            (ref) async =>
                FamilyData(children: [c], ready: true, loading: false),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppL10n.delegate,
            ZtL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: ChartsPage(spaceId: c.spaceId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('60%'), findsWidgets);
    expect(find.text('3 of 5 planned doses given'), findsWidgets);
    expect(find.text('Planned doses per day'), findsOneWidget);
    expect(find.textContaining('1 given twice'), findsOneWidget);
    expect(find.text('Paracetamol'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Sun, Jan 11: 1 given, 0 missed, 1 skipped',
      ),
      findsOneWidget,
    );
    // Missed has its icon, not only a colour.
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);

    // The percentage and the summary don't sit on top of each other.
    final pct = tester.getRect(find.text('60%').first);
    final sub = tester.getRect(find.text('3 of 5 planned doses given').first);
    expect(sub.top, greaterThanOrEqualTo(pct.bottom));

    for (final days in ['30 days', '90 days', '7 days']) {
      await tester.tap(find.text(days));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });
}
