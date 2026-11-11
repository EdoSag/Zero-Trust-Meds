import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/logic/dose_logic.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/reminders/reminder_plan.dart';

import 'support/phone.dart';

class FakeTexts implements ReminderTexts {
  @override
  String doseTitle(String child, String medicine) => 'dose $child $medicine';
  @override
  String doseBody(String dose, String time) => '$dose at $time';
  @override
  String followUpTitle(String child, String medicine) =>
      'follow $child $medicine';
  @override
  String followUpBody(String time) => 'still $time';
  @override
  String missedTitle(String child, String medicine) =>
      'missed $child $medicine';
  @override
  String missedBody(String time) => 'missed $time';
  @override
  String lastDayTitle(String child, String medicine) => 'last $child $medicine';
  @override
  String get lastDayBody => 'last day';
  @override
  String get privateTitle => 'Medicine reminder';
  @override
  String get privateBody => 'Open the app';
  @override
  String doseOf(Medication m) => '${m.amount} ${m.unit}';
  @override
  String timeOf(DateTime utc) => utc.toIso8601String();
}

const amox = Medication(
  id: 'med-1',
  name: 'Amoxicillin',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

Treatment course(
  String id, {
  List<TimeOfDose> times = const [TimeOfDose(8, 0), TimeOfDose(20, 0)],
  String start = '2026-01-10',
  int? days = 7,
  List<Pause> pauses = const [],
  DoseSchedule? schedule,
}) => Treatment(
  id: id,
  medication: amox,
  schedule: schedule ?? FixedTimes(times),
  startDate: LocalDate.parse(start),
  days: days,
  pauses: pauses,
);

/// A child on Mum's phone (and Dad's, as caregiver when [withDad]).
class Family {
  Family._(this.server, this.phone, this.spaceId);
  final InMemorySpaceServer server;
  final Phone phone;
  final String spaceId;

  static Future<Family> start({
    String zone = 'UTC',
    int missedAfterMinutes = 120,
    List<Treatment> treatments = const [],
  }) async {
    final server = InMemorySpaceServer();
    final mumPhone = await Phone(server, mum, 1).start();
    final space = await mumPhone.spaces.create(myName: 'Mum');
    await space.save(
      Child.itemId,
      Child(
        name: 'Noa',
        timeZone: zone,
        missedAfterMinutes: missedAfterMinutes,
      ).toJson(),
    );
    for (final t in treatments) {
      await space.save(t.id, t.toJson());
    }
    await mumPhone.spaces.sync(space);
    return Family._(server, mumPhone, space.id);
  }

  Future<void> log(DoseLog l) async {
    final space = await phone.spaces.open(spaceId);
    await space.save(l.id, l.toJson());
  }

  Future<ChildData> child() async => (await phone.child(spaceId))!;
}

DoseLog given(String id, String date, TimeOfDose time, DateTime at) => DoseLog(
  id: id,
  treatmentId: 't1',
  action: DoseAction.given,
  at: at,
  byUserId: dad,
  slotDate: LocalDate.parse(date),
  slotTime: time,
);

List<MedsReminder> plan(
  ChildData c,
  DateTime now, [
  ReminderPrefs prefs = const ReminderPrefs(),
]) => ReminderPlan.plan([c], prefs, FakeTexts(), now);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('each planned dose gets a reminder, a follow-up and a missed alert; '
      'past doses get none', () async {
    final f = await Family.start(treatments: [course('t1')]);
    final c = await f.child();
    // 12 Jan 10:00 UTC: today's 08:00 is past (its missed alert at 10:00 is
    // not after now), 20:00 is ahead.
    final now = DateTime.utc(2026, 1, 12, 10);
    final r = plan(c, now);
    final today = r.where((x) => x.date == LocalDate.parse('2026-01-12'));
    expect(today.map((x) => (x.kind, x.at)), [
      (ReminderKind.dose, DateTime.utc(2026, 1, 12, 20)),
      (ReminderKind.followUp, DateTime.utc(2026, 1, 12, 20, 30)),
      (ReminderKind.missed, DateTime.utc(2026, 1, 12, 22)),
    ]);
    expect(r.every((x) => x.at.isAfter(now)), isTrue);
    // Course runs to 16 Jan: 4 more days x 2 doses x 3, plus today's
    // evening (3) and the last-day notice.
    expect(r.where((x) => x.kind == ReminderKind.dose).length, 9);
    expect(r.where((x) => x.kind == ReminderKind.lastDay).length, 1);
    expect(r.last.date, LocalDate.parse('2026-01-16'));
    // Soonest first.
    for (var i = 1; i < r.length; i++) {
      expect(r[i].at.isBefore(r[i - 1].at), isFalse);
    }
  });

  test("a dose another caregiver logged cancels its reminders once synced "
      'here', () async {
    final f = await Family.start(treatments: [course('t1')]);
    final now = DateTime.utc(2026, 1, 12, 19);
    var r = plan(await f.child(), now);
    expect(r.where((x) => x.date == LocalDate.parse('2026-01-12')).length, 3);
    await f.log(
      given(
        'dose/1',
        '2026-01-12',
        const TimeOfDose(20, 0),
        DateTime.utc(2026, 1, 12, 19, 50),
      ),
    );
    r = plan(await f.child(), now);
    expect(r.where((x) => x.date == LocalDate.parse('2026-01-12')), isEmpty);
    // A skipped dose is answered too.
    await f.log(
      DoseLog(
        id: 'dose/2',
        treatmentId: 't1',
        action: DoseAction.skipped,
        at: DateTime.utc(2026, 1, 12, 19),
        byUserId: mum,
        slotDate: LocalDate.parse('2026-01-13'),
        slotTime: const TimeOfDose(8, 0),
        reason: 'Asleep',
      ),
    );
    r = plan(await f.child(), now);
    expect(
      r.where(
        (x) =>
            x.date == LocalDate.parse('2026-01-13') &&
            x.time == const TimeOfDose(8, 0),
      ),
      isEmpty,
    );
  });

  test('times are the child\'s wall clock, set as instants', () async {
    final f = await Family.start(
      zone: 'America/New_York',
      treatments: [
        course('t1', times: const [TimeOfDose(8, 0)]),
      ],
    );
    final r = plan(await f.child(), DateTime.utc(2026, 1, 12, 0));
    final first = r.firstWhere((x) => x.kind == ReminderKind.dose);
    // 08:00 in New York in January is 13:00 UTC, whatever zone the phone
    // reading it is in.
    expect(first.at, DateTime.utc(2026, 1, 12, 13));
    expect(first.date, LocalDate.parse('2026-01-12'));
  });

  test(
    'a time skipped by the spring-forward jump still reminds once',
    () async {
      final f = await Family.start(
        zone: 'Europe/London',
        treatments: [
          course(
            't1',
            times: const [TimeOfDose(1, 30)],
            start: '2026-03-28',
            days: 3,
          ),
        ],
      );
      final r = plan(await f.child(), DateTime.utc(2026, 3, 27, 12));
      final doses = [
        for (final x in r)
          if (x.kind == ReminderKind.dose) x,
      ];
      expect(doses.map((x) => x.date.toString()), [
        '2026-03-28',
        '2026-03-29',
        '2026-03-30',
      ]);
      // 29 Mar 01:30 doesn't exist in London: just after the jump.
      expect(
        doses[1].at,
        ChildClock.instant(
          tz.getLocation('Europe/London'),
          LocalDate.parse('2026-03-29'),
          const TimeOfDose(1, 30),
        ),
      );
      expect(doses[1].at, DateTime.utc(2026, 3, 29, 1, 30));
    },
  );

  test('a paused course gets no reminders while paused', () async {
    final f = await Family.start(
      treatments: [
        course('t1', pauses: [Pause(DateTime.utc(2026, 1, 12, 9))]),
      ],
    );
    final r = plan(await f.child(), DateTime.utc(2026, 1, 12, 10));
    expect(r, isEmpty);

    final resumed = await Family.start(
      treatments: [
        course(
          't1',
          pauses: [
            Pause(DateTime.utc(2026, 1, 12, 9), DateTime.utc(2026, 1, 13, 12)),
          ],
        ),
      ],
    );
    final r2 = plan(await resumed.child(), DateTime.utc(2026, 1, 12, 10));
    expect(
      r2.where((x) => x.kind == ReminderKind.dose).first.at,
      DateTime.utc(2026, 1, 13, 20),
    );
  });

  test('last-day notice at 9:00 in the child\'s zone, not for a one-day '
      'course, and only when wanted', () async {
    final f = await Family.start(
      zone: 'Asia/Jerusalem',
      treatments: [
        course('t1', days: 3),
        course('t2', days: 1, start: '2026-01-11'),
        course(
          't3',
          schedule: const AsNeeded(minIntervalMinutes: 360),
          start: '2026-01-10',
          days: 5,
        ),
      ],
    );
    final c = await f.child();
    final now = DateTime.utc(2026, 1, 10, 12);
    final last = [
      for (final x in plan(c, now))
        if (x.kind == ReminderKind.lastDay) x,
    ];
    // 09:00 in Jerusalem (UTC+2) is 07:00 UTC.
    expect(last.map((x) => (x.treatmentId, x.at)), [
      ('t1', DateTime.utc(2026, 1, 12, 7)),
      ('t3', DateTime.utc(2026, 1, 14, 7)),
    ]);
    expect(last.first.offersGiven, isFalse);
    // As needed: no dose reminders, only the notice.
    expect(
      plan(
        c,
        now,
      ).where((x) => x.treatmentId == 't3' && x.kind != ReminderKind.lastDay),
      isEmpty,
    );
    expect(
      plan(
        c,
        now,
        const ReminderPrefs(lastDayNotice: false),
      ).where((x) => x.kind == ReminderKind.lastDay),
      isEmpty,
    );
  });

  test('settings: off, muted child, no follow-up, no missed alert', () async {
    final f = await Family.start(treatments: [course('t1')]);
    final c = await f.child();
    final now = DateTime.utc(2026, 1, 12, 10);
    expect(plan(c, now, const ReminderPrefs(enabled: false)), isEmpty);
    expect(plan(c, now, ReminderPrefs(mutedChildren: {c.spaceId})), isEmpty);
    final kinds = plan(
      c,
      now,
      const ReminderPrefs(followUpMinutes: 0, missedAlerts: false),
    ).map((x) => x.kind).toSet();
    expect(kinds, {ReminderKind.dose, ReminderKind.lastDay});
  });

  test('no follow-up once the dose would already count as missed', () async {
    final f = await Family.start(
      missedAfterMinutes: 30,
      treatments: [course('t1')],
    );
    final r = plan(await f.child(), DateTime.utc(2026, 1, 12, 10));
    expect(r.where((x) => x.kind == ReminderKind.followUp), isEmpty);
    expect(
      r.firstWhere((x) => x.kind == ReminderKind.missed).at,
      DateTime.utc(2026, 1, 12, 20, 30),
    );
  });

  test('names can be kept out of the notification; the payload never has '
      'them', () async {
    final f = await Family.start(treatments: [course('t1')]);
    final c = await f.child();
    final now = DateTime.utc(2026, 1, 12, 10);
    final named = plan(c, now).first;
    expect(named.title, 'dose Noa Amoxicillin');
    final hidden = plan(c, now, const ReminderPrefs(showNames: false));
    for (final r in hidden) {
      expect(r.title, 'Medicine reminder');
      expect(r.body, 'Open the app');
    }
    for (final r in [...plan(c, now), ...hidden]) {
      expect(r.payload, isNot(contains('Noa')));
      expect(r.payload, isNot(contains('Amoxicillin')));
    }
  });

  test('a reminder finds its dose back from the payload', () async {
    final f = await Family.start(treatments: [course('t1')]);
    final c = await f.child();
    final r = plan(c, DateTime.utc(2026, 1, 12, 10)).first;
    final target = ReminderTarget.parse(r.payload)!;
    expect(target.spaceId, c.spaceId);
    expect(target.markGiven, isFalse);
    expect(target.withMarkGiven().markGiven, isTrue);
    final dose = ReminderPlan.doseFor(c, target)!;
    expect(dose.at, r.at);
    expect(dose.treatment.id, 't1');
    // Ids are stable between runs, so syncing again changes nothing.
    expect(
      plan(c, DateTime.utc(2026, 1, 12, 10)).first.notificationId,
      r.notificationId,
    );
    expect(ReminderTarget.parse('nonsense'), isNull);
    expect(
      ReminderPlan.doseFor(
        c,
        ReminderTarget(
          spaceId: c.spaceId,
          treatmentId: 't1',
          date: LocalDate.parse('2026-03-01'),
          time: const TimeOfDose(8, 0),
        ),
      ),
      isNull,
    );
  });

  test('settings survive saving and loading', () {
    const prefs = ReminderPrefs(
      enabled: false,
      followUpMinutes: 15,
      missedAlerts: false,
      lastDayNotice: false,
      showNames: false,
      mutedChildren: {'b', 'a'},
    );
    final back = ReminderPrefs.fromJson(prefs.toJson());
    expect(back.enabled, isFalse);
    expect(back.followUpMinutes, 15);
    expect(back.missedAlerts, isFalse);
    expect(back.lastDayNotice, isFalse);
    expect(back.showNames, isFalse);
    expect(back.mutedChildren, {'a', 'b'});
    final defaults = ReminderPrefs.fromJson(null);
    expect(defaults.enabled, isTrue);
    expect(defaults.followUpMinutes, 30);
  });

  test('never more than the OS allows', () async {
    final f = await Family.start(
      treatments: [
        course(
          't1',
          times: [for (var h = 0; h < 24; h++) TimeOfDose(h, 0)],
          days: null,
        ),
      ],
    );
    final r = plan(await f.child(), DateTime.utc(2026, 1, 12, 10));
    expect(r.length, ReminderPlan.max);
    expect(r.first.at, DateTime.utc(2026, 1, 12, 10, 30));
  });
}
