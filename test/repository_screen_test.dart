import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukp_ta_repository/models/filter_options.dart';
import 'package:ukp_ta_repository/models/search_result.dart';
import 'package:ukp_ta_repository/models/thesis.dart';
import 'package:ukp_ta_repository/services/api_client.dart';

import 'support/test_harness.dart';

const SearchResult _emptyResult =
    SearchResult(total: 0, limit: 20, offset: 0, items: <Thesis>[]);

/// Taps the year range slider at a fraction of its track. A tap moves the thumb
/// nearest to the pointer, which is deterministic where a drag is not. The slider
/// refetch is debounced, so the fake clock has to pass the debounce window.
Future<void> _tapYearRange(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byKey(const Key('year-range')));
  await tester.tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Long enough to clear the 350 ms debounce of the search controller.
const Duration _afterDebounce = Duration(milliseconds: 400);

void main() {
  group('repository screen', () {
    testWidgets('shows the loading state before results arrive', (WidgetTester tester) async {
      final api = FakeApiClient(searchGate: Completer<void>());
      await pumpApp(tester, api, settle: false);

      expect(find.text('Memuat repository…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('replaces the loading state with results', (WidgetTester tester) async {
      final gate = Completer<void>();
      final api = FakeApiClient(searchGate: gate);
      await pumpApp(tester, api, settle: false);

      expect(find.text('Memuat repository…'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Memuat repository…'), findsNothing);
      expect(find.text('Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code'), findsOneWidget);
    });

    testWidgets('renders a card per result with metadata', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      expect(find.text('Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code'), findsOneWidget);
      expect(find.text('R. Prasetyo, N. Rahmawati'), findsOneWidget);
      expect(find.text('Informatika · Mobile Engineering · 2025'), findsOneWidget);
      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('0.84'), findsOneWidget);
      expect(find.textContaining('Menampilkan 1–2 dari 2 TA'), findsOneWidget);
    });

    testWidgets('renders the empty state when nothing matches', (WidgetTester tester) async {
      final api = FakeApiClient(searchResult: _emptyResult);
      await pumpApp(tester, api);

      expect(find.text('Tidak ada TA yang cocok'), findsOneWidget);
      expect(find.text('Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code'), findsNothing);
    });

    testWidgets('renders the error state and recovers on retry', (WidgetTester tester) async {
      final api = FakeApiClient(
        searchError: const ApiException('Layanan sedang bermasalah. Coba lagi sebentar.'),
      );
      await pumpApp(tester, api);

      expect(find.text('Layanan tidak tersedia'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      api.searchError = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Layanan tidak tersedia'), findsNothing);
      expect(find.text('Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code'), findsOneWidget);
    });

    testWidgets('results still render when filter options are empty', (WidgetTester tester) async {
      final api = FakeApiClient(filterOptions: const FilterOptions.empty());
      await pumpApp(tester, api);

      expect(find.text('Belum ada data filter.'), findsOneWidget);
      expect(find.text('Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code'), findsOneWidget);
    });
  });

  group('filters', () {
    testWidgets('sidebar lists year range, programs, konsentrasi, and topik',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      expect(find.text('RENTANG TAHUN'), findsOneWidget);
      expect(find.byKey(const Key('year-range')), findsOneWidget);
      expect(find.text('PROGRAM STUDI'), findsOneWidget);
      expect(find.text('KONSENTRASI'), findsOneWidget);
      expect(find.text('TOPIK'), findsOneWidget);
      expect(find.text('Sistem Informasi'), findsOneWidget);
      expect(find.text('Cyber Security'), findsOneWidget);
      expect(find.text('Semua topik'), findsOneWidget);
    });

    testWidgets('narrowing the year range refetches with both bounds',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      final before = api.searchCalls;

      await _tapYearRange(tester, 0.5);

      expect(api.searchCalls, greaterThan(before));
      expect(api.lastFilters!.yearFrom, isNotNull);
      expect(api.lastFilters!.yearTo, isNotNull);
      expect(api.lastFilters!.hasYearRange, isTrue);
    });

    testWidgets('a full span clears the year range again', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      await _tapYearRange(tester, 0.5);
      expect(api.lastFilters!.hasYearRange, isTrue);

      await _tapYearRange(tester, 0.95);

      expect(api.lastFilters!.hasYearRange, isFalse);
      expect(api.lastFilters!.yearFrom, isNull);
      expect(api.lastFilters!.yearTo, isNull);
    });

    testWidgets('dragging the year slider refetches once, not once per frame',
        (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      final before = api.searchCalls;

      // The slider reports a value on every drag frame; the refetch must stay debounced.
      final rect = tester.getRect(find.byKey(const Key('year-range')));
      final gesture = await tester.startGesture(
        Offset(rect.right - 6, rect.center.dy),
      );
      for (var frame = 0; frame < 10; frame++) {
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump(_afterDebounce);
      await tester.pumpAndSettle();

      expect(api.searchCalls - before, 1);
      expect(api.lastFilters!.hasYearRange, isTrue);
    });

    testWidgets('selecting a program filters by program', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Sistem Informasi').first);
      await tester.pumpAndSettle();

      expect(api.lastFilters!.program, 'Sistem Informasi');
    });

    testWidgets('selecting a topik filters by topic', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      await tester.tap(find.byKey(const Key('topic-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('computer vision').last);
      await tester.pumpAndSettle();

      expect(api.lastFilters!.topic, 'computer vision');
    });

    testWidgets('reset clears active filters', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cyber Security').first);
      await tester.pumpAndSettle();
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Reset').first);
      await tester.pumpAndSettle();

      expect(api.lastFilters!.concentration, isNull);
      expect(find.text('Reset'), findsNothing);
    });
  });

  group('search', () {
    testWidgets('submitting the field sends the query', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);
      final before = api.searchCalls;

      await tester.enterText(find.byKey(const Key('search-input')), 'absensi siswa');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(api.searchCalls, greaterThan(before));
      expect(api.lastFilters!.query, 'absensi siswa');
    });

    testWidgets('active filters appear as removable chips', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Cyber Security').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Cyber Security'), findsOneWidget);
    });
  });

  group('narrow layout', () {
    testWidgets('filters move into the drawer', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api, size: const Size(420, 800));

      expect(find.text('PROGRAM STUDI'), findsNothing);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('PROGRAM STUDI'), findsOneWidget);
    });

    testWidgets('nav actions collapse into icons', (WidgetTester tester) async {
      final api = FakeApiClient();
      await pumpApp(tester, api, size: const Size(420, 800));

      expect(find.text('Publications'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });
}
