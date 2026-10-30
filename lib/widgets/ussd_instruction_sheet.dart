import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/ussd_dialer.dart';

/// Opens the dialer, then asks the user to confirm. Returns true only when the
/// user confirms the transaction.
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
            Text(
              sheetContext.tr('ussd.instructions'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFF4F7FB), fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: Text(sheetContext.tr('ussd.completed_button')),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text(sheetContext.tr('ussd.cancel_button')),
            ),
          ],
        ),
      ),
    ),
  );
  return completed == true;
}
