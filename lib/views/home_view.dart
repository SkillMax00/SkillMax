import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/subscription_controller.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({required this.user, super.key});

  final User user;

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(subscriptionControllerProvider.notifier)
          .init(appUserId: widget.user.uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SkillMax'),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(subscriptionControllerProvider.notifier).logOut();
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.user.email ?? widget.user.uid,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.isPremium ? 'Premium: ACTIVE' : 'Premium: INACTIVE',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: controller.showPaywall,
              child: const Text('Show Paywall'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: controller.showPaywallIfNeeded,
              child: const Text('Show Paywall If Needed'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: controller.restorePurchases,
              child: const Text('Restore Purchases'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: controller.showCustomerCenter,
              child: const Text('Open Customer Center'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.refresh,
              child: const Text('Refresh Customer Info'),
            ),
          ],
        ),
      ),
    );
  }
}
