import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/model/models.dart';
import 'package:zerotrust_meds/ui/child_editor.dart';

import 'support/phone.dart';

Widget _app(Widget home) => ProviderScope(
  overrides: [
    meProvider.overrideWith((ref) async => const MeProfile(name: 'Dana')),
  ],
  child: MaterialApp(
    localizationsDelegates: const [
      AppL10n.delegate,
      ZtL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  ),
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('who a profile is for', () {
    test('profiles saved before people were added are children', () {
      final old = Child.fromJson({
        'kind': 'child',
        'name': 'Noa',
        'timeZone': 'Asia/Jerusalem',
      });
      expect(old.role, PersonRole.child);
      // A child is written exactly as before, so older versions see no change.
      expect(old.toJson().containsKey('relation'), isFalse);
    });

    test('a parent stays a parent, and newer fields survive a save', () {
      final grandma = Child.fromJson({
        'kind': 'child',
        'name': 'Grandma',
        'timeZone': 'UTC',
        'relation': 'parent',
        'fromANewerVersion': {'a': 1},
      });
      expect(grandma.role, PersonRole.parent);
      final saved = grandma.copyWith(name: 'Savta').toJson();
      expect(saved['relation'], 'parent');
      expect(saved['name'], 'Savta');
      expect(saved['fromANewerVersion'], {'a': 1});
      expect(Child.fromJson(saved).role, PersonRole.parent);
    });

    test('an unknown relation reads as a child', () {
      expect(PersonRole.parse('cousin'), PersonRole.child);
      expect(PersonRole.parse(null), PersonRole.child);
    });
  });

  testWidgets('a new profile asks who it is for, above the name', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ChildEditorPage()));
    await tester.pumpAndSettle();

    expect(find.text('Add a person'), findsOneWidget);
    for (final label in ['Me', 'My child', 'My parent', 'Someone else']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    final question = tester.getTopLeft(find.text('Who is this?'));
    final name = tester.getTopLeft(find.widgetWithText(TextFormField, 'Name'));
    expect(question.dy, lessThan(name.dy));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'My child'))
          .selected,
      isTrue,
    );

    // "Me" fills in your own name.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Me'));
    await tester.pump();
    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Name'),
    );
    expect(field.controller!.text, 'Dana');
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Me')).selected,
      isTrue,
    );
  });

  testWidgets('editing a parent shows "My parent" chosen', (tester) async {
    late ChildData c;
    await tester.runAsync(() async {
      final phone = await Phone(InMemorySpaceServer(), mum, 1).start();
      final space = await phone.spaces.create(myName: 'Dana');
      await space.save(
        Child.itemId,
        const Child(
          name: 'Grandpa',
          timeZone: 'UTC',
          role: PersonRole.parent,
        ).toJson(),
      );
      c = (await phone.child(space.id))!;
    });
    expect(c.child.role, PersonRole.parent);
    await tester.pumpWidget(_app(ChildEditorPage(existing: c)));
    await tester.pumpAndSettle();
    expect(find.text('Edit details'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'My parent'))
          .selected,
      isTrue,
    );
  });
}
