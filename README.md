# Zero-Trust Meds

Track the medicines you, your children or your elderly parents take, shared
between every caregiver, end-to-end encrypted. On the phone it is called
**ZT Meds**; in stores and on release pages, **Zero-Trust Meds**. Same
account, settings and look as the other Zero-Trust apps, built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core). Part of the
[Zero-Trust suite](https://zerotrust.bz).

> ZT Meds helps you remember and record medicines. It does not give medical advice, check doses or check for interactions. Always follow your doctor, your pharmacist and the label.

## What it does

- **People and caregivers.** Each person has a profile (who it is for: me, my child, my parent or someone else; name, birth date, colour, time zone for dose times). Profiles saved before this have no `relation` and are children. Whoever adds a profile invites the other caregivers with a link or a QR code. Admins manage medicines, treatments and caregivers; caregivers see everything and log doses.
- **Medicines and treatments.** One family list of medicines, reused across children. A treatment is a medicine for one child at set times each day (morning, noon, evening, night by default) for a number of days, or "as needed" with a minimum gap between doses and a most per 24 hours. Treatments can be edited, paused, ended early, and move to history after their last day.
- **ZT Family hub (S-10, L-2).** An admin can switch on "Show in ZT Family" for a person and pick one of the account's ZT Family circles. That circle's family hub then lists the person's doses for today: a read-only copy, one item per dose of today and tomorrow and per one-time dose given today (`meds/dose/<person space id>.<key>`, kind `meds.dose`, with Core's `ZtFamilySummary`: `at` the dose time, `done` given). Records stay in the person's own space. Every caregiver's phone that is in the circle keeps the copy up to date and removes past days; switching off removes the person's doses. Everyone in the circle sees the medicine names and times, so it is off until switched on.
- **Medical ID.** Each person has a Medical ID card (on their page): allergies first, then conditions, current medicines (taken from the running treatments, not typed twice), blood type, other important information (a pacemaker, where the EpiPen is) and emergency contacts with a call button. Every caregiver sees it and can share it as text; only admins edit it (`medical_id` is admin-only, like the profile). It is one encrypted item per space, and unknown fields from newer versions are kept. ZT Phone's lock-screen Medical ID (P-3) is to read it from here later.
- **Medicine names.** Typing a medicine's name suggests the family's own medicines first (picking one fills in its dose) and then about 95 common medicines, each under its generic name and the brand names sold in Israel, in English and Hebrew ("nuro" finds Nurofen, "אקמ" finds אקמול). The list is part of the app (`lib/logic/medicine_names.dart`), works offline and holds names only. The Ministry of Health drug registry is not bundled: its terms of reuse are unclear, so it waits until they are checked.
- **Supply and refills.** Any caregiver can count how much of a medicine is left ("Supply left" on a treatment). Doses given afterwards, one-time doses of the same medicine included, come off by themselves. The treatment shows about how much is left and when it runs out (from the planned doses a day, or the last two weeks' average for as-needed medicines), and "Order more" with a warning icon from a chosen number of days before (7 by default). An "Order more" notification comes at 09:00 that morning, and each morning after until someone counts again; it can be turned off in Reminders. Counts are their own encrypted items (`stock/<uuid>`), with the medicine name inside; the newest count of a medicine wins.
- **Today.** Each child's doses for today, grouped by time of day, each marked Given, Due, Missed, Upcoming, Skipped or Paused, always with an icon and a label as well as a colour.
- **Logging.** One tap logs a dose with who gave it and when. The time can be changed, a dose can be skipped with a reason, and a record can be undone. The app warns before a second dose of the same planned dose, and before an as-needed dose inside its minimum gap or above its daily most. A dose not logged within the child's window (2 hours by default) becomes Missed.
- **One-time doses.** "Log a one-time dose" (on each child's card and in the child's Today section) records a medicine given once, like a fever reducer, with no treatment or schedule: who it was given to, medicine and amount, when (now by default) and an optional reason. Any caregiver can log one. It shows in today's list, recent records, charts and the timeline, and the form warns when the same medicine was given in the last 24 hours.

- **Reminders.** A notification at each planned dose time with a "Mark as given" button, a follow-up if the dose still isn't logged (30 minutes by default, or off), an alert when it turns missed, and a notice on the morning of a course's last day. Each caregiver chooses their own reminders, which children they get them for and quiet hours (dose reminders come without sound then, the extras not at all), and can keep names out of the notification text. The lock screen never shows the text.

- **Charts.** Per medicine, a calendar with days as rows and dose times as columns; tap a dose to see who gave it and when. Per child, one timeline of every medicine with the share of planned doses given for each, over 7, 30 or 90 days. With more than one child, the home screen starts with a card per child: today's doses by status and the last 7 days. Every status has an icon and a label, never colour alone.

## Privacy

Like every Zero-Trust app, it is zero-knowledge: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

### How the sharing stays private

Built on the shared [Zero-Trust Core](https://github.com/EdoSag/Zero-Trust-Core) "shared spaces" (Z24):

- Each child is its own space with its own random key. Everything about the child is encrypted on the phone before it is sent; the server only stores ciphertext and who belongs to which space (row-level security).
- An invite carries a one-time secret and the inviter's key fingerprint in the part of the link that never reaches a server. Both phones then show the same 8-digit code; the admin lets the person in only when the codes match. The child's key is then wrapped to the new caregiver's public key.
- Removing a caregiver replaces the child's key, so nothing written afterwards can be read with the old one, and their phone deletes its copy.
- The server enforces that only admins write children, medicines and treatments; every phone checks it again.
- Each dose record is its own item, so two caregivers who give the same dose offline both show up ("given twice") instead of one silently replacing the other.
- No ads, no analytics, no push service: reminders are scheduled on the phone itself and work without internet. A notification carries only ids besides its text; "Mark as given" opens the app, which must be unlocked before anything is logged. A dose logged on another phone cancels this phone's follow-up and missed alert when this phone syncs, which happens while the app is open (the keys never sit in the background).

## One account, one core

One Zero-Trust account opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Meds/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#meds),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language. Medicine names are suggested in both.

## Time zones

Dose times are wall-clock times in the child's time zone (08:00 means 08:00 at home), stored with the zone's IANA name. Records are stored in UTC, and every phone shows times in its own local time. Daylight saving changes are handled: a time that doesn't exist when the clocks go forward moves to just after the jump, and a time that happens twice when they go back counts once.

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

First create a file named `.env` in the project folder. It is not committed
(CI writes its own) and it is bundled into the APK, so it holds public client
values only, never a service-role key:

```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>
```

Then:

```bash
flutter pub get
dart run zt_release_checks --app meds   # shared release checks
flutter analyze && flutter test
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

Strings live in `lib/l10n/app_en.arb` and `app_he.arb`. Launcher icons are drawn from the suite's brand mark:
`flutter test tool/launcher_icon_test.dart`.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Meds"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
