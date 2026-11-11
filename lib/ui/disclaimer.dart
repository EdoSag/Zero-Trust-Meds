import 'package:flutter/material.dart';

import 'common.dart';

/// "Not medical advice": shown once before the app opens, and from
/// Settings any time.
class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key, this.readOnly = false, this.onAccept});
  final bool readOnly;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: readOnly ? AppBar(title: Text(l.disclaimerTitle)) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!readOnly) ...[
              const SizedBox(height: 24),
              Icon(
                Icons.health_and_safety_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l.disclaimerTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
            Text(l.disclaimerBody1),
            const SizedBox(height: 12),
            Text(l.disclaimerBody2),
            const SizedBox(height: 12),
            Text(l.disclaimerBody3),
            const SizedBox(height: 12),
            Text(l.disclaimerBody4),
            if (!readOnly) ...[
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onAccept,
                child: Text(l.disclaimerAccept),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
