import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/features/home/join_by_code.dart';
import 'package:play_hub/features/home/tournaments_tab.dart';
import 'package:play_hub/providers/providers.dart';

/// "Mine" tab: tournaments the user runs, and ones they registered for.
class MineTab extends ConsumerStatefulWidget {
  const MineTab({super.key, required this.greeting, required this.onCreate});

  final String greeting;
  final VoidCallback onCreate;

  @override
  ConsumerState<MineTab> createState() => _MineTabState();
}

class _MineTabState extends ConsumerState<MineTab> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final hosting = _segment == 0;

    return TournamentsTab(
      // A new key makes the list animate in again when switching.
      key: ValueKey('mine-$_segment'),
      watch: hosting
          ? (ref) => ref.watch(myTournamentsProvider)
          : (ref) => ref.watch(joinedTournamentsProvider),
      title: widget.greeting,
      subtitle: hosting
          ? 'Tournaments you run'
          : 'Tournaments you registered for',
      emptyTitle: hosting ? 'No tournaments yet' : 'Nothing registered yet',
      emptyMessage: hosting
          ? 'Create a friendly tournament in a minute, or host one with '
              'invites and registration.'
          : 'Join a hosted tournament with an invite code, or find one in '
              'Discover.',
      onCreate: hosting ? widget.onCreate : null,
      trailing: const JoinByCodeButton(),
      headerExtra: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Hosting'),
            icon: Icon(Icons.emoji_events_outlined),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Registered'),
            icon: Icon(Icons.how_to_reg_outlined),
          ),
        ],
        selected: {_segment},
        onSelectionChanged: (selection) =>
            setState(() => _segment = selection.first),
      ),
    );
  }
}
