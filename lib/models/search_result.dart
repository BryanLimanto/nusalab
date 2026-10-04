import 'thesis.dart';

/// A page of `GET /api/search` results.
class SearchResult {
  const SearchResult({
    required this.total,
    required this.limit,
    required this.offset,
    required this.items,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return SearchResult(
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(Thesis.fromJson)
              .toList()
          : const <Thesis>[],
    );
  }

  final int total;
  final int limit;
  final int offset;
  final List<Thesis> items;

  bool get isEmpty => items.isEmpty;
}
