import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ukp_ta_repository/models/chat_message.dart';
import 'package:ukp_ta_repository/models/search_filters.dart';
import 'package:ukp_ta_repository/services/api_client.dart';

/// Exercises the real HTTP layer with a mock transport. The widget tests use a subclass
/// that overrides `chat` and `search`, so these are what guard request construction.
void main() {
  group('ApiClient.chat request', () {
    test('sends Content-Type: application/json', () async {
      late http.Request captured;
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:8000/api',
        httpClient: MockClient((http.Request request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'answer': 'ok',
              'mode': 'similarity',
              'matches': <dynamic>[],
              'topics': <dynamic>[],
            }),
            200,
          );
        }),
      );

      await client.chat(message: 'aplikasi absensi', mode: ChatMode.similarity);

      // Missing this header makes FastAPI parse the body as a form payload and return 422.
      expect(captured.headers['Content-Type'], 'application/json');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/chat');
    });

    test('encodes a JSON body with message and mode', () async {
      late String body;
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:8000/api',
        httpClient: MockClient((http.Request request) async {
          body = request.body;
          return http.Response(
            '{"answer":"ok","mode":"similarity","matches":[],"topics":[]}',
            200,
          );
        }),
      );

      await client.chat(message: 'aplikasi absensi', mode: ChatMode.similarity);

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      expect(decoded['message'], 'aplikasi absensi');
      expect(decoded['mode'], 'similarity');
      expect(decoded.containsKey('filters'), isFalse);
    });

    test('forwards active filters', () async {
      late String body;
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:8000/api',
        httpClient: MockClient((http.Request request) async {
          body = request.body;
          return http.Response(
            '{"answer":"ok","mode":"topics","matches":[],"topics":[]}',
            200,
          );
        }),
      );

      await client.chat(
        message: 'tren riset',
        mode: ChatMode.topics,
        filters: const SearchFilters(years: <int>{2025, 2024}, program: 'Informatika'),
      );

      final filters = jsonDecode(body)['filters'] as Map<String, dynamic>;
      expect(filters['years'], <dynamic>[2024, 2025]);
      expect(filters['program'], 'Informatika');
    });

    test('does not append an empty query string', () async {
      late Uri url;
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:8000/api',
        httpClient: MockClient((http.Request request) async {
          url = request.url;
          return http.Response('{"answer":"ok","mode":"similarity","matches":[],"topics":[]}', 200);
        }),
      );

      await client.chat(message: 'halo', mode: ChatMode.similarity);

      expect(url.toString(), 'http://127.0.0.1:8000/api/chat');
    });
  });

  group('ApiClient.search request', () {
    test('repeats the years parameter and adds paging', () async {
      late Uri url;
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:8000/api',
        httpClient: MockClient((http.Request request) async {
          url = request.url;
          return http.Response(
            '{"total":0,"limit":20,"offset":0,"items":[]}',
            200,
          );
        }),
      );

      await client.search(
        const SearchFilters(query: 'absensi siswa', years: <int>{2024, 2025}),
      );

      expect(url.queryParametersAll['years'], <String>['2024', '2025']);
      expect(url.queryParameters['q'], 'absensi siswa');
      expect(url.queryParameters['limit'], '20');
      expect(url.queryParameters['offset'], '0');
    });

    test('resolves a relative base URL against the current origin', () async {
      late Uri url;
      final client = ApiClient(
        baseUrl: '/api',
        httpClient: MockClient((http.Request request) async {
          url = request.url;
          return http.Response('{"total":0,"limit":20,"offset":0,"items":[]}', 200);
        }),
      );

      await client.search(const SearchFilters());

      expect(url.path, '/api/search');
      expect(url.hasScheme, isTrue, reason: 'a relative base must resolve to an absolute URL');
    });
  });

  group('ApiClient error mapping', () {
    Future<ApiException> capture(Future<Object?> Function() run) async {
      try {
        await run();
      } on ApiException catch (error) {
        return error;
      }
      fail('expected an ApiException');
    }

    ApiClient clientReturning(String body, int status) => ApiClient(
          baseUrl: 'http://127.0.0.1:8000/api',
          httpClient: MockClient((_) async => http.Response(body, status)),
        );

    test('maps 422 to a short user-safe message', () async {
      final error = await capture(
        () => clientReturning('{"detail":[]}', 422).search(const SearchFilters()),
      );
      expect(error.message, 'Permintaan ditolak oleh server.');
    });

    test('maps 5xx to a retry hint', () async {
      final error = await capture(
        () => clientReturning('boom', 500).search(const SearchFilters()),
      );
      expect(error.message, contains('Coba lagi'));
    });

    test('maps malformed JSON to a format error', () async {
      final error = await capture(
        () => clientReturning('<html>', 200).search(const SearchFilters()),
      );
      expect(error.message, 'Format data dari server tidak dikenali.');
    });

    test('maps a transport failure to a chatbot message', () async {
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:8000/api',
        httpClient: MockClient((_) async => throw const SocketExceptionStub()),
      );
      final error = await capture(
        () => client.chat(message: 'halo', mode: ChatMode.similarity),
      );
      expect(error.message, 'Tidak dapat menghubungi layanan chatbot.');
    });
  });
}

/// Stand-in transport failure: the client must translate it into an ApiException.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}