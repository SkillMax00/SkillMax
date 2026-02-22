import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/onboarding_profile.dart';
import '../models/training_plan.dart';

class PlanGenerationService {
  PlanGenerationService({String? cloudFunctionUrl})
    : _cloudFunctionUrl =
          cloudFunctionUrl ?? const String.fromEnvironment('PLAN_FUNCTION_URL');

  final String _cloudFunctionUrl;
  String? _lastRemoteError;
  String? _lastAttemptedUrl;

  String? get lastRemoteError => _lastRemoteError;
  String? get lastAttemptedUrl => _lastAttemptedUrl;
  bool get hasFunctionUrl => _cloudFunctionUrl.trim().isNotEmpty;

  Future<TrainingPlan> generateInitialPlan(
    OnboardingProfile profile, {
    String? idToken,
  }) async {
    _lastRemoteError = null;
    _lastAttemptedUrl = null;
    if (_cloudFunctionUrl.trim().isNotEmpty) {
      final remotePlan = await _generateWithCloudFunction(
        profile,
        idToken: idToken,
      );
      if (remotePlan != null) {
        debugPrint('PlanGenerationService: AI plan generated successfully.');
        return remotePlan;
      }
      debugPrint(
        'PlanGenerationService: Falling back to local plan. '
        'Reason: ${_lastRemoteError ?? 'unknown'}',
      );
    } else {
      _lastRemoteError = 'PLAN_FUNCTION_URL is empty.';
      debugPrint(
        'PlanGenerationService: PLAN_FUNCTION_URL missing. Using fallback plan.',
      );
    }

    return _generateFallbackPlan(profile);
  }

  Future<TrainingPlan?> _generateWithCloudFunction(
    OnboardingProfile profile, {
    String? idToken,
  }) async {
    final client = HttpClient();
    try {
      final functionUri = Uri.tryParse(_cloudFunctionUrl);
      if (functionUri == null ||
          !functionUri.hasScheme ||
          !functionUri.hasAuthority) {
        _lastRemoteError = 'Invalid PLAN_FUNCTION_URL: $_cloudFunctionUrl';
        return null;
      }
      _lastAttemptedUrl = functionUri.toString();

      final request = await client.postUrl(functionUri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (idToken != null && idToken.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      } else {
        _lastRemoteError =
            'Missing Firebase ID token for function auth header.';
      }
      request.add(
        utf8.encode(jsonEncode(<String, dynamic>{'profile': profile.toMap()})),
      );

      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response);
        _lastRemoteError =
            'HTTP ${response.statusCode} from function: ${body.trim()}';
        return null;
      }

      final body = await utf8.decodeStream(response);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        _lastRemoteError = 'Function response was not a JSON object.';
        return null;
      }

      final planMap = decoded['plan'];
      if (planMap is! Map<String, dynamic>) {
        _lastRemoteError = 'Function response missing "plan" object.';
        return null;
      }

      return TrainingPlan.fromMap(planMap);
    } catch (e) {
      _lastRemoteError = 'Exception while calling function: $e';
      return null;
    } finally {
      client.close(force: true);
    }
  }

  TrainingPlan _generateFallbackPlan(OnboardingProfile profile) {
    final createdAt = DateTime.now();
    final planId = 'plan_${createdAt.millisecondsSinceEpoch}';

    final days = profile.daysPerWeek ?? 4;
    final length = profile.workoutLength ?? '25-35';

    final weeklySplit = _buildWeeklySplit(days);

    return TrainingPlan(
      id: planId,
      userId: profile.userId,
      createdAt: createdAt,
      daysPerWeek: days,
      workoutLength: length,
      weeklySplit: weeklySplit,
      skillTrack: profile.skills.take(3).toList(growable: false),
      blocks: <String>[
        'Strength block',
        'Skill progression',
        'Mobility / prehab',
        'Recovery targets',
      ],
      generator: 'fallback',
    );
  }

  List<String> _buildWeeklySplit(int days) {
    if (days <= 2) {
      return <String>['Full Body + Skills', 'Full Body + Mobility'];
    }
    if (days == 3) {
      return <String>['Push + Skill', 'Pull + Skill', 'Legs + Core'];
    }
    if (days == 4) {
      return <String>['Push', 'Pull', 'Legs + Core', 'Skill Focus'];
    }
    if (days == 5) {
      return <String>[
        'Push',
        'Pull',
        'Legs + Core',
        'Skill Focus',
        'Conditioning + Mobility',
      ];
    }

    return <String>[
      'Push',
      'Pull',
      'Legs + Core',
      'Skill Focus',
      'Volume Strength',
      'Mobility + Recovery',
    ];
  }
}
