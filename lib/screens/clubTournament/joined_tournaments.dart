import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/screens/clubTournament/tournament_details_screen.dart';
import 'package:play_hub/screens/clubTournament/tournament_info_screen.dart';

class JoinedTournaments extends StatefulWidget {
  const JoinedTournaments({super.key});

  @override
  State<JoinedTournaments> createState() => _JoinedTournamentsState();
}

class _JoinedTournamentsState extends State<JoinedTournaments> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _joinedTournaments = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, upcoming, completed

  @override
  void initState() {
    super.initState();
    _fetchJoinedTournaments();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchJoinedTournaments() async {
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final userId = _authService.currentUserEmailId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('📥 Fetching joined tournaments for user: $userId');

      // Get user document to fetch joinedTournaments array
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found for: $userId');
        if (mounted) {
          setState(() {
            _joinedTournaments = [];
            _isLoading = false;
          });
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final joinedTournamentIds = List<String>.from(
        userData['joinedTournaments'] ?? [],
      );

      debugPrint('Found ${joinedTournamentIds.length} joined tournaments');

      final tournaments = <Map<String, dynamic>>[];

      // Fetch each tournament
      for (final tournamentId in joinedTournamentIds) {
        try {
          final tournamentDoc = await _firestore
              .collection('tournaments')
              .doc(tournamentId)
              .get();

          if (!tournamentDoc.exists) {
            debugPrint('⚠️ Tournament $tournamentId not found');
            continue;
          }

          final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
          final clubId = tournamentData['clubId'] as String?;

          // Fetch club data if available
          Map<String, dynamic>? clubData;
          if (clubId != null) {
            final clubDoc = await _firestore
                .collection('clubs')
                .doc(clubId)
                .get();
            if (clubDoc.exists) {
              clubData = clubDoc.data() as Map<String, dynamic>;
            }
          }

          final merged = {
            'id': tournamentId,
            ...tournamentData,
            if (clubData != null) 'club': clubData,
          };

          tournaments.add(merged);
          debugPrint('✅ Tournament: ${merged['name'] ?? 'Unknown'}');
        } catch (e) {
          debugPrint('⚠️ Error processing tournament $tournamentId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _joinedTournaments = tournaments;
          _isLoading = false;
        });
      }

      debugPrint('✅ Fetched ${tournaments.length} joined tournaments');
    } catch (e) {
      debugPrint('❌ Error fetching joined tournaments: $e');
      if (mounted) {
        setState(() {
          _joinedTournaments = [];
          _isLoading = false;
        });

        _showErrorSnackBar('Error fetching tournaments: $e');
      }
    }
  }

  Future<void> _joinTournament(
    BuildContext context,
    String tournamentId,
  ) async {
    try {
      final userId = _authService.currentUserEmailId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if tournament exists
      final tournamentDoc = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .get();

      if (!tournamentDoc.exists) {
        throw Exception('Tournament not found. Please check the ID.');
      }

      // Check if user already joined
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final joinedTournaments = List<String>.from(
        userData['joinedTournaments'] ?? [],
      );

      if (joinedTournaments.contains(tournamentId)) {
        throw Exception('You have already joined this tournament.');
      }

      // Add tournament to user's joined tournaments
      joinedTournaments.add(tournamentId);
      await _firestore.collection('users').doc(userId).update({
        'joinedTournaments': joinedTournaments,
      });

      // Add user to tournament's participants
      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('participants')
          .doc(userId)
          .set({
            'userId': userId,
            'joinedAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      // Close dialog if still mounted
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      _showSuccessSnackBar('Successfully joined tournament!');

      // Refresh the list
      await _fetchJoinedTournaments();
    } catch (e) {
      debugPrint('❌ Error joining tournament: $e');

      if (context.mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// ✅ FIXED: Create dialog with proper StatefulBuilder and controller lifecycle
  Future<void> _showJoinTournamentDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _JoinTournamentDialog(
          onJoin: (tournamentId) async {
            await _joinTournament(dialogContext, tournamentId);
          },
        );
      },
    );
  }

  bool _isUpcoming(Map<String, dynamic> tournament) {
    final dateField = tournament['date'];
    if (dateField == null) return false;

    try {
      DateTime date;

      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else {
        return false;
      }

      return date.isAfter(DateTime.now());
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _getFilteredTournaments() {
    if (_filterStatus == 'all') {
      return _joinedTournaments;
    } else if (_filterStatus == 'upcoming') {
      return _joinedTournaments.where((t) => _isUpcoming(t)).toList();
    } else {
      return _joinedTournaments.where((t) => !_isUpcoming(t)).toList();
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  int _to12Hour(int hour24) => hour24 == 0
      ? 12
      : hour24 > 12
      ? hour24 - 12
      : hour24;

  String _getAmPm(int hour24) => hour24 >= 12 ? 'PM' : 'AM';

  Future<void> _shareTournament(Map<String, dynamic> tournament) async {
    final tournamentId = tournament['id'] as String? ?? '';
    final tournamentName = tournament['name'] as String? ?? 'Tournament';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Tournament'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this tournament ID with friends:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                tournamentId,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tournament: $tournamentName',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showSuccessSnackBar('Copied to clipboard!');
            },
            icon: const Icon(Icons.copy, size: 18, color: Colors.white),
            label: const Text('Copy ID', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    final tournamentName = tournament['name'] as String? ?? 'Tournament';
    final club = tournament['club'] as Map<String, dynamic>? ?? {};
    final clubName = club['name'] as String? ?? 'Unknown Club';
    final dateField = tournament['date'];
    final isUpcoming = _isUpcoming(tournament);
    final tournamentId = tournament['id'] as String? ?? 'N/A';

    // Parse date and time from Timestamp
    String formattedDateTime = 'Date TBA';
    try {
      DateTime date;

      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else {
        date = DateTime.now();
      }

      final day = date.day.toString().padLeft(2, '0');
      final month = _getMonthAbbr(date.month);
      final year = date.year;
      final hour12 = _to12Hour(date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = _getAmPm(date.hour);

      formattedDateTime = '$day-$month-$year, $hour12:$minute $amPm';
    } catch (e) {
      debugPrint('Error parsing date: $e');
      formattedDateTime = 'Invalid Date';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.05).toInt()),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TournamentDetailsScreen(
                    tournamentId: tournament['id'] as String,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tournamentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              clubName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isUpcoming
                              ? Colors.blue.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUpcoming
                                ? Colors.blue.shade300
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          isUpcoming ? 'Upcoming' : 'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: isUpcoming
                                ? Colors.blue.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tournament ID Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number_rounded,
                          size: 14,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ID: $tournamentId',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        // Share Button
                        IconButton(
                          onPressed: () => _shareTournament(tournament),
                          icon: Icon(
                            Icons.share_rounded,
                            color: Colors.teal.shade600,
                            size: 20,
                          ),
                          tooltip: 'Share Tournament',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date and Time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          formattedDateTime,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tournament Format
                  if (tournament['format'] != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 18,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Format',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                tournament['format'] as String? ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text(
                        'Tournament Info',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => TournamentInfoScreen(
                              tournamentId: tournament['id'] as String,
                              tournamentName: tournamentName,
                              startDate: tournament['date'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.teal.withAlpha((255 * 0.3).toInt()),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.05).toInt()),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 18,
                width: 200,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.only(bottom: 8),
              ),
              Container(
                height: 14,
                width: 150,
                color: Colors.grey.shade200,
                margin: const EdgeInsets.only(bottom: 16),
              ),
              Row(
                children: [
                  Container(
                    height: 18,
                    width: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 15,
                    width: 120,
                    color: Colors.grey.shade200,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 50,
                width: double.infinity,
                color: Colors.grey.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((255 * 0.1).toInt()),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.group_add_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Joined Tournaments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Join tournaments by entering their tournament ID. Ask friends for their tournament ID or create your own!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTournaments = _getFilteredTournaments();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header with Title and Join Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Joined Tournaments',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100.withOpacity(0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.teal.shade300.withOpacity(0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.shade300.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Material(
                          color: Colors.teal.shade600.withOpacity(0.15),
                          child: InkWell(
                            onTap: _showJoinTournamentDialog,
                            borderRadius: BorderRadius.circular(20),
                            splashColor: Colors.teal.shade400.withOpacity(0.4),
                            highlightColor: Colors.teal.shade300.withOpacity(
                              0.2,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.share_rounded,
                                color: Colors.teal.shade700,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Filter Chips
                if (_joinedTournaments.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All',
                          value: 'all',
                          isSelected: _filterStatus == 'all',
                          onTap: () {
                            setState(() => _filterStatus = 'all');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Upcoming',
                          value: 'upcoming',
                          isSelected: _filterStatus == 'upcoming',
                          onTap: () {
                            setState(() => _filterStatus = 'upcoming');
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Completed',
                          value: 'completed',
                          isSelected: _filterStatus == 'completed',
                          onTap: () {
                            setState(() => _filterStatus = 'completed');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Tournaments List
          Expanded(
            child: _isLoading
                ? _buildLoadingShimmer()
                : filteredTournaments.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchJoinedTournaments,
                    color: Colors.teal.shade700,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredTournaments.length,
                      itemBuilder: (context, index) =>
                          _buildTournamentCard(filteredTournaments[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// ✅ NEW: Separate widget for join tournament dialog
/// This prevents TextEditingController disposal issues
class _JoinTournamentDialog extends StatefulWidget {
  final Future<void> Function(String tournamentId) onJoin;

  const _JoinTournamentDialog({required this.onJoin});

  @override
  State<_JoinTournamentDialog> createState() => _JoinTournamentDialogState();
}

class _JoinTournamentDialogState extends State<_JoinTournamentDialog> {
  late TextEditingController _tournamentIdController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _tournamentIdController = TextEditingController();
  }

  @override
  void dispose() {
    _tournamentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline, color: Colors.teal),
          SizedBox(width: 12),
          Text('Join Tournament'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter the Tournament ID to join',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tournamentIdController,
            enabled: !_isJoining,
            decoration: InputDecoration(
              labelText: 'Tournament ID',
              hintText: 'e.g., tournament_123',
              prefixIcon: const Icon(Icons.confirmation_number),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isJoining ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isJoining ? null : _handleJoin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isJoining
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text('Join'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Future<void> _handleJoin() async {
    final tournamentId = _tournamentIdController.text.trim();

    if (tournamentId.isEmpty) {
      return;
    }

    setState(() => _isJoining = true);

    try {
      await widget.onJoin(tournamentId);
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }
}
