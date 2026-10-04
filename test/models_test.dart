import 'package:flutter_test/flutter_test.dart';
import 'package:ukp_ta_repository/models/chat_message.dart';
import 'package:ukp_ta_repository/models/filter_options.dart';
import 'package:ukp_ta_repository/models/proposal_draft.dart';
import 'package:ukp_ta_repository/models/search_filters.dart';
import 'package:ukp_ta_repository/models/search_result.dart';
import 'package:ukp_ta_repository/models/thesis.dart';

import 'support/test_harness.dart';

void main() {
  group('Thesis.fromJson', () {
    test('maps every field of the API contract', () {
      final thesis = Thesis.fromJson(<String, dynamic>{
        'id': 'ta-2025-0002',
        'title': 'Aplikasi Mobile untuk Absensi Siswa',
        'authors': <String>['R. Prasetyo', 'N. Rahmawati'],
        'program': 'Informatika',
        'concentration': 'Mobile Engineering',
        'year': 2025,
        'keywords': <String>['mobile', 'absensi'],
        'tags': <String>['Q1'],
        'abstract': 'Ringkasan abstrak.',
        'url': 'https://repository.ukp.ac.id/ta/2025/0002',
        'score': 0.84,
      });

      expect(thesis.id, 'ta-2025-0002');
      expect(thesis.authorsLabel, 'R. Prasetyo, N. Rahmawati');
      expect(thesis.metaLabel, 'Informatika · Mobile Engineering · 2025');
      expect(thesis.score, closeTo(0.84, 1e-9));
      expect(thesis.hasUrl, isTrue);
    });

    test('falls back safely on missing or wrong-typed fields', () {
      final thesis = Thesis.fromJson(<String, dynamic>{'year': 2024.0});

      expect(thesis.title, 'Tanpa judul');
      expect(thesis.authors, isEmpty);
      expect(thesis.keywords, isEmpty);
      expect(thesis.year, 2024);
      expect(thesis.score, isNull);
      expect(thesis.hasUrl, isFalse);
      expect(thesis.authorsLabel, '—');
    });
  });

  group('SearchResult.fromJson', () {
    test('ignores malformed item entries', () {
      final result = SearchResult.fromJson(<String, dynamic>{
        'total': 2,
        'limit': 20,
        'offset': 0,
        'items': <dynamic>[
          <String, dynamic>{'id': 'a', 'title': 'Judul A', 'year': 2025},
          'bukan objek',
          null,
        ],
      });

      expect(result.total, 2);
      expect(result.items, hasLength(1));
      expect(result.items.first.title, 'Judul A');
      expect(result.isEmpty, isFalse);
    });

    test('reports an empty page', () {
      final result = SearchResult.fromJson(<String, dynamic>{});
      expect(result.total, 0);
      expect(result.isEmpty, isTrue);
    });
  });

  group('SearchFilters', () {
    test('is empty when nothing is set', () {
      expect(const SearchFilters().isEmpty, isTrue);
      expect(const SearchFilters().toQueryParameters(), isEmpty);
    });

    test('repeats the years key as FastAPI list[int] expects', () {
      const filters = SearchFilters(years: <int>{2024, 2026}, program: 'Informatika');

      final params = filters.toQueryParameters();
      expect(params['years'], <String>['2024', '2026']);
      expect(params['program'], <String>['Informatika']);
    });

    test('trims the query and drops a blank one', () {
      expect(const SearchFilters(query: '  absensi  ').toQueryParameters()['q'], <String>['absensi']);
      expect(const SearchFilters(query: '   ').toQueryParameters().containsKey('q'), isFalse);
    });

    test('toggleYear adds then removes a year', () {
      const filters = SearchFilters();
      final added = filters.toggleYear(2025);
      expect(added.years, <int>{2025});
      expect(added.toggleYear(2025).years, isEmpty);
    });

    test('choosing a program clears the konsentrasi', () {
      const filters = SearchFilters(concentration: 'Cyber Security');
      final next = filters.copyWith(program: 'Informatika');

      expect(next.program, 'Informatika');
      expect(next.concentration, isNull);
    });

    test('sends the year range and topic as their own parameters', () {
      const filters = SearchFilters(
        yearFrom: 2022,
        yearTo: 2025,
        topic: 'computer vision',
      );

      final params = filters.toQueryParameters();
      expect(params['year_from'], <String>['2022']);
      expect(params['year_to'], <String>['2025']);
      expect(params['topic'], <String>['computer vision']);
      expect(filters.hasFilters, isTrue);
      expect(filters.hasYearRange, isTrue);
    });

    test('clearing the range drops both bounds at once', () {
      const filters = SearchFilters(yearFrom: 2022, yearTo: 2025);
      final next = filters.copyWith(clearYearRange: true);

      expect(next.yearFrom, isNull);
      expect(next.yearTo, isNull);
      expect(next.hasYearRange, isFalse);
      expect(next.toQueryParameters().containsKey('year_from'), isFalse);
    });

    test('clearing the topic drops it', () {
      const filters = SearchFilters(topic: 'nlp');
      expect(filters.copyWith(clearTopic: true).topic, isNull);
    });
  });

  group('FilterOptions.fromJson', () {
    test('maps years, programs, and konsentrasi', () {
      final options = FilterOptions.fromJson(<String, dynamic>{
        'years': <dynamic>[2026, 2024],
        'programs': <dynamic>['Informatika'],
        'concentrations': <dynamic>['Data Mining'],
      });

      expect(options.years, <int>[2026, 2024]);
      expect(options.programs, <String>['Informatika']);
      expect(options.isEmpty, isFalse);
      expect(options.minYear, 2024);
      expect(options.maxYear, 2026);
    });

    test('maps topics and tags for the sidebar dropdown', () {
      final options = FilterOptions.fromJson(<String, dynamic>{
        'years': <dynamic>[2025],
        'topics': <dynamic>['nlp', 'computer vision'],
        'tags': <dynamic>['AI'],
      });

      expect(options.topics, <String>['nlp', 'computer vision']);
      expect(options.tags, <String>['AI']);
      expect(options.isEmpty, isFalse);
    });

    test('empty option set is detected', () {
      const options = FilterOptions.empty();
      expect(options.isEmpty, isTrue);
      expect(options.minYear, 0);
      expect(options.maxYear, 0);
    });
  });

  group('ProposalDraft.fromJson', () {
    test('parses a RISET draft with sections, references, and provenance', () {
      final draft = ProposalDraft.fromJson(<String, dynamic>{
        'stage': 'draft',
        'answer': 'Draf siap disunting.',
        'path': 'riset',
        'idea': 'deteksi kecurangan ujian',
        'sections': <dynamic>[
          <String, dynamic>{
            'number': 1,
            'title': 'Judul',
            'body': 'Deteksi Kecurangan Ujian Online',
            'citations': <dynamic>[],
          },
          <String, dynamic>{
            'number': 2,
            'title': 'Latar Belakang Masalah',
            'body': 'Ujian daring rentan [1].',
            'citations': <dynamic>[1, 2],
          },
          'bukan objek',
        ],
        'references': <dynamic>['Smith, J. Eye tracking. Journal, 2023.'],
        'grounded_on': <dynamic>['Aplikasi Mobile untuk Absensi Siswa'],
        'notice': null,
      });

      expect(draft.stage, ProposalStage.draft);
      expect(draft.path, ProposalPath.riset);
      expect(draft.sections, hasLength(2));
      expect(draft.sections.first.citations, isEmpty);
      expect(draft.sections.last.citations, <int>[1, 2]);
      expect(draft.references, hasLength(1));
      expect(draft.groundedOn, hasLength(1));
      expect(draft.degraded, isFalse);
    });

    test('defaults to the clarify stage on an unknown stage or path', () {
      final draft = ProposalDraft.fromJson(<String, dynamic>{'answer': 'x', 'stage': 'lain'});

      expect(draft.stage, ProposalStage.clarify);
      expect(draft.path, isNull);
      expect(draft.sections, isEmpty);
      expect(draft.references, isEmpty);
      expect(draft.groundedOn, isEmpty);
    });

    test('reports a degraded answer when the notice is set without sections', () {
      final draft = ProposalDraft.fromJson(<String, dynamic>{
        'stage': 'draft',
        'answer': 'x',
        'path': 'proyek',
        'notice': 'llm_unavailable',
      });

      expect(draft.degraded, isTrue);
      expect(draft.path, ProposalPath.proyek);
    });

    test('flattens the draft into plain text for the clipboard', () {
      const draft = risetDraftReply;
      final text = draft.toPlainText();

      expect(text, contains('aplikasi mobile absensi siswa'));
      expect(text, contains('1. Judul'));
      expect(text, contains('2. Latar Belakang Masalah'));
      expect(text, contains('Daftar Pustaka'));
      expect(text, contains('[1] Smith, J.'));
    });

    test('only user and assistant are accepted as turn roles', () {
      expect(
        ProposalTurn.fromJson(<String, dynamic>{'role': 'assistant', 'content': 'x'}).role,
        ProposalRole.assistant,
      );
      expect(
        ProposalTurn.fromJson(<String, dynamic>{'role': 'sistem'}).role,
        ProposalRole.user,
      );
      expect(
        const ProposalTurn(role: ProposalRole.user, content: 'x').toJson(),
        <String, dynamic>{'role': 'user', 'content': 'x'},
      );
    });

    test('maps both official tracks', () {
      expect(ProposalPath.fromWire('proyek'), ProposalPath.proyek);
      expect(ProposalPath.fromWire('lain'), isNull);
      expect(ProposalPath.riset.label, 'RISET');
      expect(ProposalPath.proyek.label, 'PROYEK');
    });
  });

  group('ChatReply.fromJson', () {
    test('parses similarity matches with scores and reasons', () {
      final reply = ChatReply.fromJson(<String, dynamic>{
        'answer': 'Mirip.',
        'mode': 'similarity',
        'matches': <dynamic>[
          <String, dynamic>{
            'id': 'ta-1',
            'title': 'Judul',
            'authors': <String>['A'],
            'year': 2025,
            'program': 'Informatika',
            'score': 0.77,
            'why': 'Irisan kata kunci: mobile',
          },
        ],
        'topics': <dynamic>[],
      });

      expect(reply.mode, ChatMode.similarity);
      expect(reply.matches, hasLength(1));
      expect(reply.matches.first.scoreLabel, '0.77');
      expect(reply.matches.first.why, 'Irisan kata kunci: mobile');
      expect(reply.notice, isNull);
    });

    test('parses topic clusters and the notice field', () {
      final reply = ChatReply.fromJson(<String, dynamic>{
        'answer': 'Topik.',
        'mode': 'topics',
        'matches': <dynamic>[],
        'topics': <dynamic>[
          <String, dynamic>{
            'label': 'data mining',
            'count': 3,
            'thesis_ids': <String>['a', 'b', 'c'],
          },
        ],
        'notice': 'Generator LLM tidak tersedia.',
      });

      expect(reply.mode, ChatMode.topics);
      expect(reply.topics.first.thesisIds, hasLength(3));
      expect(reply.notice, 'Generator LLM tidak tersedia.');
    });

    test('defaults to similarity mode on an unknown mode value', () {
      final reply = ChatReply.fromJson(<String, dynamic>{'answer': 'x', 'mode': 'lain'});
      expect(reply.mode, ChatMode.similarity);
      expect(reply.matches, isEmpty);
      expect(reply.topics, isEmpty);
    });
  });
}
