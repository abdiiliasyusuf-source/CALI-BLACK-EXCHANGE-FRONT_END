import 'package:flutter/material.dart';

import '../services/ussd_dialer.dart';

/// Opens the dialer, then asks the user to confirm. Returns true only when the
/// user taps "I Have Completed Transaction".
Future<bool> runUssdTransaction(
  BuildContext context, {
  required UssdProvider provider,
  required num amount,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await launchUssdDialer(
      provider: provider,
      merchantNumber: ussdMerchantNumbers[provider]!,
      amount: amount,
    );
  } on UssdDialerException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  }
  if (!context.mounted) return false;

  final completed = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: const Color(0xFF161B26),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.dialpad_rounded, size: 36, color: Color(0xFF00E676)),
            const SizedBox(height: 14),
            const Text(
              "We've opened your dialer with your transaction code. Please "
              'complete the prompt on your screen, enter your PIN, and tap '
              'below once finished.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFF4F7FB), fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('I Have Completed Transaction'),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  return completed == true;
}
