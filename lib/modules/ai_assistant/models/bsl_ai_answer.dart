class BslAiSource {
  final String title;
  final Uri? url;

  const BslAiSource({required this.title, this.url});

  factory BslAiSource.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString().trim() ?? '';
    final rawUrl = json['url']?.toString().trim();

    return BslAiSource(
      title: title.isEmpty ? 'BSL izvor' : title,
      url: rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl),
    );
  }
}

class BslAiAnswer {
  final String answer;
  final String city;
  final bool grounded;
  final List<BslAiSource> sources;
  final String? requestId;

  const BslAiAnswer({
    required this.answer,
    required this.city,
    required this.grounded,
    required this.sources,
    this.requestId,
  });

  factory BslAiAnswer.fromJson(
    Map<String, dynamic> json, {
    required String fallbackCity,
  }) {
    final answer = json['answer']?.toString().trim() ?? '';
    if (answer.isEmpty) {
      throw const FormatException('BSL AI odgovor nema tekst.');
    }

    final rawSources = json['sources'];
    final sources = rawSources is List
        ? rawSources
              .whereType<Map<String, dynamic>>()
              .map(BslAiSource.fromJson)
              .toList(growable: false)
        : const <BslAiSource>[];

    final responseCity = json['city']?.toString().trim();
    final requestId = json['request_id']?.toString().trim();

    return BslAiAnswer(
      answer: answer,
      city: responseCity == null || responseCity.isEmpty
          ? fallbackCity
          : responseCity,
      grounded: json['grounded'] == true,
      sources: sources,
      requestId: requestId == null || requestId.isEmpty ? null : requestId,
    );
  }
}
