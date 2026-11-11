import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_meds/data/meds_data.dart';
import 'package:zerotrust_meds/l10n/generated/app_localizations.dart';
import 'package:zerotrust_meds/logic/photo.dart';
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

  test('a picked photo keeps no metadata, is upright and small', () {
    // 600x300 photo taken sideways, with a GPS position and a camera name.
    final photo = img.Image(width: 600, height: 300);
    photo.exif.imageIfd['Orientation'] = img.IfdValueShort(6);
    photo.exif.imageIfd['Make'] = img.IfdValueAscii('PhoneCam');
    photo.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(32, 1);
    photo.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(34, 1);
    final picked = img.encodeJpg(photo);
    expect(img.decodeJpgExif(picked)!.gpsIfd.isEmpty, isFalse);

    final clean = cleanPhoto(picked)!;
    final exif = img.decodeJpgExif(clean);
    expect(exif == null || exif.isEmpty, isTrue);
    final back = img.decodeJpg(clean)!;
    // Turned upright (orientation 6 is 90 degrees), then shrunk.
    expect(back.width, 128);
    expect(back.height, photoSize);

    expect(cleanPhoto(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
