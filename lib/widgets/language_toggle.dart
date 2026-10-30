import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_state.dart';

/// Switches the whole app between English and Somali.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isSomali = context.select<WalletState, bool>((w) => w.isSomali);
    return TextButton.icon(
      onPressed: context.read<WalletState>().toggleLanguage,
      icon: const Icon(Icons.language_rounded, size: 17),
      label: Text(isSomali ? 'Soomaali 🇸🇴' : 'English 🇬🇧'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF00E676),
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
