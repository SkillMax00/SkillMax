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
    final weekStart = _startOfWeek(createdAt);

    final days = profile.daysPerWeek ?? 4;
    final length = profile.workoutLength ?? '25-35';

    final weeklySplit = _buildWeeklySplit(days);
    final scheduleDays = List<PlanScheduleDay>.generate(days, (index) {
      return PlanScheduleDay(
        date: weekStart.add(Duration(days: index)),
        type: weeklySplit[index % weeklySplit.length],
      );
    });

    final workoutDays = scheduleDays
        .map(
          (day) => WorkoutDayPlan(
            date: day.date,
            type: day.type,
            estimatedMinutes: _lengthBucketToMinutes(length),
            exercises: _buildExercisesForType(
              day.type,
              profile: profile,
              isNoEquipment: profile.equipment.any(
                (e) => e.toLowerCase().contains('none') || e.contains('bodyweight'),
              ),
            ),
          ),
        )
        .toList(growable: false);

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
      activeWeekStartDate: weekStart,
      scheduleDays: scheduleDays,
      skillTracks: profile.skills
          .take(3)
          .map(
            (skill) => SkillTrackProgress(
              name: skill,
              currentStep: 1,
              ladderSteps: _defaultSkillLadder(skill),
            ),
          )
          .toList(growable: false),
      volumeTargets: _buildVolumeTargets(profile.goal),
      progressionRules: const <String>[
        'If all prescribed reps are met for 2 sessions, increase progression by 1 step.',
        'If RPE > 9 for 2 sessions, deload by reducing one set.',
        'If workout day is missed and adaptation is enabled, reshuffle remaining sessions.',
      ],
      workoutDays: workoutDays,
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

  int _lengthBucketToMinutes(String bucket) {
    if (bucket.contains('15-20')) return 20;
    if (bucket.contains('25-35')) return 32;
    if (bucket.contains('60+')) return 60;
    return 48;
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  List<WorkoutExercise> _buildExercisesForType(
    String type, {
    required OnboardingProfile profile,
    required bool isNoEquipment,
  }) {
    final lower = type.toLowerCase();
    final pullNeedsRegression = (profile.baselinePull ?? '').toLowerCase().contains('0');

    if (lower.contains('pull')) {
      return <WorkoutExercise>[
        WorkoutExercise(
          id: 'pull_focus',
          name: pullNeedsRegression || isNoEquipment
              ? 'Band-Assisted Row'
              : 'Strict Pull-Up',
          category: 'pull',
          progressionLevel: pullNeedsRegression ? 1 : 3,
          sets: 4,
          reps: pullNeedsRegression ? '6-8' : '5-7',
          restSeconds: 120,
          altExercises: const <String>['Ring Row', 'Inverted Row'],
        ),
        const WorkoutExercise(
          id: 'pull_accessory',
          name: 'Scapular Pull-Up',
          category: 'pull',
          progressionLevel: 2,
          sets: 3,
          reps: '10',
          restSeconds: 90,
          altExercises: <String>['Band Pulldown'],
        ),
      ];
    }

    if (lower.contains('legs')) {
      return const <WorkoutExercise>[
        WorkoutExercise(
          id: 'leg_focus',
          name: 'Bulgarian Split Squat',
          category: 'legs',
          progressionLevel: 3,
          sets: 4,
          reps: '8/side',
          restSeconds: 90,
          altExercises: <String>['Reverse Lunge'],
        ),
        WorkoutExercise(
          id: 'core_finish',
          name: 'Hollow Hold',
          category: 'core',
          progressionLevel: 2,
          sets: 4,
          reps: '25s',
          restSeconds: 60,
          altExercises: <String>['Dead Bug'],
        ),
      ];
    }

    if (lower.contains('mobility')) {
      return const <WorkoutExercise>[
        WorkoutExercise(
          id: 'mobility_flow',
          name: 'Shoulder CARs',
          category: 'mobility',
          progressionLevel: 2,
          sets: 3,
          reps: '8',
          restSeconds: 40,
          altExercises: <String>['Wall Slides'],
        ),
        WorkoutExercise(
          id: 'spine_flow',
          name: 'Thoracic Rotation Flow',
          category: 'mobility',
          progressionLevel: 2,
          sets: 3,
          reps: '8/side',
          restSeconds: 40,
          altExercises: <String>['Open Book'],
        ),
      ];
    }

    if (lower.contains('skill')) {
      return <WorkoutExercise>[
        WorkoutExercise(
          id: 'skill_focus',
          name: profile.skills.isNotEmpty ? '${profile.skills.first} Progression' : 'Handstand Hold',
          category: 'skill',
          progressionLevel: 2,
          sets: 5,
          reps: '20s',
          restSeconds: 75,
          altExercises: const <String>['Wall Drill'],
        ),
        const WorkoutExercise(
          id: 'skill_support',
          name: 'Scapular Stability Drill',
          category: 'skill',
          progressionLevel: 2,
          sets: 3,
          reps: '10',
          restSeconds: 60,
          altExercises: <String>['Band Pull-Apart'],
        ),
      ];
    }

    return <WorkoutExercise>[
      WorkoutExercise(
        id: 'push_focus',
        name: isNoEquipment ? 'Deficit Push-Up' : 'Ring Dip',
        category: 'push',
        progressionLevel: 3,
        sets: 4,
        reps: '6-8',
        restSeconds: 105,
        altExercises: const <String>['Bench Dip', 'Elevated Push-Up'],
      ),
      const WorkoutExercise(
        id: 'push_accessory',
        name: 'Pseudo Planche Push-Up',
        category: 'push',
        progressionLevel: 3,
        sets: 3,
        reps: '8',
        restSeconds: 90,
        altExercises: <String>['Incline Push-Up'],
      ),
    ];
  }

  List<String> _defaultSkillLadder(String skill) {
    return <String>[
      '$skill Foundation',
      '$skill Capacity',
      '$skill Strength',
      '$skill Control',
    ];
  }

  List<VolumeTarget> _buildVolumeTargets(String? goal) {
    if ((goal ?? '').toLowerCase().contains('mobility')) {
      return const <VolumeTarget>[
        VolumeTarget(category: 'Mobility', target: 5, unit: 'sessions'),
        VolumeTarget(category: 'Skill practice', target: 3, unit: 'sessions'),
        VolumeTarget(category: 'Core', target: 6, unit: 'sets'),
      ];
    }

    return const <VolumeTarget>[
      VolumeTarget(category: 'Push', target: 12, unit: 'sets'),
      VolumeTarget(category: 'Pull', target: 12, unit: 'sets'),
      VolumeTarget(category: 'Legs', target: 10, unit: 'sets'),
      VolumeTarget(category: 'Core', target: 10, unit: 'sets'),
      VolumeTarget(category: 'Skill practice', target: 4, unit: 'sessions'),
      VolumeTarget(category: 'Mobility', target: 3, unit: 'sessions'),
    ];
  }
}
