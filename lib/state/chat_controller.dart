import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/search_filters.dart';
import '../services/api_client.dart';

/// Owns the chatbot conversation shown in the sliding panel.
class ChatController extends ChangeNotifier {
  ChatController(this._api);

  final ApiClient _api;

  final List<ChatMessage> messages = <ChatMessage>[];
  ChatMode mode = ChatMode.similarity;
  bool sending = false;
  String? errorMessage;

  bool get isEmpty => messages.isEmpty;

  void setMode(ChatMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
  }

  Future<void> send(String text, {SearchFilters? filters}) async {
    final message = text.trim();
    if (message.isEmpty || sending) return;

    messages.add(ChatMessage(role: ChatRole.user, text: message));
    messages.add(const ChatMessage(role: ChatRole.assistant, text: '', pending: true));
    sending = true;
    errorMessage = null;
    notifyListeners();

    try {
      final reply = await _api.chat(
        message: message,
        mode: mode,
        filters: filters,
      );
      _replacePending(reply.answer, reply: reply);
    } on ApiException catch (error) {
      errorMessage = error.message;
      _replacePending(
        'Maaf, permintaan tidak dapat diproses. Silakan coba lagi.',
        failed: true,
      );
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void clear() {
    messages.clear();
    errorMessage = null;
    notifyListeners();
  }

  void _replacePending(String answer, {ChatReply? reply, bool failed = false}) {
    if (messages.isEmpty) return;
    messages[messages.length - 1] = ChatMessage(
      role: ChatRole.assistant,
      text: answer,
      reply: reply,
      failed: failed,
    );
  }
}
