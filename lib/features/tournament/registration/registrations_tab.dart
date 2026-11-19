import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:play_hub/core/utils/errors.dart';
import 'package:play_hub/core/widgets/empty_state.dart';
import 'package:play_hub/core/widgets/entrance.dart';
import 'package:play_hub/models/registration.dart';
import 'package:play_hub/models/tournament.dart';
import 'package:play_hub/providers/providers.dart';

/// Organizer's view of everyone who asked to join a hosted tournament.
class RegistrationsTab extends ConsumerStatefulWidget {
  const RegistrationsTab({super.key, required this.tournament});

  final Tournament tournament;

  @override
  ConsumerState<RegistrationsTab> createState() => _RegistrationsTabState();
}

class _RegistrationsTabState extends ConsumerState<RegistrationsTab> {
  RegistrationStatus _filter = RegistrationStatus.pending;

  Tournament get _t => widget.tournament;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (success != null) _toast(success);
    } catch (e) {
      _toast(describeError(e));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 44),
              backgroundColor: destructive
                  ? Theme.of(context).colorScheme.error
                  : _t.sport.color,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _approve(Registration r) async {
    if (_t.hasEntryFee && r.owesFee) {
      final ok = await _confirm(
        title: 'Approve without payment?',
        message: '${r.teamName} has not been marked as paid yet. You can '
            'still approve them and confirm the payment later.',
        action: 'Approve',
      );
      if (!ok) return;
    }
    await _run(
      () => ref.read(tournamentRepositoryProvider).approveRegistration(
            tournamentId: _t.id,
            registrationId: r.id,
          ),
      success: '${r.teamName} approved.',
    );
  }

  Future<void> _reject(Registration r) async {
    final wasApproved = r.isApproved;
    final ok = await _confirm(
      title: wasApproved ? 'Remove ${r.teamName}?' : 'Reject ${r.teamName}?',
      message: wasApproved
          ? 'They will be taken out of the tournament.'
          : 'They will see that their registration was not accepted.',
      action: wasApproved ? 'Remove' : 'Reject',
      destructive: true,
    );
    if (!ok) return;
    await _run(
      () => ref.read(tournamentRepositoryProvider).rejectRegistration(
            tournamentId: _t.id,
            registrationId: r.id,
          ),
    );
  }

  Future<void> _setPayment(Registration r, PaymentStatus status) {
    return _run(
      () => ref.read(tournamentRepositoryProvider).setPaymentStatus(
            tournamentId: _t.id,
            registrationId: r.id,
            status: status,
          ),
    );
  }

  Future<void> _copyPhone(Registration r) async {
    await Clipboard.setData(ClipboardData(text: r.phone));
    _toast('Phone number copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registrations = ref.watch(registrationsProvider(_t.id));

    return registrations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load registrations',
        message: describeError(error),
        color: theme.colorScheme.error,
      ),
      data: (all) {
        int count(RegistrationStatus s) => all.where((r) => r.status == s).length;
        final visible = all.where((r) => r.status == _filter).toList();
        final pendingPayments = all
            .where(
              (r) =>
                  r.paymentStatus == PaymentStatus.submitted &&
                  !r.isRejected,
            )
            .length;

        return ListView(
          key: const PageStorageKey('registrations-list'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            if (_t.hasFixtures)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InfoBanner(
                  icon: Icons.lock_outline_rounded,
                  text: 'Fixtures are drawn, so teams can no longer be '
                      'approved or removed. Reset the fixtures to change '
                      'the line-up.',
                ),
              ),
            if (pendingPayments > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InfoBanner(
                  icon: Icons.payments_outlined,
                  color: const Color(0xFFF59E0B),
                  text: pendingPayments == 1
                      ? '1 team says it has paid. Check your UPI app or cash '
                          'and confirm it.'
                      : '$pendingPayments teams say they have paid. Check '
                          'your UPI app or cash and confirm each one.',
                ),
              ),
            SegmentedButton<RegistrationStatus>(
              showSelectedIcon: false,
              segments: [
                for (final s in RegistrationStatus.values)
                  ButtonSegment(
                    value: s,
                    label: Text('${s.label} (${count(s)})'),
                  ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) =>
                  setState(() => _filter = selection.first),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: EmptyState(
                  icon: Icons.how_to_reg_outlined,
                  color: _t.sport.color,
                  title: all.isEmpty
                      ? 'No registrations yet'
                      : 'No ${_filter.label.toLowerCase()} registrations',
                  message: all.isEmpty
                      ? 'Share the invite code from the Overview tab. Teams '
                          'that register will show up here.'
                      : 'Switch tabs above to see the others.',
                ),
              )
            else
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RegistrationTile(
                    tournament: _t,
                    registration: visible[i],
                    locked: _t.hasFixtures,
                    onApprove: () => _approve(visible[i]),
                    onReject: () => _reject(visible[i]),
                    onPayment: (status) => _setPayment(visible[i], status),
                    onCopyPhone: () => _copyPhone(visible[i]),
                  ).entrance(index: i),
                ),
          ],
        );
      },
    );
  }
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({
    required this.tournament,
    required this.registration,
    required this.locked,
    required this.onApprove,
    required this.onReject,
    required this.onPayment,
    required this.onCopyPhone,
  });

  final Tournament tournament;
  final Registration registration;
  final bool locked;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<PaymentStatus> onPayment;
  final VoidCallback onCopyPhone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = registration;
    final showPayment = tournament.hasEntryFee && !r.isRejected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.teamName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _Chip(
                  label: r.status.label,
                  color: switch (r.status) {
                    RegistrationStatus.pending => const Color(0xFFF59E0B),
                    RegistrationStatus.approved => const Color(0xFF16A34A),
                    RegistrationStatus.rejected => const Color(0xFFDC2626),
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onCopyPhone,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${r.userName}  |  ${r.phone}',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (r.players.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                r.players.join(', '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '"${r.note}"',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (showPayment) ...[
              const SizedBox(height: 12),
              _PaymentRow(registration: r, onPayment: onPayment),
            ],
            const SizedBox(height: 12),
            _Actions(
              registration: r,
              locked: locked,
              onApprove: onApprove,
              onReject: onReject,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.registration, required this.onPayment});

  final Registration registration;
  final ValueChanged<PaymentStatus> onPayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = registration;

    final color = switch (r.paymentStatus) {
      PaymentStatus.paid => const Color(0xFF16A34A),
      PaymentStatus.submitted => const Color(0xFFF59E0B),
      _ => theme.colorScheme.onSurfaceVariant,
    };

    final detail = [
      if (r.paymentMethod != null) r.paymentMethod!.label,
      if (r.paymentRef.isNotEmpty) 'Ref ${r.paymentRef}',
    ].join('  |  ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_rupee_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.paymentStatus.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (detail.isNotEmpty)
                  Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (r.paymentStatus == PaymentStatus.paid)
            TextButton(
              onPressed: () => onPayment(PaymentStatus.unpaid),
              child: const Text('Undo'),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: const Color(0xFF16A34A),
              ),
              onPressed: () => onPayment(PaymentStatus.paid),
              child: Text(
                r.paymentStatus == PaymentStatus.submitted
                    ? 'Confirm'
                    : 'Mark paid',
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.registration,
    required this.locked,
    required this.onApprove,
    required this.onReject,
  });

  final Registration registration;
  final bool locked;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final r = registration;

    final approve = Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: locked ? null : onApprove,
        child: Text(r.isRejected ? 'Approve anyway' : 'Approve'),
      ),
    );
    final reject = Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: error,
          side: BorderSide(color: locked ? Colors.transparent : error),
        ),
        onPressed: locked ? null : onReject,
        child: Text(r.isApproved ? 'Remove' : 'Reject'),
      ),
    );

    if (r.isPending) {
      return Row(children: [approve, const SizedBox(width: 10), reject]);
    }
    if (r.isApproved) return Row(children: [reject]);
    return Row(children: [approve]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
