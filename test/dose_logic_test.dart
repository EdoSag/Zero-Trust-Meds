import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zerotrust_meds/logic/dose_logic.dart';
import 'package:zerotrust_meds/model/models.dart';

const med = Medication(
  id: 'm1',
  name: 'Amoxicillin',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

Treatment fixed(
  List<String> times, {
  String start = '2026-03-26',
  int? days = 5,
  List<Pause> pauses = const [],
}) => Treatment(
  id: 't1',
  medication: med,
  schedule: FixedTimes([for (final t in times) TimeOfDose.parse(t)]),
  startDate: LocalDate.parse(start),
  days: days,
  pauses: pauses,
);

Treatment asNeeded({int minInterval = 240, int? max = 4}) => Treatment(
  id: 'p1',
  medication: med,
  schedule: AsNeeded(minIntervalMinutes: minInterval, maxPer24h: max),
  startDate: LocalDate.parse('2026-01-01'),
);

DoseLog given(
  String treatmentId,
  DateTime at, {
  String? date,
  String? time,
  String id = 'l',
  String by = 'u1',
}) => DoseLog(
  id: id,
  treatmentId: treatmentId,
  action: DoseAction.given,
  at: at,
  byUserId: by,
  slotDate: date == null ? null : LocalDate.parse(date),
  slotTime: time == null ? null : TimeOfDose.parse(time),
);

void main() {
  setUpAll(tzdata.initializeTimeZones);
  late tz.Location jerusalem;
  late tz.Location newYork;
  setUp(() {
    jerusalem = tz.getLocation('Asia/Jerusalem');
    newYork = tz.getLocation('America/New_York');
  });

  group('ChildClock', () {
    test('ordinary day maps wall time with the zone offset', () {
      // Jerusalem is UTC+2 in winter.
      expect(
        ChildClock.instant(
          jerusalem,
          LocalDate.parse('2026-01-10'),
          const TimeOfDose(8, 0),
        ),
        DateTime.utc(2026, 1, 10, 6),
      );
      // and UTC+3 in summer.
      expect(
        ChildClock.instant(
          jerusalem,
          LocalDate.parse('2026-07-10'),
          const TimeOfDose(8, 0),
        ),
        DateTime.utc(2026, 7, 10, 5),
      );
    });

    test('spring forward: a time in the gap happens just after the jump', () {
      // New York 2026-03-08: 02:00 jumps to 03:00 (UTC-5 -> UTC-4).
      final at = ChildClock.instant(
        newYork,
        LocalDate.parse('2026-03-08'),
        const TimeOfDose(2, 30),
      );
      expect(at, DateTime.utc(2026, 3, 8, 7, 30));
      final local = tz.TZDateTime.from(at, newYork);
      expect((local.hour, local.minute), (3, 30));
      // 08:00 that day is EDT.
      expect(
        ChildClock.instant(
          newYork,
          LocalDate.parse('2026-03-08'),
          const TimeOfDose(8, 0),
        ),
        DateTime.utc(2026, 3, 8, 12),
      );
    });

    test('fall back: a repeated time counts once, at its first occurrence', () {
      // New York 2026-11-01: 02:00 goes back to 01:00 (UTC-4 -> UTC-5).
      final at = ChildClock.instant(
        newYork,
        LocalDate.parse('2026-11-01'),
        const TimeOfDose(1, 30),
      );
      expect(at, DateTime.utc(2026, 11, 1, 5, 30));
      final t = fixed(['01:30'], start: '2026-10-31', days: 3);
      final doses = ChildClock.planned(
        t,
        newYork,
        LocalDate.parse('2026-10-31'),
        LocalDate.parse('2026-11-02'),
      );
      expect(doses, hasLength(3));
      expect(doses.map((d) => d.at).toSet(), hasLength(3));
    });

    test(
      'a 5-day course gives every dose exactly once across a DST change',
      () {
        // Israel goes to summer time on Friday 2026-03-27.
        final t = fixed(['08:00', '20:00'], start: '2026-03-25', days: 5);
        final doses = ChildClock.planned(
          t,
          jerusalem,
          LocalDate.parse('2026-03-20'),
          LocalDate.parse('2026-04-10'),
        );
        expect(doses, hasLength(10));
        expect(doses.first.date, LocalDate.parse('2026-03-25'));
        expect(doses.last.date, LocalDate.parse('2026-03-29'));
        for (final d in doses) {
          final local = tz.TZDateTime.from(d.at, jerusalem);
          expect((local.hour, local.minute), (d.time.hour, d.time.minute));
        }
        expect(doses[0].at, DateTime.utc(2026, 3, 25, 6));
        expect(doses[8].at, DateTime.utc(2026, 3, 29, 5));
      },
    );

    test('ending early stops planned doses after that day', () {
      final t = Treatment(
        id: 't1',
        medication: med,
        schedule: FixedTimes(const [TimeOfDose(8, 0)]),
        startDate: LocalDate.parse('2026-01-01'),
        days: 10,
        endedOn: LocalDate.parse('2026-01-03'),
      );
      final doses = ChildClock.planned(
        t,
        jerusalem,
        LocalDate.parse('2026-01-01'),
        LocalDate.parse('2026-01-31'),
      );
      expect(doses, hasLength(3));
      expect(t.isFinishedBy(LocalDate.parse('2026-01-04')), isTrue);
      expect(t.isFinishedBy(LocalDate.parse('2026-01-03')), isFalse);
    });

    test('as-needed treatments have no planned doses', () {
      expect(
        ChildClock.planned(
          asNeeded(),
          jerusalem,
          LocalDate.parse('2026-01-01'),
          LocalDate.parse('2026-01-05'),
        ),
        isEmpty,
      );
    });

    test('today is the child\'s day, not the phone\'s', () {
      // 23:30 UTC on Jan 10 is already Jan 11 in Jerusalem.
      expect(
        ChildClock.today(jerusalem, DateTime.utc(2026, 1, 10, 23, 30)),
        LocalDate.parse('2026-01-11'),
      );
    });
  });

  group('DoseRules.statusOf', () {
    late PlannedDose dose;
    const window = Duration(hours: 2);
    setUp(() {
      dose = ChildClock.planned(
        fixed(['08:00'], start: '2026-01-10', days: 1),
        jerusalem,
        LocalDate.parse('2026-01-10'),
        LocalDate.parse('2026-01-10'),
      ).single; // 06:00 UTC
    });

    DoseState at(DateTime now, [List<DoseLog> logs = const []]) =>
        DoseRules.statusOf(dose, logs, now, missedAfter: window).state;

    test(
      'upcoming, then due from 30 minutes before, then missed after the window',
      () {
        expect(at(DateTime.utc(2026, 1, 10, 5, 29)), DoseState.upcoming);
        expect(at(DateTime.utc(2026, 1, 10, 5, 30)), DoseState.due);
        expect(at(DateTime.utc(2026, 1, 10, 7, 59)), DoseState.due);
        expect(at(DateTime.utc(2026, 1, 10, 8, 0)), DoseState.missed);
      },
    );

    test('the missed window is configurable', () {
      expect(
        DoseRules.statusOf(
          dose,
          const [],
          DateTime.utc(2026, 1, 10, 6, 31),
          missedAfter: const Duration(minutes: 30),
        ).state,
        DoseState.missed,
      );
      expect(DoseRules.missedAt(dose, window), DateTime.utc(2026, 1, 10, 8));
    });

    test('a logged dose is given even when logged late', () {
      final log = given(
        't1',
        DateTime.utc(2026, 1, 10, 9),
        date: '2026-01-10',
        time: '08:00',
      );
      final s = DoseRules.statusOf(
        dose,
        [log],
        DateTime.utc(2026, 1, 10, 12),
        missedAfter: window,
      );
      expect(s.state, DoseState.given);
      expect(s.givenTwice, isFalse);
    });

    test('a record for another slot or treatment does not count', () {
      expect(
        at(DateTime.utc(2026, 1, 10, 12), [
          given(
            't1',
            DateTime.utc(2026, 1, 10, 6),
            date: '2026-01-10',
            time: '20:00',
          ),
          given(
            't2',
            DateTime.utc(2026, 1, 10, 6),
            date: '2026-01-10',
            time: '08:00',
          ),
        ]),
        DoseState.missed,
      );
    });

    test('skipped with a reason', () {
      final skip = DoseLog(
        id: 's',
        treatmentId: 't1',
        action: DoseAction.skipped,
        at: DateTime.utc(2026, 1, 10, 6),
        byUserId: 'u1',
        slotDate: LocalDate.parse('2026-01-10'),
        slotTime: const TimeOfDose(8, 0),
        reason: 'Vomited',
      );
      final s = DoseRules.statusOf(
        dose,
        [skip],
        DateTime.utc(2026, 1, 10, 12),
        missedAfter: window,
      );
      expect(s.state, DoseState.skipped);
      expect(s.logs.single.reason, 'Vomited');
    });

    test('two caregivers giving the same dose is shown as given twice', () {
      final s = DoseRules.statusOf(
        dose,
        [
          given(
            't1',
            DateTime.utc(2026, 1, 10, 6, 5),
            date: '2026-01-10',
            time: '08:00',
            id: 'a',
            by: 'mum',
          ),
          given(
            't1',
            DateTime.utc(2026, 1, 10, 6, 1),
            date: '2026-01-10',
            time: '08:00',
            id: 'b',
            by: 'dad',
          ),
        ],
        DateTime.utc(2026, 1, 10, 7),
        missedAfter: window,
      );
      expect(s.state, DoseState.given);
      expect(s.givenTwice, isTrue);
      expect(s.logs.map((l) => l.byUserId), ['dad', 'mum']);
    });

    test('paused doses are neither due nor missed', () {
      final t = fixed(
        ['08:00'],
        start: '2026-01-10',
        days: 1,
        pauses: [Pause(DateTime.utc(2026, 1, 9))],
      );
      final d = ChildClock.planned(
        t,
        jerusalem,
        LocalDate.parse('2026-01-10'),
        LocalDate.parse('2026-01-10'),
      ).single;
      expect(
        DoseRules.statusOf(
          d,
          const [],
          DateTime.utc(2026, 1, 11),
          missedAfter: window,
        ).state,
        DoseState.paused,
      );
    });
  });

  group('DoseGuard', () {
    test('warns before giving a planned dose that is already given', () {
      final t = fixed(['08:00'], start: '2026-01-10', days: 1);
      final slot = ChildClock.planned(
        t,
        jerusalem,
        LocalDate.parse('2026-01-10'),
        LocalDate.parse('2026-01-10'),
      ).single;
      final logs = [
        given(
          't1',
          DateTime.utc(2026, 1, 10, 6),
          date: '2026-01-10',
          time: '08:00',
        ),
      ];
      final w = DoseGuard.beforeGiving(
        t: t,
        logs: logs,
        at: DateTime.utc(2026, 1, 10, 6, 10),
        slot: slot,
      );
      expect(w.single, isA<AlreadyGiven>());
      expect(
        DoseGuard.beforeGiving(
          t: t,
          logs: const [],
          at: DateTime.utc(2026, 1, 10, 6),
          slot: slot,
        ),
        isEmpty,
      );
    });

    test('as-needed: warns inside the minimum interval, on either side', () {
      final t = asNeeded(minInterval: 240);
      final logs = [given('p1', DateTime.utc(2026, 1, 10, 10))];
      final soon = DoseGuard.beforeGiving(
        t: t,
        logs: logs,
        at: DateTime.utc(2026, 1, 10, 13),
      );
      expect(soon.single, isA<TooSoon>());
      expect(
        (soon.single as TooSoon).nextAllowed,
        DateTime.utc(2026, 1, 10, 14),
      );
      // A dose back-dated to just before an existing one also warns.
      expect(
        DoseGuard.beforeGiving(
          t: t,
          logs: logs,
          at: DateTime.utc(2026, 1, 10, 8),
        ),
        [isA<TooSoon>()],
      );
      expect(
        DoseGuard.beforeGiving(
          t: t,
          logs: logs,
          at: DateTime.utc(2026, 1, 10, 14),
        ),
        isEmpty,
      );
    });

    test('as-needed: warns at the maximum per 24 hours', () {
      final t = asNeeded(minInterval: 0, max: 3);
      final logs = [
        for (final h in [1, 7, 13])
          given('p1', DateTime.utc(2026, 1, 10, h), id: 'l$h'),
      ];
      final w = DoseGuard.beforeGiving(
        t: t,
        logs: logs,
        at: DateTime.utc(2026, 1, 10, 20),
      );
      final max = w.single as MaxReached;
      expect(max.count, 3);
      expect(max.nextAllowed, DateTime.utc(2026, 1, 11, 1));
      expect(
        DoseGuard.nextAllowed(t, logs, DateTime.utc(2026, 1, 10, 20)),
        DateTime.utc(2026, 1, 11, 1),
      );
      // After the first falls out of the window it's fine again.
      expect(
        DoseGuard.beforeGiving(
          t: t,
          logs: logs,
          at: DateTime.utc(2026, 1, 11, 1, 1),
        ),
        isEmpty,
      );
    });

    test('skipped records never count toward double doses', () {
      final t = asNeeded();
      final logs = [
        DoseLog(
          id: 's',
          treatmentId: 'p1',
          action: DoseAction.skipped,
          at: DateTime.utc(2026, 1, 10, 10),
          byUserId: 'u1',
        ),
      ];
      expect(
        DoseGuard.beforeGiving(
          t: t,
          logs: logs,
          at: DateTime.utc(2026, 1, 10, 10, 30),
        ),
        isEmpty,
      );
      expect(
        DoseGuard.nextAllowed(t, logs, DateTime.utc(2026, 1, 10, 11)),
        DateTime.utc(2026, 1, 10, 11),
      );
    });
  });

  test('adherence counts given, missed and skipped, not upcoming', () {
    final t = fixed(['08:00', '20:00'], start: '2026-01-10', days: 2);
    final doses = ChildClock.planned(
      t,
      jerusalem,
      LocalDate.parse('2026-01-10'),
      LocalDate.parse('2026-01-11'),
    );
    final logs = [
      given(
        't1',
        DateTime.utc(2026, 1, 10, 6),
        date: '2026-01-10',
        time: '08:00',
      ),
      given(
        't1',
        DateTime.utc(2026, 1, 11, 6),
        date: '2026-01-11',
        time: '08:00',
      ),
    ];
    final now = DateTime.utc(2026, 1, 11, 12);
    final a = Adherence.of([
      for (final d in doses)
        DoseRules.statusOf(d, logs, now, missedAfter: const Duration(hours: 2)),
    ]);
    expect((a.given, a.missed, a.skipped), (2, 1, 0));
    expect(a.percent, 67);
    expect(const Adherence().percent, isNull);
  });
}
