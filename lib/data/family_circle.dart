import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../logic/dose_logic.dart';
import '../model/models.dart';
import 'meds_data.dart';

/// S-10 and L-2: a person's doses in the ZT Family circle, for its family
/// hub ("today's medicines"). Only for people whose admin chose a circle
/// ([Child.familyCircle]); everyone in that circle then sees the medicine
/// names and times, so it is off until asked for.
///
/// The circle gets a read-only copy: one item per dose of today and
/// tomorrow (in the person's zone) and per one-time dose given today, id
/// `meds/dose/<person space id>.<key>`, kind `meds.dose`, with the common
/// [ZtFamilySummary] (`at` the dose time, `done` given). Records stay in the
/// person's own space; any caregiver's phone in the circle refreshes the
/// copy, and past days, stopped people and deleted doses are removed.
abstract final class FamilyCircleDoses {
  static const app = 'meds';
  static const kind = 'dose';
  static const fullKind = 'meds.dose';
  static const _prefix = '$app/$kind/';

  static String idFor(String spaceId, String key) =>
      ZtFamilySpace.itemId(app, kind, '$spaceId.$key');

  /// The person (Meds space id) an item of the circle is about, or null
  /// when it isn't a Meds dose.
  static String? spaceOf(String itemId) {
    if (!itemId.startsWith(_prefix)) return null;
    final rest = itemId.substring(_prefix.length);
    final dot = rest.indexOf('.');
    return dot <= 0 ? null : rest.substring(0, dot);
  }

  static String _amount(Medication m) {
    final a = m.amount;
    if (a == null) return '';
    final n = a == a.roundToDouble() ? a.toInt().toString() : a.toString();
    return m.unit.trim().isEmpty ? n : '$n ${m.unit.trim()}';
  }

  static Map<String, Object?> _item(
    ChildData c,
    Medication m,
    DateTime at,
    bool done,
  ) {
    final amount = _amount(m);
    return ZtFamilySummary(
      title: [
        '${c.child.name}: ${m.name.trim()}',
        if (amount.isNotEmpty) amount,
      ].join(' '),
      kind: fullKind,
      at: at,
      done: done,
    ).addTo({
      'kind': fullKind,
      'person': c.child.name,
      'medicine': m.name.trim(),
      if (amount.isNotEmpty) 'amount': amount,
    });
  }

  /// What the circle should hold for [c] now; empty when [c] isn't shown
  /// in a circle.
  static Map<String, Map<String, Object?>> itemsFor(
    ChildData c,
    DateTime nowUtc,
  ) {
    if (c.child.familyCircle == null) return const {};
    final today = c.today(nowUtc);
    final out = <String, Map<String, Object?>>{};
    for (final day in [today, today.addDays(1)]) {
      for (final d in c.doses(day, nowUtc)) {
        if (d.state == DoseState.paused) continue;
        final p = d.dose;
        final t = p.time;
        final key =
            '${p.treatment.id}.${p.date}.'
            '${t.hour.toString().padLeft(2, '0')}${t.minute.toString().padLeft(2, '0')}';
        out[idFor(c.spaceId, key)] = _item(
          c,
          p.treatment.medication,
          p.at,
          d.state == DoseState.given,
        );
      }
    }
    for (final log in c.oneTimeOn(today)) {
      final id = log.id.startsWith('dose/') ? log.id.substring(5) : log.id;
      out[idFor(c.spaceId, 'once.$id')] = _item(
        c,
        log.medication!,
        log.at,
        true,
      );
    }
    return out;
  }

  /// What to save and delete in [circleId]: [want] for the people of this
  /// phone shown there, compared with what the circle holds. Doses of people
  /// this phone knows ([mine], Meds space ids) that aren't wanted any more
  /// go; other people's are left to their own caregivers.
  static ({Map<String, Map<String, Object?>> save, Set<String> delete}) diff({
    required Iterable<LocalItem> existing,
    required Map<String, Map<String, Object?>> want,
    required Set<String> mine,
  }) {
    final have = <String, Map<String, Object?>?>{};
    for (final i in existing) {
      if (i.deleted) continue;
      if (spaceOf(i.itemId) == null) continue;
      have[i.itemId] = i.json;
    }
    final save = <String, Map<String, Object?>>{
      for (final e in want.entries)
        if (!have.containsKey(e.key) ||
            jsonEncode(have[e.key]) != jsonEncode(e.value))
          e.key: e.value,
    };
    final delete = <String>{
      for (final id in have.keys)
        if (!want.containsKey(id) && mine.contains(spaceOf(id))) id,
    };
    return (save: save, delete: delete);
  }

  /// Brings every circle this phone is in up to date with [family].
  static Future<void> sync(
    SpacesController circles,
    SpacesState state,
    FamilyData family,
    DateTime nowUtc,
  ) async {
    final mine = {for (final c in family.children) c.spaceId};
    for (final entry in state.entries) {
      final space = entry.space;
      if (space == null) continue;
      final want = <String, Map<String, Object?>>{
        for (final c in family.children)
          if (c.child.familyCircle == entry.info.id) ...itemsFor(c, nowUtc),
      };
      final changes = diff(
        existing: await space.store.all(),
        want: want,
        mine: mine,
      );
      for (final e in changes.save.entries) {
        await circles.save(entry.info.id, e.key, e.value);
      }
      for (final id in changes.delete) {
        await circles.delete(entry.info.id, id);
      }
    }
  }
}

/// A ZT Family circle this phone is in, by name.
typedef FamilyCircle = ({String id, String name});

/// The ZT Family circles this account is in and can write to.
final familyCirclesProvider = FutureProvider<List<FamilyCircle>>((ref) async {
  final state = ref.watch(ztFamilySpacesProvider);
  final out = <FamilyCircle>[];
  for (final e in state.entries) {
    final space = e.space;
    if (space == null) continue;
    final item = await space.store.get('family.circle');
    final name = item == null || item.deleted
        ? ''
        : (item.json?['name'] as String? ?? '').trim();
    out.add((id: e.info.id, name: name));
  }
  return out;
});
