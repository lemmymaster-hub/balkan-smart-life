import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../controllers/wallet_demo_controller.dart';
import '../models/wallet_demo_models.dart';
import '../models/wallet_service.dart';
import '../services/wallet_biometric_auth_service.dart';
import '../widgets/wallet_add_demo_card_sheet.dart';
import '../widgets/wallet_connection_card.dart';
import '../widgets/wallet_demo_payment_card.dart';
import '../widgets/wallet_demo_payment_sheet.dart';
import '../widgets/wallet_pay_anywhere_card.dart';
import '../widgets/wallet_quick_service_card.dart';
import '../widgets/wallet_security_card.dart';
import '../widgets/wallet_transaction_tile.dart';
import 'wallet_demo_capture_screen.dart';

class WalletHomeScreen extends StatefulWidget {
  final WalletDemoController? demoController;
  final String? demoUserId;
  final String? demoUserEmail;
  final WalletBiometricAuthenticator? biometricAuthenticator;

  const WalletHomeScreen({
    super.key,
    this.demoController,
    this.demoUserId,
    this.demoUserEmail,
    this.biometricAuthenticator,
  });

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  late final WalletDemoController _controller;
  late final bool _ownsController;
  late final WalletBiometricAuthenticator _biometricAuthenticator;
  final PageController _cardPageController = PageController(
    viewportFraction: 0.93,
  );

  _WalletHistoryFilter _historyFilter = _WalletHistoryFilter.all;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.demoController == null;
    _controller = widget.demoController ?? WalletDemoController();
    _biometricAuthenticator =
        widget.biometricAuthenticator ??
        LocalAuthWalletBiometricAuthenticator();
    _controller.addListener(_handleControllerChanged);
    unawaited(_initializeDemo());
  }

  String get _demoUserId {
    return widget.demoUserId ??
        FirebaseAuth.instance.currentUser?.uid ??
        'guest';
  }

  String get _demoUserEmail {
    return widget.demoUserEmail ??
        FirebaseAuth.instance.currentUser?.email ??
        '';
  }

  Future<void> _initializeDemo() async {
    try {
      await _controller.initialize(userId: _demoUserId);
      if (mounted && _initializationError != null) {
        setState(() => _initializationError = null);
      }
    } catch (error, stackTrace) {
      debugPrint('BSL WALLET DEMO INIT ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _initializationError = error);
    }
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    _cardPageController.dispose();
    super.dispose();
  }

  List<WalletDemoCard> get _displayCards {
    final cards = List<WalletDemoCard>.of(_controller.cards);
    cards.sort((first, second) {
      if (first.isDefault == second.isDefault) return 0;
      return first.isDefault ? -1 : 1;
    });
    return cards;
  }

  List<WalletDemoTransaction> get _filteredTransactions {
    final transactions = _controller.transactions;
    switch (_historyFilter) {
      case _WalletHistoryFilter.all:
        return transactions;
      case _WalletHistoryFilter.services:
        return transactions
            .where(
              (transaction) =>
                  transaction.category == WalletTransactionCategory.bslService,
            )
            .toList(growable: false);
      case _WalletHistoryFilter.merchants:
        return transactions
            .where(
              (transaction) =>
                  transaction.category == WalletTransactionCategory.merchant,
            )
            .toList(growable: false);
      case _WalletHistoryFilter.parking:
        return transactions
            .where(
              (transaction) =>
                  transaction.category ==
                  WalletTransactionCategory.parkingMachine,
            )
            .toList(growable: false);
    }
  }

  Future<void> _addDemoCard() async {
    final draft = await showModalBottomSheet<WalletDemoCardDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          WalletAddDemoCardSheet(initialEmail: _demoUserEmail),
    );

    if (!mounted || draft == null) return;

    await _controller.addCard(draft);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo token kartice je dodat. Nema stvarne autorizacije.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _manageCard(WalletDemoCard card) async {
    final action = await showModalBottomSheet<_CardAction>(
      context: context,
      backgroundColor: const Color(0xFF0B1225),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${card.brandLabel} •••• ${card.last4}',
                  style: const TextStyle(color: BslColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (!card.isDefault)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: BslColors.cyan,
                    ),
                    title: const Text(
                      'Postavi kao zadanu',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () =>
                        Navigator.pop(sheetContext, _CardAction.setDefault),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: BslColors.danger,
                  ),
                  title: const Text(
                    'Ukloni demo karticu',
                    style: TextStyle(color: BslColors.danger),
                  ),
                  onTap: () => Navigator.pop(sheetContext, _CardAction.remove),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == _CardAction.setDefault) {
      await _controller.setDefaultCard(card.id);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A33),
        title: const Text('Ukloniti demo karticu?'),
        content: Text(
          'Kartica ${card.maskedNumber} bit će uklonjena samo iz lokalnog demo prikaza.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await _controller.removeCard(card.id);
  }

  Future<void> _startServicePayment(WalletService service) async {
    final request = _requestForService(service);
    await _openPaymentConfirmation(request);
  }

  Future<void> _startCapturePayment(WalletDemoCaptureMode mode) async {
    final request = await Navigator.push<WalletDemoPaymentRequest>(
      context,
      MaterialPageRoute(
        builder: (context) => WalletDemoCaptureScreen(mode: mode),
      ),
    );

    if (!mounted || request == null) return;
    await _openPaymentConfirmation(request);
  }

  Future<void> _openPaymentConfirmation(
    WalletDemoPaymentRequest request,
  ) async {
    if (_controller.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prvo dodaj demo karticu za simulaciju plaćanja.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _addDemoCard();
      return;
    }

    final cardId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WalletDemoPaymentSheet(
        request: request,
        cards: _controller.cards,
        initialCardId: _controller.defaultCard?.id,
      ),
    );

    if (!mounted || cardId == null) return;

    final biometricResult = await _biometricAuthenticator.authenticate(
      localizedReason:
          'Potvrdi BSL plaćanje ${request.amount.toStringAsFixed(2)} KM za '
          '${request.title}.',
    );

    if (!mounted) return;
    if (!biometricResult.isAuthenticated) {
      await _showBiometricFailure(biometricResult);
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PaymentProcessingDialog(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 900));

    WalletDemoTransaction? transaction;
    Object? paymentError;
    try {
      transaction = await _controller.recordPayment(
        request: request,
        cardId: cardId,
      );
    } catch (error) {
      paymentError = error;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (paymentError != null || transaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentError?.toString() ?? 'Demo plaćanje nije uspjelo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _showReceipt(transaction);
  }

  Future<void> _showBiometricFailure(WalletBiometricAuthResult result) async {
    if (result.wasCanceled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.title}. ${result.message}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A33),
        icon: const Icon(
          Icons.fingerprint_outlined,
          color: BslColors.warning,
          size: 38,
        ),
        title: Text(result.title),
        content: Text(result.message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Razumijem'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReceipt(WalletDemoTransaction transaction) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DemoReceipt(transaction: transaction),
    );
  }

  Future<void> _showSecurityDetails() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1225),
      showDragHandle: true,
      builder: (context) => const _WalletSecuritySheet(),
    );
  }

  Future<void> _resetDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111A33),
        title: const Text('Vratiti početni demo?'),
        content: const Text(
          'Dodatne demo kartice i nove simulirane transakcije bit će uklonjene.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Vrati demo'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await _controller.resetDemo();
  }

  WalletDemoPaymentRequest _requestForService(WalletService service) {
    switch (service.id) {
      case 'parking':
        return const WalletDemoPaymentRequest(
          id: 'parking_service_demo',
          title: 'Parkiraj.ba',
          subtitle: 'Parking Skenderija • 1 sat',
          amount: 2,
          category: WalletTransactionCategory.bslService,
        );
      case 'ev_charging':
        return const WalletDemoPaymentRequest(
          id: 'ev_service_demo',
          title: 'EL punjači',
          subtitle: 'Završena demo sesija • 11.8 kWh',
          amount: 18.40,
          category: WalletTransactionCategory.bslService,
        );
      case 'taxi':
        return const WalletDemoPaymentRequest(
          id: 'taxi_service_demo',
          title: 'BSL Taxi',
          subtitle: 'Vožnja završena • 6.4 km',
          amount: 12.50,
          category: WalletTransactionCategory.bslService,
        );
      default:
        return const WalletDemoPaymentRequest(
          id: 'bill_service_demo',
          title: 'Plati račun',
          subtitle: 'Demo račun komunalne usluge',
          amount: 48.90,
          category: WalletTransactionCategory.bslService,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BslColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BSL Novčanik',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              'Interni investicijski demo',
              style: TextStyle(color: BslColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sigurnost',
            onPressed: _showSecurityDetails,
            icon: const Icon(Icons.shield_rounded, color: BslColors.success),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF111A33),
            onSelected: (value) {
              if (value == 'reset') unawaited(_resetDemo());
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: BslColors.cyan),
                    SizedBox(width: 9),
                    Text('Vrati početni demo'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -90,
            child: _GlowOrb(size: 230, color: Color(0x292FE6FF)),
          ),
          const Positioned(
            top: 430,
            left: -110,
            child: _GlowOrb(size: 230, color: Color(0x247B61FF)),
          ),
          if (_initializationError != null)
            _WalletInitializationError(onRetry: _initializeDemo)
          else if (!_controller.isInitialized)
            const Center(
              child: CircularProgressIndicator(color: BslColors.cyan),
            )
          else
            _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final cards = _displayCards;
    final transactions = _filteredTransactions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(17, 8, 17, 34),
      children: [
        const _DemoModeBanner(),
        const SizedBox(height: 20),
        const _WalletHero(),
        const SizedBox(height: 18),
        _SectionHeader(
          title: 'Moje kartice',
          subtitle: '${cards.length} demo tokena',
          actionLabel: 'Dodaj',
          onAction: _addDemoCard,
        ),
        const SizedBox(height: 9),
        if (cards.isEmpty)
          WalletConnectionCard(onAddCard: _addDemoCard)
        else
          SizedBox(
            height: 236,
            child: PageView.builder(
              key: const ValueKey('wallet-card-carousel'),
              controller: _cardPageController,
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return WalletDemoPaymentCard(
                  card: card,
                  onManage: () => unawaited(_manageCard(card)),
                );
              },
            ),
          ),
        const SizedBox(height: 22),
        const _SectionHeader(
          title: 'Brzo plaćanje',
          subtitle: 'BSL gradske usluge',
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 330;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: WalletServices.values.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: singleColumn ? 1 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: singleColumn ? 2.25 : 0.95,
              ),
              itemBuilder: (context, index) {
                final service = WalletServices.values[index];
                return WalletQuickServiceCard(
                  service: service,
                  onTap: () => unawaited(_startServicePayment(service)),
                );
              },
            );
          },
        ),
        const SizedBox(height: 22),
        WalletPayAnywhereCard(
          onScanMerchantQr: () =>
              unawaited(_startCapturePayment(WalletDemoCaptureMode.merchantQr)),
          onScanParkingMachine: () =>
              unawaited(_startCapturePayment(WalletDemoCaptureMode.parkingQr)),
          onNfcPayment: () =>
              unawaited(_startCapturePayment(WalletDemoCaptureMode.nfc)),
        ),
        const SizedBox(height: 22),
        const _SectionHeader(
          title: 'Istorija transakcija',
          subtitle: 'Lokalni demo zapisi',
        ),
        const SizedBox(height: 9),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _WalletHistoryFilter.values
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: _historyFilter == filter,
                      onSelected: (_) =>
                          setState(() => _historyFilter = filter),
                      selectedColor: BslColors.cyan.withValues(alpha: 0.18),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      side: BorderSide(
                        color: _historyFilter == filter
                            ? BslColors.cyan
                            : Colors.white.withValues(alpha: 0.09),
                      ),
                      labelStyle: TextStyle(
                        color: _historyFilter == filter
                            ? BslColors.cyan
                            : Colors.white60,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      checkmarkColor: BslColors.cyan,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          const _EmptyHistory()
        else
          ...transactions.map(
            (transaction) => WalletTransactionTile(transaction: transaction),
          ),
        const SizedBox(height: 18),
        WalletSecurityCard(onTap: _showSecurityDetails),
        const SizedBox(height: 14),
        const _WalletRoadmapCard(),
      ],
    );
  }
}

enum _CardAction { setDefault, remove }

enum _WalletHistoryFilter { all, services, merchants, parking }

extension on _WalletHistoryFilter {
  String get label {
    switch (this) {
      case _WalletHistoryFilter.all:
        return 'Sve';
      case _WalletHistoryFilter.services:
        return 'BSL usluge';
      case _WalletHistoryFilter.merchants:
        return 'Prodavnice';
      case _WalletHistoryFilter.parking:
        return 'Parking aparati';
    }
  }
}

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: BslColors.warning.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(BslRadius.small),
        border: Border.all(color: BslColors.warning.withValues(alpha: 0.30)),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_rounded, color: BslColors.warning, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'BSL WALLET DEMO • nema stvarne naplate • ne unosite stvarnu karticu',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHero extends StatelessWidget {
  const _WalletHero();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grad plaćaš jednim dodirom.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'U produkciji se kartica tokenizuje jednom, a parking, punjenje, '
          'taxi, računi i kupovina potvrđuju se iz BSL-a. Novčanik ne čuva '
          'saldo.',
          style: TextStyle(
            color: BslColors.textSecondary,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _PaymentProcessingDialog extends StatelessWidget {
  const _PaymentProcessingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      backgroundColor: Color(0xFF111A33),
      content: Row(
        children: [
          CircularProgressIndicator(color: BslColors.cyan),
          SizedBox(width: 18),
          Expanded(
            child: Text(
              'Simuliram sigurnu potvrdu...',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoReceipt extends StatelessWidget {
  final WalletDemoTransaction transaction;

  const _DemoReceipt({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        decoration: const BoxDecoration(
          color: Color(0xFF0B1225),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0x2635D07F),
              child: Icon(
                Icons.check_rounded,
                color: BslColors.success,
                size: 41,
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              'Demo plaćanje uspješno',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              transaction.title,
              style: const TextStyle(color: BslColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              '${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
              style: const TextStyle(
                color: BslColors.cyan,
                fontSize: 33,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Demo kartica •••• ${transaction.cardLast4}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: BslColors.success,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Identitet potvrđen biometrijom uređaja',
                  style: TextStyle(color: BslColors.success, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: BslColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(BslRadius.small),
              ),
              child: const Text(
                'Ovo je simulirani račun. Novac nije naplaćen niti je zahtjev poslan banci.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BslColors.warning, fontSize: 10.5),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: BslButtons.primary(),
                child: const Text('Završi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSecuritySheet extends StatelessWidget {
  const _WalletSecuritySheet();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sigurnosni model BSL Novčanika',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 13),
            _SecurityPoint(
              icon: Icons.credit_card_off_rounded,
              text: 'Puni broj kartice i CVV se ne čuvaju u BSL-u.',
            ),
            _SecurityPoint(
              icon: Icons.token_rounded,
              text: 'Payment provider vraća token i maskirani broj.',
            ),
            _SecurityPoint(
              icon: Icons.fingerprint_rounded,
              text:
                  'Demo plaćanje zahtijeva stvarnu sistemsku biometrijsku '
                  'potvrdu uređaja.',
            ),
            _SecurityPoint(
              icon: Icons.visibility_off_rounded,
              text:
                  'BSL ne dobija sliku otiska niti pristup biometrijskim '
                  'podacima.',
            ),
            _SecurityPoint(
              icon: Icons.dns_rounded,
              text: 'Tajni ključevi ostaju isključivo na BSL backendu.',
            ),
            _SecurityPoint(
              icon: Icons.contactless_rounded,
              text:
                  'Pravi NFC zahtijeva certificirani EMV/payment partnerski tok.',
            ),
            SizedBox(height: 8),
            Text(
              'Trenutna verzija je interni UI/UX demo i ne komunicira s bankom, trgovcem ili terminalom.',
              style: TextStyle(
                color: BslColors.warning,
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SecurityPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, color: BslColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletRoadmapCard extends StatelessWidget {
  const _WalletRoadmapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(BslRadius.medium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: BslColors.purple),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sljedeće: BSL City Card i P2P',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Pretplatne gradske usluge i transferi dolaze nakon payment i pravne integracije.',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(BslRadius.medium),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_rounded, color: Colors.white30, size: 34),
          SizedBox(height: 8),
          Text(
            'Nema transakcija u ovom filteru',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 18)],
      ),
    );
  }
}

class _WalletInitializationError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _WalletInitializationError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: BslColors.danger),
            const SizedBox(height: 10),
            const Text(
              'Demo novčanik nije mogao biti učitan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }
}
