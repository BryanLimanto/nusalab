import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukp_ta_repository/models/proposal_draft.dart';
import 'package:ukp_ta_repository/services/api_client.dart';
import 'package:ukp_ta_repository/widgets/proposal_panel.dart';

import 'support/test_harness.dart';

void main() {
  group('proposal panel', () {
    testWidgets('opens from the FAB and explains both tracks',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      expect(find.byType(ProposalPanel), findsNothing);

      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();

      expect(find.byType(ProposalPanel), findsOneWidget);
      expect(find.text('Generator Proposal TA'), findsOneWidget);
      expect(find.text('Mulai dari judul atau ide Anda'), findsOneWidget);
      expect(find.text('RISET'), findsOneWidget);
      expect(find.text('PROYEK'), findsOneWidget);
      expect(find.text('11 bagian'), findsOneWidget);
      expect(find.text('10 bagian'), findsOneWidget);
    });

    testWidgets('opens from the AppBar navigation entry', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      await tester.tap(find.text('Chatbot Proposal AI'));
      await tester.pumpAndSettle();

      expect(find.byType(ProposalPanel), findsOneWidget);
    });

    testWidgets('an idea is answered with the track question first',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'aplikasi mobile absensi siswa',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(api.proposalCalls, 1);
      expect(api.lastProposalMessage, 'aplikasi mobile absensi siswa');
      expect(api.lastProposalPath, isNull);
      expect(
        find.text('Apakah Tugas Akhir ini mengambil jalur RISET atau PROYEK?'),
        findsOneWidget,
      );
      // Quick replies are what turns the question into a choice.
      expect(find.byKey(const Key('track-riset')), findsOneWidget);
      expect(find.byKey(const Key('track-proyek')), findsOneWidget);
    });

    testWidgets('picking RISET drafts the skeleton with sections and references',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'aplikasi mobile absensi siswa',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      api.proposalReply = risetDraftReply;
      await tester.tap(find.byKey(const Key('track-riset')));
      await tester.pumpAndSettle();

      expect(api.lastProposalPath, ProposalPath.riset);
      expect(find.text('Kerangka Jalur RISET'), findsOneWidget);
      expect(find.text('2 bagian'), findsOneWidget);
      // The first section is expanded by default.
      expect(find.text('Deteksi Kecurangan Ujian Online dengan Eye Tracking'), findsOneWidget);
      expect(find.textContaining('Smith, J. Eye tracking in exams'), findsOneWidget);
    });

    testWidgets('the conversation history is resent with every call',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'aplikasi mobile absensi siswa',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track-proyek')));
      await tester.pumpAndSettle();

      expect(api.proposalCalls, 2);
      // The idea and the student's track answer are resent. Assistant turns are not:
      // the clarification question is fixed and a draft would blow the context.
      expect(api.lastProposalHistory, hasLength(2));
      expect(api.lastProposalHistory.first.role, ProposalRole.user);
      expect(api.lastProposalHistory.first.content, 'aplikasi mobile absensi siswa');
      expect(api.lastProposalHistory.last.role, ProposalRole.user);
      expect(api.lastProposalHistory.last.content, 'PROYEK');
    });

    testWidgets('the active konsentrasi is forwarded as drafting context',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Artificial Intelligence').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'deteksi kecurangan ujian',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(api.lastProposalConcentration, 'Artificial Intelligence');
    });

    testWidgets('a degraded answer surfaces the notice', (WidgetTester tester) async {
      final api = FakeApiClient(
        proposalReply: const ProposalDraft(
          stage: ProposalStage.draft,
          answer: 'Draf belum dapat dibuat karena generator LLM sedang tidak tersedia.',
          path: ProposalPath.proyek,
          notice: 'llm_unavailable',
        ),
      );
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'aplikasi absensi',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('llm_unavailable'), findsOneWidget);
      expect(find.byKey(const Key('track-riset')), findsNothing);
    });

    testWidgets('a failed request shows a friendly error', (WidgetTester tester) async {
      final api = FakeApiClient(
        proposalError: const ApiException('Tidak dapat menghubungi layanan repository.'),
      );
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'aplikasi absensi',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Tidak dapat menghubungi layanan repository.'), findsOneWidget);
      expect(find.text('Maaf, draf belum dapat dibuat. Silakan coba lagi.'), findsOneWidget);
    });

    testWidgets('empty input is not sent', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(api.proposalCalls, 0);
    });

    testWidgets('the draft can be copied as plain text', (WidgetTester tester) async {
      final api = FakeApiClient(proposalReply: risetDraftReply);
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'aplikasi mobile absensi siswa',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Salin draf'));
      await tester.pumpAndSettle();

      expect(find.text('Draf proposal disalin.'), findsOneWidget);
    });

    testWidgets('clearing resets the conversation', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Generator Proposal TA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('proposal-input')),
        'aplikasi mobile absensi siswa',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Hapus percakapan'));
      await tester.pumpAndSettle();

      expect(find.text('Mulai dari judul atau ide Anda'), findsOneWidget);
    });
  });
}