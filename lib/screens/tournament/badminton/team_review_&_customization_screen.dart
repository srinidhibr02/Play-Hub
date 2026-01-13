import 'package:flutter/material.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/tournament_schedule_screen.dart';

class TeamReviewScreen extends StatefulWidget {
  final List<String> members;
  final String teamType;
  final int rematches;
  final DateTime startDate;
  final TimeOfDay startTime;
  final int matchDuration;
  final int breakDuration;
  final int totalMatches;
  final bool allowRematches;
  final String tournamentFormat;
  final int? customTeamSize; // NEW: Custom team size

  const TeamReviewScreen({
    super.key,
    required this.members,
    required this.teamType,
    required this.rematches,
    required this.startDate,
    required this.startTime,
    required this.matchDuration,
    required this.breakDuration,
    required this.totalMatches,
    required this.allowRematches,
    required this.tournamentFormat,
    this.customTeamSize,
  });

  @override
  State<TeamReviewScreen> createState() => _TeamReviewScreenState();
}

class _TeamReviewScreenState extends State<TeamReviewScreen>
    with TickerProviderStateMixin {
  late List<Team> teams;
  late AnimationController _fabAnimationController;

  final List<Color> teamColors = [
    Colors.orange,
    Colors.blue,
    Colors.red,
    Colors.purple,
    Colors.green,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.cyan,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _generateTeams();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _generateTeams() {
    teams = [];
    List<String> shuffledMembers = List<String>.from(widget.members)..shuffle();

    if (widget.teamType == 'Singles') {
      // Singles: Each player is their own team
      for (int i = 0; i < shuffledMembers.length; i++) {
        teams.add(
          Team(
            id: 'T${i + 1}',
            name: shuffledMembers[i],
            players: [shuffledMembers[i]],
          ),
        );
      }
    } else if (widget.teamType == 'Doubles') {
      // Doubles: 2 players per team
      for (int i = 0; i < shuffledMembers.length; i += 2) {
        if (i + 1 < shuffledMembers.length) {
          teams.add(
            Team(
              id: 'T${teams.length + 1}',
              name: 'Team ${teams.length + 1}',
              players: [shuffledMembers[i], shuffledMembers[i + 1]],
            ),
          );
        }
      }
    } else {
      // Custom: Use customTeamSize to divide members
      final teamSize = widget.customTeamSize ?? 3;

      for (int i = 0; i < shuffledMembers.length; i += teamSize) {
        // Ensure we have enough members for a complete team
        if (i + teamSize <= shuffledMembers.length) {
          List<String> teamPlayers = [];
          for (int j = 0; j < teamSize; j++) {
            teamPlayers.add(shuffledMembers[i + j]);
          }

          teams.add(
            Team(
              id: 'T${teams.length + 1}',
              name: 'Team ${teams.length + 1}',
              players: teamPlayers,
            ),
          );
        }
      }
    }
  }

  void _shuffleTeams() {
    setState(() {
      _generateTeams();
    });
    _showSnackBar('Teams reshuffled!', Colors.orange.shade600);
  }

  void _proceedToSchedule() {
    showDialog(
      context: context,
      barrierDismissible: false, // ✅ Prevent outside taps
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange.shade600, size: 28),
              SizedBox(width: 12),
              Text(
                'Confirm Schedule',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule ${widget.totalMatches} matches for ${teams.length} teams?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '• ${widget.teamType} tournament\n• ${widget.tournamentFormat.toUpperCase()} format\n'
                        '${widget.allowRematches ? "• ${widget.rematches} x rematches" : "• No rematches"}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _navigateToSchedule(); // Navigate
              },
              icon: Icon(Icons.arrow_forward, size: 18),
              label: Text('Generate Schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSchedule() {
    Navigator.pop(context);
    Navigator.pop(context);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BadmintonMatchScheduleScreen(
          teams: teams,
          teamType: widget.teamType,
          rematches: widget.rematches,
          startDate: widget.startDate,
          startTime: widget.startTime,
          matchDuration: widget.matchDuration,
          breakDuration: widget.breakDuration,
          totalMatches: widget.totalMatches,
          allowRematches: widget.allowRematches,
          customTeamSize: widget.customTeamSize, // Pass custom team size
          members: widget.members, // ✅ ADD THIS - Required for Firestore
          tournamentFormat: widget.tournamentFormat,
        ),
      ),
    );
  }

  void _swapPlayers(
    String fromTeamId,
    int fromIndex,
    String toTeamId,
    int toIndex,
  ) {
    setState(() {
      Team fromTeam = teams.firstWhere((t) => t.id == fromTeamId);
      Team toTeam = teams.firstWhere((t) => t.id == toTeamId);

      String temp = fromTeam.players[fromIndex];
      fromTeam.players[fromIndex] = toTeam.players[toIndex];
      toTeam.players[toIndex] = temp;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getInfoText() {
    if (widget.teamType == 'Singles') {
      return 'Drag to swap players';
    } else if (widget.teamType == 'Doubles') {
      return 'Drag players between teams';
    } else {
      // Custom doubles format
      return 'Drag to customize teams • Doubles pairs will be auto-generated';
    }
  }

  String _getSubInfoText() {
    if (widget.teamType == 'Singles') {
      return 'Customize your singles setup before starting';
    } else if (widget.teamType == 'Doubles') {
      return 'Customize your doubles setup before starting';
    } else {
      final teamSize = widget.customTeamSize ?? 3;
      final pairsPerTeam = (teamSize * (teamSize - 1)) ~/ 2;
      return 'Each team will form $pairsPerTeam doubles pairs for matches';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade500, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review Teams',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${teams.length} ${widget.teamType == 'Singles' ? 'players' : 'teams'} ready',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: _fabAnimationController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: IconButton(
                onPressed: _shuffleTeams,
                icon: const Icon(Icons.shuffle, color: Colors.white, size: 26),
                tooltip: 'Shuffle Teams',
                splashRadius: 24,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern Info Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.amber.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade600, Colors.orange.shade700],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
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
                        _getInfoText(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSubInfoText(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Teams List
          Expanded(
            child: widget.teamType == 'Singles'
                ? _buildSinglesList()
                : _buildTeamsList(),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildSinglesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        final color = teamColors[index % teamColors.length];

        return DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (details) {
            final data = details.data;
            return data['teamId'] != team.id;
          },
          onAcceptWithDetails: (details) {
            final data = details.data;
            _swapPlayers(data['teamId'], data['playerIndex'], team.id, 0);
            _showSnackBar('Players swapped!', Colors.green.shade600);
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;

            return Draggable<Map<String, dynamic>>(
              data: {
                'teamId': team.id,
                'playerIndex': 0,
                'player': team.players[0],
              },
              feedback: Stack(
                children: [
                  Container(
                    width: 300,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withOpacity(0.8), color],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              team.players[0][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            team.players[0],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: _buildSinglePlayerCard(team, index, color),
              ),
              onDragStarted: () {},
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  boxShadow: isHovering
                      ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                  border: Border.all(
                    color: isHovering
                        ? Colors.orange.shade600
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: _buildSinglePlayerCard(team, index, color),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSinglePlayerCard(Team team, int index, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                team.players[0][0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  team.players[0],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator, color: color.withOpacity(0.5), size: 20),
        ],
      ),
    );
  }

  Widget _buildTeamsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        final color = teamColors[index % teamColors.length];
        final bool showExpanded = _expandedTeams.contains(team.id);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.85), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.groups,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${team.players.length} members',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (team.players.length > 6) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '+${team.players.length - 6}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.15),
                            color.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'T${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Expand Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (showExpanded) {
                            _expandedTeams.remove(team.id);
                          } else {
                            _expandedTeams.add(team.id);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(showExpanded ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          showExpanded ? Icons.expand_less : Icons.expand_more,
                          color: color,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Compact Preview
                if (!showExpanded) _buildCompactPlayersPreview(team, color),

                // Expanded Grid
                if (showExpanded)
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _buildExpandedPlayersGrid(team, color),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Track expanded teams
  Set<String> _expandedTeams = {};

  Widget _buildCompactPlayersPreview(Team team, Color color) {
    final previewPlayers = team.players.take(3).toList();
    final hasMore = team.players.length > 3;

    return Row(
      children: [
        ...previewPlayers.asMap().entries.map((entry) {
          final playerIndex = entry.key;
          final player = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              right: playerIndex < previewPlayers.length - 1 ? 8 : 0,
            ),
            child: _buildPlayerChip(player, color, playerIndex),
          );
        }).toList(),
        if (hasMore)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color.fromRGBO(224, 224, 224, 1)),
            ),
            child: Text(
              '+${team.players.length - 3}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedPlayersGrid(Team team, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chipsPerRow = (constraints.maxWidth / 140).floor().clamp(1, 6);

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: team.players.asMap().entries.map((entry) {
            final playerIndex = entry.key;
            final player = entry.value;
            return _buildDraggablePlayerChip(
              team.id,
              playerIndex,
              player,
              color,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDraggablePlayerChip(
    String teamId,
    int playerIndex,
    String player,
    Color color,
  ) {
    return Draggable<Map<String, dynamic>>(
      data: {'teamId': teamId, 'playerIndex': playerIndex, 'player': player},
      feedback: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.9), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.3),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${playerIndex + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                player,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildPlayerChip(player, color, playerIndex),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          return data['teamId'] != teamId || data['playerIndex'] != playerIndex;
        },
        onAcceptWithDetails: (details) {
          final data = details.data;
          _swapPlayers(
            data['teamId'],
            data['playerIndex'],
            teamId,
            playerIndex,
          );
          _showSnackBar(
            '${data['player']} ↔ $player swapped!',
            Colors.green.shade600,
          );
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedScale(
            scale: isHovering ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: isHovering
                    ? [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: Border.all(
                  color: isHovering
                      ? Colors.orange.shade600
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: _buildPlayerChip(player, color, playerIndex, isHovering),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerChip(
    String playerName,
    Color color,
    int playerIndex, [
    bool isHovering = false,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHovering
              ? [color.withOpacity(0.85), color]
              : [color.withOpacity(0.12), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHovering ? color : color.withOpacity(0.25),
          width: isHovering ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isHovering ? 0.25 : 0.08),
            blurRadius: isHovering ? 10 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            playerName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isHovering ? Colors.white : color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isHovering) ...[
            const SizedBox(width: 5),
            Icon(
              Icons.open_with,
              size: 12,
              color: isHovering ? Colors.white : color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shuffleTeams,
                icon: const Icon(Icons.shuffle, size: 20),
                label: const Text('Shuffle'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.shade600, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.orange.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _proceedToSchedule,
                icon: const Icon(
                  Icons.calendar_month,
                  size: 20,
                  color: Colors.white,
                ),
                label: const Text(
                  'Schedule Matches',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 4,
                  shadowColor: Colors.orange.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
