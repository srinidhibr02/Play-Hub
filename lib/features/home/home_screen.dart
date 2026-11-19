import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/navigation/app_route.dart';
import 'package:play_hub/features/home/join_by_code.dart';
import 'package:play_hub/features/home/mine_tab.dart';
import 'package:play_hub/features/home/profile_tab.dart';
import 'package:play_hub/features/home/tournaments_tab.dart';
import 'package:play_hub/features/tournament/create/create_tournament_screen.dart';
import 'package:play_hub/providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  void _createTournament() {
    Navigator.of(context).push(appRoute(const CreateTournamentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final firstName = (user?.displayName?.trim().split(' ').first) ?? '';
    final greeting = firstName.isEmpty ? 'My tournaments' : 'Hi, $firstName';

    final tabs = <Widget>[
      MineTab(
        key: const ValueKey('mine'),
        greeting: greeting,
        onCreate: _createTournament,
      ),
      TournamentsTab(
        key: const ValueKey('discover'),
        watch: (ref) => ref.watch(publicTournamentsProvider),
        title: 'Discover',
        subtitle: 'Tournaments you can follow or join',
        emptyTitle: 'Nothing to discover yet',
        emptyMessage:
            'Tournaments that organizers list publicly will show up here. '
            'Have an invite code? Tap Join.',
        trailing: const JoinByCodeButton(),
      ),
      const ProfileTab(key: ValueKey('profile')),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          child: tabs[_index],
        ),
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _createTournament,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New tournament'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded),
            label: 'Mine',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
