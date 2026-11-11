import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/model/models.dart';
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

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets(
    'today shows each dose with an icon and a label, not only colour',
    (tester) async {
      final noa = await _noa(tester);

      await _pumpToday(tester, noa);

      expect(find.text('Noa'), findsOneWidget);
      expect(find.text('1 of 3 doses given today'), findsOneWidget);
      for (final label in ['Morning', 'Noon', 'Night']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Missed'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Given'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.textContaining('Given by Mum'), findsOneWidget);
      expect(find.textContaining('Paracetamol'), findsOneWidget);
      expect(find.textContaining('Can be given now'), findsOneWidget);
      expect(find.textContaining('Ibuprofen'), findsNothing);

      // The status sits beside the medicine name, not on top of it.
      final name = tester.getRect(find.text('Amoxicillin · 5 ml').first);
      final missed = tester.getRect(find.text('Missed'));
      expect(missed.overlaps(name), isFalse);
      expect(missed.left, greaterThan(name.left));
    },
  );

  testWidgets('in Hebrew the screen is translated and laid out right to left', (
    tester,
  ) async {
    final noa = await _noa(tester);
    await _pumpToday(tester, noa, locale: const Locale('he'));

    expect(tester.takeException(), isNull);
    expect(find.text('ניתנו היום 1 מתוך 3 מנות'), findsOneWidget);
    for (final label in ['בוקר', 'צהריים', 'לילה']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('הוחמץ'), findsOneWidget);
    expect(find.text('ניתן'), findsOneWidget);
    expect(find.text('בקרוב'), findsOneWidget);
    expect(find.textContaining('אפשר לתת עכשיו'), findsOneWidget);
    expect(find.text('Missed'), findsNothing);

    // Mirrored: the status sits to the left of the medicine name.
    final name = tester.getRect(find.text('Amoxicillin · 5 ml').first);
    final missed = tester.getRect(find.text('הוחמץ'));
    expect(missed.overlaps(name), isFalse);
    expect(missed.right, lessThan(name.right));
  });
}

/// Noa, with an antibiotic three times a day (13:00 given) and two
/// as-needed medicines, one not started yet.
Future<ChildData> _noa(WidgetTester tester) async {
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
    // Starts next month: not offered today.
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
    await mumPhone.spaces.sync(space);
    noa = (await mumPhone.child(space.id))!;
  });
  return noa;
}

Future<void> _pumpToday(
  WidgetTester tester,
  ChildData noa, {
  Locale? locale,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 16:00 UTC: 08:00 missed (2 h window), 13:00 given, 20:00 upcoming.
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
