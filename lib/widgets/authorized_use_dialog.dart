import 'package:flutter/material.dart';

import '../services/authorized_use_consent_service.dart';

/// First-run dialog for authorized network tool use.
class AuthorizedUseDialog extends StatefulWidget {
  const AuthorizedUseDialog({super.key});

  static Future<bool> showIfNeeded(BuildContext context) async {
    final consent = AuthorizedUseConsentService();
    if (await consent.hasConsent()) return true;

    if (!context.mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AuthorizedUseDialog(),
    );
    return accepted ?? false;
  }

  @override
  State<AuthorizedUseDialog> createState() => _AuthorizedUseDialogState();
}

class _AuthorizedUseDialogState extends State<AuthorizedUseDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Authorized Use Required'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'NetTool performs network discovery, port scanning, and bandwidth '
              'tests. Only use these features on networks and systems you own or '
              'have explicit written permission to test.',
            ),
            const SizedBox(height: 12),
            Text(
              'Unauthorized scanning may violate local laws, contracts, or '
              'acceptable-use policies. You are responsible for how you use this app.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acknowledged,
              onChanged: (value) => setState(() => _acknowledged = value ?? false),
              title: const Text('I confirm I am authorized to run these tests'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _acknowledged
              ? () async {
                  await AuthorizedUseConsentService().grantConsent();
                  if (context.mounted) Navigator.of(context).pop(true);
                }
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
