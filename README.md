# Zero-Trust Meds

Track the medicines your children get, shared between every caregiver, end-to-end encrypted. Part of the [Zero-Trust](https://zerotrust.bz) suite. On the phone it is called **ZT Meds**.

> ZT Meds helps you remember and record medicines. It does not give medical advice, check doses or check for interactions. Always follow your doctor, your pharmacist and the label.

## What it does

- **Children and caregivers.** Each child has a profile (name, birth date, colour, time zone for dose times). The parent who adds a child invites the other caregivers with a link or a QR code. Admins manage medicines, treatments and caregivers; caregivers see everything and log doses.
- **Medicines and treatments.** One family list of medicines, reused across children. A treatment is a medicine for one child at set times each day (morning, noon, evening, night by default) for a number of days, or "as needed" with a minimum gap between doses and a most per 24 hours. Treatments can be edited, paused, ended early, and move to history after their last day.
- **Today.** Each child's doses for today, grouped by time of day, each marked Given, Due, Missed, Upcoming, Skipped or Paused, always with an icon and a label as well as a colour.
- **Logging.** One tap logs a dose with who gave it and when. The time can be changed, a dose can be skipped with a reason, and a record can be undone. The app warns before a second dose of the same planned dose, and before an as-needed dose inside its minimum gap or above its daily most. A dose not logged within the child's window (2 hours by default) becomes Missed.

Reminders and charts come in the next versions.

## How the sharing stays private

Built on the shared [Zero-Trust Core](https://github.com/EdoSag/Zero-Trust-Core) "shared spaces" (Z24):

- Each child is its own space with its own random key. Everything about the child is encrypted on the phone before it is sent; the server only stores ciphertext and who belongs to which space (row-level security).
- An invite carries a one-time secret and the inviter's key fingerprint in the part of the link that never reaches a server. Both phones then show the same 8-digit code; the admin lets the person in only when the codes match. The child's key is then wrapped to the new caregiver's public key.
- Removing a caregiver replaces the child's key, so nothing written afterwards can be read with the old one, and their phone deletes its copy.
- The server enforces that only admins write children, medicines and treatments; every phone checks it again.
- Each dose record is its own item, so two caregivers who give the same dose offline both show up ("given twice") instead of one silently replacing the other.
- No ads, no analytics, no push service: reminders will be scheduled on the phone itself.

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
