import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../data/meds_data.dart';
import 'common.dart';
import 'home_page.dart';

/// Invites a caregiver to one child: a link to send, or a QR code to scan
/// in person. Then shows who answered, to confirm with the code.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key, required this.spaceId});
  final String spaceId;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  SpaceRole _role = SpaceRole.member;
  SpaceInviteLink? _link;
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final link = await ref
          .read(ztSpacesProvider.notifier)
          .invite(widget.spaceId, role: _role);
      if (mounted) setState(() => _link = link);
    } on Object {
      if (mounted) showSnack(context, context.l.needsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final c = ref.watch(familyProvider).value?.child(widget.spaceId);
    final joins = [
      for (final j
          in ref.watch(pendingJoinsProvider).value ?? const <PendingJoin>[])
        if (j.spaceId == widget.spaceId) j,
    ];
    final link = _link;
    return Scaffold(
      appBar: AppBar(title: Text(l.inviteTo(c?.child.name ?? ''))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final j in joins)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: Text(l.joinRequest(j.name, c?.child.name ?? '')),
                subtitle: Text(l.joinRequestHint),
                onTap: () => confirmJoin(
                  context,
                  ref,
                  j,
                  childName: c?.child.name ?? '',
                ),
              ),
            ),
          if (link == null) ...[
            Text(l.inviteIntro),
            const SizedBox(height: 16),
            SegmentedButton<SpaceRole>(
              segments: [
                ButtonSegment(
                  value: SpaceRole.member,
                  label: Text(l.roleCaregiver),
                ),
                ButtonSegment(value: SpaceRole.admin, label: Text(l.roleAdmin)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _role == SpaceRole.admin ? l.roleAdminHint : l.roleCaregiverHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.qr_code),
              label: Text(l.createInvite),
            ),
          ] else ...[
            Text(l.inviteReady, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: link.qrData,
                  size: 240,
                  semanticsLabel: l.inviteQr,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: link.toString()),
                      );
                      if (context.mounted) showSnack(context, l.linkCopied);
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(l.copyLink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: l.inviteMessage(
                          c?.child.name ?? '',
                          link.toString(),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.share),
                    label: Text(l.shareLink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l.inviteNextSteps,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(pendingJoinsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l.checkForAnswers),
            ),
          ],
        ],
      ),
    );
  }
}

/// The admin checks the code on the other person's phone, then lets them in.
Future<void> confirmJoin(
  BuildContext context,
  WidgetRef ref,
  PendingJoin j, {
  required String childName,
}) async {
  final l = context.l;
  final spaces = ref.read(ztSpacesProvider.notifier);
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.confirmJoinTitle(j.name, childName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.confirmJoinBody),
          const SizedBox(height: 16),
          Text(
            j.verificationCode,
            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 2,
            ),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 8),
          Text(j.role == SpaceRole.admin ? l.roleAdmin : l.roleCaregiver),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'reject'),
          child: Text(l.codesDiffer),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.later)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'ok'),
          child: Text(l.codesMatch),
        ),
      ],
    ),
  );
  try {
    if (choice == 'ok') {
      await spaces.confirm(j);
      if (context.mounted) showSnack(context, l.joined(j.name));
    } else if (choice == 'reject') {
      await spaces.revokeInvite(j.inviteId);
    } else {
      return;
    }
  } on Object {
    if (context.mounted) showSnack(context, l.needsInternet);
  }
  ref.invalidate(pendingJoinsProvider);
  ref.read(medsRevisionProvider.notifier).bump();
}

/// Joins a child from an invite link (pasted, scanned, or opened from a
/// message), then shows the code to compare with the admin.
class JoinPage extends ConsumerStatefulWidget {
  const JoinPage({super.key, this.initialLink});
  final String? initialLink;

  @override
  ConsumerState<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends ConsumerState<JoinPage> {
  late final _link = TextEditingController(text: widget.initialLink);
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _code;

  @override
  void initState() {
    super.initState();
    ref
        .read(meProvider.future)
        .then((me) {
          if (mounted && _name.text.isEmpty) _name.text = me.name;
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _validLink(String? v) {
    try {
      final link = SpaceInviteLink.parse(v ?? '');
      if (link.app != 'meds') return context.l.inviteOtherApp;
      return null;
    } on FormatException {
      return context.l.inviteInvalid;
    }
  }

  Future<void> _scan() async {
    final text = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (text != null) setState(() => _link.text = text);
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l;
    setState(() => _busy = true);
    try {
      final name = _name.text.trim();
      final actions = ref.read(medsActionsProvider);
      final me = await ref.read(meProvider.future);
      if (me.name != name) {
        await actions.saveMe(
          MeProfile(name: name, disclaimerAccepted: me.disclaimerAccepted),
        );
      }
      final started = await ref
          .read(ztSpacesProvider.notifier)
          .answer(SpaceInviteLink.parse(_link.text), myName: name);
      if (mounted) setState(() => _code = started.verificationCode);
    } on SpaceRefused {
      if (mounted) showSnack(context, l.inviteUsed);
    } on Object {
      if (mounted) showSnack(context, l.needsInternet);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final code = _code;
    return Scaffold(
      appBar: AppBar(title: Text(l.joinWithInvite)),
      body: code != null
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.verified_user_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  l.joinCodeTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  code,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 16),
                Text(l.joinCodeBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.done),
                ),
              ],
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l.joinIntro),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _link,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.inviteLink,
                      suffixIcon: IconButton(
                        tooltip: l.scanQr,
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scan,
                      ),
                    ),
                    validator: _validLink,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.yourName,
                      helperText: l.yourNameHint,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l.required : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _join,
                    child: Text(l.join),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _key = GlobalKey(debugLabel: 'qr');
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l.scanQr)),
    body: QRView(
      key: _key,
      overlay: QrScannerOverlayShape(
        borderColor: Theme.of(context).colorScheme.primary,
        borderRadius: 12,
        borderLength: 32,
        borderWidth: 8,
        cutOutSize: 260,
      ),
      onQRViewCreated: (controller) {
        controller.scannedDataStream.listen((b) {
          final code = b.code;
          if (_done || code == null) return;
          try {
            SpaceInviteLink.parse(code);
          } on FormatException {
            return;
          }
          _done = true;
          controller.pauseCamera();
          if (context.mounted) Navigator.of(context).pop(code);
        });
      },
    ),
  );
}
