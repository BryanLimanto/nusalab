import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/proposal_draft.dart';
import '../state/proposal_controller.dart';
import '../state/repository_search_controller.dart';
import '../theme/app_theme.dart';
import 'chat_overlay.dart';

/// Generator Proposal TA: a ChatGPT-style conversation that first asks whether the
/// thesis takes the RISET or PROYEK track, then renders the matching skeleton as
/// collapsible sections.
///
/// The draft runs to several thousand tokens, so the panel keeps every section closed
/// and shows the answer, the provenance of the State-of-the-Art section, and the
/// reference list up front.
class ProposalPanel extends StatefulWidget {
  const ProposalPanel({super.key});

  /// Opens the panel using the layout that fits the current window.
  static Future<void> show(BuildContext context) =>
      ChatOverlay.show(context, child: const ProposalPanel());

  @override
  State<ProposalPanel> createState() => _ProposalPanelState();
}

class _ProposalPanelState extends State<ProposalPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Konsentrasi selected in the repository sidebar, used as extra drafting context.
  String? get _concentration =>
      context.read<RepositorySearchController>().filters.concentration;

  void _send({ProposalPath? track}) {
    final text = _input.text.trim();
    if (text.isEmpty && track == null) return;
    _input.clear();
    final controller = context.read<ProposalController>();
    final concentration = _concentration;
    if (track != null) {
      controller.chooseTrack(track, concentration: concentration);
    } else {
      controller.sendIdea(text, concentration: concentration);
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _copy(ProposalDraft draft) {
    // Fire-and-forget: the confirmation must not wait for the clipboard round trip.
    unawaited(Clipboard.setData(ClipboardData(text: draft.toPlainText())));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Draf proposal disalin.')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProposalController>();
    final theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.sm, Insets.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.description_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Generator Proposal TA',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Asisten pembimbing TA · konsentrasi AI',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus percakapan',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: controller.isEmpty ? null : controller.clear,
              ),
              IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.isEmpty
              ? const _ProposalIntro()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.sm,
                  ),
                  itemCount: controller.messages.length,
                  itemBuilder: (BuildContext context, int index) => _Turn(
                    message: controller.messages[index],
                    drafting: controller.path != null,
                    onTrack: _send,
                    onCopy: _copy,
                  ),
                ),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(
              controller.errorMessage!,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('proposal-input'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  enabled: !controller.sending,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: controller.path == null
                        ? 'Tulis judul atau ide Tugas Akhir…'
                        : 'Ada yang ingin diperbaiki dari draf ini?',
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              IconButton.filled(
                onPressed: controller.sending ? null : () => _send(),
                icon: const Icon(Icons.send_rounded, size: 18),
                tooltip: 'Kirim',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Explains the two official tracks before the student sends anything.
class _ProposalIntro extends StatelessWidget {
  const _ProposalIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: <Widget>[
        Text('Mulai dari judul atau ide Anda', style: theme.textTheme.titleSmall),
        const SizedBox(height: Insets.xs),
        Text(
          'Tuliskan ide singkatnya. Assistants akan menanyakan jalur proposal, '
          'lalu menyusun kerangka lengkap sesuai pedoman konsentrasi.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Insets.md),
        for (final track in ProposalPath.values) ...<Widget>[
          _TrackCard(path: track),
          const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.path});

  final ProposalPath path;

  /// Section count from the official guidelines, shown as a hint before drafting.
  int get _sectionCount => path == ProposalPath.riset ? 11 : 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRiset = path == ProposalPath.riset;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isRiset ? Icons.science_outlined : Icons.widgets_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: Insets.xs),
              Text(
                path.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text('$_sectionCount bagian', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            isRiset
                ? 'Untuk penelitian ilmiah: hipotesis, dataset, eksperimen, dan metrik '
                    'evaluasi model.'
                : 'Untuk pengembangan aplikasi: solusi AI yang dapat dipakai pengguna, '
                    'diuji dengan metrik model dan UAT.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Turn extends StatelessWidget {
  const _Turn({
    required this.message,
    required this.drafting,
    required this.onTrack,
    required this.onCopy,
  });

  final ProposalMessage message;

  /// True once the track is settled, so the pending turn is generating a draft rather
  /// than just asking the question.
  final bool drafting;

  final void Function({ProposalPath? track}) onTrack;
  final void Function(ProposalDraft draft) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = message.draft;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.sm + 2),
        margin: const EdgeInsets.only(bottom: Insets.sm),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUser ? theme.colorScheme.primary.withValues(alpha: 0.2) : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (message.pending)
              _PendingLabel(drafting: drafting)
            else if (message.text.isNotEmpty)
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: message.failed ? theme.colorScheme.error : null,
                ),
              ),
            if (draft != null) ...<Widget>[
              if (draft.groundedOn.isNotEmpty) ...<Widget>[
                const SizedBox(height: Insets.sm),
                _GroundedNote(titles: draft.groundedOn),
              ],
              if (draft.sections.isNotEmpty)
                _DraftCard(draft: draft, onCopy: () => onCopy(draft)),
              // The track is settled but the answer is still the clarification question.
              if (draft.stage == ProposalStage.clarify) ...<Widget>[
                const SizedBox(height: Insets.sm),
                _TrackQuickReplies(onPick: onTrack),
              ],
              if (draft.notice != null) ...<Widget>[
                const SizedBox(height: Insets.xs),
                Text(
                  draft.notice!,
                  style: theme.textTheme.labelSmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingLabel extends StatelessWidget {
  const _PendingLabel({required this.drafting});

  final bool drafting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              drafting
                  ? 'Menyusun draf proposal, mohon tunggu…'
                  : 'Mengirim…',
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Provenance of the State-of-the-Art section: the published TAs actually retrieved.
class _GroundedNote extends StatelessWidget {
  const _GroundedNote({required this.titles});

  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.sm),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Penelitian terdahulu mengacu pada ${titles.length} TA repository:',
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          for (final title in titles)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('· $title', style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}

/// The generated skeleton: collapsible sections plus the reference list.
class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onCopy});

  final ProposalDraft draft;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = draft.path;

    return Container(
      margin: const EdgeInsets.only(top: Insets.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.xs, Insets.xs, Insets.xs),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    path == null
                        ? 'Draf Proposal'
                        : 'Kerangka Jalur ${path.label}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${draft.sections.length} bagian',
                  style: theme.textTheme.labelSmall,
                ),
                IconButton(
                  tooltip: 'Salin draf',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  onPressed: onCopy,
                ),
              ],
            ),
          ),
          for (var i = 0; i < draft.sections.length; i++)
            _SectionTile(section: draft.sections[i], initiallyExpanded: i == 0),
          if (draft.references.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Insets.sm),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Daftar pustaka (${draft.references.length})',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Insets.xs),
                  for (var i = 0; i < draft.references.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '[${i + 1}] ${draft.references[i]}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, this.initiallyExpanded = false});

  final ProposalSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      // The tile's own border is drawn by the enclosing card.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        childrenPadding: const EdgeInsets.fromLTRB(Insets.sm, 0, Insets.sm, Insets.sm),
        title: Text(
          '${section.number}. ${section.title}',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: section.citations.isEmpty
            ? null
            : Tooltip(
                message: 'Sitasi: ${section.citations.map((int n) => '[$n]').join(', ')}',
                child: Text(
                  '[${section.citations.join('] [')}]',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.accent),
                ),
              ),
        children: <Widget>[
          Text(_plain(section.body), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// RISET / PROYEK quick replies shown under the clarification question.
class _TrackQuickReplies extends StatelessWidget {
  const _TrackQuickReplies({required this.onPick});

  final void Function({ProposalPath? track}) onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.xs,
      children: <Widget>[
        for (final track in ProposalPath.values)
          OutlinedButton(
            key: Key('track-${track.wireName}'),
            onPressed: () => onPick(track: track),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              track.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// The model answers in Markdown, but this widget renders plain text: emphasis and
/// heading markers would otherwise show up as literal noise.
String _plain(String body) => body
    .replaceAll('**', '')
    .replaceAll('`', '')
    .replaceAllMapped(
      RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true),
      (_) => '',
    );