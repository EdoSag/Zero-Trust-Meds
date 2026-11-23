import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/logic/stock.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/reminders/reminder_plan.dart';
import 'package:zerotrust_meds/ui/stock_sheet.dart';

import 'support/phone.dart';

const amox = Medication(
  id: 'med-1',
  name: 'Amoxicillin',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

class _Texts implements ReminderTexts {
  @override
  String doseTitle(String child, String medicine) => 'dose';
  @override
  String doseBody(String dose, String time) => '';
  @override
  String followUpTitle(String child, String medicine) => '';
  @override
  String followUpBody(String time) => '';
  @override
  String missedTitle(String child, String medicine) => '';
  @override
  String missedBody(String time) => '';
  @override
  String lastDayTitle(String child, String medicine) => '';
  @override
  String get lastDayBody => '';
  @override
  String refillTitle(String child, String medicine) =>
      'order $medicine for $child';
  @override
  String refillBody(LocalDate? runsOut) => 'runs out $runsOut';
  @override
  String get privateTitle => 'private';
  @override
  String get privateBody => 'private';
  @override
  String doseOf(Medication m) => '';
  @override
  String timeOf(DateTime utc) => '';
}

DoseLog given(String id, DateTime at, {Medication? oneTime}) => DoseLog(
  id: 'dose/$id',
  treatmentId: oneTime == null ? 't1' : '',
  action: DoseAction.given,
  at: at,
  byUserId: dad,
  medication: oneTime,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('the sums', () {
    final stock = MedStock(
      id: 'stock/1',
      medicine: 'Vitamin D',
      count: 30,
      countedAt: DateTime.utc(2026, 1, 10, 6),
    );

    test('doses after the count come off; runs out and order-by follow', () {
      final s = StockMath.of(
        stock: stock,
        given: [
          (at: DateTime.utc(2026, 1, 9, 8), amount: 1), // before the count
          for (var h = 8; h <= 20; h += 12)
            (at: DateTime.utc(2026, 1, 10, h), amount: 1),
          (at: DateTime.utc(2026, 1, 11, 8), amount: 1),
        ],
        plannedPerDay: 2,
        nowUtc: DateTime.utc(2026, 1, 11, 12),
        today: LocalDate.parse('2026-01-11'),
      );
      expect(s.left, 27);
      expect(s.perDay, 2);
      // 27 / 2 = 13 whole days from today.
      expect(s.runsOutOn, LocalDate.parse('2026-01-24'));
      expect(s.orderBy, LocalDate.parse('2026-01-17'));
      expect(s.lowOn(LocalDate.parse('2026-01-16')), isFalse);
      expect(s.lowOn(LocalDate.parse('2026-01-17')), isTrue);
    });

    test('as needed: the last two weeks\' average; never below zero', () {
      final s = StockMath.of(
        stock: stock.copyWithCount(1),
        given: [
          for (var d = 1; d <= 7; d++)
            (at: DateTime.utc(2026, 1, d + 3, 9), amount: 2),
        ],
        plannedPerDay: 0,
        nowUtc: DateTime.utc(2026, 1, 11, 12),
        today: LocalDate.parse('2026-01-11'),
      );
      // Only 10 Jan's dose (2) came after the count of 1.
      expect(s.perDay, 1); // 14 over 14 days
      expect(s.left, 0);
      expect(s.isOut, isTrue);
      expect(s.runsOutOn, LocalDate.parse('2026-01-11'));
    });

    test('nothing given and nothing planned: no run-out date', () {
      final s = StockMath.of(
        stock: stock,
        given: const [],
        plannedPerDay: 0,
        nowUtc: DateTime.utc(2026, 1, 11),
        today: LocalDate.parse('2026-01-11'),
      );
      expect(s.left, 30);
      expect(s.runsOutOn, isNull);
      expect(s.lowOn(LocalDate.parse('2026-01-11')), isFalse);
    });
  });

  group('in a family', () {
    late InMemorySpaceServer server;
    late Phone mumPhone, dadPhone;
    late String spaceId;

    setUp(() async {
      server = InMemorySpaceServer();
      mumPhone = await Phone(server, mum, 1).start();
      dadPhone = await Phone(server, dad, 2).start();
      final space = await mumPhone.spaces.create(myName: 'Mum');
      spaceId = space.id;
      await space.save(
        Child.itemId,
        const Child(
          name: 'Savta',
          timeZone: 'UTC',
          role: PersonRole.parent,
        ).toJson(),
      );
      await space.save(
        't1',
        Treatment(
          id: 't1',
          medication: amox,
          schedule: const FixedTimes([TimeOfDose(8, 0), TimeOfDose(20, 0)]),
          startDate: LocalDate.parse('2026-01-10'),
        ).toJson(),
      );
      await mumPhone.spaces.sync(space);
      final link = await mumPhone.spaces.invite(spaceId);
      await dadPhone.spaces.answer(
        SpaceInviteLink.parse(link.toString()),
        myName: 'Dad',
      );
      await mumPhone.spaces.confirm(
        (await mumPhone.spaces.pendingJoins(spaceId)).single,
      );
    });

    test('a caregiver counts; doses of the same medicine come off, by name, '
        'and the order-more reminder comes the morning it is due', () async {
      // Dad (not an admin) counts 100 ml on 10 Jan at 07:00.
      final dadSpace = await dadPhone.spaces.open(spaceId);
      await dadPhone.spaces.sync(dadSpace);
      await dadSpace.save(
        'stock/s1',
        MedStock(
          id: 'stock/s1',
          medicine: 'Amoxicillin',
          count: 100,
          countedAt: DateTime.utc(2026, 1, 10, 7),
          byUserId: dad,
        ).toJson(),
      );
      for (final l in [
        given('a', DateTime.utc(2026, 1, 9, 20)), // before the count
        given('b', DateTime.utc(2026, 1, 10, 8)),
        given('c', DateTime.utc(2026, 1, 10, 20)),
        // A one-time dose of the same medicine, spelled differently.
        given(
          'd',
          DateTime.utc(2026, 1, 11, 2),
          oneTime: const Medication(
            id: 'x',
            name: 'amoxicillin ',
            amount: 5,
            unit: 'ml',
          ),
        ),
      ]) {
        await dadSpace.save(l.id, l.toJson());
      }
      await dadPhone.spaces.sync(dadSpace);

      // Mum's phone accepts Dad's count.
      final c = (await mumPhone.child(spaceId))!;
      expect(c.stocks, hasLength(1));
      final now = DateTime.utc(2026, 1, 11, 12);
      final s = c.stockOf(
        const Medication(id: 'y', name: 'AMOXICILLIN', amount: 5, unit: 'ml'),
        now,
      )!;
      expect(s.left, 85);
      expect(s.perDay, 10);
      expect(s.runsOutOn, LocalDate.parse('2026-01-19'));
      expect(s.orderBy, LocalDate.parse('2026-01-12'));

      final r = ReminderPlan.plan(
        [c],
        const ReminderPrefs(),
        _Texts(),
        now,
      ).where((x) => x.kind == ReminderKind.refill).toList();
      // Every morning from the order-by day, set ahead so they keep coming
      // while the app stays closed.
      expect(r.map((x) => x.at), [
        for (var d = 12; d < 12 + ReminderPlan.refillMornings; d++)
          DateTime.utc(2026, 1, d, 9),
      ]);
      expect(r.first.title, 'order Amoxicillin for Savta');
      expect(r.first.body, 'runs out 2026-01-19');
      expect(r.first.offersGiven, isFalse);
      expect(r.map((x) => x.notificationId).toSet(), hasLength(r.length));

      // Past the order-by day: from the next morning, until someone counts
      // again.
      final later = DateTime.utc(2026, 1, 14, 10);
      expect(
        ReminderPlan.plan(
          [c],
          const ReminderPrefs(),
          _Texts(),
          later,
        ).where((x) => x.kind == ReminderKind.refill).map((x) => x.at).first,
        DateTime.utc(2026, 1, 15, 9),
      );

      // Off in the settings: none.
      expect(
        ReminderPlan.plan(
          [c],
          const ReminderPrefs(refillNotice: false),
          _Texts(),
          now,
        ).where((x) => x.kind == ReminderKind.refill),
        isEmpty,
      );
    });

    test('the newest count wins when two were made', () async {
      final space = await mumPhone.spaces.open(spaceId);
      for (final (id, count, hour) in [
        ('stock/a', 50.0, 7),
        ('stock/b', 20.0, 9),
      ]) {
        await space.save(
          id,
          MedStock(
            id: id,
            medicine: 'Amoxicillin',
            count: count,
            countedAt: DateTime.utc(2026, 1, 10, hour),
          ).toJson(),
        );
      }
      final c = (await mumPhone.child(spaceId))!;
      expect(c.stockFor(amox)!.id, 'stock/b');
      expect(c.stockOf(amox, DateTime.utc(2026, 1, 10, 10))!.left, 20);
    });

    test('other units never mix, and an edited dose does not change what '
        'was given', () async {
      final space = await mumPhone.spaces.open(spaceId);
      await space.save(
        'stock/s1',
        MedStock(
          id: 'stock/s1',
          medicine: 'Amoxicillin',
          count: 100,
          countedAt: DateTime.utc(2026, 1, 10, 7),
          unit: 'ml',
        ).toJson(),
      );
      for (final l in [
        // Given as 5 ml, logged with its amount.
        DoseLog(
          id: 'dose/b',
          treatmentId: 't1',
          action: DoseAction.given,
          at: DateTime.utc(2026, 1, 10, 8),
          byUserId: mum,
          amount: 5,
          unit: 'ml',
        ),
        // Tablets of the same name: a different count.
        given(
          'd',
          DateTime.utc(2026, 1, 10, 12),
          oneTime: const Medication(
            id: 'x',
            name: 'Amoxicillin',
            form: MedForm.tablet,
            amount: 1,
            unit: 'tablet',
          ),
        ),
      ]) {
        await space.save(l.id, l.toJson());
      }
      // The dose is edited to 10 ml afterwards.
      await space.save(
        't1',
        Treatment(
          id: 't1',
          medication: const Medication(
            id: 'med-1',
            name: 'Amoxicillin',
            form: MedForm.liquid,
            amount: 10,
            unit: 'ml',
          ),
          schedule: const FixedTimes([TimeOfDose(8, 0), TimeOfDose(20, 0)]),
          startDate: LocalDate.parse('2026-01-10'),
        ).toJson(),
      );
      final c = (await mumPhone.child(spaceId))!;
      final now = DateTime.utc(2026, 1, 10, 13);
      expect(c.stockOf(c.treatments.single.medication, now)!.left, 95);
      const tablets = Medication(
        id: 'x',
        name: 'Amoxicillin',
        form: MedForm.tablet,
        amount: 1,
        unit: 'tablet',
      );
      expect(c.stockFor(tablets), isNull);
    });

    test('a medicine counted as empty is due the next morning, even when '
        'how fast it goes is unknown', () async {
      final space = await mumPhone.spaces.open(spaceId);
      const ibu = Medication(
        id: 'med-2',
        name: 'Ibuprofen',
        form: MedForm.liquid,
        amount: 5,
        unit: 'ml',
      );
      await space.save(
        't2',
        Treatment(
          id: 't2',
          medication: ibu,
          schedule: const AsNeeded(minIntervalMinutes: 360),
          startDate: LocalDate.parse('2026-01-10'),
        ).toJson(),
      );
      await space.save(
        'stock/i',
        MedStock(
          id: 'stock/i',
          medicine: 'Ibuprofen',
          count: 0,
          countedAt: DateTime.utc(2026, 1, 10, 7),
          unit: 'ml',
        ).toJson(),
      );
      final c = (await mumPhone.child(spaceId))!;
      final now = DateTime.utc(2026, 1, 10, 12);
      expect(c.stockOf(ibu, now)!.perDay, isNull);
      final r = ReminderPlan.plan(
        [c],
        const ReminderPrefs(),
        _Texts(),
        now,
      ).where((x) => x.kind == ReminderKind.refill && x.treatmentId == 't2');
      expect(r.first.at, DateTime.utc(2026, 1, 11, 9));
      expect(r.first.body, 'runs out null');
    });
  });

  test('settings saved before order-more reminders existed have them on', () {
    expect(ReminderPrefs.fromJson({'enabled': true}).refillNotice, isTrue);
    expect(
      ReminderPrefs.fromJson(
        const ReminderPrefs(refillNotice: false).toJson(),
      ).refillNotice,
      isFalse,
    );
  });

  testWidgets('the supply line says when to order more, with an icon', (
    tester,
  ) async {
    final low = StockMath.of(
      stock: MedStock(
        id: 'stock/1',
        medicine: 'Amoxicillin',
        count: 40,
        countedAt: DateTime.utc(2026, 1, 10),
      ),
      given: const [],
      plannedPerDay: 10,
      nowUtc: DateTime.utc(2026, 1, 10, 12),
      today: LocalDate.parse('2026-01-10'),
    );
    Future<void> show(LocalDate today) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppL10n.delegate,
          ZtL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: StockLine(low, amox, today: today)),
      ),
    );
    await show(LocalDate.parse('2026-01-10'));
    await tester.pumpAndSettle();
    // 4 days' worth: runs out 14 Jan, order by 7 Jan: already time.
    expect(find.textContaining('Order more'), findsOneWidget);
    expect(find.textContaining('About 40 ml left'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}

extension on MedStock {
  MedStock copyWithCount(double count) => MedStock(
    id: id,
    medicine: medicine,
    count: count,
    countedAt: countedAt,
    warnDays: warnDays,
  );
}
