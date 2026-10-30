import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/wallet_state.dart';

/// Shows the merchant number to pay for the selected Zaad or eDahab source.
/// [source] is `zaad` or `edahab` (case-insensitive); other values render nothing.
class MerchantNumberCard extends StatelessWidget {
  const MerchantNumberCard({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final key = source.toLowerCase();
    if (key != 'zaad' && key != 'edahab') return const SizedBox.shrink();
    final number = context.select<WalletState, String>(
      (wallet) => wallet.merchantNumberFor(key),
    );
    if (number.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Color(0xFF00E676)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('merchant.${key}_instruction', {'number': number}),
              style: const TextStyle(
                color: Color(0xFFF4F7FB),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr('merchant.copy'),
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final message = context.trRead('merchant.copied');
              await Clipboard.setData(ClipboardData(text: number));
              messenger.showSnackBar(SnackBar(content: Text(message)));
            },
          ),
        ],
      ),
    );
  }
}
