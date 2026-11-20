import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:play_hub/core/navigation/app_route.dart';
import 'package:play_hub/core/utils/errors.dart';
import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/features/tournament/registration/payment_sheet.dart';
import 'package:play_hub/features/tournament/registration/register_screen.dart';
import 'package:play_hub/logic/badminton_stats.dart';
import 'package:play_hub/logic/invite_code.dart';
import 'package:play_hub/logic/payments.dart';
import 'package:play_hub/logic/player_stats.dart';
import 'package:play_hub/logic/scorecard.dart';
import 'package:play_hub/logic/tournament_stats.dart';
import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/models/tournament_match.dart';
import 'package:play_hub/providers/providers.dart';

/// First tab of a tournament: invite code, registration (hosted
/// tournaments) and the key details.
class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.tournament, required this.isOwner});

  final Tournament tournament;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    // A registered team is allowed to see the organizer's phone number.
    final registered = !isOwner &&
        t.isHosted &&
        ref.watch(myRegistrationProvider(t.id)).valueOrNull != null;

    return ListView(
      key: const PageStorageKey('overview-list'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _InviteCard(tournament: t, isOwner: isOwner).entrance(),
        if (t.isHosted) ...[
          const SizedBox(height: 14),
          (isOwner
                  ? _OwnerRegistrationCard(tournament: t)
                  : _MyRegistrationCard(tournament: t))
              .entrance(index: 1),
        ],
        _StatsCard(tournament: t),
        _LeadersCard(tournament: t),
        const SizedBox(height: 14),
        _DetailsCard(
          tournament: t,
          showContact: isOwner || registered,
        ).entrance(index: 3),
      ],
    );
  }
}

// ======================================================================
// Stats
// ======================================================================

/// Headline numbers from the results entered so far. Hidden until a match
/// has been completed.
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    final matches = ref.watch(matchesProvider(t.id)).valueOrNull;
    if (matches == null) return const SizedBox.shrink();

    final lines = TournamentStats.compute(sport: t.sport, matches: matches);
    if (lines.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, color: t.sport.color),
                  const SizedBox(width: 10),
                  Text(
                    'Tournament stats',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${t.completedCount}/${t.matchCount} played',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (line.detail.isNotEmpty)
                              Text(
                                line.detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        line.value,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: t.sport.color,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Leaders (football and cricket)
// ======================================================================

class _LeaderRow {
  const _LeaderRow(this.name, this.team, this.value);

  final String name;
  final String team;
  final String value;
}

class _LeaderSection {
  const _LeaderSection(this.title, this.icon, this.rows);

  final String title;
  final IconData icon;
  final List<_LeaderRow> rows;
}

/// Top players, from the events and scorecards organizers record.
class _LeadersCard extends ConsumerWidget {
  const _LeadersCard({required this.tournament});

  final Tournament tournament;

  List<_LeaderSection> _football(
    List<TournamentMatch> matches,
    List<Team> teams,
  ) {
    final all = PlayerStats.compute(matches: matches, teams: teams);
    return [
      _LeaderSection(
        'Top scorers',
        Icons.sports_soccer_rounded,
        [
          for (final p in PlayerStats.topScorers(all))
            _LeaderRow(
              p.name,
              p.teamName,
              p.penaltyGoals > 0
                  ? '${p.goals} (${p.penaltyGoals} pen)'
                  : '${p.goals}',
            ),
        ],
      ),
      _LeaderSection(
        'Most assists',
        Icons.handshake_outlined,
        [
          for (final p in PlayerStats.topAssists(all))
            _LeaderRow(p.name, p.teamName, '${p.assists}'),
        ],
      ),
      _LeaderSection(
        'Discipline',
        Icons.style_rounded,
        [
          for (final p in PlayerStats.discipline(all))
            _LeaderRow(
              p.name,
              p.teamName,
              [
                if (p.yellowCards > 0) '${p.yellowCards} Y',
                if (p.redCards > 0) '${p.redCards} R',
              ].join('  '),
            ),
        ],
      ),
    ];
  }

  List<_LeaderSection> _cricket(
    List<TournamentMatch> matches,
    List<Team> teams,
  ) {
    final all = CricketStats.compute(matches: matches, teams: teams);
    String sr(double? v) => v == null ? '-' : v.toStringAsFixed(1);
    return [
      _LeaderSection(
        'Most runs',
        Icons.sports_cricket_rounded,
        [
          for (final p in CricketStats.topBatters(all))
            _LeaderRow(
              p.name,
              '${p.teamName} · HS ${p.highestText} · SR ${sr(p.strikeRate)}',
              '${p.runs}',
            ),
        ],
      ),
      _LeaderSection(
        'Most wickets',
        Icons.sports_baseball_rounded,
        [
          for (final p in CricketStats.topBowlers(all))
            _LeaderRow(
              p.name,
              '${p.teamName} · best ${p.bestFigures} · '
                  'econ ${sr(p.economy)}',
              '${p.wickets}',
            ),
        ],
      ),
      _LeaderSection(
        'Most sixes',
        Icons.rocket_launch_outlined,
        [
          for (final p in CricketStats.mostSixes(all))
            _LeaderRow(p.name, p.teamName, '${p.sixes}'),
        ],
      ),
    ];
  }

  List<_LeaderSection> _badminton(
    List<TournamentMatch> matches,
    List<Team> teams,
  ) {
    final all = BadmintonStats.compute(matches: matches, teams: teams);
    return [
      _LeaderSection(
        'Most wins',
        Icons.emoji_events_outlined,
        [
          for (final p in BadmintonStats.mostWins(all))
            _LeaderRow(
              p.name,
              '${p.teamName} · ${p.won} of ${p.played} won',
              '${p.won}',
            ),
        ],
      ),
      _LeaderSection(
        'Best point difference',
        Icons.trending_up_rounded,
        [
          for (final p in BadmintonStats.bestPointDifference(all))
            _LeaderRow(p.name, p.teamName, '+${p.pointDifference}'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;

    final matches = ref.watch(matchesProvider(t.id)).valueOrNull;
    final teams = ref.watch(teamsProvider(t.id)).valueOrNull;
    if (matches == null || teams == null) return const SizedBox.shrink();

    final sections = (switch (t.sport) {
      Sport.football => _football(matches, teams),
      Sport.cricket => _cricket(matches, teams),
      Sport.badminton => _badminton(matches, teams),
    })
        .where((s) => s.rows.isNotEmpty)
        .toList();
    if (sections.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: t.sport.color),
                  const SizedBox(width: 10),
                  Text(
                    'Player leaders',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              for (final section in sections)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(section.icon, size: 18, color: t.sport.color),
                          const SizedBox(width: 8),
                          Text(
                            section.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < section.rows.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${i + 1}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      section.rows[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (section.rows[i].team.isNotEmpty)
                                      Text(
                                        section.rows[i].team,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                section.rows[i].value,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: t.sport.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Invite
// ======================================================================

class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.tournament, required this.isOwner});

  final Tournament tournament;
  final bool isOwner;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _creating = false;

  Tournament get _t => widget.tournament;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('$what copied');
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buildInviteMessage(_t),
          subject: 'Join ${_t.name} on Play Hub',
        ),
      );
    } catch (e) {
      // No share sheet available: fall back to the clipboard.
      await _copy(buildInviteMessage(_t), 'Invite message');
    }
  }

  Future<void> _createCode() async {
    setState(() => _creating = true);
    try {
      await ref.read(tournamentRepositoryProvider).ensureInviteCode(_t);
    } catch (e) {
      _toast(describeError(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _t.sport.color;
    final hasCode = _t.inviteCode.isNotEmpty;

    if (!hasCode && !widget.isOwner) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _t.sport.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INVITE CODE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (hasCode) ...[
            SelectableText(
              InviteCode.format(_t.inviteCode),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _t.isHosted
                  ? 'Share this so teams can find and register.'
                  : 'Share this so friends can follow along.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: () => _copy(
                      InviteCode.format(_t.inviteCode),
                      'Invite code',
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Code'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _t.sport.colorDark,
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: _share,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share invite'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'This tournament has no invite code yet.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _t.sport.colorDark,
              ),
              onPressed: _creating ? null : _createCode,
              child: _creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Create invite code'),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Organizer: registration controls
// ======================================================================

class _OwnerRegistrationCard extends ConsumerWidget {
  const _OwnerRegistrationCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = tournament;
    final registrations =
        ref.watch(registrationsProvider(t.id)).valueOrNull ?? const [];
    final pending = registrations.where((r) => r.isPending).length;
    final toConfirm = registrations
        .where((r) => r.paymentStatus == PaymentStatus.submitted)
        .length;

    String subtitle;
    if (t.hasFixtures) {
      subtitle = 'Closed because the fixtures are drawn.';
    } else if (!t.registrationOpen) {
      subtitle = 'Teams cannot register right now.';
    } else if (t.deadlinePassed(DateTime.now())) {
      subtitle = 'The deadline has passed. Teams can no longer register.';
    } else if (t.isFull) {
      subtitle = 'Full. No more teams can register.';
    } else {
      subtitle = t.registrationDeadline == null
          ? 'Teams can register with your invite code.'
          : 'Open until ${formatDate(t.registrationDeadline!)}.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel('Registration'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: t.registrationOpen && !t.hasFixtures,
              onChanged: t.hasFixtures
                  ? null
                  : (value) async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(tournamentRepositoryProvider)
                            .setRegistrationOpen(t.id, value);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(describeError(e))),
                        );
                      }
                    },
              title: const Text(
                'Accepting registrations',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(subtitle),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '${t.teamCount}/${t.maxTeams}',
                    label: 'Approved',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _Stat(value: '$pending', label: 'Pending')),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    value: t.hasEntryFee ? formatRupees(t.entryFee) : 'Free',
                    label: 'Entry fee',
                  ),
                ),
              ],
            ),
            if (toConfirm > 0) ...[
              const SizedBox(height: 12),
              Text(
                toConfirm == 1
                    ? '1 payment is waiting for your confirmation.'
                    : '$toConfirm payments are waiting for your confirmation.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD97706),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => DefaultTabController.maybeOf(context)?.animateTo(1),
              icon: const Icon(Icons.how_to_reg_outlined),
              label: Text(
                pending > 0 ? 'Review $pending pending' : 'View registrations',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Participant: my registration
// ======================================================================

class _MyRegistrationCard extends ConsumerWidget {
  const _MyRegistrationCard({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registration = ref.watch(myRegistrationProvider(tournament.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: registration.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Text(describeError(error)),
          data: (r) => r == null
              ? _NotRegistered(tournament: tournament)
              : _Registered(tournament: tournament, registration: r),
        ),
      ),
    );
  }
}

class _NotRegistered extends StatelessWidget {
  const _NotRegistered({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tournament;
    final blocked = t.registrationBlockedReason(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('Registration'),
        if (blocked != null)
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  blocked,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        else ...[
          Text(
            'Register your ${t.sport.participantNoun.toLowerCase()}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (t.hasEntryFee)
                'Entry fee ${formatRupees(t.entryFee)}, pay by '
                    '${Payments.describeOptions(t).toLowerCase()}.'
              else
                'Free entry.',
              '${t.maxTeams - t.teamCount} '
                  '${t.maxTeams - t.teamCount == 1 ? 'spot' : 'spots'} left.',
              if (t.registrationDeadline != null)
                'Register by ${formatDate(t.registrationDeadline!)}.',
            ].join(' '),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.sport.color),
            onPressed: () => Navigator.of(context).push(
              appRoute(RegisterScreen(tournament: t)),
            ),
            child: const Text('Register'),
          ),
        ],
      ],
    );
  }
}

class _Registered extends ConsumerWidget {
  const _Registered({required this.tournament, required this.registration});

  final Tournament tournament;
  final Registration registration;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw registration?'),
        content: const Text(
          'Your registration will be cancelled. You can register again while '
          'registration is open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(tournamentRepositoryProvider)
          .withdrawRegistration(tournament.id, registration.userId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = tournament;
    final r = registration;

    final (statusColor, statusText) = switch (r.status) {
      RegistrationStatus.pending => (
          const Color(0xFFF59E0B),
          'Waiting for the organizer to review your team.'
        ),
      RegistrationStatus.approved => (
          const Color(0xFF16A34A),
          "You're in! The organizer will draw the fixtures soon."
        ),
      RegistrationStatus.rejected => (
          const Color(0xFFDC2626),
          'The organizer did not accept this registration.'
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('Your registration'),
        Row(
          children: [
            Expanded(
              child: Text(
                r.teamName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                r.status.label,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusText, style: theme.textTheme.bodyMedium),
        if (t.hasEntryFee && !r.isRejected) ...[
          const SizedBox(height: 14),
          _PaymentStatusBox(tournament: t, registration: r),
        ],
        if (r.isPending) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: () => _withdraw(context, ref),
              child: const Text('Withdraw registration'),
            ),
          ),
        ],
        if (r.isRejected && t.contactPhone.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Questions? Call ${t.contactPhone}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentStatusBox extends StatelessWidget {
  const _PaymentStatusBox({required this.tournament, required this.registration});

  final Tournament tournament;
  final Registration registration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tournament;

    final (color, icon, title, body) = switch (registration.paymentStatus) {
      PaymentStatus.paid => (
          const Color(0xFF16A34A),
          Icons.check_circle_rounded,
          'Payment confirmed',
          'The organizer received your ${formatRupees(t.entryFee)}.'
        ),
      PaymentStatus.submitted => (
          const Color(0xFFF59E0B),
          Icons.hourglass_top_rounded,
          'Waiting for confirmation',
          'You told the organizer you paid '
              '${registration.paymentMethod?.label ?? ''}. They will confirm '
              'it once they see it.'
        ),
      _ => (
          theme.colorScheme.primary,
          Icons.currency_rupee_rounded,
          'Entry fee ${formatRupees(t.entryFee)} due',
          'Pay by ${Payments.describeOptions(t).toLowerCase()} and tell the '
              'organizer.'
        ),
    };

    final canPay = registration.paymentStatus == PaymentStatus.unpaid;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
          if (canPay) ...[
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: t.sport.color,
              ),
              onPressed: () => showPaymentSheet(context, t),
              child: const Text('How to pay'),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Details
// ======================================================================

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.tournament, required this.showContact});

  final Tournament tournament;
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tournament;

    final formatText = t.format == TournamentFormat.roundRobin
        ? (t.settings.legs == 2 ? 'League, home & away' : 'League')
        : 'Knockout';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel('Details'),
            if (t.description.isNotEmpty) ...[
              Text(
                t.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
            ],
            _InfoRow(Icons.category_outlined, 'Type', t.kind.title),
            _InfoRow(Icons.account_tree_outlined, 'Format', formatText),
            _InfoRow(
              Icons.rule_rounded,
              'Rules',
              rulesSummary(t.sport, t.settings),
            ),
            _InfoRow(
              Icons.calendar_today_outlined,
              'Starts',
              formatDate(t.startDate),
            ),
            if (t.venue.isNotEmpty)
              _InfoRow(Icons.place_outlined, 'Venue', t.venue),
            _InfoRow(
              Icons.person_outline_rounded,
              'Organizer',
              t.ownerName.isEmpty ? 'Organizer' : t.ownerName,
            ),
            if (t.isHosted) ...[
              _InfoRow(
                Icons.groups_outlined,
                'Capacity',
                '${t.maxTeams} ${t.sport.participantNounPlural.toLowerCase()}',
              ),
              _InfoRow(
                Icons.currency_rupee_rounded,
                'Entry fee',
                t.hasEntryFee
                    ? '${formatRupees(t.entryFee)} per team '
                        '(${Payments.describeOptions(t)})'
                    : 'Free',
              ),
              if (t.registrationDeadline != null)
                _InfoRow(
                  Icons.event_available_outlined,
                  'Register by',
                  formatDate(t.registrationDeadline!),
                ),
              if (showContact && t.contactPhone.isNotEmpty)
                _InfoRow(Icons.phone_outlined, 'Contact', t.contactPhone),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Small pieces
// ======================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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
