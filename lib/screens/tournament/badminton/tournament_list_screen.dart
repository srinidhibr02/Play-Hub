import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/screens/tournament/badminton/badminton_tournament_setup_screen.dart';
import 'package:play_hub/screens/tournament/badminton/tournament_schedule_screen.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';
import 'package:rxdart/rxdart.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen>
    with TickerProviderStateMixin {
  final TournamentFirestoreService _firestoreService =
      TournamentFirestoreService();
  final String _selectedFilter = 'all';
  String? _userEmail;
  bool _isFabExpanded = false;

  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _initAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bounceAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
        );
  }

  Future<void> _loadUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    String? email = user?.email;

    setState(() {
      _userEmail = email;
    });
  }

  // 🎨 ULTIMATE EMPTY SCREEN - TOP POSITIONED
  Widget _buildEmptyScreen() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),

          // 🎾 Animated Hero Illustration
          Center(
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 140,
                height: 140,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.orange.shade300.withOpacity(0.6),
                      Colors.yellow.shade200.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade500,
                            Colors.orange.shade700,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sports_tennis_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flash_on,
                          size: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              'No Active Tournaments',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(height: 10),
          Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'Create your first tournament or join existing ones using share codes to start playing!',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // 🔥 Hero Action Buttons
          Column(
            children: [
              // Primary CTA - Create
              GestureDetector(
                onTap: () {
                  _bounceController.forward().then(
                    (_) => _bounceController.reverse(),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BadmintonTournamentSetupScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade600,
                        Colors.deepOrange.shade500,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Create First Tournament',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Secondary CTA - Join
              GestureDetector(
                onTap: () {
                  _bounceController.forward().then(
                    (_) => _bounceController.reverse(),
                  );
                  _showJoinTournamentDialog();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade500, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Join with Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
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
          // Icon 1: Search
          Container(
            margin: const EdgeInsets.only(right: 2),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BadmintonTournamentSetupScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              tooltip: 'Create new tournament',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Icon 2: Filter/Sort
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () {
                _showJoinTournamentDialog();
              },
              icon: Icon(Icons.key_rounded, color: Colors.white),
              tooltip: 'Join with Code',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
          FloatingActionButton(
            onPressed: () {
              setState(() => _isFabExpanded = !_isFabExpanded);
            },
            backgroundColor: Colors.orange.shade400,
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
      Map<String, dynamic>? tournament = await _firestoreService
          .getTournamentByShareCode(shareCode, context);

      if (tournament == null) {
        _showError('Invalid or expired share code');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BadmintonMatchScheduleScreen(tournamentId: shareCode),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
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
    return StreamBuilder<Map<String, dynamic>>(
      stream: _getCombinedTournaments(_userEmail!),
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

        final data = snapshot.data!;
        final createdTournaments =
            data['created'] as List<Map<String, dynamic>>? ?? [];
        final joinedTournaments =
            data['joined'] as List<Map<String, dynamic>>? ?? [];

        if (createdTournaments.isEmpty && joinedTournaments.isEmpty) {
          return _buildEmptyScreen(); // 🎯 Premium empty screen
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (createdTournaments.isNotEmpty) ...[
              _buildSectionHeader('Created Tournaments', Colors.orange),
              ...createdTournaments.map(
                (t) => _buildTournamentCard(t, isCreator: true),
              ),
            ],
            if (createdTournaments.isNotEmpty && joinedTournaments.isNotEmpty)
              const SizedBox(height: 24),
            if (joinedTournaments.isNotEmpty) ...[
              _buildSectionHeader('Joined Tournaments', Colors.blue),
              ...joinedTournaments.map(
                (t) => _buildTournamentCard(t, isCreator: false),
              ),
            ],
          ],
        );
      },
    );
  }

  Stream<Map<String, dynamic>> _getCombinedTournaments(String userEmail) {
    // Get created tournaments
    final createdStream = _firestoreService.getUserTournaments(userEmail);

    // Get joined tournaments
    final joinedStream = _firestoreService.getJoinedTournaments(userEmail);

    return Rx.combineLatest2(
      createdStream,
      joinedStream,
      (created, joined) => {'created': created, 'joined': joined},
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(
    Map<String, dynamic> tournament, {
    required bool isCreator,
  }) {
    String tournamentId = tournament['id'];
    String teamType = tournament['teamType'] ?? 'Unknown';
    String status = tournament['status'] ?? 'active';
    String tournamentFormat = tournament['tournamentFormat'] ?? '';
    Map<String, dynamic> stats = tournament['stats'] ?? {};
    Map<String, dynamic> schedule = tournament['schedule'] ?? {};

    int completedMatches = stats['completedMatches'] ?? 0;
    int totalTeams = stats['totalTeams'] ?? 0;
    int totalMatches = stats['totalMatches'] ?? 0;

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
          borderRadius: BorderRadius.circular(20),
          border: !isCreator
              ? Border.all(color: Colors.blue.shade200, width: 2)
              : Border.all(color: Colors.red.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Action Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCreator
                      ? [Colors.orange.shade600, Colors.orange.shade400]
                      : [Colors.blue.shade600, Colors.blue.shade400],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Icon + Info
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getTeamTypeIcon(teamType),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${tournamentFormat.split('_').join(' ').toUpperCase()} - $teamType',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Created ${DateFormat('MMM d').format(createdAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isCreator) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Joined',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status + Delete Button (Creator Only)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content - Stats + Date
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.people_outline_rounded,
                          label: 'Teams',
                          value: totalTeams.toString(),
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.sports_tennis,
                          label: 'Matches',
                          value: totalMatches.toString(),
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.verified,
                          label: 'Done',
                          value: completedMatches.toString(),
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),

                  // Start Date
                  if (startDate != null) ...[
                    const SizedBox(height: 16),
                    Container(height: 1, color: Colors.grey.shade200),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Starts ${DateFormat('MMM d, yyyy').format(startDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        if (isCreator) ...[
                          const SizedBox(width: 12),
                          // Delete Button - Only for Creators
                          GestureDetector(
                            onTap: () => _showDeleteConfirmation(tournamentId),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(
                                  255,
                                  244,
                                  67,
                                  54,
                                ).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color.fromARGB(255, 229, 57, 53),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
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

  // Add this method to your class
  void _showDeleteConfirmation(String tournamentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text(
              'Delete Tournament',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete this tournament? \nThis action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              print('$tournamentId & $_userEmail');
              _firestoreService.deleteTournament(
                _userEmail as String,
                tournamentId,
              ); // Your existing delete method
            },
            child: const Text('Delete'),
          ),
        ],
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
