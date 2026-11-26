import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:play_hub/logic/invite_code.dart';
import 'package:play_hub/models/tournament.dart';

/// Shows the invite code as a large QR code, handy to display on a phone or
/// screenshot for a poster. The QR holds the plain code, so any scanner shows
/// it and it can be typed into Play Hub's join screen.
Future<void> showInviteQrDialog(BuildContext context, Tournament t) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final code = InviteCode.format(t.inviteCode);
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: InviteCode.normalize(t.inviteCode),
                  size: 220,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: t.sport.colorDark,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: t.sport.colorDark,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                code,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Open Play Hub and enter this code to join.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
