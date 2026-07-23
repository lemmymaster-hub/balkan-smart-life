import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bsl_ai_answer_sheet.dart';
import 'bsl_ai_bulb_icon.dart';

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
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.fromLTRB(11, 6, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF51A2943), Color(0xF50B1328)],
          ),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BslAiBulbIcon(size: 43),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PITAJ BSL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF7DEBFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pametni asistent za ${widget.city}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Container(
                height: 41,
                padding: const EdgeInsets.only(left: 10, right: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.11),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.only(bottom: 8),
                          hintText: 'Pitaj o gradu...',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pošalji pitanje',
                      onPressed: _isAnswerOpen ? null : _submit,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(34, 34),
                        maximumSize: const Size(34, 34),
                        backgroundColor: Colors.cyanAccent.withValues(
                          alpha: 0.14,
                        ),
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.04,
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: _isAnswerOpen
                            ? Colors.white24
                            : Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }
}
