import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:play_hub/models/tournament_match.dart';

/// Bottom sheet to record one goal or card. Returns null if dismissed.
Future<MatchEvent?> showMatchEventSheet(
  BuildContext context, {
  required String teamAId,
  required String teamBId,
  required String nameA,
  required String nameB,
  required List<String> squadA,
  required List<String> squadB,
  required Color accent,
  MatchEvent? initial,
}) {
  return showModalBottomSheet<MatchEvent>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _EventSheet(
      teamAId: teamAId,
      teamBId: teamBId,
      nameA: nameA,
      nameB: nameB,
      squadA: squadA,
      squadB: squadB,
      accent: accent,
      initial: initial,
    ),
  );
}

class _EventSheet extends StatefulWidget {
  const _EventSheet({
    required this.teamAId,
    required this.teamBId,
    required this.nameA,
    required this.nameB,
    required this.squadA,
    required this.squadB,
    required this.accent,
    this.initial,
  });

  final String teamAId;
  final String teamBId;
  final String nameA;
  final String nameB;
  final List<String> squadA;
  final List<String> squadB;
  final Color accent;
  final MatchEvent? initial;

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late MatchEventType _type;
  late bool _sideA;
  late final TextEditingController _player;
  late final TextEditingController _assist;
  late final TextEditingController _off;
  late final TextEditingController _minute;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _type = e?.type ?? MatchEventType.goal;
    _sideA = e == null || e.teamId == widget.teamAId;
    _player = TextEditingController(text: e?.player ?? '');
    _assist = TextEditingController(text: e?.assist ?? '');
    _off = TextEditingController(text: e?.playerOff ?? '');
    _minute = TextEditingController(text: e?.minute?.toString() ?? '');
  }

  @override
  void dispose() {
    _player.dispose();
    _assist.dispose();
    _off.dispose();
    _minute.dispose();
    super.dispose();
  }

  List<String> get _squad => _sideA ? widget.squadA : widget.squadB;
  bool get _hasAssist => _type == MatchEventType.goal;
  bool get _isSub => _type == MatchEventType.substitution;

  String? get _playerError =>
      _player.text.trim().isEmpty ? 'Enter the player' : null;

  String? get _offError {
    if (!_isSub) return null;
    final off = _off.text.trim();
    if (off.isEmpty) return 'Enter the player going off';
    if (off.toLowerCase() == _player.text.trim().toLowerCase()) {
      return 'Must be a different player';
    }
    return null;
  }

  String? get _minuteError {
    final text = _minute.text.trim();
    if (text.isEmpty) return null;
    final m = int.tryParse(text);
    return (m == null || m < 1 || m > 150) ? 'Use 1 to 150' : null;
  }

  void _save() {
    setState(() => _submitted = true);
    if (_playerError != null || _offError != null || _minuteError != null) {
      return;
    }
    final assist = _hasAssist ? _assist.text.trim() : '';
    Navigator.of(context).pop(
      MatchEvent(
        type: _type,
        teamId: _sideA ? widget.teamAId : widget.teamBId,
        player: _player.text.trim(),
        // A player cannot assist their own goal.
        assist: assist.toLowerCase() == _player.text.trim().toLowerCase()
            ? ''
            : assist,
        playerOff: _isSub ? _off.text.trim() : '',
        minute: int.tryParse(_minute.text.trim()),
      ),
    );
  }

  Widget _squadChips(TextEditingController target) {
    if (_squad.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final name in _squad)
            ActionChip(
              label: Text(name),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => target.text = name),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownGoal = _type == MatchEventType.ownGoal;

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
              widget.initial == null ? 'Add event' : 'Edit event',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in MatchEventType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(widget.nameA)),
                ButtonSegment(value: false, label: Text(widget.nameB)),
              ],
              selected: {_sideA},
              onSelectionChanged: (v) => setState(() => _sideA = v.first),
            ),
            if (ownGoal)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Pick the team of the player who scored it. The goal counts '
                  'for the other side.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _player,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _isSub ? 'Player coming on' : 'Player',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                errorText: _submitted ? _playerError : null,
              ),
            ),
            _squadChips(_player),
            if (_isSub) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _off,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Player going off',
                  prefixIcon: const Icon(Icons.logout_rounded),
                  errorText: _submitted ? _offError : null,
                ),
              ),
              _squadChips(_off),
            ],
            if (_hasAssist) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _assist,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Assist (optional)',
                  prefixIcon: Icon(Icons.handshake_outlined),
                ),
              ),
              _squadChips(_assist),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _minute,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                labelText: 'Minute (optional)',
                prefixIcon: const Icon(Icons.timer_outlined),
                errorText: _submitted ? _minuteError : null,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: widget.accent),
              onPressed: _save,
              child: Text(widget.initial == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
