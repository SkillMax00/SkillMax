import 'package:flutter/material.dart';

import 'login_view.dart';
import 'onboarding_flow_view.dart';
import 'signup_view.dart';

const _kBg = Color(0xFFF7F5F2);
const _kInk = Color(0xFF0E0E12);
const _kMuted = Color(0xFF2A2931);

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

  Widget _buildPhonePreview(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 510),
            child: AspectRatio(
              aspectRatio: 0.57,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(52),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.16),
                      blurRadius: 22,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: Container(
                    color: const Color(0xFF17161D),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.fitness_center,
                            color: Colors.white70,
                            size: 58,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Temporary image/GIF spot',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Show workout preview here',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    Expanded(child: _buildPhonePreview(context)),
                    const SizedBox(height: 18),
                    Text(
                      'Working out\nmade easy',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _kInk,
                            fontSize: 48,
                            height: 1.02,
                          ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _startOnboarding(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kInk,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _openLogin(context),
                style: TextButton.styleFrom(
                  foregroundColor: _kInk,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    TextSpan(
                      text: 'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _kMuted,
                        fontSize: 15,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _kInk,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openSignUp(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF55555B),
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
