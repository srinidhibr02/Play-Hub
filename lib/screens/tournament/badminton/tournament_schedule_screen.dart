import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/constants/badminton.dart';
import 'package:play_hub/screens/tournament/badminton/points_table_screen.dart';
import 'package:play_hub/screens/tournament/badminton/scorecard.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/service/badminton_services/badminton_service.dart';
import 'package:play_hub/service/badminton_services/match_util_service.dart';
import 'package:play_hub/service/badminton_services/tournament_dialog.dart';

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
          onMatchTap: _openScorecard,
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
          teamType: widget.teamType ?? 'Singles',
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
