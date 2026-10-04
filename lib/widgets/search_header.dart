import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/repository_search_controller.dart';
import '../theme/app_theme.dart';

/// Prominent search header above the results column.
class SearchHeader extends StatefulWidget {
  const SearchHeader({super.key});

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: context.read<RepositorySearchController>().filters.query);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RepositorySearchController>();
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Repository Tugas Akhir UKP',
            style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 0.2),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            "Cari judul, penulis, atau kata kunci pada ${controller.total} TA yang terbit.",
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('search-input'),
                  controller: _text,
                  textInputAction: TextInputAction.search,
                  onChanged: controller.setQuery,
                  onSubmitted: (_) => controller.submitQuery(),
                  decoration: InputDecoration(
                    hintText: 'Contoh: aplikasi mobile absensi siswa',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _text.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan pencarian',
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _text.clear();
                              controller.setQuery('');
                              controller.submitQuery();
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              FilledButton(
                onPressed: controller.submitQuery,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cari'),
              ),
            ],
          ),
          if (controller.filters.hasFilters) ...<Widget>[
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final year in (controller.filters.years.toList()..sort()))
                  Chip(
                    label: Text('$year'),
                    onDeleted: () => controller.toggleYear(year),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  ),
                if (controller.filters.hasYearRange)
                  Chip(
                    label: Text(
                      '${controller.filters.yearFrom ?? controller.options.minYear}'
                      ' – ${controller.filters.yearTo ?? controller.options.maxYear}',
                    ),
                    onDeleted: () => controller.setYearRange(
                      controller.options.minYear,
                      controller.options.maxYear,
                      minYear: controller.options.minYear,
                      maxYear: controller.options.maxYear,
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  ),
                if (controller.filters.program != null)
                  Chip(
                    label: Text(controller.filters.program!),
                    onDeleted: () => controller.setProgram(null),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  ),
                if (controller.filters.concentration != null)
                  Chip(
                    label: Text(controller.filters.concentration!),
                    onDeleted: () => controller.setConcentration(null),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  ),
                if (controller.filters.topic != null)
                  Chip(
                    label: Text(controller.filters.topic!),
                    onDeleted: () => controller.setTopic(null),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
