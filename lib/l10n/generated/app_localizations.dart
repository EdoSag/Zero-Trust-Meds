import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZT Meds'**
  String get appTitle;

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your children. Pull down to try again.'**
  String get loadError;

  /// No description provided for @addChildOrJoin.
  ///
  /// In en, this message translates to:
  /// **'Add or join'**
  String get addChildOrJoin;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Add a child'**
  String get addChild;

  /// No description provided for @addChildHint.
  ///
  /// In en, this message translates to:
  /// **'You manage their medicines and invite caregivers'**
  String get addChildHint;

  /// No description provided for @joinWithInvite.
  ///
  /// In en, this message translates to:
  /// **'Join with an invite'**
  String get joinWithInvite;

  /// No description provided for @joinWithInviteHint.
  ///
  /// In en, this message translates to:
  /// **'Scan or paste the invite another parent sent you'**
  String get joinWithInviteHint;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Track your children\'s medicines together'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a child, set up their treatments and invite everyone who gives them medicine. Everything is end-to-end encrypted.'**
  String get emptyBody;

  /// No description provided for @waitingForAdmin.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the admin to let you in'**
  String get waitingForAdmin;

  /// No description provided for @waitingForSync.
  ///
  /// In en, this message translates to:
  /// **'Confirmed. The child\'s details will appear in a moment.'**
  String get waitingForSync;

  /// No description provided for @waitingCode.
  ///
  /// In en, this message translates to:
  /// **'Your code: {code}. The admin checks it on their phone.'**
  String waitingCode(String code);

  /// No description provided for @joinRequest.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to help with {child}'**
  String joinRequest(String name, String child);

  /// No description provided for @joinRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to compare codes and let them in'**
  String get joinRequestHint;

  /// No description provided for @nothingToday.
  ///
  /// In en, this message translates to:
  /// **'No doses today'**
  String get nothingToday;

  /// No description provided for @givenOfToday.
  ///
  /// In en, this message translates to:
  /// **'{given} of {total} doses given today'**
  String givenOfToday(int given, int total);

  /// No description provided for @markGiven.
  ///
  /// In en, this message translates to:
  /// **'Mark as given'**
  String get markGiven;

  /// No description provided for @giveAgain.
  ///
  /// In en, this message translates to:
  /// **'Give again'**
  String get giveAgain;

  /// No description provided for @givenAtOtherTime.
  ///
  /// In en, this message translates to:
  /// **'Given at another time'**
  String get givenAtOtherTime;

  /// No description provided for @skipDose.
  ///
  /// In en, this message translates to:
  /// **'Skip this dose'**
  String get skipDose;

  /// No description provided for @asNeeded.
  ///
  /// In en, this message translates to:
  /// **'As needed'**
  String get asNeeded;

  /// No description provided for @lastGiven.
  ///
  /// In en, this message translates to:
  /// **'Last: {name}, {when}'**
  String lastGiven(String name, String when);

  /// No description provided for @nextAllowed.
  ///
  /// In en, this message translates to:
  /// **'Next allowed {when}'**
  String nextAllowed(String when);

  /// No description provided for @canGiveNow.
  ///
  /// In en, this message translates to:
  /// **'Can be given now'**
  String get canGiveNow;

  /// No description provided for @everyHours.
  ///
  /// In en, this message translates to:
  /// **'At least {hours} h apart'**
  String everyHours(String hours);

  /// No description provided for @maxPerDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{At most 1 a day} other{At most {count} a day}}'**
  String maxPerDay(int count);

  /// No description provided for @statusGiven.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get statusGiven;

  /// No description provided for @statusDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get statusDue;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusGivenTwice.
  ///
  /// In en, this message translates to:
  /// **'Given twice'**
  String get statusGivenTwice;

  /// No description provided for @slot.
  ///
  /// In en, this message translates to:
  /// **'{slot, select, morning{Morning} noon{Noon} evening{Evening} other{Night}}'**
  String slot(String slot);

  /// No description provided for @form.
  ///
  /// In en, this message translates to:
  /// **'{form, select, liquid{Liquid} tablet{Tablet} capsule{Capsule} drops{Drops} inhaler{Inhaler} cream{Cream} injection{Injection} other{Other}}'**
  String form(String form);

  /// No description provided for @formUnit.
  ///
  /// In en, this message translates to:
  /// **'{form, select, liquid{ml} tablet{tablet} capsule{capsule} drops{drops} inhaler{puffs} cream{application} injection{ml} other{dose}}'**
  String formUnit(String form);

  /// No description provided for @loggedGiven.
  ///
  /// In en, this message translates to:
  /// **'{medicine} logged as given to {child}'**
  String loggedGiven(String medicine, String child);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @warnTitle.
  ///
  /// In en, this message translates to:
  /// **'Give {medicine} again?'**
  String warnTitle(String medicine);

  /// No description provided for @warnAlreadyGiven.
  ///
  /// In en, this message translates to:
  /// **'{name} already gave this dose at {when}.'**
  String warnAlreadyGiven(String name, String when);

  /// No description provided for @warnTooSoon.
  ///
  /// In en, this message translates to:
  /// **'The last dose was at {last}. The next one is allowed from {next}.'**
  String warnTooSoon(String last, String next);

  /// No description provided for @warnMaxReached.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Already 1 dose in the last 24 hours, the most allowed.} other{Already {count} doses in the last 24 hours, the most allowed.}} The next one is allowed from {next}.'**
  String warnMaxReached(int count, String next);

  /// No description provided for @warnCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the label or ask a doctor or pharmacist if unsure.'**
  String get warnCheck;

  /// No description provided for @dontGive.
  ///
  /// In en, this message translates to:
  /// **'Don\'t give'**
  String get dontGive;

  /// No description provided for @giveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Give anyway'**
  String get giveAnyway;

  /// No description provided for @skipTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip this dose'**
  String get skipTitle;

  /// No description provided for @skipReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get skipReason;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @reasonAsleep.
  ///
  /// In en, this message translates to:
  /// **'Asleep'**
  String get reasonAsleep;

  /// No description provided for @reasonVomited.
  ///
  /// In en, this message translates to:
  /// **'Vomited'**
  String get reasonVomited;

  /// No description provided for @reasonRefused.
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get reasonRefused;

  /// No description provided for @reasonDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s advice'**
  String get reasonDoctor;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @plannedFor.
  ///
  /// In en, this message translates to:
  /// **'For {child}, {when}'**
  String plannedFor(String child, String when);

  /// No description provided for @givenBy.
  ///
  /// In en, this message translates to:
  /// **'Given by {name} at {when}'**
  String givenBy(String name, String when);

  /// No description provided for @skippedBy.
  ///
  /// In en, this message translates to:
  /// **'Skipped by {name} at {when}'**
  String skippedBy(String name, String when);

  /// No description provided for @changeTime.
  ///
  /// In en, this message translates to:
  /// **'Change the time'**
  String get changeTime;

  /// No description provided for @undoRecord.
  ///
  /// In en, this message translates to:
  /// **'Remove this record'**
  String get undoRecord;

  /// No description provided for @recordRemoved.
  ///
  /// In en, this message translates to:
  /// **'Record removed'**
  String get recordRemoved;

  /// No description provided for @childGone.
  ///
  /// In en, this message translates to:
  /// **'This child is no longer here.'**
  String get childGone;

  /// No description provided for @editChild.
  ///
  /// In en, this message translates to:
  /// **'Edit child'**
  String get editChild;

  /// No description provided for @exportChild.
  ///
  /// In en, this message translates to:
  /// **'Export records'**
  String get exportChild;

  /// No description provided for @leaveChild.
  ///
  /// In en, this message translates to:
  /// **'Stop being a caregiver'**
  String get leaveChild;

  /// No description provided for @deleteChild.
  ///
  /// In en, this message translates to:
  /// **'Delete child'**
  String get deleteChild;

  /// No description provided for @addTreatment.
  ///
  /// In en, this message translates to:
  /// **'Add treatment'**
  String get addTreatment;

  /// No description provided for @bornOn.
  ///
  /// In en, this message translates to:
  /// **'Born {date}'**
  String bornOn(String date);

  /// No description provided for @timesIn.
  ///
  /// In en, this message translates to:
  /// **'Dose times in {zone}'**
  String timesIn(String zone);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @treatments.
  ///
  /// In en, this message translates to:
  /// **'Treatments'**
  String get treatments;

  /// No description provided for @noTreatments.
  ///
  /// In en, this message translates to:
  /// **'No running treatments'**
  String get noTreatments;

  /// No description provided for @caregivers.
  ///
  /// In en, this message translates to:
  /// **'Caregivers'**
  String get caregivers;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @recentRecords.
  ///
  /// In en, this message translates to:
  /// **'Recent records'**
  String get recentRecords;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'Finished treatments'**
  String get history;

  /// No description provided for @leaveChildTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop being a caregiver for {child}?'**
  String leaveChildTitle(String child);

  /// No description provided for @leaveChildBody.
  ///
  /// In en, this message translates to:
  /// **'Their records are removed from your phones. The other caregivers keep everything.'**
  String get leaveChildBody;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @deleteChildTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {child}?'**
  String deleteChildTitle(String child);

  /// No description provided for @deleteChildBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes the child, every treatment and every dose record for all caregivers. This can\'t be undone. Export the records first if you want to keep them.'**
  String get deleteChildBody;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String fromDate(String date);

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'{start} to {end}'**
  String dateRange(String start, String end);

  /// No description provided for @adherence.
  ///
  /// In en, this message translates to:
  /// **'{percent}% given'**
  String adherence(int percent);

  /// No description provided for @editTreatment.
  ///
  /// In en, this message translates to:
  /// **'Edit treatment'**
  String get editTreatment;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @endToday.
  ///
  /// In en, this message translates to:
  /// **'End after today'**
  String get endToday;

  /// No description provided for @endTodayHint.
  ///
  /// In en, this message translates to:
  /// **'Moves to finished treatments tomorrow'**
  String get endTodayHint;

  /// No description provided for @deleteTreatment.
  ///
  /// In en, this message translates to:
  /// **'Delete treatment'**
  String get deleteTreatment;

  /// No description provided for @deleteTreatmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {medicine}?'**
  String deleteTreatmentTitle(String medicine);

  /// No description provided for @deleteTreatmentBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes the treatment and its dose records for all caregivers. To keep the history, end it instead.'**
  String get deleteTreatmentBody;

  /// No description provided for @youName.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String youName(String name);

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get roleCaregiver;

  /// No description provided for @roleAdminHint.
  ///
  /// In en, this message translates to:
  /// **'Admins manage medicines, treatments and caregivers.'**
  String get roleAdminHint;

  /// No description provided for @roleCaregiverHint.
  ///
  /// In en, this message translates to:
  /// **'Caregivers see everything and log doses.'**
  String get roleCaregiverHint;

  /// No description provided for @removeCaregiverTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeCaregiverTitle(String name);

  /// No description provided for @removeCaregiverBody.
  ///
  /// In en, this message translates to:
  /// **'They lose access at once. The child\'s key is replaced, so nothing written from now on can be read with their old key.'**
  String get removeCaregiverBody;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get makeAdmin;

  /// No description provided for @makeCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Make caregiver'**
  String get makeCaregiver;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Check your connection and try again.'**
  String get actionFailed;

  /// No description provided for @removedTreatment.
  ///
  /// In en, this message translates to:
  /// **'Deleted treatment'**
  String get removedTreatment;

  /// No description provided for @saveFailedOffline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection and try again.'**
  String get saveFailedOffline;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @childName.
  ///
  /// In en, this message translates to:
  /// **'Child\'s name'**
  String get childName;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birthDate;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get color;

  /// No description provided for @childTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone for dose times'**
  String get childTimeZone;

  /// No description provided for @childTimeZoneHint.
  ///
  /// In en, this message translates to:
  /// **'08:00 means 08:00 here, wherever a caregiver is'**
  String get childTimeZoneHint;

  /// No description provided for @missedAfter.
  ///
  /// In en, this message translates to:
  /// **'Missed after'**
  String get missedAfter;

  /// No description provided for @missedAfterHint.
  ///
  /// In en, this message translates to:
  /// **'A dose not logged by then shows as missed'**
  String get missedAfterHint;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String hoursShort(int hours);

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @yourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Shown to the other caregivers'**
  String get yourNameHint;

  /// No description provided for @addChildPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only people you invite can see this child. Names, medicines and doses are encrypted on this phone before they are sent.'**
  String get addChildPrivacy;

  /// No description provided for @searchZone.
  ///
  /// In en, this message translates to:
  /// **'Search city or region'**
  String get searchZone;

  /// No description provided for @addATime.
  ///
  /// In en, this message translates to:
  /// **'Add at least one time'**
  String get addATime;

  /// No description provided for @addTreatmentFor.
  ///
  /// In en, this message translates to:
  /// **'New treatment for {child}'**
  String addTreatmentFor(String child);

  /// No description provided for @medicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get medicine;

  /// No description provided for @medicineName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get medicineName;

  /// No description provided for @medicineForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get medicineForm;

  /// No description provided for @doseAmount.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get doseAmount;

  /// No description provided for @doseUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get doseUnit;

  /// No description provided for @medicineNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get medicineNotes;

  /// No description provided for @medicineNotesHint.
  ///
  /// In en, this message translates to:
  /// **'With food, shake well…'**
  String get medicineNotesHint;

  /// No description provided for @when.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get when;

  /// No description provided for @fixedTimes.
  ///
  /// In en, this message translates to:
  /// **'Set times'**
  String get fixedTimes;

  /// No description provided for @timesPerDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Once a day} =2{Twice a day} other{{count} times a day}}'**
  String timesPerDay(int count);

  /// No description provided for @fewerTimes.
  ///
  /// In en, this message translates to:
  /// **'Fewer times'**
  String get fewerTimes;

  /// No description provided for @moreTimes.
  ///
  /// In en, this message translates to:
  /// **'More times'**
  String get moreTimes;

  /// No description provided for @timesInZone.
  ///
  /// In en, this message translates to:
  /// **'Times are in {zone}.'**
  String timesInZone(String zone);

  /// No description provided for @minHoursBetween.
  ///
  /// In en, this message translates to:
  /// **'Hours between doses'**
  String get minHoursBetween;

  /// No description provided for @maxPer24h.
  ///
  /// In en, this message translates to:
  /// **'Most per 24 h'**
  String get maxPer24h;

  /// No description provided for @howLong.
  ///
  /// In en, this message translates to:
  /// **'How long'**
  String get howLong;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startDate;

  /// No description provided for @numberOfDays.
  ///
  /// In en, this message translates to:
  /// **'Number of days'**
  String get numberOfDays;

  /// No description provided for @lastDayIs.
  ///
  /// In en, this message translates to:
  /// **'Last day: {date}'**
  String lastDayIs(String date);

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Empty: until you end it'**
  String get ongoing;

  /// No description provided for @inviteTo.
  ///
  /// In en, this message translates to:
  /// **'Invite to {child}'**
  String inviteTo(String child);

  /// No description provided for @inviteIntro.
  ///
  /// In en, this message translates to:
  /// **'Invite a parent, grandparent or babysitter. They need a Zero-Trust account. The invite works once and expires in 7 days.'**
  String get inviteIntro;

  /// No description provided for @createInvite.
  ///
  /// In en, this message translates to:
  /// **'Create invite'**
  String get createInvite;

  /// No description provided for @inviteReady.
  ///
  /// In en, this message translates to:
  /// **'Let them scan this code, or send them the link.'**
  String get inviteReady;

  /// No description provided for @inviteQr.
  ///
  /// In en, this message translates to:
  /// **'Invite QR code'**
  String get inviteQr;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @shareLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get shareLink;

  /// No description provided for @inviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Join me in ZT Meds to look after {child}: {link}'**
  String inviteMessage(String child, String link);

  /// No description provided for @inviteNextSteps.
  ///
  /// In en, this message translates to:
  /// **'When they open it, they see an 8-digit code. Compare it with the code shown here before letting them in, so you know it is really them.'**
  String get inviteNextSteps;

  /// No description provided for @checkForAnswers.
  ///
  /// In en, this message translates to:
  /// **'Check for answers'**
  String get checkForAnswers;

  /// No description provided for @needsInternet.
  ///
  /// In en, this message translates to:
  /// **'This needs an internet connection. Try again when you\'re online.'**
  String get needsInternet;

  /// No description provided for @confirmJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Let {name} help with {child}?'**
  String confirmJoinTitle(String name, String child);

  /// No description provided for @confirmJoinBody.
  ///
  /// In en, this message translates to:
  /// **'Ask them for the code on their phone. Only let them in if it is exactly this:'**
  String get confirmJoinBody;

  /// No description provided for @codesDiffer.
  ///
  /// In en, this message translates to:
  /// **'Codes differ'**
  String get codesDiffer;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @codesMatch.
  ///
  /// In en, this message translates to:
  /// **'Codes match'**
  String get codesMatch;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'{name} can now see and log doses'**
  String joined(String name);

  /// No description provided for @inviteOtherApp.
  ///
  /// In en, this message translates to:
  /// **'This invite is for another Zero-Trust app'**
  String get inviteOtherApp;

  /// No description provided for @inviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a ZT Meds invite link'**
  String get inviteInvalid;

  /// No description provided for @inviteUsed.
  ///
  /// In en, this message translates to:
  /// **'This invite was already used, expired or was withdrawn. Ask for a new one.'**
  String get inviteUsed;

  /// No description provided for @joinCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Show this code to the admin'**
  String get joinCodeTitle;

  /// No description provided for @joinCodeBody.
  ///
  /// In en, this message translates to:
  /// **'They compare it with the code on their phone and let you in. The child appears here once they do.'**
  String get joinCodeBody;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @joinIntro.
  ///
  /// In en, this message translates to:
  /// **'Paste the invite link you were sent, or scan the QR code on the other parent\'s phone.'**
  String get joinIntro;

  /// No description provided for @inviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLink;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQr;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @medicineList.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicineList;

  /// No description provided for @medicineListHint.
  ///
  /// In en, this message translates to:
  /// **'The family\'s list, reused across children'**
  String get medicineListHint;

  /// No description provided for @medicineListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Medicines you add to treatments appear here, ready to reuse.'**
  String get medicineListEmpty;

  /// No description provided for @deleteMedicineTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {medicine} from the list?'**
  String deleteMedicineTitle(String medicine);

  /// No description provided for @deleteMedicineBody.
  ///
  /// In en, this message translates to:
  /// **'Running treatments keep their copy of it.'**
  String get deleteMedicineBody;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @disclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Not medical advice'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerBody1.
  ///
  /// In en, this message translates to:
  /// **'ZT Meds helps you remember and record the medicines your children get. It does not give medical advice, check doses or check for interactions.'**
  String get disclaimerBody1;

  /// No description provided for @disclaimerBody2.
  ///
  /// In en, this message translates to:
  /// **'Always follow the instructions from your doctor or pharmacist and on the medicine\'s label. If you are unsure, ask them.'**
  String get disclaimerBody2;

  /// No description provided for @disclaimerBody3.
  ///
  /// In en, this message translates to:
  /// **'Reminders can be late or not show at all, for example when the phone is off, in battery saver or has notifications turned off. Never rely on the app alone.'**
  String get disclaimerBody3;

  /// No description provided for @disclaimerBody4.
  ///
  /// In en, this message translates to:
  /// **'In an emergency, call your local emergency number.'**
  String get disclaimerBody4;

  /// No description provided for @disclaimerAccept.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get disclaimerAccept;

  /// No description provided for @newTimesFromTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Saved. The new times start tomorrow, so today\'s records stay as they are.'**
  String get newTimesFromTomorrow;

  /// No description provided for @atLeastOne.
  ///
  /// In en, this message translates to:
  /// **'At least 1'**
  String get atLeastOne;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePhoto;

  /// No description provided for @photoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the photo. Try again.'**
  String get photoFailed;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
