import 'package:flutter/material.dart';

import 'package:play_hub/models/sport.dart';
import 'package:play_hub/models/team.dart';

/// Mid-dark colours that keep white text readable.
const List<int> teamPalette = [
  0xFFE11D48,
  0xFFEA580C,
  0xFFD97706,
  0xFF16A34A,
  0xFF0D9488,
  0xFF0284C7,
  0xFF4F46E5,
  0xFF9333EA,
  0xFFDB2777,
  0xFF475569,
];

int paletteColor(int index) => teamPalette[index % teamPalette.length];

/// Opens the add/edit sheet. Returns the team, or null if dismissed.
Future<Team?> showTeamEditor(
  BuildContext context, {
  required Sport sport,
  required List<Team> existing,
  Team? initial,
}) {
  return showModalBottomSheet<Team>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => TeamEditorSheet(
      sport: sport,
      existing: existing,
      initial: initial,
    ),
  );
}

/// Opens a dialog to paste several team names, one per line. Returns the
/// trimmed, non-empty lines (or null if cancelled).
Future<List<String>?> showQuickAddDialog(
  BuildContext context, {
  required Sport sport,
  required int slotsLeft,
}) {
  final controller = TextEditingController();
  return showDialog<List<String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add several ${sport.participantNounPlural.toLowerCase()}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'One per line. You can add up to $slotsLeft more.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 6,
              maxLines: 10,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Falcons\nRoyal Strikers\nCity Warriors',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () {
            final names = controller.text
                .split('\n')
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty)
                .toList();
            Navigator.of(context).pop(names);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

class TeamEditorSheet extends StatefulWidget {
  const TeamEditorSheet({
    super.key,
    required this.sport,
    required this.existing,
    this.initial,
  });

  final Sport sport;
  final List<Team> existing;
  final Team? initial;

  @override
  State<TeamEditorSheet> createState() => _TeamEditorSheetState();
}

class _TeamEditorSheetState extends State<TeamEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _playersController;
  late int _colorValue;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _playersController = TextEditingController(
      text: initial?.players.join('\n') ?? '',
    );
    _colorValue = initial?.colorValue ?? paletteColor(widget.existing.length);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _playersController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    final duplicate = widget.existing.any(
      (t) =>
          t.id != widget.initial?.id &&
          t.name.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      setState(() => _error = 'Another entry already uses this name');
      return;
    }

    final players = _playersController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    Navigator.of(context).pop(
      Team(
        id: widget.initial?.id ?? '',
        name: name,
        shortName: Team.autoShortName(name),
        colorValue: _colorValue,
        players: players,
        seed: widget.initial?.seed ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noun = widget.sport.participantNoun;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit $noun' : 'Add $noun',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: '$noun name',
                errorText: _error,
                prefixIcon: const Icon(Icons.shield_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _playersController,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: widget.sport.playersHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Colour',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final value in teamPalette)
                  GestureDetector(
                    onTap: () => setState(() => _colorValue = value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _colorValue == value
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _colorValue == value
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: widget.sport.color,
              ),
              onPressed: _save,
              child: Text(_isEditing ? 'Save changes' : 'Add $noun'),
            ),
          ],
        ),
      ),
    );
  }
}
