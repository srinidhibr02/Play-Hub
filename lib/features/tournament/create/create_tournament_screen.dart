import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/navigation/app_route.dart';
import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/core/widgets/number_stepper.dart';
import 'package:play_hub/core/widgets/pressable_scale.dart';
import 'package:play_hub/core/widgets/sport_badge.dart';
import 'package:play_hub/features/tournament/detail/tournament_detail_screen.dart';
import 'package:play_hub/logic/payments.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

enum _Step {
  sport('Choose a sport'),
  type('Tournament type'),
  details('Tournament details'),
  rules('Format & rules'),
  registration('Registration & fees'),
  review('Review');

  const _Step(this.title);
  final String title;
}

/// Wizard for a new tournament.
///
/// Friendly tournaments are created straight away (sport, type, details,
/// rules, review). Hosted tournaments add a registration and fees step.
class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _feeController = TextEditingController();
  final _upiController = TextEditingController();
  final _phoneController = TextEditingController();

  int _step = 0;
  Sport? _sport;
  TournamentKind _kind = TournamentKind.friendly;
  TournamentFormat _format = TournamentFormat.roundRobin;
  TournamentSettings _settings = const TournamentSettings();
  late DateTime _startDate;
  bool _isPublic = false;
  bool _publicTouched = false;
  bool _nameTouched = false;
  bool _registrationTouched = false;
  bool _saving = false;

  // Hosted only
  int _capacity = 8;
  DateTime? _deadline;
  bool _acceptCash = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _venueController.dispose();
    _descriptionController.dispose();
    _feeController.dispose();
    _upiController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ derived state

  bool get _isHosted => _kind == TournamentKind.hosted;

  List<_Step> get _steps => [
        _Step.sport,
        _Step.type,
        _Step.details,
        _Step.rules,
        if (_isHosted) _Step.registration,
        _Step.review,
      ];

  _Step get _currentStep => _steps[_step];

  bool get _nameValid => _nameController.text.trim().length >= 3;

  int get _formatMax => _format == TournamentFormat.roundRobin ? 24 : 32;

  int get _fee => int.tryParse(_feeController.text.trim()) ?? 0;

  Color get _accent => _sport?.color ?? Theme.of(context).colorScheme.primary;

  String? get _phoneError => Payments.isValidPhone(_phoneController.text)
      ? null
      : 'Enter a phone number teams can reach you on';

  String? get _paymentError => Payments.validateFeeSetup(
        fee: _fee,
        upiId: _upiController.text,
        acceptCash: _acceptCash,
      );

  String? get _deadlineError {
    final d = _deadline;
    if (d == null) return null;
    final deadlineDay = DateTime(d.year, d.month, d.day);
    final startDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    if (deadlineDay.isAfter(startDay)) {
      return 'The deadline must be on or before the start date.';
    }
    return null;
  }

  bool get _registrationValid =>
      _phoneError == null && _paymentError == null && _deadlineError == null;

  bool get _canContinue => switch (_currentStep) {
        _Step.sport => _sport != null,
        _ => true,
      };

  // ----------------------------------------------------------------- actions

  void _selectSport(Sport sport) {
    setState(() {
      _sport = sport;
      _settings = TournamentSettings.defaultsFor(sport);
    });
  }

  void _selectKind(TournamentKind kind) {
    setState(() {
      _kind = kind;
      // Listed by default for hosted events, unlisted for private friendlies,
      // unless the organizer already made their own choice.
      if (!_publicTouched) _isPublic = kind == TournamentKind.hosted;
    });
  }

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    switch (_currentStep) {
      case _Step.sport:
        if (_sport == null) return;
      case _Step.details:
        if (!_nameValid) {
          setState(() => _nameTouched = true);
          return;
        }
      case _Step.registration:
        if (!_registrationValid) {
          setState(() => _registrationTouched = true);
          return;
        }
      case _Step.type:
      case _Step.rules:
      case _Step.review:
        break;
    }

    if (_step < _steps.length - 1) {
      _goToStep(_step + 1);
    } else {
      _create();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      _goToStep(_step - 1);
    }
  }

  Future<DateTime?> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) {
    // Keep the dialog's bounds valid even if the start date is in the past.
    final safeLast = last.isBefore(first) ? first : last;
    final safeInitial = initial.isBefore(first)
        ? first
        : (initial.isAfter(safeLast) ? safeLast : initial);
    return showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: first,
      lastDate: safeLast,
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await _pickDate(
      initial: _startDate,
      first: now.subtract(const Duration(days: 365)),
      last: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await _pickDate(
      initial: _deadline ?? _startDate,
      first: today,
      last: _startDate,
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _create() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final sport = _sport;
    if (user == null || sport == null) return;

    setState(() => _saving = true);
    try {
      final hosted = _isHosted;
      final tournament = Tournament(
        id: '',
        ownerId: user.uid,
        ownerName: user.displayName ?? user.email ?? 'Organizer',
        name: _nameController.text.trim(),
        sport: sport,
        startDate: _startDate,
        settings: _settings,
        kind: _kind,
        format: _format,
        venue: _venueController.text.trim(),
        description: _descriptionController.text.trim(),
        isPublic: _isPublic,
        capacity: hosted ? math.min(_capacity, _formatMax) : 0,
        registrationOpen: hosted,
        registrationDeadline: hosted ? _deadline : null,
        entryFee: hosted ? _fee : 0,
        upiId: hosted && _fee > 0 ? _upiController.text.trim() : '',
        acceptCash: hosted && _fee > 0 && _acceptCash,
        contactPhone:
            hosted ? Payments.normalizePhone(_phoneController.text) : '',
      );
      final id = await ref
          .read(tournamentRepositoryProvider)
          .createTournament(tournament);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        appRoute(TournamentDetailScreen(tournamentId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create the tournament. Check your connection and '
            'try again.',
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _steps;
    final isLast = _step == steps.length - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
            onPressed: _back,
          ),
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _currentStep.title,
              key: ValueKey(_currentStep),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  '${_step + 1}/${steps.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: (_step + 1) / steps.length),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: _accent,
                    backgroundColor: _accent.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final step in steps) _scrollPage(_pageFor(step)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _back,
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _accent),
                        onPressed: (_canContinue && !_saving) ? _next : null,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isLast
                                    ? (_isHosted
                                        ? 'Create & get invite code'
                                        : 'Create tournament')
                                    : 'Continue',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageFor(_Step step) => switch (step) {
        _Step.sport => _buildSportStep(),
        _Step.type => _buildTypeStep(),
        _Step.details => _buildDetailsStep(),
        _Step.rules => _buildRulesStep(),
        _Step.registration => _buildRegistrationStep(),
        _Step.review => _buildReviewStep(),
      };

  Widget _scrollPage(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: child,
    );
  }

  // ------------------------------------------------------------ step: sport

  Widget _buildSportStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are you hosting?',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < Sport.values.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SportOption(
              sport: Sport.values[i],
              selected: _sport == Sport.values[i],
              onTap: () => _selectSport(Sport.values[i]),
            ).entrance(index: i),
          ),
      ],
    );
  }

  // ------------------------------------------------------------- step: type

  Widget _buildTypeStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you want to run it?',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < TournamentKind.values.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _KindOption(
              kind: TournamentKind.values[i],
              accent: _accent,
              selected: _kind == TournamentKind.values[i],
              onTap: () => _selectKind(TournamentKind.values[i]),
            ).entrance(index: i),
          ),
      ],
    );
  }

  // ----------------------------------------------------------- step: details

  Widget _buildDetailsStep() {
    final theme = Theme.of(context);
    final showNameError = _nameTouched && !_nameValid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Tournament name',
            hintText: 'e.g. Sunday Smash Cup',
            prefixIcon: const Icon(Icons.emoji_events_outlined),
            errorText: showNameError
                ? 'Give your tournament a name (3+ characters)'
                : null,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _venueController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Venue (optional)',
            hintText: 'Ground, court or club name',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _pickStartDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Start date',
              prefixIcon: Icon(Icons.calendar_today_outlined),
              suffixIcon: Icon(Icons.expand_more_rounded),
            ),
            child: Text(formatDate(_startDate)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Description (optional)',
            hintText: _isHosted
                ? 'Rules, prizes, what to bring...'
                : 'Anything players should know...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            value: _isPublic,
            onChanged: (value) => setState(() {
              _isPublic = value;
              _publicTouched = true;
            }),
            title: const Text(
              'List in Discover',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _isPublic
                  ? 'Anyone can find it in the Discover tab.'
                  : 'Unlisted. Only people with the invite code can find it.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- step: rules

  Widget _buildRulesStep() {
    final sport = _sport ?? Sport.football;
    final isLeague = _format == TournamentFormat.roundRobin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TournamentFormat>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: TournamentFormat.roundRobin,
                    label: Text('League'),
                    icon: Icon(Icons.table_rows_rounded),
                  ),
                  ButtonSegment(
                    value: TournamentFormat.knockout,
                    label: Text('Knockout'),
                    icon: Icon(Icons.account_tree_rounded),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: (selection) => setState(() {
                  _format = selection.first;
                  _capacity = math.min(_capacity, _formatMax);
                }),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _format.description,
                  key: ValueKey(_format),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (isLeague) ...[
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Single round')),
                    ButtonSegment(value: 2, label: Text('Home & away')),
                  ],
                  selected: {_settings.legs},
                  onSelectionChanged: (selection) => setState(
                    () => _settings = _settings.copyWith(legs: selection.first),
                  ),
                ),
              ],
            ],
          ),
        ).entrance(),
        const SizedBox(height: 14),
        _Section(
          title: '${sport.label} rules',
          child: _buildSportRules(sport),
        ).entrance(index: 1),
        if (isLeague) ...[
          const SizedBox(height: 14),
          _Section(
            title: 'Points table',
            child: Column(
              children: [
                NumberStepper(
                  label: 'Points for a win',
                  value: _settings.winPoints,
                  min: 1,
                  max: 5,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(winPoints: v),
                  ),
                ),
                if (sport != Sport.badminton) ...[
                  const SizedBox(height: 12),
                  NumberStepper(
                    label: sport == Sport.cricket
                        ? 'Points for a tie / no result'
                        : 'Points for a draw',
                    value: _settings.drawPoints,
                    min: 0,
                    max: 3,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(drawPoints: v),
                    ),
                  ),
                ],
              ],
            ),
          ).entrance(index: 2),
        ],
      ],
    );
  }

  Widget _buildSportRules(Sport sport) {
    switch (sport) {
      case Sport.football:
        return NumberStepper(
          label: 'Half length',
          value: _settings.halfMinutes,
          min: 5,
          max: 45,
          step: 5,
          suffix: ' min',
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(halfMinutes: v)),
        );
      case Sport.cricket:
        return NumberStepper(
          label: 'Overs per innings',
          value: _settings.overs,
          min: 1,
          max: 50,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(overs: v)),
        );
      case Sport.badminton:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Games per match',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final n in const [1, 3, 5])
                  ButtonSegment(value: n, label: Text('Best of $n')),
              ],
              selected: {_settings.bestOfGames},
              onSelectionChanged: (selection) => setState(
                () => _settings =
                    _settings.copyWith(bestOfGames: selection.first),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Points per game',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final n in const [11, 15, 21])
                  ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_settings.pointsPerGame},
              onSelectionChanged: (selection) => setState(
                () => _settings =
                    _settings.copyWith(pointsPerGame: selection.first),
              ),
            ),
          ],
        );
    }
  }

  // ------------------------------------------------------ step: registration

  Widget _buildRegistrationStep() {
    final theme = Theme.of(context);
    final sport = _sport ?? Sport.football;
    final hasFee = _fee > 0;
    final showErrors = _registrationTouched;
    final paymentError = showErrors ? _paymentError : null;
    final deadlineError = _deadlineError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Who can join',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NumberStepper(
                label: 'Maximum ${sport.participantNounPlural.toLowerCase()}',
                helper: 'Up to $_formatMax for a ${_format.label.toLowerCase()}',
                value: _capacity,
                min: 2,
                max: _formatMax,
                onChanged: (v) => setState(() => _capacity = v),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDeadline,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Registration deadline (optional)',
                    prefixIcon: const Icon(Icons.event_available_outlined),
                    errorText: deadlineError,
                    suffixIcon: _deadline == null
                        ? const Icon(Icons.expand_more_rounded)
                        : IconButton(
                            tooltip: 'Remove deadline',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _deadline = null),
                          ),
                  ),
                  child: Text(
                    _deadline == null
                        ? 'No deadline'
                        : formatDate(_deadline!),
                  ),
                ),
              ),
            ],
          ),
        ).entrance(),
        const SizedBox(height: 14),
        _Section(
          title: 'Entry fee',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Fee per team (₹)',
                  hintText: '0 for free entry',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: hasFee
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _upiController,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Your UPI ID',
                                hintText: 'name@bank',
                                prefixIcon: Icon(Icons.qr_code_2_rounded),
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _acceptCash,
                              onChanged: (v) =>
                                  setState(() => _acceptCash = v),
                              title: const Text(
                                'Accept cash',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: const Text(
                                'Teams can pay you in person instead.',
                              ),
                            ),
                            if (paymentError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  paymentError,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              'Play Hub does not handle the money. Teams pay '
                              'you directly, then tell the app they have '
                              'paid and you confirm it.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ).entrance(index: 1),
        const SizedBox(height: 14),
        _Section(
          title: 'Contact',
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Your phone number',
              hintText: 'Shown to registered teams',
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: showErrors ? _phoneError : null,
            ),
          ),
        ).entrance(index: 2),
      ],
    );
  }

  // ------------------------------------------------------------ step: review

  String _rulesSummary(Sport sport) {
    switch (sport) {
      case Sport.football:
        return '${_settings.halfMinutes} minute halves';
      case Sport.cricket:
        return '${_settings.overs} overs per innings';
      case Sport.badminton:
        return 'Best of ${_settings.bestOfGames} games to '
            '${_settings.pointsPerGame}';
    }
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final sport = _sport ?? Sport.football;
    final isLeague = _format == TournamentFormat.roundRobin;
    final name = _nameController.text.trim();
    final venue = _venueController.text.trim();

    final formatText = isLeague
        ? (_settings.legs == 2 ? 'League, home & away' : 'League, single round')
        : 'Knockout';

    final payBy = [
      if (_upiController.text.trim().isNotEmpty) 'UPI',
      if (_acceptCash) 'cash',
    ].join(' or ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SportBadge(sport: sport, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Untitled tournament' : name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ReviewRow(
                  icon: Icons.category_outlined,
                  label: 'Sport',
                  value: sport.label,
                ),
                _ReviewRow(
                  icon: _isHosted
                      ? Icons.campaign_outlined
                      : Icons.bolt_rounded,
                  label: 'Type',
                  value: _kind.title,
                ),
                _ReviewRow(
                  icon: Icons.account_tree_outlined,
                  label: 'Format',
                  value: formatText,
                ),
                _ReviewRow(
                  icon: Icons.rule_rounded,
                  label: 'Rules',
                  value: _rulesSummary(sport),
                ),
                if (isLeague)
                  _ReviewRow(
                    icon: Icons.leaderboard_outlined,
                    label: 'Points',
                    value: sport == Sport.badminton
                        ? '${_settings.winPoints} for a win'
                        : '${_settings.winPoints} for a win, '
                            '${_settings.drawPoints} for a draw',
                  ),
                _ReviewRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Starts',
                  value: formatDate(_startDate),
                ),
                if (venue.isNotEmpty)
                  _ReviewRow(
                    icon: Icons.place_outlined,
                    label: 'Venue',
                    value: venue,
                  ),
                if (_isHosted) ...[
                  _ReviewRow(
                    icon: Icons.groups_outlined,
                    label: 'Capacity',
                    value: '${math.min(_capacity, _formatMax)} '
                        '${sport.participantNounPlural.toLowerCase()}',
                  ),
                  if (_deadline != null)
                    _ReviewRow(
                      icon: Icons.event_available_outlined,
                      label: 'Register by',
                      value: formatDate(_deadline!),
                    ),
                  _ReviewRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Entry fee',
                    value: _fee > 0
                        ? '${formatRupees(_fee)} per team, pay by $payBy'
                        : 'Free',
                  ),
                  _ReviewRow(
                    icon: Icons.phone_outlined,
                    label: 'Contact',
                    value: Payments.normalizePhone(_phoneController.text),
                  ),
                ],
                _ReviewRow(
                  icon: _isPublic
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  label: 'Visibility',
                  value: _isPublic ? 'Listed in Discover' : 'Unlisted',
                ),
              ],
            ),
          ),
        ).entrance(),
        const SizedBox(height: 16),
        Text(
          _isHosted
              ? 'You will get an invite code to share. Teams register, you '
                  'approve them, then you draw the fixtures.'
              : 'Next you will add '
                  '${sport.participantNounPlural.toLowerCase()} and draw the '
                  'fixtures.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ======================================================================
// Option cards and small building blocks
// ======================================================================

class _SportOption extends StatelessWidget {
  const _SportOption({
    required this.sport,
    required this.selected,
    required this.onTap,
  });

  final Sport sport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textColor = selected ? Colors.white : scheme.onSurface;
    final subColor = selected
        ? Colors.white.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: selected ? sport.gradient : null,
          color: selected ? null : theme.cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? sport.color : scheme.outlineVariant,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: sport.color.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : sport.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                sport.icon,
                size: 30,
                color: selected ? Colors.white : sport.color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sport.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sport.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(color: subColor),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey('on'),
                      color: Colors.white,
                    )
                  : Icon(
                      Icons.circle_outlined,
                      key: const ValueKey('off'),
                      color: scheme.outline,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Friendly / Hosted choice card with a short list of what each one means.
class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.kind,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final TournamentKind kind;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isHosted = kind == TournamentKind.hosted;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : theme.cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? accent : scheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: selected ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isHosted ? Icons.campaign_rounded : Icons.bolt_rounded,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        kind.tagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('on'),
                          color: accent,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('off'),
                          color: scheme.outline,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final line in kind.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
