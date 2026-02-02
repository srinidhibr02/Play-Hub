import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/screens/clubTournament/badminton_club_tournament/match_scorecard_screen.dart';
import 'package:play_hub/screens/clubTournament/badminton_club_tournament/standings_widget.dart';
import 'package:play_hub/screens/clubTournament/club_service/club_tournament_service.dart';
import 'package:play_hub/screens/clubTournament/club_service/playoff_scheduling_service.dart';

class RoundRobinScheduleScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final DateTime startDate;
  final TimeOfDay startTime;
  final int matchDuration;
  final int breakDuration;
  final String tournamentFormat;

  const RoundRobinScheduleScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.startDate,
    required this.startTime,
    required this.matchDuration,
    required this.breakDuration,
    required this.tournamentFormat,
  });

  @override
  State<RoundRobinScheduleScreen> createState() =>
      _RoundRobinScheduleScreenState();
}

class _RoundRobinScheduleScreenState extends State<RoundRobinScheduleScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  final _service = ClubTournamentService();
  final _playoffService = PlayoffSchedulingService();
  int _selectedCategoryIndex = 0;
  int _selectedTabIndex = 0;
  bool _isLoadingAction = false;

  // Track playoff generation status per category
  final Map<String, bool> _playoffsGenerated = {};

  final Map<String, Color> categoryColors = {
    'Male Singles': const Color(0xFF3B82F6),
    'Male Doubles': const Color(0xFFF97316),
    'Female Singles': const Color(0xFFEC4899),
    'Female Doubles': const Color(0xFFA855F7),
    'Mixed Doubles': const Color(0xFF10B981),
  };

  final Map<String, IconData> categoryIcons = {
    'Male Singles': Icons.person_rounded,
    'Male Doubles': Icons.people_rounded,
    'Female Singles': Icons.person_rounded,
    'Female Doubles': Icons.people_rounded,
    'Mixed Doubles': Icons.groups_rounded,
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    return categoryColors[category] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String category) {
    return categoryIcons[category] ?? Icons.sports_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: Colors.grey.shade900),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tournament Schedule',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            widget.tournamentName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getCategoryTournaments(widget.tournamentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final categories = snapshot.data ?? [];

        if (categories.isEmpty) {
          return _buildEmptyState();
        }

        return _buildContent(categories);
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: _fadeController,
                curve: Curves.elasticOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade100, Colors.cyan.shade100],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_volleyball_rounded,
                size: 56,
                color: Colors.teal.shade600,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Generating schedules...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.teal.shade600),
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Error Loading Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade50, Colors.cyan.shade50],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 64,
              color: Colors.teal.shade300,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Tournaments Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Generate tournament schedules to get started',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> categories) {
    if (_selectedCategoryIndex >= categories.length) {
      _selectedCategoryIndex = 0;
    }

    final selected = categories[_selectedCategoryIndex];
    final categoryName = selected['category'] as String? ?? 'Unknown';
    final categoryColor = _getCategoryColor(categoryName);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCategorySelector(categories),
          _buildCategoryInfoCard(selected, categoryColor),
          _buildCategoryContent(categoryName, categoryColor),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(List<Map<String, dynamic>> categories) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(categories.length, (index) {
            final cat = categories[index];
            final catName = cat['category'] as String? ?? 'Unknown';
            final isSelected = _selectedCategoryIndex == index;
            final color = _getCategoryColor(catName);
            final icon = _getCategoryIcon(catName);

            return GestureDetector(
              onTap: () => setState(() {
                _selectedCategoryIndex = index;
                _selectedTabIndex = 0;
              }),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [color.withOpacity(0.9), color]
                        : [Colors.grey.shade100, Colors.grey.shade200],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      catName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cat['participantCount'] ?? 0}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCategoryInfoCard(
    Map<String, dynamic> category,
    Color categoryColor,
  ) {
    final categoryName = category['category'] as String? ?? 'Unknown';
    final participants = category['participantCount'] as int? ?? 0;
    final icon = _getCategoryIcon(categoryName);

    return FadeTransition(
      opacity: _fadeController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
            ),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [categoryColor, categoryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Category Tournament',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoStat(
                      icon: Icons.people_rounded,
                      label: 'Participants',
                      value: participants.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoStat(
                      icon: Icons.sports_tennis_rounded,
                      label: 'Format',
                      value: widget.tournamentFormat == 'round_robin'
                          ? 'League'
                          : 'Knockout',
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

  Widget _buildInfoStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(String categoryName, Color categoryColor) {
    return StatefulBuilder(
      builder: (context, setTabState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setTabState(() => _selectedTabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: _selectedTabIndex == 0
                              ? LinearGradient(
                                  colors: [categoryColor, categoryColor],
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 20,
                              color: _selectedTabIndex == 0
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Matches',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedTabIndex == 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: _selectedTabIndex == 0
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setTabState(() => _selectedTabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: _selectedTabIndex == 1
                              ? LinearGradient(
                                  colors: [categoryColor, categoryColor],
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.leaderboard_rounded,
                              size: 20,
                              color: _selectedTabIndex == 1
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Standings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedTabIndex == 1
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: _selectedTabIndex == 1
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _selectedTabIndex == 0
                ? _buildMatchesTab(categoryName, categoryColor)
                : _buildStandingsTab(categoryName, categoryColor),
          ],
        );
      },
    );
  }

  Widget _buildMatchesTab(String categoryName, Color categoryColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getCategoryMatchesStream(
        widget.tournamentId,
        categoryName,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: CircularProgressIndicator(color: categoryColor),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.sports_tennis_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No matches scheduled',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        // ✅ Group matches by stage
        final leagueMatches = matches
            .where((m) => (m['stage'] as String?) == 'League')
            .toList();
        final semiMatches = matches
            .where((m) => (m['stage'] as String?) == 'Semi-Final')
            .toList();
        final finalMatches = matches
            .where((m) => (m['stage'] as String?) == 'Final')
            .toList();

        // ✅ Calculate overall progress
        final totalMatches = matches.length;
        final completedMatches = matches
            .where((m) => (m['status'] as String?) == 'Completed')
            .length;
        final progressPercent = totalMatches > 0
            ? (completedMatches / totalMatches * 100).toInt()
            : 0;

        // ✅ Check if tournament is finished
        final allFinalsCompleted =
            finalMatches.isNotEmpty &&
            finalMatches.every((m) => (m['status'] as String?) == 'Completed');

        // ✅ Check if playoffs have been generated for this category
        final hasPlayoffsGenerated =
            semiMatches.isNotEmpty || finalMatches.isNotEmpty;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Tournament Progress Card
                _buildTournamentProgressCard(
                  completedMatches,
                  totalMatches,
                  progressPercent,
                  categoryColor,
                ),
                const SizedBox(height: 24),

                // ✅ Tournament Winner Card
                if (allFinalsCompleted) ...[
                  _buildTournamentWinnerCard(matches, categoryColor),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),

                // ✅ Finals Phase Section
                if (finalMatches.isNotEmpty) ...[
                  _buildEnhancedPhaseHeader(
                    'Finals',
                    '🏆',
                    Colors.amber,
                    finalMatches,
                    categoryName: categoryName,
                  ),
                  const SizedBox(height: 12),
                  ...finalMatches.asMap().entries.map((entry) {
                    return _buildEnhancedMatchCard(
                      entry.value,
                      entry.key + 1,
                      'F',
                      categoryName,
                      categoryColor,
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                // ✅ Semi-Finals Phase Section
                if (semiMatches.isNotEmpty) ...[
                  _buildEnhancedPhaseHeader(
                    'Semi-Finals',
                    '🥊',
                    Colors.orange,
                    semiMatches,
                    categoryName: categoryName,
                    onGenerateNextRound: () =>
                        _autoGenerateFinals(categoryName),
                  ),
                  const SizedBox(height: 12),
                  ...semiMatches.asMap().entries.map((entry) {
                    return _buildEnhancedMatchCard(
                      entry.value,
                      entry.key + 1,
                      'SF',
                      categoryName,
                      categoryColor,
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // ✅ League Phase Section
                if (leagueMatches.isNotEmpty) ...[
                  _buildEnhancedPhaseHeader(
                    'League Phase',
                    '⚽',
                    categoryColor,
                    leagueMatches,
                    categoryName: categoryName,
                    onGenerateNextRound: hasPlayoffsGenerated
                        ? null // Disable button if playoffs already exist
                        : () => _handleLeagueComplete(
                            categoryName,
                            categoryColor,
                          ),
                    hasNextRoundGenerated:
                        hasPlayoffsGenerated, // Pass this parameter
                  ),
                  const SizedBox(height: 12),
                  ...leagueMatches.asMap().entries.map((entry) {
                    return _buildEnhancedMatchCard(
                      entry.value,
                      entry.key + 1,
                      'L',
                      categoryName,
                      categoryColor,
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// ✅ Tournament Progress Card
  Widget _buildTournamentProgressCard(
    int completed,
    int total,
    int progressPercent,
    Color categoryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withOpacity(0.1),
            categoryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: categoryColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tournament Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ✅ Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(categoryColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$completed of $total matches completed',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Enhanced Phase Header with Progress and Action Button
  Widget _buildEnhancedPhaseHeader(
    String phaseName,
    String emoji,
    Color color,
    List<Map<String, dynamic>> phaseMatches, {
    String? categoryName,
    VoidCallback? onGenerateNextRound,
    bool hasNextRoundGenerated = false,
  }) {
    final completed = phaseMatches
        .where((m) => (m['status'] as String?) == 'Completed')
        .length;
    final total = phaseMatches.length;
    final isPhaseComplete = completed == total && total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Phase Header (Status Only)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phaseName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      '$total matches • $completed completed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ Status Badge ONLY (no action)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPhaseComplete
                      ? Colors.green.withOpacity(0.15)
                      : color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPhaseComplete
                        ? Colors.green.withOpacity(0.3)
                        : color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPhaseComplete
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      size: 14,
                      color: isPhaseComplete ? Colors.green.shade700 : color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPhaseComplete ? 'Complete' : 'In Progress',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPhaseComplete ? Colors.green.shade700 : color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 2. ✅ SEPARATE Generate Button (League Phase Only)
        if (isPhaseComplete &&
            phaseName == 'League Phase' &&
            onGenerateNextRound != null &&
            !hasNextRoundGenerated)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingAction ? null : onGenerateNextRound,
                icon: _isLoadingAction
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.sports_tennis_rounded, size: 18),
                label: Text(
                  _isLoadingAction ? 'Generating...' : 'Generate Semis/Finals',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: hasNextRoundGenerated
                      ? Colors.grey.shade400
                      : Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// ✅ Enhanced Match Card with Match Number
  Widget _buildEnhancedMatchCard(
    Map<String, dynamic> match,
    int matchNumber,
    String stageCode,
    String categoryName,
    Color categoryColor,
  ) {
    final team1 = match['team1'] as Map<String, dynamic>;
    final team2 = match['team2'] as Map<String, dynamic>;
    final status = match['status'] as String? ?? 'Scheduled';
    final score1 = match['score1'] as int? ?? 0;
    final score2 = match['score2'] as int? ?? 0;
    final date = match['date'] as Timestamp?;
    final time = match['time'] as String? ?? '';
    final stage = match['stage'] as String? ?? 'League';
    final round = match['roundName'] as String? ?? '';
    final isBye = match['isBye'] as bool? ?? false;
    final isCompleted = status == 'Completed';

    final stageStyle = _getStageStyle(stage);

    // ✅ Proper match ID/number
    final displayMatchId = '$stageCode-$matchNumber';

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _slideController,
              curve: Interval(
                0.1 + (matchNumber * 0.02),
                1.0,
                curve: Curves.easeOut,
              ),
            ),
          ),
      child: GestureDetector(
        onTap: !isBye ? () => _openScorecard(match, categoryName) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted
                  ? Colors.green.withOpacity(0.3)
                  : stageStyle['borderColor'] as Color,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? Colors.green.withOpacity(0.1)
                    : (stageStyle['color'] as Color).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Header: Match ID + Stage + Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Match ID Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Match $displayMatchId',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: categoryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Stage Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (stageStyle['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (stageStyle['color'] as Color).withOpacity(
                            0.3,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            stageStyle['emoji'] as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stage,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: stageStyle['color'] as Color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge with Icon
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isBye
                            ? Colors.purple.shade100
                            : isCompleted
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCompleted)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: Colors.green.shade700,
                            )
                          else if (isBye)
                            Icon(
                              Icons.block_rounded,
                              size: 12,
                              color: Colors.purple.shade700,
                            )
                          else
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isBye
                                  ? Colors.purple.shade700
                                  : isCompleted
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ Round info (if playoff)
                if (round.isNotEmpty && stage != 'League')
                  Column(
                    children: [
                      Text(
                        round,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),

                // ✅ Teams and Score
                if (!isBye)
                  Column(
                    children: [
                      // Team 1
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (team1['members'] as List<dynamic>? ?? []).join(
                                ', ',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isCompleted
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  categoryColor.withOpacity(0.15),
                                  categoryColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: categoryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              score1.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // VS
                      Center(
                        child: Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Team 2
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (team2['members'] as List<dynamic>? ?? []).join(
                                ', ',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isCompleted
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  categoryColor.withOpacity(0.15),
                                  categoryColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: categoryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              score2.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${team1['name'] as String? ?? 'Team'} - BYE',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // ✅ Date & Time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      date != null
                          ? DateFormat('MMM d').format(date.toDate())
                          : 'TBD',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ Standings Tab (without button)
  Widget _buildStandingsTab(String categoryName, Color categoryColor) {
    return StandingsWidget(
      tournamentId: widget.tournamentId,
      categoryId: categoryName,
      categoryColor: categoryColor,
    );
  }

  /// ✅ Handle league completion - Show playoff dialog
  Future<void> _handleLeagueComplete(
    String categoryName,
    Color categoryColor,
  ) async {
    try {
      setState(() => _isLoadingAction = true);

      final standings = await _playoffService.getLeagueStandings(
        widget.tournamentId,
        categoryName,
      );

      if (!mounted) return;

      final teamCount = standings.length;

      final choice = await _playoffService.showPlayoffChoiceDialog(
        context,
        teamCount,
      );

      if (choice == null) {
        setState(() => _isLoadingAction = false);
        return;
      }

      await _playoffService.createPlayoffs(
        widget.tournamentId,
        categoryName,
        choice,
        widget.startDate,
        widget.startTime,
        widget.matchDuration,
        widget.breakDuration,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Playoffs scheduled successfully!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Mark playoffs as generated for this category
      _playoffsGenerated[categoryName] = true;

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  /// ✅ Auto-generate finals after semi-finals
  Future<void> _autoGenerateFinals(String categoryName) async {
    try {
      setState(() => _isLoadingAction = true);

      final matches = await _service
          .getCategoryMatchesStream(widget.tournamentId, categoryName)
          .first;

      final semiMatches = matches
          .where((m) => (m['stage'] as String?) == 'Semi-Final')
          .toList();

      final finalsExist = matches.any(
        (m) => (m['stage'] as String?) == 'Final',
      );

      if (finalsExist) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Finals already created!'),
            backgroundColor: Colors.blue.shade600,
          ),
        );
        setState(() => _isLoadingAction = false);
        return;
      }

      if (semiMatches.length < 2) {
        throw Exception('Not all semi-finals are completed');
      }

      final winner1Id = semiMatches[0]['winner'] as String?;
      final winner2Id = semiMatches[1]['winner'] as String?;

      if (winner1Id == null || winner2Id == null) {
        throw Exception('Semi-final winners not determined');
      }

      final teams = await _service.getTeams(widget.tournamentId, categoryName);

      final team1 = teams.firstWhere(
        (t) => (t['id'] as String?) == winner1Id,
        orElse: () => {},
      );
      final team2 = teams.firstWhere(
        (t) => (t['id'] as String?) == winner2Id,
        orElse: () => {},
      );

      if (team1.isEmpty || team2.isEmpty) {
        throw Exception('Winner team data not found');
      }

      final finalMatch = {
        'id': '${categoryName}_Final_M1',
        'team1': {
          'id': team1['id'],
          'name': team1['name'],
          'members': List<String>.from(team1['players'] ?? []),
        },
        'team2': {
          'id': team2['id'],
          'name': team2['name'],
          'members': List<String>.from(team2['players'] ?? []),
        },
        'date': DateTime.now().add(const Duration(days: 3)),
        'time': '14:00',
        'status': 'Scheduled',
        'score1': 0,
        'score2': 0,
        'winner': null,
        'stage': 'Final',
        'roundName': 'Championship Match',
        'category': categoryName,
        'isBye': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _service.updateMatch(
        widget.tournamentId,
        categoryName,
        finalMatch['id'] as String,
        finalMatch,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Finals created successfully! ✨'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  /// ✅ Tournament winner card
  Widget _buildTournamentWinnerCard(
    List<Map<String, dynamic>> matches,
    Color categoryColor,
  ) {
    final finalMatch = matches.firstWhere(
      (m) => (m['stage'] as String?) == 'Final',
    );
    final winnerId = finalMatch['winner'] as String?;
    final winnerTeam = winnerId == (finalMatch['team1']['id'] as String?)
        ? finalMatch['team1']
        : finalMatch['team2'];

    return ScaleTransition(
      scale: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade600, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Text('🏆', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tournament Winner',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              winnerTeam['name'] as String? ?? 'Champion',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Team Members',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (winnerTeam['members'] as List<dynamic>? ?? []).join(', '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      '🎉 Congratulations to the champions! 🎉',
                    ),
                    backgroundColor: Colors.green.shade600,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '🎊 Celebrate 🎊',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStageStyle(String stage) {
    switch (stage) {
      case 'League':
        return {
          'color': Colors.blue,
          'emoji': '⚽',
          'borderColor': Colors.blue.withOpacity(0.3),
        };
      case 'Semi-Final':
        return {
          'color': Colors.orange,
          'emoji': '🥊',
          'borderColor': Colors.orange.withOpacity(0.3),
        };
      case 'Final':
        return {
          'color': Colors.amber,
          'emoji': '🏆',
          'borderColor': Colors.amber.withOpacity(0.3),
        };
      default:
        return {
          'color': Colors.grey,
          'emoji': '🎯',
          'borderColor': Colors.grey.withOpacity(0.3),
        };
    }
  }

  void _openScorecard(Map<String, dynamic> match, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchScorecardScreen(
          tournamentId: widget.tournamentId,
          categoryId: categoryName,
          match: match,
          tournamentFormat: widget.tournamentFormat,
        ),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {});
      }
    });
  }
}
