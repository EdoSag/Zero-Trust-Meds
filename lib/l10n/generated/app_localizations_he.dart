// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'ZT Meds';

  @override
  String get todayTitle => 'היום';

  @override
  String get settings => 'הגדרות';

  @override
  String get loadError =>
      'לא ניתן היה לטעון את הילדים. אפשר למשוך למטה כדי לנסות שוב.';

  @override
  String get addChildOrJoin => 'הוספה או הצטרפות';

  @override
  String get addChild => 'הוספת ילד או ילדה';

  @override
  String get addChildHint => 'את התרופות מנהלים אתם, ומזמינים את המטפלים';

  @override
  String get joinWithInvite => 'הצטרפות עם הזמנה';

  @override
  String get joinWithInviteHint => 'סריקה או הדבקה של ההזמנה ששלח לכם הורה אחר';

  @override
  String get emptyTitle => 'מעקב משותף אחרי התרופות של הילדים';

  @override
  String get emptyBody =>
      'מוסיפים ילד או ילדה, מגדירים את הטיפולים ומזמינים את כל מי שנותן להם תרופות. הכול מוצפן מקצה לקצה.';

  @override
  String get waitingForAdmin => 'ממתינים שהמנהל יאשר את הכניסה';

  @override
  String get waitingForSync => 'אושר. פרטי הילד יופיעו בעוד רגע.';

  @override
  String waitingCode(String code) {
    return 'הקוד שלכם: $code. המנהל בודק אותו בטלפון שלו.';
  }

  @override
  String joinRequest(String name, String child) {
    return '$name רוצה לעזור עם $child';
  }

  @override
  String get joinRequestHint => 'יש להקיש כדי להשוות קודים ולאשר כניסה';

  @override
  String get nothingToday => 'אין מנות היום';

  @override
  String givenOfToday(int given, int total) {
    return 'ניתנו היום $given מתוך $total מנות';
  }

  @override
  String get markGiven => 'סימון כניתן';

  @override
  String get giveAgain => 'מתן נוסף';

  @override
  String get givenAtOtherTime => 'ניתן בשעה אחרת';

  @override
  String get skipDose => 'דילוג על המנה';

  @override
  String get asNeeded => 'לפי הצורך';

  @override
  String lastGiven(String name, String when) {
    return 'אחרון: $name, $when';
  }

  @override
  String nextAllowed(String when) {
    return 'המנה הבאה מותרת $when';
  }

  @override
  String get canGiveNow => 'אפשר לתת עכשיו';

  @override
  String everyHours(String hours) {
    return 'לפחות $hours שע׳ בין מנות';
  }

  @override
  String maxPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לכל היותר $count ביום',
      one: 'לכל היותר פעם ביום',
    );
    return '$_temp0';
  }

  @override
  String get statusGiven => 'ניתן';

  @override
  String get statusDue => 'הגיע הזמן';

  @override
  String get statusMissed => 'הוחמץ';

  @override
  String get statusUpcoming => 'בקרוב';

  @override
  String get statusSkipped => 'דולג';

  @override
  String get statusPaused => 'מושהה';

  @override
  String get statusGivenTwice => 'ניתן פעמיים';

  @override
  String slot(String slot) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'morning': 'בוקר',
      'noon': 'צהריים',
      'evening': 'ערב',
      'other': 'לילה',
    });
    return '$_temp0';
  }

  @override
  String form(String form) {
    String _temp0 = intl.Intl.selectLogic(form, {
      'liquid': 'נוזל',
      'tablet': 'טבלייה',
      'capsule': 'כמוסה',
      'drops': 'טיפות',
      'inhaler': 'משאף',
      'cream': 'משחה',
      'injection': 'זריקה',
      'other': 'אחר',
    });
    return '$_temp0';
  }

  @override
  String formUnit(String form) {
    String _temp0 = intl.Intl.selectLogic(form, {
      'liquid': 'מ״ל',
      'tablet': 'טבלייה',
      'capsule': 'כמוסה',
      'drops': 'טיפות',
      'inhaler': 'שאיפות',
      'cream': 'מריחה',
      'injection': 'מ״ל',
      'other': 'מנה',
    });
    return '$_temp0';
  }

  @override
  String loggedGiven(String medicine, String child) {
    return '$medicine נרשם כניתן ל$child';
  }

  @override
  String get undo => 'ביטול פעולה';

  @override
  String warnTitle(String medicine) {
    return 'לתת שוב $medicine?';
  }

  @override
  String warnAlreadyGiven(String name, String when) {
    return '$name כבר נתן את המנה הזאת ב־$when.';
  }

  @override
  String warnTooSoon(String last, String next) {
    return 'המנה האחרונה ניתנה ב־$last. המנה הבאה מותרת החל מ־$next.';
  }

  @override
  String warnMaxReached(int count, String next) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'כבר ניתנו $count מנות ב־24 השעות האחרונות, המקסימום המותר.',
      one: 'כבר ניתנה מנה אחת ב־24 השעות האחרונות, המקסימום המותר.',
    );
    return '$_temp0 המנה הבאה מותרת החל מ־$next.';
  }

  @override
  String get warnCheck =>
      'במקרה של ספק, כדאי לבדוק את העלון או לשאול רופא או רוקח.';

  @override
  String get dontGive => 'לא לתת';

  @override
  String get giveAnyway => 'לתת בכל זאת';

  @override
  String get skipTitle => 'דילוג על המנה';

  @override
  String get skipReason => 'סיבה';

  @override
  String get skip => 'דילוג';

  @override
  String get reasonAsleep => 'ישן';

  @override
  String get reasonVomited => 'הקיא';

  @override
  String get reasonRefused => 'סירב';

  @override
  String get reasonDoctor => 'לפי הנחיית רופא';

  @override
  String get cancel => 'ביטול';

  @override
  String get more => 'עוד';

  @override
  String plannedFor(String child, String when) {
    return 'עבור $child, $when';
  }

  @override
  String givenBy(String name, String when) {
    return 'ניתן על ידי $name ב־$when';
  }

  @override
  String skippedBy(String name, String when) {
    return 'דולג על ידי $name ב־$when';
  }

  @override
  String get changeTime => 'שינוי השעה';

  @override
  String get undoRecord => 'הסרת הרישום';

  @override
  String get recordRemoved => 'הרישום הוסר';

  @override
  String get childGone => 'הילד או הילדה כבר לא כאן.';

  @override
  String get editChild => 'עריכת פרטי הילד';

  @override
  String get exportChild => 'ייצוא הרישומים';

  @override
  String get leaveChild => 'הפסקת הטיפול';

  @override
  String get deleteChild => 'מחיקת הילד';

  @override
  String get addTreatment => 'הוספת טיפול';

  @override
  String bornOn(String date) {
    return 'תאריך לידה: $date';
  }

  @override
  String timesIn(String zone) {
    return 'שעות המנות לפי $zone';
  }

  @override
  String get today => 'היום';

  @override
  String get treatments => 'טיפולים';

  @override
  String get noTreatments => 'אין טיפולים פעילים';

  @override
  String get caregivers => 'מטפלים';

  @override
  String get invite => 'הזמנה';

  @override
  String get recentRecords => 'רישומים אחרונים';

  @override
  String get history => 'טיפולים שהסתיימו';

  @override
  String leaveChildTitle(String child) {
    return 'להפסיק לטפל ב$child?';
  }

  @override
  String get leaveChildBody =>
      'הרישומים יוסרו מהטלפונים שלכם. שאר המטפלים שומרים את הכול.';

  @override
  String get leave => 'יציאה';

  @override
  String deleteChildTitle(String child) {
    return 'למחוק את $child?';
  }

  @override
  String get deleteChildBody =>
      'הילד, כל הטיפולים וכל רישומי המנות יימחקו אצל כל המטפלים. אי אפשר לבטל את זה. כדי לשמור את הרישומים, כדאי לייצא אותם קודם.';

  @override
  String get delete => 'מחיקה';

  @override
  String fromDate(String date) {
    return 'החל מ־$date';
  }

  @override
  String dateRange(String start, String end) {
    return '$start עד $end';
  }

  @override
  String adherence(int percent) {
    return '$percent% ניתנו';
  }

  @override
  String get editTreatment => 'עריכת הטיפול';

  @override
  String get resume => 'חידוש';

  @override
  String get pause => 'השהיה';

  @override
  String get endToday => 'סיום אחרי היום';

  @override
  String get endTodayHint => 'יעבור לטיפולים שהסתיימו מחר';

  @override
  String get deleteTreatment => 'מחיקת הטיפול';

  @override
  String deleteTreatmentTitle(String medicine) {
    return 'למחוק את $medicine?';
  }

  @override
  String get deleteTreatmentBody =>
      'הטיפול ורישומי המנות שלו יימחקו אצל כל המטפלים. כדי לשמור את ההיסטוריה, עדיף לסיים אותו.';

  @override
  String youName(String name) {
    return '$name (את/ה)';
  }

  @override
  String get roleAdmin => 'מנהל';

  @override
  String get roleCaregiver => 'מטפל';

  @override
  String get roleAdminHint => 'מנהלים מנהלים את התרופות, הטיפולים והמטפלים.';

  @override
  String get roleCaregiverHint => 'מטפלים רואים הכול ורושמים מנות.';

  @override
  String removeCaregiverTitle(String name) {
    return 'להסיר את $name?';
  }

  @override
  String get removeCaregiverBody =>
      'הגישה נחסמת מיד. המפתח של הילד מוחלף, כך שאי אפשר לקרוא שום דבר שייכתב מעכשיו עם המפתח הישן.';

  @override
  String get remove => 'הסרה';

  @override
  String get makeAdmin => 'הפיכה למנהל';

  @override
  String get makeCaregiver => 'הפיכה למטפל';

  @override
  String get actionFailed => 'זה לא הצליח. כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get removedTreatment => 'הטיפול נמחק';

  @override
  String get saveFailedOffline =>
      'לא ניתן היה לשמור. כדאי לבדוק את החיבור ולנסות שוב.';

  @override
  String get save => 'שמירה';

  @override
  String get childName => 'שם הילד';

  @override
  String get required => 'שדה חובה';

  @override
  String get birthDate => 'תאריך לידה';

  @override
  String get optional => 'לא חובה';

  @override
  String get color => 'צבע';

  @override
  String get childTimeZone => 'אזור זמן לשעות המנות';

  @override
  String get childTimeZoneHint => '08:00 פירושו 08:00 כאן, איפה שהמטפל לא יהיה';

  @override
  String get missedAfter => 'הוחמץ אחרי';

  @override
  String get missedAfterHint => 'מנה שלא נרשמה עד אז מוצגת כמוחמצת';

  @override
  String minutesShort(int minutes) {
    return '$minutes דק׳';
  }

  @override
  String hoursShort(int hours) {
    return '$hours שע׳';
  }

  @override
  String get yourName => 'השם שלך';

  @override
  String get yourNameHint => 'מוצג לשאר המטפלים';

  @override
  String get addChildPrivacy =>
      'רק אנשים שתזמינו יכולים לראות את הילד. שמות, תרופות ומנות מוצפנים בטלפון הזה לפני שהם נשלחים.';

  @override
  String get searchZone => 'חיפוש עיר או אזור';

  @override
  String get addATime => 'יש להוסיף לפחות שעה אחת';

  @override
  String addTreatmentFor(String child) {
    return 'טיפול חדש עבור $child';
  }

  @override
  String get medicine => 'תרופה';

  @override
  String get medicineName => 'שם';

  @override
  String get medicineForm => 'צורה';

  @override
  String get doseAmount => 'מנה';

  @override
  String get doseUnit => 'יחידה';

  @override
  String get medicineNotes => 'הערות';

  @override
  String get medicineNotesHint => 'עם אוכל, לנער היטב…';

  @override
  String get when => 'מתי';

  @override
  String get fixedTimes => 'שעות קבועות';

  @override
  String timesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פעמים ביום',
      two: 'פעמיים ביום',
      one: 'פעם ביום',
    );
    return '$_temp0';
  }

  @override
  String get fewerTimes => 'פחות פעמים';

  @override
  String get moreTimes => 'יותר פעמים';

  @override
  String timesInZone(String zone) {
    return 'השעות לפי $zone.';
  }

  @override
  String get minHoursBetween => 'שעות בין מנות';

  @override
  String get maxPer24h => 'מקסימום ב־24 שעות';

  @override
  String get howLong => 'לכמה זמן';

  @override
  String get startDate => 'התחלה';

  @override
  String get numberOfDays => 'מספר ימים';

  @override
  String lastDayIs(String date) {
    return 'יום אחרון: $date';
  }

  @override
  String get ongoing => 'ריק: עד שמסיימים אותו';

  @override
  String inviteTo(String child) {
    return 'הזמנה לטיפול ב$child';
  }

  @override
  String get inviteIntro =>
      'אפשר להזמין הורה, סבא, סבתא או בייביסיטר. צריך חשבון Zero-Trust. ההזמנה עובדת פעם אחת ותוקפה פג אחרי 7 ימים.';

  @override
  String get createInvite => 'יצירת הזמנה';

  @override
  String get inviteReady =>
      'אפשר לתת להם לסרוק את הקוד הזה, או לשלוח להם את הקישור.';

  @override
  String get inviteQr => 'קוד QR של ההזמנה';

  @override
  String get linkCopied => 'הקישור הועתק';

  @override
  String get copyLink => 'העתקת הקישור';

  @override
  String get shareLink => 'שליחת הקישור';

  @override
  String inviteMessage(String child, String link) {
    return 'הצטרפו אליי ב־ZT Meds כדי לטפל ב$child: $link';
  }

  @override
  String get inviteNextSteps =>
      'כשהם פותחים אותו, הם רואים קוד בן 8 ספרות. לפני שמאשרים, כדאי להשוות אותו לקוד שמוצג כאן, כדי לדעת שזה באמת הם.';

  @override
  String get checkForAnswers => 'בדיקת תשובות';

  @override
  String get needsInternet => 'צריך חיבור לאינטרנט. אפשר לנסות שוב כשיש חיבור.';

  @override
  String confirmJoinTitle(String name, String child) {
    return 'לאשר ל$name לעזור עם $child?';
  }

  @override
  String get confirmJoinBody =>
      'כדאי לבקש מהם את הקוד שבטלפון שלהם, ולאשר רק אם הוא בדיוק זה:';

  @override
  String get codesDiffer => 'הקודים שונים';

  @override
  String get later => 'אחר כך';

  @override
  String get codesMatch => 'הקודים תואמים';

  @override
  String joined(String name) {
    return '$name יכול עכשיו לראות ולרשום מנות';
  }

  @override
  String get inviteOtherApp => 'ההזמנה הזאת שייכת לאפליקציית Zero-Trust אחרת';

  @override
  String get inviteInvalid => 'זה לא קישור הזמנה של ZT Meds';

  @override
  String get inviteUsed =>
      'ההזמנה כבר נוצלה, פג תוקפה או בוטלה. אפשר לבקש הזמנה חדשה.';

  @override
  String get joinCodeTitle => 'יש להראות את הקוד הזה למנהל';

  @override
  String get joinCodeBody =>
      'המנהל משווה אותו לקוד שבטלפון שלו ומאשר את הכניסה. הילד יופיע כאן אחרי האישור.';

  @override
  String get done => 'סיום';

  @override
  String get joinIntro =>
      'אפשר להדביק את קישור ההזמנה שקיבלתם, או לסרוק את קוד ה־QR בטלפון של ההורה השני.';

  @override
  String get inviteLink => 'קישור הזמנה';

  @override
  String get scanQr => 'סריקת קוד QR';

  @override
  String get join => 'הצטרפות';

  @override
  String get notSet => 'לא הוגדר';

  @override
  String get medicineList => 'תרופות';

  @override
  String get medicineListHint => 'הרשימה המשפחתית, לשימוש חוזר בין הילדים';

  @override
  String get medicineListEmpty =>
      'תרופות שתוסיפו לטיפולים יופיעו כאן, מוכנות לשימוש חוזר.';

  @override
  String deleteMedicineTitle(String medicine) {
    return 'להסיר את $medicine מהרשימה?';
  }

  @override
  String get deleteMedicineBody => 'טיפולים פעילים שומרים עותק משלהם.';

  @override
  String get edit => 'עריכה';

  @override
  String get disclaimerTitle => 'לא ייעוץ רפואי';

  @override
  String get disclaimerBody1 =>
      'ZT Meds עוזרת לזכור ולתעד את התרופות שהילדים מקבלים. היא לא נותנת ייעוץ רפואי, לא בודקת מינונים ולא בודקת אינטראקציות בין תרופות.';

  @override
  String get disclaimerBody2 =>
      'תמיד יש לפעול לפי ההוראות של הרופא או הרוקח ולפי העלון של התרופה. במקרה של ספק, כדאי לשאול אותם.';

  @override
  String get disclaimerBody3 =>
      'תזכורות עלולות להגיע באיחור או לא להופיע בכלל, למשל כשהטלפון כבוי, במצב חיסכון בסוללה או כשההתראות כבויות. אסור להסתמך על האפליקציה בלבד.';

  @override
  String get disclaimerBody4 => 'במקרה חירום, יש להתקשר למספר החירום המקומי.';

  @override
  String get disclaimerAccept => 'הבנתי';

  @override
  String get newTimesFromTomorrow =>
      'נשמר. השעות החדשות מתחילות מחר, כך שהרישומים של היום נשארים כמו שהם.';

  @override
  String get atLeastOne => 'לפחות 1';

  @override
  String get takePhoto => 'צילום תמונה';

  @override
  String get choosePhoto => 'בחירת תמונה';

  @override
  String get removePhoto => 'הסרה';

  @override
  String get photoFailed => 'לא ניתן היה לקבל את התמונה. אפשר לנסות שוב.';

  @override
  String get charts => 'תרשימים';

  @override
  String chartsFor(String child) {
    return '$child: איך זה הלך';
  }

  @override
  String lastDays(int days) {
    return '$days ימים';
  }

  @override
  String get chartsEmpty =>
      'עדיין אין מה להציג לתקופה הזאת. התרשימים מתמלאים ככל שנרשמות מנות.';

  @override
  String get plannedDosesPerDay => 'מנות מתוכננות ליום';

  @override
  String get byTreatment => 'לפי טיפול';

  @override
  String get asNeededGiven => 'מנות לפי הצורך שניתנו';

  @override
  String asNeededSummary(int given, int most) {
    String _temp0 = intl.Intl.pluralLogic(
      given,
      locale: localeName,
      other: 'ניתן $given פעמים',
      one: 'ניתן פעם אחת',
    );
    return '$_temp0, הכי הרבה ביום: $most';
  }

  @override
  String get chartsNote =>
      'חושב בטלפון הזה מהרישומים שכולם רשמו. מנות שעוד לא הגיע זמנן היום לא נספרות.';

  @override
  String get noPlannedDosesYet =>
      'עדיין לא הגיע זמנה של אף מנה מתוכננת בתקופה הזאת';

  @override
  String plannedGivenShare(int given, int total) {
    return 'ניתנו $given מתוך $total מנות מתוכננות';
  }

  @override
  String dayBarLabel(String day, int given, int missed, int skipped) {
    return '$day: $given ניתנו, $missed הוחמצו, $skipped דולגו';
  }

  @override
  String asNeededDayLabel(String day, int count) {
    return '$day: $count מנות לפי הצורך';
  }

  @override
  String missedCount(int count) {
    return '$count הוחמצו';
  }

  @override
  String skippedCount(int count) {
    return '$count דולגו';
  }

  @override
  String givenTwiceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ניתנו פעמיים',
      one: '1 ניתנה פעמיים',
    );
    return '$_temp0';
  }

  @override
  String get byTreatmentHint => 'הקשה על תרופה מציגה את כל המנות כלוח שנה.';

  @override
  String get timeline => 'ציר זמן';

  @override
  String get timelineHint =>
      'כל התרופות יחד, היום החדש ביותר ראשון. הקשה על מנה מציגה פרטים.';

  @override
  String gridIntro(String child) {
    return 'השורות הן ימים והעמודות הן שעות המנות, לפי אזור הזמן של $child. הקשה על מנה מראה מי נתן אותה ומתי.';
  }

  @override
  String cellLabel(String day, String time, String status) {
    return '$day, $time: $status';
  }

  @override
  String get familyOverview => 'משפחה';

  @override
  String lastSevenDays(String percent) {
    return '7 הימים האחרונים: $percent';
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
    return '$dose ב־$time';
  }

  @override
  String reminderFollowUpTitle(String child, String medicine) {
    return 'עדיין ממתין: $medicine עבור $child';
  }

  @override
  String reminderFollowUpBody(String time) {
    return 'תוכנן ל־$time ועדיין לא נרשם.';
  }

  @override
  String reminderMissedTitle(String child, String medicine) {
    return 'לא נרשם: $medicine עבור $child';
  }

  @override
  String reminderMissedBody(String time) {
    return 'המנה של $time לא נרשמה. כדאי לפתוח את ZT Meds ולבדוק לפני שנותנים אותה.';
  }

  @override
  String reminderLastDayTitle(String child, String medicine) {
    return 'יום אחרון של $medicine עבור $child';
  }

  @override
  String get reminderLastDayBody => 'היום הוא היום האחרון של הטיפול.';

  @override
  String get reminderPrivateTitle => 'תזכורת לתרופה';

  @override
  String get reminderPrivateBody => 'אפשר לפתוח את ZT Meds כדי לראות איזו מנה.';

  @override
  String get reminderChannel => 'תזכורות למנות';

  @override
  String get reminderChannelHint =>
      'כשמגיע הזמן של מנות הילדים או כשהן מוחמצות';

  @override
  String get remindersTitle => 'תזכורות';

  @override
  String get remindersHint => 'כשמגיע זמן מנה, תזכורות חוזרות ומנות שהוחמצו';

  @override
  String get remindersOn => 'תזכורות למנות';

  @override
  String get remindersOnHint => 'בכל שעת מנה מתוכננת';

  @override
  String get followUp => 'תזכורת חוזרת';

  @override
  String get followUpHint => 'שוב, אם המנה עדיין לא נרשמה';

  @override
  String get followUpOff => 'כבוי';

  @override
  String followUpAfter(int minutes) {
    return 'אחרי $minutes דקות';
  }

  @override
  String get missedAlerts => 'התראה על מנה שהוחמצה';

  @override
  String get missedAlertsHint => 'כשמנה עוברת את זמן ה״הוחמץ אחרי״ של הילד';

  @override
  String get lastDayNotice => 'הודעת יום אחרון';

  @override
  String get lastDayNoticeHint => 'ב־9:00 ביום האחרון של הטיפול';

  @override
  String get showNamesInReminders => 'שמות בתזכורות';

  @override
  String get showNamesInRemindersHint =>
      'כבוי: בתזכורות כתוב רק ״תזכורת לתרופה״. מסך הנעילה אף פעם לא מציג את הטקסט.';

  @override
  String get remindersForChildren => 'תזכורות עבור';

  @override
  String get remindersHowTheyWork =>
      'התזכורות מוגדרות בטלפון הזה ולא צריכות אינטרנט. מנה שנרשמה בטלפון אחר מבטלת אותן כאן כשהטלפון הזה מסתנכרן, וזה קורה כש־ZT Meds פתוחה. כל מטפל מגדיר תזכורות משלו.';

  @override
  String get reminderDoseGone => 'המנה הזאת כבר לא מתוכננת.';

  @override
  String get quietHours => 'שעות שקטות';

  @override
  String get quietHoursOff => 'כבוי';

  @override
  String quietHoursRange(String from, String until) {
    return '$from עד $until: תזכורות למנות בלי צליל, בלי תזכורות חוזרות או התראות';
  }

  @override
  String get quietHoursFrom => 'התחלה';

  @override
  String get quietHoursUntil => 'סיום';
}
