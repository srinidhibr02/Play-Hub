import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:play_hub/logic/match_rules.dart';
import 'package:play_hub/models/scorecard_lines.dart';

Widget _sheetPadding(BuildContext context, Widget child) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(child: child),
    );

Widget _squadChips(
  List<String> squad,
  Set<String> taken,
  TextEditingController target,
  VoidCallback refresh,
) {
  final free = squad.where((n) => !taken.contains(n.toLowerCase())).toList();
  if (free.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final name in free)
          ActionChip(
            label: Text(name),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              target.text = name;
              refresh();
            },
          ),
      ],
    ),
  );
}

TextField _numberField(
  TextEditingController c,
  String label, {
  String? error,
  int maxLength = 3,
}) =>
    TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      decoration: InputDecoration(labelText: label, errorText: error),
    );

int _n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

// ======================================================================
// Batter
// ======================================================================

/// Add or edit one batter. [taken] holds names already on the card
/// (lower-case) so squad chips only offer players not yet listed.
Future<BatterLine?> showBatterSheet(
  BuildContext context, {
  required String teamName,
  required List<String> squad,
  required Set<String> taken,
  required Color accent,
  BatterLine? initial,
}) {
  return showModalBottomSheet<BatterLine>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _BatterSheet(
      teamName: teamName,
      squad: squad,
      taken: taken,
      accent: accent,
      initial: initial,
    ),
  );
}

class _BatterSheet extends StatefulWidget {
  const _BatterSheet({
    required this.teamName,
    required this.squad,
    required this.taken,
    required this.accent,
    this.initial,
  });

  final String teamName;
  final List<String> squad;
  final Set<String> taken;
  final Color accent;
  final BatterLine? initial;

  @override
  State<_BatterSheet> createState() => _BatterSheetState();
}

class _BatterSheetState extends State<_BatterSheet> {
  late final TextEditingController _name;
  late final TextEditingController _runs;
  late final TextEditingController _balls;
  late final TextEditingController _fours;
  late final TextEditingController _sixes;
  late final TextEditingController _how;
  late bool _out;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    String num(int? v) => (v == null || v == 0) ? '' : '$v';
    _name = TextEditingController(text: b?.name ?? '');
    _runs = TextEditingController(text: b == null ? '' : '${b.runs}');
    _balls = TextEditingController(text: num(b?.balls));
    _fours = TextEditingController(text: num(b?.fours));
    _sixes = TextEditingController(text: num(b?.sixes));
    _how = TextEditingController(text: b?.dismissal ?? '');
    _out = b?.out ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _runs, _balls, _fours, _sixes, _how]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError {
    final n = _name.text.trim();
    if (n.isEmpty) return 'Enter the batter';
    if (widget.taken.contains(n.toLowerCase())) return 'Already on the card';
    return null;
  }

  void _save() {
    setState(() => _submitted = true);
    if (_nameError != null) return;
    Navigator.of(context).pop(
      BatterLine(
        name: _name.text.trim(),
        runs: _n(_runs),
        balls: _n(_balls),
        fours: _n(_fours),
        sixes: _n(_sixes),
        out: _out,
        dismissal: _out ? _how.text.trim() : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _sheetPadding(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'Add batter' : 'Edit batter',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            widget.teamName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Batter',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              errorText: _submitted ? _nameError : null,
            ),
          ),
          _squadChips(widget.squad, widget.taken, _name, () => setState(() {})),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _numberField(_runs, 'Runs')),
              const SizedBox(width: 10),
              Expanded(child: _numberField(_balls, 'Balls')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numberField(_fours, 'Fours', maxLength: 2)),
              const SizedBox(width: 10),
              Expanded(child: _numberField(_sixes, 'Sixes', maxLength: 2)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _out,
            onChanged: (v) => setState(() => _out = v),
            title: const Text(
              'Got out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Leave off if not out.'),
          ),
          if (_out)
            TextField(
              controller: _how,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'How out (optional)',
                hintText: 'b Kiran, c Sam b Kiran, run out',
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
    );
  }
}

// ======================================================================
// Bowler
// ======================================================================

Future<BowlerLine?> showBowlerSheet(
  BuildContext context, {
  required String teamName,
  required List<String> squad,
  required Set<String> taken,
  required Color accent,
  BowlerLine? initial,
}) {
  return showModalBottomSheet<BowlerLine>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _BowlerSheet(
      teamName: teamName,
      squad: squad,
      taken: taken,
      accent: accent,
      initial: initial,
    ),
  );
}

class _BowlerSheet extends StatefulWidget {
  const _BowlerSheet({
    required this.teamName,
    required this.squad,
    required this.taken,
    required this.accent,
    this.initial,
  });

  final String teamName;
  final List<String> squad;
  final Set<String> taken;
  final Color accent;
  final BowlerLine? initial;

  @override
  State<_BowlerSheet> createState() => _BowlerSheetState();
}

class _BowlerSheetState extends State<_BowlerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _overs;
  late final TextEditingController _runs;
  late final TextEditingController _wickets;
  late final TextEditingController _maidens;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _name = TextEditingController(text: b?.name ?? '');
    _overs = TextEditingController(
      text: b == null ? '' : MatchRules.oversText(b.balls),
    );
    _runs = TextEditingController(text: b == null ? '' : '${b.runs}');
    _wickets = TextEditingController(text: b == null ? '' : '${b.wickets}');
    _maidens = TextEditingController(
      text: (b == null || b.maidens == 0) ? '' : '${b.maidens}',
    );
  }

  @override
  void dispose() {
    for (final c in [_name, _overs, _runs, _wickets, _maidens]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError {
    final n = _name.text.trim();
    if (n.isEmpty) return 'Enter the bowler';
    if (widget.taken.contains(n.toLowerCase())) return 'Already on the card';
    return null;
  }

  int? get _balls =>
      MatchRules.parseOvers(_overs.text.trim().isEmpty ? '0' : _overs.text);

  String? get _oversError => _balls == null
      ? 'Like 3.2 (an over has 6 balls, so after the dot use 0 to 5)'
      : null;

  void _save() {
    setState(() => _submitted = true);
    if (_nameError != null || _oversError != null) return;
    Navigator.of(context).pop(
      BowlerLine(
        name: _name.text.trim(),
        balls: _balls!,
        runs: _n(_runs),
        wickets: _n(_wickets),
        maidens: _n(_maidens),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _sheetPadding(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'Add bowler' : 'Edit bowler',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            widget.teamName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Bowler',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              errorText: _submitted ? _nameError : null,
            ),
          ),
          _squadChips(widget.squad, widget.taken, _name, () => setState(() {})),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _overs,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Overs',
                    hintText: '3.2',
                    errorText: _submitted ? _oversError : null,
                    errorMaxLines: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _numberField(_runs, 'Runs')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numberField(_wickets, 'Wickets', maxLength: 2)),
              const SizedBox(width: 10),
              Expanded(child: _numberField(_maidens, 'Maidens', maxLength: 2)),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: widget.accent),
            onPressed: _save,
            child: Text(widget.initial == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}
