import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/meds_data.dart';
import '../logic/dose_logic.dart';
import '../platform/links.dart';
import '../reminders/reminders.dart';
import '../ui/child_page.dart';
import '../ui/common.dart';
import '../ui/dose_actions.dart';
import '../ui/disclaimer.dart';
import '../ui/home_page.dart';
import '../ui/sharing_pages.dart';
import 'auth_providers.dart';

/// Routes between the shared account screens and Meds.
///
/// Signed out: sign in or create an account. Signed in but locked (cold
/// start, auto-lock): unlock with the account password or biometrics. A new
/// recovery key is always shown, and confirmed, before the vault opens.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  /// Stays on the sign-in screen until it hands back a result, even though
  /// Supabase reports the session a moment earlier.
  late bool _signingIn = ref.read(currentUserProvider) == null;
  UnlockResult? _awaitingRecoveryKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A key still waiting behind the recovery-key screen is zeroed when the
  /// app leaves the foreground, so coming back asks for the password.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final pending = _awaitingRecoveryKey;
      if (pending != null) {
        pending.dek.fillRange(0, pending.dek.length, 0);
        setState(() => _awaitingRecoveryKey = null);
      }
    }
  }

  void _onUnlocked(UnlockResult result) {
    if (!mounted) return;
    if (result.newRecoveryKey != null) {
      setState(() {
        _signingIn = false;
        _awaitingRecoveryKey = result;
      });
      return;
    }
    setState(() => _signingIn = false);
    ref
        .read(vaultControllerProvider.notifier)
        .unlock(result.dek, legacyDek: result.legacyDek);
  }

  void _forgotPassword() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ZtForgotPasswordScreen()),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      // Don't leave a page open over a locked vault.
      if (next is VaultLocked) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) {
        ref.read(vaultControllerProvider.notifier).lock();
        // Reminders name the children: none stay after signing out.
        ref.read(reminderSchedulerProvider).cancelAll().ignore();
        setState(() => _signingIn = true);
      }
    });

    final pending = _awaitingRecoveryKey;
    if (pending != null) {
      return ZtRecoveryKeyScreen(
        recoveryKey: pending.newRecoveryKey!,
        onDone: () {
          setState(() => _awaitingRecoveryKey = null);
          ref
              .read(vaultControllerProvider.notifier)
              .unlock(pending.dek, legacyDek: pending.legacyDek);
        },
      );
    }

    if (ref.watch(passwordRecoveryProvider)) {
      return ZtResetPasswordScreen(
        onUnlocked: (result) {
          ref.read(passwordRecoveryProvider.notifier).done();
          _onUnlocked(result);
        },
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null || _signingIn) {
      return ZtSignInScreen(
        onUnlocked: _onUnlocked,
        onForgotPassword: _forgotPassword,
      );
    }

    if (ref.watch(vaultControllerProvider) is VaultLocked) {
      return ZtUnlockScreen(
        email: user.email,
        onUnlocked: _onUnlocked,
        onSignOut: () => ref.read(accountServiceProvider).signOut(),
        onForgotPassword: _forgotPassword,
      );
    }

    return const MedsHome();
  }
}

/// Meds once unlocked: runs sync for the account's own vault and every
/// child's shared space, asks once to read the "not medical advice" notice,
/// and opens invite links the app was started with.
class MedsHome extends ConsumerStatefulWidget {
  const MedsHome({super.key});

  @override
  ConsumerState<MedsHome> createState() => _MedsHomeState();
}

class _MedsHomeState extends ConsumerState<MedsHome> {
  StreamSubscription<void>? _links;
  StreamSubscription<void>? _taps;
  Timer? _resyncSoon;
  Timer? _hourly;
  bool _handlingTaps = false;

  @override
  void initState() {
    super.initState();
    _links = IncomingLinks.instance.arrived.listen((_) => _takeLinks());
    _taps = ref.read(reminderSchedulerProvider).tapped.listen((_) {
      _takeTaps();
    });
    // Reminders are set 14 days ahead; this keeps the window moving, and
    // drops follow-ups for doses given while the app stayed open.
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => _resync());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takeLinks();
      _takeTaps();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The language or the 24-hour setting changed the reminders' text.
    _resync();
  }

  @override
  void dispose() {
    _links?.cancel();
    _taps?.cancel();
    _resyncSoon?.cancel();
    _hourly?.cancel();
    super.dispose();
  }

  /// Sets the phone's reminders from what this phone knows now. Runs
  /// after every change (local or synced), so a dose logged anywhere
  /// cancels its follow-up and missed alert here.
  void _resync() {
    _resyncSoon?.cancel();
    _resyncSoon = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      try {
        final family = await ref.read(familyProvider.future);
        final prefs = await ref.read(reminderPrefsProvider.future);
        if (!mounted) return;
        final texts = L10nReminderTexts(context);
        final plan = ReminderPlan.plan(
          family.children,
          prefs,
          texts,
          DateTime.now().toUtc(),
        );
        await ref.read(reminderSchedulerProvider).sync(plan, texts.channel);
      } on Object {
        // Retried on the next change or within the hour.
      }
    });
  }

  Future<void> _takeLinks() async {
    final links = await IncomingLinks.instance.take();
    for (final link in links) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => JoinPage(initialLink: link)),
      );
    }
  }

  /// A reminder tapped, or "Mark as given" pressed, now that the app is
  /// unlocked: opens the dose, or logs it (warning first about a double
  /// dose, as everywhere else).
  Future<void> _takeTaps() async {
    if (_handlingTaps) return;
    _handlingTaps = true;
    try {
      while (mounted) {
        final taps = ref.read(reminderSchedulerProvider).takeTaps();
        if (taps.isEmpty) break;
        for (final tap in taps) {
          if (!mounted) return;
          await _open(tap);
        }
      }
    } finally {
      _handlingTaps = false;
    }
  }

  Future<void> _open(ReminderTarget tap) async {
    final me = await ref.read(meProvider.future);
    if (!me.disclaimerAccepted || !mounted) return;
    final family = await ref.read(familyProvider.future);
    final c = family.child(tap.spaceId);
    if (c == null || !mounted) return;
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    nav.push(
      MaterialPageRoute<void>(builder: (_) => ChildPage(spaceId: c.spaceId)),
    );
    final dose = ReminderPlan.doseFor(c, tap);
    if (dose == null) {
      if (tap.date != null) showSnack(context, context.l.reminderDoseGone);
      return;
    }
    // Let the child's page open first.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    if (tap.markGiven) {
      await giveDose(context, ref, c, dose.treatment, slot: dose);
    } else {
      final status = DoseRules.statusOf(
        dose,
        c.logsOf(dose.treatment.id),
        DateTime.now().toUtc(),
        missedAfter: c.missedAfter,
      );
      await showDoseSheet(context, ref, c, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync for the account's own vault (name, notice) and the children.
    ref.watch(ztSyncControllerProvider);
    ref.watch(ztSpacesProvider);
    ref.listen(familyProvider, (_, _) => _resync());
    ref.listen(reminderPrefsProvider, (_, _) => _resync());
    final me = ref.watch(meProvider);
    final accepted = me.value?.disclaimerAccepted;
    if (accepted == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!accepted) {
      return DisclaimerPage(
        onAccept: () => ref
            .read(medsActionsProvider)
            .saveMe(MeProfile(name: me.value!.name, disclaimerAccepted: true)),
      );
    }
    return const HomePage();
  }
}
