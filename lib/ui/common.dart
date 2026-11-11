import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/meds_config.dart';
import '../l10n/generated/app_localizations.dart';
import '../logic/dose_logic.dart';
import '../model/models.dart';

extension L10nX on BuildContext {
  AppL10n get l => AppL10n.of(this);
  String get localeName => Localizations.localeOf(this).toLanguageTag();
}

/// A UTC instant as a time on this phone ("8:00 AM" or "08:00").
String formatTime(BuildContext context, DateTime utc) =>
    TimeOfDay.fromDateTime(utc.toLocal()).format(context);

/// "Wed, Nov 11" in the phone's language.
String formatDay(BuildContext context, DateTime local) =>
    DateFormat.MMMEd(context.localeName).format(local);

String formatLocalDate(BuildContext context, LocalDate d) =>
    formatDay(context, DateTime(d.year, d.month, d.day));

/// Day and time on this phone, for "given by Dana at ...".
String formatWhen(BuildContext context, DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final time = formatTime(context, utc);
  return sameDay ? time : '${formatDay(context, local)} $time';
}

String formatAmount(BuildContext context, double? amount) {
  if (amount == null) return '';
  return NumberFormat.decimalPattern(context.localeName).format(amount);
}

/// "5 ml" / "1 tablet".
String doseText(BuildContext context, Medication m) {
  final a = formatAmount(context, m.amount);
  final unit = m.unit.isNotEmpty ? m.unit : context.l.formUnit(m.form.name);
  return a.isEmpty ? unit : '$a $unit';
}

String formLabel(BuildContext context, MedForm f) => context.l.form(f.name);

/// A status is never shown by colour alone: each has an icon and a label.
class StatusLook {
  const StatusLook(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;

  static StatusLook of(BuildContext context, DoseState s) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l;
    return switch (s) {
      DoseState.given => StatusLook(
        Icons.check_circle,
        const Color(0xFF22C55E),
        l.statusGiven,
      ),
      DoseState.due => StatusLook(
        Icons.notifications_active,
        scheme.primary,
        l.statusDue,
      ),
      DoseState.missed => StatusLook(
        Icons.warning_amber_rounded,
        missedAmber,
        l.statusMissed,
      ),
      DoseState.upcoming => StatusLook(
        Icons.schedule,
        scheme.onSurfaceVariant,
        l.statusUpcoming,
      ),
      DoseState.skipped => StatusLook(
        Icons.block,
        scheme.onSurfaceVariant,
        l.statusSkipped,
      ),
      DoseState.paused => StatusLook(
        Icons.pause_circle_outline,
        scheme.onSurfaceVariant,
        l.statusPaused,
      ),
    };
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.state, {super.key, this.twice = false});
  final DoseState state;
  final bool twice;

  @override
  Widget build(BuildContext context) {
    final look = StatusLook.of(context, state);
    final label = twice ? context.l.statusGivenTwice : look.label;
    final color = twice ? missedAmber : look.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(twice ? Icons.error_outline : look.icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar(this.child, {super.key, this.radius = 20});
  final Child child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = Color(child.color);
    final photo = child.photo;
    if (photo != null) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(photo)),
        );
      } on FormatException {
        // fall through to initials
      }
    }
    final initial = child.name.trim().isEmpty
        ? '?'
        : child.name.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundColor: Colors.white,
      child: Text(
        initial,
        style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String slotLabel(BuildContext context, TimeSlot s) => context.l.slot(s.name);

/// A snackbar that closes by itself even with an action (Flutter keeps
/// those open otherwise).
void showSnack(
  BuildContext context,
  String text, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 6),
        persist: false,
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// One section heading in a list.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
