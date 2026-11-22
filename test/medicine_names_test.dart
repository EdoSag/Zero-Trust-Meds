import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/logic/medicine_names.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/ui/medicine_name_field.dart';

const ours = Medication(
  id: 'm1',
  name: 'Acamol syrup',
  form: MedForm.liquid,
  amount: 5,
  unit: 'ml',
);

void main() {
  group('suggestions', () {
    test('the family\'s own medicines come first, then common names', () {
      final s = MedicineNames.suggest('aca', [ours]);
      expect(s.first.saved, ours);
      expect(s.map((x) => x.name), contains('Acamol'));
      final acamol = s.firstWhere((x) => x.name == 'Acamol');
      expect(acamol.also, contains('Paracetamol'));
    });

    test('Hebrew names, words inside a name, any case', () {
      expect(MedicineNames.suggest('אקמ', const []).map((x) => x.name), [
        'אקמול',
      ]);
      expect(MedicineNames.suggest('CLAV', const []).map((x) => x.name), [
        'Amoxicillin and clavulanic acid',
      ]);
      expect(
        MedicineNames.suggest('nuro', const []).single.also,
        contains('Ibuprofen'),
      );
    });

    test('quiet for one letter, and once the name is complete', () {
      expect(MedicineNames.suggest('a', const []), isEmpty);
      expect(MedicineNames.suggest('Ritalin', const []), isEmpty);
      expect(
        MedicineNames.suggest('ab', const []).length,
        lessThanOrEqualTo(8),
      );
    });

    test('every built-in medicine has a name in English and in Hebrew', () {
      final hebrew = RegExp(r'[֐-׿]');
      for (final names in builtInMedicines) {
        expect(names.any(hebrew.hasMatch), isTrue, reason: names.first);
        expect(names.first.contains(hebrew), isFalse, reason: names.first);
      }
    });
  });

  testWidgets('typing shows suggestions under the field; picking the family\'s '
      'own fills its dose, a common name just the name', (tester) async {
    final name = TextEditingController();
    Medication? picked;
    var changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppL10n.delegate,
          ZtL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MedicineNameField(
              controller: name,
              family: const [ours],
              onChanged: () => changed++,
              onSaved: (m) => picked = m,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'aca');
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(TextFormField));
    final first = tester.getRect(find.text('Acamol syrup'));
    final common = tester.getRect(find.text('Acamol'));
    expect(first.top, greaterThanOrEqualTo(field.bottom));
    expect(common.top, greaterThan(first.top));
    expect(find.text('From your list · 5 ml'), findsOneWidget);

    await tester.tap(find.text('Acamol syrup'));
    await tester.pumpAndSettle();
    expect(picked, ours);
    expect(name.text, 'Acamol syrup');

    await tester.enterText(find.byType(TextFormField), 'nuro');
    await tester.pumpAndSettle();
    changed = 0;
    await tester.tap(find.text('Nurofen'));
    await tester.pumpAndSettle();
    expect(name.text, 'Nurofen');
    expect(changed, 1);
    expect(find.text('Nurofen'), findsOneWidget); // the list closed
  });
}
