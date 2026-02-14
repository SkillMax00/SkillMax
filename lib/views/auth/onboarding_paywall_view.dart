import 'package:flutter/material.dart';

import 'login_view.dart';
import 'signup_view.dart';

class OnboardingPaywallView extends StatelessWidget {
  const OnboardingPaywallView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Unlock SkillMax Premium',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start with a free trial, then continue with full access to all SkillMax features.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What you get:'),
                          SizedBox(height: 8),
                          Text('- Full premium lessons'),
                          Text('- Personalized plans'),
                          Text('- Priority feature access'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const SignUpView(showPaywallAfterSignUp: true),
                        ),
                      );
                    },
                    child: const Text('Start Free Trial'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginView(),
                        ),
                      );
                    },
                    child: const Text('I Already Have an Account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
