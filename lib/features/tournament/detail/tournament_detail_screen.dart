import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/empty_state.dart';
import 'package:play_hub/core/widgets/status_pill.dart';
import 'package:play_hub/features/tournament/detail/bracket_tab.dart';
import 'package:play_hub/features/tournament/detail/fixtures_tab.dart';
import 'package:play_hub/features/tournament/detail/overview_tab.dart';
import 'package:play_hub/features/tournament/detail/standings_tab.dart';
import 'package:play_hub/features/tournament/detail/teams_tab.dart';
import 'package:play_hub/features/tournament/registration/registrations_tab.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentProvider(tournamentId));

    return tournament.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load tournament',
          message: 'Check your connection and try again.',
        ),
      ),
      data: (t) => t == null
          ? Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Tournament not found',
                message: 'It may have been deleted by the organizer.',
              ),
            )
          : _TournamentView(tournament: t),
    );
  }
}

class _TournamentView extends ConsumerWidget {
  const _TournamentView({required this.tournament});

  final Tournament tournament;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tournament?'),
        content: Text(
          '"${tournament.name}" with all its teams, fixtures and scores will '
          'be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Grab everything we need before leaving this screen.
    final repository = ref.read(tournamentRepositoryProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    navigator.pop();
    try {
      await repository.deleteTournament(tournament.id);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete the tournament.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    final user = ref.watch(authStateProvider).valueOrNull;
    final isOwner = user != null && user.uid == t.ownerId;
    final topInset = MediaQuery.paddingOf(context).top;

    // Hosted tournaments give their organizer a Requests tab.
    final showRequests = t.isHosted && isOwner;
    final pending = showRequests
        ? (ref.watch(registrationsProvider(t.id)).valueOrNull ?? const [])
            .where((r) => r.isPending)
            .length
        : 0;

    final isKnockout = t.format == TournamentFormat.knockout;

    final tabs = <Tab>[
      const Tab(text: 'Overview'),
      if (showRequests)
        Tab(text: pending > 0 ? 'Requests ($pending)' : 'Requests'),
      Tab(text: 'Teams (${t.teamCount})'),
      const Tab(text: 'Fixtures'),
      Tab(text: isKnockout ? 'Bracket' : 'Table'),
    ];
    final scrollable = tabs.length > 3;

    return DefaultTabController(
      key: ValueKey(tabs.length),
      length: tabs.length,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 232,
              backgroundColor: t.sport.colorDark,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Text(
                t.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                if (isOwner)
                  PopupMenuButton<String>(
                    iconColor: Colors.white,
                    onSelected: (value) {
                      if (value == 'delete') _confirmDelete(context, ref);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete tournament'),
                      ),
                    ],
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: t.sport.gradient),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    topInset + kToolbarHeight + 8,
                    20,
                    kTextTabBarHeight + 12,
                  ),
                  child: _Header(tournament: t),
                ),
              ),
              bottom: TabBar(
                isScrollable: scrollable,
                tabAlignment:
                    scrollable ? TabAlignment.start : TabAlignment.fill,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                tabs: tabs,
              ),
            ),
          ],
          body: TabBarView(
            children: [
              OverviewTab(tournament: t, isOwner: isOwner),
              if (showRequests) RegistrationsTab(tournament: t),
              TeamsTab(tournament: t, isOwner: isOwner),
              FixturesTab(tournament: t, isOwner: isOwner),
              if (isKnockout)
                BracketTab(tournament: t)
              else
                StandingsTab(tournament: t),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    Widget meta(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusPill(status: t.status, onGradient: true),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${t.sport.label}  •  ${t.format.label}  •  ${t.kind.label}',
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            meta(Icons.calendar_today_rounded, formatDate(t.startDate)),
            if (t.venue.isNotEmpty) meta(Icons.place_rounded, t.venue),
            meta(Icons.person_rounded, t.ownerName.isEmpty
                ? 'Organizer'
                : t.ownerName),
          ],
        ),
      ],
    );
  }
}
