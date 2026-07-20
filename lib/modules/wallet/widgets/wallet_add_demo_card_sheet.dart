import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/bsl_design_system.dart';
import '../models/wallet_demo_models.dart';
import '../services/wallet_card_validator.dart';

class WalletAddDemoCardSheet extends StatefulWidget {
  final String initialEmail;

  const WalletAddDemoCardSheet({super.key, required this.initialEmail});

  @override
  State<WalletAddDemoCardSheet> createState() => _WalletAddDemoCardSheetState();
}

class _WalletAddDemoCardSheetState extends State<WalletAddDemoCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _holderController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _detailsAccepted = false;
  bool _verificationStep = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _fillDemoData(_DemoCardPreset preset) {
    final isVisa = preset == _DemoCardPreset.visa;
    setState(() {
      _nicknameController.text = isVisa
          ? 'Moja demo Visa'
          : 'Moja demo Mastercard';
      _holderController.text = 'BSL DEMO KORISNIK';
      _numberController.text = isVisa
          ? '4242 4242 4242 4242'
          : '5555 5555 5555 4444';
      _expiryController.text = '12/30';
      _cvvController.text = '123';
      _phoneController.text = '+387 61 123 456';
      if (_emailController.text.trim().isEmpty) {
        _emailController.text = 'demo@bsl.app';
      }
      _detailsAccepted = true;
    });
  }

  void _continueToVerification() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (!_detailsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Potvrdi da koristiš isključivo demo podatke.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _verificationStep = true);
  }

  void _finishDemoVerification() {
    if (_otpController.text.trim() != '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Za demo verifikaciju unesi kod 123456.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final digits = WalletCardValidator.digitsOnly(_numberController.text);
    final expiry = WalletCardValidator.parseExpiry(_expiryController.text);
    if (digits.length < 4 || expiry == null) return;

    final draft = WalletDemoCardDraft(
      nickname: _nicknameController.text.trim(),
      holderName: _holderController.text.trim(),
      last4: digits.substring(digits.length - 4),
      brand: WalletCardValidator.brandFor(digits),
      expiryMonth: expiry.month,
      expiryYear: expiry.year,
    );

    // Puni broj kartice, CVV i demo OTP se nikada ne vraćaju kontroleru
    // niti upisuju u lokalnu pohranu.
    _numberController.clear();
    _cvvController.clear();
    _otpController.clear();
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0B1225),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            child: AnimatedSwitcher(
              duration: BslDurations.normal,
              child: _verificationStep
                  ? _buildVerificationStep()
                  : _buildDetailsStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('wallet-demo-card-details'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          _SheetTitle(
            icon: Icons.add_card_rounded,
            title: 'Dodaj demo karticu',
            subtitle: 'Prikaz budućeg sigurnog procesa tokenizacije',
            onClose: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          const _DemoWarning(),
          const SizedBox(height: 13),
          const Text(
            'Brzi testni podaci',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('wallet-fill-demo-visa'),
                onPressed: () => _fillDemoData(_DemoCardPreset.visa),
                icon: const Icon(Icons.credit_card_rounded, size: 17),
                label: const Text('Demo Visa'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('wallet-fill-demo-mastercard'),
                onPressed: () => _fillDemoData(_DemoCardPreset.mastercard),
                icon: const Icon(Icons.credit_card_rounded, size: 17),
                label: const Text('Demo Mastercard'),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _WalletTextField(
            controller: _nicknameController,
            label: 'Naziv kartice',
            hint: 'Lična, poslovna, porodična...',
            icon: Icons.label_outline_rounded,
            validator: (value) => _required(value, 'Unesi naziv kartice.'),
          ),
          _WalletTextField(
            controller: _holderController,
            label: 'Ime vlasnika kartice',
            hint: 'Kao što je napisano na kartici',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.characters,
            validator: (value) => _required(value, 'Unesi ime vlasnika.'),
          ),
          _WalletTextField(
            key: const ValueKey('wallet-demo-card-number'),
            controller: _numberController,
            label: 'Broj testne kartice',
            hint: '4242 4242 4242 4242',
            icon: Icons.credit_card_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: const [_CardNumberFormatter()],
            validator: (value) {
              final number = value ?? '';
              if (!WalletCardValidator.isValidNumber(number)) {
                return 'Unesi ispravan demo broj kartice.';
              }
              if (!WalletCardValidator.isSupportedDemoNumber(number)) {
                return 'Dozvoljeni su samo ponuđeni testni brojevi.';
              }
              return null;
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _WalletTextField(
                  controller: _expiryController,
                  label: 'Važi do',
                  hint: 'MM/GG',
                  icon: Icons.calendar_month_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_ExpiryFormatter()],
                  validator: (value) =>
                      WalletCardValidator.isValidExpiry(value ?? '')
                      ? null
                      : 'Neispravan datum.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletTextField(
                  key: const ValueKey('wallet-demo-card-cvv'),
                  controller: _cvvController,
                  label: 'CVV demo',
                  hint: '123',
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (value) =>
                      WalletCardValidator.isValidCvv(value ?? '')
                      ? null
                      : '3 ili 4 cifre.',
                ),
              ),
            ],
          ),
          _WalletTextField(
            controller: _phoneController,
            label: 'Telefon za 3-D Secure',
            hint: '+387 61 123 456',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            validator: (value) =>
                (value ?? '').trim().length >= 8 ? null : 'Unesi demo telefon.',
          ),
          _WalletTextField(
            controller: _emailController,
            label: 'Email za potvrdu',
            hint: 'demo@bsl.app',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) => (value ?? '').contains('@')
                ? null
                : 'Unesi ispravan demo email.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _detailsAccepted,
            activeColor: BslColors.cyan,
            checkColor: BslColors.bgDark,
            onChanged: (value) {
              setState(() => _detailsAccepted = value ?? false);
            },
            title: const Text(
              'Koristim samo testne podatke',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'Ne unosim podatke stvarne platne kartice.',
              style: TextStyle(color: Colors.white54, fontSize: 10.5),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('wallet-card-continue'),
              onPressed: _continueToVerification,
              style: BslButtons.primary(),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Nastavi na demo 3-D Secure'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep() {
    return Column(
      key: const ValueKey('wallet-demo-verification'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetHandle(),
        _SheetTitle(
          icon: Icons.verified_user_rounded,
          title: '3-D Secure potvrda',
          subtitle: 'Simulacija bankarske provjere identiteta',
          onClose: () => Navigator.pop(context),
        ),
        const SizedBox(height: 22),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: BslColors.cyan.withValues(alpha: 0.11),
              shape: BoxShape.circle,
              border: Border.all(color: BslColors.cyan.withValues(alpha: 0.42)),
              boxShadow: BslShadows.cyanGlow(alpha: 0.12),
            ),
            child: const Icon(
              Icons.sms_rounded,
              color: BslColors.cyan,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Demo kod je poslan na uneseni broj telefona.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Za ovu demonstraciju koristi kod 123456.',
            style: TextStyle(color: BslColors.warning, fontSize: 12),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const ValueKey('wallet-demo-otp'),
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
          decoration: _inputDecoration(
            label: 'Jednokratni demo kod',
            icon: Icons.password_rounded,
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('wallet-demo-tokenize'),
            onPressed: _finishDemoVerification,
            style: BslButtons.primary(),
            icon: const Icon(Icons.token_rounded),
            label: const Text('Kreiraj demo token kartice'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => setState(() => _verificationStep = false),
            child: const Text('Nazad na podatke kartice'),
          ),
        ),
      ],
    );
  }

  String? _required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }
}

class _WalletTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _WalletTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label: label, hint: hint, icon: icon),
      ),
    );
  }
}

class _DemoWarning extends StatelessWidget {
  const _DemoWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BslColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BslRadius.small),
        border: Border.all(color: BslColors.warning.withValues(alpha: 0.34)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_rounded, color: BslColors.warning, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'DEMO: nema povezivanja s bankom i nema naplate. Koristi samo '
              'ponuđene Visa ili Mastercard testne podatke. Puni broj i CVV '
              'se odbacuju nakon simulacije.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DemoCardPreset { visa, mastercard }

class _SheetTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _SheetTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: BslColors.cyan.withValues(alpha: 0.13),
          child: Icon(icon, color: BslColors.cyan),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BslColors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          color: Colors.white70,
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  String? hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.white30),
    prefixIcon: Icon(icon, color: BslColors.cyan),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BslRadius.small),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BslRadius.small),
      borderSide: const BorderSide(color: BslColors.cyan),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BslRadius.small),
      borderSide: const BorderSide(color: BslColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BslRadius.small),
      borderSide: const BorderSide(color: BslColors.danger),
    ),
  );
}

class _CardNumberFormatter extends TextInputFormatter {
  const _CardNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = WalletCardValidator.digitsOnly(newValue.text);
    final limited = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buffer = StringBuffer();

    for (var index = 0; index < limited.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(limited[index]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  const _ExpiryFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = WalletCardValidator.digitsOnly(newValue.text);
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = limited.length > 2
        ? '${limited.substring(0, 2)}/${limited.substring(2)}'
        : limited;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
