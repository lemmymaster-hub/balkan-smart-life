import 'package:flutter/material.dart';

import '../models/bsl_ai_answer.dart';
import '../services/bsl_ai_service.dart';

typedef BslAiAskCallback =
    Future<BslAiAnswer> Function({
      required String question,
      required String city,
    });

class BslAiAnswerSheet extends StatefulWidget {
  final String question;
  final String city;
  final BslAiAskCallback onAsk;

  const BslAiAnswerSheet({
    super.key,
    required this.question,
    required this.city,
    required this.onAsk,
  });

  @override
  State<BslAiAnswerSheet> createState() => _BslAiAnswerSheetState();
}

class _BslAiAnswerSheetState extends State<BslAiAnswerSheet> {
  late Future<BslAiAnswer> _answerFuture;

  @override
  void initState() {
    super.initState();
    _askAgain();
  }

  void _askAgain() {
    _answerFuture = widget.onAsk(
      question: widget.question,
      city: widget.city,
    );
  }

  void _retry() {
    setState(_askAgain);
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14243D), Color(0xFF080D1B)],
        ),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.22),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D9FF), Color(0xFF346BFF)],
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x6600D9FF), blurRadius: 18),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pitaj BSL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Gradski AI asistent • BETA',
                        style: TextStyle(
                          color: Color(0xFF78E8FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Zatvori',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<BslAiAnswer>(
              future: _answerFuture,
              builder: (context, snapshot) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF233452),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(5),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          widget.question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      _BslAiLoading(city: widget.city)
                    else if (snapshot.hasError)
                      _BslAiError(error: snapshot.error, onRetry: _retry)
                    else if (snapshot.hasData)
                      _BslAiAnswerContent(answer: snapshot.requireData),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BslAiLoading extends StatelessWidget {
  final String city;

  const _BslAiLoading({required this.city});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.13),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Provjeravam pouzdane informacije za $city...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BslAiError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _BslAiError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is BslAiException
        ? (error as BslAiException).userMessage
        : 'BSL AI trenutno nije dostupan. Pokušajte ponovo.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF30212A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: Colors.orangeAccent,
                size: 21,
              ),
              SizedBox(width: 9),
              Text(
                'Odgovor nije dostupan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.cyanAccent,
              side: BorderSide(
                color: Colors.cyanAccent.withValues(alpha: 0.34),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Pokušaj ponovo'),
          ),
        ],
      ),
    );
  }
}

class _BslAiAnswerContent extends StatelessWidget {
  final BslAiAnswer answer;

  const _BslAiAnswerContent({required this.answer});

  @override
  Widget build(BuildContext context) {
    final hasVerifiedSources = answer.grounded && answer.sources.isNotEmpty;
    final statusColor = hasVerifiedSources
        ? const Color(0xFF48E5A2)
        : Colors.amberAccent;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasVerifiedSources
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hasVerifiedSources
                      ? 'Odgovor potvrđen navedenim izvorima'
                      : 'AI odgovor • provjerite važne informacije',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  answer.city,
                  style: const TextStyle(
                    color: Color(0xFF8AECFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SelectableText(
            answer.answer,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          if (answer.sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            const Text(
              'IZVORI',
              style: TextStyle(
                color: Color(0xFF78E8FF),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.15,
              ),
            ),
            const SizedBox(height: 9),
            ...answer.sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        source.title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
