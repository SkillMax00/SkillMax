import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/subscription_controller.dart';
import '../models/training_plan.dart';
import '../models/training_session_result.dart';
import '../services/coach_chat_service.dart';
import '../services/training_data_repository.dart';

const _kBgBase = Color(0xFFF7FAFD);
const _kBgCard = Color(0xFFFFFFFF);
const _kBgCardSoft = Color(0xFFF1F6FA);
const _kAccent = Color(0xFF1E628C);
const _kMuted = Color(0xFF6F8494);
const _kText = Color(0xFF112331);

class HomeView extends ConsumerStatefulWidget {
  const HomeView({required this.user, super.key});

  final User user;

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  final TrainingDataRepository _repository = TrainingDataRepository();
  final CoachChatService _coachService = CoachChatService();
  final TextEditingController _coachInputController = TextEditingController();

  int _tabIndex = 0;
  int _bodyCarouselIndex = 0;
  bool _showRecovery = false;
  bool _showTargetsIntro = true;
  bool _showNoAdaptBanner = true;

  List<_CoachMessage> _coachMessages = const <_CoachMessage>[];
  _PlanChangePreview? _pendingChange;
  List<_WorkoutDayUi>? _weekOverride;
  _WorkoutDayUi? _todayOverride;

  @override
  void initState() {
    super.initState();
    _coachMessages = <_CoachMessage>[
      const _CoachMessage(
        text:
            'Coach online. I can make your workout easier, swap exercises, and adapt your week if plans shift.',
        fromCoach: true,
      ),
    ];
    Future.microtask(
      () => ref
          .read(subscriptionControllerProvider.notifier)
          .init(appUserId: widget.user.uid),
    );
  }

  @override
  void dispose() {
    _coachInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionControllerProvider);
    final subController = ref.read(subscriptionControllerProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: _kBgBase,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0x0D1E628C), Color(0x051E628C), _kBgBase],
          ),
        ),
        child: SafeArea(
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

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.user.uid)
                        .collection('sessions')
                        .orderBy('completedAt', descending: true)
                        .snapshots(),
                    builder: (context, sessionsSnapshot) {
                      final sessionDocs = sessionsSnapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final sessions = sessionDocs
                          .map(_WorkoutLogUi.fromDoc)
                          .toList(growable: false);

                      final workoutData = _buildWorkoutData(
                        profileMap: profileMap,
                        plan: plan,
                        sessions: sessions,
                        isPremium: subState.isPremium,
                      );

                      final currentDay = _todayOverride ??
                          workoutData.weekDays.firstWhere(
                            (d) => d.date == workoutData.today.date,
                            orElse: () => workoutData.today,
                          );

                      final screen = _buildTabScreen(
                        context: context,
                        index: _tabIndex,
                        subState: subState,
                        subController: subController,
                        plan: plan,
                        profileMap: profileMap,
                        workoutData: workoutData,
                        today: currentDay,
                        sessions: sessions,
                      );

                      return Stack(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            child: screen,
                          ),
                          if (_tabIndex == 0 &&
                              !subState.isPremium &&
                              workoutData.hasLockedContent)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 88,
                              child: _UnlockBanner(
                                onTap: () async {
                                  await subController.showPaywall();
                                  await subController.refresh();
                                },
                              ),
                            ),
                          Positioned(
                            right: 16,
                            bottom: 90,
                            child: _CoachFab(
                              onTap: () {
                                _openCoach(
                                  context,
                                  workoutData,
                                  subController,
                                  subState,
                                  profileMap,
                                  plan,
                                  sessions,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _BottomTabBar(
        index: _tabIndex,
        onChange: (value) => setState(() => _tabIndex = value),
      ),
    );
  }

  Widget _buildTabScreen({
    required BuildContext context,
    required int index,
    required SubscriptionState subState,
    required SubscriptionController subController,
    required TrainingPlan? plan,
    required Map<String, dynamic> profileMap,
    required _WorkoutData workoutData,
    required _WorkoutDayUi today,
    required List<_WorkoutLogUi> sessions,
  }) {
    if (index == 1) {
      return _BodyTab(
        showRecovery: _showRecovery,
        onToggle: (value) => setState(() => _showRecovery = value),
        carouselIndex: _bodyCarouselIndex,
        onCarouselChanged: (index) => setState(() => _bodyCarouselIndex = index),
        sessions: sessions,
        focusExercises: today.exercises,
      );
    }

    if (index == 2) {
      return _TargetsTab(
        showIntro: _showTargetsIntro,
        onDismissIntro: () => setState(() => _showTargetsIntro = false),
        targets: workoutData.targets,
      );
    }

    if (index == 3) {
      return _LogTab(
        profileMap: profileMap,
        sessions: sessions,
        isPremium: subState.isPremium,
        onUpgradeTap: () async {
          await subController.showPaywall();
          await subController.refresh();
        },
        onSettingsTap: () => _openSettingsScreen(
          context,
          profileMap: profileMap,
          subState: subState,
          subController: subController,
        ),
        onSignOutTap: () async {
          await subController.logOut();
          await FirebaseAuth.instance.signOut();
        },
      );
    }

    return _WorkoutTab(
      today: today,
      weekDays: workoutData.weekDays,
      profileMap: profileMap,
      hasAutoAdapt: workoutData.adaptIfMissed,
      showNoAdaptBanner: _showNoAdaptBanner && !workoutData.adaptIfMissed,
      missedMessage: workoutData.missedMessage,
      isPremium: subState.isPremium,
      onAdaptNow: () {
        final adapted = _adaptWeekDays(workoutData.weekDays);
        setState(() {
          _weekOverride = adapted;
          _showNoAdaptBanner = false;
        });
        if (plan != null) {
          _persistWeekToPlan(plan, adapted);
        }
      },
      onKeepSchedule: () => setState(() => _showNoAdaptBanner = false),
      onOpenMenu: () => _showWorkoutMenu(
        context,
        workoutData: workoutData,
        plan: plan,
        profileMap: profileMap,
        sessions: sessions,
        subController: subController,
        subState: subState,
      ),
      onSwapTap: () {
        final swapped = _swapWorkout(today, workoutData);
        setState(() {
          _todayOverride = swapped;
        });
        if (plan != null) {
          _persistTodayToPlan(plan, swapped);
        }
      },
      onPickLength: () => _showSimplePicker(
        context,
        title: 'Workout Length',
        options: const <String>['15-20', '25-35', '40-55', '60+'],
      ),
      onPickEquipment: () => _showSimplePicker(
        context,
        title: 'Equipment Preset',
        options: const <String>['Large Gym', 'Home / Rings', 'Bodyweight only'],
      ),
      onLockedTap: () async {
        await subController.showPaywall();
        await subController.refresh();
      },
      onStartTap: () => _startWorkout(
        context,
        today: today,
        subState: subState,
        subController: subController,
        plan: plan,
        allDays: workoutData.weekDays,
      ),
    );
  }

  _WorkoutData _buildWorkoutData({
    required Map<String, dynamic> profileMap,
    required TrainingPlan? plan,
    required List<_WorkoutLogUi> sessions,
    required bool isPremium,
  }) {
    final now = DateTime.now();
    final weekStart = _startOfWeek(now);

    final generatedWeek = _buildWeekDays(
      weekStart: weekStart,
      profileMap: profileMap,
      plan: plan,
      sessions: sessions,
      isPremium: isPremium,
    );

    final weekDays = _weekOverride ?? generatedWeek;
    final today = weekDays.firstWhere(
      (day) => _isSameDay(day.date, now),
      orElse: () => weekDays.first,
    );

    final targets = _buildTargets(plan, sessions);
    final missed = weekDays
        .where((day) => day.status == _WorkoutStatus.missed)
        .toList(growable: false);

    final adaptIfMissed = profileMap['adaptIfMissDay'] == true ||
        profileMap['adapt_if_missed']?.toString().toLowerCase() == 'yes';

    if (adaptIfMissed && missed.isNotEmpty && _weekOverride == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final adapted = _adaptWeekDays(weekDays);
        setState(() {
          _weekOverride = adapted;
          _coachMessages = <_CoachMessage>[
            const _CoachMessage(
              text:
                  'I noticed a missed session. I shifted your week and softened one heavy day to keep momentum.',
              fromCoach: true,
            ),
            ..._coachMessages,
          ];
        });
        if (plan != null) {
          _persistWeekToPlan(plan, adapted);
        }
      });
    }

    return _WorkoutData(
      today: today,
      weekDays: weekDays,
      targets: targets,
      hasLockedContent: weekDays.any((d) => d.isLocked),
      adaptIfMissed: adaptIfMissed,
      missedMessage: missed.isEmpty
          ? null
          : 'Missed ${_weekdayName(missed.first.date.weekday)}. Want me to adapt your week?',
    );
  }

  List<_WorkoutDayUi> _buildWeekDays({
    required DateTime weekStart,
    required Map<String, dynamic> profileMap,
    required TrainingPlan? plan,
    required List<_WorkoutLogUi> sessions,
    required bool isPremium,
  }) {
    if (plan?.workoutDays.isNotEmpty == true) {
      final stored = plan!.workoutDays.toList(growable: true)
        ..sort((a, b) => a.date.compareTo(b.date));

      return List<_WorkoutDayUi>.generate(stored.length, (index) {
        final day = stored[index];
        final completed = sessions.any((log) => _isSameDay(log.completedAt, day.date));
        final status = completed
            ? _WorkoutStatus.completed
            : _isMissed(day.date)
                ? _WorkoutStatus.missed
                : _WorkoutStatus.scheduled;
        return _WorkoutDayUi(
          date: day.date,
          type: day.type,
          estimatedMinutes: day.estimatedMinutes,
          exercises: day.exercises
              .map(
                (e) => _ExerciseUi(
                  name: e.name,
                  sets: e.sets,
                  reps: e.reps,
                  level: e.progressionLevel,
                  category: e.category,
                ),
              )
              .toList(growable: false),
          status: status,
          isLocked: !isPremium && index > 0,
        );
      });
    }

    final skills = (profileMap['skills'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(growable: false);
    final equipment =
        (profileMap['equipment'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(growable: false);

    final split = plan?.weeklySplit.isNotEmpty == true
        ? plan!.weeklySplit
        : const <String>['Push', 'Pull', 'Legs + Core', 'Skill Focus'];

    final daysPerWeek = (profileMap['daysPerWeek'] as num?)?.toInt() ??
        (plan?.daysPerWeek ?? 4).clamp(2, 6);

    final scheduledDates = <DateTime>[];
    for (var i = 0; i < daysPerWeek; i++) {
      scheduledDates.add(weekStart.add(Duration(days: i)));
    }

    return List<_WorkoutDayUi>.generate(daysPerWeek, (index) {
      final dayDate = scheduledDates[index];
      final type = split[index % split.length];
      final completed = sessions.any((log) => _isSameDay(log.completedAt, dayDate));
      final status = completed
          ? _WorkoutStatus.completed
          : _isMissed(dayDate)
              ? _WorkoutStatus.missed
              : _WorkoutStatus.scheduled;

      final exercises = _generateExercises(
        type: type,
        skills: skills,
        equipment: equipment,
      );

      return _WorkoutDayUi(
        date: dayDate,
        type: type,
        estimatedMinutes: _estimateMinutes(profileMap['workoutLength']?.toString()),
        exercises: exercises,
        status: status,
        isLocked: !isPremium && index > 0,
      );
    });
  }

  bool _isMissed(DateTime plannedDate) {
    final now = DateTime.now();
    final cutoff = DateTime(plannedDate.year, plannedDate.month, plannedDate.day)
        .add(const Duration(days: 1, hours: 3));
    return now.isAfter(cutoff);
  }

  List<_TargetUi> _buildTargets(TrainingPlan? plan, List<_WorkoutLogUi> sessions) {
    final defaults = const <_TargetUi>[
      _TargetUi('Push', 12, 0, 'sets'),
      _TargetUi('Pull', 12, 0, 'sets'),
      _TargetUi('Legs', 10, 0, 'sets'),
      _TargetUi('Core', 10, 0, 'sets'),
      _TargetUi('Skill practice', 4, 0, 'sessions'),
      _TargetUi('Mobility', 3, 0, 'sessions'),
    ];

    if (plan?.volumeTargets.isNotEmpty == true) {
      return plan!.volumeTargets
          .map(
            (t) => _TargetUi(
              t.category,
              t.target,
              _estimateCompletedFromLogs(t.category, sessions),
              t.unit,
            ),
          )
          .toList(growable: false);
    }

    return defaults
        .map(
          (t) => _TargetUi(
            t.label,
            t.target,
            _estimateCompletedFromLogs(t.label, sessions),
            t.unit,
          ),
        )
        .toList(growable: false);
  }

  int _estimateCompletedFromLogs(String category, List<_WorkoutLogUi> sessions) {
    if (sessions.isEmpty) return 0;
    final weeklySessions = sessions.where(
      (s) => s.completedAt.isAfter(DateTime.now().subtract(const Duration(days: 7))),
    );

    final multiplier = switch (category.toLowerCase()) {
      'push' => 3,
      'pull' => 3,
      'legs' => 3,
      'core' => 2,
      'skill practice' => 1,
      'mobility' => 1,
      _ => 1,
    };

    return weeklySessions.length * multiplier;
  }

  List<_WorkoutDayUi> _adaptWeekDays(List<_WorkoutDayUi> days) {
    if (days.isEmpty) return days;
    final copied = days.map((day) => day.copyWith()).toList(growable: true);

    final missedIndex = copied.indexWhere((day) => day.status == _WorkoutStatus.missed);
    if (missedIndex == -1 || missedIndex == copied.length - 1) {
      return copied;
    }

    for (var i = missedIndex + 1; i < copied.length; i++) {
      copied[i] = copied[i].copyWith(date: copied[i].date.add(const Duration(days: 1)));
    }

    for (var i = 1; i < copied.length; i++) {
      final prevHeavy = _isHeavy(copied[i - 1].type);
      final currentHeavy = _isHeavy(copied[i].type);
      if (prevHeavy && currentHeavy) {
        copied[i] = copied[i].copyWith(
          type: 'Skill + Mobility',
          exercises: const <_ExerciseUi>[
            _ExerciseUi(
              name: 'Cossack Squat Flow',
              sets: 3,
              reps: '10/side',
              level: 2,
              category: 'mobility',
            ),
            _ExerciseUi(
              name: 'Scapular Pull-Up Hold',
              sets: 3,
              reps: '20s',
              level: 2,
              category: 'skill',
            ),
            _ExerciseUi(
              name: 'Dead Bug',
              sets: 3,
              reps: '12',
              level: 1,
              category: 'core',
            ),
          ],
        );
      }
    }

    return copied;
  }

  bool _isHeavy(String type) {
    final lower = type.toLowerCase();
    return lower.contains('push') || lower.contains('pull') || lower.contains('legs');
  }

  _WorkoutDayUi _swapWorkout(_WorkoutDayUi current, _WorkoutData data) {
    final alternatives = <String>[
      'Upper Body Day',
      'Skill Density Day',
      'Lower + Core Power',
      'Pull Endurance Day',
    ];
    final randomType = alternatives[math.Random().nextInt(alternatives.length)];
    return current.copyWith(
      type: randomType,
      exercises: _generateExercises(
        type: randomType,
        skills: const <String>['Handstand', 'Pull-up'],
        equipment: const <String>['Pull-up bar'],
      ),
    );
  }

  Future<void> _startWorkout(
    BuildContext context, {
    required _WorkoutDayUi today,
    required SubscriptionState subState,
    required SubscriptionController subController,
    required TrainingPlan? plan,
    required List<_WorkoutDayUi> allDays,
  }) async {
    if (today.isLocked && !subState.isPremium) {
      await subController.showPaywall();
      await subController.refresh();
      return;
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _WorkoutPlayerSheet(
          day: today,
          onComplete: () async {
            final now = DateTime.now();
            final result = TrainingSessionResult(
              id: 'session_${now.millisecondsSinceEpoch}',
              userId: widget.user.uid,
              completedAt: now,
              completed: true,
              difficulty: 7,
              painScore: 2,
              notes: 'Completed via dashboard player',
            );
            await _repository.saveSessionResult(result);
            if (plan != null) {
              final completedDays = allDays
                  .map(
                    (day) => _isSameDay(day.date, today.date)
                        ? day.copyWith(status: _WorkoutStatus.completed)
                        : day,
                  )
                  .toList(growable: false);
              await _persistWeekToPlan(plan, completedDays);
            }
            if (!mounted) return;
            Navigator.of(this.context).pop();
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('Workout logged. Nice work.')),
            );
          },
        );
      },
    );
  }

  Future<void> _openCoach(
    BuildContext context,
    _WorkoutData workoutData,
    SubscriptionController subController,
    SubscriptionState subState,
    Map<String, dynamic> profileMap,
    TrainingPlan? plan,
    List<_WorkoutLogUi> sessions,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> sendMessage(String text) async {
              if (text.trim().isEmpty) return;
              setSheetState(() {
                _coachMessages = <_CoachMessage>[
                  ..._coachMessages,
                  _CoachMessage(text: text.trim(), fromCoach: false),
                ];
              });

              final response = await _coachRespondFromApi(
                text.trim(),
                workoutData,
                profileMap,
                plan,
                sessions,
              );

              setSheetState(() {
                _coachMessages = <_CoachMessage>[
                  ..._coachMessages,
                  _CoachMessage(text: response.message, fromCoach: true),
                ];
                _pendingChange = response.preview;
              });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              maxChildSize: 0.95,
              minChildSize: 0.55,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 14,
                    bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB4C8D8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: _kAccent),
                          const SizedBox(width: 8),
                          Text(
                            'AI Coach',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: _kText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _QuickChip('Make it easier', onTap: () => sendMessage('Make it easier')),
                            _QuickChip('Swap exercise', onTap: () => sendMessage('Swap exercise')),
                            _QuickChip('I missed a day', onTap: () => sendMessage('I missed a day')),
                            _QuickChip('I feel sore', onTap: () => sendMessage('I feel sore')),
                            _QuickChip(
                              'I have no equipment today',
                              onTap: () => sendMessage('I have no equipment today'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _coachMessages.length,
                          itemBuilder: (context, index) {
                            final message = _coachMessages[index];
                            return Align(
                              alignment: message.fromCoach
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                                ),
                                decoration: BoxDecoration(
                                  color: message.fromCoach
                                      ? const Color(0xFFF2F7FB)
                                      : _kAccent.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: message.fromCoach
                                        ? const Color(0xFFD5E4EF)
                                        : _kAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  message.text,
                                  style: const TextStyle(color: _kText, height: 1.35),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_pendingChange != null)
                        _PlanChangeCard(
                          preview: _pendingChange!,
                          onApply: () {
                            _applyPlanChange(_pendingChange!, workoutData, plan);
                            setSheetState(() {
                              _coachMessages = <_CoachMessage>[
                                ..._coachMessages,
                                const _CoachMessage(
                                  text: 'Applied. I updated your plan preview.',
                                  fromCoach: true,
                                ),
                              ];
                              _pendingChange = null;
                            });
                          },
                          onUndo: () {
                            setState(() {
                              _weekOverride = null;
                              _todayOverride = null;
                            });
                            setSheetState(() {
                              _pendingChange = null;
                              _coachMessages = <_CoachMessage>[
                                ..._coachMessages,
                                const _CoachMessage(
                                  text: 'Undone. You are back to your previous plan.',
                                  fromCoach: true,
                                ),
                              ];
                            });
                          },
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _coachInputController,
                              style: const TextStyle(color: _kText),
                              decoration: InputDecoration(
                                hintText: 'Ask Coach...',
                                hintStyle: const TextStyle(color: _kMuted),
                                filled: true,
                                fillColor: const Color(0xFFF4F8FC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: sendMessage,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: _kAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              final text = _coachInputController.text;
                              _coachInputController.clear();
                              sendMessage(text);
                            },
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (!mounted) return;
    await subController.refresh();
    if (!subState.isPremium) {
      setState(() {});
    }
  }

  Future<_CoachResponse> _coachRespondFromApi(
    String input,
    _WorkoutData data,
    Map<String, dynamic> profileMap,
    TrainingPlan? plan,
    List<_WorkoutLogUi> sessions,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null || !_coachService.hasFunctionUrl) {
      return _coachRespondFallback(input, data);
    }

    final contextPayload = <String, dynamic>{
      'profile': profileMap,
      'plan': plan?.toMap(),
      'todayWorkout': _toWorkoutDayMap(data.today),
      'recentLogs': sessions
          .take(5)
          .map(
            (e) => <String, dynamic>{
              'completedAt': e.completedAt.toIso8601String(),
              'durationMinutes': e.durationMinutes,
              'title': e.title,
              'prHighlight': e.prHighlight,
            },
          )
          .toList(growable: false),
    };

    final apiResult = await _coachService.chat(
      message: input,
      idToken: idToken,
      context: contextPayload,
    );
    if (apiResult == null) {
      return _coachRespondFallback(input, data);
    }

    final planAction = apiResult.proposedPlanDiff?['action']?.toString() ?? 'none';
    final workoutAction =
        apiResult.proposedWorkoutEdits?['action']?.toString() ?? 'none';

    _ChangeType? applyType;
    if (planAction == 'adapt_week') {
      applyType = _ChangeType.adaptWeek;
    } else if (workoutAction == 'ease_today') {
      applyType = _ChangeType.easeToday;
    } else if (workoutAction == 'swap_today') {
      applyType = _ChangeType.swapToday;
    }

    if (applyType == null) {
      return _CoachResponse(message: apiResult.message, preview: null);
    }

    final before = apiResult.proposedPlanDiff?['before']?.toString() ??
        apiResult.proposedWorkoutEdits?['before']?.toString() ??
        'Current setup';
    final after = apiResult.proposedPlanDiff?['after']?.toString() ??
        apiResult.proposedWorkoutEdits?['summary']?.toString() ??
        'Updated setup';
    final title = apiResult.proposedPlanDiff?['notes']?.toString() ??
        apiResult.proposedWorkoutEdits?['summary']?.toString() ??
        'Coach update';

    return _CoachResponse(
      message: apiResult.message,
      preview: _PlanChangePreview(
        title: title,
        before: before,
        after: after,
        applyType: applyType,
      ),
    );
  }

  _CoachResponse _coachRespondFallback(String input, _WorkoutData data) {
    final text = input.toLowerCase();

    if (text.contains('missed')) {
      return _CoachResponse(
        message:
            'You missed a day. I can either shorten 4 workouts this week or push 1 workout into next week.',
        preview: _PlanChangePreview(
          title: 'Missed-day reschedule',
          before: 'Tue Push, Thu Pull, Sat Legs',
          after: 'Wed Push, Fri Pull, Sun Skill + Mobility',
          applyType: _ChangeType.adaptWeek,
        ),
      );
    }

    if (text.contains('easier') || text.contains('sore')) {
      return _CoachResponse(
        message: 'I can reduce intensity by lowering one set and adding rest.',
        preview: _PlanChangePreview(
          title: 'Difficulty adjustment',
          before: 'Ring Dips 4 x 8, 90s rest',
          after: 'Ring Dips 3 x 8, 120s rest + easier accessory',
          applyType: _ChangeType.easeToday,
        ),
      );
    }

    if (text.contains('swap') || text.contains('no equipment')) {
      return _CoachResponse(
        message: 'I can swap to equipment-free alternatives for today.',
        preview: _PlanChangePreview(
          title: 'Equipment-aware swap',
          before: 'Pull-ups / Ring rows',
          after: 'Table rows / Band pull-aparts / Doorframe isometrics',
          applyType: _ChangeType.swapToday,
        ),
      );
    }

    return const _CoachResponse(
      message: 'I can adjust workload, swap movements, or reshuffle your week. Pick one and I will draft changes.',
      preview: null,
    );
  }

  void _applyPlanChange(
    _PlanChangePreview preview,
    _WorkoutData data,
    TrainingPlan? plan,
  ) {
    if (preview.applyType == _ChangeType.adaptWeek) {
      final adapted = _adaptWeekDays(data.weekDays);
      setState(() => _weekOverride = adapted);
      if (plan != null) {
        _persistWeekToPlan(plan, adapted);
      }
      return;
    }

    if (preview.applyType == _ChangeType.easeToday) {
      final eased = data.today.copyWith(
        exercises: data.today.exercises
            .map(
              (e) => e.copyWith(
                sets: math.max(2, e.sets - 1),
                reps: e.reps.contains('-') ? e.reps : '${e.reps} (easier)',
              ),
            )
            .toList(growable: false),
      );
      setState(() => _todayOverride = eased);
      if (plan != null) {
        _persistTodayToPlan(plan, eased);
      }
      return;
    }

    final swapped = data.today.copyWith(
      exercises: const <_ExerciseUi>[
        _ExerciseUi(
          name: 'Table Rows',
          sets: 4,
          reps: '10-12',
          level: 2,
          category: 'pull',
        ),
        _ExerciseUi(
          name: 'Push-Up Eccentrics',
          sets: 4,
          reps: '8',
          level: 2,
          category: 'push',
        ),
        _ExerciseUi(
          name: 'Hollow Hold',
          sets: 3,
          reps: '30s',
          level: 2,
          category: 'core',
        ),
      ],
    );
    setState(() => _todayOverride = swapped);
    if (plan != null) {
      _persistTodayToPlan(plan, swapped);
    }
  }

  void _showWorkoutMenu(
    BuildContext context, {
    required _WorkoutData workoutData,
    required TrainingPlan? plan,
    required Map<String, dynamic> profileMap,
    required List<_WorkoutLogUi> sessions,
    required SubscriptionController subController,
    required SubscriptionState subState,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kBgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final items = <String>[
          'Edit equipment',
          'Edit goals',
          'Edit schedule/days',
          'Reset today',
          'Ask AI Coach',
        ];
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(items[index], style: const TextStyle(color: _kText)),
                trailing: const Icon(Icons.chevron_right_rounded, color: _kMuted),
                onTap: () {
                  Navigator.of(context).pop();
                  if (items[index] == 'Reset today') {
                    setState(() => _todayOverride = null);
                  }
                  if (items[index] == 'Ask AI Coach') {
                    _openCoach(
                      this.context,
                      workoutData,
                      subController,
                      subState,
                      profileMap,
                      plan,
                      sessions,
                    );
                  }
                },
              );
            },
            separatorBuilder: (context, index) =>
                const Divider(color: Color(0xFFE2ECF3), height: 1),
            itemCount: items.length,
          ),
        );
      },
    );
  }

  Future<void> _showSimplePicker(
    BuildContext context, {
    required String title,
    required List<String> options,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kBgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _kText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              ...options.map(
                (option) => ListTile(
                  title: Text(option, style: const TextStyle(color: _kText)),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  List<_ExerciseUi> _generateExercises({
    required String type,
    required List<String> skills,
    required List<String> equipment,
  }) {
    final hasNoEquipment = equipment.any(
      (e) => e.toLowerCase().contains('none') || e.toLowerCase().contains('bodyweight'),
    );

    final pullBaseline = skills.join(' ').toLowerCase().contains('pull-up')
        ? 'Assisted Pull-Up Negatives'
        : 'Scap Pull-Up Holds';

    final typeLower = type.toLowerCase();
    if (typeLower.contains('pull')) {
      return <_ExerciseUi>[
        _ExerciseUi(
          name: hasNoEquipment ? 'Towel Rows' : pullBaseline,
          sets: 3,
          reps: '6-8',
          level: 3,
          category: 'pull',
        ),
        const _ExerciseUi(
          name: 'Ring Row',
          sets: 4,
          reps: '10',
          level: 2,
          category: 'pull',
        ),
        const _ExerciseUi(
          name: 'Biceps Isometric Hold',
          sets: 3,
          reps: '20s',
          level: 2,
          category: 'pull',
        ),
      ];
    }

    if (typeLower.contains('legs')) {
      return const <_ExerciseUi>[
        _ExerciseUi(
          name: 'Bulgarian Split Squat',
          sets: 4,
          reps: '8/side',
          level: 3,
          category: 'legs',
        ),
        _ExerciseUi(
          name: 'Single-Leg RDL',
          sets: 3,
          reps: '10',
          level: 2,
          category: 'legs',
        ),
        _ExerciseUi(
          name: 'Hollow Body Hold',
          sets: 4,
          reps: '30s',
          level: 3,
          category: 'core',
        ),
      ];
    }

    if (typeLower.contains('skill')) {
      return const <_ExerciseUi>[
        _ExerciseUi(
          name: 'Wall Handstand Hold',
          sets: 5,
          reps: '25s',
          level: 3,
          category: 'skill',
        ),
        _ExerciseUi(
          name: 'Tuck Front Lever Raise',
          sets: 4,
          reps: '5',
          level: 3,
          category: 'skill',
        ),
        _ExerciseUi(
          name: 'Pike Compression',
          sets: 3,
          reps: '12',
          level: 2,
          category: 'core',
        ),
      ];
    }

    return const <_ExerciseUi>[
      _ExerciseUi(
        name: 'Ring Dips',
        sets: 4,
        reps: '8',
        level: 4,
        category: 'push',
      ),
      _ExerciseUi(
        name: 'Pseudo Planche Push-Up',
        sets: 4,
        reps: '6-8',
        level: 4,
        category: 'push',
      ),
      _ExerciseUi(
        name: 'Deficit Push-Up',
        sets: 3,
        reps: '12',
        level: 3,
        category: 'push',
      ),
    ];
  }

  int _estimateMinutes(String? bucket) {
    final raw = bucket ?? '40-55';
    if (raw.contains('15-20')) return 20;
    if (raw.contains('25-35')) return 32;
    if (raw.contains('60')) return 60;
    return 48;
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  Future<void> _openSettingsScreen(
    BuildContext context, {
    required Map<String, dynamic> profileMap,
    required SubscriptionState subState,
    required SubscriptionController subController,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AccountSettingsView(
          user: widget.user,
          profileMap: profileMap,
          isPremium: subState.isPremium,
          onManageMembership: () async {
            await subController.showCustomerCenter();
            await subController.refresh();
          },
          onSignOut: () async {
            await subController.logOut();
            await FirebaseAuth.instance.signOut();
          },
        ),
      ),
    );
  }

  Future<void> _persistWeekToPlan(
    TrainingPlan plan,
    List<_WorkoutDayUi> weekDays,
  ) async {
    final updated = _copyPlanWithUpdatedDays(plan, weekDays);
    await _repository.saveTrainingPlan(widget.user.uid, updated);
  }

  Future<void> _persistTodayToPlan(TrainingPlan plan, _WorkoutDayUi today) async {
    final baseline = _weekOverride ??
        _buildWeekDays(
          weekStart: _startOfWeek(DateTime.now()),
          profileMap: const <String, dynamic>{},
          plan: plan,
          sessions: const <_WorkoutLogUi>[],
          isPremium: true,
        );
    final next = baseline
        .map((d) => _isSameDay(d.date, today.date) ? today : d)
        .toList(growable: false);
    final updated = _copyPlanWithUpdatedDays(plan, next);
    await _repository.saveTrainingPlan(widget.user.uid, updated);
  }

  TrainingPlan _copyPlanWithUpdatedDays(
    TrainingPlan base,
    List<_WorkoutDayUi> days,
  ) {
    final sorted = days.toList(growable: true)..sort((a, b) => a.date.compareTo(b.date));
    return TrainingPlan(
      id: base.id,
      userId: base.userId,
      createdAt: base.createdAt,
      daysPerWeek: base.daysPerWeek,
      workoutLength: base.workoutLength,
      weeklySplit: sorted.map((e) => e.type).toList(growable: false),
      skillTrack: base.skillTrack,
      blocks: base.blocks,
      generator: base.generator,
      activeWeekStartDate: sorted.isEmpty ? base.activeWeekStartDate : _startOfWeek(sorted.first.date),
      scheduleDays: sorted
          .map(
            (e) => PlanScheduleDay(
              date: e.date,
              type: e.type,
              status: switch (e.status) {
                _WorkoutStatus.completed => 'completed',
                _WorkoutStatus.missed => 'missed',
                _WorkoutStatus.scheduled => 'scheduled',
              },
            ),
          )
          .toList(growable: false),
      skillTracks: base.skillTracks,
      volumeTargets: base.volumeTargets,
      progressionRules: base.progressionRules,
      workoutDays: sorted
          .map(
            (e) => WorkoutDayPlan(
              date: e.date,
              type: e.type,
              estimatedMinutes: e.estimatedMinutes,
              status: switch (e.status) {
                _WorkoutStatus.completed => 'completed',
                _WorkoutStatus.missed => 'missed',
                _WorkoutStatus.scheduled => 'scheduled',
              },
              exercises: e.exercises
                  .asMap()
                  .entries
                  .map(
                    (entry) => WorkoutExercise(
                      id: '${e.type}_${entry.key}',
                      name: entry.value.name,
                      category: entry.value.category,
                      progressionLevel: entry.value.level,
                      sets: entry.value.sets,
                      reps: entry.value.reps,
                      restSeconds: 90,
                      altExercises: const <String>[],
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> _toWorkoutDayMap(_WorkoutDayUi day) {
    return <String, dynamic>{
      'date': day.date.toIso8601String(),
      'type': day.type,
      'estimatedMinutes': day.estimatedMinutes,
      'status': switch (day.status) {
        _WorkoutStatus.completed => 'completed',
        _WorkoutStatus.missed => 'missed',
        _WorkoutStatus.scheduled => 'scheduled',
      },
      'exercises': day.exercises
          .map(
            (e) => <String, dynamic>{
              'name': e.name,
              'sets': e.sets,
              'reps': e.reps,
              'level': e.level,
              'category': e.category,
            },
          )
          .toList(growable: false),
    };
  }
}

class _WorkoutTab extends StatelessWidget {
  const _WorkoutTab({
    required this.today,
    required this.weekDays,
    required this.profileMap,
    required this.hasAutoAdapt,
    required this.showNoAdaptBanner,
    required this.missedMessage,
    required this.isPremium,
    required this.onAdaptNow,
    required this.onKeepSchedule,
    required this.onOpenMenu,
    required this.onSwapTap,
    required this.onPickLength,
    required this.onPickEquipment,
    required this.onLockedTap,
    required this.onStartTap,
  });

  final _WorkoutDayUi today;
  final List<_WorkoutDayUi> weekDays;
  final Map<String, dynamic> profileMap;
  final bool hasAutoAdapt;
  final bool showNoAdaptBanner;
  final String? missedMessage;
  final bool isPremium;

  final VoidCallback onAdaptNow;
  final VoidCallback onKeepSchedule;
  final VoidCallback onOpenMenu;
  final VoidCallback onSwapTap;
  final VoidCallback onPickLength;
  final VoidCallback onPickEquipment;
  final VoidCallback onLockedTap;
  final VoidCallback onStartTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = '${today.exercises.length} Exercises • ${_muscleCount(today)} Muscles';
    final firstName =
        profileMap['fullName']?.toString().split(' ').first ?? 'Athlete';

    return CustomScrollView(
      key: const ValueKey('workout-tab'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE6F0F7),
                  child: Text(
                    firstName.isEmpty ? 'S' : firstName[0].toUpperCase(),
                    style: const TextStyle(color: _kText, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'My Plan >',
                  style: TextStyle(color: _kMuted, fontSize: 15),
                ),
                const Spacer(),
                _PillButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Swap',
                  onTap: onSwapTap,
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onOpenMenu,
                  icon: const Icon(Icons.more_horiz_rounded, color: _kText),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              today.type,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: _kText,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(subtitle, style: const TextStyle(color: _kMuted, fontSize: 15)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _DropdownPill(label: _lengthLabel(today.estimatedMinutes), onTap: onPickLength),
                const SizedBox(width: 8),
                _DropdownPill(
                  label: _equipmentLabel(profileMap),
                  onTap: onPickEquipment,
                ),
              ],
            ),
          ),
        ),
        if (missedMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _MissedBanner(
                message: missedMessage!,
                showActions: !hasAutoAdapt && showNoAdaptBanner,
                onAdapt: onAdaptNow,
                onKeep: onKeepSchedule,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStartTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(today.isLocked && !isPremium ? 'Unlock to Start' : 'Start'),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            child: _TimelineWorkoutList(
              today: today,
              isPremium: isPremium,
              onLockedTap: onLockedTap,
            ),
          ),
        ),
      ],
    );
  }

  int _muscleCount(_WorkoutDayUi day) {
    final categories = day.exercises.map((e) => e.category).toSet();
    return categories.length;
  }

  String _lengthLabel(int minutes) {
    if (minutes <= 25) return '20m';
    if (minutes <= 40) return '25-35';
    if (minutes <= 55) return '40-55';
    return '60+';
  }

  String _equipmentLabel(Map<String, dynamic> profileMap) {
    final equipment =
        (profileMap['equipment'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList(growable: false);
    if (equipment.isEmpty) return 'Large Gym';
    if (equipment.any((e) => e.toLowerCase().contains('none'))) {
      return 'Bodyweight';
    }
    if (equipment.any((e) => e.toLowerCase().contains('rings'))) {
      return 'Home / Rings';
    }
    return 'Large Gym';
  }
}

class _BodyTab extends StatelessWidget {
  const _BodyTab({
    required this.showRecovery,
    required this.onToggle,
    required this.carouselIndex,
    required this.onCarouselChanged,
    required this.sessions,
    required this.focusExercises,
  });

  final bool showRecovery;
  final ValueChanged<bool> onToggle;
  final int carouselIndex;
  final ValueChanged<int> onCarouselChanged;
  final List<_WorkoutLogUi> sessions;
  final List<_ExerciseUi> focusExercises;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const ValueKey('body-tab'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _SegmentControl(
              leftLabel: 'Results',
              rightLabel: 'Recovery',
              isRightSelected: showRecovery,
              onChanged: (isRight) => onToggle(isRight),
            ),
          ),
        ),
        if (!showRecovery) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _ScoreCard(locked: sessions.length < 3),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                'Focus Exercises',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _kText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: math.min(5, math.max(1, focusExercises.length)),
                controller: PageController(viewportFraction: 0.9),
                onPageChanged: onCarouselChanged,
                itemBuilder: (context, index) {
                  final ex = focusExercises[index % focusExercises.length];
                  return _FocusExerciseCard(exercise: ex, points: _fakeTrend(index));
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 90),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == carouselIndex
                          ? _kAccent
                          : const Color(0xFFB8CCD9),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ] else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
              child: _RecoveryCard(sessionCount: sessions.length),
            ),
          ),
      ],
    );
  }

  List<double> _fakeTrend(int seed) {
    return List<double>.generate(8, (i) => 2 + (math.sin(i + seed) + 1.3));
  }
}

class _TargetsTab extends StatelessWidget {
  const _TargetsTab({
    required this.showIntro,
    required this.onDismissIntro,
    required this.targets,
  });

  final bool showIntro;
  final VoidCallback onDismissIntro;
  final List<_TargetUi> targets;

  @override
  Widget build(BuildContext context) {
    final total = targets.fold<int>(
      0,
      (runningTotal, target) => runningTotal + target.target,
    );
    final done = targets.fold<int>(
      0,
      (runningTotal, target) => runningTotal + target.completed,
    );
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return CustomScrollView(
      key: const ValueKey('targets-tab'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (showIntro)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _IntroTargetsCard(onClose: onDismissIntro),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Text(
              'Weekly Set Targets',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: _kText,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text('Feb 22 - Feb 28', style: TextStyle(color: _kMuted)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _HexProgress(progress: progress),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
            child: Column(
              children: [
                ...targets.map((target) => _TargetRow(target: target)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kAccent,
                      side: const BorderSide(color: Color(0xFFC9DCE8)),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Adjust targets'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LogTab extends StatelessWidget {
  const _LogTab({
    required this.profileMap,
    required this.sessions,
    required this.isPremium,
    required this.onUpgradeTap,
    required this.onSettingsTap,
    required this.onSignOutTap,
  });

  final Map<String, dynamic> profileMap;
  final List<_WorkoutLogUi> sessions;
  final bool isPremium;
  final VoidCallback onUpgradeTap;
  final VoidCallback onSettingsTap;
  final Future<void> Function() onSignOutTap;

  @override
  Widget build(BuildContext context) {
    final firstName = profileMap['fullName']?.toString().split(' ').first ?? 'Athlete';
    final streak = _estimateStreak(sessions);

    return CustomScrollView(
      key: const ValueKey('log-tab'),
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.ios_share_rounded, color: _kText),
                ),
                Expanded(
                  child: Text(
                    firstName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _kText,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: onSettingsTap,
                  icon: const Icon(Icons.settings_rounded, color: _kText),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _StatsGrid(
              workouts: sessions.length,
              weeklyGoalDone: _weeklyDone(sessions),
              weeklyGoalTotal: (profileMap['daysPerWeek'] as num?)?.toInt() ?? 4,
              streak: streak,
            ),
          ),
        ),
        if (!isPremium)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _PromoCard(onTap: onUpgradeTap),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _CalendarCard(completedDates: sessions.map((s) => s.completedAt).toList()),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
            child: Column(
              children: [
                _PastWorkoutsCard(sessions: sessions),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSignOutTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E628C),
                      side: const BorderSide(color: Color(0xFFC9DCE8)),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _estimateStreak(List<_WorkoutLogUi> sessions) {
    if (sessions.isEmpty) return 0;
    final uniqueWeeks = sessions
        .map((s) => _weekKey(s.completedAt))
        .toSet()
        .toList(growable: false)
      ..sort();
    return uniqueWeeks.length;
  }

  int _weeklyDone(List<_WorkoutLogUi> sessions) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return sessions
        .where((s) => s.completedAt.isAfter(weekStart.subtract(const Duration(seconds: 1))))
        .length;
  }

  String _weekKey(DateTime date) {
    final weekStart = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    return '${weekStart.year}-${weekStart.month}-${weekStart.day}';
  }
}

class _TimelineWorkoutList extends StatelessWidget {
  const _TimelineWorkoutList({
    required this.today,
    required this.isPremium,
    required this.onLockedTap,
  });

  final _WorkoutDayUi today;
  final bool isPremium;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E7F1)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        children: [
          _ExerciseRow(
            exercise: today.exercises.first,
            isFocus: true,
            showLock: false,
          ),
          const SizedBox(height: 12),
          for (var i = 1; i < today.exercises.length; i++) ...[
            _ExerciseRow(
              exercise: today.exercises[i],
              isFocus: false,
              showLock: today.isLocked && !isPremium,
              onTap: today.isLocked && !isPremium ? onLockedTap : null,
            ),
            const SizedBox(height: 10),
          ],
          if (today.isLocked && !isPremium)
            ...List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: onLockedTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.lock_rounded, color: _kMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 10,
                            margin: const EdgeInsets.only(right: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD0DFEA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatefulWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.isFocus,
    required this.showLock,
    this.onTap,
  });

  final _ExerciseUi exercise;
  final bool isFocus;
  final bool showLock;
  final VoidCallback? onTap;

  @override
  State<_ExerciseRow> createState() => _ExerciseRowState();
}

class _ExerciseRowState extends State<_ExerciseRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _pressed ? 0.96 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 110),
          opacity: _pressed ? 0.9 : 1,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD6E6F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: widget.showLock
                      ? const Icon(Icons.lock_rounded, color: _kMuted)
                      : const Icon(Icons.fitness_center_rounded, color: _kText),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isFocus)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            'FOCUS EXERCISE',
                            style: TextStyle(
                              color: _kAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      Text(
                        widget.showLock ? 'Locked exercise' : widget.exercise.name,
                        style: const TextStyle(
                          color: _kText,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.showLock
                            ? 'Unlock to view sets and reps'
                            : '${widget.exercise.sets} sets • ${widget.exercise.reps} • Level ${widget.exercise.level}',
                        style: const TextStyle(color: _kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: _kMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({required this.index, required this.onChange});

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final items = const <(IconData, String)>[
      (Icons.fitness_center_outlined, 'Workout'),
      (Icons.monitor_heart_outlined, 'Body'),
      (Icons.track_changes_outlined, 'Targets'),
      (Icons.event_note_outlined, 'Log'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE2ECF3))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = i == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChange(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i].$1,
                      color: selected ? _kAccent : const Color(0xFF7290A5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].$2,
                      style: TextStyle(
                        color: selected ? _kAccent : const Color(0xFF7290A5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CoachFab extends StatelessWidget {
  const _CoachFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'coach-fab',
      onPressed: onTap,
      backgroundColor: _kAccent,
      child: const Icon(Icons.auto_awesome_rounded),
    );
  }
}

class _UnlockBanner extends StatelessWidget {
  const _UnlockBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF1E628C), Color(0xFF2E79A8)],
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_open_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock your next workout',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'With a free 7-day trial',
                      style: TextStyle(color: Color(0xFFE7F3FB), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutPlayerSheet extends StatelessWidget {
  const _WorkoutPlayerSheet({required this.day, required this.onComplete});

  final _WorkoutDayUi day;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFB4C8D8),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Text(
            day.type,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _kText,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${day.estimatedMinutes} minutes • ${day.exercises.length} exercises',
            style: const TextStyle(color: _kMuted),
          ),
          const SizedBox(height: 14),
          ...day.exercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(color: _kText, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${exercise.sets} x ${exercise.reps}',
                      style: const TextStyle(color: _kMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Complete and Log'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF5FA),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kText, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _kText, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _DropdownPill extends StatelessWidget {
  const _DropdownPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF5FA),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: _kText, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MissedBanner extends StatelessWidget {
  const _MissedBanner({
    required this.message,
    required this.showActions,
    required this.onAdapt,
    required this.onKeep,
  });

  final String message;
  final bool showActions;
  final VoidCallback onAdapt;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: _kText, fontWeight: FontWeight.w700),
          ),
          if (showActions) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: onAdapt,
                  style: ElevatedButton.styleFrom(backgroundColor: _kAccent),
                  child: const Text('Adapt'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onKeep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kMuted,
                    side: const BorderSide(color: Color(0xFFC8DBE8)),
                  ),
                  child: const Text('Keep as is'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip(this.text, {required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FB),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFFCDE0EC)),
          ),
          child: Text(text, style: const TextStyle(color: _kText, fontSize: 12)),
        ),
      ),
    );
  }
}

class _PlanChangeCard extends StatelessWidget {
  const _PlanChangeCard({
    required this.preview,
    required this.onApply,
    required this.onUndo,
  });

  final _PlanChangePreview preview;
  final VoidCallback onApply;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4E4EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.title,
            style: const TextStyle(color: _kText, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Before: ${preview.before}', style: const TextStyle(color: _kMuted)),
          Text('After: ${preview.after}', style: const TextStyle(color: Color(0xFF3B5F79))),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(backgroundColor: _kAccent),
                child: const Text('Apply changes'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onUndo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kMuted,
                  side: const BorderSide(color: Color(0xFFC8DBE8)),
                ),
                child: const Text('Undo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({
    required this.leftLabel,
    required this.rightLabel,
    required this.isRightSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool isRightSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3F9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: leftLabel,
              selected: !isRightSelected,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: rightLabel,
              selected: isRightSelected,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD3E4EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Overall Strength',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _kText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              const Icon(Icons.info_outline_rounded, color: _kMuted, size: 18),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _kMuted),
            ],
          ),
          const SizedBox(height: 10),
          if (locked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBgCardSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_rounded, color: _kMuted),
                      SizedBox(width: 8),
                      Text(
                        'Log 3 workouts to unlock your score',
                        style: TextStyle(color: _kText, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _GhostBars(),
                ],
              ),
            )
          else
            const Text('77 / 100', style: TextStyle(color: _kText, fontSize: 32, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _GhostBars extends StatelessWidget {
  const _GhostBars();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFD0DFEA),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _FocusExerciseCard extends StatelessWidget {
  const _FocusExerciseCard({required this.exercise, required this.points});

  final _ExerciseUi exercise;
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFEAF3F9), Color(0xFFF4F8FC)],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF35556D),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Estimated Level', style: TextStyle(color: _kMuted, fontSize: 12)),
          const SizedBox(height: 14),
          Expanded(child: _MiniLineChart(points: points)),
        ],
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.points});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniChartPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  _MiniChartPainter(this.points);

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _kAccent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i / math.max(points.length - 1, 1) * size.width;
      final y = size.height - ((points[i] / 5).clamp(0.0, 1.0) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.sessionCount});

  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    final readiness = (58 + (sessionCount * 4)).clamp(58, 92);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4E5F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Readiness: $readiness%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _kText,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyChip('Upper body: Mild soreness'),
              _TinyChip('Legs: Fresh'),
              _TinyChip('Sleep: 6h 50m'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kBgCardSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Recommended today: 12-minute mobility + shoulder prehab flow.',
              style: TextStyle(color: _kText),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FB),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: const TextStyle(color: _kText, fontSize: 12)),
    );
  }
}

class _IntroTargetsCard extends StatelessWidget {
  const _IntroTargetsCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Introducing: Set Targets',
                  style: TextStyle(color: _kText, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Track your weekly volume by movement pattern and skill sessions.',
                  style: TextStyle(color: _kMuted),
                ),
                SizedBox(height: 6),
                Text('Learn More', style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: _kMuted),
          ),
        ],
      ),
    );
  }
}

class _HexProgress extends StatelessWidget {
  const _HexProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(220),
              painter: _HexPainter(progress: progress),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(color: _kText, fontSize: 38, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.34;

    final track = Paint()
      ..color = const Color(0xFFD6E6F0)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF9FC2D8),
          Color(0xFF1E628C),
          Color(0xFF8FB4CC),
          Color(0xFF8AB0CA),
          Color(0xFF7EABC8),
          Color(0xFF2C78A8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 24))
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = _hexPath(center, radius);
    canvas.drawPath(path, track);

    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(extract, fill);
  }

  Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final theta = (math.pi / 3 * i) - math.pi / 2;
      final x = center.dx + radius * math.cos(theta);
      final y = center.dy + radius * math.sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.target});

  final _TargetUi target;

  @override
  Widget build(BuildContext context) {
    final ratio = target.target == 0 ? 0.0 : (target.completed / target.target).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(target.label, style: const TextStyle(color: _kText, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${target.completed}/${target.target} ${target.unit}',
                style: const TextStyle(color: _kMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            color: _kAccent,
            backgroundColor: const Color(0xFFD4E5F0),
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.workouts,
    required this.weeklyGoalDone,
    required this.weeklyGoalTotal,
    required this.streak,
  });

  final int workouts;
  final int weeklyGoalDone;
  final int weeklyGoalTotal;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatCell(label: 'WORKOUTS', value: '$workouts'),
          const _StatCell(label: 'MILESTONES', value: '2 badges'),
          _StatCell(label: 'WEEKLY GOAL', value: '$weeklyGoalDone/$weeklyGoalTotal'),
          _StatCell(label: 'CURRENT STREAK', value: '$streak weeks'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 16 * 2 - 14 * 2 - 10) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBgCardSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _kMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _kText, fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: <Color>[Color(0xFFEAF3F9), Color(0xFFDDECF6)]),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                'Try SkillMax FREE for 7 Days',
                style: TextStyle(color: _kText, fontWeight: FontWeight.w800),
              ),
            ),
            Text('Start >', style: TextStyle(color: _kAccent, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.completedDates});

  final List<DateTime> completedDates;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('Calendar', style: TextStyle(color: _kText, fontWeight: FontWeight.w800, fontSize: 20)),
              Spacer(),
              Text('Feb v', style: TextStyle(color: _kMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              'M', 'T', 'W', 'T', 'F', 'S', 'S',
            ].map((d) => Text(d, style: TextStyle(color: _kMuted, fontSize: 12))).toList(),
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < 5; week++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (dayIndex) {
                  final dayNumber = week * 7 + dayIndex + 1;
                  final date = DateTime(monthStart.year, monthStart.month, dayNumber);
                  final inMonth = date.month == monthStart.month;
                  final completed = completedDates.any(
                    (done) => done.year == date.year && done.month == date.month && done.day == date.day,
                  );

                  return SizedBox(
                    width: 30,
                    child: Column(
                      children: [
                        Text(
                          inMonth ? '$dayNumber' : '',
                          style: TextStyle(color: inMonth ? _kText : Colors.transparent, fontSize: 12),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: completed ? _kAccent : const Color(0x336F8EA5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _PastWorkoutsCard extends StatelessWidget {
  const _PastWorkoutsCard({required this.sessions});

  final List<_WorkoutLogUi> sessions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Past Workouts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _kText,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, color: _kAccent),
              ),
            ],
          ),
          if (sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "You haven't logged any workouts yet!",
                style: TextStyle(color: _kMuted),
              ),
            )
          else
            ...sessions.take(8).map(
                  (session) => Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kBgCardSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, color: _kMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.title,
                                style: const TextStyle(color: _kText, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${session.durationMinutes} min • PR: ${session.prHighlight}',
                                style: const TextStyle(color: _kMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

String _weekdayName(int day) {
  const names = <int, String>{
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };
  return names[day] ?? 'Day';
}

class _CoachMessage {
  const _CoachMessage({required this.text, required this.fromCoach});

  final String text;
  final bool fromCoach;
}

class _CoachResponse {
  const _CoachResponse({required this.message, required this.preview});

  final String message;
  final _PlanChangePreview? preview;
}

class _PlanChangePreview {
  const _PlanChangePreview({
    required this.title,
    required this.before,
    required this.after,
    required this.applyType,
  });

  final String title;
  final String before;
  final String after;
  final _ChangeType applyType;
}

enum _ChangeType { adaptWeek, easeToday, swapToday }

class _WorkoutData {
  const _WorkoutData({
    required this.today,
    required this.weekDays,
    required this.targets,
    required this.hasLockedContent,
    required this.adaptIfMissed,
    required this.missedMessage,
  });

  final _WorkoutDayUi today;
  final List<_WorkoutDayUi> weekDays;
  final List<_TargetUi> targets;
  final bool hasLockedContent;
  final bool adaptIfMissed;
  final String? missedMessage;
}

class _WorkoutDayUi {
  const _WorkoutDayUi({
    required this.date,
    required this.type,
    required this.exercises,
    required this.estimatedMinutes,
    required this.status,
    required this.isLocked,
  });

  final DateTime date;
  final String type;
  final List<_ExerciseUi> exercises;
  final int estimatedMinutes;
  final _WorkoutStatus status;
  final bool isLocked;

  _WorkoutDayUi copyWith({
    DateTime? date,
    String? type,
    List<_ExerciseUi>? exercises,
    int? estimatedMinutes,
    _WorkoutStatus? status,
    bool? isLocked,
  }) {
    return _WorkoutDayUi(
      date: date ?? this.date,
      type: type ?? this.type,
      exercises: exercises ?? this.exercises,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      status: status ?? this.status,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

enum _WorkoutStatus { scheduled, completed, missed }

class _ExerciseUi {
  const _ExerciseUi({
    required this.name,
    required this.sets,
    required this.reps,
    required this.level,
    required this.category,
  });

  final String name;
  final int sets;
  final String reps;
  final int level;
  final String category;

  _ExerciseUi copyWith({
    String? name,
    int? sets,
    String? reps,
    int? level,
    String? category,
  }) {
    return _ExerciseUi(
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      level: level ?? this.level,
      category: category ?? this.category,
    );
  }
}

class _TargetUi {
  const _TargetUi(this.label, this.target, this.completed, this.unit);

  final String label;
  final int target;
  final int completed;
  final String unit;
}

class _WorkoutLogUi {
  const _WorkoutLogUi({
    required this.completedAt,
    required this.durationMinutes,
    required this.title,
    required this.prHighlight,
  });

  final DateTime completedAt;
  final int durationMinutes;
  final String title;
  final String prHighlight;

  factory _WorkoutLogUi.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data();
    final completedAt = DateTime.tryParse(map['completedAt']?.toString() ?? '') ?? DateTime.now();
    final difficulty = (map['difficulty'] as num?)?.toInt() ?? 6;
    final pain = (map['painScore'] as num?)?.toInt() ?? 2;

    return _WorkoutLogUi(
      completedAt: completedAt,
      durationMinutes: 24 + (difficulty * 3),
      title: map['title']?.toString() ?? 'Skill Session',
      prHighlight: pain <= 2 ? 'Great form day' : 'Kept it controlled',
    );
  }
}

class _AccountSettingsView extends StatefulWidget {
  const _AccountSettingsView({
    required this.user,
    required this.profileMap,
    required this.isPremium,
    required this.onManageMembership,
    required this.onSignOut,
  });

  final User user;
  final Map<String, dynamic> profileMap;
  final bool isPremium;
  final Future<void> Function() onManageMembership;
  final Future<void> Function() onSignOut;

  @override
  State<_AccountSettingsView> createState() => _AccountSettingsViewState();
}

class _AccountSettingsViewState extends State<_AccountSettingsView> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  DateTime? _birthday;
  bool _savingEmail = false;
  bool _savingPassword = false;
  bool _savingBirthday = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email ?? '');

    final birthRaw =
        widget.profileMap['birthDate'] ?? widget.profileMap['birthday'];
    _birthday = DateTime.tryParse(birthRaw?.toString() ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _settingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF112331),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                _fieldLabel('Email'),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('name@example.com'),
                ),
                const SizedBox(height: 8),
                _actionButton(
                  label: _savingEmail ? 'Updating...' : 'Update Email',
                  busy: _savingEmail,
                  onTap: _updateEmail,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Password'),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration('New password (min 6 chars)'),
                ),
                const SizedBox(height: 8),
                _actionButton(
                  label: _savingPassword ? 'Updating...' : 'Update Password',
                  busy: _savingPassword,
                  onTap: _updatePassword,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Birthday'),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickBirthday,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD6E6F0)),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _birthday == null
                                ? 'Select birthday'
                                : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Color(0xFF1E3342)),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF6F8494),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _actionButton(
                  label: _savingBirthday ? 'Saving...' : 'Save Birthday',
                  busy: _savingBirthday,
                  onTap: _saveBirthday,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _settingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Membership',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF112331),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isPremium
                            ? const Color(0xFF1E628C)
                            : const Color(0xFF8EA2B1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isPremium ? 'Premium Active' : 'Free Plan',
                      style: const TextStyle(
                        color: Color(0xFF1E3342),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _actionButton(
                  label: widget.isPremium
                      ? 'Manage / Cancel Membership'
                      : 'View Membership Options',
                  onTap: () async {
                    await widget.onManageMembership();
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Opened membership management.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _settingsCard(
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await widget.onSignOut();
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E628C),
                  side: const BorderSide(color: Color(0xFFC9DCE8)),
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E8F2)),
      ),
      child: child,
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6F8494),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6E6F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD6E6F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E628C), width: 1.4),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Future<void> Function() onTap,
    bool busy = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E628C),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label),
      ),
    );
  }

  Future<void> _updateEmail() async {
    final nextEmail = _emailController.text.trim();
    if (nextEmail.isEmpty || nextEmail == widget.user.email) return;

    setState(() => _savingEmail = true);
    try {
      await widget.user.verifyBeforeUpdateEmail(nextEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Confirm to finish updating.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Unable to update email.')),
      );
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    final nextPassword = _passwordController.text.trim();
    if (nextPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await widget.user.updatePassword(nextPassword);
      _passwordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'Please sign out and sign in again, then retry password update.'
          : (e.message ?? 'Unable to update password.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940, 1, 1),
      lastDate: now,
    );
    if (selected == null) return;
    setState(() => _birthday = selected);
  }

  Future<void> _saveBirthday() async {
    if (_birthday == null) return;
    setState(() => _savingBirthday = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('profile')
          .doc('current')
          .set(
            <String, dynamic>{
              'birthDate': _birthday!.toIso8601String(),
            },
            SetOptions(merge: true),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Birthday saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save birthday right now.')),
      );
    } finally {
      if (mounted) setState(() => _savingBirthday = false);
    }
  }
}
