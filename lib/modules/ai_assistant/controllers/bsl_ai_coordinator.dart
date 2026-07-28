import '../models/bsl_ai_answer.dart';
import '../models/bsl_ai_request_context.dart';
import '../services/bsl_ai_local_intent_resolver.dart';
import '../services/bsl_ai_service.dart';

class BslAiCoordinator {
  final BslAiService _remoteService;
  final BslAiLocalIntentResolver _localResolver;

  BslAiCoordinator({
    BslAiService? remoteService,
    BslAiLocalIntentResolver localResolver = const BslAiLocalIntentResolver(),
  }) : _remoteService = remoteService ?? BslAiService(),
       _localResolver = localResolver;

  Future<BslAiAnswer> ask({
    required String question,
    required BslAiRequestContext context,
  }) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw const BslAiException('Unesite pitanje za BSL AI.');
    }

    final localAnswer = _localResolver.resolve(
      question: normalizedQuestion,
      context: context,
    );
    if (localAnswer != null) return localAnswer;

    if (_remoteService.isConfigured) {
      return _remoteService.ask(
        question: normalizedQuestion,
        city: context.city,
        context: context,
      );
    }

    return BslAiAnswer(
      answer:
          'Trenutno mogu otvoriti Parkiraj.ba, EL Punjače, vremensku '
          'prognozu i BSL novčanik. Za opšta pitanja biće aktiviran sigurni '
          'BSL AI server; NVIDIA ključ neće biti smješten u aplikaciji.',
      city: context.city,
      grounded: false,
      sources: const [],
    );
  }

  void dispose() {
    _remoteService.dispose();
  }
}
