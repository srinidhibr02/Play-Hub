import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/widgets/empty_state.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/features/tournament/detail/team_editor_sheet.dart';
import 'package:play_hub/models/team.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

class TeamsTab extends ConsumerWidget {
  const TeamsTab({super.key, required this.tournament, required this.isOwner});

  final Tournament tournament;
  final bool isOwner;

  bool get _canEdit => isOwner && !tournament.hasFixtures;

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addTeam(
    BuildContext context,
    WidgetRef ref,
    List<Team> existing,
  ) async {
    if (existing.length >= tournament.maxTeams) {
      _toast(context, 'This format supports up to ${tournament.maxTeams}.');
      return;
    }
    final team = await showTeamEditor(
      context,
      sport: tournament.sport,
      existing: existing,
    );
    if (team == null || !context.mounted) return;

    try {
      await ref
          .read(tournamentRepositoryProvider)
          .addTeams(tournament.id, [team], startSeed: existing.length);
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not add. Try again.');
    }
  }

  Future<void> _quickAdd(
    BuildContext context,
    WidgetRef ref,
    List<Team> existing,
  ) async {
    final slotsLeft = tournament.maxTeams - existing.length;
    if (slotsLeft <= 0) {
      _toast(context, 'This format supports up to ${tournament.maxTeams}.');
      return;
    }
    final names = await showQuickAddDialog(
      context,
      sport: tournament.sport,
      slotsLeft: slotsLeft,
    );
    if (names == null || names.isEmpty || !context.mounted) return;

    // Drop duplicates, both against existing entries and within the list.
    final seen = existing.map((t) => t.name.toLowerCase()).toSet();
    final fresh = <String>[];
    for (final name in names) {
      if (seen.add(name.toLowerCase())) fresh.add(name);
    }
    final skippedDuplicates = names.length - fresh.length;
    final accepted = fresh.take(slotsLeft).toList();
    final skippedOverLimit = fresh.length - accepted.length;

    if (accepted.isEmpty) {
      _toast(context, 'Nothing new to add.');
      return;
    }

    final teams = [
      for (var i = 0; i < accepted.length; i++)
        Team(
          id: '',
          name: accepted[i],
          shortName: Team.autoShortName(accepted[i]),
          colorValue: paletteColor(existing.length + i),
        ),
    ];

    try {
      await ref
          .read(tournamentRepositoryProvider)
          .addTeams(tournament.id, teams, startSeed: existing.length);
      if (!context.mounted) return;
      final notes = [
        if (skippedDuplicates > 0) '$skippedDuplicates duplicate(s) skipped',
        if (skippedOverLimit > 0) '$skippedOverLimit over the limit skipped',
      ];
      _toast(
        context,
        'Added ${accepted.length}.${notes.isEmpty ? '' : ' ${notes.join(', ')}.'}',
      );
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not add. Try again.');
    }
  }

  Future<void> _editTeam(
    BuildContext context,
    WidgetRef ref,
    List<Team> existing,
    Team team,
  ) async {
    final updated = await showTeamEditor(
      context,
      sport: tournament.sport,
      existing: existing,
      initial: team,
    );
    if (updated == null || !context.mounted) return;
    try {
      await ref
          .read(tournamentRepositoryProvider)
          .updateTeam(tournament.id, updated);
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not save. Try again.');
    }
  }

  Future<void> _deleteTeam(
    BuildContext context,
    WidgetRef ref,
    Team team,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${team.name}?'),
        content: const Text('This entry will be removed from the tournament.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(tournamentRepositoryProvider)
          .deleteTeam(tournament.id, team.id);
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not remove. Try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sport = tournament.sport;
    final teamsAsync = ref.watch(teamsProvider(tournament.id));

    return teamsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load teams',
        message: 'Check your connection and try again.',
      ),
      data: (teams) {
        return ListView(
          key: const PageStorageKey('teams-list'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            if (tournament.description.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: sport.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tournament.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).entrance(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${teams.length} of ${tournament.maxTeams} '
                    '${sport.participantNounPlural.toLowerCase()}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_canEdit) ...[
                  TextButton.icon(
                    onPressed: () => _quickAdd(context, ref, teams),
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: const Text('Quick add'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => _addTeam(context, ref, teams),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (isOwner && tournament.hasFixtures)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Entries are locked because fixtures have been '
                            'drawn. Reset the fixtures to make changes.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (teams.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: sport.icon,
                  color: sport.color,
                  title: 'No ${sport.participantNounPlural.toLowerCase()} yet',
                  message: isOwner
                      ? (tournament.isHosted
                          ? 'Teams appear here when you approve their '
                              'registrations. You can also add walk-ins '
                              'yourself.'
                          : 'Add the '
                              '${sport.participantNounPlural.toLowerCase()} '
                              'taking part, then draw the fixtures.')
                      : 'The organizer has not added any '
                          '${sport.participantNounPlural.toLowerCase()} yet.',
                  actionLabel:
                      _canEdit ? 'Add ${sport.participantNoun}' : null,
                  onAction:
                      _canEdit ? () => _addTeam(context, ref, teams) : null,
                ),
              )
            else
              for (var i = 0; i < teams.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TeamTile(
                    team: teams[i],
                    position: i + 1,
                    canEdit: _canEdit,
                    onEdit: () => _editTeam(context, ref, teams, teams[i]),
                    onDelete: () => _deleteTeam(context, ref, teams[i]),
                  ).entrance(index: i),
                ),
          ],
        );
      },
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.team,
    required this.position,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final Team team;
  final int position;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(team.colorValue);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                team.shortName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (team.players.isNotEmpty)
                    Text(
                      team.players.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '#$position',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (canEdit)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
