class TrainingSessionResult {
  TrainingSessionResult({
    required this.id,
    required this.userId,
    required this.completedAt,
    required this.completed,
    required this.difficulty,
    required this.painScore,
    this.notes,
  });

  final String id;
  final String userId;
  final DateTime completedAt;
  final bool completed;
  final int difficulty;
  final int painScore;
  final String? notes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'completedAt': completedAt.toIso8601String(),
      'completed': completed,
      'difficulty': difficulty,
      'painScore': painScore,
      'notes': notes,
    };
  }
}
