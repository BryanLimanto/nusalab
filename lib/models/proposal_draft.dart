/// Proposal generator models matching `POST /api/proposal`.
///
/// The endpoint is stateless: the client resends the short conversation on every call,
/// so [ProposalTurn] is the wire form of one past message.
library;

/// Official tracks from the UKP AI-concentration guidelines.
enum ProposalPath {
  riset('riset', 'RISET', 'Penelitian ilmiah'),
  proyek('proyek', 'PROYEK', 'Pengembangan aplikasi');

  const ProposalPath(this.wireName, this.label, this.summary);

  final String wireName;
  final String label;
  final String summary;

  static ProposalPath? fromWire(String? value) {
    for (final path in ProposalPath.values) {
      if (path.wireName == value) return path;
    }
    return null;
  }
}

/// `clarify` while the track is still unknown, `draft` once the skeleton is returned.
enum ProposalStage {
  clarify('clarify'),
  draft('draft');

  const ProposalStage(this.wireName);

  final String wireName;

  static ProposalStage fromWire(String? value) =>
      value == 'draft' ? ProposalStage.draft : ProposalStage.clarify;
}

enum ProposalRole {
  user('user'),
  assistant('assistant');

  const ProposalRole(this.wireName);

  final String wireName;
}

/// One prior turn, resent with every request so the server stays stateless.
class ProposalTurn {
  const ProposalTurn({required this.role, required this.content});

  factory ProposalTurn.fromJson(Map<String, dynamic> json) => ProposalTurn(
        role: json['role'] == 'assistant' ? ProposalRole.assistant : ProposalRole.user,
        content: json['content'] as String? ?? '',
      );

  final ProposalRole role;
  final String content;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role.wireName,
        'content': content,
      };
}

/// One `## N. Title` block of the generated skeleton.
class ProposalSection {
  const ProposalSection({
    required this.number,
    required this.title,
    required this.body,
    this.citations = const <int>[],
  });

  factory ProposalSection.fromJson(Map<String, dynamic> json) {
    final rawCitations = json['citations'];
    return ProposalSection(
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      citations: rawCitations is List
          ? rawCitations.whereType<num>().map((num item) => item.toInt()).toList()
          : const <int>[],
    );
  }

  final int number;
  final String title;
  final String body;
  final List<int> citations;
}

class ProposalDraft {
  const ProposalDraft({
    required this.stage,
    required this.answer,
    this.path,
    this.idea = '',
    this.sections = const <ProposalSection>[],
    this.references = const <String>[],
    this.groundedOn = const <String>[],
    this.notice,
  });

  factory ProposalDraft.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return ProposalDraft(
      stage: ProposalStage.fromWire(json['stage'] as String?),
      answer: json['answer'] as String? ?? '',
      path: ProposalPath.fromWire(json['path'] as String?),
      idea: json['idea'] as String? ?? '',
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(ProposalSection.fromJson)
              .toList()
          : const <ProposalSection>[],
      references: _strings(json['references']),
      groundedOn: _strings(json['grounded_on']),
      notice: json['notice'] as String?,
    );
  }

  final ProposalStage stage;
  final String answer;
  final ProposalPath? path;
  final String idea;
  final List<ProposalSection> sections;
  final List<String> references;

  /// Titles of the published TAs injected as context, shown as a provenance note.
  final List<String> groundedOn;

  /// Non-null when the answer was degraded — no LLM, or no embedding provider.
  final String? notice;

  /// True when the track is settled but the provider could not produce a skeleton.
  bool get degraded => notice != null && sections.isEmpty;

  /// Plain-text draft for the clipboard.
  String toPlainText() {
    final buffer = StringBuffer(idea.isEmpty ? answer : '$idea\n\n');
    for (final section in sections) {
      buffer.writeln('${section.number}. ${section.title}');
      buffer.writeln(section.body);
      buffer.writeln();
    }
    if (references.isNotEmpty) {
      buffer.writeln('Daftar Pustaka');
      for (var i = 0; i < references.length; i++) {
        buffer.writeln('[${i + 1}] ${references[i]}');
      }
    }
    return buffer.toString().trim();
  }
}

/// One message in the proposal conversation.
class ProposalMessage {
  const ProposalMessage({
    required this.role,
    required this.text,
    this.draft,
    this.pending = false,
    this.failed = false,
  });

  final ProposalRole role;
  final String text;
  final ProposalDraft? draft;
  final bool pending;
  final bool failed;

  bool get isUser => role == ProposalRole.user;
}

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((Object? item) => item?.toString() ?? '')
      .where((String item) => item.isNotEmpty)
      .toList();
}