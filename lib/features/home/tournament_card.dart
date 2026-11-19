import 'package:flutter/material.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/pressable_scale.dart';
import 'package:play_hub/core/widgets/status_pill.dart';
import 'package:play_hub/models/tournament.dart';

class TournamentCard extends StatelessWidget {
  const TournamentCard({
    super.key,
    required this.tournament,
    required this.onTap,
  });

  final Tournament tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tournament;

    return PressableScale(
      onTap: onTap,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(gradient: t.sport.gradient),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(t.sport.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.sport.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          t.format.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(status: t.status, onGradient: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Tags(tournament: t),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _Meta(
                        icon: Icons.groups_rounded,
                        text: pluralize(t.teamCount, 'team'),
                      ),
                      _Meta(
                        icon: Icons.calendar_today_rounded,
                        text: formatDate(t.startDate),
                      ),
                      if (t.venue.isNotEmpty)
                        _Meta(icon: Icons.place_rounded, text: t.venue),
                    ],
                  ),
                  if (t.hasFixtures) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: t.progress,
                              minHeight: 6,
                              color: t.sport.color,
                              backgroundColor:
                                  t.sport.color.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${t.completedCount}/${t.matchCount} played',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Friendly / Hosted label plus, for hosted tournaments, whether people can
/// still register and what it costs.
class _Tags extends StatelessWidget {
  const _Tags({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final tags = <Widget>[
      _Tag(
        label: t.kind.label,
        icon: t.isHosted ? Icons.campaign_outlined : Icons.bolt_rounded,
        color: t.sport.color,
      ),
      if (t.isHosted && t.canRegister(now))
        const _Tag(
          label: 'Registration open',
          icon: Icons.how_to_reg_outlined,
          color: Color(0xFF16A34A),
        ),
      if (t.isHosted && !t.hasFixtures && t.registrationOpen && t.isFull)
        const _Tag(
          label: 'Full',
          icon: Icons.block_rounded,
          color: Color(0xFFD97706),
        ),
      if (t.isHosted)
        _Tag(
          label: t.hasEntryFee ? formatRupees(t.entryFee) : 'Free entry',
          icon: Icons.currency_rupee_rounded,
          color: scheme.onSurfaceVariant,
        ),
    ];

    return Wrap(spacing: 8, runSpacing: 6, children: tags);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
