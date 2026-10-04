import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../state/chat_controller.dart';
import '../state/repository_search_controller.dart';
import '../theme/app_theme.dart';
import 'chat_overlay.dart';

/// Chatbot UI: opened from the FAB on the repository screen, rendered as a sliding
/// side panel on wide viewports and a bottom sheet on narrow ones.
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  /// Opens the panel using the layout that fits the current window.
  static Future<void> show(BuildContext context) =>
      ChatOverlay.show(context, child: const ChatPanel());

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    context.read<ChatController>().send(text, filters: context.read<RepositorySearchController>().filters);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
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
              Icon(Icons.auto_awesome_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Asisten TA',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text('Berdasarkan data repository UKP', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hapus percakapan',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: chat.isEmpty ? null : chat.clear,
              ),
              IconButton(
                tooltip: 'Tutup',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, Insets.sm),
          child: SegmentedButton<ChatMode>(
            segments: <ButtonSegment<ChatMode>>[
              for (final mode in ChatMode.values)
                ButtonSegment<ChatMode>(value: mode, label: Text(mode.label)),
            ],
            selected: <ChatMode>{chat.mode},
            onSelectionChanged: (Set<ChatMode> value) => chat.setMode(value.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ),
        Expanded(
          child: chat.isEmpty
              ? const _ChatIntro()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.sm,
                  ),
                  itemCount: chat.messages.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _MessageBubble(message: chat.messages[index]),
                ),
        ),
        if (chat.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(
              chat.errorMessage!,
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
                  key: const Key('chat-input'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Tulis judul atau ringkasan proposal…',
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              IconButton.filled(
                onPressed: chat.sending ? null : _send,
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

class _ChatIntro extends StatelessWidget {
  const _ChatIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: <Widget>[
        Text('Mulai pertanyaan', style: theme.textTheme.titleSmall),
        const SizedBox(height: Insets.sm),
        const _Suggestion('Cek apakah proposal saya mirip TA yang sudah terbit'),
        const _Suggestion('Topik apa yang paling banyak diteliti tahun ini?'),
        const _Suggestion('Bagaimana tren riset data mining di Teknik Elektro?'),
      ],
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: OutlinedButton(
        onPressed: () {
          final controller = context.read<ChatController>();
          controller.send(label, filters: context.read<RepositorySearchController>().filters);
        },
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: Insets.sm),
        padding: const EdgeInsets.all(Insets.sm + 2),
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (message.text.isNotEmpty)
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: message.failed ? theme.colorScheme.error : null,
                ),
              ),
            if (message.reply != null) ...<Widget>[
              if (message.text.isNotEmpty) const SizedBox(height: Insets.sm),
              _MatchList(matches: message.reply!.matches),
              _TopicList(topics: message.reply!.topics),
              if (message.reply!.notice != null) ...<Widget>[
                const SizedBox(height: Insets.xs),
                Text(
                  message.reply!.notice!,
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

class _MatchList extends StatelessWidget {
  const _MatchList({required this.matches});

  final List<ChatMatch> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final match in matches)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          match.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      Text(
                        match.scoreLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${match.program} · ${match.year}',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (match.why.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        match.why,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TopicList extends StatelessWidget {
  const _TopicList({required this.topics});

  final List<ChatTopic> topics;

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Wrap(
        spacing: Insets.xs,
        runSpacing: Insets.xs,
        children: <Widget>[
          for (final topic in topics)
            Chip(
              avatar: CircleAvatar(
                radius: 9,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  '${topic.count}',
                  style: const TextStyle(fontSize: 9, color: AppTheme.primary),
                ),
              ),
              label: Text(topic.label),
            ),
        ],
      ),
    );
  }
}
