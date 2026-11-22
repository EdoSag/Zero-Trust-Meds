import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/ui/medical_id_page.dart';

import 'support/phone.dart';

const savtaId = MedicalId(
  bloodType: 'A+',
  allergies: ['Penicillin', 'Peanuts'],
  conditions: ['Type 2 diabetes'],
  notes: 'Has a pacemaker',
  contacts: [EmergencyContact(name: 'Dana', phone: '050-1234567')],
);

const metformin = Medication(
  id: 'm1',
  name: 'Metformin',
  form: MedForm.tablet,
  amount: 1,
  unit: 'tablet',
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('round trip; newer fields kept; empty when nothing is filled in', () {
    final json = {...savtaId.toJson(), 'organDonor': true};
    final back = MedicalId.fromJson(json);
    expect(back.allergies, ['Penicillin', 'Peanuts']);
    expect(back.contacts.single.phone, '050-1234567');
    expect(back.toJson()['organDonor'], isTrue);
    expect(const MedicalId().isEmpty, isTrue);
    expect(back.isEmpty, isFalse);
  });

  group('who may write it', () {
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
      await space.save(MedicalId.itemId, savtaId.toJson());
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

    test('a caregiver sees it but cannot change it', () async {
      final seen = (await dadPhone.child(spaceId))!;
      expect(seen.medicalId.allergies, ['Penicillin', 'Peanuts']);

      final ds = await dadPhone.spaces.open(spaceId);
      await ds.save(MedicalId.itemId, const MedicalId().toJson());
      await expectLater(dadPhone.spaces.sync(ds), throwsA(isA<SpaceRefused>()));
      // Even if a server let it through, Mum's phone refuses it.
      server.enforceAdminOnly = false;
      await dadPhone.spaces.sync(ds);
      final c = (await mumPhone.child(spaceId))!;
      expect(c.medicalId.allergies, ['Penicillin', 'Peanuts']);
    });
  });

  testWidgets('the card shows allergies first, then conditions, current '
      'medicines, blood type and who to call; shared as text', (tester) async {
    late ChildData c;
    await tester.runAsync(() async {
      final phone = await Phone(InMemorySpaceServer(), mum, 1).start();
      final space = await phone.spaces.create(myName: 'Mum');
      await space.save(
        Child.itemId,
        const Child(
          name: 'Savta',
          timeZone: 'UTC',
          role: PersonRole.parent,
        ).toJson(),
      );
      await space.save(MedicalId.itemId, savtaId.toJson());
      await space.save(
        't1',
        Treatment(
          id: 't1',
          medication: metformin,
          schedule: const FixedTimes([TimeOfDose(8, 0)]),
          startDate: LocalDate.parse('2026-01-01'),
        ).toJson(),
      );
      c = (await phone.child(space.id))!;
    });
    final now = DateTime.utc(2026, 1, 10, 12);
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late BuildContext ctx;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          home: Builder(
            builder: (context) {
              ctx = context;
              return MedicalIdPage(spaceId: c.spaceId, now: now);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(y('Allergies'), lessThan(y('Penicillin')));
    expect(y('Penicillin'), lessThan(y('Conditions')));
    expect(y('Type 2 diabetes'), lessThan(y('Current medicines')));
    expect(find.textContaining('Metformin'), findsOneWidget);
    expect(y('Current medicines'), lessThan(y('Blood type')));
    expect(find.text('A+'), findsOneWidget);
    expect(find.text('Has a pacemaker'), findsOneWidget);
    expect(find.byTooltip('Call Dana'), findsOneWidget);
    // Mum is the admin: she can edit.
    expect(find.byTooltip('Edit Medical ID'), findsOneWidget);

    final text = medicalIdText(ctx, c, now);
    expect(text, startsWith('Medical ID: Savta'));
    expect(text, contains('Allergies: Penicillin, Peanuts'));
    expect(text, contains('Blood type: A+'));
    expect(text, contains('Dana 050-1234567'));
  });

  testWidgets('the editor starts from what is saved, one item per line', (
    tester,
  ) async {
    late ChildData c;
    await tester.runAsync(() async {
      final phone = await Phone(InMemorySpaceServer(), mum, 1).start();
      final space = await phone.spaces.create(myName: 'Mum');
      await space.save(
        Child.itemId,
        const Child(name: 'Savta', timeZone: 'UTC').toJson(),
      );
      await space.save(MedicalId.itemId, savtaId.toJson());
      c = (await phone.child(space.id))!;
    });
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppL10n.delegate,
            ZtL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: MedicalIdEditorPage(c: c),
        ),
      ),
    );
    await tester.pumpAndSettle();
    TextField field(String key) =>
        tester.widget<TextField>(find.byKey(Key(key)));
    expect(field('allergies').controller!.text, 'Penicillin\nPeanuts');
    expect(field('conditions').controller!.text, 'Type 2 diabetes');
    expect(find.text('050-1234567'), findsOneWidget);
    await tester.tap(find.text('Add a contact'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Phone'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
