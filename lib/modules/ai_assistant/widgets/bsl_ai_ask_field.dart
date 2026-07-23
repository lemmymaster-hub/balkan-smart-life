import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bsl_ai_answer_sheet.dart';

class BslAiAskField extends StatefulWidget {
  final String city;
  final BslAiAskCallback onAsk;

  const BslAiAskField({
    super.key,
    required this.city,
    required this.onAsk,
  });

  @override
  State<BslAiAskField> createState() => _BslAiAskFieldState();
}

class _BslAiAskFieldState extends State<BslAiAskField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isAnswerOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isAnswerOpen) return;

    final question = _controller.text.trim();
    if (question.isEmpty) {
      _focusNode.requestFocus();
      HapticFeedback.selectionClick();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    setState(() {
      _isAnswerOpen = true;
    });

    _controller.clear();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (context) {
          return BslAiAnswerSheet(
            question: question,
            city: widget.city,
            onAsk: widget.onAsk,
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnswerOpen = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Pitaj BSL AI',
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.cyanAccent.withValues(alpha: 0.88),
              Colors.white.withValues(alpha: 0.22),
              Colors.blueAccent.withValues(alpha: 0.56),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.20),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 8, 7, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF51A2943), Color(0xF50B1328)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF397BFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.34),
                      blurRadius: 13,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PITAJ BSL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF7DEBFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.15,
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: !_isAnswerOpen,
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.text,
                        maxLines: 1,
                        maxLength: 500,
                        cursorColor: Colors.cyanAccent,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.only(top: 5),
                          hintText: 'Postavi pitanje...',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Pošalji pitanje',
                onPressed: _isAnswerOpen ? null : _submit,
                style: IconButton.styleFrom(
                  minimumSize: const Size(38, 38),
                  backgroundColor: Colors.cyanAccent.withValues(alpha: 0.12),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
                ),
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: _isAnswerOpen ? Colors.white24 : Colors.cyanAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
