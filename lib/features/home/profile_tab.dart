import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/theme/app_theme.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).valueOrNull;
    final mine = ref.watch(myTournamentsProvider).valueOrNull ?? const [];

    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Organizer');
    final photo = user?.photoURL;

    final live = mine.where((t) => t.status == TournamentStatus.live).length;
    final done =
        mine.where((t) => t.status == TournamentStatus.completed).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Center(
          child: CircleAvatar(
            radius: 46,
            backgroundColor: AppTheme.brand,
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
        ).entrance(),
        const SizedBox(height: 16),
        Text(
          name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ).entrance(index: 1),
        if (user?.email != null)
          Text(
            user!.email!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ).entrance(index: 1),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _StatTile(value: mine.length, label: 'Hosted')),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(value: live, label: 'Live now')),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(value: done, label: 'Completed')),
          ],
        ).entrance(index: 2),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    AppTheme.logoOnWhite,
                    width: 44,
                    height: 44,
                  ),
                ),
                title: const Text('Play Hub'),
                subtitle: const Text('Sports Event & Tournament Manager'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Play Hub',
                  applicationIcon: Image.asset(
                    AppTheme.logoOnWhite,
                    width: 64,
                    height: 64,
                  ),
                  children: const [
                    Text(
                      'Host and track local badminton, cricket and football '
                      'tournaments.',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                title: Text(
                  'Sign out',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => ref.read(authServiceProvider).signOut(),
              ),
            ],
          ),
        ).entrance(index: 3),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
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
      ),
    );
  }
}
