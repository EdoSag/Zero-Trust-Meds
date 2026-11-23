import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_circle.dart';
import '../data/meds_data.dart';
import 'common.dart';

/// "Show in ZT Family": the person's doses in a ZT Family circle's hub
/// (S-10, L-2). Admins switch it; caregivers see where it's shown.
class FamilyCircleTile extends ConsumerWidget {
  const FamilyCircleTile(this.c, {super.key});
  final ChildData c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final circles = ref.watch(familyCirclesProvider).value ?? const [];
    final chosen = c.child.familyCircle;
    String nameOf(String id) {
      for (final x in circles) {
        if (x.id == id && x.name.isNotEmpty) return x.name;
      }
      return l.familyCircleUnnamed;
    }

    final on = chosen != null;
    if (!c.isAdmin && !on) return const SizedBox.shrink();
    final subtitle = on
        ? l.familyCircleOnHint(nameOf(chosen))
        : circles.isEmpty
        ? l.familyCircleNone
        : l.familyCircleOffHint;
    return SwitchListTile(
      secondary: const Icon(Icons.diversity_3_outlined),
      title: Text(l.familyCircleShow),
      subtitle: Text(subtitle),
      value: on,
      onChanged: !c.isAdmin || (!on && circles.isEmpty)
          ? null
          : (v) => _set(context, ref, v, circles),
    );
  }

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    bool on,
    List<FamilyCircle> circles,
  ) async {
    final l = context.l;
    String? id;
    if (on) {
      id = circles.length == 1
          ? circles.single.id
          : await showDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: Text(l.familyCirclePick),
                children: [
                  for (final x in circles)
                    SimpleDialogOption(
                      onPressed: () => Navigator.of(ctx).pop(x.id),
                      child: Text(
                        x.name.isEmpty ? l.familyCircleUnnamed : x.name,
                      ),
                    ),
                ],
              ),
            );
      if (id == null) return;
    }
    try {
      await ref
          .read(medsActionsProvider)
          .saveChild(
            c.spaceId,
            on
                ? c.child.copyWith(familyCircle: id)
                : c.child.copyWith(clearFamilyCircle: true),
          );
    } on Object {
      if (context.mounted) showSnack(context, l.saveFailedOffline);
    }
  }
}
