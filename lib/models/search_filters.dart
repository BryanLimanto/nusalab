/// Filter state for the repository search. Mirrors the query parameters of
/// `GET /api/search`: `q`, `year`/`years`, `year_from`/`year_to`, `program`,
/// `concentration`, and `topic`.
class SearchFilters {
  const SearchFilters({
    this.query = '',
    this.years = const <int>{},
    this.yearFrom,
    this.yearTo,
    this.program,
    this.concentration,
    this.topic,
  });

  final String query;
  final Set<int> years;

  /// Inclusive bounds of the year range slider. Null means "no bound".
  final int? yearFrom;
  final int? yearTo;

  final String? program;
  final String? concentration;
  final String? topic;

  bool get hasQuery => query.trim().isNotEmpty;

  /// True when a range was narrowed on either side, so the slider shows a chip.
  bool get hasYearRange => yearFrom != null || yearTo != null;

  bool get hasFilters =>
      years.isNotEmpty || hasYearRange || program != null || concentration != null || topic != null;

  /// True when nothing at all is set, so the UI can show the unfiltered list.
  bool get isEmpty => !hasQuery && !hasFilters;

  SearchFilters copyWith({
    String? query,
    Set<int>? years,
    int? yearFrom,
    int? yearTo,
    String? program,
    String? concentration,
    String? topic,
    bool clearYearRange = false,
    bool clearProgram = false,
    bool clearConcentration = false,
    bool clearTopic = false,
  }) {
    final programChanged = !clearProgram && program != null && program != this.program;
    return SearchFilters(
      query: query ?? this.query,
      years: years ?? this.years,
      yearFrom: clearYearRange ? null : (yearFrom ?? this.yearFrom),
      yearTo: clearYearRange ? null : (yearTo ?? this.yearTo),
      program: clearProgram ? null : (program ?? this.program),
      // Konsentrasi values belong to a program studi, so picking another program drops it.
      concentration: clearConcentration || programChanged
          ? null
          : (concentration ?? this.concentration),
      topic: clearTopic ? null : (topic ?? this.topic),
    );
  }

  SearchFilters toggleYear(int year) {
    final next = Set<int>.from(years);
    if (!next.remove(year)) next.add(year);
    return copyWith(years: next);
  }

  /// Query parameters for `GET /api/search`. `years` repeats the key, which is what
  /// FastAPI's `list[int]` parameter expects.
  Map<String, List<String>> toQueryParameters() {
    final sortedYears = years.toList()..sort();
    return <String, List<String>>{
      if (hasQuery) 'q': <String>[query.trim()],
      if (sortedYears.isNotEmpty)
        'years': sortedYears.map((int year) => '$year').toList(),
      if (yearFrom != null) 'year_from': <String>['$yearFrom'],
      if (yearTo != null) 'year_to': <String>['$yearTo'],
      if (program != null) 'program': <String>[program!],
      if (concentration != null) 'concentration': <String>[concentration!],
      if (topic != null) 'topic': <String>[topic!],
    };
  }
}
