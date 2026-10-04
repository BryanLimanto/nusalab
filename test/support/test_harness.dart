import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukp_ta_repository/main.dart';
import 'package:ukp_ta_repository/models/chat_message.dart';
import 'package:ukp_ta_repository/models/filter_options.dart';
import 'package:ukp_ta_repository/models/proposal_draft.dart';
import 'package:ukp_ta_repository/models/search_filters.dart';
import 'package:ukp_ta_repository/models/search_result.dart';
import 'package:ukp_ta_repository/services/api_client.dart';

/// Offline stand-in for [ApiClient]: no HTTP, no keys, deterministic payloads.
class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.searchResult,
    this.filterOptions,
    this.chatReply,
    this.proposalReply,
    this.searchError,
    this.chatError,
    this.proposalError,
    this.searchGate,
  }) : super(baseUrl: 'http://localhost/api');

  SearchResult? searchResult;
  FilterOptions? filterOptions;
  ChatReply? chatReply;
  ProposalDraft? proposalReply;
  ApiException? searchError;
  ApiException? chatError;
  ApiException? proposalError;

  /// When set, `search` waits on this before responding, so tests can observe the
  /// loading state.
  Completer<void>? searchGate;

  int searchCalls = 0;
  int chatCalls = 0;
  int proposalCalls = 0;
  SearchFilters? lastFilters;
  SearchFilters? lastFiltersSeen;
  ChatMode? lastMode;
  String? lastMessage;
  String? lastProposalMessage;
  List<ProposalTurn> lastProposalHistory = <ProposalTurn>[];
  ProposalPath? lastProposalPath;
  String? lastProposalConcentration;

  @override
  Future<FilterOptions> fetchFilters() async =>
      filterOptions ??
      const FilterOptions(
        years: <int>[2026, 2025, 2024],
        programs: <String>['Informatika', 'Sistem Informasi'],
        concentrations: <String>['Artificial Intelligence', 'Cyber Security'],
        topics: <String>['computer vision', 'nlp', 'mobile'],
      );

  @override
  Future<SearchResult> search(
    SearchFilters filters, {
    int limit = 20,
    int offset = 0,
  }) async {
    searchCalls++;
    lastFilters = filters;
    final gate = searchGate;
    if (gate != null) await gate.future;
    final error = searchError;
    if (error != null) throw error;
    return searchResult ??
        SearchResult.fromJson(
          jsonDecode(
            '{"total":2,"limit":$limit,"offset":$offset,"items":${jsonEncode(sampleItems)}}',
          ) as Map<String, dynamic>,
        );
  }

  @override
  Future<ChatReply> chat({
    required String message,
    required ChatMode mode,
    SearchFilters? filters,
  }) async {
    chatCalls++;
    lastMessage = message;
    lastMode = mode;
    lastFiltersSeen = filters;
    final error = chatError;
    if (error != null) throw error;
    return chatReply ??
        const ChatReply(
          answer: 'Mirip dengan satu TA terkait.',
          mode: ChatMode.similarity,
          matches: <ChatMatch>[
            ChatMatch(
              id: 'ta-2025-0002',
              title: 'Aplikasi Mobile untuk Absensi Siswa',
              authors: <String>['R. Prasetyo'],
              year: 2025,
              program: 'Informatika',
              score: 0.84,
              why: 'Irisan kata kunci: mobile, absensi',
            ),
          ],
          topics: <ChatTopic>[],
        );
  }

  @override
  Future<ProposalDraft> proposal({
    required String message,
    required List<ProposalTurn> history,
    ProposalPath? path,
    String? concentration,
  }) async {
    proposalCalls++;
    lastProposalMessage = message;
    lastProposalHistory = history;
    lastProposalPath = path;
    lastProposalConcentration = concentration;
    final error = proposalError;
    if (error != null) throw error;
    return proposalReply ?? clarifyReply;
  }
}

/// The clarification question the backend returns before the track is settled.
const ProposalDraft clarifyReply = ProposalDraft(
  stage: ProposalStage.clarify,
  answer: 'Apakah Tugas Akhir ini mengambil jalur RISET atau PROYEK?',
  idea: 'aplikasi mobile absensi siswa',
);

/// A RISET draft shaped exactly like `POST /api/proposal` returns.
const ProposalDraft risetDraftReply = ProposalDraft(
  stage: ProposalStage.draft,
  answer: 'Draf proposal jalur RISET berikut siap disunting.',
  path: ProposalPath.riset,
  idea: 'aplikasi mobile absensi siswa',
  sections: <ProposalSection>[
    ProposalSection(
      number: 1,
      title: 'Judul',
      body: 'Deteksi Kecurangan Ujian Online dengan Eye Tracking',
      citations: <int>[],
    ),
    ProposalSection(
      number: 2,
      title: 'Latar Belakang Masalah',
      body: 'Ujian daring makin rentan kecurangan [1].',
      citations: <int>[1],
    ),
  ],
  references: <String>['Smith, J. Eye tracking in exams. Journal of EdTech, 2023.'],
  groundedOn: <String>['Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code'],
);

/// Two records shaped exactly like `GET /api/search` items.
const List<Map<String, dynamic>> sampleItems = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'ta-2025-0002',
    'title': 'Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code',
    'authors': <String>['R. Prasetyo', 'N. Rahmawati'],
    'program': 'Informatika',
    'concentration': 'Mobile Engineering',
    'year': 2025,
    'keywords': <String>['mobile', 'absensi'],
    'tags': <String>['Q1', 'Mobile'],
    'abstract': 'Aplikasi absensi siswa berbasis mobile dengan pemindaian kode QR.',
    'url': 'https://repository.ukp.ac.id/ta/2025/0002',
    'score': 0.84,
  },
  <String, dynamic>{
    'id': 'ta-2026-0022',
    'title': 'Pemetaan Topik Penelitian Tugas Akhir dengan K-Means',
    'authors': <String>['G. Prasetyo'],
    'program': 'Informatika',
    'concentration': 'Data Mining',
    'year': 2026,
    'keywords': <String>['clustering'],
    'tags': <String>['AI'],
    'abstract': 'Pemetaan topik penelitian dengan clustering K-Means.',
    'url': null,
    'score': null,
  },
];

SearchResult resultsFrom(List<Map<String, dynamic>> items) =>
    SearchResult.fromJson(
      jsonDecode(
        '{"total":${items.length},"limit":20,"offset":0,"items":${jsonEncode(items)}}',
      ) as Map<String, dynamic>,
    );

/// Desktop-width viewport so the filter sidebar is rendered.
Future<void> pumpApp(
  WidgetTester tester,
  FakeApiClient api, {
  Size size = const Size(1280, 900),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TaRepositoryApp(apiClient: api));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
