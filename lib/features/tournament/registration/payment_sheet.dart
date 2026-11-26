import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:play_hub/core/utils/errors.dart';
import 'package:play_hub/core/utils/formatters.dart';
import 'package:play_hub/logic/payments.dart';
import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

/// Bottom sheet where a team sees how to pay the entry fee and tells the
/// organizer that it has paid.
Future<void> showPaymentSheet(BuildContext context, Tournament tournament) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => PaymentSheet(tournament: tournament),
  );
}

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.tournament});

  final Tournament tournament;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _refController = TextEditingController();
  bool _busy = false;
  String? _refError;

  Tournament get _t => widget.tournament;
  bool get _hasUpi => _t.upiId.trim().isNotEmpty;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what copied')));
  }

  /// Opens the person's UPI app with the payee, amount and note filled in.
  /// Paying still happens in that app; the team comes back and taps
  /// "I've paid" afterwards.
  Future<void> _openUpiApp() async {
    final link = Payments.upiPayLink(
      upiId: _t.upiId,
      payeeName: _t.payeeName.isNotEmpty ? _t.payeeName : _t.ownerName,
      amount: _t.entryFee,
      note: '${_t.name} entry',
    );
    var opened = false;
    if (link != null) {
      try {
        opened = await launchUrl(
          Uri.parse(link),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open a UPI app. Copy the UPI ID and pay from your '
              'app instead.',
            ),
          ),
        );
    }
  }

  Future<void> _submit(PaymentMethod method) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    if (method == PaymentMethod.upi &&
        !Payments.isValidReference(_refController.text)) {
      setState(
        () => _refError = 'Use the 12-digit UPI reference, letters and '
            'numbers only.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _refError = null;
    });
    try {
      await ref.read(tournamentRepositoryProvider).submitPayment(
            tournamentId: _t.id,
            uid: user.uid,
            method: method,
            reference: method == PaymentMethod.upi ? _refController.text : '',
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Sent. The organizer will confirm your payment.'),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _t.sport.color;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pay entry fee',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupees(_t.entryFee),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            if (_hasUpi) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay by UPI',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _t.upiId,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy UPI ID',
                          onPressed: () => _copy(_t.upiId, 'UPI ID'),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _openUpiApp,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text('Pay ${formatRupees(_t.entryFee)} in UPI app'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Open any UPI app, send ${formatRupees(_t.entryFee)} to '
                      'this ID, then enter the reference number below.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _refController,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'UPI reference (optional)',
                        errorText: _refError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: color),
                      onPressed:
                          _busy ? null : () => _submit(PaymentMethod.upi),
                      child: const Text("I've paid by UPI"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_t.acceptCash)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _submit(PaymentMethod.cash),
                icon: const Icon(Icons.payments_outlined),
                label: const Text("I'll pay in cash"),
              ),
            if (_t.contactPhone.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Questions? Call the organizer on ${_t.contactPhone}.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
