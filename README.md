# Zero-Trust Meds

Track the medicines you, your children or your elderly parents take, shared between every caregiver, end-to-end encrypted. Part of the [Zero-Trust](https://zerotrust.bz) suite. On the phone it is called **ZT Meds**.

> ZT Meds helps you remember and record medicines. It does not give medical advice, check doses or check for interactions. Always follow your doctor, your pharmacist and the label.

## What it does

- **People and caregivers.** Each person has a profile (who it is for: me, my child, my parent or someone else; name, birth date, colour, time zone for dose times). Profiles saved before this have no `relation` and are children. Whoever adds a profile invites the other caregivers with a link or a QR code. Admins manage medicines, treatments and caregivers; caregivers see everything and log doses.
- **Medicines and treatments.** One family list of medicines, reused across children. A treatment is a medicine for one child at set times each day (morning, noon, evening, night by default) for a number of days, or "as needed" with a minimum gap between doses and a most per 24 hours. Treatments can be edited, paused, ended early, and move to history after their last day.
- **Medicine names.** Typing a medicine's name suggests the family's own medicines first (picking one fills in its dose) and then about 95 common medicines, each under its generic name and the brand names sold in Israel, in English and Hebrew ("nuro" finds Nurofen, "אקמ" finds אקמול). The list is part of the app (`lib/logic/medicine_names.dart`), works offline and holds names only. The Ministry of Health drug registry is not bundled: its terms of reuse are unclear, so it waits until they are checked.
- **Supply and refills.** Any caregiver can count how much of a medicine is left ("Supply left" on a treatment). Doses given afterwards, one-time doses of the same medicine included, come off by themselves. The treatment shows about how much is left and when it runs out (from the planned doses a day, or the last two weeks' average for as-needed medicines), and "Order more" with a warning icon from a chosen number of days before (7 by default). An "Order more" notification comes at 09:00 that morning, and each morning after until someone counts again; it can be turned off in Reminders. Counts are their own encrypted items (`stock/<uuid>`), with the medicine name inside; the newest count of a medicine wins.
- **Today.** Each child's doses for today, grouped by time of day, each marked Given, Due, Missed, Upcoming, Skipped or Paused, always with an icon and a label as well as a colour.
- **Logging.** One tap logs a dose with who gave it and when. The time can be changed, a dose can be skipped with a reason, and a record can be undone. The app warns before a second dose of the same planned dose, and before an as-needed dose inside its minimum gap or above its daily most. A dose not logged within the child's window (2 hours by default) becomes Missed.
- **One-time doses.** "Log a one-time dose" (on each child's card and in the child's Today section) records a medicine given once, like a fever reducer, with no treatment or schedule: who it was given to, medicine and amount, when (now by default) and an optional reason. Any caregiver can log one. It shows in today's list, recent records, charts and the timeline, and the form warns when the same medicine was given in the last 24 hours.

- **Reminders.** A notification at each planned dose time with a "Mark as given" button, a follow-up if the dose still isn't logged (30 minutes by default, or off), an alert when it turns missed, and a notice on the morning of a course's last day. Each caregiver chooses their own reminders, which children they get them for and quiet hours (dose reminders come without sound then, the extras not at all), and can keep names out of the notification text. The lock screen never shows the text.

- **Charts.** Per medicine, a calendar with days as rows and dose times as columns; tap a dose to see who gave it and when. Per child, one timeline of every medicine with the share of planned doses given for each, over 7, 30 or 90 days. With more than one child, the home screen starts with a card per child: today's doses by status and the last 7 days. Every status has an icon and a label, never colour alone.

## How the sharing stays private

Built on the shared [Zero-Trust Core](https://github.com/EdoSag/Zero-Trust-Core) "shared spaces" (Z24):

- Each child is its own space with its own random key. Everything about the child is encrypted on the phone before it is sent; the server only stores ciphertext and who belongs to which space (row-level security).
- An invite carries a one-time secret and the inviter's key fingerprint in the part of the link that never reaches a server. Both phones then show the same 8-digit code; the admin lets the person in only when the codes match. The child's key is then wrapped to the new caregiver's public key.
- Removing a caregiver replaces the child's key, so nothing written afterwards can be read with the old one, and their phone deletes its copy.
- The server enforces that only admins write children, medicines and treatments; every phone checks it again.
- Each dose record is its own item, so two caregivers who give the same dose offline both show up ("given twice") instead of one silently replacing the other.
- No ads, no analytics, no push service: reminders are scheduled on the phone itself and work without internet. A notification carries only ids besides its text; "Mark as given" opens the app, which must be unlocked before anything is logged. A dose logged on another phone cancels this phone's follow-up and missed alert when this phone syncs, which happens while the app is open (the keys never sit in the background).

## Time zones

Dose times are wall-clock times in the child's time zone (08:00 means 08:00 at home), stored with the zone's IANA name. Records are stored in UTC, and every phone shows times in its own local time. Daylight saving changes are handled: a time that doesn't exist when the clocks go forward moves to just after the jump, and a time that happens twice when they go back counts once.

## Development

```sh
flutter pub get
flutter analyze
flutter test
```

Strings live in `lib/l10n/app_en.arb` (English only for now; Hebrew comes with the suite-wide translation work). Launcher icons are drawn from the suite's brand mark: `flutter test tool/launcher_icon_test.dart`.

Pushes to `main` build a signed APK and publish it as a GitHub Release (see `.github/workflows/android-apk.yml`); it needs the `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD` secrets. Pull requests target `Dev`.

## License

AGPL-3.0. See [LICENSE](LICENSE).
