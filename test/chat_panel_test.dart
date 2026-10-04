import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukp_ta_repository/models/chat_message.dart';
import 'package:ukp_ta_repository/services/api_client.dart';
import 'package:ukp_ta_repository/widgets/chat_panel.dart';

import 'support/test_harness.dart';

void main() {
  group('chat panel', () {
    testWidgets('opens from the FAB and shows the intro', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      expect(find.byType(ChatPanel), findsNothing);

      await tester.tap(find.text('Tanya AI'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatPanel), findsOneWidget);
      expect(find.text('Asisten TA'), findsOneWidget);
      expect(find.text('Mulai pertanyaan'), findsOneWidget);
    });

    testWidgets('sends a message and renders the answer with matches', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.text('Tanya AI'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'aplikasi absensi siswa',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(api.chatCalls, 1);
      expect(api.lastMessage, 'aplikasi absensi siswa');
      expect(find.text('aplikasi absensi siswa'), findsOneWidget);
      expect(find.text('Mirip dengan satu TA terkait.'), findsOneWidget);
      expect(find.text('Aplikasi Mobile untuk Absensi Siswa'), findsOneWidget);
      expect(find.text('Irisan kata kunci: mobile, absensi'), findsOneWidget);
    });

    testWidgets('mode toggle switches to topic mapping', (WidgetTester tester) async {
      final api = FakeApiClient(
        chatReply: const ChatReply(
          answer: 'Topik populer: data mining.',
          mode: ChatMode.topics,
          matches: <ChatMatch>[],
          topics: <ChatTopic>[ChatTopic(label: 'data mining', count: 3, thesisIds: <String>['a'])],
        ),
      );
      await pumpApp(tester, api);
      await tester.tap(find.text('Tanya AI'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pemetaan Topik'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'tren riset',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(api.lastMode, ChatMode.topics);
      expect(find.text('Topik populer: data mining.'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'data mining'), findsOneWidget);
    });

    testWidgets('shows a friendly error when the request fails', (WidgetTester tester) async {
      final api = FakeApiClient(chatError: const ApiException('Tidak dapat menghubungi layanan chatbot.'));
      await pumpApp(tester, api);
      await tester.tap(find.text('Tanya AI'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'aplikasi absensi',
      );
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Tidak dapat menghubungi layanan chatbot.'), findsOneWidget);
      expect(find.text('Maaf, permintaan tidak dapat diproses. Silakan coba lagi.'), findsOneWidget);
    });

    testWidgets('suggestion chip sends its text immediately', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.text('Tanya AI'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Topik apa yang paling banyak diteliti tahun ini?'));
      await tester.pumpAndSettle();

      expect(api.lastMessage, 'Topik apa yang paling banyak diteliti tahun ini?');
      expect(api.chatCalls, 1);
    });

    testWidgets('empty input is not sent', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      await tester.tap(find.text('Tanya AI'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(api.chatCalls, 0);
    });

    testWidgets('active search filters are forwarded to the chatbot',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cyber Security').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tanya AI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Topik apa yang paling banyak diteliti tahun ini?'));
      await tester.pumpAndSettle();

      expect(api.lastFiltersSeen?.concentration, 'Cyber Security');
    });
  });
}
