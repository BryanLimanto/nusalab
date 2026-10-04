import 'package:flutter/foundation.dart';

import '../models/proposal_draft.dart';
import '../services/api_client.dart';

/// Owns the proposal generator conversation shown in [ProposalPanel].
///
/// The endpoint is stateless, so this controller resends the recent turns with every
/// call instead of relying on a server-side session. The track is resolved in two steps:
/// the first message is the research idea, then the student answers RISET or PROYEK
/// (through the quick replies or by typing it).
class ProposalController extends ChangeNotifier {
  ProposalController(this._api);

  final ApiClient _api;

  /// Backend caps on the payload it accepts.
  static const int maxHistoryTurns = 10;
  static const int maxTurnLength = 4000;

  final List<ProposalMessage> messages = <ProposalMessage>[];

  /// Track chosen by the student, kept so the composer stays disabled afterwards.
  ProposalPath? path;

  bool sending = false;
  String? errorMessage;

  bool get isEmpty => messages.isEmpty;

  /// True while the server still has to be asked about the track, so the panel offers
  /// the RISET / PROYEK quick replies.
  bool get awaitingTrack =>
      messages.any((ProposalMessage message) =>
          message.draft?.stage == ProposalStage.clarify);

  /// First turn: the title or idea the draft is built from.
  Future<void> sendIdea(String idea, {String? concentration}) =>
      _submit(idea, concentration: concentration);

  /// Second turn: the student picked a track in the UI, which skips the text detection.
  Future<void> chooseTrack(ProposalPath value, {String? concentration}) {
    path = value;
    return _submit(value.label, explicitPath: value, concentration: concentration);
  }

  void clear() {
    messages.clear();
    path = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _submit(
    String text, {
    ProposalPath? explicitPath,
    String? concentration,
  }) async {
    final message = text.trim();
    if (message.isEmpty || sending) return;

    messages.add(ProposalMessage(role: ProposalRole.user, text: message));
    messages.add(const ProposalMessage(role: ProposalRole.assistant, text: '', pending: true));
    sending = true;
    errorMessage = null;
    notifyListeners();

    try {
      final draft = await _api.proposal(
        message: message,
        history: _history(),
        path: explicitPath,
        concentration: concentration,
      );
      path = draft.path ?? path;
      _replacePending(
        ProposalMessage(
          role: ProposalRole.assistant,
          text: draft.answer,
          draft: draft,
        ),
      );
    } on ApiException catch (error) {
      errorMessage = error.message;
      _replacePending(
        const ProposalMessage(
          role: ProposalRole.assistant,
          text: 'Maaf, draf belum dapat dibuat. Silakan coba lagi.',
          failed: true,
        ),
      );
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  /// Prior turns as the API expects them. Pending and failed bubbles are skipped, and
  /// only the most recent turns are kept so the payload stays inside the server limits.
  List<ProposalTurn> _history() {
    final turns = <ProposalTurn>[
      for (final message in messages)
        if (!message.pending &&
            !message.failed &&
            message.text.isNotEmpty &&
            message.draft == null)
          ProposalTurn(
            role: message.role,
            content: _clip(message.text),
          ),
    ];
    return turns.length <= maxHistoryTurns
        ? turns
        : turns.sublist(turns.length - maxHistoryTurns);
  }

  String _clip(String value) => value.length <= maxTurnLength
      ? value
      : value.substring(0, maxTurnLength);

  void _replacePending(ProposalMessage replacement) {
    if (messages.isEmpty) return;
    messages[messages.length - 1] = replacement;
  }
}