import 'api_client.dart';

class ChatService {
  final ApiClient _apiClient = ApiClient();

  Stream<List<Map<String, dynamic>>> watchMessages(String chatId) {
    return Stream.fromFuture(_fetchMessages(chatId));
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _apiClient.post('/chats/$chatId/messages', body: {
      'text': trimmed,
    });
  }

  Future<List<Map<String, dynamic>>> _fetchMessages(String chatId) async {
    final response = await _apiClient.getList('/chats/$chatId/messages');
    return response.whereType<Map<String, dynamic>>().toList().reversed.toList();
  }
}
