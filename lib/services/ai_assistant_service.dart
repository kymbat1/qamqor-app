import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiAssistantService {
  final http.Client _client;

  AiAssistantService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> ask({
    required String question,
    required String cycleContext,
  }) async {
    final config = _AiApiConfig.fromEnv();

    if (!config.isReady) {
      throw const AiAssistantException(
        'Добавьте XAI_API_KEY и XAI_MODEL в .env, затем перезапустите приложение.',
      );
    }

    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${config.baseUrl}/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${config.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': config.model,
              'messages': [
                {
                  'role': 'system',
                  'content': _instructions(cycleContext),
                },
                {
                  'role': 'user',
                  'content': question,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 35));
    } on http.ClientException catch (error) {
      throw AiAssistantException(_networkErrorText(error.message));
    } on Object catch (error) {
      throw AiAssistantException(_networkErrorText(error.toString()));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiAssistantException(_errorText(response));
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final text = _extractText(decoded);
    if (text == null || text.trim().isEmpty) {
      throw const AiAssistantException(
        'ИИ вернул пустой ответ. Попробуйте сформулировать вопрос еще раз.',
      );
    }

    return text.trim();
  }

  static String _instructions(String cycleContext) {
    return '''
Ты медицинский wellness-ассистент приложения Qamqor. Отвечай только на русском языке, спокойно и понятно.

Главная задача: помогать пользовательнице разобраться с циклом, симптомами, подготовкой к записи к врачу и самонаблюдением. Учитывай данные календаря ниже, но не выдавай прогнозы как точный диагноз.

$cycleContext

Правила безопасности:
- Не ставь диагноз и не назначай лекарства, гормоны или дозировки.
- Если пользователь пишет про резкую/необычную боль, обморок, температуру, очень обильное кровотечение, беременность, положительный тест, боль после секса, неприятный запах выделений или симптомы инфекции, мягко советуй обратиться к врачу срочно.
- Если вопрос про обычные спазмы во время месячных, предложи безопасные меры: отдых, вода, тепло на живот, отслеживание силы боли, запись к врачу при усилении или необычности.
- Для фолликулярной, овуляторной и лютеиновой фаз давай разные рекомендации по самонаблюдению, энергии, симптомам и подготовке к врачу.
- В конце дай 1-3 конкретных следующих шага.
''';
  }

  static String? _extractText(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }

    final first = choices.first;
    if (first is! Map) {
      return null;
    }

    final message = first['message'];
    if (message is! Map) {
      return null;
    }

    final content = message['content'];
    return content is String ? content : null;
  }

  static String _errorText(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        final message = error['message'] as String;
        if (message.toLowerCase().contains('model')) {
          return 'Модель Grok указана неверно или недоступна. Проверьте XAI_MODEL в .env.';
        }
        return 'Grok вернул ошибку: $message';
      }
      if (error is String && error.trim().isNotEmpty) {
        return 'Grok вернул ошибку: $error';
      }
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return 'Grok вернул ошибку: $message';
      }
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return 'Grok вернул ошибку: $detail';
      }
    } catch (_) {
      // The friendly status-based message below is enough for the UI.
    }

    if (response.statusCode == 400) {
      final body = utf8.decode(response.bodyBytes).trim();
      final preview = body.length > 180 ? body.substring(0, 180) : body;
      if (preview.isNotEmpty) {
        return 'Grok не принял формат запроса: $preview';
      }
      return 'Grok не принял формат запроса. Проверьте XAI_MODEL и XAI_API_BASE_URL в .env.';
    }
    if (response.statusCode == 401) {
      return 'Grok API key не принят. Проверьте XAI_API_KEY в .env.';
    }
    if (response.statusCode == 429) {
      return 'Grok временно ограничил запросы. Попробуйте позже или проверьте лимиты проекта.';
    }
    return 'Не удалось получить ответ ИИ. Код ошибки: ${response.statusCode}.';
  }

  static String _networkErrorText(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('xmlhttprequest') ||
        lower.contains('cors') ||
        lower.contains('access-control')) {
      return 'Браузер заблокировал прямой запрос к Grok. Для Web-версии нужен proxy через FastAPI backend.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return 'Не получилось подключиться к Grok. Проверьте интернет и XAI_API_BASE_URL в .env.';
    }
    return 'Не получилось отправить запрос к Grok: $message';
  }
}

class AiAssistantException implements Exception {
  final String message;

  const AiAssistantException(this.message);

  @override
  String toString() => message;
}

class _AiApiConfig {
  final String apiKey;
  final String model;
  final String baseUrl;

  _AiApiConfig({
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });

  bool get isReady => apiKey.isNotEmpty && model.isNotEmpty;

  factory _AiApiConfig.fromEnv() {
    final xaiKey = _env('XAI_API_KEY');
    final genericKey = _env('AI_API_KEY');
    final openAiKey = _env('OPENAI_API_KEY');
    final apiKey = xaiKey ?? genericKey ?? openAiKey ?? '';
    final modelFromEnv = xaiKey != null
        ? _env('XAI_MODEL') ?? _env('AI_MODEL') ?? 'latest'
        : _env('XAI_MODEL') ??
            _env('AI_MODEL') ??
            _env('OPENAI_MODEL') ??
            'latest';
    final model = _normalizeModel(modelFromEnv);
    final baseUrl = _normalizeBaseUrl(
      _env('XAI_API_BASE_URL') ??
          _env('AI_API_BASE_URL') ??
          'https://api.x.ai/v1',
    );

    return _AiApiConfig(
      apiKey: apiKey,
      model: model,
      baseUrl: baseUrl,
    );
  }

  static String? _env(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('/chat/completions')) {
      normalized = normalized.substring(
        0,
        normalized.length - '/chat/completions'.length,
      );
    }
    return normalized;
  }

  static String _normalizeModel(String value) {
    final normalized = value.trim();
    if (normalized == 'latest') {
      return 'grok-3-mini';
    }
    return normalized;
  }
}
