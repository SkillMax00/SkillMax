import 'dart:async';

import 'package:flutter/material.dart';

import 'signup_view.dart';
import 'trial_intro_view.dart';

const _kCanvas = Colors.white;
const _kInk = Color(0xFF121017);
const _kSubtleText = Color(0xFF706C77);
const _kTile = Color(0xFFF6F6F8);

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
  final TextEditingController _heightController = TextEditingController(
    text: '68',
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

  final List<OnboardingStep> _steps = const [
    OnboardingStep(
      id: 'source',
      headline: 'Where did you hear about SkillMax?',
      options: [
        'TikTok',
        'Instagram',
        'YouTube',
        'App Store',
        'Friend',
        'Coach',
        'Reddit',
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
          'SkillMax updates your plan when you plateau so progress does not stop after week 2.',
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
      subhead: 'This helps us improve.',
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
      headline: 'Congratulations - your SkillMax plan is ready!',
      subhead:
          'Based on your answers, your schedule and progressions are now personalized.',
      type: OnboardingStepType.planReady,
    ),
  ];

  @override
  void dispose() {
    _loadingAdvanceTimer?.cancel();
    _pageController.dispose();
    _referralController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _index = page);
    _loadingAdvanceTimer?.cancel();
    if (_steps[page].type == OnboardingStepType.loading) {
      _loadingAdvanceTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted || _index != page) return;
        _next();
      });
    }
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

    final height = int.tryParse(_heightController.text.trim());
    final weight = int.tryParse(_weightController.text.trim());

    payload['height'] = height;
    payload['weight'] = weight;
    payload['height_unit'] = _useImperial ? 'in' : 'cm';
    payload['weight_unit'] = _useImperial ? 'lb' : 'kg';
    payload['birthday'] = _birthday?.toIso8601String();
    payload['rating'] = _rating;
    payload['referral_code'] = _referralController.text.trim();

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
        final height = int.tryParse(_heightController.text.trim());
        final weight = int.tryParse(_weightController.text.trim());
        return height != null && height > 0 && weight != null && weight > 0;
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

  void _onContinue() {
    final step = _steps[_index];
    if (!_isStepComplete(step)) return;
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
            color: _index > 0 ? _kInk : Colors.black26,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: Colors.black,
              backgroundColor: const Color(0xFFECECEF),
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
            color: _kInk,
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
        if (step.subhead != null) ...[
          const SizedBox(height: 10),
          Text(
            step.subhead!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _kSubtleText,
              fontWeight: FontWeight.w500,
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
        border: Border.all(color: const Color(0xFFE2DFE8)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: CustomPaint(painter: _ProofChartPainter()),
          ),
          const SizedBox(height: 12),
          Text(
            'SkillMax rises steadily while random workouts often stall.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _kSubtleText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeightWeight() {
    final heightUnit = _useImperial ? 'in' : 'cm';
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
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2DFE8)),
          ),
          child: Column(
            children: [
              _InputRow(
                label: 'Height',
                controller: _heightController,
                suffix: heightUnit,
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
        const SizedBox(height: 8),
        Text(
          _useImperial ? 'Imperial selected' : 'Metric selected',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: _kSubtleText),
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
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(1998, 1, 1),
              firstDate: DateTime(1930),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() => _birthday = date);
            }
          },
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
              onPressed: () => setState(() => _rating = i + 1),
              icon: Icon(
                active ? Icons.star_rounded : Icons.star_outline_rounded,
                color: active
                    ? const Color(0xFFF7B500)
                    : const Color(0xFFC9C6D1),
                size: 36,
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
          borderSide: const BorderSide(color: Color(0xFFE2DFE8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2DFE8)),
        ),
      ),
    );
  }

  Widget _buildLoadingStep() {
    return Column(
      children: const [
        SizedBox(height: 8),
        LinearProgressIndicator(
          value: 0.78,
          minHeight: 8,
          color: Colors.black,
          backgroundColor: Color(0xFFECECEF),
        ),
        SizedBox(height: 16),
        _ChecklistRow(text: 'Weekly schedule'),
        SizedBox(height: 8),
        _ChecklistRow(text: 'Skill progressions'),
        SizedBox(height: 8),
        _ChecklistRow(text: 'Strength blocks'),
        SizedBox(height: 8),
        _ChecklistRow(text: 'Mobility / prehab'),
        SizedBox(height: 8),
        _ChecklistRow(text: 'Recovery targets'),
      ],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2DFE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly plan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Push / Pull / Legs + Core / Skill Focus',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Skill track',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(skillText, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                'Session setup',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '$days days/week, $length sessions',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _presentSignUpFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kInk,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text("Let's get started!"),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () {}, child: const Text('Preview plan')),
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
                    backgroundColor: _kInk,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    disabledBackgroundColor: const Color(0xFFB8B8BD),
                    disabledForegroundColor: const Color(0xFFF2F2F4),
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
                    colors: [Color(0xFF101015), Color(0xFF18181D)],
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
                    color: selected ? Colors.white : const Color(0xFFC6C1CD),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: _kInk)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _kInk,
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
              color: _kInk,
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(suffix),
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
              borderSide: const BorderSide(color: Color(0xFFE2DFE8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2DFE8)),
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
        border: Border.all(color: const Color(0xFFE2DFE8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: _kInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: _kInk, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ProofChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE4E0E9)
      ..strokeWidth = 1;

    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final skillMax = Paint()
      ..color = _kInk
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final random = Paint()
      ..color = const Color(0xFF888392)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final a = Path()
      ..moveTo(0, size.height * 0.82)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.68,
        size.width * 0.55,
        size.height * 0.42,
        size.width,
        size.height * 0.18,
      );

    final b = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.25, size.height * 0.57)
      ..lineTo(size.width * 0.48, size.height * 0.76)
      ..lineTo(size.width * 0.7, size.height * 0.44)
      ..lineTo(size.width, size.height * 0.54);

    canvas.drawPath(a, skillMax);
    canvas.drawPath(b, random);

    final labelStyle = TextStyle(
      color: const Color(0xFF777382),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    final tpStart = TextPainter(
      text: TextSpan(text: 'Month 1', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tpStart.paint(canvas, Offset(0, size.height - 18));

    final tpEnd = TextPainter(
      text: TextSpan(text: 'Month 6', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tpEnd.paint(canvas, Offset(size.width - tpEnd.width, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
