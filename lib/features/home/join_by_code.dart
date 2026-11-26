import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/navigation/app_route.dart';
import 'package:play_hub/core/utils/errors.dart';
import 'package:play_hub/features/home/scan_code_screen.dart';
import 'package:play_hub/features/tournament/detail/tournament_detail_screen.dart';
import 'package:play_hub/logic/invite_code.dart';
import 'package:play_hub/providers/providers.dart';

/// Small button for the home screens that opens the join dialog.
class JoinByCodeButton extends StatelessWidget {
  const JoinByCodeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      onPressed: () => showJoinByCodeDialog(context),
      icon: const Icon(Icons.pin_outlined, size: 18),
      label: const Text('Join'),
    );
  }
}

Future<void> showJoinByCodeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _JoinDialog(),
  );
}

class _JoinDialog extends ConsumerStatefulWidget {
  const _JoinDialog();

  @override
  ConsumerState<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends ConsumerState<_JoinDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      appRoute(const ScanCodeScreen()),
    );
    if (code == null || !mounted) return;
    _controller.text = InviteCode.format(code);
    await _submit();
  }

  Future<void> _submit() async {
    final input = _controller.text;
    if (!InviteCode.isValid(input)) {
      setState(() => _error = 'Codes have ${InviteCode.length} letters or '
          'numbers, like K7M-2QX.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id =
          await ref.read(tournamentRepositoryProvider).findTournamentIdByCode(
                input,
              );
      if (!mounted) return;
      if (id == null) {
        setState(() {
          _busy = false;
          _error = 'No tournament found with that code. Check it and retry.';
        });
        return;
      }
      // Grab the navigator before closing the dialog, then open the page.
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(appRoute(TournamentDetailScreen(tournamentId: id)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join with a code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the invite code the organizer shared with you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _submit(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
              LengthLimitingTextInputFormatter(8),
            ],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'K7M-2QX',
              suffixIcon: IconButton(
                tooltip: 'Scan QR code',
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: _busy ? null : _scan,
              ),
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Find'),
        ),
      ],
    );
  }
}
