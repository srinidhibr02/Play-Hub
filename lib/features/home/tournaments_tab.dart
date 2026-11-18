import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/navigation/app_route.dart';
import 'package:play_hub/core/widgets/empty_state.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/features/home/tournament_card.dart';
import 'package:play_hub/features/tournament/detail/tournament_detail_screen.dart';
import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

/// A filterable list of tournaments, used for both "My tournaments" and
/// "Discover".
class TournamentsTab extends ConsumerWidget {
  const TournamentsTab({
    super.key,
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptyMessage,
    this.onCreate,
  });

  final AutoDisposeStreamProvider<List<Tournament>> provider;
  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptyMessage;

  /// When set, the empty state offers a "create" button.
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tournaments = ref.watch(provider);
    final filter = ref.watch(sportFilterProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ).entrance(),
        ),
        SliverToBoxAdapter(child: _SportFilterBar(selected: filter)),
        ...tournaments.when(
          loading: () => <Widget>[
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, stack) => <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load tournaments',
                message:
                    'Check your connection. If this keeps happening, make sure '
                    'the Firestore rules in firestore.rules are deployed.',
                color: theme.colorScheme.error,
              ),
            ),
          ],
          data: (items) {
            final visible = filter == null
                ? items
                : items.where((t) => t.sport == filter).toList();

            if (visible.isEmpty) {
              final filtered = filter != null && items.isNotEmpty;
              return <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: filtered
                        ? Icons.filter_alt_off_rounded
                        : Icons.emoji_events_outlined,
                    title: filtered
                        ? 'No ${filter?.label ?? ''} tournaments'
                        : emptyTitle,
                    message: filtered
                        ? 'Try another sport, or clear the filter.'
                        : emptyMessage,
                    actionLabel: filtered ? null : 'Create tournament',
                    onAction: filtered ? null : onCreate,
                  ),
                ),
              ];
            }

            return <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final tournament = visible[index];
                    return TournamentCard(
                      tournament: tournament,
                      onTap: () => Navigator.of(context).push(
                        appRoute(
                          TournamentDetailScreen(tournamentId: tournament.id),
                        ),
                      ),
                    ).entrance(index: index);
                  },
                ),
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _SportFilterBar extends ConsumerWidget {
  const _SportFilterBar({required this.selected});

  final Sport? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(sportFilterProvider.notifier);

    Widget chip({
      required String label,
      required bool isSelected,
      required Color color,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      return ChoiceChip(
        showCheckmark: false,
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: color,
        side: BorderSide(
          color: isSelected ? color : scheme.outlineVariant,
        ),
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : scheme.onSurfaceVariant,
              ),
        label: Text(label),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : scheme.onSurface,
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        children: [
          chip(
            label: 'All',
            isSelected: selected == null,
            color: scheme.primary,
            onTap: () => notifier.state = null,
          ),
          for (final sport in Sport.values) ...[
            const SizedBox(width: 8),
            chip(
              label: sport.label,
              icon: sport.icon,
              isSelected: selected == sport,
              color: sport.color,
              onTap: () => notifier.state = sport,
            ),
          ],
        ],
      ),
    );
  }
}
