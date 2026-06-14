import 'api_client.dart';

class AiAssistantService {
  final ApiClient _apiClient;

  AiAssistantService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<String> ask({
    required String question,
    String cycleContext = '',
  }) async {
    try {
      final response = await _apiClient.post(
        '/ai/chat',
        body: {'question': question.trim()},
      );
      final answer = response['answer']?.toString().trim();
      if (answer == null || answer.isEmpty) {
        throw const AiAssistantException(
          'ИИ вернул пустой ответ. Попробуйте сформулировать вопрос еще раз.',
        );
      }
      return answer;
    } on ApiException catch (error) {
      throw AiAssistantException(_messageForApiError(error));
    } catch (error) {
      if (error is AiAssistantException) rethrow;
      throw AiAssistantException(_networkErrorText(error.toString()));
    }
  }

  String _messageForApiError(ApiException error) {
    final message = error.message.toLowerCase();
    if (error.statusCode == 401 || message.contains('missing bearer')) {
      return 'Я смогу учитывать календарь после входа в аккаунт. Войдите и повторите вопрос.';
    }
    if (error.statusCode == 403) {
      return 'Ассистент доступен для клиентского аккаунта. Войдите как клиент.';
    }
    if (message.contains('local-ai-unavailable')) {
      return 'Локальная модель не запущена. Запустите Ollama или продолжайте с безопасными базовыми советами backend.';
    }
    return 'Не получилось получить ответ ассистента. Код ошибки: ${error.statusCode ?? 'нет'}';
  }

  String _networkErrorText(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('xmlhttprequest') ||
        lower.contains('cors') ||
        lower.contains('access-control')) {
      return 'Браузер заблокировал запрос к backend. Проверьте BACKEND_API_URL в .env.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return 'Не получилось подключиться к backend. Проверьте, что FastAPI запущен.';
    }
    return 'Не получилось отправить запрос ассистенту: $message';
  }
}

class AiAssistantException implements Exception {
  final String message;

  const AiAssistantException(this.message);

  @override
  String toString() => message;
}
