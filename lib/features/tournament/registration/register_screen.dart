import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/utils/errors.dart';
import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/logic/payments.dart';
import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

/// Form a team fills in to register for a hosted tournament.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.tournament});

  final Tournament tournament;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamController = TextEditingController();
  final _playersController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  Tournament get _t => widget.tournament;

  @override
  void dispose() {
    _teamController.dispose();
    _playersController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    FocusScope.of(context).unfocus();

    final players = _playersController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      await ref.read(tournamentRepositoryProvider).submitRegistration(
            _t,
            Registration(
              id: user.uid,
              userId: user.uid,
              userName: user.displayName ?? user.email ?? 'Player',
              teamName: _teamController.text.trim(),
              phone: Payments.normalizePhone(_phoneController.text),
              players: players,
              note: _noteController.text.trim(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Registered! The organizer will review your team.'),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sport = _t.sport;
    final noun = sport.participantNoun;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Register',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _t.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeeBanner(tournament: _t).entrance(),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _teamController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '$noun name',
                        prefixIcon: const Icon(Icons.shield_outlined),
                      ),
                      validator: (value) => (value ?? '').trim().length < 2
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _playersController,
                      minLines: 2,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: '${sport.playersHint} (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Your phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) => Payments.isValidPhone(value ?? '')
                          ? null
                          : 'Enter a valid phone number',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _noteController,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note for the organizer (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your name and phone number are shared with the '
                      'organizer only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: sport.color),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit registration'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Explains the entry fee (or that there is none) before registering.
class _FeeBanner extends StatelessWidget {
  const _FeeBanner({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tournament;
    final color = t.sport.color;

    final text = t.hasEntryFee
        ? 'Entry fee: ${formatRupees(t.entryFee)} per team. After you '
            'register you can pay by ${Payments.describeOptions(t).toLowerCase()}.'
        : 'This tournament is free to enter.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.currency_rupee_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
