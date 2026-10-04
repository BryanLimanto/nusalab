import 'package:flutter/material.dart';

/// Shared placement for the chatbot panels: a right-hand sliding panel on wide
/// viewports and a bottom sheet on narrow ones, so search results stay visible while
/// asking a question.
class ChatOverlay extends StatelessWidget {
  const ChatOverlay({super.key, required this.child});

  /// Below this width the panels open as a bottom sheet instead of a side panel.
  static const double wideBreakpoint = 900;

  /// Opens [child] using the layout that fits the current window.
  static Future<void> show(BuildContext context, {required Widget child}) {
    if (MediaQuery.sizeOf(context).width >= wideBreakpoint) {
      final overlay = ChatOverlay(child: child);
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Tutup panel',
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => overlay,
        transitionBuilder: (_, Animation<double> animation, __, Widget framed) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          // `framed` is the overlay built by `pageBuilder`. Reusing it instead of
          // constructing a second one keeps a single widget instance, and therefore a
          // single stateful panel, across the whole animation.
          child: framed,
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= wideBreakpoint;
    return Align(
      alignment: isWide ? Alignment.centerRight : Alignment.bottomCenter,
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(
          width: isWide ? 460 : double.infinity,
          height: isWide ? double.infinity : size.height * 0.86,
          child: child,
        ),
      ),
    );
  }
}