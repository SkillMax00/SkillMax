import 'package:flutter/material.dart';

import 'login_view.dart';
import 'onboarding_flow_view.dart';
import 'signup_view.dart';

const _kBlue = Color(0xFF1E628C);
const _kBlueDeep = Color(0xFF123F5C);
const _kText = Color(0xFF122433);
const _kSubtle = Color(0xFF5A7386);

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  void _startOnboarding(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OnboardingFlowView()));
  }

  void _openLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginView()));
  }

  void _openSignUp(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignUpView()));
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2474A7), Color(0xFF184E70), Color(0xFF112F45)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 63, 92, 0.26),
            blurRadius: 34,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -24,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                color: Color(0x2FFFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -48,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                color: Color(0x26FFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'SkillMax',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Adaptive training for real progress',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Plans update with your recovery, schedule, and results.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8FD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildHeroCard(context)),
              const SizedBox(height: 22),
              Text(
                'Build strength with a plan that adjusts to you',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _kText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Personalized training, skill progressions, and smarter weekly structure.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kSubtle,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => _startOnboarding(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _openLogin(context),
                style: TextButton.styleFrom(
                  foregroundColor: _kBlueDeep,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text(
                  'Already have an account? Sign in',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => _openSignUp(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4B667B),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                ),
                child: const Text('Skip (Debug)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
