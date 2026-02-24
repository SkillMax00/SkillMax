class TrainingSessionResult {
  TrainingSessionResult({
    required this.id,
    required this.userId,
    required this.completedAt,
    required this.completed,
    required this.difficulty,
    required this.painScore,
    this.energy,
    this.tooEasyExercises = const <String>[],
    this.tooHardExercises = const <String>[],
    this.exerciseLogs = const <Map<String, dynamic>>[],
    this.notes,
  });

  final String id;
  final String userId;
  final DateTime completedAt;
  final bool completed;
  final int difficulty;
  final int painScore;
  final String? energy;
  final List<String> tooEasyExercises;
  final List<String> tooHardExercises;
  final List<Map<String, dynamic>> exerciseLogs;
  final String? notes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'completedAt': completedAt.toIso8601String(),
      'completed': completed,
      'difficulty': difficulty,
      'painScore': painScore,
      'energy': energy,
      'tooEasyExercises': tooEasyExercises,
      'tooHardExercises': tooHardExercises,
      'exerciseLogs': exerciseLogs,
      'notes': notes,
    };
  }
}
