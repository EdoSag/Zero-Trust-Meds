// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZT Meds';

  @override
  String get todayTitle => 'Today';

  @override
  String get settings => 'Settings';

  @override
  String get loadError =>
      'Couldn\'t load your children. Pull down to try again.';

  @override
  String get addChildOrJoin => 'Add or join';

  @override
  String get addChild => 'Add a child';

  @override
  String get addChildHint => 'You manage their medicines and invite caregivers';

  @override
  String get joinWithInvite => 'Join with an invite';

  @override
  String get joinWithInviteHint =>
      'Scan or paste the invite another parent sent you';

  @override
  String get emptyTitle => 'Track your children\'s medicines together';

  @override
  String get emptyBody =>
      'Add a child, set up their treatments and invite everyone who gives them medicine. Everything is end-to-end encrypted.';

  @override
  String get waitingForAdmin => 'Waiting for the admin to let you in';

  @override
  String get waitingForSync =>
      'Confirmed. The child\'s details will appear in a moment.';

  @override
  String waitingCode(String code) {
    return 'Your code: $code. The admin checks it on their phone.';
  }

  @override
  String joinRequest(String name, String child) {
    return '$name wants to help with $child';
  }

  @override
  String get joinRequestHint => 'Tap to compare codes and let them in';

  @override
  String get nothingToday => 'No doses today';

  @override
  String givenOfToday(int given, int total) {
    return '$given of $total doses given today';
  }

  @override
  String get markGiven => 'Mark as given';

  @override
  String get giveAgain => 'Give again';

  @override
  String get givenAtOtherTime => 'Given at another time';

  @override
  String get skipDose => 'Skip this dose';

  @override
  String get asNeeded => 'As needed';

  @override
  String lastGiven(String name, String when) {
    return 'Last: $name, $when';
  }

  @override
  String nextAllowed(String when) {
    return 'Next allowed $when';
  }

  @override
  String get canGiveNow => 'Can be given now';

  @override
  String everyHours(String hours) {
    return 'At least $hours h apart';
  }

  @override
  String maxPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'At most $count a day',
      one: 'At most 1 a day',
    );
    return '$_temp0';
  }

  @override
  String get statusGiven => 'Given';

  @override
  String get statusDue => 'Due';

  @override
  String get statusMissed => 'Missed';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusGivenTwice => 'Given twice';

  @override
  String slot(String slot) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'morning': 'Morning',
      'noon': 'Noon',
      'evening': 'Evening',
      'other': 'Night',
    });
    return '$_temp0';
  }

  @override
  String form(String form) {
    String _temp0 = intl.Intl.selectLogic(form, {
      'liquid': 'Liquid',
      'tablet': 'Tablet',
      'capsule': 'Capsule',
      'drops': 'Drops',
      'inhaler': 'Inhaler',
      'cream': 'Cream',
      'injection': 'Injection',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String formUnit(String form) {
    String _temp0 = intl.Intl.selectLogic(form, {
      'liquid': 'ml',
      'tablet': 'tablet',
      'capsule': 'capsule',
      'drops': 'drops',
      'inhaler': 'puffs',
      'cream': 'application',
      'injection': 'ml',
      'other': 'dose',
    });
    return '$_temp0';
  }

  @override
  String loggedGiven(String medicine, String child) {
    return '$medicine logged as given to $child';
  }

  @override
  String get undo => 'Undo';

  @override
  String warnTitle(String medicine) {
    return 'Give $medicine again?';
  }

  @override
  String warnAlreadyGiven(String name, String when) {
    return '$name already gave this dose at $when.';
  }

  @override
  String warnTooSoon(String last, String next) {
    return 'The last dose was at $last. The next one is allowed from $next.';
  }

  @override
  String warnMaxReached(int count, String next) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Already $count doses in the last 24 hours, the most allowed.',
      one: 'Already 1 dose in the last 24 hours, the most allowed.',
    );
    return '$_temp0 The next one is allowed from $next.';
  }

  @override
  String get warnCheck =>
      'Check the label or ask a doctor or pharmacist if unsure.';

  @override
  String get dontGive => 'Don\'t give';

  @override
  String get giveAnyway => 'Give anyway';

  @override
  String get skipTitle => 'Skip this dose';

  @override
  String get skipReason => 'Reason';

  @override
  String get skip => 'Skip';

  @override
  String get reasonAsleep => 'Asleep';

  @override
  String get reasonVomited => 'Vomited';

  @override
  String get reasonRefused => 'Refused';

  @override
  String get reasonDoctor => 'Doctor\'s advice';

  @override
  String get cancel => 'Cancel';

  @override
  String get more => 'More';

  @override
  String plannedFor(String child, String when) {
    return 'For $child, $when';
  }

  @override
  String givenBy(String name, String when) {
    return 'Given by $name at $when';
  }

  @override
  String skippedBy(String name, String when) {
    return 'Skipped by $name at $when';
  }

  @override
  String get changeTime => 'Change the time';

  @override
  String get undoRecord => 'Remove this record';

  @override
  String get recordRemoved => 'Record removed';

  @override
  String get childGone => 'This child is no longer here.';

  @override
  String get editChild => 'Edit child';

  @override
  String get exportChild => 'Export records';

  @override
  String get leaveChild => 'Stop being a caregiver';

  @override
  String get deleteChild => 'Delete child';

  @override
  String get addTreatment => 'Add treatment';

  @override
  String bornOn(String date) {
    return 'Born $date';
  }

  @override
  String timesIn(String zone) {
    return 'Dose times in $zone';
  }

  @override
  String get today => 'Today';

  @override
  String get treatments => 'Treatments';

  @override
  String get noTreatments => 'No running treatments';

  @override
  String get caregivers => 'Caregivers';

  @override
  String get invite => 'Invite';

  @override
  String get recentRecords => 'Recent records';

  @override
  String get history => 'Finished treatments';

  @override
  String leaveChildTitle(String child) {
    return 'Stop being a caregiver for $child?';
  }

  @override
  String get leaveChildBody =>
      'Their records are removed from your phones. The other caregivers keep everything.';

  @override
  String get leave => 'Leave';

  @override
  String deleteChildTitle(String child) {
    return 'Delete $child?';
  }

  @override
  String get deleteChildBody =>
      'Deletes the child, every treatment and every dose record for all caregivers. This can\'t be undone. Export the records first if you want to keep them.';

  @override
  String get delete => 'Delete';

  @override
  String fromDate(String date) {
    return 'From $date';
  }

  @override
  String dateRange(String start, String end) {
    return '$start to $end';
  }

  @override
  String adherence(int percent) {
    return '$percent% given';
  }

  @override
  String get editTreatment => 'Edit treatment';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get endToday => 'End after today';

  @override
  String get endTodayHint => 'Moves to finished treatments tomorrow';

  @override
  String get deleteTreatment => 'Delete treatment';

  @override
  String deleteTreatmentTitle(String medicine) {
    return 'Delete $medicine?';
  }

  @override
  String get deleteTreatmentBody =>
      'Deletes the treatment and its dose records for all caregivers. To keep the history, end it instead.';

  @override
  String youName(String name) {
    return '$name (you)';
  }

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleCaregiver => 'Caregiver';

  @override
  String get roleAdminHint =>
      'Admins manage medicines, treatments and caregivers.';

  @override
  String get roleCaregiverHint => 'Caregivers see everything and log doses.';

  @override
  String removeCaregiverTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeCaregiverBody =>
      'They lose access at once. The child\'s key is replaced, so nothing written from now on can be read with their old key.';

  @override
  String get remove => 'Remove';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get makeCaregiver => 'Make caregiver';

  @override
  String get actionFailed =>
      'That didn\'t work. Check your connection and try again.';

  @override
  String get removedTreatment => 'Deleted treatment';

  @override
  String get saveFailedOffline =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String get save => 'Save';

  @override
  String get childName => 'Child\'s name';

  @override
  String get required => 'Required';

  @override
  String get birthDate => 'Birth date';

  @override
  String get optional => 'Optional';

  @override
  String get color => 'Colour';

  @override
  String get childTimeZone => 'Time zone for dose times';

  @override
  String get childTimeZoneHint =>
      '08:00 means 08:00 here, wherever a caregiver is';

  @override
  String get missedAfter => 'Missed after';

  @override
  String get missedAfterHint => 'A dose not logged by then shows as missed';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String get yourName => 'Your name';

  @override
  String get yourNameHint => 'Shown to the other caregivers';

  @override
  String get addChildPrivacy =>
      'Only people you invite can see this child. Names, medicines and doses are encrypted on this phone before they are sent.';

  @override
  String get searchZone => 'Search city or region';

  @override
  String get addATime => 'Add at least one time';

  @override
  String addTreatmentFor(String child) {
    return 'New treatment for $child';
  }

  @override
  String get medicine => 'Medicine';

  @override
  String get medicineName => 'Name';

  @override
  String get medicineForm => 'Form';

  @override
  String get doseAmount => 'Dose';

  @override
  String get doseUnit => 'Unit';

  @override
  String get medicineNotes => 'Notes';

  @override
  String get medicineNotesHint => 'With food, shake well…';

  @override
  String get when => 'When';

  @override
  String get fixedTimes => 'Set times';

  @override
  String timesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times a day',
      two: 'Twice a day',
      one: 'Once a day',
    );
    return '$_temp0';
  }

  @override
  String get fewerTimes => 'Fewer times';

  @override
  String get moreTimes => 'More times';

  @override
  String timesInZone(String zone) {
    return 'Times are in $zone.';
  }

  @override
  String get minHoursBetween => 'Hours between doses';

  @override
  String get maxPer24h => 'Most per 24 h';

  @override
  String get howLong => 'How long';

  @override
  String get startDate => 'Start';

  @override
  String get numberOfDays => 'Number of days';

  @override
  String lastDayIs(String date) {
    return 'Last day: $date';
  }

  @override
  String get ongoing => 'Empty: until you end it';

  @override
  String inviteTo(String child) {
    return 'Invite to $child';
  }

  @override
  String get inviteIntro =>
      'Invite a parent, grandparent or babysitter. They need a Zero-Trust account. The invite works once and expires in 7 days.';

  @override
  String get createInvite => 'Create invite';

  @override
  String get inviteReady => 'Let them scan this code, or send them the link.';

  @override
  String get inviteQr => 'Invite QR code';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get copyLink => 'Copy link';

  @override
  String get shareLink => 'Send link';

  @override
  String inviteMessage(String child, String link) {
    return 'Join me in ZT Meds to look after $child: $link';
  }

  @override
  String get inviteNextSteps =>
      'When they open it, they see an 8-digit code. Compare it with the code shown here before letting them in, so you know it is really them.';

  @override
  String get checkForAnswers => 'Check for answers';

  @override
  String get needsInternet =>
      'This needs an internet connection. Try again when you\'re online.';

  @override
  String confirmJoinTitle(String name, String child) {
    return 'Let $name help with $child?';
  }

  @override
  String get confirmJoinBody =>
      'Ask them for the code on their phone. Only let them in if it is exactly this:';

  @override
  String get codesDiffer => 'Codes differ';

  @override
  String get later => 'Later';

  @override
  String get codesMatch => 'Codes match';

  @override
  String joined(String name) {
    return '$name can now see and log doses';
  }

  @override
  String get inviteOtherApp => 'This invite is for another Zero-Trust app';

  @override
  String get inviteInvalid => 'This isn\'t a ZT Meds invite link';

  @override
  String get inviteUsed =>
      'This invite was already used, expired or was withdrawn. Ask for a new one.';

  @override
  String get joinCodeTitle => 'Show this code to the admin';

  @override
  String get joinCodeBody =>
      'They compare it with the code on their phone and let you in. The child appears here once they do.';

  @override
  String get done => 'Done';

  @override
  String get joinIntro =>
      'Paste the invite link you were sent, or scan the QR code on the other parent\'s phone.';

  @override
  String get inviteLink => 'Invite link';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get join => 'Join';

  @override
  String get notSet => 'Not set';

  @override
  String get medicineList => 'Medicines';

  @override
  String get medicineListHint => 'The family\'s list, reused across children';

  @override
  String get medicineListEmpty =>
      'Medicines you add to treatments appear here, ready to reuse.';

  @override
  String deleteMedicineTitle(String medicine) {
    return 'Remove $medicine from the list?';
  }

  @override
  String get deleteMedicineBody => 'Running treatments keep their copy of it.';

  @override
  String get edit => 'Edit';

  @override
  String get disclaimerTitle => 'Not medical advice';

  @override
  String get disclaimerBody1 =>
      'ZT Meds helps you remember and record the medicines your children get. It does not give medical advice, check doses or check for interactions.';

  @override
  String get disclaimerBody2 =>
      'Always follow the instructions from your doctor or pharmacist and on the medicine\'s label. If you are unsure, ask them.';

  @override
  String get disclaimerBody3 =>
      'Reminders can be late or not show at all, for example when the phone is off, in battery saver or has notifications turned off. Never rely on the app alone.';

  @override
  String get disclaimerBody4 =>
      'In an emergency, call your local emergency number.';

  @override
  String get disclaimerAccept => 'I understand';

  @override
  String get newTimesFromTomorrow =>
      'Saved. The new times start tomorrow, so today\'s records stay as they are.';

  @override
  String get atLeastOne => 'At least 1';

  @override
  String get charts => 'Charts';

  @override
  String chartsFor(String child) {
    return '$child: how it went';
  }

  @override
  String lastDays(int days) {
    return '$days days';
  }

  @override
  String get chartsEmpty =>
      'Nothing to show for this period yet. Charts fill in as doses are logged.';

  @override
  String get plannedDosesPerDay => 'Planned doses per day';

  @override
  String get byTreatment => 'By treatment';

  @override
  String get asNeededGiven => 'As-needed doses given';

  @override
  String asNeededSummary(int given, int most) {
    String _temp0 = intl.Intl.pluralLogic(
      given,
      locale: localeName,
      other: 'Given $given times',
      one: 'Given once',
    );
    return '$_temp0, most in a day: $most';
  }

  @override
  String get chartsNote =>
      'Worked out on this phone from the records everyone logged. Doses still to come today aren\'t counted.';

  @override
  String get noPlannedDosesYet => 'No planned doses due yet in this period';

  @override
  String plannedGivenShare(int given, int total) {
    return '$given of $total planned doses given';
  }

  @override
  String dayBarLabel(String day, int given, int missed, int skipped) {
    return '$day: $given given, $missed missed, $skipped skipped';
  }

  @override
  String asNeededDayLabel(String day, int count) {
    return '$day: $count as-needed doses';
  }

  @override
  String missedCount(int count) {
    return '$count missed';
  }

  @override
  String skippedCount(int count) {
    return '$count skipped';
  }

  @override
  String givenTwiceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count given twice',
      one: '1 given twice',
    );
    return '$_temp0';
  }

  @override
  String get byTreatmentHint =>
      'Tap a medicine to see every dose as a calendar.';

  @override
  String get timeline => 'Timeline';

  @override
  String get timelineHint =>
      'Every medicine together, newest day first. Tap a dose for details.';

  @override
  String gridIntro(String child) {
    return 'Days are rows and dose times are columns, in $child\'s time zone. Tap a dose to see who gave it and when.';
  }

  @override
  String cellLabel(String day, String time, String status) {
    return '$day, $time: $status';
  }

  @override
  String get familyOverview => 'Family';

  @override
  String lastSevenDays(String percent) {
    return 'Last 7 days: $percent';
  }

  @override
  String todayCount(int count, String status) {
    return '$count $status';
  }

  @override
  String reminderDoseTitle(String child, String medicine) {
    return '$child: $medicine';
  }

  @override
  String reminderDoseBody(String dose, String time) {
    return '$dose at $time';
  }

  @override
  String reminderFollowUpTitle(String child, String medicine) {
    return 'Still due: $medicine for $child';
  }

  @override
  String reminderFollowUpBody(String time) {
    return 'Planned for $time and not logged yet.';
  }

  @override
  String reminderMissedTitle(String child, String medicine) {
    return 'Not logged: $medicine for $child';
  }

  @override
  String reminderMissedBody(String time) {
    return 'The $time dose isn\'t logged. Open ZT Meds to check before giving it.';
  }

  @override
  String reminderLastDayTitle(String child, String medicine) {
    return 'Last day of $medicine for $child';
  }

  @override
  String get reminderLastDayBody => 'Today is the last day of this course.';

  @override
  String get reminderPrivateTitle => 'Medicine reminder';

  @override
  String get reminderPrivateBody => 'Open ZT Meds to see which dose.';

  @override
  String get reminderChannel => 'Dose reminders';

  @override
  String get reminderChannelHint =>
      'When your children\'s doses are due or missed';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersHint => 'When doses are due, follow-ups and missed doses';

  @override
  String get remindersOn => 'Dose reminders';

  @override
  String get remindersOnHint => 'At each planned dose time';

  @override
  String get followUp => 'Follow-up';

  @override
  String get followUpHint => 'Again if a dose isn\'t logged yet';

  @override
  String get followUpOff => 'Off';

  @override
  String followUpAfter(int minutes) {
    return '$minutes minutes later';
  }

  @override
  String get missedAlerts => 'Missed-dose alert';

  @override
  String get missedAlertsHint =>
      'When a dose passes the child\'s \"missed after\" time';

  @override
  String get lastDayNotice => 'Last-day notice';

  @override
  String get lastDayNoticeHint => 'At 9:00 on the last day of a course';

  @override
  String get showNamesInReminders => 'Names in reminders';

  @override
  String get showNamesInRemindersHint =>
      'Off: reminders only say \"Medicine reminder\". The lock screen never shows the text.';

  @override
  String get remindersForChildren => 'Remind me about';

  @override
  String get remindersHowTheyWork =>
      'Reminders are set on this phone and need no internet. A dose logged on another phone cancels them here when this phone syncs, which happens while ZT Meds is open. Every caregiver sets their own reminders.';

  @override
  String get reminderDoseGone => 'That dose isn\'t planned any more.';

  @override
  String get quietHours => 'Quiet hours';

  @override
  String get quietHoursOff => 'Off';

  @override
  String quietHoursRange(String from, String until) {
    return '$from to $until: dose reminders without sound, no follow-ups or alerts';
  }

  @override
  String get quietHoursFrom => 'Starts';

  @override
  String get quietHoursUntil => 'Ends';
}
