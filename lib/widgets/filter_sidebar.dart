import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/search_filters.dart';
import '../state/repository_search_controller.dart';
import '../theme/app_theme.dart';

/// Left sidebar: checkboxes for year, program studi, and konsentrasi.
class FilterSidebar extends StatelessWidget {
  const FilterSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RepositorySearchController>();
    final options = controller.options;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.lg, Insets.md, Insets.xl),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'FILTER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (controller.filters.hasFilters)
                TextButton(
                  onPressed: controller.resetFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reset'),
                ),
            ],
          ),
          if (controller.filterStatus == LoadStatus.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.md),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (controller.filterStatus == LoadStatus.error)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.sm),
              child: Text('Filter tidak dapat dimuat.'),
            ),
          if (options.isEmpty && controller.filterStatus != LoadStatus.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.sm),
              child: Text('Belum ada data filter.'),
            ),
          if (options.years.isNotEmpty) ...<Widget>[
            const _SectionTitle('Rentang Tahun'),
            _YearRangeSlider(
              filters: controller.filters,
              minYear: options.minYear,
              maxYear: options.maxYear,
            ),
          ],
          if (options.programs.isNotEmpty) ...<Widget>[
            const _SectionTitle('Program Studi'),
            for (final program in options.programs)
              _FilterOption(
                label: program,
                selected: controller.filters.program == program,
                onChanged: (bool? selected) =>
                    controller.setProgram(selected == true ? program : null),
              ),
          ],
          if (options.concentrations.isNotEmpty) ...<Widget>[
            const _SectionTitle('Konsentrasi'),
            for (final concentration in options.concentrations)
              _FilterOption(
                label: concentration,
                selected: controller.filters.concentration == concentration,
                onChanged: (bool? selected) =>
                    controller.setConcentration(selected == true ? concentration : null),
              ),
          ],
          if (options.topics.isNotEmpty) ...<Widget>[
            const _SectionTitle('Topik'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('topic-filter'),
                  isExpanded: true,
                  isDense: true,
                  value: options.topics.contains(controller.filters.topic)
                      ? controller.filters.topic
                      : null,
                  hint: const Text('Semua topik', style: TextStyle(fontSize: 13.5)),
                  items: <DropdownMenuItem<String>>[
                    for (final topic in options.topics)
                      DropdownMenuItem<String>(
                        value: topic,
                        child: Text(
                          topic,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                  ],
                  onChanged: controller.setTopic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inclusive year range. The endpoints are the oldest and newest published years, so
/// a full span means "no filter" and is reported as unset.
class _YearRangeSlider extends StatelessWidget {
  const _YearRangeSlider({
    required this.filters,
    required this.minYear,
    required this.maxYear,
  });

  final SearchFilters filters;
  final int minYear;
  final int maxYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.read<RepositorySearchController>();
    // RangeSlider requires a strictly positive span, which a single-year corpus has not.
    if (maxYear <= minYear) return Text('$minYear', style: theme.textTheme.bodySmall);

    final start = (filters.yearFrom ?? minYear).clamp(minYear, maxYear);
    final end = (filters.yearTo ?? maxYear).clamp(minYear, maxYear);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
          child: Text(
            filters.hasYearRange ? '$start – $end' : 'Semua tahun ($minYear–$maxYear)',
            style: theme.textTheme.bodySmall,
          ),
        ),
        RangeSlider(
          key: const Key('year-range'),
          values: RangeValues(start.toDouble(), end.toDouble()),
          min: minYear.toDouble(),
          max: maxYear.toDouble(),
          divisions: maxYear - minYear,
          labels: RangeLabels('$start', '$end'),
          onChanged: (RangeValues value) => controller.setYearRange(
            value.start.round(),
            value.end.round(),
            minYear: minYear,
            maxYear: maxYear,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.sm),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: onChanged,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
    );
  }
}
