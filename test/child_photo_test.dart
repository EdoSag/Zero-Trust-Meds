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

/// A 1x1 PNG.
const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  testWidgets('the child editor offers a photo, and removing it', (
    tester,
  ) async {
    late ChildData c;
    await tester.runAsync(() async {
      final phone = await Phone(InMemorySpaceServer(), mum, 1).start();
      final space = await phone.spaces.create(myName: 'Mum');
      await space.save(
        Child.itemId,
        const Child(name: 'Noa', timeZone: 'UTC', photo: pixel).toJson(),
      );
      c = (await phone.child(space.id))!;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meProvider.overrideWith((ref) async => const MeProfile(name: 'Mum')),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppL10n.delegate,
            ZtL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppL10n.supportedLocales,
          home: ChildEditorPage(existing: c),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CircleAvatar && w.backgroundImage != null,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is CircleAvatar && w.backgroundImage != null,
      ),
      findsNothing,
    );
  });
}
