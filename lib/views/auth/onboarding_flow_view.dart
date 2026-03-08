import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:permission_handler/permission_handler.dart';

import 'signup_view.dart';
import 'trial_intro_view.dart';

const _kCanvas = Color(0xFFF6FAFE);
const _kBlue = Color(0xFF1E628C);
const _kBlueDeep = Color(0xFF134865);
const _kText = Color(0xFF153042);
const _kSubtleText = Color(0xFF648095);
const _kTile = Color(0xFFEAF4FB);

class OnboardingFlowView extends StatefulWidget {
  const OnboardingFlowView({super.key});

  @override
  State<OnboardingFlowView> createState() => _OnboardingFlowViewState();
}

enum OnboardingStepType {
  singleChoice,
  multiSelect,
  chart,
  heightWeight,
  date,
  trust,
  rating,
  referral,
  loading,
  planReady,
}

class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.headline,
    this.subhead,
    this.type = OnboardingStepType.singleChoice,
    this.options,
    this.microcopy,
    this.maxSelections,
  });

  final String id;
  final String headline;
  final String? subhead;
  final String? microcopy;
  final OnboardingStepType type;
  final List<String>? options;
  final int? maxSelections;
}

class _OnboardingFlowViewState extends State<OnboardingFlowView> {
  final PageController _pageController = PageController();
  final TextEditingController _referralController = TextEditingController();
  final TextEditingController _heightFeetController = TextEditingController(
    text: '5',
  );
  final TextEditingController _heightInchesController = TextEditingController(
    text: '8',
  );
  final TextEditingController _heightCmController = TextEditingController(
    text: '173',
  );
  final TextEditingController _weightController = TextEditingController(
    text: '160',
  );

  final Map<String, String> _singleAnswers = <String, String>{};
  final Map<String, Set<String>> _multiAnswers = <String, Set<String>>{};

  DateTime? _birthday;
  bool _useImperial = true;
  int _rating = 0;
  int _index = 0;
  Timer? _loadingAdvanceTimer;
  Timer? _loadingTickTimer;
  double _loadingProgress = 0;
  bool _didAskForStoreReview = false;

  final List<OnboardingStep> _steps = const [
    OnboardingStep(
      id: 'source',
      headline: 'Where did you hear about SkillMax?',
      options: [
        'TikTok',
        'Instagram',
        'YouTube',
        'App Store',
        'Google Search',
        'Other',
      ],
    ),
    OnboardingStep(
      id: 'other_apps',
      headline: 'Have you tried other calisthenics/workout apps?',
      options: ['Yes', 'No'],
    ),
    OnboardingStep(
      id: 'proof',
      headline: 'Adaptive training = long-term results',
      subhead:
          'SkillMax updates your plan when you plateau so progress does not stall after week 2.',
      type: OnboardingStepType.chart,
    ),
    OnboardingStep(
      id: 'gender',
      headline: 'Choose your gender',
      subhead:
          'Gender is used to personalize training and recovery recommendations.',
      options: ['Male', 'Female', 'Other'],
    ),
    OnboardingStep(
      id: 'height_weight',
      headline: 'Height & weight',
      subhead: 'Helps us scale volume and progression safely.',
      type: OnboardingStepType.heightWeight,
    ),
    OnboardingStep(
      id: 'birthday',
      headline: 'When were you born?',
      subhead: 'Used to personalize recovery and training load.',
      type: OnboardingStepType.date,
    ),
    OnboardingStep(
      id: 'goal',
      headline: 'What is your goal?',
      subhead: 'We will build your plan around this.',
      options: [
        'Build Strength & Muscle',
        'Get Lean & Athletic',
        'Master Skills',
        'Mobility & Recovery',
      ],
    ),
    OnboardingStep(
      id: 'skills',
      headline: 'Pick your top skills (choose up to 3)',
      subhead: 'SkillMax builds progressions into your weekly plan.',
      type: OnboardingStepType.multiSelect,
      maxSelections: 3,
      options: [
        'Pull-up',
        'Muscle-up',
        'Handstand',
        'Handstand push-up',
        'Planche (progressions)',
        'Front lever',
        'Back lever',
        'Pistol squat',
        'Human flag',
        'Core mastery',
      ],
    ),
    OnboardingStep(
      id: 'experience',
      headline: 'What is your current level?',
      options: ['Beginner', 'Intermediate', 'Advanced'],
    ),
    OnboardingStep(
      id: 'baseline_push',
      headline: 'Quick baseline: push strength',
      options: ['0-5 push-ups', '6-15', '16-30', '31-50', '50+'],
    ),
    OnboardingStep(
      id: 'baseline_pull',
      headline: 'Quick baseline: pull strength',
      microcopy:
          "If you don't have a bar, choose '0' and we will start with alternatives.",
      options: ['0 pull-ups', '1-3', '4-7', '8-12', '13+'],
    ),
    OnboardingStep(
      id: 'baseline_legs',
      headline: 'Quick baseline: legs + core',
      options: [
        "I'm building basics",
        'Solid basics (squats/lunges + plank)',
        'Strong (pistol progressions / advanced core)',
      ],
    ),
    OnboardingStep(
      id: 'equipment',
      headline: 'What equipment can you use?',
      subhead: 'Select all that apply.',
      type: OnboardingStepType.multiSelect,
      options: [
        'Pull-up bar',
        'Dip bars / parallel bars',
        'Rings',
        'Resistance bands',
        'Dumbbells / weights',
        'None (bodyweight only)',
      ],
    ),
    OnboardingStep(
      id: 'days_per_week',
      headline: 'Training days per week',
      options: ['2', '3', '4', '5', '6'],
    ),
    OnboardingStep(
      id: 'workout_length',
      headline: 'Workout length',
      options: ['15-20 min', '25-35', '40-55', '60+'],
    ),
    OnboardingStep(
      id: 'barrier',
      headline: 'What is stopping you right now?',
      options: [
        'Lack of consistency',
        'Not sure what to do',
        'Plateau / no progress',
        'Busy schedule',
        'Low motivation',
        'Pain / fear of injury',
      ],
    ),
    OnboardingStep(
      id: 'trust',
      headline: 'Thanks for trusting SkillMax',
      subhead: 'Your privacy matters. We do not sell personal data.',
      type: OnboardingStepType.trust,
    ),
    OnboardingStep(
      id: 'adapt_if_missed',
      headline: 'Should SkillMax adapt if you miss a workout?',
      subhead: 'We will reshuffle your week so you do not fall behind.',
      options: ['Yes', 'No'],
    ),
    OnboardingStep(
      id: 'rating',
      headline: 'How does this feel so far?',
      subhead: 'Your feedback directly improves SkillMax.',
      type: OnboardingStepType.rating,
    ),
    OnboardingStep(
      id: 'notifications',
      headline: 'Reach your goals with reminders',
      subhead: 'Would you like workout reminders?',
      options: ["Allow", "Don't Allow"],
    ),
    OnboardingStep(
      id: 'referral',
      headline: 'Do you have a referral code?',
      subhead: 'You can skip this step.',
      type: OnboardingStepType.referral,
    ),
    OnboardingStep(
      id: 'generate',
      headline: 'Time to generate your SkillMax plan',
      subhead:
          'Calibrating progressions based on your goals, strength, and schedule.',
      type: OnboardingStepType.loading,
    ),
    OnboardingStep(
      id: 'plan_ready',
      headline: 'Your SkillMax plan is ready',
      subhead:
          'Based on your answers, your schedule and progressions are personalized.',
      type: OnboardingStepType.planReady,
    ),
  ];

  @override
  void dispose() {
    _loadingAdvanceTimer?.cancel();
    _loadingTickTimer?.cancel();
    _pageController.dispose();
    _referralController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _heightCmController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _index = page);
    _loadingAdvanceTimer?.cancel();
    _loadingTickTimer?.cancel();

    if (_steps[page].type == OnboardingStepType.loading) {
      _startLoadingAnimation(page);
    }
  }

  void _startLoadingAnimation(int page) {
    setState(() => _loadingProgress = 0);

    _loadingTickTimer = Timer.periodic(const Duration(milliseconds: 70), (
      timer,
    ) {
      if (!mounted || _index != page) {
        timer.cancel();
        return;
      }

      final next = (_loadingProgress + 0.028).clamp(0.0, 1.0);
      setState(() => _loadingProgress = next);
      if (next >= 1.0) {
        timer.cancel();
      }
    });

    _loadingAdvanceTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || _index != page) return;
      _next();
    });
  }

  Future<void> _presentSignUpFlow() async {
    if (!mounted) return;
    final signedUp = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const SignUpView(showPaywallAfterSignUp: false),
      ),
    );
    if (!mounted || signedUp != true) return;
    final onboardingData = _buildOnboardingPayload();
    final unlocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TrialIntroScreen(onboardingData: onboardingData),
      ),
    );
    if (mounted && unlocked == true) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Map<String, dynamic> _buildOnboardingPayload() {
    final payload = <String, dynamic>{};

    payload.addAll(_singleAnswers);

    _multiAnswers.forEach((key, value) {
      payload[key] = value.toList(growable: false);
    });

    final weight = int.tryParse(_weightController.text.trim());
    final cmHeight = int.tryParse(_heightCmController.text.trim());
    final feet = int.tryParse(_heightFeetController.text.trim()) ?? 0;
    final inches = int.tryParse(_heightInchesController.text.trim()) ?? 0;
    final totalInches = (feet * 12) + inches;

    payload['height'] = _useImperial ? totalInches : cmHeight;
    payload['weight'] = weight;
    payload['height_unit'] = _useImperial ? 'in' : 'cm';
    payload['height_feet'] = _useImperial ? feet : null;
    payload['height_inches'] = _useImperial ? inches : null;
    payload['weight_unit'] = _useImperial ? 'lb' : 'kg';
    payload['birthday'] = _birthday?.toIso8601String();
    payload['rating'] = _rating;
    payload['referral_code'] = _referralController.text.trim().toUpperCase();

    return payload;
  }

  bool _isStepComplete(OnboardingStep step) {
    switch (step.type) {
      case OnboardingStepType.singleChoice:
        return _singleAnswers[step.id] != null;
      case OnboardingStepType.multiSelect:
        final selected = _multiAnswers[step.id];
        return selected != null && selected.isNotEmpty;
      case OnboardingStepType.chart:
      case OnboardingStepType.trust:
        return true;
      case OnboardingStepType.heightWeight:
        final weight = int.tryParse(_weightController.text.trim());
        if (weight == null || weight <= 0) return false;

        if (_useImperial) {
          final feet = int.tryParse(_heightFeetController.text.trim()) ?? -1;
          final inches =
              int.tryParse(_heightInchesController.text.trim()) ?? -1;
          return feet >= 0 &&
              inches >= 0 &&
              inches <= 11 &&
              (feet > 0 || inches > 0);
        }

        final cm = int.tryParse(_heightCmController.text.trim());
        return cm != null && cm > 0;
      case OnboardingStepType.date:
        return _birthday != null;
      case OnboardingStepType.rating:
        return _rating > 0;
      case OnboardingStepType.referral:
      case OnboardingStepType.loading:
      case OnboardingStepType.planReady:
        return true;
    }
  }

  void _setSingleAnswer(OnboardingStep step, String value) {
    setState(() => _singleAnswers[step.id] = value);
  }

  void _toggleMultiAnswer(OnboardingStep step, String value) {
    final selected = _multiAnswers.putIfAbsent(step.id, () => <String>{});
    setState(() {
      if (selected.contains(value)) {
        selected.remove(value);
        return;
      }

      if (step.id == 'equipment') {
        if (value == 'None (bodyweight only)') {
          selected
            ..clear()
            ..add(value);
          return;
        }
        selected.remove('None (bodyweight only)');
      }

      if (step.maxSelections != null &&
          selected.length >= step.maxSelections!) {
        return;
      }
      selected.add(value);
    });
  }

  Future<void> _triggerStoreReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open review flow right now.')),
      );
    }
  }

  Future<void> _requestNativeNotificationPermission() async {
    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  Future<void> _openBirthdayPicker() async {
    final now = DateTime.now();
    final initialDate =
        _birthday ?? DateTime(now.year - 20, now.month, now.day);

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      var tempDate = initialDate;
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) {
          return Container(
            height: 320,
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        onPressed: () {
                          setState(() => _birthday = tempDate);
                          Navigator.of(context).pop();
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    maximumDate: now,
                    minimumDate: DateTime(1930),
                    initialDateTime: initialDate,
                    onDateTimeChanged: (value) => tempDate = value,
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _birthday = selected);
    }
  }

  void _next() {
    if (!_pageController.hasClients) return;
    if (_index == _steps.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (!_pageController.hasClients || _index == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onContinue() async {
    final step = _steps[_index];
    if (!_isStepComplete(step)) return;

    if (step.id == 'notifications' &&
        _singleAnswers['notifications'] == 'Allow') {
      await _requestNativeNotificationPermission();
    }

    _next();
  }

  Widget _buildHeader() {
    final progress = (_index + 1) / _steps.length;
    return Row(
      children: [
        IconButton(
          onPressed: _index > 0 ? _back : null,
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: _index > 0 ? _kBlue : Colors.black26,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: _kBlue,
              backgroundColor: const Color(0xFFDCEAF5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIntro(OnboardingStep step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step.headline,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _kText,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.02,
          ),
        ),
        if (step.subhead != null) ...[
          const SizedBox(height: 10),
          Text(
            step.subhead!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _kSubtleText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (step.microcopy != null) ...[
          const SizedBox(height: 10),
          Text(
            step.microcopy!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _kSubtleText),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionList(OnboardingStep step) {
    final isMulti = step.type == OnboardingStepType.multiSelect;
    final selectedSingle = _singleAnswers[step.id];
    final selectedMulti = _multiAnswers[step.id] ?? <String>{};
    return Column(
      children: [
        for (final option in step.options ?? const <String>[]) ...[
          _SelectionTile(
            label: option,
            selected: isMulti
                ? selectedMulti.contains(option)
                : selectedSingle == option,
            onTap: () {
              if (isMulti) {
                _toggleMultiAnswer(step, option);
              } else {
                _setSingleAnswer(step, option);
              }
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildProofChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8EAF5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(30, 98, 140, 0.08),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: CustomPaint(painter: _ProofChartPainter()),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(color: _kBlue, text: 'SkillMax adaptive plan'),
              SizedBox(width: 10),
              _LegendDot(color: Color(0xFF8AA4B6), text: 'Random routine'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeightWeight() {
    final weightUnit = _useImperial ? 'lb' : 'kg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _kTile,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _UnitButton(
                  label: 'Imperial',
                  selected: _useImperial,
                  onTap: () => setState(() => _useImperial = true),
                ),
              ),
              Expanded(
                child: _UnitButton(
                  label: 'Metric',
                  selected: !_useImperial,
                  onTap: () => setState(() => _useImperial = false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8EAF5)),
          ),
          child: Column(
            children: [
              if (_useImperial) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Height',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InputRow(
                        label: 'Feet',
                        controller: _heightFeetController,
                        suffix: 'ft',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InputRow(
                        label: 'Inches',
                        controller: _heightInchesController,
                        suffix: 'in',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ] else
                _InputRow(
                  label: 'Height',
                  controller: _heightCmController,
                  suffix: 'cm',
                  onChanged: (_) => setState(() {}),
                ),
              const SizedBox(height: 10),
              _InputRow(
                label: 'Weight',
                controller: _weightController,
                suffix: weightUnit,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBirthday() {
    final text = _birthday == null
        ? 'Select your birthday'
        : '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}';

    return Column(
      children: [
        _SelectionTile(
          label: text,
          selected: _birthday != null,
          onTap: _openBirthdayPicker,
        ),
      ],
    );
  }

  Widget _buildTrustStep() {
    return Column(
      children: const [
        _InfoTile(text: 'Edit goals anytime'),
        SizedBox(height: 10),
        _InfoTile(text: 'Adjust equipment anytime'),
        SizedBox(height: 10),
        _InfoTile(text: 'Pause training anytime'),
      ],
    );
  }

  Widget _buildRating() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final active = i < _rating;
            return IconButton(
              onPressed: () {
                setState(() => _rating = i + 1);
                if (!_didAskForStoreReview) {
                  _didAskForStoreReview = true;
                  _triggerStoreReview();
                }
              },
              icon: Icon(
                active ? Icons.star_rounded : Icons.star_outline_rounded,
                color: active
                    ? const Color(0xFFFCB230)
                    : const Color(0xFFB9D2E3),
                size: 38,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildReferral() {
    return TextField(
      controller: _referralController,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        hintText: 'Enter referral code',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8EAF5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8EAF5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBlue, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildLoadingStep() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8EAF5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _loadingProgress,
              minHeight: 10,
              color: _kBlue,
              backgroundColor: const Color(0xFFDCEAF5),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(_loadingProgress * 100).round()}%',
              style: const TextStyle(
                color: _kSubtleText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ChecklistRow(
            text: 'Weekly schedule',
            active: _loadingProgress > 0.1,
          ),
          const SizedBox(height: 8),
          _ChecklistRow(
            text: 'Skill progressions',
            active: _loadingProgress > 0.3,
          ),
          const SizedBox(height: 8),
          _ChecklistRow(
            text: 'Strength blocks',
            active: _loadingProgress > 0.5,
          ),
          const SizedBox(height: 8),
          _ChecklistRow(
            text: 'Mobility / prehab',
            active: _loadingProgress > 0.7,
          ),
          const SizedBox(height: 8),
          _ChecklistRow(
            text: 'Recovery targets',
            active: _loadingProgress > 0.9,
          ),
        ],
      ),
    );
  }

  Future<void> _openPlanPreview() async {
    final days = _singleAnswers['days_per_week'] ?? '4';
    final goal = _singleAnswers['goal'] ?? 'Build Strength & Muscle';
    final skills = (_multiAnswers['skills'] ?? <String>{}).take(2).join(' + ');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan preview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _kText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ll get a $days-day weekly split focused on "$goal".',
                  style: const TextStyle(color: _kSubtleText),
                ),
                const SizedBox(height: 8),
                Text(
                  'Skill focus: ${skills.isEmpty ? 'Pull-up + Handstand' : skills}',
                  style: const TextStyle(color: _kSubtleText),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Full day-by-day details unlock after signup and subscription.',
                  style: TextStyle(color: _kSubtleText),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanReadyStep() {
    final days = _singleAnswers['days_per_week'] ?? '4';
    final length = _singleAnswers['workout_length'] ?? '25-35';
    final skills = (_multiAnswers['skills'] ?? <String>{}).take(3).toList();
    final skillText = skills.isEmpty ? 'Pull-up, Handstand' : skills.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8F3FB), Color(0xFFF7FBFF)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8EAF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly plan',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _kText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Push / Pull / Legs + Core / Skill Focus',
                style: TextStyle(
                  color: _kSubtleText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Skill track',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _kText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                skillText,
                style: const TextStyle(
                  color: _kSubtleText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Session setup',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _kText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$days days/week, $length sessions',
                style: const TextStyle(
                  color: _kSubtleText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _presentSignUpFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text('Unlock my plan'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _openPlanPreview,
          style: OutlinedButton.styleFrom(
            foregroundColor: _kBlue,
            side: const BorderSide(color: Color(0xFFBCD8E9)),
          ),
          child: const Text('Preview plan'),
        ),
      ],
    );
  }

  Widget _buildStepBody(OnboardingStep step) {
    switch (step.type) {
      case OnboardingStepType.singleChoice:
      case OnboardingStepType.multiSelect:
        return _buildOptionList(step);
      case OnboardingStepType.chart:
        return _buildProofChart();
      case OnboardingStepType.heightWeight:
        return _buildHeightWeight();
      case OnboardingStepType.date:
        return _buildBirthday();
      case OnboardingStepType.trust:
        return _buildTrustStep();
      case OnboardingStepType.rating:
        return _buildRating();
      case OnboardingStepType.referral:
        return _buildReferral();
      case OnboardingStepType.loading:
        return _buildLoadingStep();
      case OnboardingStepType.planReady:
        return _buildPlanReadyStep();
    }
  }

  bool get _showContinue {
    final type = _steps[_index].type;
    return type != OnboardingStepType.loading &&
        type != OnboardingStepType.planReady;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: _handlePageChanged,
                  itemCount: _steps.length,
                  itemBuilder: (context, i) {
                    final step = _steps[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildStepIntro(step),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: _buildStepBody(step),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (_showContinue) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isStepComplete(_steps[_index])
                      ? _onContinue
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    disabledBackgroundColor: const Color(0xFFADC7D7),
                    disabledForegroundColor: const Color(0xFFF2F7FB),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E628C), Color(0xFF134865)],
                  )
                : null,
            color: selected ? null : _kTile,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: selected ? Colors.white : const Color(0xFF9AB7C9),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: _kBlueDeep)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _kText,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitButton extends StatelessWidget {
  const _UnitButton({
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
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _kBlueDeep,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.controller,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String suffix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
            const Spacer(),
            Text(suffix, style: const TextStyle(color: _kSubtleText)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Enter $label'.toLowerCase(),
            filled: true,
            fillColor: _kTile,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8EAF5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8EAF5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBlue, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8EAF5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: _kBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: active ? 1 : 0.38,
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            color: active ? _kBlue : const Color(0xFF9AB7C9),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, color: _kText),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: _kSubtleText,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProofChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE0EDF6)
      ..strokeWidth = 1;

    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final adaptivePath = Path()
      ..moveTo(0, size.height * 0.84)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.72,
        size.width * 0.4,
        size.height * 0.51,
        size.width * 0.66,
        size.height * 0.32,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.24,
        size.width * 0.9,
        size.height * 0.16,
        size.width,
        size.height * 0.1,
      );

    final adaptiveArea = Path.from(adaptivePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final adaptiveFill = Paint()
      ..color = const Color(0x221E628C)
      ..style = PaintingStyle.fill;

    final adaptiveLine = Paint()
      ..color = _kBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final randomPath = Path()
      ..moveTo(0, size.height * 0.64)
      ..lineTo(size.width * 0.16, size.height * 0.7)
      ..lineTo(size.width * 0.32, size.height * 0.6)
      ..lineTo(size.width * 0.48, size.height * 0.76)
      ..lineTo(size.width * 0.64, size.height * 0.56)
      ..lineTo(size.width * 0.8, size.height * 0.67)
      ..lineTo(size.width, size.height * 0.58);

    final randomLine = Paint()
      ..color = const Color(0xFF8AA4B6)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    canvas.drawPath(adaptiveArea, adaptiveFill);
    canvas.drawPath(adaptivePath, adaptiveLine);
    canvas.drawPath(randomPath, randomLine);

    final axisStyle = TextStyle(
      color: const Color(0xFF6A879A),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    final x1 = TextPainter(
      text: TextSpan(text: 'Month 1', style: axisStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    x1.paint(canvas, Offset(0, size.height - 18));

    final x2 = TextPainter(
      text: TextSpan(text: 'Month 6', style: axisStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    x2.paint(canvas, Offset(size.width - x2.width, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
