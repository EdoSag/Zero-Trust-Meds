import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/logic/charts.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/ui/home_page.dart';
import 'package:zerotrust_meds/ui/one_time_dose.dart';

import 'support/phone.dart';

const nurofen = Medication(
  id: '',
  name: 'Nurofen',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

const amox = Medication(
  id: 'med-1',
  name: 'Amoxicillin',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

DoseLog oneTime(String id, DateTime at, {String by = dad}) => DoseLog(
  id: id,
  treatmentId: '',
  action: DoseAction.given,
  at: at,
  byUserId: by,
  reason: 'Fever',
  loggedAt: at,
  medication: nurofen,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('the record', () {
    test('a one-time dose keeps its medicine and reason', () {
      final log = oneTime('dose/x', DateTime.utc(2026, 1, 12, 15));
      final back = DoseLog.fromJson('dose/x', log.toJson());
      expect(back.isOneTime, isTrue);
      expect(back.treatmentId, '');
      expect(back.medication!.name, 'Nurofen');
      expect(back.medication!.amount, 5);
      expect(back.medication!.unit, 'ml');
      expect(back.reason, 'Fever');
      expect(back.slotDate, isNull);
      // Changing the time keeps the medicine.
      expect(
        back.copyWith(at: DateTime.utc(2026, 1, 12, 14)).medication!.name,
        'Nurofen',
      );
    });

    test('records of treatments read as before', () {
      final log = DoseLog(
        id: 'dose/1',
        treatmentId: 't1',
        action: DoseAction.given,
        at: DateTime.utc(2026, 1, 12, 8),
        byUserId: mum,
      );
      final json = log.toJson();
      expect(json.containsKey('medication'), isFalse);
      final back = DoseLog.fromJson('dose/1', json);
      expect(back.isOneTime, isFalse);
      expect(back.medication, isNull);
    });
  });

  group('shared with the family', () {
    late InMemorySpaceServer server;
    late Phone mumPhone, dadPhone;

    setUp(() async {
      server = InMemorySpaceServer();
      mumPhone = await Phone(server, mum, 1).start();
      dadPhone = await Phone(server, dad, 2).start();
    });

    test('a caregiver logs a one-time dose and the admin sees it in the '
        'today list, the charts and the timeline', () async {
      final space = await mumPhone.spaces.create(myName: 'Mum');
      await space.save(
        Child.itemId,
        const Child(name: 'Noa', timeZone: 'UTC').toJson(),
      );
      await mumPhone.spaces.sync(space);
      final link = await mumPhone.spaces.invite(space.id);
      await dadPhone.spaces.answer(
        SpaceInviteLink.parse(link.toString()),
        myName: 'Dad',
      );
      await mumPhone.spaces.confirm(
        (await mumPhone.spaces.pendingJoins(space.id)).single,
      );

      // Dad isn't an admin and has no treatment to log against.
      final dadSpace = await dadPhone.spaces.open(space.id);
      await dadPhone.spaces.sync(dadSpace);
      final log = oneTime('dose/n1', DateTime.utc(2026, 1, 12, 15));
      await dadSpace.save(log.id, log.toJson());
      await dadPhone.spaces.sync(dadSpace);

      final noa = (await mumPhone.child(space.id))!;
      expect(noa.treatments, isEmpty);
      final seen = noa.oneTimeLogs.single;
      expect(seen.medication!.name, 'Nurofen');
      expect(noa.nameOf(seen.byUserId), 'Dad');
      expect(noa.oneTimeOn(LocalDate.parse('2026-01-12')), hasLength(1));
      expect(noa.oneTimeOn(LocalDate.parse('2026-01-13')), isEmpty);

      final now = DateTime.utc(2026, 1, 12, 18);
      final charts = ChildCharts.of(noa, now);
      expect(charts.isEmpty, isFalse);
      expect(charts.oneTime.single.medication.name, 'Nurofen');
      expect(charts.oneTime.single.given, 1);

      final day = ChildTimeline.of(noa, now).single;
      expect(day.entries.single.isOneTime, isTrue);
      expect(day.entries.single.medication.name, 'Nurofen');
    });
  });

  group('given in the last 24 hours', () {
    test('finds the newest dose by name, one-time or from a treatment', () {
      final noa = _bare(
        treatments: [
          Treatment(
            id: 't1',
            medication: const Medication(id: 'm', name: 'nurofen '),
            schedule: const AsNeeded(minIntervalMinutes: 360),
            startDate: LocalDate.parse('2026-01-01'),
          ),
        ],
        logs: [
          oneTime('dose/old', DateTime.utc(2026, 1, 10, 8)),
          DoseLog(
            id: 'dose/t',
            treatmentId: 't1',
            action: DoseAction.given,
            at: DateTime.utc(2026, 1, 12, 9),
            byUserId: mum,
          ),
          oneTime('dose/a', DateTime.utc(2026, 1, 12, 7)),
        ],
      );
      final at = DateTime.utc(2026, 1, 12, 12);
      expect(noa.lastGivenNamed('Nurofen', at)!.id, 'dose/t');
      expect(noa.lastGivenNamed('NUROFEN', at)!.byUserId, mum);
      expect(noa.lastGivenNamed('Calpol', at), isNull);
      expect(noa.lastGivenNamed('', at), isNull);
      // Two days later nothing is that recent.
      expect(noa.lastGivenNamed('Nurofen', DateTime.utc(2026, 1, 14)), isNull);
    });
  });

  group('home screen', () {
    testWidgets('a one-time dose shows in the person\'s card with who gave '
        'it and why, under the planned doses, with a button to log one', (
      tester,
    ) async {
      final [noa] = await _family(tester, [
        (
          'Noa',
          [
            Treatment(
              id: 't1',
              medication: amox,
              schedule: const FixedTimes([TimeOfDose(8, 0)]),
              startDate: LocalDate.parse('2026-01-10'),
              days: 7,
            ),
          ],
          [oneTime('dose/n1', DateTime.utc(2026, 1, 12, 15), by: mum)],
        ),
      ]);
      await _pumpHome(tester, noa);

      expect(find.text('One-time doses'), findsOneWidget);
      expect(find.text('Nurofen · 5 ml'), findsOneWidget);
      expect(find.textContaining('One-time · Given by Mum'), findsOneWidget);
      expect(find.textContaining('Fever'), findsOneWidget);
      expect(find.text('Log a one-time dose'), findsOneWidget);

      final planned = tester.getRect(find.text('Amoxicillin · 5 ml'));
      final header = tester.getRect(find.text('One-time doses'));
      final row = tester.getRect(find.text('Nurofen · 5 ml'));
      final button = tester.getRect(find.text('Log a one-time dose'));
      final card = tester.getRect(find.byType(Card).first);
      expect(header.top, greaterThan(planned.bottom));
      expect(row.top, greaterThan(header.bottom));
      expect(button.top, greaterThan(row.bottom));
      // Inside the card, at its end edge.
      expect(card.contains(button.center), isTrue);
      expect(button.center.dx, greaterThan(card.center.dx));
    });

    testWidgets('in Hebrew it is translated and the button sits on the left', (
      tester,
    ) async {
      final [noa] = await _family(tester, [
        (
          'Noa',
          [],
          [oneTime('dose/n1', DateTime.utc(2026, 1, 12, 15), by: mum)],
        ),
      ]);
      await _pumpHome(tester, noa, locale: const Locale('he'));

      expect(tester.takeException(), isNull);
      expect(find.text('מנות חד-פעמיות'), findsOneWidget);
      expect(find.textContaining('חד-פעמי · '), findsOneWidget);
      expect(find.text('אין היום מנות מתוכננות'), findsOneWidget);
      expect(find.text('Log a one-time dose'), findsNothing);
      final button = tester.getRect(find.text('רישום מנה חד-פעמית'));
      final card = tester.getRect(find.byType(Card).first);
      expect(card.contains(button.center), isTrue);
      expect(button.center.dx, lessThan(card.center.dx));
    });
  });

  group('the form', () {
    testWidgets('needs a name, warns about a recent dose of the same '
        'medicine, and logs for the chosen person', (tester) async {
      final [noa, tom] = await _family(tester, [
        (
          'Noa',
          [],
          [
            oneTime(
              'dose/n1',
              DateTime.now().toUtc().subtract(const Duration(hours: 2)),
              by: mum,
            ),
          ],
        ),
        ('Tom', [], []),
      ]);
      final logged = <(String, Medication, String)>[];
      await tester.binding.setSurfaceSize(const Size(400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familyProvider.overrideWith(
              (ref) async =>
                  FamilyData(children: [noa, tom], ready: true, loading: false),
            ),
            medsActionsProvider.overrideWith(
              (ref) => _RecordingActions(ref, logged),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            supportedLocales: ZtLanguages.supported,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      openOneTimeDose(context, spaceId: noa.spaceId),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('One-time dose'), findsOneWidget);
      // Noa is picked; nothing typed yet, so Log asks for a name.
      expect(find.text('Noa'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Log dose'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(logged, isEmpty);

      // Nurofen was given to Noa two hours ago: picking it warns.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Nurofen · 5 ml'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nurofen was already given in the last 24 hours'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('oneTimeAmount')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '5',
      );
      // The warning sits under the medicine fields, above the time.
      final warning = tester.getRect(
        find.textContaining('already given in the last 24 hours'),
      );
      expect(
        warning.top,
        greaterThan(
          tester.getRect(find.byKey(const Key('oneTimeUnit'))).bottom,
        ),
      );
      expect(
        warning.bottom,
        lessThan(tester.getRect(find.text('Given at')).top),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Fever'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Log dose'));
      await tester.pumpAndSettle();

      expect(logged, hasLength(1));
      expect(logged.single.$1, noa.spaceId);
      expect(logged.single.$2.name, 'Nurofen');
      expect(logged.single.$2.amount, 5);
      expect(logged.single.$3, 'Fever');
      // Back where it was opened, with an Undo that closes by itself.
      expect(find.text('open'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 6));
      expect(find.text('Nurofen logged as given to Noa'), findsOneWidget);
    });
  });
}

class _RecordingActions extends MedsActions {
  _RecordingActions(super.ref, this.logged);
  final List<(String, Medication, String)> logged;

  @override
  Future<DoseLog> logOneTimeDose(
    ChildData c, {
    required Medication medication,
    required DateTime at,
    String reason = '',
  }) async {
    logged.add((c.spaceId, medication, reason));
    return DoseLog(
      id: 'dose/new',
      treatmentId: '',
      action: DoseAction.given,
      at: at,
      byUserId: mum,
      medication: medication,
      reason: reason,
    );
  }

  @override
  Future<void> deleteLog(ChildData c, DoseLog log) async {}
}

/// A child read without a server (no roster: names can't be shown).
ChildData _bare({
  List<Treatment> treatments = const [],
  List<DoseLog> logs = const [],
}) => ChildData(
  entry: const SpaceEntry(
    info: SpaceInfo(
      id: 's1',
      app: 'meds',
      keyEpoch: 1,
      myRole: SpaceRole.admin,
    ),
  ),
  child: const Child(name: 'Noa', timeZone: 'UTC'),
  medications: const [],
  treatments: treatments,
  logs: logs,
  zone: zoneOf('UTC'),
);

/// Children Mum manages, each in its own space, read back as the app does.
Future<List<ChildData>> _family(
  WidgetTester tester,
  List<(String, List<Treatment>, List<DoseLog>)> kids,
) async {
  late List<ChildData> out;
  await tester.runAsync(() async {
    final server = InMemorySpaceServer();
    final phone = await Phone(server, mum, 1).start();
    out = [];
    for (final (name, treatments, logs) in kids) {
      final space = await phone.spaces.create(myName: 'Mum');
      await space.save(
        Child.itemId,
        Child(name: name, timeZone: 'UTC').toJson(),
      );
      for (final t in treatments) {
        await space.save(t.id, t.toJson());
      }
      for (final l in logs) {
        await space.save(l.id, l.toJson());
      }
      await phone.spaces.sync(space);
      out.add((await phone.child(space.id))!);
    }
  });
  return out;
}

Future<void> _pumpHome(
  WidgetTester tester,
  ChildData noa, {
  Locale? locale,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nowProvider.overrideWith(
          (ref) => Stream.value(DateTime.utc(2026, 1, 12, 16)),
        ),
        familyProvider.overrideWith(
          (ref) async =>
              FamilyData(children: [noa], ready: true, loading: false),
        ),
        pendingJoinsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        supportedLocales: ZtLanguages.supported,
        home: const HomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
