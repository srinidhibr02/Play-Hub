import 'package:flutter/material.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/models/tournament_match.dart';

/// What the organizer chose in the schedule sheet.
class ScheduleChoice {
  const ScheduleChoice({this.at, this.venue = ''});

  /// Null clears the time.
  final DateTime? at;
  final String venue;
}

/// Bottom sheet to set when and where a match is played. Returns null if
/// dismissed, otherwise the choice (a null time means "clear").
Future<ScheduleChoice?> showScheduleSheet(
  BuildContext context, {
  required TournamentMatch match,
  required String defaultVenue,
  required DateTime tournamentStart,
}) {
  return showModalBottomSheet<ScheduleChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ScheduleSheet(
      match: match,
      defaultVenue: defaultVenue,
      tournamentStart: tournamentStart,
    ),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({
    required this.match,
    required this.defaultVenue,
    required this.tournamentStart,
  });

  final TournamentMatch match;
  final String defaultVenue;
  final DateTime tournamentStart;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late DateTime? _date;
  late TimeOfDay? _time;
  late final TextEditingController _venue;

  @override
  void initState() {
    super.initState();
    final at = widget.match.scheduledAt;
    _date = at == null ? null : DateTime(at.year, at.month, at.day);
    _time = at == null ? null : TimeOfDay(hour: at.hour, minute: at.minute);
    _venue = TextEditingController(
      text: widget.match.venue.isNotEmpty
          ? widget.match.venue
          : widget.defaultVenue,
    );
  }

  @override
  void dispose() {
    _venue.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = widget.tournamentStart;
    final initial = _date ?? (start.isAfter(today) ? start : today);
    final first = initial.isBefore(today) ? initial : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final d = _date;
    final t = _time;
    // A date alone is stored as midday-neutral 00:00 would read as midnight,
    // so a time is required with a date.
    final at = (d == null || t == null)
        ? null
        : DateTime(d.year, d.month, d.day, t.hour, t.minute);
    Navigator.of(context).pop(ScheduleChoice(at: at, venue: _venue.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.match;
    final hasDate = _date != null;
    final hasTime = _time != null;
    final incomplete = hasDate != hasTime;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Schedule match',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${m.teamAName ?? 'TBD'} vs ${m.teamBName ?? 'TBD'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(hasDate ? formatDate(_date!) : 'Pick date'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(hasTime ? _time!.format(context) : 'Pick time'),
                  ),
                ),
              ],
            ),
            if (incomplete)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  hasDate
                      ? 'Pick a time too, or the date will not be saved.'
                      : 'Pick a date too, or the time will not be saved.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _venue,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Venue / ground / court (optional)',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
            if (m.scheduledAt != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(
                  ScheduleChoice(at: null, venue: _venue.text),
                ),
                child: const Text('Clear time'),
              ),
          ],
        ),
      ),
    );
  }
}
