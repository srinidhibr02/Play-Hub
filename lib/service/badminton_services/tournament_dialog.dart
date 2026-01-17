import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';

class TournamentDialogs {
  static void showShareDialog(
    BuildContext context,
    TournamentFirestoreService service,
    String? userEmail,
    String? tournamentId,
    Function(String)? showSuccess,
    Function(String)? showError,
  ) async {
    if (userEmail == null || tournamentId == null) return;
    if (!context.mounted) return;

    try {
      final shareCode = await service.createShareableLink(
        userEmail,
        tournamentId,
      );

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: true,
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
                      icon: const Icon(Icons.copy, color: Colors.orange),
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: shareCode),
                          );

                          if (context.mounted) {
                            // Show success feedback
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Code copied!'),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade600,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          showError?.call('Failed to copy code: $e');
                        }
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
        ),
      );
    } catch (e) {
      showError?.call('Failed to create share link: $e');
    }
  }

  static Future<void> showInfoDialog(
    BuildContext context,
    TournamentFirestoreService service,
    String? userEmail,
    String? format,
    String? teamType,
    String? tournamentId,
  ) async {
    if (tournamentId == null || userEmail == null) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => FutureBuilder<Map<String, dynamic>?>(
        future: service.getTournament(userEmail, tournamentId),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.orange.shade600),
                  const SizedBox(height: 16),
                  const Text('Loading tournament info...'),
                ],
              ),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade600),
                  const SizedBox(width: 12),
                  const Text('Error'),
                ],
              ),
              content: Text(
                'Failed to load tournament info: ${snapshot.error}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          // No data
          if (!snapshot.hasData || snapshot.data == null) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade600),
                  const SizedBox(width: 12),
                  const Text('Tournament Info'),
                ],
              ),
              content: const Text('Tournament not found'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          // Data loaded - extract stats
          final tournamentData = snapshot.data!;
          final stats = tournamentData['stats'] as Map<String, dynamic>? ?? {};
          final totalMatches = stats['totalMatches'] ?? 0;
          final totalTeams = stats['totalTeams'] ?? 0;
          final completedMatches = stats['completedMatches'] ?? 0;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                const SizedBox(height: 12),
                _infoRow('Team Type', teamType ?? 'Singles'),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text(
                  'Tournament Stats',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow('Total Teams', totalTeams.toString()),
                const SizedBox(height: 8),
                _infoRow('Total Matches', totalMatches.toString()),
                const SizedBox(height: 8),
                _infoRow('Completed Matches', completedMatches.toString()),
                const SizedBox(height: 8),
                _infoRow(
                  'Remaining Matches',
                  (totalMatches - completedMatches).toString(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper widget for info rows
  static Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.orange.shade600,
          ),
        ),
      ],
    );
  }

  static Future<PlayoffChoice?> showPlayoffOptionsDialog(
    BuildContext context,
    int teamCount,
  ) async {
    return showDialog<PlayoffChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber.shade600),
            const SizedBox(width: 12),
            const Text('Playoff Options'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have $teamCount teams. How would you like to proceed?',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            _buildPlayoffOption(
              icon: Icons.flash_on,
              title: 'Direct Final',
              subtitle: 'Top 2 teams play the final',
              onTap: () => Navigator.pop(context, PlayoffChoice.directFinal),
            ),
            const SizedBox(height: 16),
            _buildPlayoffOption(
              icon: Icons.stairs,
              title: 'Semis & Final',
              subtitle: 'Top 4 teams battle for semis & final',
              onTap: () => Navigator.pop(context, PlayoffChoice.semisAndFinal),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPlayoffOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.amber.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.amber.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

enum PlayoffChoice { directFinal, semisAndFinal }
