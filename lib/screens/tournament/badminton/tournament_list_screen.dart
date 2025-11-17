import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/screens/tournament/badminton/badminton_tournament_setup_screen.dart';
import 'package:play_hub/screens/tournament/badminton/tournament_schedule_screen.dart';
import 'package:play_hub/service/badminton_service.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final TournamentFirestoreService _firestoreService =
      TournamentFirestoreService();
  String _selectedFilter = 'all'; // all, active, singles, doubles, custom
  String? _userEmail;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    String? email = user?.email;

    setState(() {
      _userEmail = email; // Placeholder
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade600,
        elevation: 0,
        title: const Text(
          'My Tournaments',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              // Navigate to create tournament
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Tournaments')),
              const PopupMenuItem(value: 'active', child: Text('Active Only')),
              const PopupMenuItem(value: 'Singles', child: Text('Singles')),
              const PopupMenuItem(value: 'Doubles', child: Text('Doubles')),
              const PopupMenuItem(value: 'Custom', child: Text('Custom')),
            ],
          ),
        ],
      ),
      body: _userEmail == null
          ? Center(
              child: CircularProgressIndicator(color: Colors.orange.shade600),
            )
          : _buildTournamentList(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            // Create New Tournament FAB
            FloatingActionButton.extended(
              onPressed: () {
                setState(() => _isFabExpanded = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BadmintonTournamentSetupScreen(),
                  ),
                );
              },
              backgroundColor: Colors.blue.shade600,
              heroTag: 'createNew',
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create New',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Join with Code FAB
            FloatingActionButton.extended(
              onPressed: () {
                setState(() => _isFabExpanded = false);
                _showJoinTournamentDialog();
              },
              backgroundColor: Colors.green.shade600,
              heroTag: 'joinCode',
              icon: const Icon(Icons.vpn_key, color: Colors.white),
              label: const Text(
                'Join with Code',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Main FAB
          FloatingActionButton(
            onPressed: () {
              setState(() => _isFabExpanded = !_isFabExpanded);
            },
            backgroundColor: Colors.orange.shade600,
            heroTag: 'main',
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isFabExpanded ? Icons.close : Icons.add,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinTournamentDialog() {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Join Tournament'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Enter Share Code',
                hintText: 'e.g., abc123xyz',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.qr_code, color: Colors.orange.shade600),
              ),
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask the tournament creator for the share code',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String code = codeController.text.trim();
              if (code.isEmpty) return;

              Navigator.pop(context);
              await _joinTournamentWithCode(code);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _joinTournamentWithCode(String shareCode) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: Colors.orange.shade600),
        ),
      );

      // Get tournament via share code
      Map<String, dynamic>? tournament = await _firestoreService
          .getTournamentByShareCode(shareCode);

      Navigator.pop(context); // Close loading

      if (tournament == null) {
        _showError('Invalid or expired share code');
        return;
      }

      // Navigate to tournament (read-only mode)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BadmintonMatchScheduleScreen(
            tournamentId: shareCode, // Use share code as ID
            // Pass other necessary params
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showError('Failed to join tournament: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTournamentList() {
    Stream<List<Map<String, dynamic>>> stream;

    switch (_selectedFilter) {
      case 'active':
        stream = _firestoreService.getActiveTournaments(_userEmail!);
        break;
      case 'Singles':
      case 'Doubles':
      case 'Custom':
        stream = _firestoreService.getTournamentsByType(
          _userEmail!,
          _selectedFilter,
        );
        break;
      default:
        stream = _firestoreService.getUserTournaments(_userEmail!);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.orange.shade600),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading tournaments',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sports_tennis,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tournaments found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new tournament to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> tournaments = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tournaments.length,
          itemBuilder: (context, index) =>
              _buildTournamentCard(tournaments[index]),
        );
      },
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    String tournamentId = tournament['id'];
    String teamType = tournament['teamType'] ?? 'Unknown';
    String status = tournament['status'] ?? 'active';
    Map<String, dynamic> stats = tournament['stats'] ?? {};
    Map<String, dynamic> schedule = tournament['schedule'] ?? {};

    int totalMatches = stats['totalMatches'] ?? 0;
    int completedMatches = stats['completedMatches'] ?? 0;
    int totalTeams = stats['totalTeams'] ?? 0;

    Timestamp? createdAtTimestamp = tournament['createdAt'];
    DateTime? createdAt = createdAtTimestamp?.toDate();

    Timestamp? startDateTimestamp = schedule['startDate'];
    DateTime? startDate = startDateTimestamp?.toDate();

    Color statusColor = status == 'active'
        ? Colors.green
        : status == 'completed'
        ? Colors.blue
        : Colors.grey;

    return GestureDetector(
      onTap: () => _openTournament(tournamentId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade400],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTeamTypeIcon(teamType),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamType,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            'Created ${DateFormat('MMM d, yyyy').format(createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.people,
                          label: 'Teams',
                          value: totalTeams.toString(),
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.sports_tennis,
                          label: 'Matches',
                          value: totalMatches.toString(),
                          color: Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.check_circle,
                          label: 'Completed',
                          value: completedMatches.toString(),
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  if (startDate != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Starts ${DateFormat('MMM d, yyyy').format(startDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Progress Bar
                  if (totalMatches > 0) ...[
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${((completedMatches / totalMatches) * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completedMatches / totalMatches,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green.shade600,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  IconData _getTeamTypeIcon(String teamType) {
    switch (teamType) {
      case 'Singles':
        return Icons.person;
      case 'Doubles':
        return Icons.people;
      default:
        return Icons.groups;
    }
  }

  void _openTournament(String tournamentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BadmintonMatchScheduleScreen(tournamentId: tournamentId),
      ),
    );
  }
}
