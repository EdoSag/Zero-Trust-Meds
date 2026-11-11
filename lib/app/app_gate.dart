import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/meds_data.dart';
import '../platform/links.dart';
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

  @override
  void initState() {
    super.initState();
    _links = IncomingLinks.instance.arrived.listen((_) => _takeLinks());
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeLinks());
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Sync for the account's own vault (name, notice) and the children.
    ref.watch(ztSyncControllerProvider);
    ref.watch(ztSpacesProvider);
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
