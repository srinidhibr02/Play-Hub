import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/points_table_screen.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';
import 'package:play_hub/service/badminton_services/match_util_service.dart';
import 'package:play_hub/service/badminton_services/tournament_dialog.dart';

// Helper class for team rankings
class TeamRanking {
  final Team team;
  int points;
  int wins;
  int losses;
  int pointsFor;
  int pointsAgainst;

  TeamRanking({
    required this.team,
    required this.points,
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  int get goalDifference => pointsFor - pointsAgainst;
}

class BadmintonMatchScheduleScreen extends StatefulWidget {
  final String? tournamentId;
  final List<Team>? teams;
  final String? teamType;
  final int? rematches;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final int? matchDuration;
  final int? breakDuration;
  final int? totalMatches;
  final bool? allowRematches;
  final int? customTeamSize;
  final List<String>? members;
  final String? tournamentFormat;

  const BadmintonMatchScheduleScreen({
    super.key,
    this.tournamentId,
    this.teams,
    this.teamType,
    this.rematches,
    this.startDate,
    this.startTime,
    this.matchDuration,
    this.breakDuration,
    this.totalMatches,
    this.allowRematches,
    this.customTeamSize,
    this.members,
    this.tournamentFormat,
  });

  @override
  State<BadmintonMatchScheduleScreen> createState() =>
      _BadmintonMatchScheduleScreenState();
}

class _BadmintonMatchScheduleScreenState
    extends State<BadmintonMatchScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _badmintonService = TournamentFirestoreService();
  final _authService = AuthService();

  String? _tournamentId;
  bool _isLoading = false;
  bool _isReorderMode = false;
  bool _leagueCompletionDialogShown = false;
  List<Match> _reorderMatches = [];
  late int _tabCount;

  @override
  void initState() {
    super.initState();
    _tabCount = widget.tournamentFormat == 'knockout' ? 1 : 2;
    _tabController = TabController(length: _tabCount, vsync: this);
    _initializeTournament();
  }

  Future<void> _initializeTournament() async {
    if (widget.tournamentId != null) {
      setState(() => _tournamentId = widget.tournamentId);
    } else if (_validateTournamentData()) {
      await _createTournament();
    } else {
      if (mounted) {
        _showErrorSnackBar('Tournament data is incomplete');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  bool _validateTournamentData() =>
      widget.teams != null &&
      widget.teamType != null &&
      widget.members != null &&
      widget.startDate != null &&
      widget.startTime != null &&
      widget.matchDuration != null &&
      widget.breakDuration != null &&
      widget.rematches != null &&
      widget.totalMatches != null &&
      widget.allowRematches != null;

  Future<void> _createTournament() async {
    setState(() => _isLoading = true);

    try {
      if (!_validateTournamentData()) {
        throw Exception('Missing required tournament parameters');
      }

      final matches = MatchGenerator(
        teams: widget.teams!,
        totalMatches: widget.totalMatches!,
        allowRematches: widget.allowRematches!,
        rematches: widget.rematches!,
        startDate: widget.startDate!,
        startTime: widget.startTime!,
        matchDuration: widget.matchDuration!,
        breakDuration: widget.breakDuration!,
        tournamentFormat: widget.tournamentFormat ?? 'round_robin',
      ).generate();

      if (matches.isEmpty) throw Exception('Could not generate matches');

      final userEmail = _authService.currentUserEmailId;
      if (userEmail == null || userEmail.isEmpty) {
        throw Exception('User not authenticated');
      }

      final tournamentId = await _badmintonService.createTournament(
        userEmail: userEmail,
        creatorName: _authService.currentUser?.displayName ?? 'Anonymous',
        members: widget.members!,
        teamType: widget.teamType!,
        teams: widget.teams!,
        matches: matches,
        startDate: widget.startDate!,
        startTime: widget.startTime!,
        matchDuration: widget.matchDuration!,
        breakDuration: widget.breakDuration!,
        totalMatches: widget.totalMatches!,
        rematches: widget.rematches!,
        allowRematches: widget.allowRematches!,
        customTeamSize: widget.customTeamSize,
        tournamentFormat: widget.tournamentFormat ?? 'round_robin',
      );

      if (!mounted) return;

      setState(() {
        _tournamentId = tournamentId;
        _isLoading = false;
      });

      _showSuccessSnackBar('Tournament created successfully!');
    } catch (e) {
      debugPrint('❌ Error creating tournament: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to create tournament: $e');
    }
  }

  Future<bool> _checkAllLeagueMatchesCompleted() async {
    try {
      final allMatches = await _badmintonService
          .getMatches(
            _authService.currentUserEmailId ?? '',
            _tournamentId ?? '',
          )
          .first;

      final leagueMatches = allMatches
          .where((m) => m.stage == 'League' || m.stage == null)
          .toList();

      if (leagueMatches.isEmpty) return false;

      return leagueMatches.every((m) => m.status == 'Completed');
    } catch (e) {
      debugPrint('Error checking league completion: $e');
      return false;
    }
  }

  Future<void> _checkAndShowLeagueCompletionDialog() async {
    if (_leagueCompletionDialogShown) return;

    final allCompleted = await _checkAllLeagueMatchesCompleted();

    if (allCompleted && mounted) {
      setState(() => _leagueCompletionDialogShown = true);
      _showLeagueCompletionDialog();
    }
  }

  void _showLeagueCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.check_circle,
                size: 50,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Excellent! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              'All League Matches Completed!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Your tournament league phase is complete. You can now schedule the next phase (Playoffs/Semifinals) to determine the winner.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Later',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showGenerateRoundDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Schedule Now',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
  }

  void _toggleReorderMode() {
    if (!_isReorderMode) {
      setState(() => _isReorderMode = true);
    } else {
      _saveReorderedMatches();
    }
  }

  Future<void> _saveReorderedMatches() async {
    try {
      var currentTime = DateTime(
        widget.startDate!.year,
        widget.startDate!.month,
        widget.startDate!.day,
        widget.startTime!.hour,
        widget.startTime!.minute,
      );

      final updatedMatches = <Match>[];
      for (int i = 0; i < _reorderMatches.length; i++) {
        final match = _reorderMatches[i];

        updatedMatches.add(
          Match(
            id: 'M${i + 1}',
            team1: match.team1,
            team2: match.team2,
            date: currentTime,
            time: DateFormat('h:mm a').format(currentTime),
            status: match.status,
            score1: match.score1,
            score2: match.score2,
            winner: match.winner,
            round: match.round,
            roundName: match.roundName,
            stage: match.stage,
            parentTeam1Id: match.parentTeam1Id,
            parentTeam2Id: match.parentTeam2Id,
          ),
        );

        currentTime = currentTime.add(
          Duration(
            minutes: (widget.matchDuration ?? 30) + (widget.breakDuration ?? 5),
          ),
        );
        debugPrint('New Order $updatedMatches');
      }
      await _badmintonService.updateMatchOrder(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
        updatedMatches,
      );

      setState(() {
        _isReorderMode = false;
        _reorderMatches = [];
      });

      _showSuccessSnackBar('Match order updated successfully!');
    } catch (e) {
      debugPrint('❌ Error saving reorder: $e');
      _showErrorSnackBar('Failed to save match order: $e');
    }
  }

  void _showGenerateRoundDialog() async {
    try {
      final allMatches = await _badmintonService
          .getMatches(
            _authService.currentUserEmailId ?? '',
            _tournamentId ?? '',
          )
          .first;

      if (allMatches.isEmpty) {
        _showErrorSnackBar('No league matches found');
        return;
      }

      final leagueMatches = allMatches
          .where((m) => m.stage == 'League' || m.stage == null)
          .toList();

      final playoffMatches = allMatches
          .where((m) => m.stage == 'Playoff')
          .toList();
      final hasPlayoffs = playoffMatches.isNotEmpty;

      if (!mounted) return;

      if (widget.tournamentFormat == 'knockout') {
        _showKnockoutRoundDialog(allMatches);
      } else {
        _showRoundRobinRoundDialog(leagueMatches, hasPlayoffs);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showRoundRobinRoundDialog(List<Match> leagueMatches, bool hasPlayoffs) {
    final allCompleted =
        leagueMatches.isNotEmpty &&
        leagueMatches.every((m) => m.status == 'Completed');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.sports_score, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            const Text('Next Round'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              allCompleted
                  ? 'League stage completed! 🎉'
                  : '⚠️ Complete all league matches first',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: allCompleted
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildRoundOption(
              enabled: allCompleted,
              icon: Icons.emoji_events,
              title: hasPlayoffs
                  ? 'View Playoff Matches'
                  : 'Generate Playoff Matches',
              subtitle: hasPlayoffs
                  ? 'Playoffs already generated'
                  : 'Create semis & finals for top teams',
              onTap: allCompleted
                  ? () {
                      Navigator.pop(context);
                      _initiatePlayout();
                    }
                  : null,
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
  }

  void _showKnockoutRoundDialog(List<Match> allMatches) {
    final playoffMatches = allMatches
        .where((m) => m.stage == 'Knockout')
        .toList();
    final completedCount = playoffMatches
        .where((m) => m.status == 'Completed')
        .length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.military_tech, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Knockout Progress'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Matches: $completedCount / ${playoffMatches.length} completed',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: playoffMatches.isEmpty
                    ? 0
                    : completedCount / playoffMatches.length,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.orange.shade600,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildRoundOption(
              enabled: true,
              icon: Icons.sports_tennis,
              title: 'Continue Knockout',
              subtitle: completedCount == playoffMatches.length
                  ? 'All matches completed! 🏆'
                  : 'Play next knockout match',
              onTap: () {
                Navigator.pop(context);
              },
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
  }

  Widget _buildRoundOption({
    required bool enabled,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.amber.shade300 : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: enabled ? Colors.white : Colors.grey.shade100,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enabled ? Colors.amber.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: enabled ? Colors.amber.shade700 : Colors.grey.shade500,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: enabled ? Colors.black : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled
                          ? Colors.grey.shade600
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
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

  Future<void> _initiatePlayout() async {
    try {
      final tournament = await _badmintonService.getTournament(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      );
      final allMatches = await _badmintonService
          .getMatches(
            _authService.currentUserEmailId ?? '',
            _tournamentId ?? '',
          )
          .first;

      final leagueMatches = allMatches
          .where((m) => m.stage == 'League' || m.stage == null)
          .toList();
      final allCompleted =
          leagueMatches.isNotEmpty &&
          leagueMatches.every((m) => m.status == 'Completed');

      if (!allCompleted) {
        _showErrorSnackBar('All league matches must be completed first');
        return;
      }
      debugPrint(
        'Printing to see teams count : ${tournament?["stats"]?["totalTeams"]}',
      );
      final teamsCount = tournament?["stats"]?["totalTeams"];

      List<Team> topTeams;

      switch (teamsCount) {
        case 2:
          // Direct Final: Team 1 vs Team 2
          topTeams = await _getTopTeams(2);
          break;

        case 3:
          // Round Robin → Top 2 play final
          topTeams = await _getTopTeams(2);
          break;

        case 4:
        case 5:
        case 6:
        case 7:
          // Semifinals: Top 4 play semis → Final
          topTeams = await _getTopTeams(4);
          break;

        case 8:
        case 9:
        case 10:
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
          // Full Playoffs: Top 8 play full knockout
          topTeams = await _getTopTeams(8);
          break;

        default:
          if (teamsCount > 15) {
            // Large tournament: Top 8 playoffs
            topTeams = await _getTopTeams(8);
            print('🌟 $teamsCount teams → Top 8 Playoffs');
          } else {
            // Less than 2 teams - no playoffs
            topTeams = [];
          }
          break;
      }

      debugPrint('Total teams $teamsCount');
      debugPrint('Top Teams $topTeams');

      if (topTeams.length < 2) {
        _showErrorSnackBar('Not enough teams to conduct playoffs');
        return;
      }

      if (!mounted) return;

      PlayoffChoice? choice;
      if (topTeams.length == 2) {
        choice = PlayoffChoice.directFinal;
      } else {
        choice = await TournamentDialogs.showPlayoffOptionsDialog(
          context,
          topTeams.length,
        );
      }

      if (choice == null) return;

      final playoffGenerator = PlayoffGenerator(
        topTeams: topTeams,
        startDate: widget.startDate ?? DateTime.now(),
        startTime: widget.startTime ?? const TimeOfDay(hour: 9, minute: 0),
        matchDuration: widget.matchDuration ?? 30,
        breakDuration: widget.breakDuration ?? 5,
        format: choice == PlayoffChoice.directFinal
            ? PlayoffFormat.directFinal
            : PlayoffFormat.semisAndFinal,
      );

      final playoffMatches = playoffGenerator.generate();

      await _badmintonService.addPlayoffMatches(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
        playoffMatches,
      );

      _showSuccessSnackBar('Playoff matches generated successfully!');
    } catch (e) {
      debugPrint('❌ Error generating playoffs: $e');
      _showErrorSnackBar('Failed to generate playoffs: $e');
    }
  }

  Future<List<Team>> _getTopTeams(int count) async {
    try {
      final userEmail = _authService.currentUserEmailId;
      final tournamentId = _tournamentId;

      if (userEmail == null || tournamentId == null) {
        throw Exception('User not authenticated');
      }

      final allMatches = await _badmintonService
          .getMatches(userEmail, tournamentId)
          .first;

      final leagueMatches = allMatches
          .where(
            (m) =>
                (m.stage == 'League' || m.stage == null) &&
                m.status == 'Completed',
          )
          .toList();

      final teamPoints = <String, TeamRanking>{};

      // ✅ FIX - Get teams from matches
      final allTeams = allMatches
          .expand((m) => [m.team1, m.team2])
          .toSet()
          .toList();
      for (final team in allTeams) {
        teamPoints[team.id] = TeamRanking(
          team: team,
          points: 0,
          wins: 0,
          losses: 0,
          pointsFor: 0,
          pointsAgainst: 0,
        );
      }

      for (final match in leagueMatches) {
        final team1Id = match.team1.id;
        final team2Id = match.team2.id;
        final score1 = match.score1;
        final score2 = match.score2;

        if (score1 > score2) {
          teamPoints[team1Id]?.wins++;
          teamPoints[team1Id]?.points += 2;
          teamPoints[team2Id]?.losses++;
        } else if (score2 > score1) {
          teamPoints[team2Id]?.wins++;
          teamPoints[team2Id]?.points += 2;
          teamPoints[team1Id]?.losses++;
        } else {
          teamPoints[team1Id]?.points += 1;
          teamPoints[team2Id]?.points += 1;
        }

        teamPoints[team1Id]?.pointsFor += score1;
        teamPoints[team1Id]?.pointsAgainst += score2;
        teamPoints[team2Id]?.pointsFor += score2;
        teamPoints[team2Id]?.pointsAgainst += score1;
      }

      final sortedTeams = teamPoints.values.toList()
        ..sort((a, b) {
          if (a.points != b.points) {
            return b.points.compareTo(a.points);
          }

          final goalDiffA = a.pointsFor - a.pointsAgainst;
          final goalDiffB = b.pointsFor - b.pointsAgainst;
          if (goalDiffA != goalDiffB) {
            return goalDiffB.compareTo(goalDiffA);
          }

          return b.pointsFor.compareTo(a.pointsFor);
        });

      return sortedTeams.take(count).map((r) => r.team).toList();
    } catch (e) {
      debugPrint('❌ Error fetching top teams: $e');
      rethrow;
    }
  }

  void _shareTournament() {
    TournamentDialogs.showShareDialog(
      context,
      _badmintonService,
      _authService.currentUserEmailId,
      _tournamentId,
      _showSuccessSnackBar,
      _showErrorSnackBar,
    );
  }

  void _showTournamentInfo() {
    TournamentDialogs.showInfoDialog(
      context,
      widget.tournamentFormat,
      widget.teamType,
      widget.teams?.length,
      widget.matchDuration,
      widget.breakDuration,
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange.shade600),
              const SizedBox(height: 16),
              Text(
                'Creating tournament...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_tournamentId == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Text(
            'Tournament not found',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    // Check league completion when matches are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowLeagueCompletionDialog();
    });

    return WillPopScope(
      onWillPop: () async {
        if (_isReorderMode) {
          setState(() => _isReorderMode = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: _isReorderMode ? _buildReorderTab() : _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.orange.shade600,
      elevation: 0,
      centerTitle: false,
      title: Text(
        _isReorderMode ? 'Reorder Matches' : 'Tournament Schedule',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Reorder matches',
          icon: Icon(
            _isReorderMode ? Icons.done : Icons.swap_vert_rounded,
            color: Colors.white,
          ),
          onPressed: _toggleReorderMode,
        ),
        if (!_isReorderMode)
          TournamentMenuButton(
            onShare: _shareTournament,
            onInfo: _showTournamentInfo,
          ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.orange.shade600,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _isReorderMode
          ? const SizedBox.shrink()
          : TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              labelColor: Colors.orange.shade600,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: _buildTabs(),
            ),
    );
  }

  List<Widget> _buildTabs() {
    const matchTab = Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_tennis, size: 20),
          SizedBox(width: 8),
          Text('Matches'),
        ],
      ),
    );

    const standingsTab = Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 20),
          SizedBox(width: 8),
          Text('Standings'),
        ],
      ),
    );

    return _tabCount == 1 ? [matchTab] : [matchTab, standingsTab];
  }

  Widget _buildTabContent() {
    return _tabCount == 1
        ? _buildMatchesTab()
        : TabBarView(
            controller: _tabController,
            children: [
              _buildMatchesTab(),
              StandingsTab(
                tournamentId: _tournamentId,
                matchDuration: widget.matchDuration,
                breakDuration: widget.breakDuration,
              ),
            ],
          );
  }

  Widget _buildReorderTab() {
    return StreamBuilder<List<Match>>(
      stream: _badmintonService.getMatches(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No matches to reorder',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          );
        }

        if (_reorderMatches.isEmpty) {
          _reorderMatches = List.from(snapshot.data!);
        }

        return ReorderableMatchList(
          matches: _reorderMatches,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final match = _reorderMatches.removeAt(oldIndex);
              _reorderMatches.insert(newIndex, match);
            });
          },
        );
      },
    );
  }

  Widget _buildMatchesTab() {
    return StreamBuilder<List<Match>>(
      stream: _badmintonService.getMatches(
        _authService.currentUserEmailId ?? '',
        _tournamentId ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorStateWidget(
            error: snapshot.error,
            onRetry: () => setState(() {}),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.orange.shade600),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyMatchesWidget();
        }

        return MatchesListView(
          matches: snapshot.data!,
          onScoreUpdate: (updatedMatch) {
            // ✅ Proper Function(Match)
            _badmintonService.updateMatch(
              _authService.currentUserEmailId ?? '',
              _tournamentId ?? '',
              updatedMatch,
            );
          },
          onMatchTap: _openScorecard, // ✅ Only for tap handler
        );
      },
    );
  }

  void _openScorecard(Match match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScorecardScreen(
          match: match,
          onScoreUpdate: (updatedMatch) {
            _badmintonService.updateMatch(
              _authService.currentUserEmailId ?? '',
              _tournamentId ?? '',
              updatedMatch,
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
