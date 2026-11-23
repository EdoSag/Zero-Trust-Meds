import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_trust_core/zero_trust_core.dart';

import '../logic/dose_logic.dart';
import '../logic/stock.dart';
import '../model/models.dart';
import 'family_circle.dart';

/// Bumped after every local write, so screens update at once even offline
/// (the sync status, which also refreshes them, changes only on sync).
final medsRevisionProvider = NotifierProvider<MedsRevision, int>(
  MedsRevision.new,
);

class MedsRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

/// One child: their shared space, profile, treatments and dose records.
class ChildData {
  ChildData({
    required this.entry,
    required this.child,
    required this.medications,
    required this.treatments,
    required this.logs,
    required this.zone,
    this.stocks = const [],
    this.medicalId = const MedicalId(),
  });

  final SpaceEntry entry;
  final Child child;

  /// Medicines saved in this child's space.
  final List<Medication> medications;
  final List<Treatment> treatments;
  final List<DoseLog> logs;
  final tz.Location zone;

  /// Supply counts (see [MedStock]); possibly several per medicine, when
  /// two caregivers counted at once. The newest one counts.
  final List<MedStock> stocks;

  /// Allergies, conditions, blood type and emergency contacts.
  final MedicalId medicalId;

  String get spaceId => entry.info.id;
  SharedSpace get space => entry.space!;
  bool get isAdmin => space.isAdmin;
  List<SpaceMember> get caregivers => space.members;
  Duration get missedAfter => Duration(minutes: child.missedAfterMinutes);

  /// Who logged a dose, by the name they gave when joining.
  String nameOf(String userId) {
    final m = space.roster[userId];
    return m == null || m.name.isEmpty ? '?' : m.name;
  }

  LocalDate today(DateTime nowUtc) => ChildClock.today(zone, nowUtc);

  /// Treatments still running today (paused ones included).
  List<Treatment> active(DateTime nowUtc) {
    final day = today(nowUtc);
    return [
      for (final t in treatments)
        if (!t.isFinishedBy(day)) t,
    ];
  }

  /// Finished or ended treatments, newest first.
  List<Treatment> history(DateTime nowUtc) {
    final day = today(nowUtc);
    return [
      for (final t in treatments)
        if (t.isFinishedBy(day)) t,
    ]..sort((a, b) => b.lastDay!.compareTo(a.lastDay!));
  }

  List<DoseLog> logsOf(String treatmentId) => [
    for (final l in logs)
      if (l.treatmentId == treatmentId) l,
  ];

  /// The planned doses of [day] with their status, by time.
  List<DoseStatus> doses(LocalDate day, DateTime nowUtc) {
    final out = <DoseStatus>[];
    for (final t in treatments) {
      for (final d in ChildClock.planned(t, zone, day, day)) {
        out.add(
          DoseRules.statusOf(d, logsOf(t.id), nowUtc, missedAfter: missedAfter),
        );
      }
    }
    out.sort((a, b) => a.dose.at.compareTo(b.dose.at));
    return out;
  }

  /// Every planned dose of [t] up to today, with its status.
  List<DoseStatus> dosesOf(
    Treatment t,
    DateTime nowUtc, {
    LocalDate? from,
    LocalDate? to,
  }) {
    final end = to ?? today(nowUtc);
    final logs = logsOf(t.id);
    return [
      for (final d in ChildClock.planned(t, zone, from ?? t.startDate, end))
        DoseRules.statusOf(d, logs, nowUtc, missedAfter: missedAfter),
    ];
  }

  /// What [DoseGuard] weighs before giving [t]: its own records and
  /// one-time doses of the same medicine.
  List<DoseLog> guardLogsOf(Treatment t) => [
    for (final l in logs)
      if (l.treatmentId == t.id ||
          (l.isOneTime && l.medication!.sameNameAs(t.medication)))
        l,
  ];

  /// One-time doses (given outside any treatment), newest first.
  List<DoseLog> get oneTimeLogs => [
    for (final l in logs)
      if (l.isOneTime) l,
  ]..sort((a, b) => b.at.compareTo(a.at));

  /// One-time doses given on [day] in the child's calendar, by time.
  List<DoseLog> oneTimeOn(LocalDate day) => [
    for (final l in oneTimeLogs.reversed)
      if (today(l.at) == day) l,
  ];

  /// The medicine a record is about: its own for a one-time dose, else its
  /// treatment's. Null when the treatment was deleted.
  Medication? medicineOf(DoseLog log) =>
      log.medication ??
      treatments.where((t) => t.id == log.treatmentId).firstOrNull?.medication;

  /// The newest dose of a medicine called [name] given in the 24 hours
  /// before [atUtc], one-time or from a treatment. Shown before logging a
  /// one-time dose so nobody doubles up by accident.
  DoseLog? lastGivenNamed(String name, DateTime atUtc) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    DoseLog? best;
    for (final l in logs) {
      if (!l.given) continue;
      if (medicineOf(l)?.name.trim().toLowerCase() != key) continue;
      if (l.at.isAfter(atUtc.add(const Duration(minutes: 1))) ||
          atUtc.difference(l.at) > const Duration(hours: 24)) {
        continue;
      }
      if (best == null || l.at.isAfter(best.at)) best = l;
    }
    return best;
  }

  /// The newest count of the medicine called [name], if anyone counted it.
  MedStock? stockNamed(String name) {
    MedStock? best;
    for (final s in stocks) {
      if (!s.isFor(name)) continue;
      if (best == null || s.countedAt.isAfter(best.countedAt)) best = s;
    }
    return best;
  }

  /// How much of the medicine called [name] is left and when it runs out;
  /// null when nobody counted it.
  StockStatus? stockOf(String name, DateTime nowUtc) {
    final stock = stockNamed(name);
    if (stock == null) return null;
    final key = name.trim().toLowerCase();
    final day = today(nowUtc);
    var planned = 0.0;
    for (final t in active(nowUtc)) {
      if (t.medication.name.trim().toLowerCase() != key) continue;
      if (t.isPaused || !t.runsOn(day)) continue;
      final s = t.schedule;
      if (s is FixedTimes) {
        planned += s.times.length * (t.medication.amount ?? 1);
      }
    }
    return StockMath.of(
      stock: stock,
      given: [
        for (final l in logs)
          if (l.given)
            if (medicineOf(l) case final m?
                when m.name.trim().toLowerCase() == key)
              (at: l.at, amount: m.amount ?? 1),
      ],
      plannedPerDay: planned,
      nowUtc: nowUtc,
      today: day,
    );
  }

  /// As-needed treatments running today.
  List<Treatment> asNeeded(DateTime nowUtc) => [
    for (final t in active(nowUtc))
      if (t.schedule is AsNeeded && !t.isPaused && t.runsOn(today(nowUtc))) t,
  ];
}

/// A child's space this account joined but an admin hasn't confirmed yet
/// (or this device can't vouch for it yet).
class PendingChild {
  const PendingChild(this.entry);
  final SpaceEntry entry;
  String get spaceId => entry.info.id;
  String? get code => entry.joinCode;
}

class FamilyData {
  const FamilyData({
    this.children = const [],
    this.pending = const [],
    this.ready = false,
    this.loading = true,
    this.error,
  });

  final List<ChildData> children;
  final List<PendingChild> pending;

  /// Spaces can be created and joined (the vault is open).
  final bool ready;
  final bool loading;
  final Object? error;

  ChildData? child(String spaceId) {
    for (final c in children) {
      if (c.spaceId == spaceId) return c;
    }
    return null;
  }

  /// The family's medicine list: every medicine in the children this
  /// account manages, once each.
  List<Medication> get medications {
    final seen = <String, Medication>{};
    for (final c in children) {
      if (!c.isAdmin) continue;
      for (final m in c.medications) {
        seen.putIfAbsent(m.sameKey, () => m);
      }
    }
    return seen.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}

tz.Location zoneOf(String name) {
  try {
    return tz.getLocation(name);
  } on Object {
    return tz.UTC;
  }
}

/// Reads one space's items into a [ChildData]; null when the space has no
/// child profile yet (just created, or not yet synced here).
Future<ChildData?> readChild(SpaceEntry e) async {
  final space = e.space;
  if (space == null) return null;
  Child? child;
  final meds = <Medication>[];
  final treatments = <Treatment>[];
  final logs = <DoseLog>[];
  final stocks = <MedStock>[];
  var medicalId = const MedicalId();
  for (final item in await space.store.all()) {
    final j = item.json;
    if (item.deleted || j == null) continue;
    try {
      switch (j['kind']) {
        case Child.kind:
          child = Child.fromJson(j);
        case Medication.kind:
          meds.add(Medication.fromJson(item.itemId, j));
        case Treatment.kind:
          treatments.add(Treatment.fromJson(item.itemId, j));
        case DoseLog.kind:
          logs.add(DoseLog.fromJson(item.itemId, j));
        case MedStock.kind:
          stocks.add(MedStock.fromJson(item.itemId, j));
        case MedicalId.kind:
          medicalId = MedicalId.fromJson(j);
      }
    } on Object {
      // A record from a newer version of the app: skipped, not fatal.
    }
  }
  if (child == null) return null;
  return ChildData(
    entry: e,
    child: child,
    medications: meds,
    treatments: treatments,
    logs: logs,
    zone: zoneOf(child.timeZone),
    stocks: stocks,
    medicalId: medicalId,
  );
}

final familyProvider = FutureProvider<FamilyData>((ref) async {
  ref.watch(medsRevisionProvider);
  final spaces = ref.watch(ztSpacesProvider);
  final children = <ChildData>[];
  final pending = <PendingChild>[];
  for (final e in spaces.entries) {
    if (e.space == null) {
      pending.add(PendingChild(e));
      continue;
    }
    final c = await readChild(e);
    if (c != null) {
      children.add(c);
    } else if (!e.space!.isAdmin) {
      // Confirmed, but the profile hasn't arrived yet.
      pending.add(PendingChild(e));
    }
  }
  children.sort(
    (a, b) => a.child.name.toLowerCase().compareTo(b.child.name.toLowerCase()),
  );
  return FamilyData(
    children: children,
    pending: pending,
    ready: spaces.ready,
    loading: spaces.loading,
    error: spaces.error,
  );
});

/// What this account says about itself: the name other caregivers see, and
/// that it read the "not medical advice" notice. Kept encrypted in the
/// app's own vault, so all the account's phones share it.
class MeProfile {
  const MeProfile({this.name = '', this.disclaimerAccepted = false});

  factory MeProfile.fromJson(Map<String, Object?>? j) => MeProfile(
    name: j?['name'] as String? ?? '',
    disclaimerAccepted: j?['disclaimerAccepted'] as bool? ?? false,
  );

  static const itemId = 'meds.me';

  final String name;
  final bool disclaimerAccepted;

  Map<String, Object?> toJson() => {
    'kind': 'meds.me',
    'name': name,
    'disclaimerAccepted': disclaimerAccepted,
  };
}

final meProvider = FutureProvider<MeProfile>((ref) async {
  ref.watch(medsRevisionProvider);
  ref.watch(ztSyncControllerProvider);
  final store = await ref.watch(ztLocalStoreProvider.future);
  final item = await store.get(MeProfile.itemId);
  return MeProfile.fromJson(item == null || item.deleted ? null : item.json);
});

/// Every change Meds makes, as one place to read the rules from.
class MedsActions {
  MedsActions(this.ref);
  final Ref ref;

  SpacesController get _spaces => ref.read(ztSpacesProvider.notifier);
  String get myUserId => ref.read(accountServiceProvider).currentUserId ?? '';

  void _changed() => ref.read(medsRevisionProvider.notifier).bump();

  Future<void> saveMe(MeProfile me) async {
    await ref
        .read(ztSyncControllerProvider.notifier)
        .save(MeProfile.itemId, me.toJson());
    _changed();
  }

  /// A new child gets a new space, with this account as its admin.
  Future<String> addChild(Child child, {required String myName}) async {
    final space = await _spaces.create(myName: myName);
    await _spaces.save(space.id, Child.itemId, child.toJson());
    _changed();
    return space.id;
  }

  Future<void> saveChild(String spaceId, Child child) async {
    await _spaces.save(spaceId, Child.itemId, child.toJson());
    _changed();
  }

  Future<void> saveMedicalId(String spaceId, MedicalId id) async {
    await _spaces.save(spaceId, MedicalId.itemId, id.toJson());
    _changed();
  }

  /// Deletes the child and every record about them, for every caregiver.
  Future<void> deleteChild(String spaceId) async {
    // Shown in a ZT Family circle: its doses leave the hub first.
    final family = ref.read(familyProvider).value;
    final circle = family?.child(spaceId)?.child.familyCircle;
    if (circle != null) {
      try {
        await FamilyCircleDoses.removePerson(
          ref.read(ztFamilySpacesProvider.notifier),
          ref.read(ztFamilySpacesProvider),
          circle,
          spaceId,
        );
      } on Object {
        // Offline or not in the circle any more: the copies go once they
        // are past (FamilyCircleDoses.stale).
      }
    }
    await _spaces.deleteSpace(spaceId);
    _changed();
  }

  Future<void> leaveChild(String spaceId) async {
    await _spaces.leave(spaceId);
    _changed();
  }

  /// Saves [m] in the child's space, reusing the same medicine there when
  /// it already exists. Returns the saved medicine.
  Future<Medication> saveMedication(ChildData c, Medication m) async {
    var id = m.id;
    if (id.isEmpty || !c.medications.any((x) => x.id == id)) {
      final same = c.medications.where((x) => x.sameKey == m.sameKey);
      id = same.isNotEmpty ? same.first.id : newUuid();
    }
    final saved = Medication(
      id: id,
      name: m.name.trim(),
      form: m.form,
      amount: m.amount,
      unit: m.unit,
      notes: m.notes,
    );
    await _spaces.save(c.spaceId, id, saved.toJson());
    _changed();
    return saved;
  }

  /// Changes a medicine in every child this account manages, so the
  /// family list stays one list. Running treatments keep their copy.
  Future<void> updateMedicationEverywhere(
    FamilyData family,
    Medication old,
    Medication updated,
  ) async {
    for (final c in family.children) {
      if (!c.isAdmin) continue;
      for (final m in c.medications) {
        if (m.sameKey != old.sameKey) continue;
        await _spaces.save(
          c.spaceId,
          m.id,
          Medication(
            id: m.id,
            name: updated.name.trim(),
            form: updated.form,
            amount: updated.amount,
            unit: updated.unit,
            notes: updated.notes,
          ).toJson(),
        );
      }
    }
    _changed();
  }

  Future<void> deleteMedicationEverywhere(
    FamilyData family,
    Medication med,
  ) async {
    for (final c in family.children) {
      if (!c.isAdmin) continue;
      for (final m in c.medications) {
        if (m.sameKey == med.sameKey) await _spaces.delete(c.spaceId, m.id);
      }
    }
    _changed();
  }

  /// Saves a new or edited treatment, and says what became of new times
  /// (see [TreatmentEdit.plan]).
  Future<TimesEdit> saveTreatment(
    ChildData c,
    Treatment t,
    LocalDate today,
  ) async {
    final old = c.treatments.where((x) => x.id == t.id).firstOrNull;
    final plan = TreatmentEdit.plan(
      old: old,
      edited: t,
      today: today,
      hasLogs: old != null && c.logsOf(old.id).isNotEmpty,
    );
    for (final x in plan) {
      await _saveOne(c, x);
    }
    if (plan.length > 1) return TimesEdit.fromTomorrow;
    return identical(plan.single, t) ? TimesEdit.saved : TimesEdit.kept;
  }

  Future<String> _saveOne(ChildData c, Treatment t) async {
    final id = t.id.isEmpty ? newUuid() : t.id;
    final med = await saveMedication(c, t.medication);
    final saved = Treatment(
      id: id,
      medication: med,
      schedule: t.schedule,
      startDate: t.startDate,
      days: t.days,
      pauses: t.pauses,
      endedOn: t.endedOn,
    );
    await _spaces.save(c.spaceId, id, saved.toJson());
    _changed();
    return id;
  }

  Future<void> pauseTreatment(ChildData c, Treatment t, DateTime nowUtc) =>
      _put(c, t.copyWith(pauses: [...t.pauses, Pause(nowUtc)]));

  Future<void> resumeTreatment(ChildData c, Treatment t, DateTime nowUtc) {
    if (!t.isPaused) return Future.value();
    final pauses = [...t.pauses];
    pauses[pauses.length - 1] = Pause(pauses.last.from, nowUtc);
    return _put(c, t.copyWith(pauses: pauses));
  }

  /// Ends the treatment after today's doses (it moves to history tomorrow).
  Future<void> endTreatment(ChildData c, Treatment t, LocalDate lastDay) =>
      _put(c, t.copyWith(endedOn: lastDay));

  Future<void> deleteTreatment(ChildData c, Treatment t) async {
    await _spaces.delete(c.spaceId, t.id);
    for (final l in c.logsOf(t.id)) {
      await _spaces.delete(c.spaceId, l.id);
    }
    _changed();
  }

  Future<void> _put(ChildData c, Treatment t) async {
    await _spaces.save(c.spaceId, t.id, t.toJson());
    _changed();
  }

  /// Records a dose as given (or skipped). Each record is a new item, so a
  /// second caregiver's record never overwrites the first.
  Future<DoseLog> logDose(
    ChildData c, {
    required Treatment treatment,
    required DateTime at,
    PlannedDose? slot,
    DoseAction action = DoseAction.given,
    String reason = '',
  }) async {
    final log = DoseLog(
      id: 'dose/${newUuid()}',
      treatmentId: treatment.id,
      action: action,
      at: at.toUtc(),
      byUserId: myUserId,
      slotDate: slot?.date,
      slotTime: slot?.time,
      reason: reason,
      loggedAt: DateTime.now().toUtc(),
    );
    await _spaces.save(c.spaceId, log.id, log.toJson());
    _changed();
    unawaited(_spaces.syncNow(c.spaceId).catchError((Object _) {}));
    return log;
  }

  /// Records a one-time dose: a medicine given once, outside any
  /// treatment. Any caregiver may log one.
  Future<DoseLog> logOneTimeDose(
    ChildData c, {
    required Medication medication,
    required DateTime at,
    String reason = '',
  }) async {
    final log = DoseLog(
      id: 'dose/${newUuid()}',
      treatmentId: '',
      action: DoseAction.given,
      at: at.toUtc(),
      byUserId: myUserId,
      reason: reason.trim(),
      loggedAt: DateTime.now().toUtc(),
      medication: Medication(
        id: medication.id,
        name: medication.name.trim(),
        form: medication.form,
        amount: medication.amount,
        unit: medication.unit.trim(),
        notes: medication.notes,
      ),
    );
    await _spaces.save(c.spaceId, log.id, log.toJson());
    _changed();
    unawaited(_spaces.syncNow(c.spaceId).catchError((Object _) {}));
    return log;
  }

  Future<void> updateLog(ChildData c, DoseLog log) async {
    await _spaces.save(c.spaceId, log.id, log.toJson());
    _changed();
  }

  /// Records how much of a medicine is left now. Updates the newest count
  /// of it when there is one, so the space keeps one record per medicine.
  Future<void> countStock(
    ChildData c, {
    required String medicine,
    required double count,
    required int warnDays,
  }) async {
    final old = c.stockNamed(medicine);
    final stock = MedStock(
      id: old?.id ?? '${MedStock.prefix}${newUuid()}',
      medicine: medicine.trim(),
      count: count,
      countedAt: DateTime.now().toUtc(),
      warnDays: warnDays,
      byUserId: myUserId,
    );
    await _spaces.save(c.spaceId, stock.id, stock.toJson());
    _changed();
    unawaited(_spaces.syncNow(c.spaceId).catchError((Object _) {}));
  }

  /// Stops counting a medicine: every count of it is deleted.
  Future<void> stopCounting(ChildData c, String medicine) async {
    for (final s in c.stocks) {
      if (s.isFor(medicine)) await _spaces.delete(c.spaceId, s.id);
    }
    _changed();
  }

  /// Undo: the record is deleted for everyone.
  Future<void> deleteLog(ChildData c, DoseLog log) async {
    await _spaces.delete(c.spaceId, log.id);
    _changed();
  }
}

final medsActionsProvider = Provider<MedsActions>(MedsActions.new);
