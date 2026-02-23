import 'dart:convert';
import 'dart:io';

class CoachChatService {
  CoachChatService({String? cloudFunctionUrl})
    : _cloudFunctionUrl =
          cloudFunctionUrl ?? const String.fromEnvironment('COACH_FUNCTION_URL');

  final String _cloudFunctionUrl;
  String? _lastError;
  String? _lastAttemptedUrl;

  bool get hasFunctionUrl => _cloudFunctionUrl.trim().isNotEmpty;
  String? get lastError => _lastError;
  String? get lastAttemptedUrl => _lastAttemptedUrl;

  Future<CoachChatResult?> chat({
    required String message,
    required String idToken,
    required Map<String, dynamic> context,
  }) async {
    _lastError = null;
    _lastAttemptedUrl = null;

    final url = _cloudFunctionUrl.trim();
    if (url.isEmpty) {
      _lastError = 'COACH_FUNCTION_URL is empty.';
      return null;
    }

    final functionUri = Uri.tryParse(url);
    if (functionUri == null || !functionUri.hasScheme || !functionUri.hasAuthority) {
      _lastError = 'Invalid COACH_FUNCTION_URL: $url';
      return null;
    }

    final client = HttpClient();
    try {
      _lastAttemptedUrl = functionUri.toString();
      final request = await client.postUrl(functionUri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      request.add(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'message': message,
            'context': context,
          }),
        ),
      );

      final response = await request.close().timeout(const Duration(seconds: 45));
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = 'HTTP ${response.statusCode}: ${body.trim()}';
        return null;
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        _lastError = 'Response was not a JSON object.';
        return null;
      }

      return CoachChatResult.fromMap(decoded);
    } catch (e) {
      _lastError = 'Exception while calling coach function: $e';
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class CoachChatResult {
  CoachChatResult({
    required this.message,
    this.proposedPlanDiff,
    this.proposedWorkoutEdits,
  });

  final String message;
  final Map<String, dynamic>? proposedPlanDiff;
  final Map<String, dynamic>? proposedWorkoutEdits;

  factory CoachChatResult.fromMap(Map<String, dynamic> map) {
    return CoachChatResult(
      message: map['message']?.toString() ?? 'Coach is ready.',
      proposedPlanDiff: _asMap(map['proposedPlanDiff']),
      proposedWorkoutEdits: _asMap(map['proposedWorkoutEdits']),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      final output = <String, dynamic>{};
      for (final entry in value.entries) {
        output[entry.key.toString()] = entry.value;
      }
      return output;
    }
    return null;
  }
}
