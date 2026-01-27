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
  String? _userEmail;
  late TabController _tabController;

  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserEmail();
    _initAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    _tabController.dispose();
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

  // ✨ MODERN EMPTY SCREEN
  Widget _buildEmptyScreen({required bool isCreated}) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🎾 Animated Icon
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCreated
                          ? [
                              Colors.orange.shade300.withAlpha(
                                (255 * 0.6).toInt(),
                              ),
                              Colors.yellow.shade200.withAlpha(
                                (255 * 0.3).toInt(),
                              ),
                            ]
                          : [
                              Colors.blue.shade300.withAlpha(
                                (255 * 0.6).toInt(),
                              ),
                              Colors.cyan.shade200.withAlpha(
                                (255 * 0.3).toInt(),
                              ),
                            ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isCreated ? Colors.orange : Colors.blue)
                            .withAlpha((255 * 0.3).toInt()),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCreated
                                ? [
                                    Colors.orange.shade500,
                                    Colors.orange.shade700,
                                  ]
                                : [Colors.blue.shade500, Colors.blue.shade700],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCreated
                              ? Icons.sports_tennis_rounded
                              : Icons.handshake_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCreated ? Icons.add : Icons.favorite,
                            size: 14,
                            color: isCreated ? Colors.orange : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title
              Text(
                isCreated ? 'No Tournaments Yet' : 'No Joined Tournaments',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isCreated ? Colors.orange : Colors.blue).withAlpha(
                    (255 * 0.05).toInt(),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isCreated ? Colors.orange : Colors.blue).withAlpha(
                      (255 * 0.1).toInt(),
                    ),
                  ),
                ),
                child: Text(
                  isCreated
                      ? 'Create your first tournament to get started with managing matches and teams!'
                      : 'Ask tournament creators for their share code to join tournaments and compete!',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Action Button
              GestureDetector(
                onTap: () {
                  _bounceController.forward().then(
                    (_) => _bounceController.reverse(),
                  );
                  if (isCreated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BadmintonTournamentSetupScreen(),
                      ),
                    );
                  } else {
                    _showJoinTournamentDialog();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCreated
                          ? [Colors.orange.shade600, Colors.deepOrange.shade500]
                          : [Colors.blue.shade600, Colors.blue.shade500],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isCreated ? Colors.orange : Colors.blue)
                            .withAlpha((255 * 0.4).toInt()),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCreated ? Icons.add_circle : Icons.vpn_key_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isCreated ? 'Create Tournament' : 'Join with Code',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Tournaments',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Manage and track your competitions',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade600,
                      Colors.deepOrange.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withAlpha((255 * 0.3).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
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
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade600,
                        Colors.deepOrange.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withAlpha((255 * 0.25).toInt()),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sports_bar_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Text('Created'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.handshake_rounded, size: 18),
                          const SizedBox(width: 8),
                          const Text('Joined'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _userEmail == null
          ? Center(
              child: CircularProgressIndicator(color: Colors.orange.shade600),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Created Tournaments Tab
                _buildTournamentListView(isCreated: true),
                // Joined Tournaments Tab
                _buildTournamentListView(isCreated: false),
              ],
            ),
      floatingActionButton: ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade500],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withAlpha((255 * 0.4).toInt()),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              _bounceController.forward().then(
                (_) => _bounceController.reverse(),
              );
              _showJoinTournamentDialog();
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            heroTag: 'joinCode',
            child: const Icon(
              Icons.vpn_key_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTournamentListView({required bool isCreated}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: isCreated
          ? _firestoreService.getUserTournaments(_userEmail!)
          : _firestoreService.getJoinedTournaments(_userEmail!),
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading tournaments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final tournaments = snapshot.data ?? [];

        if (tournaments.isEmpty) {
          return _buildEmptyScreen(isCreated: isCreated);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tournaments.length,
          itemBuilder: (context, index) =>
              _buildTournamentCard(tournaments[index], isCreator: isCreated),
        );
      },
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
        ? Colors.green.shade600
        : status == 'completed'
        ? Colors.blue.shade600
        : Colors.grey.shade400;

    Color headerGradient1 = isCreator
        ? Colors.orange.shade600
        : Colors.blue.shade600;
    Color headerGradient2 = isCreator
        ? Colors.deepOrange.shade500
        : Colors.blue.shade500;

    return GestureDetector(
      onTap: () => _openTournament(tournamentId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.08).toInt()),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [headerGradient1, headerGradient2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((255 * 0.2).toInt()),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getTeamTypeIcon(teamType),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tournamentFormat.replaceAll('_', ' ').toUpperCase()} • $teamType',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tournament['name'] ?? 'Tournament',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((255 * 0.25).toInt()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha((255 * 0.2).toInt()),
                      ),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(18),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.sports_tennis_rounded,
                          label: 'Matches',
                          value: totalMatches.toString(),
                          color: Colors.orange.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Completed',
                          value: completedMatches.toString(),
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    height: 1,
                    color: Colors.grey.shade200,
                  ),

                  // Bottom Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (startDate != null)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Starts',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy').format(startDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (createdAt != null)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Created',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d').format(createdAt),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (isCreator)
                        GestureDetector(
                          onTap: () => _showDeleteConfirmation(tournamentId),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade600,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.08).toInt()),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha((255 * 0.1).toInt())),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTeamTypeIcon(String teamType) {
    switch (teamType) {
      case 'Singles':
        return Icons.person_rounded;
      case 'Doubles':
        return Icons.people_rounded;
      default:
        return Icons.groups_rounded;
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

  void _showJoinTournamentDialog() {
    TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade500],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                'Join Tournament',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Enter the share code to join a tournament',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Input Field
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  hintText: 'e.g., ABC123XYZ',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.blue.shade600,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.key_rounded,
                    color: Colors.blue.shade600,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade500],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withAlpha((255 * 0.3).toInt()),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          String code = codeController.text.trim();
                          if (code.isEmpty) return;

                          Navigator.pop(context);
                          await _joinTournamentWithCode(code);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Join',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      _showError('Failed to join tournament: $e');
    }
  }

  void _showDeleteConfirmation(String tournamentId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Tournament',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to permanently delete this tournament? This action cannot be undone.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade600, Colors.red.shade500],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _firestoreService.deleteTournament(
                            _userEmail as String,
                            tournamentId,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
