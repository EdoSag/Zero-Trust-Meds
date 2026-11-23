import 'package:flutter/foundation.dart';

/// A calendar day with no time or zone (`2026-11-11`). Dose times are wall
/// clock times on such a day in the child's time zone.
@immutable
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.parse(String s) {
    final p = s.split('-');
    return LocalDate(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  factory LocalDate.of(DateTime d) => LocalDate(d.year, d.month, d.day);

  final int year;
  final int month;
  final int day;

  /// Calendar arithmetic in UTC, so a daylight-saving change can't make a
  /// day 23 or 25 hours long here.
  LocalDate addDays(int days) =>
      LocalDate.of(DateTime.utc(year, month, day + days));

  int daysUntil(LocalDate other) => DateTime.utc(
    other.year,
    other.month,
    other.day,
  ).difference(DateTime.utc(year, month, day)).inDays;

  bool isBefore(LocalDate o) => compareTo(o) < 0;
  bool isAfter(LocalDate o) => compareTo(o) > 0;

  @override
  int compareTo(LocalDate o) => year != o.year
      ? year - o.year
      : month != o.month
      ? month - o.month
      : day - o.day;

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// A wall-clock time of day (`08:00`).
@immutable
class TimeOfDose implements Comparable<TimeOfDose> {
  const TimeOfDose(this.hour, this.minute);

  factory TimeOfDose.parse(String s) {
    final p = s.split(':');
    return TimeOfDose(int.parse(p[0]), int.parse(p[1]));
  }

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  @override
  int compareTo(TimeOfDose o) => minutes - o.minutes;

  @override
  bool operator ==(Object other) =>
      other is TimeOfDose && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => minutes;

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Morning, noon, evening, night: how the home screen groups doses.
enum TimeSlot {
  morning,
  noon,
  evening,
  night;

  static TimeSlot of(TimeOfDose t) => t.hour >= 4 && t.hour < 11
      ? morning
      : t.hour >= 11 && t.hour < 16
      ? noon
      : t.hour >= 16 && t.hour < 20
      ? evening
      : night;

  /// The suggested time for each slot when a treatment is set up.
  TimeOfDose get defaultTime => switch (this) {
    morning => const TimeOfDose(8, 0),
    noon => const TimeOfDose(13, 0),
    evening => const TimeOfDose(18, 0),
    night => const TimeOfDose(21, 0),
  };

  /// Default times for 1 to 4 doses a day; more are spread evenly.
  static List<TimeOfDose> defaultsFor(int perDay) => switch (perDay) {
    1 => [morning.defaultTime],
    2 => [morning.defaultTime, evening.defaultTime],
    3 => [morning.defaultTime, noon.defaultTime, night.defaultTime],
    4 => [for (final s in TimeSlot.values) s.defaultTime],
    // Five or more: spread evenly from 07:00 to 22:00.
    _ => [
      for (var i = 0; i < perDay; i++)
        _fromMinutes(420 + (900 * i / (perDay - 1)).round()),
    ],
  };
}

TimeOfDose _fromMinutes(int m) => TimeOfDose(m ~/ 60, m % 60);

/// Whose medicines a profile holds. Stored as `relation` in the profile;
/// profiles from before people other than children could be added have no
/// `relation` and are children.
enum PersonRole {
  self,
  child,
  parent,
  other;

  static PersonRole parse(Object? v) => PersonRole.values.firstWhere(
    (r) => r.name == v,
    orElse: () => PersonRole.child,
  );
}

/// One person whose medicines are tracked: you, a child, a parent or
/// someone else you look after. (Named `Child` because the app began with
/// children; every Z24 space holds one, under the item id `child`.)
@immutable
class Child {
  const Child({
    required this.name,
    required this.timeZone,
    this.birthDate,
    this.color = 0xFFF43F5E,
    this.photo,
    this.missedAfterMinutes = 120,
    this.role = PersonRole.child,
    this.familyCircle,
    this.extra = const {},
  });

  factory Child.fromJson(Map<String, Object?> j) => Child(
    name: j['name'] as String? ?? '',
    timeZone: j['timeZone'] as String? ?? 'UTC',
    birthDate: j['birthDate'] == null
        ? null
        : LocalDate.parse(j['birthDate'] as String),
    color: (j['color'] as num?)?.toInt() ?? 0xFFF43F5E,
    photo: j['photo'] as String?,
    missedAfterMinutes: (j['missedAfterMinutes'] as num?)?.toInt() ?? 120,
    role: PersonRole.parse(j['relation']),
    familyCircle: j['familyCircle'] as String?,
    extra: {
      for (final e in j.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    },
  );

  static const kind = 'child';
  static const itemId = 'child';

  static const _known = {
    'kind',
    'name',
    'timeZone',
    'birthDate',
    'color',
    'photo',
    'missedAfterMinutes',
    'relation',
    'familyCircle',
  };

  final String name;

  /// IANA zone the dose times are in (`Asia/Jerusalem`): 08:00 means 08:00
  /// at home, whatever zone a caregiver's phone is in.
  final String timeZone;
  final LocalDate? birthDate;
  final int color;

  /// Small JPEG, base64. Encrypted with everything else.
  final String? photo;

  /// A dose not logged this long after its time counts as missed.
  final int missedAfterMinutes;

  /// You, a child, a parent or someone else.
  final PersonRole role;

  /// The ZT Family circle (its space id) whose hub shows this person's
  /// doses (S-10, L-2); null when they're shown nowhere else.
  final String? familyCircle;

  /// Fields this version doesn't know (written by a newer version), kept
  /// so that saving here doesn't drop them.
  final Map<String, Object?> extra;

  Child copyWith({
    String? name,
    String? timeZone,
    LocalDate? birthDate,
    int? color,
    String? photo,
    bool clearPhoto = false,
    int? missedAfterMinutes,
    PersonRole? role,
    String? familyCircle,
    bool clearFamilyCircle = false,
    Map<String, Object?>? extra,
  }) => Child(
    name: name ?? this.name,
    timeZone: timeZone ?? this.timeZone,
    birthDate: birthDate ?? this.birthDate,
    color: color ?? this.color,
    photo: clearPhoto ? null : photo ?? this.photo,
    missedAfterMinutes: missedAfterMinutes ?? this.missedAfterMinutes,
    role: role ?? this.role,
    familyCircle: clearFamilyCircle ? null : familyCircle ?? this.familyCircle,
    extra: extra ?? this.extra,
  );

  Map<String, Object?> toJson() => {
    ...extra,
    'kind': kind,
    'name': name,
    'timeZone': timeZone,
    'birthDate': birthDate?.toString(),
    'color': color,
    'photo': photo,
    'missedAfterMinutes': missedAfterMinutes,
    // Left out for children, so profiles look exactly as before to older
    // versions.
    if (role != PersonRole.child) 'relation': role.name,
    if (familyCircle != null) 'familyCircle': familyCircle,
  };
}

enum MedForm {
  liquid,
  tablet,
  capsule,
  drops,
  inhaler,
  cream,
  injection,
  other,
}

/// A medicine in the family's list.
@immutable
class Medication {
  const Medication({
    required this.id,
    required this.name,
    this.form = MedForm.liquid,
    this.amount,
    this.unit = '',
    this.notes = '',
  });

  factory Medication.fromJson(String id, Map<String, Object?> j) => Medication(
    id: id,
    name: j['name'] as String? ?? '',
    form: MedForm.values.asNameMap()[j['form']] ?? MedForm.other,
    amount: (j['amount'] as num?)?.toDouble(),
    unit: j['unit'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );

  static const kind = 'medication';

  final String id;
  final String name;
  final MedForm form;

  /// How much one dose is, in [unit] (5 ml, 1 tablet).
  final double? amount;
  final String unit;

  /// "With food", "Shake well".
  final String notes;

  /// Same medicine, for the reusable list across children.
  String get sameKey =>
      '${name.trim().toLowerCase()}|$amount|$unit|${form.name}';

  /// The same medicine by name, whatever the amount: a one-time dose of
  /// it counts towards an as-needed treatment's gap and daily most.
  bool sameNameAs(Medication other) =>
      name.trim().toLowerCase() == other.name.trim().toLowerCase();

  Map<String, Object?> toJson() => {
    'kind': kind,
    'name': name,
    'form': form.name,
    'amount': amount,
    'unit': unit,
    'notes': notes,
  };
}

/// When a treatment's doses are due.
sealed class DoseSchedule {
  const DoseSchedule();

  factory DoseSchedule.fromJson(Map<String, Object?> j) =>
      j['type'] == 'asNeeded'
      ? AsNeeded(
          minIntervalMinutes: (j['minIntervalMinutes'] as num?)?.toInt() ?? 0,
          maxPer24h: (j['maxPer24h'] as num?)?.toInt(),
        )
      : FixedTimes(
          [
            for (final t in (j['times'] as List? ?? const []))
              TimeOfDose.parse(t as String),
          ]..sort(),
        );

  Map<String, Object?> toJson();
}

/// At set clock times every day.
class FixedTimes extends DoseSchedule {
  const FixedTimes(this.times);
  final List<TimeOfDose> times;

  @override
  Map<String, Object?> toJson() => {
    'type': 'fixed',
    'times': [for (final t in times) t.toString()],
  };
}

/// "As needed" (a fever reducer): no set times, but a minimum gap between
/// doses and an optional most per 24 hours.
class AsNeeded extends DoseSchedule {
  const AsNeeded({required this.minIntervalMinutes, this.maxPer24h});
  final int minIntervalMinutes;
  final int? maxPer24h;

  @override
  Map<String, Object?> toJson() => {
    'type': 'asNeeded',
    'minIntervalMinutes': minIntervalMinutes,
    'maxPer24h': maxPer24h,
  };
}

/// A paused stretch of a treatment: [from] until [until] (open while still
/// paused), as instants.
@immutable
class Pause {
  const Pause(this.from, [this.until]);

  factory Pause.fromJson(Map<String, Object?> j) => Pause(
    DateTime.parse(j['from'] as String),
    j['until'] == null ? null : DateTime.parse(j['until'] as String),
  );

  final DateTime from;
  final DateTime? until;

  bool covers(DateTime t) =>
      !t.isBefore(from) && (until == null || t.isBefore(until!));

  Map<String, Object?> toJson() => {
    'from': from.toUtc().toIso8601String(),
    'until': until?.toUtc().toIso8601String(),
  };
}

/// A course of one medicine for the child: what, when, from when, how long.
@immutable
class Treatment {
  const Treatment({
    required this.id,
    required this.medication,
    required this.schedule,
    required this.startDate,
    this.days,
    this.pauses = const [],
    this.endedOn,
  });

  factory Treatment.fromJson(String id, Map<String, Object?> j) => Treatment(
    id: id,
    medication: Medication.fromJson(
      j['medicationId'] as String? ?? '',
      (j['medication'] as Map).cast<String, Object?>(),
    ),
    schedule: DoseSchedule.fromJson(
      (j['schedule'] as Map).cast<String, Object?>(),
    ),
    startDate: LocalDate.parse(j['startDate'] as String),
    days: (j['days'] as num?)?.toInt(),
    pauses: [
      for (final p in (j['pauses'] as List? ?? const []))
        Pause.fromJson((p as Map).cast<String, Object?>()),
    ],
    endedOn: j['endedOn'] == null
        ? null
        : LocalDate.parse(j['endedOn'] as String),
  );

  static const kind = 'treatment';

  final String id;

  /// A copy of the medicine as it was when the treatment started, so editing
  /// the family list later doesn't rewrite history.
  final Medication medication;
  final DoseSchedule schedule;
  final LocalDate startDate;

  /// Number of days, start day included. Null: until ended (as-needed and
  /// long-term medicines).
  final int? days;
  final List<Pause> pauses;

  /// Ended early: no doses after this day.
  final LocalDate? endedOn;

  /// The last day doses are planned, or null when open-ended.
  LocalDate? get lastDay {
    final planned = days == null ? null : startDate.addDays(days! - 1);
    if (endedOn == null) return planned;
    if (planned == null) return endedOn;
    return endedOn!.isBefore(planned) ? endedOn : planned;
  }

  bool get isPaused => pauses.isNotEmpty && pauses.last.until == null;

  bool pausedAt(DateTime t) => pauses.any((p) => p.covers(t));

  /// Whether [day] is within the treatment (paused days included).
  bool runsOn(LocalDate day) =>
      !day.isBefore(startDate) && (lastDay == null || !day.isAfter(lastDay!));

  /// Past its last day: shown under history.
  bool isFinishedBy(LocalDate today) =>
      lastDay != null && today.isAfter(lastDay!);

  Treatment copyWith({
    DoseSchedule? schedule,
    LocalDate? startDate,
    int? days,
    bool clearDays = false,
    List<Pause>? pauses,
    LocalDate? endedOn,
    Medication? medication,
  }) => Treatment(
    id: id,
    medication: medication ?? this.medication,
    schedule: schedule ?? this.schedule,
    startDate: startDate ?? this.startDate,
    days: clearDays ? null : days ?? this.days,
    pauses: pauses ?? this.pauses,
    endedOn: endedOn ?? this.endedOn,
  );

  Map<String, Object?> toJson() => {
    'kind': kind,
    'medicationId': medication.id,
    'medication': medication.toJson()..remove('kind'),
    'schedule': schedule.toJson(),
    'startDate': startDate.toString(),
    'days': days,
    'pauses': [for (final p in pauses) p.toJson()],
    'endedOn': endedOn?.toString(),
  };
}

enum DoseAction { given, skipped }

/// One caregiver's record of a dose: given (when) or skipped (why).
///
/// A one-time dose (Nurofen once for a fever) belongs to no treatment: its
/// [treatmentId] is empty and it carries its own [medication]. Older app
/// versions read it as a record of a deleted treatment and skip it.
///
/// Every record is its own item, never merged into another, so two
/// caregivers who both give the same dose (offline, at the same time) leave
/// two records, and the app says "given twice" instead of hiding one.
@immutable
class DoseLog {
  const DoseLog({
    required this.id,
    required this.treatmentId,
    required this.action,
    required this.at,
    required this.byUserId,
    this.slotDate,
    this.slotTime,
    this.reason = '',
    this.loggedAt,
    this.medication,
  });

  factory DoseLog.fromJson(String id, Map<String, Object?> j) => DoseLog(
    id: id,
    treatmentId: j['treatmentId'] as String,
    action: j['action'] == 'skipped' ? DoseAction.skipped : DoseAction.given,
    at: DateTime.parse(j['at'] as String).toUtc(),
    byUserId: j['by'] as String? ?? '',
    slotDate: j['slotDate'] == null
        ? null
        : LocalDate.parse(j['slotDate'] as String),
    slotTime: j['slotTime'] == null
        ? null
        : TimeOfDose.parse(j['slotTime'] as String),
    reason: j['reason'] as String? ?? '',
    loggedAt: j['loggedAt'] == null
        ? null
        : DateTime.parse(j['loggedAt'] as String).toUtc(),
    medication: j['medication'] is Map
        ? Medication.fromJson(
            j['medicationId'] as String? ?? '',
            (j['medication'] as Map).cast<String, Object?>(),
          )
        : null,
  );

  static const kind = 'dose';

  final String id;
  final String treatmentId;
  final DoseAction action;

  /// When it was given (or skipped), UTC. Caregivers may correct it.
  final DateTime at;

  /// Who logged it.
  final String byUserId;

  /// The planned dose this answers (day and time in the child's zone);
  /// null for an as-needed dose.
  final LocalDate? slotDate;
  final TimeOfDose? slotTime;

  /// Why it was skipped, or for a one-time dose why it was given ("Fever").
  final String reason;

  /// When the record was made, UTC (differs from [at] when back-dated).
  final DateTime? loggedAt;

  /// The medicine of a one-time dose, as it was given. Null for a dose of
  /// a treatment (the treatment has the medicine).
  final Medication? medication;

  /// Given once, outside any treatment.
  bool get isOneTime => treatmentId.isEmpty && medication != null;

  bool get given => action == DoseAction.given;

  bool answers(String treatmentId, LocalDate date, TimeOfDose time) =>
      this.treatmentId == treatmentId && slotDate == date && slotTime == time;

  DoseLog copyWith({DateTime? at, DoseAction? action, String? reason}) =>
      DoseLog(
        id: id,
        treatmentId: treatmentId,
        action: action ?? this.action,
        at: at ?? this.at,
        byUserId: byUserId,
        slotDate: slotDate,
        slotTime: slotTime,
        reason: reason ?? this.reason,
        loggedAt: loggedAt,
        medication: medication,
      );

  Map<String, Object?> toJson() => {
    'kind': kind,
    'treatmentId': treatmentId,
    'action': action.name,
    'at': at.toUtc().toIso8601String(),
    'by': byUserId,
    'slotDate': slotDate?.toString(),
    'slotTime': slotTime?.toString(),
    'reason': reason,
    'loggedAt': loggedAt?.toUtc().toIso8601String(),
    if (medication != null) ...{
      'medicationId': medication!.id,
      'medication': medication!.toJson()..remove('kind'),
    },
  };
}

/// How much of a medicine is left, as counted by a caregiver at
/// [countedAt]. Doses given after that are taken off it as they're logged,
/// so nobody has to change the number after each dose. Any caregiver may
/// count (it isn't admin-only); the newest count of a medicine wins.
///
/// Stored as its own item (`stock/<uuid>`), with the medicine's name inside
/// the encrypted record and not in the item id.
@immutable
class MedStock {
  const MedStock({
    required this.id,
    required this.medicine,
    required this.count,
    required this.countedAt,
    this.warnDays = 7,
    this.byUserId = '',
  });

  factory MedStock.fromJson(String id, Map<String, Object?> j) => MedStock(
    id: id,
    medicine: j['medicine'] as String? ?? '',
    count: (j['count'] as num?)?.toDouble() ?? 0,
    countedAt: DateTime.parse(j['countedAt'] as String).toUtc(),
    warnDays: (j['warnDays'] as num?)?.toInt() ?? 7,
    byUserId: j['by'] as String? ?? '',
  );

  static const kind = 'stock';
  static const prefix = 'stock/';

  /// Choices for "remind me to order more", in days before it runs out.
  static const warnChoices = [3, 5, 7, 10, 14];

  final String id;

  /// The medicine's name; matched without case, like the one-time dose
  /// checks, so a course edited into a new treatment keeps its count.
  final String medicine;

  /// In the medicine's unit (tablets, ml) when it has a dose amount, else
  /// in doses.
  final double count;
  final DateTime countedAt;

  /// "Order more" this many days before it runs out.
  final int warnDays;
  final String byUserId;

  bool isFor(String name) =>
      medicine.trim().toLowerCase() == name.trim().toLowerCase();

  Map<String, Object?> toJson() => {
    'kind': kind,
    'medicine': medicine,
    'count': count,
    'countedAt': countedAt.toUtc().toIso8601String(),
    'warnDays': warnDays,
    'by': byUserId,
  };
}

/// Someone to call in an emergency.
@immutable
class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});

  factory EmergencyContact.fromJson(Map<String, Object?> j) => EmergencyContact(
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
  );

  final String name;
  final String phone;

  Map<String, Object?> toJson() => {'name': name, 'phone': phone};
}

/// A person's Medical ID: what a doctor or paramedic should know at once.
/// One per space (item id `medical_id`), written by admins only, encrypted
/// like everything else. Current medicines aren't stored here: the card
/// shows the running treatments.
@immutable
class MedicalId {
  const MedicalId({
    this.bloodType = '',
    this.allergies = const [],
    this.conditions = const [],
    this.notes = '',
    this.contacts = const [],
    this.extra = const {},
  });

  factory MedicalId.fromJson(Map<String, Object?> j) => MedicalId(
    bloodType: j['bloodType'] as String? ?? '',
    allergies: _strings(j['allergies']),
    conditions: _strings(j['conditions']),
    notes: j['notes'] as String? ?? '',
    contacts: [
      for (final c in (j['contacts'] as List? ?? const []))
        if (c is Map) EmergencyContact.fromJson(c.cast<String, Object?>()),
    ],
    extra: {
      for (final e in j.entries)
        if (!_known.contains(e.key)) e.key: e.value,
    },
  );

  static List<String> _strings(Object? v) => [
    for (final s in (v as List? ?? const []))
      if (s is String && s.trim().isNotEmpty) s.trim(),
  ];

  static const kind = 'medical_id';
  static const itemId = 'medical_id';
  static const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _known = {
    'kind',
    'bloodType',
    'allergies',
    'conditions',
    'notes',
    'contacts',
  };

  /// "A+" etc., or empty when unknown.
  final String bloodType;
  final List<String> allergies;
  final List<String> conditions;

  /// "Has a pacemaker", "Carries an EpiPen in the blue bag".
  final String notes;
  final List<EmergencyContact> contacts;

  /// Fields from a newer version, kept on save.
  final Map<String, Object?> extra;

  bool get isEmpty =>
      bloodType.isEmpty &&
      allergies.isEmpty &&
      conditions.isEmpty &&
      notes.trim().isEmpty &&
      contacts.isEmpty;

  Map<String, Object?> toJson() => {
    ...extra,
    'kind': kind,
    'bloodType': bloodType,
    'allergies': allergies,
    'conditions': conditions,
    'notes': notes,
    'contacts': [for (final c in contacts) c.toJson()],
  };
}
