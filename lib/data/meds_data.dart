import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_trust_core/zero_trust_core.dart';

import '../logic/dose_logic.dart';
import '../model/models.dart';

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
  });

  final SpaceEntry entry;
  final Child child;

  /// Medicines saved in this child's space.
  final List<Medication> medications;
  final List<Treatment> treatments;
  final List<DoseLog> logs;
  final tz.Location zone;

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

  /// As-needed treatments running today.
  List<Treatment> asNeeded(DateTime nowUtc) => [
    for (final t in active(nowUtc))
      if (t.schedule is AsNeeded && !t.isPaused) t,
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

  /// Deletes the child and every record about them, for every caregiver.
  Future<void> deleteChild(String spaceId) async {
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

  Future<String> saveTreatment(ChildData c, Treatment t) async {
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

  Future<void> updateLog(ChildData c, DoseLog log) async {
    await _spaces.save(c.spaceId, log.id, log.toJson());
    _changed();
  }

  /// Undo: the record is deleted for everyone.
  Future<void> deleteLog(ChildData c, DoseLog log) async {
    await _spaces.delete(c.spaceId, log.id);
    _changed();
  }
}

final medsActionsProvider = Provider<MedsActions>(MedsActions.new);
