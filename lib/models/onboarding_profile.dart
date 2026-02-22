class OnboardingProfile {
  OnboardingProfile({
    required this.userId,
    required this.createdAt,
    required this.answers,
    this.gender,
    this.height,
    this.heightUnit,
    this.weight,
    this.weightUnit,
    this.goal,
    this.level,
    this.skills = const <String>[],
    this.equipment = const <String>[],
    this.daysPerWeek,
    this.workoutLength,
    this.birthDate,
    this.age,
  });

  final String userId;
  final DateTime createdAt;
  final Map<String, dynamic> answers;

  final String? gender;
  final double? height;
  final String? heightUnit;
  final double? weight;
  final String? weightUnit;
  final String? goal;
  final String? level;
  final List<String> skills;
  final List<String> equipment;
  final int? daysPerWeek;
  final String? workoutLength;
  final DateTime? birthDate;
  final int? age;

  factory OnboardingProfile.fromOnboardingAnswers({
    required String userId,
    required Map<String, dynamic> answers,
  }) {
    final now = DateTime.now();
    final birthdayRaw = answers['birthday'];
    final birthday = birthdayRaw is String
        ? DateTime.tryParse(birthdayRaw)
        : null;

    int? calculatedAge;
    if (birthday != null) {
      calculatedAge = now.year - birthday.year;
      final hadBirthday =
          now.month > birthday.month ||
          (now.month == birthday.month && now.day >= birthday.day);
      if (!hadBirthday) {
        calculatedAge -= 1;
      }
    }

    final skills = (answers['skills'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(growable: false);

    final equipment =
        (answers['equipment'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(growable: false);

    return OnboardingProfile(
      userId: userId,
      createdAt: now,
      answers: Map<String, dynamic>.from(answers),
      gender: answers['gender']?.toString(),
      height: _asDouble(answers['height']),
      heightUnit: answers['height_unit']?.toString(),
      weight: _asDouble(answers['weight']),
      weightUnit: answers['weight_unit']?.toString(),
      goal: answers['goal']?.toString(),
      level: answers['experience']?.toString(),
      skills: skills,
      equipment: equipment,
      daysPerWeek: int.tryParse(answers['days_per_week']?.toString() ?? ''),
      workoutLength: answers['workout_length']?.toString(),
      birthDate: birthday,
      age: calculatedAge,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'answers': answers,
      'gender': gender,
      'height': height,
      'heightUnit': heightUnit,
      'weight': weight,
      'weightUnit': weightUnit,
      'goal': goal,
      'level': level,
      'skills': skills,
      'equipment': equipment,
      'daysPerWeek': daysPerWeek,
      'workoutLength': workoutLength,
      'birthDate': birthDate?.toIso8601String(),
      'age': age,
    };
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
