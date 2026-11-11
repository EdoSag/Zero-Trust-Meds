import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/logic/dose_logic.dart';
import 'package:zerotrust_meds/model/models.dart';

import 'support/phone.dart';

const amox = Medication(
  id: 'med-1',
  name: 'Amoxicillin',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

void main() {
  setUpAll(tzdata.initializeTimeZones);
  late InMemorySpaceServer server;
  late Phone a, b, c;

  setUp(() async {
    server = InMemorySpaceServer();
    a = await Phone(server, mum, 1).start();
    b = await Phone(server, dad, 2).start();
    c = await Phone(server, sitter, 3).start();
  });

  Future<void> invite(String spaceId, Phone who, {required String name}) async {
    final link = await a.spaces.invite(spaceId);
    final started = await who.spaces.answer(
      SpaceInviteLink.parse(link.toString()),
      myName: name,
    );
    final pending = await a.spaces.pendingJoins(spaceId);
    // Both phones show the same code before Mum lets them in.
    expect(pending.single.verificationCode, started.verificationCode);
    expect(pending.single.name, name);
    await a.spaces.confirm(pending.single);
  }

  /// Mum adds Noa with a twice-daily treatment and lets [who] in.
  Future<String> noaWith(Phone who, {String name = 'Dad'}) async {
    final space = await a.spaces.create(myName: 'Mum');
    await space.save(
      Child.itemId,
      const Child(name: 'Noa', timeZone: 'Asia/Jerusalem').toJson(),
    );
    await space.save(amox.id, amox.toJson());
    await space.save(
      't1',
      Treatment(
        id: 't1',
        medication: amox,
        schedule: const FixedTimes([TimeOfDose(8, 0), TimeOfDose(20, 0)]),
        startDate: LocalDate.parse('2026-01-10'),
        days: 7,
      ).toJson(),
    );
    await a.spaces.sync(space);
    await invite(space.id, who, name: name);
    return space.id;
  }

  test(
    'a caregiver sees the child, treatment and caregivers after joining',
    () async {
      final id = await noaWith(b);
      final noa = (await b.child(id))!;
      expect(noa.child.name, 'Noa');
      expect(noa.isAdmin, isFalse);
      expect(noa.treatments.single.medication.name, 'Amoxicillin');
      expect(
        noa.caregivers.map((m) => m.name),
        unorderedEquals(['Mum', 'Dad']),
      );
      expect(noa.nameOf(mum), 'Mum');
    },
  );

  test(
    'a dose logged by one caregiver shows as given, by whom, on the other',
    () async {
      final id = await noaWith(b);
      final bs = await b.spaces.open(id);
      final log = DoseLog(
        id: 'dose/1',
        treatmentId: 't1',
        action: DoseAction.given,
        at: DateTime.utc(2026, 1, 10, 6, 5),
        byUserId: dad,
        slotDate: LocalDate.parse('2026-01-10'),
        slotTime: const TimeOfDose(8, 0),
      );
      await bs.save(log.id, log.toJson());
      await b.spaces.sync(bs);

      final noa = (await a.child(id))!;
      final now = DateTime.utc(2026, 1, 10, 7);
      final today = noa.doses(LocalDate.parse('2026-01-10'), now);
      expect(today.first.state, DoseState.given);
      expect(noa.nameOf(today.first.logs.single.byUserId), 'Dad');
      expect(today.last.state, DoseState.upcoming);

      // Mum is about to give the same morning dose: warned.
      final w = DoseGuard.beforeGiving(
        t: noa.treatments.single,
        logs: noa.logs,
        at: now,
        slot: today.first.dose,
      );
      expect(w.single, isA<AlreadyGiven>());
    },
  );

  test(
    'two caregivers logging the same dose offline both count: given twice',
    () async {
      final id = await noaWith(b);
      final as = await a.spaces.open(id);
      final bs = await b.spaces.open(id);
      for (final (space, by, n) in [(as, mum, 1), (bs, dad, 2)]) {
        await space.save(
          'dose/$n',
          DoseLog(
            id: 'dose/$n',
            treatmentId: 't1',
            action: DoseAction.given,
            at: DateTime.utc(2026, 1, 10, 6, n),
            byUserId: by,
            slotDate: LocalDate.parse('2026-01-10'),
            slotTime: const TimeOfDose(8, 0),
          ).toJson(),
        );
      }
      await a.spaces.sync(as);
      await b.spaces.sync(bs);
      final noa = (await a.child(id))!;
      final s = noa
          .doses(LocalDate.parse('2026-01-10'), DateTime.utc(2026, 1, 10, 7))
          .first;
      expect(s.givenTwice, isTrue);
      expect(s.logs.map((l) => noa.nameOf(l.byUserId)), ['Mum', 'Dad']);
    },
  );

  test('caregivers log doses but cannot change treatments', () async {
    final id = await noaWith(b);
    final bs = await b.spaces.open(id);
    await bs.save(
      't1',
      Treatment(
        id: 't1',
        medication: amox,
        schedule: const FixedTimes([TimeOfDose(8, 0)]),
        startDate: LocalDate.parse('2026-01-10'),
        days: 1,
      ).toJson(),
    );
    await expectLater(b.spaces.sync(bs), throwsA(isA<SpaceRefused>()));
    // And even a server that let it through: the admin's phone refuses it.
    server.enforceAdminOnly = false;
    await b.spaces.sync(bs);
    final noa = (await a.child(id))!;
    expect(noa.treatments.single.days, 7);
  });

  test('removing a caregiver rotates the key and wipes their copy', () async {
    final id = await noaWith(b);
    await invite(id, c, name: 'Sitter');
    expect((await c.child(id))!.child.name, 'Noa');
    final as = await a.spaces.open(id);
    final epoch = as.keyEpoch;

    await a.spaces.remove(id, sitter);
    expect(as.keyEpoch, epoch + 1);
    await as.save(
      Child.itemId,
      const Child(
        name: 'Noa',
        timeZone: 'Asia/Jerusalem',
        color: 0xFF22C55E,
      ).toJson(),
    );
    await a.spaces.sync(as);

    // Dad moves to the new key and keeps reading.
    expect((await b.child(id))!.child.color, 0xFF22C55E);
    // The sitter's phone finds out and forgets the child.
    final cs = await c.spaces.open(id);
    await c.spaces.sync(cs);
    expect(cs.gone, isTrue);
    expect(c.stores, isNot(contains(id)));
  });

  test(
    'the family medicine list is one list across the children Mum manages',
    () async {
      final noa = await noaWith(b);
      final eli = await a.spaces.create(myName: 'Mum');
      await eli.save(
        Child.itemId,
        const Child(name: 'Eli', timeZone: 'Asia/Jerusalem').toJson(),
      );
      await eli.save(
        'med-2',
        const Medication(
          id: 'med-2',
          name: 'amoxicillin ',
          form: MedForm.liquid,
          amount: 5,
          unit: 'ml',
        ).toJson(),
      );
      await eli.save(
        'med-3',
        const Medication(id: 'med-3', name: 'Paracetamol', unit: 'ml').toJson(),
      );
      await a.spaces.sync(eli);
      final family = FamilyData(
        children: [(await a.child(noa))!, (await a.child(eli.id))!],
      );
      expect(family.medications.map((m) => m.name), [
        'Amoxicillin',
        'Paracetamol',
      ]);
      // Dad isn't an admin anywhere: his list is empty.
      expect(
        FamilyData(children: [(await b.child(noa))!]).medications,
        isEmpty,
      );
    },
  );

  test('deleting the child removes it for every caregiver', () async {
    final id = await noaWith(b);
    await a.spaces.deleteSpace(id);
    final bs = await b.spaces.open(id);
    await b.spaces.sync(bs);
    expect(bs.gone, isTrue);
    expect(await b.spaces.list(), isEmpty);
  });
}
