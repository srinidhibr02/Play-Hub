import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:play_hub/screens/clubTournament/badminton_club_tournament/knockout_match_scorecard_screen.dart';
import 'package:play_hub/screens/clubTournament/club_service/club_tournament_service.dart';
import 'package:play_hub/screens/clubTournament/club_service/knockout_match_service.dart';

class KnockoutScheduleScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final DateTime startDate;
  final TimeOfDay startTime;
  final int matchDuration;
  final int breakDuration;
  final bool isBestOf3;

  const KnockoutScheduleScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.startDate,
    required this.startTime,
    required this.matchDuration,
    required this.breakDuration,
    required this.isBestOf3,
  });

  @override
  State<KnockoutScheduleScreen> createState() => _KnockoutScheduleScreenState();
}

class _KnockoutScheduleScreenState extends State<KnockoutScheduleScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  final _service = ClubTournamentService();
  final _knockoutService = KnockoutTournamentService();
  int _selectedCategoryIndex = 0;
  String? _selectedRound;

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
            'Knockout Tournament',
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
            'Loading tournament...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
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
            'Error Loading Tournament',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade700,
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
              Icons.sports_baseball_rounded,
              size: 64,
              color: Colors.teal.shade300,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Categories',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
            ),
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

    return Column(
      children: [
        _buildCategorySelector(categories),
        _buildCategoryInfoCard(selected, categoryColor),
        Expanded(child: _buildCategoryContent(categoryName, categoryColor)),
      ],
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
              onTap: () => setState(() => _selectedCategoryIndex = index),
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
    final icon = _getCategoryIcon(categoryName);

    return FadeTransition(
      opacity: _fadeController,
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
                        widget.isBestOf3 ? 'Best of 3' : 'Single Match',
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
                    icon: Icons.emoji_events_rounded,
                    label: 'Format',
                    value: 'Knockout',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoStat(
                    icon: Icons.sports_tennis_rounded,
                    label: 'Type',
                    value: widget.isBestOf3 ? 'Best of 3' : 'Single',
                  ),
                ),
              ],
            ),
          ],
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
              fontSize: 13,
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getTeams(widget.tournamentId, categoryName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: categoryColor));
        }

        // Fetch current round
        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('tournaments')
              .doc(widget.tournamentId)
              .collection('categoryTournaments')
              .doc(categoryName)
              .snapshots(),
          builder: (context, roundSnapshot) {
            if (!roundSnapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: categoryColor),
              );
            }

            final currentRound =
                roundSnapshot.data?.get('currentRound') as String? ??
                'Quarter-Finals';
            _selectedRound = _selectedRound ?? currentRound;

            return Column(
              children: [
                // Round Selector
                _buildRoundSelector(currentRound, categoryColor),

                // Matches Tab
                Expanded(
                  child: _buildMatchesTab(
                    categoryName,
                    _selectedRound ?? currentRound,
                    categoryColor,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRoundSelector(String currentRound, Color categoryColor) {
    final rounds = ['Quarter-Finals', 'Semi-Finals', 'Finals'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Round: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            ...rounds.map((round) {
              final isSelected = _selectedRound == round;
              return GestureDetector(
                onTap: () => setState(() => _selectedRound = round),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? categoryColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? categoryColor : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    round,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  final _firestore = FirebaseFirestore.instance;

  Widget _buildMatchesTab(
    String categoryName,
    String roundName,
    Color categoryColor,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _knockoutService.getCurrentRoundMatches(
        widget.tournamentId,
        categoryName,
        roundName,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: categoryColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No matches in $roundName',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return _buildMatchCard(match, index, categoryName, categoryColor);
          },
        );
      },
    );
  }

  Widget _buildMatchCard(
    Map<String, dynamic> match,
    int index,
    String categoryName,
    Color categoryColor,
  ) {
    final team1 = match['team1'] as Map<String, dynamic>;
    final team2 = match['team2'] as Map<String, dynamic>;
    final status = match['status'] as String? ?? 'Scheduled';
    final score1 = match['score1'] as int? ?? 0;
    final score2 = match['score2'] as int? ?? 0;
    final isBestOf3 = match['isBestOf3'] as bool? ?? false;
    final isCompleted = status == 'Completed';

    return GestureDetector(
      onTap: () => _openScorecard(match, categoryName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    match['id'] as String? ?? 'Match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team1['members'].join(', ') as String? ?? 'Team 1',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                    ),
                    child: Text(
                      isBestOf3 ? '$score1-$score2' : '$score1-$score2',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          team2['members'].join(', ') as String? ?? 'Team 2',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isBestOf3)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Best of 3 Series',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScorecard(Map<String, dynamic> match, String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedMatchScorecardScreen(
          tournamentId: widget.tournamentId,
          categoryId: categoryName,
          match: match,
          tournamentFormat: 'knockout',
          isBestOf3: widget.isBestOf3,
        ),
      ),
    ).then((result) {
      if (result == true) {
        setState(() {});
      }
    });
  }
}
