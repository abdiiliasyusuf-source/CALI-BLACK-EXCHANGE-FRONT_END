// ignore_for_file: prefer_single_quotes

const Map<String, String> enWallet = {
  'deposit.submitting': 'Submitting securely…',
  'deposit.crypto_success':
      'Crypto deposit submitted and marked pending approval.',
  'deposit.betting_success':
      '{gateway} deposit submitted as pending. Reference: {reference}',
  'deposit.mobile_success':
      'Mobile money deposit request submitted as pending.',
  'deposit.invalid_input': 'Invalid input.',
  'deposit.invalid_amount': 'Enter a valid amount.',
  'deposit.minimum_amount': 'Minimum deposit is \$1.00 USD.',
  'deposit.maximum_amount': 'Enter an amount below \$1,000,000.',
  'deposit.enter_tx_hash': 'Enter the transaction hash.',
  'deposit.invalid_tx_hash':
      'Transaction hash must be 64 hexadecimal characters.',
  'deposit.invalid_player_id': 'Enter a valid player account ID.',
  'deposit.title': 'Wallet deposit',
  'deposit.details_title': 'Deposit details',
  'deposit.details_description':
      'Enter an amount and choose how to fund your wallet.',
  'deposit.amount_label': 'Amount (USD)',
  'deposit.crypto_amount_helper':
      'Verified deposits are credited to your Cali Black Exchange wallet balance.',
  'deposit.amount_helper': 'Minimum deposit: \$1.00 USD.',
  'deposit.player_id_label': '{gateway} User ID',
  'deposit.player_id_hint': 'Enter your betting account ID',
  'deposit.crypto_asset_label': 'Crypto asset',
  'deposit.tx_hash_label': 'Transaction Hash (TxHash)',
  'deposit.tx_hash_hint': 'Paste the 64-character transaction hash',
  'deposit.tx_hash_helper':
      'Use the transaction hash to verify the deposit to your Cali Black Exchange wallet.',
  'deposit.payment_method': 'PAYMENT METHOD',
  'deposit.funding_source': 'PAY 1XBET WITH',
  'deposit.zaad_subtitle': 'Zaad Mobile Money',
  'deposit.edahab_subtitle': 'eDahab Mobile Money',
  'deposit.betting_subtitle': 'Betting account deposit',
  'deposit.crypto_method_title': 'Crypto (USDT / USDC)',
  'deposit.crypto_subtitle': 'Crypto deposit',
  'deposit.submit_crypto': 'Submit Crypto Deposit',
  'deposit.submit_gateway': 'Submit {gateway} Deposit',
  'deposit.pay_edahab': 'Pay with eDahab',
  'deposit.pay_zaad': 'Pay with ZAAD',
  'deposit.crypto_footer':
      'Crypto deposits remain pending until transaction verification.',
  'deposit.betting_footer':
      'Betting deposits are processed securely by the cashier service.',
  'deposit.mobile_footer': 'Wallet deposits are recorded as pending requests.',
  'deposit.header_title': 'Secure Wallet Deposit Center',
  'deposit.secure_badge': 'CALI BLACK EXCHANGE · SECURE DEPOSIT',
  'deposit.header_description':
      'Add funds to your Cali Black Exchange wallet using a supported provider.',
  'withdrawal.invalid_amount': 'Enter a valid withdrawal amount.',
  'withdrawal.minimum_amount': 'Minimum withdrawal is \$1.00 USD.',
  'withdrawal.insufficient_balance':
      'Amount exceeds your available USD balance.',
  'withdrawal.invalid_tron_address': 'Enter a valid TRON (TRC-20) address.',
  'withdrawal.invalid_bep20_address':
      'Enter a valid BNB Smart Chain (BEP-20) address.',
  'withdrawal.processing': 'Processing withdrawal securely…',
  'withdrawal.success':
      'Withdrawal submitted. Your USD balance was updated.',
  'withdrawal.invalid_input': 'Invalid input.',
  'withdrawal.title': 'Crypto withdrawal',
  'withdrawal.header_title': 'Withdraw to crypto',
  'withdrawal.header_description':
      'Review the network and wallet address carefully before submitting.',
  'withdrawal.available_balance': 'Available USD balance',
  'withdrawal.asset_label': 'Crypto asset and network',
  'withdrawal.amount_label': 'Amount (USD)',
  'withdrawal.amount_helper': 'Minimum withdrawal: \$1.00 USD.',
  'withdrawal.address_label': 'Destination wallet address',
  'withdrawal.tron_address_hint': 'TRON address starting with T',
  'withdrawal.bep20_address_hint': 'BEP-20 address starting with 0x',
  'withdrawal.tron_address_helper':
      'USDT withdrawals use the TRC-20 network.',
  'withdrawal.bep20_address_helper':
      'USDC withdrawals use the BEP-20 network.',
  'withdrawal.submit': 'Submit Crypto Withdrawal',
  'ussd.instructions':
      "We've opened your dialer with your transaction code. Please "
      'complete the prompt on your screen, enter your PIN, and tap '
      'below once finished.',
  'ussd.completed_button': 'I Have Completed Transaction',
  'ussd.cancel_button': 'Cancel',
};

const Map<String, String> soWallet = {
  'deposit.submitting': 'Si ammaan ah ayaa loo gudbinayaa…',
  'deposit.crypto_success':
      'Codsiga dhigashada Crypto waa la gudbiyey, wuxuuna sugayaa oggolaansho.',
  'deposit.betting_success':
      'Dhigashada {gateway} waa la gudbiyey, waxayna sugaysaa xaqiijin. Tixraac: {reference}',
  'deposit.mobile_success':
      'Codsiga dhigashada lacagta moobilka waa la gudbiyey, wuxuuna sugayaa xaqiijin.',
  'deposit.invalid_input': 'Xogta la geliyey sax ma aha.',
  'deposit.invalid_amount': 'Geli lacag sax ah.',
  'deposit.minimum_amount': 'Dhigashada ugu yar waa \$1.00 USD.',
  'deposit.maximum_amount': 'Geli lacag ka yar \$1,000,000.',
  'deposit.enter_tx_hash': 'Geli summada macaamilka (transaction hash).',
  'deposit.invalid_tx_hash':
      'Summada macaamilku waa inay ka koobnaataa 64 xaraf oo hexadecimal ah.',
  'deposit.invalid_player_id': 'Geli aqoonsi akoon ciyaaryahan oo sax ah.',
  'deposit.title': 'Lacag ku shub boorsada',
  'deposit.details_title': 'Faahfaahinta dhigashada',
  'deposit.details_description':
      'Geli lacagta, kadibna dooro habka aad boorsadaada ugu shubayso.',
  'deposit.amount_label': 'Lacagta (USD)',
  'deposit.crypto_amount_helper':
      'Dhigashada la xaqiijiyey waxaa lagu daraa hadhaaga boorsadaada Cali Black Exchange.',
  'deposit.amount_helper': 'Dhigashada ugu yar: \$1.00 USD.',
  'deposit.player_id_label': 'Aqoonsiga isticmaalaha {gateway}',
  'deposit.player_id_hint': 'Geli aqoonsiga akoonkaaga sharadka',
  'deposit.crypto_asset_label': 'Hantida Crypto',
  'deposit.tx_hash_label': 'Summada macaamilka (TxHash)',
  'deposit.tx_hash_hint': 'Ku dheji summada macaamilka oo ka kooban 64 xaraf',
  'deposit.tx_hash_helper':
      'Isticmaal summada macaamilka si loo xaqiijiyo dhigashada boorsadaada Cali Black Exchange.',
  'deposit.payment_method': 'HABKA LACAG-BIXINTA',
  'deposit.funding_source': 'KU BIXI 1XBET',
  'deposit.zaad_subtitle': 'Zaad – lacagta moobilka',
  'deposit.edahab_subtitle': 'eDahab – lacagta moobilka',
  'deposit.betting_subtitle': 'Dhigasho akoon sharad',
  'deposit.crypto_method_title': 'Crypto (USDT / USDC)',
  'deposit.crypto_subtitle': 'Dhigasho Crypto',
  'deposit.submit_crypto': 'Gudbi Dhigashada Crypto',
  'deposit.submit_gateway': 'Gudbi Dhigashada {gateway}',
  'deposit.pay_edahab': 'Ku bixi eDahab',
  'deposit.pay_zaad': 'Ku bixi ZAAD',
  'deposit.crypto_footer':
      'Dhigashada Crypto waxay sugaysaa xaqiijinta macaamilka.',
  'deposit.betting_footer':
      'Dhigashada sharadka waxaa si ammaan ah u maamula adeegga lacag-qabaha.',
  'deposit.mobile_footer':
      'Dhigashada boorsada waxaa loo diiwaangeliyaa codsi sugaya xaqiijin.',
  'deposit.header_title': 'Xarunta Dhigashada Boorsada ee Ammaan ah',
  'deposit.secure_badge': 'CALI BLACK EXCHANGE · DHIGASHO AMMAAN AH',
  'deposit.header_description':
      'Ku shubo boorsadaada Cali Black Exchange adigoo adeegsanaya adeeg-bixiye la taageero.',
  'withdrawal.invalid_amount': 'Geli lacag bixitaan oo sax ah.',
  'withdrawal.minimum_amount': 'Bixitaanka ugu yar waa \$1.00 USD.',
  'withdrawal.insufficient_balance':
      'Lacagtu waxay ka badan tahay hadhaaga USD ee kuu bannaan.',
  'withdrawal.invalid_tron_address': 'Geli cinwaan TRON (TRC-20) oo sax ah.',
  'withdrawal.invalid_bep20_address':
      'Geli cinwaan BNB Smart Chain (BEP-20) oo sax ah.',
  'withdrawal.processing': 'Bixitaanka si ammaan ah ayaa loo farsamaynayaa…',
  'withdrawal.success':
      'Codsiga bixitaanka waa la gudbiyey. Hadhaagaaga USD waa la cusboonaysiiyey.',
  'withdrawal.invalid_input': 'Xogta la geliyey sax ma aha.',
  'withdrawal.title': 'Lacag kala bax Crypto',
  'withdrawal.header_title': 'U dir boorso Crypto',
  'withdrawal.header_description':
      'Si taxaddar leh u hubi shabakadda iyo cinwaanka boorsada ka hor intaadan gudbin.',
  'withdrawal.available_balance': 'Hadhaaga USD ee kuu bannaan',
  'withdrawal.asset_label': 'Hantida Crypto iyo shabakadda',
  'withdrawal.amount_label': 'Lacagta (USD)',
  'withdrawal.amount_helper': 'Bixitaanka ugu yar: \$1.00 USD.',
  'withdrawal.address_label': 'Cinwaanka boorsada loo dirayo',
  'withdrawal.tron_address_hint': 'Cinwaanka TRON ee ka bilaabma T',
  'withdrawal.bep20_address_hint': 'Cinwaanka BEP-20 ee ka bilaabma 0x',
  'withdrawal.tron_address_helper':
      'Bixitaanka USDT wuxuu adeegsadaa shabakadda TRC-20.',
  'withdrawal.bep20_address_helper':
      'Bixitaanka USDC wuxuu adeegsadaa shabakadda BEP-20.',
  'withdrawal.submit': 'Gudbi Bixitaanka Crypto',
  'ussd.instructions':
      'Waxaan furnay garaacaha taleefanka oo wata koodhka macaamilkaaga. Fadlan '
      'raac tilmaamaha shaashadda, geli PIN-kaaga, kadibna taabo '
      'badhanka hoose markaad dhammayso.',
  'ussd.completed_button': 'Waan Dhammaystiray Macaamilka',
  'ussd.cancel_button': 'Jooji',
};
