import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/meds_data.dart';
import '../model/models.dart';
import 'common.dart';
import 'disclaimer.dart';
import 'reminders_page.dart';

/// The shared Zero-Trust settings screen, with Meds' own rows.
class MedsSettingsPage extends ConsumerWidget {
  const MedsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final me = ref.watch(meProvider).value;
    return ZtSettingsPage(
      showSyncStatus: true,
      onSignedOut: () {
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      privacyPolicyUrl: Uri.parse('https://zerotrust.bz/privacy'),
      termsUrl: Uri.parse('https://zerotrust.bz/terms'),
      supportUrl: Uri.parse('https://zerotrust.bz/support'),
      appSection: [
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(l.yourName),
          subtitle: Text(me == null || me.name.isEmpty ? l.notSet : me.name),
          onTap: me == null ? null : () => _editName(context, ref, me),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(l.remindersTitle),
          subtitle: Text(l.remindersHint),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RemindersPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.medication_outlined),
          title: Text(l.medicineList),
          subtitle: Text(l.medicineListHint),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MedicationsPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.health_and_safety_outlined),
          title: Text(l.disclaimerTitle),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DisclaimerPage(readOnly: true),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    MeProfile me,
  ) async {
    final l = context.l;
    final controller = TextEditingController(text: me.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.yourName),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(helperText: l.yourNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref
        .read(medsActionsProvider)
        .saveMe(
          MeProfile(name: name, disclaimerAccepted: me.disclaimerAccepted),
        );
    // Shown to the other caregivers of every child this account is in.
    final family = await ref.read(familyProvider.future);
    final spaces = ref.read(ztSpacesProvider.notifier);
    final myId = ref.read(medsActionsProvider).myUserId;
    for (final c in family.children) {
      try {
        await spaces.rename(c.spaceId, myId, name);
      } on Object {
        // Only admins can rewrite the member list; caregivers' names
        // change when an admin renames them.
      }
    }
  }
}

/// The family's medicines (from every child this account manages).
/// Changing one here changes it for every child; running treatments keep
/// the copy they started with.
class MedicationsPage extends ConsumerWidget {
  const MedicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final family = ref.watch(familyProvider).value;
    final meds = family?.medications ?? const <Medication>[];
    return Scaffold(
      appBar: AppBar(title: Text(l.medicineList)),
      body: meds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.medicineListEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                for (final m in meds)
                  ListTile(
                    leading: const Icon(Icons.medication),
                    title: Text(m.name),
                    subtitle: Text(
                      [
                        formLabel(context, m.form),
                        doseText(context, m),
                        if (m.notes.isNotEmpty) m.notes,
                      ].join(' · '),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: l.more,
                      onSelected: (v) async {
                        final actions = ref.read(medsActionsProvider);
                        if (v == 'rename') {
                          final updated = await _editMed(context, m);
                          if (updated != null) {
                            await actions.updateMedicationEverywhere(
                              family!,
                              m,
                              updated,
                            );
                          }
                        } else if (v == 'delete' &&
                            await confirm(
                              context,
                              title: l.deleteMedicineTitle(m.name),
                              body: l.deleteMedicineBody,
                              action: l.delete,
                              destructive: true,
                            )) {
                          await actions.deleteMedicationEverywhere(family!, m);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'rename', child: Text(l.edit)),
                        PopupMenuItem(value: 'delete', child: Text(l.delete)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<Medication?> _editMed(BuildContext context, Medication m) {
    final l = context.l;
    final name = TextEditingController(text: m.name);
    final notes = TextEditingController(text: m.notes);
    return showDialog<Medication>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.edit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l.medicineName),
            ),
            TextField(
              controller: notes,
              decoration: InputDecoration(labelText: l.medicineNotes),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => name.text.trim().isEmpty
                ? null
                : Navigator.pop(
                    ctx,
                    Medication(
                      id: m.id,
                      name: name.text.trim(),
                      form: m.form,
                      amount: m.amount,
                      unit: m.unit,
                      notes: notes.text.trim(),
                    ),
                  ),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
