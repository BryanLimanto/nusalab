import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/filter_options.dart';
import '../models/search_filters.dart';
import '../models/search_result.dart';
import '../services/api_client.dart';

enum LoadStatus { initial, loading, ready, error }

/// Owns the repository search: filter values, options, and the current result page.
class RepositorySearchController extends ChangeNotifier {
  RepositorySearchController(this._api);

  final ApiClient _api;

  static const int pageSize = 20;

  LoadStatus status = LoadStatus.initial;
  LoadStatus filterStatus = LoadStatus.initial;
  String? errorMessage;
  FilterOptions options = const FilterOptions.empty();
  SearchFilters filters = const SearchFilters();
  SearchResult result = const SearchResult(total: 0, limit: pageSize, offset: 0, items: []);
  int offset = 0;

  Timer? _debounce;

  int get total => result.total;

  bool get hasNextPage => offset + result.items.length < result.total;

  bool get hasPreviousPage => offset > 0;

  Future<void> init() async {
    await Future.wait<void>([loadOptions(), refresh()]);
  }

  Future<void> loadOptions() async {
    filterStatus = LoadStatus.loading;
    notifyListeners();
    try {
      options = await _api.fetchFilters();
      filterStatus = LoadStatus.ready;
    } on ApiException {
      // Filters are an enhancement: keep browsing available with the sidebar empty.
      filterStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  void setQuery(String value) {
    filters = filters.copyWith(query: value);
    _schedule();
  }

  void submitQuery() {
    _debounce?.cancel();
    offset = 0;
    unawaited(refresh());
  }

  void toggleYear(int year) {
    filters = filters.toggleYear(year);
    submitQuery();
  }

  /// Applies the year range slider. The slider reports a value on every drag frame, so
  /// the refetch is debounced like keyword input instead of firing per frame, and a full
  /// span is reported as unset. An unchanged range does not refetch at all.
  void setYearRange(int from, int to, {required int minYear, required int maxYear}) {
    final next = (from <= minYear && to >= maxYear)
        ? filters.copyWith(clearYearRange: true)
        : filters.copyWith(yearFrom: from, yearTo: to);
    if (next.yearFrom == filters.yearFrom && next.yearTo == filters.yearTo) return;
    filters = next;
    _schedule();
  }

  void setTopic(String? topic) {
    filters = topic == null
        ? filters.copyWith(clearTopic: true)
        : filters.copyWith(topic: topic);
    submitQuery();
  }

  void setProgram(String? program) {
    filters = program == null
        ? filters.copyWith(clearProgram: true)
        : filters.copyWith(program: program);
    submitQuery();
  }

  void setConcentration(String? concentration) {
    filters = concentration == null
        ? filters.copyWith(clearConcentration: true)
        : filters.copyWith(concentration: concentration);
    submitQuery();
  }

  void resetFilters() {
    filters = SearchFilters(query: filters.query);
    submitQuery();
  }

  void nextPage() {
    if (!hasNextPage) return;
    offset += result.items.length;
    unawaited(refresh());
  }

  void previousPage() {
    if (!hasPreviousPage) return;
    offset = (offset - pageSize).clamp(0, result.total);
    unawaited(refresh());
  }

  /// Reloads the current filters from the first page.
  Future<void> refresh() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      result = await _api.search(filters, limit: pageSize, offset: offset);
      status = LoadStatus.ready;
    } on ApiException catch (error) {
      errorMessage = error.message;
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), submitQuery);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
