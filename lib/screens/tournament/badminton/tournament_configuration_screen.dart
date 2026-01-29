import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/screens/tournament/badminton/team_review_&_customization_screen.dart';

class TournamentConfigScreen extends StatefulWidget {
  final List<String> members;
  final String teamType;

  const TournamentConfigScreen({
    super.key,
    required this.members,
    required this.teamType,
  });

  @override
  State<TournamentConfigScreen> createState() => _TournamentConfigScreenState();
}

class _TournamentConfigScreenState extends State<TournamentConfigScreen> {
  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  int totalMatches = 1;
  int breakBetweenMatches = 10;
  int matchDuration = 20;
  bool allowRematches = false;
  int? customTeamSize;
  int rematches = 1;

  String tournamentFormat = "round_robin";

  @override
  void initState() {
    super.initState();
    if (widget.teamType == 'Custom') {
      final configs = _getValidTeamConfigurations();
      if (configs.isNotEmpty) {
        customTeamSize = configs[configs.length ~/ 2];
      }
    }

    if (!allowRematches) {
      totalMatches = _getBaseMaxMatches();
    } else {
      rematches = 1;
      totalMatches = _getBaseMaxMatches();
    }
  }

  List<int> _getValidTeamConfigurations() {
    List<int> validConfigs = [];
    int totalMembers = widget.members.length;

    for (int teamSize = 2; teamSize <= totalMembers ~/ 2; teamSize++) {
      if (totalMembers % teamSize == 0) {
        int numTeams = totalMembers ~/ teamSize;
        if (numTeams >= 2) {
          validConfigs.add(teamSize);
        }
      }
    }

    return validConfigs;
  }

  int _getBaseMaxMatches() {
    final teamsCount = _getTeamsCount();
    if (teamsCount < 2) return 0;

    if (tournamentFormat == "knockout") {
      return teamsCount - 1;
    }

    if (widget.teamType == 'Singles' || widget.teamType == 'Doubles') {
      return (teamsCount * (teamsCount - 1)) ~/ 2;
    } else {
      final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
      final pairsPerTeam = _getPairsPerTeam(teamSize);
      final teamMatchups = (teamsCount * (teamsCount - 1)) ~/ 2;
      return teamMatchups * pairsPerTeam * pairsPerTeam;
    }
  }

  int _getCurrentMaxMatches() {
    final baseMax = _getBaseMaxMatches();
    return allowRematches ? baseMax * rematches : baseMax;
  }

  int _getTeamsCount() {
    if (widget.teamType == 'Singles') {
      return widget.members.length;
    } else if (widget.teamType == 'Doubles') {
      return widget.members.length ~/ 2;
    } else {
      final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
      return widget.members.length ~/ teamSize;
    }
  }

  int _getPairsPerTeam(int teamSize) {
    return (teamSize * (teamSize - 1)) ~/ 2;
  }

  String _getMinimumRequirement() {
    if (widget.teamType == 'Singles') {
      return '2 players to create a tournament';
    } else if (widget.teamType == 'Doubles') {
      return '4 members (2 teams) to create a tournament';
    } else {
      final validConfigs = _getValidTeamConfigurations();
      if (validConfigs.isEmpty) {
        return '4 members minimum (2 teams of 2) to create a tournament';
      }
      final minSize = validConfigs.first;
      final minMembers = minSize * 2;
      return '$minMembers members (2 teams) to create a tournament';
    }
  }

  String _getTeamInfo() {
    final teamsCount = _getTeamsCount();
    final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
    final pairsPerteam = _getPairsPerTeam(teamSize);

    final validConfigs = _getValidTeamConfigurations();
    String configOptions = '';

    if (validConfigs.length > 1) {
      configOptions = '\nAvailable: ';
      for (int i = 0; i < validConfigs.length; i++) {
        final size = validConfigs[i];
        final teams = widget.members.length ~/ size;
        configOptions += '$teams×$size';
        if (i < validConfigs.length - 1) configOptions += ', ';
      }
    }

    return '$teamsCount teams × $teamSize members each ($pairsPerteam pairs per team)$configOptions';
  }

  int _calculateTotalMatchesMaximum() {
    final teamsCount = _getTeamsCount();
    if (teamsCount < 2) return 0;

    if (tournamentFormat == "knockout") {
      return teamsCount - 1;
    }

    if (widget.teamType == 'Singles') {
      int uniquePairs = (teamsCount * (teamsCount - 1)) ~/ 2;
      return allowRematches ? uniquePairs * rematches : uniquePairs;
    } else if (widget.teamType == 'Doubles') {
      int uniquePairs = (teamsCount * (teamsCount - 1)) ~/ 2;
      return allowRematches ? uniquePairs * rematches : uniquePairs;
    } else {
      final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
      final pairsPerTeam = _getPairsPerTeam(teamSize);
      final teamMatchups = (teamsCount * (teamsCount - 1)) ~/ 2;
      int matchesPerTeamMatchup = pairsPerTeam * pairsPerTeam;
      int totalMatches = teamMatchups * matchesPerTeamMatchup;

      return allowRematches ? totalMatches * rematches : totalMatches;
    }
  }

  void _incrementTeamSize() {
    setState(() {
      totalMatches = _getCurrentMaxMatches();
      final validConfigs = _getValidTeamConfigurations();
      if (validConfigs.isEmpty) return;

      final currentSize = customTeamSize ?? validConfigs[0];
      final currentIndex = validConfigs.indexOf(currentSize);

      if (currentIndex < validConfigs.length - 1) {
        customTeamSize = validConfigs[currentIndex + 1];
      }
    });
  }

  void _decrementTeamSize() {
    setState(() {
      totalMatches = _getCurrentMaxMatches();
      final validConfigs = _getValidTeamConfigurations();
      if (validConfigs.isEmpty) return;

      final currentSize = customTeamSize ?? validConfigs[0];
      final currentIndex = validConfigs.indexOf(currentSize);

      if (currentIndex > 0) {
        customTeamSize = validConfigs[currentIndex - 1];
      }
    });
  }

  void _generateSchedule() {
    if (_getTeamsCount() < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(_getMinimumRequirement()),
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
      return;
    }
    if (widget.teamType.toLowerCase() != 'custom') {
      totalMatches = _calculateTotalMatchesMaximum();
    }
    debugPrint('total matches : $totalMatches');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamReviewScreen(
          members: widget.members,
          teamType: widget.teamType,
          rematches: rematches,
          startDate: selectedDate,
          startTime: startTime,
          matchDuration: matchDuration,
          breakDuration: breakBetweenMatches,
          totalMatches: totalMatches,
          allowRematches: allowRematches,
          customTeamSize: customTeamSize,
          tournamentFormat: tournamentFormat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var maxMatches = _calculateTotalMatchesMaximum();
    final teamsCount = _getTeamsCount();

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
              'Tournament Setup',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Configure tournament settings',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FORMAT SELECTION
              if (widget.teamType != 'Custom') ...[
                _buildSectionTitle('Tournament Format'),
                const SizedBox(height: 12),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.orange.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.shade200,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.04).toInt()),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              tournamentFormat = 'round_robin';
                              allowRematches = true;
                              HapticFeedback.lightImpact();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: tournamentFormat == 'round_robin'
                                  ? LinearGradient(
                                      colors: [
                                        Colors.orange.shade600,
                                        Colors.deepOrange.shade500,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                              ),
                              boxShadow: tournamentFormat == 'round_robin'
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.shade400.withAlpha(
                                          (255 * 0.3).toInt(),
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'ROUND ROBIN',
                                style: TextStyle(
                                  color: tournamentFormat == 'round_robin'
                                      ? Colors.white
                                      : Colors.orange.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              tournamentFormat = 'knockout';
                              allowRematches = false;
                              totalMatches = _getBaseMaxMatches();
                              HapticFeedback.lightImpact();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: tournamentFormat == 'knockout'
                                  ? LinearGradient(
                                      colors: [
                                        Colors.orange.shade600,
                                        Colors.deepOrange.shade500,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                              ),
                              boxShadow: tournamentFormat == 'knockout'
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.shade400.withAlpha(
                                          (255 * 0.3).toInt(),
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'KNOCKOUT',
                                style: TextStyle(
                                  color: tournamentFormat == 'knockout'
                                      ? Colors.white
                                      : Colors.orange.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // SUMMARY CARD
              _buildSummaryCard(
                icon: Icons.people,
                title: widget.teamType == 'Singles' ? 'Players' : 'Teams',
                value: teamsCount.toString(),
                subtitle: widget.teamType,
                color: Colors.blue,
                showTeamSizeControls: widget.teamType == 'Custom',
              ),
              const SizedBox(height: 20),

              // ERROR BOX
              if (teamsCount < 2)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You need at least ${_getMinimumRequirement()}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // DATE & TIME
              _buildSectionTitle('Date & Time'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDateSelector()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimeSelector()),
                ],
              ),
              const SizedBox(height: 24),

              // REMATCHES
              _buildSectionTitle('Match Rules'),
              const SizedBox(height: 12),
              _buildMatchRulesCard(),
              const SizedBox(height: 12),

              if (tournamentFormat == "round_robin" && allowRematches) ...[
                _buildSliderCard(
                  value: rematches.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: rematches.toString(),
                  onChanged: (value) {
                    setState(() {
                      rematches = value.toInt();
                    });
                  },
                  suffix: rematches == 1 ? 'match' : 'matches',
                  helperText: 'Number of rematches against every other team.',
                ),
                const SizedBox(height: 20),
              ],

              // CUSTOM TEAM MATCHES
              if (widget.teamType == "Custom") ...[
                _buildSectionTitle('Total Matches'),
                const SizedBox(height: 12),
                _buildSliderCard(
                  value: totalMatches.toDouble().clamp(
                    1.0,
                    maxMatches.toDouble(),
                  ),
                  min: 1.0,
                  max: (maxMatches >= 1 ? maxMatches.toDouble() : 1.0),
                  divisions: maxMatches > 1 ? maxMatches - 1 : 1,
                  label: totalMatches.toString(),
                  onChanged: maxMatches >= 1
                      ? (value) {
                          setState(() {
                            totalMatches = value.toInt().clamp(1, maxMatches);
                          });
                        }
                      : null,
                  suffix: 'matches',
                  helperText: allowRematches
                      ? 'Up to $maxMatches matches with rematches'
                      : 'Up to ${_getBaseMaxMatches()} matches (no rematches)',
                ),
                const SizedBox(height: 20),
              ] else if (tournamentFormat == 'round_robin') ...[
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_rounded,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$teamsCount teams : ${_calculateTotalMatchesMaximum()} matches\n$rematches matchup vs every other team',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // MATCH DURATION
              _buildSectionTitle('Match Duration'),
              const SizedBox(height: 12),
              _buildSliderCard(
                value: matchDuration.toDouble(),
                min: 15,
                max: 45,
                divisions: 6,
                label: matchDuration.toString(),
                onChanged: (value) {
                  setState(() {
                    matchDuration = value.toInt();
                  });
                },
                suffix: 'minutes',
              ),
              const SizedBox(height: 20),

              // BREAK BETWEEN MATCHES
              _buildSectionTitle('Break Between Matches'),
              const SizedBox(height: 12),
              _buildSliderCard(
                value: breakBetweenMatches.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                label: breakBetweenMatches.toString(),
                onChanged: (value) {
                  setState(() {
                    breakBetweenMatches = value.toInt();
                  });
                },
                suffix: 'minutes',
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: teamsCount >= 2
                  ? LinearGradient(
                      colors: [
                        Colors.orange.shade600,
                        Colors.deepOrange.shade500,
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: teamsCount >= 2
                  ? [
                      BoxShadow(
                        color: Colors.orange.withAlpha((255 * 0.3).toInt()),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: teamsCount >= 2 ? _generateSchedule : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: teamsCount >= 2
                      ? Colors.transparent
                      : Colors.grey.shade300,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: teamsCount >= 2
                          ? Colors.white
                          : Colors.grey.shade500,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Next Step',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: teamsCount >= 2
                            ? Colors.white
                            : Colors.grey.shade500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required bool showTeamSizeControls,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((255 * 0.25).toInt()),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.04).toInt()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha((255 * 0.12).toInt()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (showTeamSizeControls)
                      GestureDetector(
                        onTap: _decrementTeamSize,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withAlpha((255 * 0.12).toInt()),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            color: color,
                            size: 18,
                          ),
                        ),
                      ),
                    if (showTeamSizeControls) const SizedBox(width: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (showTeamSizeControls) const SizedBox(width: 8),
                    if (showTeamSizeControls)
                      GestureDetector(
                        onTap: _incrementTeamSize,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withAlpha((255 * 0.12).toInt()),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: color,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (showTeamSizeControls)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _getTeamInfo().split('\n')[0],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRulesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allowRematches ? Colors.orange.shade200 : Colors.blue.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.04).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: allowRematches
                  ? Colors.orange.shade50
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              allowRematches ? Icons.repeat_rounded : Icons.shuffle_rounded,
              color: allowRematches
                  ? Colors.orange.shade600
                  : Colors.blue.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allow Rematches',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  allowRematches
                      ? 'Teams can play multiple times'
                      : 'Each matchup only once',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: allowRematches,
            activeTrackColor: Colors.orange.shade600,
            activeColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
            inactiveThumbColor: Colors.white,
            onChanged: (tournamentFormat == "knockout")
                ? null
                : (value) {
                    setState(() {
                      allowRematches = value;
                      final maxMatches = _getBaseMaxMatches();
                      rematches = allowRematches ? rematches : 1;
                      totalMatches = allowRematches ? totalMatches : maxMatches;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: Colors.orange.shade600),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.04).toInt()),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.orange.shade600,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d').format(selectedDate),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: startTime,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(primary: Colors.orange.shade600),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => startTime = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.04).toInt()),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.orange.shade600,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              startTime.format(context),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderCard({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    Function(double)? onChanged,
    required String suffix,
    String? helperText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.04).toInt()),
            blurRadius: 8,
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
                label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  suffix,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.orange.shade600,
              inactiveTrackColor: Colors.orange.shade100,
              thumbColor: Colors.orange.shade600,
              overlayColor: Colors.orange.shade200.withAlpha(
                (255 * 0.3).toInt(),
              ),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
