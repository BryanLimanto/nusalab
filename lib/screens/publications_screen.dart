import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/thesis.dart';
import '../state/repository_search_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/thesis_card.dart';

/// Browse the whole catalogue: every published TA grouped by year.
class PublicationsScreen extends StatefulWidget {
  const PublicationsScreen({super.key});

  static const String routeName = '/publications';

  @override
  State<PublicationsScreen> createState() => _PublicationsScreenState();
}

class _PublicationsScreenState extends State<PublicationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<RepositorySearchController>();
      if (controller.status == LoadStatus.initial) controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RepositorySearchController>();
    final theme = Theme.of(context);
    final grouped = _groupByYear(controller);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${controller.total} Tugas Akhir',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Seluruh publikasi yang tercatat di repository UKP.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (controller.status) {
                LoadStatus.initial || LoadStatus.loading => const LoadingView(),
                LoadStatus.error => ErrorView(
                    message: controller.errorMessage ?? 'Terjadi kesalahan.',
                    onRetry: controller.refresh,
                  ),
                LoadStatus.ready => controller.result.isEmpty
                    ? const EmptyView(
                        title: 'Belum ada publikasi',
                        message: 'Repository masih kosong.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(Insets.md),
                        children: <Widget>[
                          for (final MapEntry<int, List<Thesis>> entry in grouped.entries) ...<Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, Insets.sm, 0, Insets.sm),
                              child: Text(
                                '${entry.key}  ·  ${entry.value.length} TA',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            for (final thesis in entry.value) ...<Widget>[
                              ThesisCard(thesis: thesis),
                              const SizedBox(height: Insets.sm),
                            ],
                          ],
                        ],
                      ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<int, List<Thesis>> _groupByYear(RepositorySearchController controller) {
    final grouped = <int, List<Thesis>>{};
    for (final thesis in controller.result.items) {
      grouped.putIfAbsent(thesis.year, () => <Thesis>[]).add(thesis);
    }
    return Map<int, List<Thesis>>.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }
}
