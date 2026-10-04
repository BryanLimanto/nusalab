import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/chat_message.dart';
import '../models/filter_options.dart';
import '../models/proposal_draft.dart';
import '../models/search_filters.dart';
import '../models/search_result.dart';

/// User-facing failure. Never surfaces a stack trace or a provider detail.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin HTTP layer over the FastAPI contract.
///
/// Every method throws [ApiException] with a short Indonesian message so the UI can
/// render a friendly error state instead of crashing.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _http;
  final String baseUrl;

  Future<FilterOptions> fetchFilters() async {
    final json = await _getJson('/filters');
    return FilterOptions.fromJson(json as Map<String, dynamic>);
  }

  Future<SearchResult> search(
    SearchFilters filters, {
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, List<String>>{
      ...filters.toQueryParameters(),
      'limit': <String>['$limit'],
      'offset': <String>['$offset'],
    };
    final json = await _getJson('/search', params);
    return SearchResult.fromJson(json as Map<String, dynamic>);
  }

  Future<ChatReply> chat({
    required String message,
    required ChatMode mode,
    SearchFilters? filters,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'mode': mode.wireName,
      if (filters != null && !filters.isEmpty)
        'filters': <String, dynamic>{
          'years': filters.years.toList()..sort(),
          if (filters.program != null) 'program': filters.program,
          if (filters.concentration != null) 'concentration': filters.concentration,
        },
    };
    try {
      final response = await _http
          // Without this header FastAPI treats the body as a form payload and answers 422.
          .post(
            _uri('/chat'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return ChatReply.fromJson(_decode(response));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Tidak dapat menghubungi layanan chatbot.');
    }
  }

  /// Asks the generator which track applies, or returns the draft once it is settled.
  /// The whole conversation is resent because the endpoint keeps no state.
  Future<ProposalDraft> proposal({
    required String message,
    required List<ProposalTurn> history,
    ProposalPath? path,
    String? concentration,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'history': history.map((ProposalTurn turn) => turn.toJson()).toList(),
      if (path != null) 'path': path.wireName,
      if (concentration != null && concentration.isNotEmpty) 'concentration': concentration,
    };
    try {
      final response = await _http
          .post(
            _uri('/proposal'),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConfig.proposalTimeout);
      return ProposalDraft.fromJson(_decode(response));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Generator proposal sedang tidak tersedia. Coba lagi sebentar.',
      );
    }
  }

  Future<Object?> _getJson(String path, [Map<String, List<String>>? params]) async {
    try {
      final response =
          await _http.get(_uri(path, params)).timeout(AppConfig.requestTimeout);
      return _decode(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('Tidak dapat menghubungi layanan repository.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(_messageForStatus(response.statusCode));
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Format data dari server tidak dikenali.');
      }
      return decoded;
    } on FormatException {
      throw const ApiException('Format data dari server tidak dikenali.');
    }
  }

  String _messageForStatus(int status) {
    if (status == 404) return 'Endpoint tidak ditemukan.';
    if (status == 422) return 'Permintaan ditolak oleh server.';
    if (status >= 500) return 'Layanan sedang bermasalah. Coba lagi sebentar.';
    return 'Permintaan gagal (kode $status).';
  }

  /// Builds an absolute URL. `baseUrl` may be relative (`/api`) so the browser resolves
  /// it against the deployment origin.
  Uri _uri(String path, [Map<String, List<String>>? params]) {
    final base = Uri.parse(baseUrl);
    final query = (params ?? const <String, List<String>>{}).entries
        .expand(
          (MapEntry<String, List<String>> entry) => entry.value.map(
            (String value) =>
                '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
          ),
        )
        .join('&');
    // Omit `query` when empty, otherwise the URL ends in a stray `?`.
    final target = base.replace(
      path: '${base.path}$path',
      query: query.isEmpty ? null : query,
    );
    return target.hasScheme ? target : Uri.base.resolveUri(target);
  }
}
