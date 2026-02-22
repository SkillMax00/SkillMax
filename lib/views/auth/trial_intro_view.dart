import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../controllers/subscription_controller.dart';
import '../../models/onboarding_profile.dart';
import '../../services/plan_generation_service.dart';
import '../../services/training_data_repository.dart';

const _kBg = Colors.white;
const _kInk = Color(0xFF111111);
const _kMuted = Color(0xFF666666);

class TrialIntroScreen extends ConsumerStatefulWidget {
  const TrialIntroScreen({super.key, this.onboardingData});

  final Map<String, dynamic>? onboardingData;

  @override
  ConsumerState<TrialIntroScreen> createState() => _TrialIntroScreenState();
}

class _TrialIntroScreenState extends ConsumerState<TrialIntroScreen> {
  final TrainingDataRepository _repository = TrainingDataRepository();
  final PlanGenerationService _planService = PlanGenerationService();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await ref
          .read(subscriptionControllerProvider.notifier)
          .init(appUserId: user.uid);
    });
  }

  Future<void> _openPaywall() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref
        .read(subscriptionControllerProvider.notifier)
        .showPaywall();

    if (!mounted) return;

    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      final saved = await _persistProfileAndPlan();
      if (!saved || !mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    if (result == PaywallResult.error) {
      setState(() => _error = 'Unable to load the paywall right now.');
    }

    setState(() => _isLoading = false);
  }

  Future<bool> _persistProfileAndPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Missing user session. Please sign in again.';
        _isLoading = false;
      });
      return false;
    }

    final onboardingData = widget.onboardingData;
    if (onboardingData == null || onboardingData.isEmpty) {
      setState(() => _isLoading = false);
      return true;
    }

    try {
      final idToken = await user.getIdToken();
      final profile = OnboardingProfile.fromOnboardingAnswers(
        userId: user.uid,
        answers: onboardingData,
      );
      await _repository.saveOnboardingProfile(profile);

      final plan = await _planService.generateInitialPlan(
        profile,
        idToken: idToken,
      );
      await _repository.saveTrainingPlan(user.uid, plan);
      await _repository
          .savePlanGenerationDiagnostic(user.uid, <String, dynamic>{
            'generatedAt': DateTime.now().toIso8601String(),
            'generator': plan.generator,
            'usedFallback': plan.generator != 'ai',
            'functionUrlConfigured': _planService.hasFunctionUrl,
            'attemptedFunctionUrl': _planService.lastAttemptedUrl,
            'remoteError': _planService.lastRemoteError,
          });

      if (plan.generator != 'ai') {
        debugPrint(
          'TrialIntroScreen: Saved fallback plan. '
          'Reason: ${_planService.lastRemoteError ?? 'unknown'}',
        );
      }

      setState(() => _isLoading = false);
      return true;
    } catch (_) {
      setState(() {
        _error = 'Unable to save your profile right now. Please try again.';
        _isLoading = false;
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'We want you to try SkillMax for free.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: _kInk, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unlock your full personalized plan now. You can cancel anytime.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: _kMuted),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F6F8),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE9E9ED)),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 60,
                                color: Color(0xFF222222),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Premium training unlocked',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _openPaywall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kInk,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB8B8BD),
                  disabledForegroundColor: const Color(0xFFF2F2F4),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Try for \$0.00'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => ref
                          .read(subscriptionControllerProvider.notifier)
                          .restorePurchases(),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text('Restore purchases'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
