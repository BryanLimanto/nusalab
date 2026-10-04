import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/thesis.dart';
import '../theme/app_theme.dart';

/// One search result: title, authors, year, truncated abstract, and tag chips.
class ThesisCard extends StatelessWidget {
  const ThesisCard({super.key, required this.thesis, this.onOpenUrl});

  final Thesis thesis;
  final ValueChanged<String>? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final excerpt = _excerpt(thesis.abstractText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    thesis.title,
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
                  ),
                ),
                if (thesis.score != null) ...<Widget>[
                  const SizedBox(width: Insets.sm),
                  _ScoreBadge(score: thesis.score!),
                ],
                PopupMenuButton<String>(
                  tooltip: 'Aksi TA',
                  onSelected: (String _) async {
                    final text = '${thesis.authorsLabel} (${thesis.year}). ${thesis.title}.';
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sitasi disalin.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'citation',
                      child: Text('Salin sitasi'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              thesis.authorsLabel,
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.school_outlined, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: Insets.xs),
                  Flexible(
                    child: Text(
                      thesis.metaLabel,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (excerpt.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(excerpt, style: theme.textTheme.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (thesis.tags.isNotEmpty || thesis.keywords.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.md),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: <Widget>[
                  for (final tag in thesis.tags) Chip(label: Text(tag)),
                  for (final keyword in thesis.keywords.take(3))
                    Chip(
                      label: Text(keyword),
                      backgroundColor: theme.colorScheme.surface,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.primary.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ],
            if (thesis.hasUrl) ...<Widget>[
              const SizedBox(height: Insets.sm),
              InkWell(
                onTap: () async {
                  if (onOpenUrl != null) {
                    onOpenUrl!(thesis.url!);
                    return;
                  }
                  await Clipboard.setData(ClipboardData(text: thesis.url!));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link repository disalin.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        onOpenUrl == null ? Icons.copy_rounded : Icons.open_in_new_rounded,
                        size: 13,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: Insets.xs),
                      // Flexible, not mainAxisSize.min: the URL must ellipsize on narrow cards.
                      Flexible(
                        child: Text(
                          thesis.url!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _excerpt(String abstractText) {
    final normalized = abstractText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 320) return normalized;
    return '${normalized.substring(0, 317)}…';
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Kemiripan vektor dengan kueri',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: Text(
          score.toStringAsFixed(2),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
