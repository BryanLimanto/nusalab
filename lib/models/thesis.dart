/// A published Tugas Akhir record as returned by `GET /api/search`.
class Thesis {
  const Thesis({
    required this.id,
    required this.title,
    required this.authors,
    required this.program,
    required this.concentration,
    required this.year,
    required this.keywords,
    required this.tags,
    required this.abstractText,
    required this.url,
    this.score,
  });

  factory Thesis.fromJson(Map<String, dynamic> json) {
    return Thesis(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Tanpa judul',
      authors: _stringList(json['authors']),
      program: json['program'] as String? ?? '-',
      concentration: json['concentration'] as String? ?? '-',
      year: (json['year'] as num?)?.toInt() ?? 0,
      keywords: _stringList(json['keywords']),
      tags: _stringList(json['tags']),
      abstractText: json['abstract'] as String? ?? '',
      url: json['url'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String title;
  final List<String> authors;
  final String program;
  final String concentration;
  final int year;
  final List<String> keywords;
  final List<String> tags;

  /// `abstract` is reserved in Dart, so the field carries a different name.
  final String abstractText;
  final String? url;
  final double? score;

  String get authorsLabel => authors.isEmpty ? '—' : authors.join(', ');

  String get metaLabel => '$program · $concentration · $year';

  bool get hasUrl => url != null && url!.isNotEmpty;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((Object? item) => item?.toString() ?? '').where((String item) => item.isNotEmpty).toList();
}
