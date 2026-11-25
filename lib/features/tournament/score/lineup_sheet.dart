import 'package:flutter/material.dart';

/// Pick the starting players for one side. Returns the chosen names (empty
/// list clears the lineup), or null if dismissed.
Future<List<String>?> showLineupSheet(
  BuildContext context, {
  required String teamName,
  required List<String> squad,
  required List<String> initial,
  required Color accent,
  int maxPlayers = 11,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _LineupSheet(
      teamName: teamName,
      squad: squad,
      initial: initial,
      accent: accent,
      maxPlayers: maxPlayers,
    ),
  );
}

class _LineupSheet extends StatefulWidget {
  const _LineupSheet({
    required this.teamName,
    required this.squad,
    required this.initial,
    required this.accent,
    required this.maxPlayers,
  });

  final String teamName;
  final List<String> squad;
  final List<String> initial;
  final Color accent;
  final int maxPlayers;

  @override
  State<_LineupSheet> createState() => _LineupSheetState();
}

class _LineupSheetState extends State<_LineupSheet> {
  late final List<String> _selected = [...widget.initial];
  final TextEditingController _extra = TextEditingController();

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  bool _has(String name) =>
      _selected.any((n) => n.toLowerCase() == name.trim().toLowerCase());

  bool get _full => _selected.length >= widget.maxPlayers;

  void _toggle(String name) {
    setState(() {
      if (_has(name)) {
        _selected.removeWhere((n) => n.toLowerCase() == name.toLowerCase());
      } else if (!_full) {
        _selected.add(name.trim());
      }
    });
  }

  void _addExtra() {
    final name = _extra.text.trim();
    if (name.isEmpty || _has(name) || _full) return;
    setState(() {
      _selected.add(name);
      _extra.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Players typed in earlier but not in the squad still show as chips.
    final extras = _selected
        .where((n) => !widget.squad.any((s) => s.toLowerCase() == n.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Starting lineup',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${widget.teamName} · ${_selected.length} of '
              '${widget.maxPlayers} selected',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (widget.squad.isEmpty && extras.isEmpty)
              Text(
                'This team has no squad list. Type the players below.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final name in widget.squad)
                  FilterChip(
                    label: Text(name),
                    selected: _has(name),
                    selectedColor: widget.accent.withValues(alpha: 0.2),
                    onSelected: (_) => _toggle(name),
                  ),
                for (final name in extras)
                  InputChip(
                    label: Text(name),
                    selected: true,
                    selectedColor: widget.accent.withValues(alpha: 0.2),
                    onDeleted: () => _toggle(name),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _extra,
                    enabled: !_full,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _addExtra(),
                    decoration: const InputDecoration(
                      labelText: 'Add another player',
                      prefixIcon: Icon(Icons.person_add_alt_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _full ? null : _addExtra,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Add',
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.accent),
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Save lineup'),
            ),
            if (_selected.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(context).pop(<String>[]),
                child: const Text('Clear lineup'),
              ),
          ],
        ),
      ),
    );
  }
}
