import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/repository_search_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_panel.dart';
import '../widgets/filter_sidebar.dart';
import '../widgets/proposal_panel.dart';
import '../widgets/search_header.dart';
import '../widgets/state_views.dart';
import '../widgets/thesis_card.dart';
import 'publications_screen.dart';

/// Repository screen: search header, left filter sidebar, right results list, and the
/// chatbot FAB.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _sidebarWidth = 268;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RepositorySearchController>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RepositorySearchController>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isWide ? Insets.lg : 0,
        title: const _Brand(),
        leading: isWide
            ? null
            : Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Filter',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        actions: <Widget>[
          if (isWide) ...<Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Home'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed(PublicationsScreen.routeName),
              child: const Text('Publications'),
            ),
            TextButton.icon(
              onPressed: () => ProposalPanel.show(context),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Chatbot Proposal AI'),
            ),
            TextButton.icon(
              onPressed: () => ChatPanel.show(context),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Chatbot'),
            ),
          ] else ...<Widget>[
            IconButton(
              tooltip: 'Generator Proposal TA',
              icon: const Icon(Icons.description_outlined),
              onPressed: () => ProposalPanel.show(context),
            ),
            IconButton(
              tooltip: 'Chatbot',
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () => ChatPanel.show(context),
            ),
          ],
          const SizedBox(width: Insets.sm),
        ],
        bottom: isWide
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(height: 1, color: AppTheme.border),
              ),
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (isWide) ...<Widget>[
              const VerticalDivider(width: 1),
              const SizedBox(width: _sidebarWidth, child: FilterSidebar()),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: Column(
                children: <Widget>[
                  const SearchHeader(),
                  const Divider(height: 1),
                  Expanded(child: _Results(controller: controller, isWide: isWide)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton.small(
            heroTag: 'proposal-fab',
            tooltip: 'Generator Proposal TA',
            onPressed: () => ProposalPanel.show(context),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            // The small variant takes a `child`; the default one takes an `icon`.
            child: const Icon(Icons.description_outlined, size: 18),
          ),
          const SizedBox(height: Insets.sm),
          FloatingActionButton.extended(
            heroTag: 'chat-fab',
            onPressed: () => ChatPanel.show(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Tanya AI'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ],
      ),
      drawer: isWide ? null : const Drawer(child: SafeArea(child: FilterSidebar())),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.controller, required this.isWide});

  final RepositorySearchController controller;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (controller.status == LoadStatus.loading && controller.result.items.isEmpty) {
      return const LoadingView(label: 'Memuat repository…');
    }
    if (controller.status == LoadStatus.error) {
      return ErrorView(
        message: controller.errorMessage ?? 'Terjadi kesalahan.',
        onRetry: controller.refresh,
      );
    }
    if (controller.result.isEmpty) {
      return EmptyView(
        title: 'Tidak ada TA yang cocok',
        message: controller.filters.hasFilters || controller.filters.hasQuery
            ? 'Coba longgarkan filter atau gunakan kata kunci yang lebih umum.'
            : 'Repository belum memiliki data.',
        actionLabel: controller.filters.hasFilters ? 'Reset filter' : null,
        onAction: controller.filters.hasFilters ? controller.resetFilters : null,
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: controller.result.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int index) =>
                ThesisCard(thesis: controller.result.items[index]),
          ),
        ),
        _ResultFooter(controller: controller),
      ],
    );
  }
}

class _ResultFooter extends StatelessWidget {
  const _ResultFooter({required this.controller});

  final RepositorySearchController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = controller.result.total == 0 ? 0 : controller.offset + 1;
    final end = controller.offset + controller.result.items.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Menampilkan $start–$end dari ${controller.total} TA',
              style: theme.textTheme.labelMedium,
            ),
          ),
          TextButton(
            onPressed: controller.hasPreviousPage ? controller.previousPage : null,
            child: const Text('Sebelumnya'),
          ),
          TextButton(
            onPressed: controller.hasNextPage ? controller.nextPage : null,
            child: const Text('Berikutnya'),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'UKP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: Insets.sm),
        Flexible(
          child: Text(
            'Repository TA',
            overflow: TextOverflow.ellipsis,
            style: theme.appBarTheme.titleTextStyle,
          ),
        ),
      ],
    );
  }
}
