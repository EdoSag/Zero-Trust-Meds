import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/meds_data.dart';
import '../logic/dose_logic.dart';
import '../model/models.dart';
import 'child_editor.dart';
import 'child_page.dart';
import 'common.dart';
import 'dose_actions.dart';
import 'family_overview.dart';
import 'settings_page.dart';
import 'sharing_pages.dart';

/// The time now, ticking every minute so Due turns into Missed on screen.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now().toUtc(),
  );
});

DateTime readNow(WidgetRef ref) =>
    ref.watch(nowProvider).value ?? DateTime.now().toUtc();

/// People waiting to join a child this account manages.
final pendingJoinsProvider = FutureProvider<List<PendingJoin>>((ref) async {
  final family = await ref.watch(familyProvider.future);
  final spaces = ref.read(ztSpacesProvider.notifier);
  final out = <PendingJoin>[];
  for (final c in family.children) {
    if (!c.isAdmin) continue;
    try {
      out.addAll(await spaces.pendingJoins(c.spaceId));
    } on Object {
      // offline: shown on the next refresh
    }
  }
  return out;
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final family = ref.watch(familyProvider);
    final now = readNow(ref);
    final data = family.value;
    final joins = ref.watch(pendingJoinsProvider).value ?? const [];

    Widget body;
    if (data == null || (data.loading && data.children.isEmpty)) {
      body = family.hasError
          ? Center(child: Text(l.loadError))
          : const Center(child: CircularProgressIndicator());
    } else if (data.children.isEmpty && data.pending.isEmpty) {
      body = const _Empty();
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.read(ztSpacesProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsetsDirectional.only(bottom: 96),
          children: [
            for (final j in joins) _JoinRequestCard(j, family: data),
            for (final p in data.pending) _PendingCard(p),
            if (data.children.length > 1)
              FamilyOverview(data.children, now: now),
            for (final c in data.children) _ChildToday(c, now: now),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.todayTitle),
        actions: [
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MedsSettingsPage()),
            ),
          ),
        ],
      ),
      body: body,
      floatingActionButton: data == null || data.children.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddSheet(context),
              icon: const Icon(Icons.add),
              label: Text(l.addChildOrJoin),
            ),
    );
  }
}

Future<void> showAddSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (ctx) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.child_care),
          title: Text(ctx.l.addChild),
          subtitle: Text(ctx.l.addChildHint),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChildEditorPage()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.qr_code_scanner),
          title: Text(ctx.l.joinWithInvite),
          subtitle: Text(ctx.l.joinWithInviteHint),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const JoinPage()));
          },
        ),
      ],
    ),
  ),
);

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l.emptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l.emptyBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChildEditorPage(),
                ),
              ),
              icon: const Icon(Icons.child_care),
              label: Text(l.addChild),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const JoinPage())),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l.joinWithInvite),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard(this.p);
  final PendingChild p;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.hourglass_top),
        title: Text(l.waitingForAdmin),
        subtitle: Text(
          p.code == null ? l.waitingForSync : l.waitingCode(p.code!),
        ),
      ),
    );
  }
}

class _JoinRequestCard extends ConsumerWidget {
  const _JoinRequestCard(this.join, {required this.family});
  final PendingJoin join;
  final FamilyData family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final child = family.child(join.spaceId)?.child.name ?? '';
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      child: ListTile(
        leading: const Icon(Icons.person_add_alt),
        title: Text(l.joinRequest(join.name, child)),
        subtitle: Text(l.joinRequestHint),
        onTap: () => confirmJoin(context, ref, join, childName: child),
      ),
    );
  }
}

/// One child's doses today, grouped by morning, noon, evening and night.
class _ChildToday extends ConsumerWidget {
  const _ChildToday(this.c, {required this.now});
  final ChildData c;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final today = c.today(now);
    final doses = c.doses(today, now);
    final asNeeded = c.asNeeded(now);
    final given = doses.where((d) => d.state == DoseState.given).length;
    final bySlot = <TimeSlot, List<DoseStatus>>{};
    for (final d in doses) {
      bySlot.putIfAbsent(TimeSlot.of(d.dose.time), () => []).add(d);
    }
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: ChildAvatar(c.child),
            title: Text(
              c.child.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              doses.isEmpty && asNeeded.isEmpty
                  ? l.nothingToday
                  : l.givenOfToday(given, doses.length),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChildPage(spaceId: c.spaceId),
              ),
            ),
          ),
          for (final slot in TimeSlot.values)
            if (bySlot[slot] case final list?) ...[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                child: Text(
                  slotLabel(context, slot),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              for (final d in list) DoseRow(c, d),
            ],
          for (final t in asNeeded) AsNeededRow(c, t, now: now),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class DoseRow extends ConsumerWidget {
  const DoseRow(this.c, this.status, {super.key});
  final ChildData c;
  final DoseStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = status.dose.treatment;
    final open =
        status.state == DoseState.due ||
        status.state == DoseState.missed ||
        status.state == DoseState.upcoming;
    final who = status.logs.isEmpty
        ? null
        : status.logs.last.given
        ? context.l.givenBy(
            c.nameOf(status.logs.last.byUserId),
            formatTime(context, status.logs.last.at),
          )
        : context.l.skippedBy(
            c.nameOf(status.logs.last.byUserId),
            formatTime(context, status.logs.last.at),
          );
    return ListTile(
      dense: true,
      title: Text('${t.medication.name} · ${doseText(context, t.medication)}'),
      subtitle: Text([formatTime(context, status.dose.at), ?who].join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(status.state, twice: status.givenTwice),
          if (open)
            IconButton(
              tooltip: context.l.markGiven,
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => giveDose(context, ref, c, t, slot: status.dose),
            ),
        ],
      ),
      onTap: () => showDoseSheet(context, ref, c, status),
    );
  }
}

/// An as-needed medicine: when it may be given next, and a Give button.
class AsNeededRow extends ConsumerWidget {
  const AsNeededRow(this.c, this.t, {super.key, required this.now});
  final ChildData c;
  final Treatment t;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final logs = c.logsOf(t.id).where((x) => x.given).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final next = DoseGuard.nextAllowed(t, logs, now);
    final last = logs.isEmpty ? null : logs.last;
    final parts = [
      l.asNeeded,
      if (last != null)
        l.lastGiven(c.nameOf(last.byUserId), formatWhen(context, last.at)),
      next.isAfter(now)
          ? l.nextAllowed(formatWhen(context, next))
          : l.canGiveNow,
    ];
    return ListTile(
      dense: true,
      title: Text('${t.medication.name} · ${doseText(context, t.medication)}'),
      subtitle: Text(parts.join(' · ')),
      trailing: IconButton(
        tooltip: l.markGiven,
        icon: Icon(
          next.isAfter(now)
              ? Icons.hourglass_bottom
              : Icons.check_circle_outline,
        ),
        onPressed: () => giveDose(context, ref, c, t),
      ),
      onTap: () => showAsNeededSheet(context, ref, c, t),
    );
  }
}

/// Recent doses of an as-needed medicine, with give / give at another time.
Future<void> showAsNeededSheet(
  BuildContext context,
  WidgetRef ref,
  ChildData c,
  Treatment t,
) {
  final l = context.l;
  final actions = ref.read(medsActionsProvider);
  final logs = c.logsOf(t.id)..sort((a, b) => b.at.compareTo(a.at));
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              '${t.medication.name} · ${doseText(ctx, t.medication)}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            subtitle: Text(asNeededRule(ctx, t.schedule as AsNeeded)),
          ),
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l.markGiven),
            onTap: () {
              Navigator.pop(ctx);
              giveDose(context, ref, c, t);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: Text(l.givenAtOtherTime),
            onTap: () async {
              Navigator.pop(ctx);
              final at = await pickDoseTime(context, DateTime.now().toUtc());
              if (at != null && context.mounted) {
                await giveDose(context, ref, c, t, at: at);
              }
            },
          ),
          if (logs.isNotEmpty) const Divider(),
          for (final log in logs.take(10))
            ListTile(
              dense: true,
              leading: Icon(log.given ? Icons.check : Icons.block),
              title: Text(
                log.given
                    ? l.givenBy(c.nameOf(log.byUserId), formatWhen(ctx, log.at))
                    : l.skippedBy(
                        c.nameOf(log.byUserId),
                        formatWhen(ctx, log.at),
                      ),
              ),
              trailing: IconButton(
                tooltip: l.undoRecord,
                icon: const Icon(Icons.undo),
                onPressed: () {
                  Navigator.pop(ctx);
                  unawaited(actions.deleteLog(c, log));
                  showSnack(
                    context,
                    l.recordRemoved,
                    actionLabel: l.undo,
                    onAction: () => actions.updateLog(c, log),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

String asNeededRule(BuildContext context, AsNeeded s) {
  final l = context.l;
  final gap = l.everyHours(_hours(context, s.minIntervalMinutes));
  return s.maxPer24h == null ? gap : '$gap · ${l.maxPerDay(s.maxPer24h!)}';
}

String _hours(BuildContext context, int minutes) =>
    formatAmount(context, minutes / 60);
