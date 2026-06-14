import 'dart:async';

import '../models/chat_thread.dart';
import 'api_client.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient();

  Stream<List<ChatThread>> watchChats() async* {
    while (true) {
      yield await _fetchChats();
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  Stream<List<ChatMessage>> watchMessages(String chatId) async* {
    while (true) {
      yield await _fetchMessages(chatId);
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<List<ChatThread>> fetchChats() => _fetchChats();

  Future<List<ChatMessage>> fetchMessages(String chatId) => _fetchMessages(chatId);

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _apiClient.post('/chats/$chatId/messages', body: {
      'text': trimmed,
    });
  }

  Future<List<ChatThread>> _fetchChats() async {
    final response = await _apiClient.getList('/chats');
    final chats = response
        .whereType<Map<String, dynamic>>()
        .map(ChatThread.fromJson)
        .where((chat) => chat.id.isNotEmpty)
        .toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  Future<List<ChatMessage>> _fetchMessages(String chatId) async {
    if (chatId.trim().isEmpty) return [];
    final response = await _apiClient.getList('/chats/$chatId/messages');
    return response
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .where((message) => message.id.isNotEmpty)
        .toList()
        .reversed
        .toList();
  }
}
