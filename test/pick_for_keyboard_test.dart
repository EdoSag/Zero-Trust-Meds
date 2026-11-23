import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/ui/pick_for_keyboard_page.dart';

import 'support/phone.dart';

const amox = Medication(
  id: 'med-1',
  name: 'Amoxicillin',
  amount: 5,
  unit: 'ml',
  notes: 'Shake well',
);
const fever = Medication(
  id: 'med-2',
  name: 'Paracetamol',
  amount: 7.5,
  unit: 'ml',
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('offers running medicines, then what to type of one', (
    tester,
  ) async {
    final noa = await _noa(tester);
    String? picked = 'unset';
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyProvider.overrideWith(
            (ref) async =>
                FamilyData(children: [noa], ready: true, loading: false),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppL10n.delegate,
            ...ZtLanguages.delegates,
          ],
          supportedLocales: ZtLanguages.supported,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: true),
              child: Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picked = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(alwaysUse24HourFormat: true),
                          child: PickForKeyboardPage(
                            now: DateTime.utc(2026, 1, 12, 16),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Insert into ZT Keyboard'), findsOneWidget);
    expect(find.text('Noa'), findsOneWidget);
    // Not started yet: not offered.
    expect(find.textContaining('Ibuprofen'), findsNothing);
    final name = tester.getTopLeft(find.text('Noa')).dy;
    final list = tester.getTopLeft(find.text('All running medicines')).dy;
    final med = tester.getTopLeft(find.text('Amoxicillin 5 ml')).dy;
    expect(name, lessThan(list));
    expect(list, lessThan(med));

    await tester.tap(find.text('Amoxicillin 5 ml'));
    await tester.pumpAndSettle();
    expect(find.text('Amoxicillin: 08:00, 13:00, 20:00'), findsNothing);
    expect(find.text('Amoxicillin 5 ml: 08:00, 13:00, 20:00'), findsOneWidget);
    expect(find.textContaining('Amoxicillin 5 ml, last given'), findsOneWidget);
    expect(find.text('Shake well'), findsOneWidget);
    await tester.tap(find.text('Amoxicillin 5 ml: 08:00, 13:00, 20:00'));
    await tester.pumpAndSettle();
    expect(picked, 'Amoxicillin 5 ml: 08:00, 13:00, 20:00');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All running medicines'));
    await tester.pumpAndSettle();
    expect(
      picked,
      startsWith('Amoxicillin 5 ml: 08:00, 13:00, 20:00\nParacetamol 7.5 ml: '),
    );
  });

  testWidgets('a later one-time dose of the medicine counts as last given', (
    tester,
  ) async {
    final extra = DoseLog(
      id: 'dose/2',
      treatmentId: '',
      action: DoseAction.given,
      at: DateTime.utc(2026, 1, 12, 15),
      byUserId: mum,
      medication: const Medication(
        id: 'x',
        name: 'amoxicillin',
        amount: 10,
        unit: 'ml',
      ),
    );
    final noa = await _noa(tester, more: [extra]);
    final t = noa.treatments.firstWhere((t) => t.id == 't1');
    expect(lastGiven(noa, t)!.id, 'dose/2');
    // Only the treatment's own: the 13:05 dose.
    final without = await _noa(tester);
    expect(lastGiven(without, t)!.id, 'dose/1');
  });
}

Future<ChildData> _noa(
  WidgetTester tester, {
  List<DoseLog> more = const [],
}) async {
  late ChildData noa;
  await tester.runAsync(() async {
    final server = InMemorySpaceServer();
    final mumPhone = await Phone(server, mum, 1).start();
    final space = await mumPhone.spaces.create(myName: 'Mum');
    await space.save(
      Child.itemId,
      const Child(name: 'Noa', timeZone: 'UTC').toJson(),
    );
    await space.save(
      't1',
      Treatment(
        id: 't1',
        medication: amox,
        schedule: const FixedTimes([
          TimeOfDose(8, 0),
          TimeOfDose(13, 0),
          TimeOfDose(20, 0),
        ]),
        startDate: LocalDate.parse('2026-01-10'),
        days: 7,
      ).toJson(),
    );
    await space.save(
      'p1',
      Treatment(
        id: 'p1',
        medication: fever,
        schedule: const AsNeeded(minIntervalMinutes: 360, maxPer24h: 4),
        startDate: LocalDate.parse('2026-01-01'),
      ).toJson(),
    );
    await space.save(
      'p2',
      Treatment(
        id: 'p2',
        medication: const Medication(id: 'med-3', name: 'Ibuprofen'),
        schedule: const AsNeeded(minIntervalMinutes: 360),
        startDate: LocalDate.parse('2026-02-01'),
      ).toJson(),
    );
    await space.save(
      'dose/1',
      DoseLog(
        id: 'dose/1',
        treatmentId: 't1',
        action: DoseAction.given,
        at: DateTime.utc(2026, 1, 12, 13, 5),
        byUserId: mum,
        slotDate: LocalDate.parse('2026-01-12'),
        slotTime: const TimeOfDose(13, 0),
      ).toJson(),
    );
    for (final l in more) {
      await space.save(l.id, l.toJson());
    }
    await mumPhone.spaces.sync(space);
    noa = (await mumPhone.child(space.id))!;
  });
  return noa;
}
