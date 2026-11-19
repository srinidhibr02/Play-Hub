import 'package:flutter/material.dart';

import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/logic/payments.dart';
import 'package:play_hub/models/tournament.dart';

/// Bottom sheet to change the details that are safe to change after a
/// tournament exists. Sport, format, rules, capacity and fee are fixed
/// because teams, fixtures or payments may depend on them. Returns the
/// updated tournament, or null if dismissed.
Future<Tournament?> showEditTournamentSheet(
  BuildContext context,
  Tournament tournament,
) {
  return showModalBottomSheet<Tournament>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _EditSheet(tournament: tournament),
  );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.tournament});

  final Tournament tournament;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _venue;
  late final TextEditingController _description;
  late final TextEditingController _upi;
  late final TextEditingController _phone;
  late DateTime _startDate;
  late bool _isPublic;
  late bool _acceptCash;
  bool _submitted = false;

  Tournament get _t => widget.tournament;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _t.name);
    _venue = TextEditingController(text: _t.venue);
    _description = TextEditingController(text: _t.description);
    _upi = TextEditingController(text: _t.upiId);
    _phone = TextEditingController(text: _t.contactPhone);
    _startDate = _t.startDate;
    _isPublic = _t.isPublic;
    _acceptCash = _t.acceptCash;
  }

  @override
  void dispose() {
    _name.dispose();
    _venue.dispose();
    _description.dispose();
    _upi.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? get _nameError =>
      _name.text.trim().length >= 3 ? null : 'Use at least 3 characters';

  String? get _phoneError {
    if (!_t.isHosted) return null;
    return Payments.isValidPhone(_phone.text)
        ? null
        : 'Enter a phone number teams can reach you on';
  }

  String? get _paymentError {
    if (!_t.isHosted || !_t.hasEntryFee) return null;
    return Payments.validateFeeSetup(
      fee: _t.entryFee,
      upiId: _upi.text,
      acceptCash: _acceptCash,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = _startDate.isBefore(today) ? _startDate : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _save() {
    setState(() => _submitted = true);
    if (_nameError != null || _phoneError != null || _paymentError != null) {
      return;
    }
    Navigator.of(context).pop(
      _t.copyWith(
        name: _name.text.trim(),
        venue: _venue.text.trim(),
        description: _description.text.trim(),
        startDate: _startDate,
        isPublic: _isPublic,
        upiId: _t.hasEntryFee ? _upi.text.trim() : null,
        acceptCash: _t.hasEntryFee ? _acceptCash : null,
        contactPhone: _t.isHosted ? Payments.normalizePhone(_phone.text) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paymentError = _submitted ? _paymentError : null;

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
              'Edit details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sport, format, rules, capacity and entry fee are locked once a '
              'tournament is created.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Tournament name',
                errorText: _submitted ? _nameError : null,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _venue,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Venue',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.expand_more_rounded),
                ),
                child: Text(formatDate(_startDate)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              maxLength: 400,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              title: const Text(
                'List in Discover',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _isPublic
                    ? 'Anyone can find it in the Discover tab.'
                    : 'Unlisted. Only people with the invite code can find it.',
              ),
            ),
            if (_t.isHosted) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Contact phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _submitted ? _phoneError : null,
                ),
              ),
            ],
            if (_t.isHosted && _t.hasEntryFee) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _upi,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Your UPI ID',
                  hintText: 'name@bank',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptCash,
                onChanged: (v) => setState(() => _acceptCash = v),
                title: const Text(
                  'Accept cash',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (paymentError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    paymentError,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _t.sport.color,
              ),
              onPressed: _save,
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
