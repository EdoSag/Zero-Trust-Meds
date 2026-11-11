import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/meds_data.dart';
import '../logic/dose_logic.dart';
import '../model/models.dart';
import 'child_editor.dart';
import 'common.dart';
import 'home_page.dart';
import 'sharing_pages.dart';
import 'treatment_editor.dart';

class ChildPage extends ConsumerWidget {
  const ChildPage({super.key, required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final c = ref.watch(familyProvider).value?.child(spaceId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.childGone)),
      );
    }
    final now = readNow(ref);
    final today = c.today(now);
    final doses = c.doses(today, now);
    final active = c.active(now);
    final history = c.history(now);
    final recent = [...c.logs]..sort((a, b) => b.at.compareTo(a.at));
    final myId = ref.read(medsActionsProvider).myUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.child.name),
        actions: [
          if (c.isAdmin)
            IconButton(
              tooltip: l.editChild,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChildEditorPage(existing: c),
                ),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: l.more,
            onSelected: (v) => switch (v) {
              'export' => _export(context, c),
              'leave' => _leave(context, ref, c),
              'delete' => _delete(context, ref, c),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'export', child: Text(l.exportChild)),
              PopupMenuItem(value: 'leave', child: Text(l.leaveChild)),
              if (c.isAdmin)
                PopupMenuItem(value: 'delete', child: Text(l.deleteChild)),
            ],
          ),
        ],
      ),
      floatingActionButton: c.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TreatmentEditorPage(spaceId: c.spaceId),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l.addTreatment),
            )
          : null,
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 96),
        children: [
          ListTile(
            leading: ChildAvatar(c.child, radius: 28),
            title: Text(
              c.child.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Text(
              [
                if (c.child.birthDate != null)
                  l.bornOn(formatLocalDate(context, c.child.birthDate!)),
                l.timesIn(c.child.timeZone),
              ].join(' · '),
            ),
          ),
          SectionHeader(l.today),
          if (doses.isEmpty && c.asNeeded(now).isEmpty)
            ListTile(title: Text(l.nothingToday)),
          for (final d in doses) DoseRow(c, d),
          for (final t in c.asNeeded(now)) AsNeededRow(c, t, now: now),
          SectionHeader(l.treatments),
          if (active.isEmpty) ListTile(title: Text(l.noTreatments)),
          for (final t in active) _TreatmentTile(c, t, now: now),
          SectionHeader(
            l.caregivers,
            trailing: c.isAdmin
                ? TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => InvitePage(spaceId: c.spaceId),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(l.invite),
                  )
                : null,
          ),
          for (final m in c.caregivers) _MemberTile(c, m, me: m.userId == myId),
          if (recent.isNotEmpty) SectionHeader(l.recentRecords),
          for (final log in recent.take(20)) _LogTile(c, log),
          if (history.isNotEmpty) SectionHeader(l.history),
          for (final t in history) _TreatmentTile(c, t, now: now),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, ChildData c) async {
    final json = const JsonEncoder.withIndent('  ').convert({
      'app': 'Zero-Trust Meds',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'child': c.child.toJson()..remove('photo'),
      'caregivers': [
        for (final m in c.caregivers) {'name': m.name, 'role': m.role.name},
      ],
      'medications': [for (final m in c.medications) m.toJson()],
      'treatments': [
        for (final t in c.treatments) {'id': t.id, ...t.toJson()},
      ],
      'doses': [
        for (final l in c.logs) {...l.toJson(), 'byName': c.nameOf(l.byUserId)},
      ],
    });
    final name = c.child.name.replaceAll(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
      '_',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            mimeType: 'application/json',
            name: 'zt-meds-$name.json',
          ),
        ],
        fileNameOverrides: ['zt-meds-$name.json'],
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, ChildData c) async {
    final l = context.l;
    if (!await confirm(
      context,
      title: l.leaveChildTitle(c.child.name),
      body: l.leaveChildBody,
      action: l.leave,
      destructive: true,
    )) {
      return;
    }
    await ref.read(medsActionsProvider).leaveChild(c.spaceId);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ChildData c) async {
    final l = context.l;
    if (!await confirm(
      context,
      title: l.deleteChildTitle(c.child.name),
      body: l.deleteChildBody,
      action: l.delete,
      destructive: true,
    )) {
      return;
    }
    await ref.read(medsActionsProvider).deleteChild(c.spaceId);
    if (context.mounted) Navigator.of(context).pop();
  }
}

String scheduleText(BuildContext context, Treatment t) {
  final s = t.schedule;
  return switch (s) {
    FixedTimes(:final times) =>
      times
          .map(
            (x) => MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay(hour: x.hour, minute: x.minute),
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                context,
              ),
            ),
          )
          .join(', '),
    AsNeeded() => asNeededRule(context, s),
  };
}

class _TreatmentTile extends ConsumerWidget {
  const _TreatmentTile(this.c, this.t, {required this.now});
  final ChildData c;
  final Treatment t;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final last = t.lastDay;
    final period = last == null
        ? l.fromDate(formatLocalDate(context, t.startDate))
        : l.dateRange(
            formatLocalDate(context, t.startDate),
            formatLocalDate(context, last),
          );
    final adherence = Adherence.of(c.dosesOf(t, now));
    return ListTile(
      leading: Icon(t.isPaused ? Icons.pause_circle_outline : Icons.medication),
      title: Text('${t.medication.name} · ${doseText(context, t.medication)}'),
      subtitle: Text(
        [
          scheduleText(context, t),
          period,
          if (t.isPaused) l.statusPaused,
          if (adherence.percent != null) l.adherence(adherence.percent!),
        ].join(' · '),
      ),
      onTap: c.isAdmin ? () => _actions(context, ref) : null,
    );
  }

  void _actions(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final actions = ref.read(medsActionsProvider);
    final today = c.today(now);
    final finished = t.isFinishedBy(today);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.editTreatment),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TreatmentEditorPage(spaceId: c.spaceId, existing: t),
                  ),
                );
              },
            ),
            if (!finished)
              ListTile(
                leading: Icon(t.isPaused ? Icons.play_arrow : Icons.pause),
                title: Text(t.isPaused ? l.resume : l.pause),
                onTap: () {
                  Navigator.pop(ctx);
                  t.isPaused
                      ? actions.resumeTreatment(c, t, DateTime.now().toUtc())
                      : actions.pauseTreatment(c, t, DateTime.now().toUtc());
                },
              ),
            if (!finished)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: Text(l.endToday),
                subtitle: Text(l.endTodayHint),
                onTap: () {
                  Navigator.pop(ctx);
                  actions.endTreatment(c, t, today);
                },
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(ctx).colorScheme.error,
              ),
              title: Text(l.deleteTreatment),
              onTap: () async {
                Navigator.pop(ctx);
                if (await confirm(
                  context,
                  title: l.deleteTreatmentTitle(t.medication.name),
                  body: l.deleteTreatmentBody,
                  action: l.delete,
                  destructive: true,
                )) {
                  await actions.deleteTreatment(c, t);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile(this.c, this.m, {required this.me});
  final ChildData c;
  final SpaceMember m;
  final bool me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final admin = m.role == SpaceRole.admin;
    return ListTile(
      leading: Icon(
        admin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
      ),
      title: Text(me ? l.youName(m.name) : m.name),
      subtitle: Text(admin ? l.roleAdmin : l.roleCaregiver),
      trailing: c.isAdmin && !me
          ? PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (v) async {
                final spaces = ref.read(ztSpacesProvider.notifier);
                try {
                  if (v == 'role') {
                    await spaces.setRole(
                      c.spaceId,
                      m.userId,
                      admin ? SpaceRole.member : SpaceRole.admin,
                    );
                  } else if (v == 'remove') {
                    if (!context.mounted) return;
                    if (!await confirm(
                      context,
                      title: l.removeCaregiverTitle(m.name),
                      body: l.removeCaregiverBody,
                      action: l.remove,
                      destructive: true,
                    )) {
                      return;
                    }
                    await spaces.remove(c.spaceId, m.userId);
                  }
                  ref.read(medsRevisionProvider.notifier).bump();
                } on Object {
                  if (context.mounted) showSnack(context, l.actionFailed);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'role',
                  child: Text(admin ? l.makeCaregiver : l.makeAdmin),
                ),
                PopupMenuItem(value: 'remove', child: Text(l.remove)),
              ],
            )
          : null,
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile(this.c, this.log);
  final ChildData c;
  final DoseLog log;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = c.treatments.where((x) => x.id == log.treatmentId).firstOrNull;
    final who = c.nameOf(log.byUserId);
    final when = formatWhen(context, log.at);
    return ListTile(
      dense: true,
      leading: Icon(log.given ? Icons.check : Icons.block),
      title: Text(t?.medication.name ?? l.removedTreatment),
      subtitle: Text(
        [
          log.given ? l.givenBy(who, when) : l.skippedBy(who, when),
          if (log.reason.isNotEmpty) log.reason,
        ].join(' · '),
      ),
    );
  }
}
