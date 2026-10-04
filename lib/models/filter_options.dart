/// Distinct filter values from `GET /api/filters`.
class FilterOptions {
  const FilterOptions({
    required this.years,
    required this.programs,
    required this.concentrations,
    this.topics = const <String>[],
    this.tags = const <String>[],
  });

  const FilterOptions.empty()
      : years = const <int>[],
        programs = const <String>[],
        concentrations = const <String>[],
        topics = const <String>[],
        tags = const <String>[];

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    return FilterOptions(
      years: _intList(json['years']),
      programs: _stringList(json['programs']),
      concentrations: _stringList(json['concentrations']),
      topics: _stringList(json['topics']),
      tags: _stringList(json['tags']),
    );
  }

  final List<int> years;
  final List<String> programs;
  final List<String> concentrations;

  /// Topik / kata kunci across the corpus, used by the Topik dropdown.
  final List<String> topics;
  final List<String> tags;

  /// Oldest and newest published year, the bounds of the year range slider.
  int get minYear => years.isEmpty ? 0 : years.last;

  int get maxYear => years.isEmpty ? 0 : years.first;

  bool get isEmpty =>
      years.isEmpty && programs.isEmpty && concentrations.isEmpty && topics.isEmpty;
}

List<int> _intList(Object? value) {
  if (value is! List) return const <int>[];
  return value.whereType<num>().map((num item) => item.toInt()).toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((Object? item) => item?.toString() ?? '').where((String item) => item.isNotEmpty).toList();
}
