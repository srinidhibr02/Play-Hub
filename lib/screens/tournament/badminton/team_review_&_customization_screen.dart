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
  final int? customTeamSize;

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
  late AnimationController _listAnimationController;
  Set<String> _expandedTeams = {};

  final List<Color> teamColors = [
    Colors.blue,
    Colors.purple,
    Colors.red,
    Colors.green,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.cyan,
    Colors.amber,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _generateTeams();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  void _generateTeams() {
    teams = [];
    List<String> shuffledMembers = List<String>.from(widget.members)..shuffle();

    if (widget.teamType == 'Singles') {
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
      final teamSize = widget.customTeamSize ?? 3;

      for (int i = 0; i < shuffledMembers.length; i += teamSize) {
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
      _expandedTeams.clear();
      _generateTeams();
    });
    _showSnackBar('Teams reshuffled!', Colors.green.shade600);
  }

  void _proceedToSchedule() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: Colors.orange.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confirm Schedule',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Schedule ${widget.totalMatches} matches for ${teams.length} ${widget.teamType == 'Singles' ? 'players' : 'teams'}?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        '${widget.teamType} tournament',
                        Colors.orange.shade600,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        '${widget.tournamentFormat.toUpperCase()} format',
                        Colors.blue.shade600,
                      ),
                      if (widget.allowRematches) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          '${widget.rematches}x rematches',
                          Colors.purple.shade600,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                            colors: [
                              Colors.orange.shade600,
                              Colors.deepOrange.shade500,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withAlpha(
                                (255 * 0.3).toInt(),
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                            _navigateToSchedule();
                          },
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Generate',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
        );
      },
    );
  }

  Widget _buildDetailRow(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
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
          customTeamSize: widget.customTeamSize,
          members: widget.members,
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
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
      return 'Customize your teams';
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Teams',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${teams.length} ${widget.teamType == 'Singles' ? 'players' : 'teams'} ready',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1).animate(
                CurvedAnimation(
                  parent: _fabAnimationController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _shuffleTeams,
                  icon: Icon(
                    Icons.shuffle_rounded,
                    color: Colors.orange.shade600,
                    size: 22,
                  ),
                  tooltip: 'Shuffle Teams',
                  splashRadius: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info Banner
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
                  color: Colors.orange.withAlpha((255 * 0.08).toInt()),
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
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.orange.shade600,
                    size: 20,
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
                          height: 1.3,
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
              feedback: _buildSinglePlayerCardDrag(team, index, color),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: _buildSinglePlayerCard(team, index, color, false),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  boxShadow: isHovering
                      ? [
                          BoxShadow(
                            color: Colors.orange.withAlpha((255 * 0.3).toInt()),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha((255 * 0.06).toInt()),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: _buildSinglePlayerCard(team, index, color, isHovering),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSinglePlayerCard(
    Team team,
    int index,
    Color color,
    bool isHovering,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHovering ? color : color.withAlpha((255 * 0.2).toInt()),
          width: isHovering ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha((255 * 0.7).toInt()), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha((255 * 0.3).toInt()),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                team.players[0][0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha((255 * 0.1).toInt()),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: color.withAlpha((255 * 0.3).toInt()),
                    ),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  team.players[0],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.drag_indicator_rounded,
            color: color.withAlpha((255 * 0.4).toInt()),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePlayerCardDrag(Team team, int index, Color color) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withAlpha((255 * 0.8).toInt()), color],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  team.players[0][0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                team.players[0],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
            ),
          ],
        ),
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
        final showExpanded = _expandedTeams.contains(team.id);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha((255 * 0.1).toInt()),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withAlpha((255 * 0.2).toInt()),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Header
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withAlpha((255 * 0.8).toInt()),
                              color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha((255 * 0.3).toInt()),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
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
                              team.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${team.players.length} member${team.players.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
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
                          color: color.withAlpha((255 * 0.1).toInt()),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withAlpha((255 * 0.3).toInt()),
                          ),
                        ),
                        child: Text(
                          'T${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: showExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: color,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Compact Preview
                if (!showExpanded) _buildCompactPlayersPreview(team, color),

                // Expanded Grid
                if (showExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildExpandedPlayersGrid(team, color),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactPlayersPreview(Team team, Color color) {
    final previewPlayers = team.players.take(4).toList();
    final hasMore = team.players.length > 4;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...previewPlayers.asMap().entries.map((entry) {
            final player = entry.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildPlayerChip(player, color, entry.key),
            );
          }),
          if (hasMore)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '+${team.players.length - 4}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedPlayersGrid(Team team, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: team.players.asMap().entries.map((entry) {
        final playerIndex = entry.key;
        final player = entry.value;
        return _buildDraggablePlayerChip(team.id, playerIndex, player, color);
      }).toList(),
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
        borderRadius: BorderRadius.circular(12),
        child: _buildPlayerChipDrag(player, color, playerIndex),
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
            scale: isHovering ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: _buildPlayerChip(player, color, playerIndex, isHovering),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHovering
              ? [color.withAlpha((255 * 0.85).toInt()), color]
              : [
                  color.withAlpha((255 * 0.08).toInt()),
                  color.withAlpha((255 * 0.05).toInt()),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHovering ? color : color.withAlpha((255 * 0.25).toInt()),
          width: isHovering ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((255 * (isHovering ? 0.2 : 0.06)).toInt()),
            blurRadius: isHovering ? 8 : 2,
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isHovering ? Colors.white : color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isHovering) ...[
            const SizedBox(width: 4),
            Icon(Icons.open_with_rounded, size: 12, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerChipDrag(String playerName, Color color, int playerIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha((255 * 0.9).toInt()), color],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((255 * 0.4).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        playerName,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.08).toInt()),
            blurRadius: 16,
            offset: const Offset(0, -4),
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
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Shuffle'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.shade600, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: Colors.orange.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade600,
                      Colors.deepOrange.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withAlpha((255 * 0.3).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _proceedToSchedule,
                  icon: const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Schedule',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
