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
    );
  }
}
