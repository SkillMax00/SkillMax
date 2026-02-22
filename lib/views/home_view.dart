import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/subscription_controller.dart';
import '../models/training_plan.dart';

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
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.uid)
              .collection('profile')
              .doc('current')
              .snapshots(),
          builder: (context, profileSnapshot) {
            final profileMap =
                profileSnapshot.data?.data() ?? <String, dynamic>{};
            final activePlanId = profileMap['activePlanId']?.toString();

            return StreamBuilder<TrainingPlan?>(
              stream: _planStream(widget.user.uid, activePlanId),
              builder: (context, planSnapshot) {
                final plan = planSnapshot.data;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                        child: _Header(
                          email: widget.user.email,
                          onLogout: () async {
                            await controller.logOut();
                            await FirebaseAuth.instance.signOut();
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: _HeroCard(
                          isPremium: state.isPremium,
                          isLoading: state.isLoading,
                          plan: plan,
                          goal: profileMap['goal']?.toString(),
                          level: profileMap['level']?.toString(),
                          age: profileMap['age'],
                        ),
                      ),
                    ),
                    if (state.errorMessage != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    if (planSnapshot.connectionState == ConnectionState.waiting)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: LinearProgressIndicator(),
                        ),
                      )
                    else if (plan != null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                          child: _PlanMetaRow(plan: plan),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: _SectionCard(
                            title: 'Weekly Split',
                            icon: Icons.calendar_month_rounded,
                            child: _WeeklySplitList(split: plan.weeklySplit),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: _SectionCard(
                            title: 'Skill Track',
                            icon: Icons.bolt_rounded,
                            child: _TagWrap(
                              items: plan.skillTrack.isEmpty
                                  ? const <String>['Core strength', 'Form']
                                  : plan.skillTrack,
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: _SectionCard(
                            title: 'Training Blocks',
                            icon: Icons.widgets_rounded,
                            child: _BlockList(blocks: plan.blocks),
                          ),
                        ),
                      ),
                    ] else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                          child: _SectionCard(
                            title: 'No Plan Yet',
                            icon: Icons.fitness_center,
                            child: Text(
                              'Complete onboarding and purchase to generate your personalized plan.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF61666F)),
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                        child: _SectionCard(
                          title: 'Billing & Account',
                          icon: Icons.verified_user_rounded,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _ActionButton(
                                label: 'Manage Plan',
                                onPressed: controller.showCustomerCenter,
                              ),
                              _ActionButton(
                                label: 'Restore',
                                onPressed: controller.restorePurchases,
                                accent: false,
                              ),
                              _ActionButton(
                                label: 'Refresh',
                                onPressed: controller.refresh,
                                accent: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Stream<TrainingPlan?> _planStream(String userId, String? activePlanId) {
    if (activePlanId != null && activePlanId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('plans')
          .doc(activePlanId)
          .snapshots()
          .map((doc) {
            final data = doc.data();
            if (data == null) return null;
            return TrainingPlan.fromMap(data);
          });
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('plans')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((query) {
          if (query.docs.isEmpty) return null;
          return TrainingPlan.fromMap(query.docs.first.data());
        });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.email, required this.onLogout});

  final String? email;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkillMax Plan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0E1322),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              email ?? 'Athlete',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6C7382)),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Sign out',
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isPremium,
    required this.isLoading,
    required this.plan,
    required this.goal,
    required this.level,
    required this.age,
  });

  final bool isPremium;
  final bool isLoading;
  final TrainingPlan? plan;
  final String? goal;
  final String? level;
  final dynamic age;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (goal != null && goal!.isNotEmpty) _prettify(goal!),
      if (level != null && level!.isNotEmpty) _prettify(level!),
      if (age != null) '$age yrs',
    ].join('  •  ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E152A), Color(0xFF1C2F58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(14, 21, 42, 0.32),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(
                label: isPremium ? 'Premium Active' : 'Premium Inactive',
                color: isPremium
                    ? const Color(0xFF2FD686)
                    : const Color(0xFFF6A623),
              ),
              const SizedBox(width: 8),
              if (plan != null)
                _StatusChip(
                  label: plan!.generator == 'ai' ? 'AI Plan' : 'Fallback Plan',
                  color: plan!.generator == 'ai'
                      ? const Color(0xFF5BA9FF)
                      : const Color(0xFFB088FF),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            plan == null
                ? 'Your personalized plan will appear here.'
                : '${plan!.daysPerWeek} day program • ${plan!.workoutLength} min',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFDFE8FF),
                height: 1.35,
              ),
            ),
          ],
          if (isLoading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(
              color: Colors.white,
              backgroundColor: Color(0x66FFFFFF),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanMetaRow extends StatelessWidget {
  const _PlanMetaRow({required this.plan});

  final TrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetaTile(
            label: 'Sessions / week',
            value: '${plan.daysPerWeek}',
            icon: Icons.event_repeat_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetaTile(
            label: 'Duration',
            value: '${plan.workoutLength} min',
            icon: Icons.timer_rounded,
          ),
        ),
      ],
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E9F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF3FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Color(0xFF304C8A)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF707A8D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF121A2D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2A3F71), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF161F33),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WeeklySplitList extends StatelessWidget {
  const _WeeklySplitList({required this.split});

  final List<String> split;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(split.length, (index) {
        final day = index + 1;
        return Container(
          margin: EdgeInsets.only(bottom: index == split.length - 1 ? 0 : 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDE7FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A3F71),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  split[index],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF1F2638),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF233761),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BlockList extends StatelessWidget {
  const _BlockList({required this.blocks});

  final List<String> blocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: blocks
          .map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF29976C),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      block,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF20283A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0x40FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.accent = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent ? const Color(0xFF132651) : Colors.white,
          foregroundColor: accent ? Colors.white : const Color(0xFF2A3551),
          padding: const EdgeInsets.symmetric(vertical: 13),
          elevation: accent ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: accent
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFD7DEEA)),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

String _prettify(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
