import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/onboarding_profile.dart';
import '../models/training_plan.dart';
import '../models/training_session_result.dart';

class TrainingDataRepository {
  TrainingDataRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> saveOnboardingProfile(OnboardingProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.userId)
        .collection('profile')
        .doc('current')
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> saveTrainingPlan(String userId, TrainingPlan plan) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(plan.id)
        .set(plan.toMap(), SetOptions(merge: true));

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('current')
        .set(<String, dynamic>{
          'activePlanId': plan.id,
          'lastPlanCreatedAt': plan.createdAt.toIso8601String(),
        }, SetOptions(merge: true));
  }

  Future<void> savePlanGenerationDiagnostic(
    String userId,
    Map<String, dynamic> diagnostic,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('current')
        .set(<String, dynamic>{
          'lastPlanGenerationDiagnostic': diagnostic,
        }, SetOptions(merge: true));
  }

  Future<void> saveSessionResult(TrainingSessionResult result) async {
    await _firestore
        .collection('users')
        .doc(result.userId)
        .collection('sessions')
        .doc(result.id)
        .set(result.toMap(), SetOptions(merge: true));
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('current')
        .set(patch, SetOptions(merge: true));
  }
}
