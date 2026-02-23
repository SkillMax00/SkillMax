class TrainingPlan {
  TrainingPlan({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.daysPerWeek,
    required this.workoutLength,
    required this.weeklySplit,
    required this.skillTrack,
    required this.blocks,
    required this.generator,
    this.activeWeekStartDate,
    this.scheduleDays = const <PlanScheduleDay>[],
    this.skillTracks = const <SkillTrackProgress>[],
    this.volumeTargets = const <VolumeTarget>[],
    this.progressionRules = const <String>[],
    this.workoutDays = const <WorkoutDayPlan>[],
  });

  final String id;
  final String userId;
  final DateTime createdAt;
  final int daysPerWeek;
  final String workoutLength;
  final List<String> weeklySplit;
  final List<String> skillTrack;
  final List<String> blocks;
  final String generator;
  final DateTime? activeWeekStartDate;
  final List<PlanScheduleDay> scheduleDays;
  final List<SkillTrackProgress> skillTracks;
  final List<VolumeTarget> volumeTargets;
  final List<String> progressionRules;
  final List<WorkoutDayPlan> workoutDays;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'daysPerWeek': daysPerWeek,
      'workoutLength': workoutLength,
      'weeklySplit': weeklySplit,
      'skillTrack': skillTrack,
      'blocks': blocks,
      'generator': generator,
      'activeWeekStartDate': activeWeekStartDate?.toIso8601String(),
      'scheduleDays': scheduleDays.map((e) => e.toMap()).toList(),
      'skillTracks': skillTracks.map((e) => e.toMap()).toList(),
      'volumeTargets': volumeTargets.map((e) => e.toMap()).toList(),
      'progressionRules': progressionRules,
      'workoutDays': workoutDays.map((e) => e.toMap()).toList(),
    };
  }

  factory TrainingPlan.fromMap(Map<String, dynamic> map) {
    return TrainingPlan(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      daysPerWeek: (map['daysPerWeek'] as num?)?.toInt() ?? 4,
      workoutLength: map['workoutLength']?.toString() ?? '25-35',
      weeklySplit: (map['weeklySplit'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      skillTrack: (map['skillTrack'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      blocks: (map['blocks'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      generator: map['generator']?.toString() ?? 'fallback',
      activeWeekStartDate: DateTime.tryParse(
        map['activeWeekStartDate']?.toString() ?? '',
      ),
      scheduleDays: (map['scheduleDays'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PlanScheduleDay.fromMap)
          .toList(growable: false),
      skillTracks: (map['skillTracks'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SkillTrackProgress.fromMap)
          .toList(growable: false),
      volumeTargets: (map['volumeTargets'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(VolumeTarget.fromMap)
          .toList(growable: false),
      progressionRules:
          (map['progressionRules'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(growable: false),
      workoutDays: (map['workoutDays'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutDayPlan.fromMap)
          .toList(growable: false),
    );
  }
}

class PlanScheduleDay {
  const PlanScheduleDay({
    required this.date,
    required this.type,
    this.status = 'scheduled',
  });

  final DateTime date;
  final String type;
  final String status;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': date.toIso8601String(),
      'type': type,
      'status': status,
    };
  }

  factory PlanScheduleDay.fromMap(Map<String, dynamic> map) {
    return PlanScheduleDay(
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      type: map['type']?.toString() ?? 'Skill',
      status: map['status']?.toString() ?? 'scheduled',
    );
  }
}

class SkillTrackProgress {
  const SkillTrackProgress({
    required this.name,
    this.currentStep = 1,
    this.ladderSteps = const <String>[],
  });

  final String name;
  final int currentStep;
  final List<String> ladderSteps;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'currentStep': currentStep,
      'ladderSteps': ladderSteps,
    };
  }

  factory SkillTrackProgress.fromMap(Map<String, dynamic> map) {
    return SkillTrackProgress(
      name: map['name']?.toString() ?? 'Skill',
      currentStep: (map['currentStep'] as num?)?.toInt() ?? 1,
      ladderSteps: (map['ladderSteps'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class VolumeTarget {
  const VolumeTarget({
    required this.category,
    required this.target,
    this.completed = 0,
    this.unit = 'sets',
  });

  final String category;
  final int target;
  final int completed;
  final String unit;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'category': category,
      'target': target,
      'completed': completed,
      'unit': unit,
    };
  }

  factory VolumeTarget.fromMap(Map<String, dynamic> map) {
    return VolumeTarget(
      category: map['category']?.toString() ?? 'Push',
      target: (map['target'] as num?)?.toInt() ?? 0,
      completed: (map['completed'] as num?)?.toInt() ?? 0,
      unit: map['unit']?.toString() ?? 'sets',
    );
  }
}

class WorkoutDayPlan {
  const WorkoutDayPlan({
    required this.date,
    required this.type,
    required this.exercises,
    required this.estimatedMinutes,
    this.status = 'scheduled',
  });

  final DateTime date;
  final String type;
  final List<WorkoutExercise> exercises;
  final int estimatedMinutes;
  final String status;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': date.toIso8601String(),
      'type': type,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'estimatedMinutes': estimatedMinutes,
      'status': status,
    };
  }

  factory WorkoutDayPlan.fromMap(Map<String, dynamic> map) {
    return WorkoutDayPlan(
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      type: map['type']?.toString() ?? 'Skill',
      exercises: (map['exercises'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutExercise.fromMap)
          .toList(growable: false),
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 40,
      status: map['status']?.toString() ?? 'scheduled',
    );
  }
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    required this.category,
    required this.progressionLevel,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.altExercises = const <String>[],
  });

  final String id;
  final String name;
  final String category;
  final int progressionLevel;
  final int sets;
  final String reps;
  final int restSeconds;
  final List<String> altExercises;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'progressionLevel': progressionLevel,
      'sets': sets,
      'reps': reps,
      'restSeconds': restSeconds,
      'altExercises': altExercises,
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Exercise',
      category: map['category']?.toString() ?? 'skill',
      progressionLevel: (map['progressionLevel'] as num?)?.toInt() ?? 1,
      sets: (map['sets'] as num?)?.toInt() ?? 3,
      reps: map['reps']?.toString() ?? '8-10',
      restSeconds: (map['restSeconds'] as num?)?.toInt() ?? 90,
      altExercises: (map['altExercises'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}
