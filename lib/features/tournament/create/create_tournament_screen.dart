import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/navigation/app_route.dart';
import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/core/widgets/number_stepper.dart';
import 'package:play_hub/core/widgets/pressable_scale.dart';
import 'package:play_hub/core/widgets/sport_badge.dart';
import 'package:play_hub/features/tournament/detail/tournament_detail_screen.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

/// Four-step wizard: sport, details, format & rules, review.
class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() =>
      _CreateTournamentScreenState();
}

class _CreateTournamentScreenState
    extends ConsumerState<CreateTournamentScreen> {
  static const _stepTitles = [
    'Choose a sport',
    'Tournament details',
    'Format & rules',
    'Review',
  ];

  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _step = 0;
  Sport? _sport;
  TournamentFormat _format = TournamentFormat.roundRobin;
  TournamentSettings _settings = const TournamentSettings();
  late DateTime _startDate;
  bool _isPublic = true;
  bool _nameTouched = false;
  bool _saving = false;

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
    super.dispose();
  }

  bool get _nameValid => _nameController.text.trim().length >= 3;

  bool get _canContinue => switch (_step) {
        0 => _sport != null,
        _ => true,
      };

  Color get _accent => _sport?.color ?? Theme.of(context).colorScheme.primary;

  void _selectSport(Sport sport) {
    setState(() {
      _sport = sport;
      _settings = TournamentSettings.defaultsFor(sport);
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
    if (_step == 0 && _sport == null) return;
    if (_step == 1 && !_nameValid) {
      setState(() => _nameTouched = true);
      return;
    }
    if (_step < _stepTitles.length - 1) {
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _create() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final sport = _sport;
    if (user == null || sport == null) return;

    setState(() => _saving = true);
    try {
      final tournament = Tournament(
        id: '',
        ownerId: user.uid,
        ownerName: user.displayName ?? user.email ?? 'Organizer',
        name: _nameController.text.trim(),
        sport: sport,
        startDate: _startDate,
        settings: _settings,
        format: _format,
        venue: _venueController.text.trim(),
        description: _descriptionController.text.trim(),
        isPublic: _isPublic,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _step == _stepTitles.length - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              _stepTitles[_step],
              key: ValueKey(_step),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  '${_step + 1}/${_stepTitles.length}',
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
                tween: Tween<double>(
                  end: (_step + 1) / _stepTitles.length,
                ),
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
                  _scrollPage(_buildSportStep()),
                  _scrollPage(_buildDetailsStep()),
                  _scrollPage(_buildRulesStep()),
                  _scrollPage(_buildReviewStep()),
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
                            : Text(isLast ? 'Create tournament' : 'Continue'),
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

  Widget _scrollPage(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: child,
    );
  }

  // ------------------------------------------------------------ step 1: sport

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

  // ---------------------------------------------------------- step 2: details

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
          onTap: _pickDate,
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
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            hintText: 'Rules, entry fee, prizes, contact...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            title: const Text(
              'Public tournament',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _isPublic
                  ? 'Shown in Discover so players and fans can follow along.'
                  : 'Only you can see this tournament.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- step 3: rules

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
                onSelectionChanged: (selection) =>
                    setState(() => _format = selection.first),
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

  // ---------------------------------------------------------- step 4: review

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
                _ReviewRow(
                  icon: _isPublic
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  label: 'Visibility',
                  value: _isPublic ? 'Public' : 'Private',
                ),
              ],
            ),
          ),
        ).entrance(),
        const SizedBox(height: 16),
        Text(
          'Next you will add ${sport.participantNounPlural.toLowerCase()} and '
          'draw the fixtures.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

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
    final subColor =
        selected ? Colors.white.withValues(alpha: 0.85) : scheme.onSurfaceVariant;

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
            width: 76,
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
