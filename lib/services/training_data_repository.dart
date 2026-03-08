import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

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

  Future<String> ensureReferralCodeForUser(String userId) async {
    final profileRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('current');

    final existingProfile = await profileRef.get();
    final existingCode = existingProfile.data()?['referralOwnCode']?.toString();
    if (existingCode != null && existingCode.isNotEmpty) {
      return existingCode;
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      final code = _generateReferralCode();
      final codeRef = _firestore.collection('referral_codes').doc(code);

      final created = await _firestore.runTransaction<bool>((tx) async {
        final codeSnap = await tx.get(codeRef);
        if (codeSnap.exists) return false;
        tx.set(codeRef, <String, dynamic>{
          'code': code,
          'ownerUserId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(profileRef, <String, dynamic>{
          'referralOwnCode': code,
        }, SetOptions(merge: true));
        return true;
      });

      if (created) {
        return code;
      }
    }

    throw StateError('Unable to allocate a unique referral code.');
  }

  Future<void> applyReferralCode({
    required String userId,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;

    final profileRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('current');
    final referrerDoc = await _firestore
        .collection('referral_codes')
        .doc(normalized)
        .get();
    final ownerId = referrerDoc.data()?['ownerUserId']?.toString();

    if (!referrerDoc.exists || ownerId == null || ownerId.isEmpty) {
      await profileRef.set(<String, dynamic>{
        'enteredReferralCode': normalized,
        'referralStatus': 'invalid',
      }, SetOptions(merge: true));
      return;
    }

    if (ownerId == userId) {
      await profileRef.set(<String, dynamic>{
        'enteredReferralCode': normalized,
        'referralStatus': 'self',
      }, SetOptions(merge: true));
      return;
    }

    await profileRef.set(<String, dynamic>{
      'enteredReferralCode': normalized,
      'referredByCode': normalized,
      'referredByUserId': ownerId,
      'referredAt': FieldValue.serverTimestamp(),
      'referralStatus': 'applied',
    }, SetOptions(merge: true));
  }

  static final Random _random = Random.secure();

  static String _generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List<String>.generate(
      8,
      (_) => chars[_random.nextInt(chars.length)],
      growable: false,
    ).join();
  }
}
