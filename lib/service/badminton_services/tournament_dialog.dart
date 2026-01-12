import 'package:flutter/material.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';

class TournamentDialogs {
  static void showShareDialog(
    BuildContext context,
    TournamentFirestoreService service,
    String? userEmail,
    String? tournamentId,
    Function(String) showSuccess,
    Function(String) showError,
  ) async {
    if (userEmail == null || tournamentId == null) return;

    try {
      final shareCode = await service.createShareableLink(
        userEmail,
        tournamentId,
      );

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.share, color: Colors.orange.shade600),
              const SizedBox(width: 12),
              const Text('Share Tournament'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        shareCode,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.orange.shade600),
                      onPressed: () {
                        showSuccess('Code copied!');
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share this code with others. Valid for 30 days.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      showError('Failed to create share link: $e');
    }
  }

  static void showInfoDialog(
    BuildContext context,
    String? format,
    String? teamType,
    int? teamCount,
    int? matchDuration,
    int? breakDuration,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Tournament Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Format', format?.toUpperCase() ?? 'ROUND ROBIN'),
            _infoRow('Team Type', teamType ?? 'Singles'),
            _infoRow('Teams', '$teamCount'),
            _infoRow('Match Duration', '$matchDuration min'),
            _infoRow('Break Duration', '$breakDuration min'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
