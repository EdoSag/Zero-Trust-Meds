import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/family_circle.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/ui/family_circle_tile.dart';

import 'support/phone.dart';

const amox = Medication(
  id: 'med-1',
  name: 'Amoxicillin',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

/// Savta, shown in circle [circle] (or nowhere), with a twice-daily course,
/// this morning's dose given and a one-time dose of paracetamol.
Future<ChildData> savta({String? circle}) async {
  final phone = await Phone(InMemorySpaceServer(), mum, 1).start();
  final space = await phone.spaces.create(myName: 'Mum');
  await space.save(
    Child.itemId,
    Child(
      name: 'Savta',
      timeZone: 'UTC',
      role: PersonRole.parent,
      familyCircle: circle,
    ).toJson(),
  );
  await space.save(
    't1',
    Treatment(
      id: 't1',
      medication: amox,
      schedule: const FixedTimes([TimeOfDose(8, 0), TimeOfDose(20, 0)]),
      startDate: LocalDate.parse('2026-01-01'),
    ).toJson(),
  );
  for (final l in [
    DoseLog(
      id: 'dose/a',
      treatmentId: 't1',
      action: DoseAction.given,
      at: DateTime.utc(2026, 1, 10, 8, 5),
      byUserId: mum,
      slotDate: LocalDate.parse('2026-01-10'),
      slotTime: const TimeOfDose(8, 0),
    ),
    DoseLog(
      id: 'dose/b',
      treatmentId: '',
      action: DoseAction.given,
      at: DateTime.utc(2026, 1, 10, 11),
      byUserId: mum,
      medication: const Medication(
        id: 'm2',
        name: 'Paracetamol',
        form: MedForm.tablet,
        amount: 1,
        unit: 'tablet',
      ),
    ),
  ]) {
    await space.save(l.id, l.toJson());
  }
  return (await phone.child(space.id))!;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  final now = DateTime.utc(2026, 1, 10, 12);

  test('the person\'s circle survives a save, and is left out when unset', () {
    final c = const Child(name: 'A', timeZone: 'UTC', familyCircle: 'circle-1');
    expect(Child.fromJson(c.toJson()).familyCircle, 'circle-1');
    expect(c.copyWith(clearFamilyCircle: true).familyCircle, isNull);
    expect(
      const Child(
        name: 'A',
        timeZone: 'UTC',
      ).toJson().containsKey('familyCircle'),
      isFalse,
    );
  });

  test('nothing goes to a circle until one is chosen', () async {
    expect(FamilyCircleDoses.itemsFor(await savta(), now), isEmpty);
  });

  test('today\'s and tomorrow\'s doses and today\'s one-time doses, in the '
      'format the family hub reads', () async {
    final c = await savta(circle: 'circle-1');
    final items = FamilyCircleDoses.itemsFor(c, now);
    expect(items, hasLength(5));
    for (final id in items.keys) {
      expect(ZtFamilySpace.appOf(id), 'meds');
      expect(id, startsWith('meds/dose/${c.spaceId}.'));
      expect(FamilyCircleDoses.spaceOf(id), c.spaceId);
      expect(items[id]!['kind'], 'meds.dose');
    }
    final summaries = [for (final j in items.values) ZtFamilySummary.of(j)!]
      ..sort((a, b) => a.at!.compareTo(b.at!));
    expect(summaries.map((s) => (s.title, s.at, s.done)), [
      ('Savta: Amoxicillin 5 ml', DateTime.utc(2026, 1, 10, 8), true),
      ('Savta: Paracetamol 1 tablet', DateTime.utc(2026, 1, 10, 11), true),
      ('Savta: Amoxicillin 5 ml', DateTime.utc(2026, 1, 10, 20), false),
      ('Savta: Amoxicillin 5 ml', DateTime.utc(2026, 1, 11, 8), false),
      ('Savta: Amoxicillin 5 ml', DateTime.utc(2026, 1, 11, 20), false),
    ]);
    expect(summaries.every((s) => s.kind == 'meds.dose'), isTrue);
  });

  test('only changes are written; stale doses of my people go, other '
      'people\'s and Family\'s own items stay', () async {
    final c = await savta(circle: 'circle-1');
    final want = FamilyCircleDoses.itemsFor(c, now);
    final same = want.entries.first;
    final changed = want.entries.elementAt(1);
    LocalItem item(String id, Map<String, Object?>? json) =>
        LocalItem(itemId: id, updatedAt: now, json: json);
    final yesterday = FamilyCircleDoses.idFor(c.spaceId, 't1.2026-01-09.0800');
    final someoneElse = FamilyCircleDoses.idFor('other-space', 'x.0800');
    final r = FamilyCircleDoses.diff(
      existing: [
        item(same.key, same.value),
        item(changed.key, {
          ...changed.value,
          'zt': {'t': 'old', 'kind': 'meds.dose'},
        }),
        item(yesterday, {'kind': 'meds.dose'}),
        item(someoneElse, {'kind': 'meds.dose'}),
        item('family.circle', {'kind': 'family.circle', 'name': 'Cohens'}),
        item('calendar/event/e1', {'kind': 'calendar.event'}),
      ],
      want: want,
      mine: {c.spaceId},
    );
    expect(r.save.keys, isNot(contains(same.key)));
    expect(r.save.keys, contains(changed.key));
    expect(r.save, hasLength(want.length - 1));
    expect(r.delete, {yesterday});

    // Turned off: every dose of hers goes.
    final off = FamilyCircleDoses.diff(
      existing: [for (final e in want.entries) item(e.key, e.value)],
      want: const {},
      mine: {c.spaceId},
    );
    expect(off.delete, want.keys.toSet());
  });

  test('a circle member who is not its admin can write the doses into the '
      'circle, and they read back for the hub', () async {
    final server = InMemorySpaceServer();
    Future<SharedSpaces> circlesOf(String user, int seed) async => SharedSpaces(
      app: ZtFamilySpace.app,
      myUserId: user,
      identity: await ZtIdentity.fromDek(dek(seed)),
      backend: server.backendFor(user),
      privateStore: InMemorySpacePrivateStore(),
      openStore: (_) async => InMemoryItemStore(),
      deleteStore: (_) async {},
      deviceId: 'phone-$user',
      policy: ZtFamilySpace.policy,
    );
    final mumCircles = await circlesOf(mum, 1);
    final dadCircles = await circlesOf(dad, 2);
    final circle = await mumCircles.create(myName: 'Mum');
    await circle.save('family.circle', {
      'kind': 'family.circle',
      'name': 'Cohens',
    });
    await mumCircles.sync(circle);
    final link = await mumCircles.invite(circle.id);
    await dadCircles.answer(
      SpaceInviteLink.parse(link.toString()),
      myName: 'Dad',
    );
    await mumCircles.confirm((await mumCircles.pendingJoins(circle.id)).single);

    final c = await savta(circle: circle.id);
    final dads = await dadCircles.open(circle.id);
    await dadCircles.sync(dads);
    final changes = FamilyCircleDoses.diff(
      existing: await dads.store.all(),
      want: FamilyCircleDoses.itemsFor(c, now),
      mine: {c.spaceId},
    );
    for (final e in changes.save.entries) {
      await dads.save(e.key, e.value);
    }
    await dadCircles.sync(dads);

    await mumCircles.sync(circle);
    final doses = [
      for (final i in await circle.store.all())
        if (ZtFamilySpace.appOf(i.itemId) == 'meds')
          ZtFamilySummary.of(i.json)!,
    ];
    expect(doses, hasLength(5));
    expect(doses.where((d) => d.done == true), hasLength(2));
  });

  testWidgets('the switch names the circle, and is off with a hint when the '
      'account is in no circle', (tester) async {
    late ChildData shown, notShown;
    await tester.runAsync(() async {
      shown = await savta(circle: 'circle-1');
      notShown = await savta();
    });
    Future<void> pump(ChildData c, List<FamilyCircle> circles) =>
        tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              familyCirclesProvider.overrideWith((ref) async => circles),
            ],
            child: MaterialApp(
              localizationsDelegates: const [
                AppL10n.delegate,
                ZtL10n.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppL10n.supportedLocales,
              home: Scaffold(body: FamilyCircleTile(c)),
            ),
          ),
        );
    await pump(shown, [(id: 'circle-1', name: 'Cohens')]);
    await tester.pumpAndSettle();
    expect(find.text('Show in ZT Family'), findsOneWidget);
    expect(find.textContaining('family hub of Cohens'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await pump(notShown, const []);
    await tester.pumpAndSettle();
    expect(
      find.text('Create or join a circle in ZT Family first'),
      findsOneWidget,
    );
    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
    expect(tile.onChanged, isNull);
  });
}
