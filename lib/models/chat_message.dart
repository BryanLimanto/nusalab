/// Chatbot domain models matching `POST /api/chat`.
enum ChatMode {
  similarity('similarity', 'Cek Similarity'),
  topics('topics', 'Pemetaan Topik');

  const ChatMode(this.wireName, this.label);

  final String wireName;
  final String label;
}

class ChatMatch {
  const ChatMatch({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.program,
    required this.score,
    required this.why,
  });

  factory ChatMatch.fromJson(Map<String, dynamic> json) {
    return ChatMatch(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      authors: _strings(json['authors']),
      year: (json['year'] as num?)?.toInt() ?? 0,
      program: json['program'] as String? ?? '-',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      why: json['why'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final List<String> authors;
  final int year;
  final String program;
  final double score;
  final String why;

  String get scoreLabel => score.toStringAsFixed(2);
}

class ChatTopic {
  const ChatTopic({
    required this.label,
    required this.count,
    required this.thesisIds,
  });

  factory ChatTopic.fromJson(Map<String, dynamic> json) {
    return ChatTopic(
      label: json['label'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      thesisIds: _strings(json['thesis_ids']),
    );
  }

  final String label;
  final int count;
  final List<String> thesisIds;
}

class ChatReply {
  const ChatReply({
    required this.answer,
    required this.mode,
    required this.matches,
    required this.topics,
    this.notice,
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'];
    final rawTopics = json['topics'];
    return ChatReply(
      answer: json['answer'] as String? ?? '',
      mode: json['mode'] == 'topics' ? ChatMode.topics : ChatMode.similarity,
      matches: rawMatches is List
          ? rawMatches
              .whereType<Map<String, dynamic>>()
              .map(ChatMatch.fromJson)
              .toList()
          : const <ChatMatch>[],
      topics: rawTopics is List
          ? rawTopics
              .whereType<Map<String, dynamic>>()
              .map(ChatTopic.fromJson)
              .toList()
          : const <ChatTopic>[],
      notice: json['notice'] as String?,
    );
  }

  final String answer;
  final ChatMode mode;
  final List<ChatMatch> matches;
  final List<ChatTopic> topics;
  final String? notice;
}

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.reply,
    this.pending = false,
    this.failed = false,
  });

  final ChatRole role;
  final String text;
  final ChatReply? reply;
  final bool pending;
  final bool failed;
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((Object? item) => item?.toString() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList();
}
