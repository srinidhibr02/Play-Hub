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
  int breakBetweenMatches = 15;
  int matchDuration = 15;
  bool allowRematches = false;
  int? customTeamSize;
  int rematches = 1;

  String tournamentFormat = "round_robin"; // "round_robin" or "knockout"

  @override
  void initState() {
    super.initState();
    if (widget.teamType == 'Custom') {
      customTeamSize = widget.members.length ~/ 2;
      if (customTeamSize! < 2) customTeamSize = 2;
    }

    final teamsCount = _getTeamsCount();
    final maxMatches = allowRematches
        ? _getMaxMatchesPerTeam()
        : (teamsCount > 1 ? teamsCount - 1 : 1);
    if (!allowRematches) {
      rematches = maxMatches;
    } else if (rematches > maxMatches) {
      rematches = maxMatches;
    }
  }

  int _getBaseMaxMatches() {
    // Calculate max WITHOUT rematches (rematches = 1)
    final teamsCount = _getTeamsCount();
    if (teamsCount < 2) return 0;

    if (tournamentFormat == "knockout") {
      return teamsCount - 1;
    }

    if (widget.teamType == 'Singles' || widget.teamType == 'Doubles') {
      return (teamsCount * (teamsCount - 1)) ~/ 2;
    } else {
      // Custom: your pair logic without rematches multiplier
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

  @override
  Widget build(BuildContext context) {
    var maxMatches = _calculateTotalMatchesMaximum();
    final teamsCount = _getTeamsCount();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade600,
        elevation: 0,
        title: const Text(
          'Tournament Setup',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FORMAT SELECTION
            _buildSectionTitle('Tournament Format'),
            const SizedBox(height: 10),
            Container(
              height: 56, // ✅ Taller for modern feel
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28), // ✅ Softer corners
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1.5, // ✅ Thicker, premium border
                ),
                boxShadow: [
                  // ✅ Subtle glassmorphism shadow
                  BoxShadow(
                    color: Colors.orange.shade100,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Round Robin Tab ✅
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          tournamentFormat = 'round_robin';
                          allowRematches = true;
                          HapticFeedback.lightImpact(); // ✅ iOS/Android haptic
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: tournamentFormat == 'round_robin'
                              ? LinearGradient(
                                  colors: [
                                    Colors.orange.shade600,
                                    Colors.orange.shade700,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            bottomLeft: Radius.circular(28),
                          ),
                          boxShadow: tournamentFormat == 'round_robin'
                              ? [
                                  BoxShadow(
                                    color: Colors.orange.shade400.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'ROUND ROBIN', // ✅ ALL CAPS modern
                            style: TextStyle(
                              color: tournamentFormat == 'round_robin'
                                  ? Colors.white
                                  : Colors.orange.shade900,
                              fontWeight: FontWeight.w700, // ✅ Bolder
                              fontSize: 13, // ✅ Compact modern
                              letterSpacing: 0.5, // ✅ Letter spacing
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Knockout Tab ✅
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          tournamentFormat = 'knockout';
                          allowRematches = false;
                          totalMatches = _getBaseMaxMatches();
                          HapticFeedback.lightImpact(); // ✅ Haptic feedback
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: tournamentFormat == 'knockout'
                              ? LinearGradient(
                                  colors: [
                                    Colors.orange.shade600,
                                    Colors.orange.shade700,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                          boxShadow: tournamentFormat == 'knockout'
                              ? [
                                  BoxShadow(
                                    color: Colors.orange.shade400.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            'KNOCKOUT', // ✅ ALL CAPS modern
                            style: TextStyle(
                              color: tournamentFormat == 'knockout'
                                  ? Colors.white
                                  : Colors.orange.shade900,
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

            const SizedBox(height: 15),

            _buildSummaryCard(
              icon: Icons.people,
              title: widget.teamType == 'Singles' ? 'Players' : 'Teams',
              value: teamsCount.toString(),
              subtitle: widget.teamType,
              color: Colors.blue,
              showTeamSizeControls: widget.teamType == 'Custom',
            ),
            const SizedBox(height: 16),

            if (teamsCount < 2)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You need at least ${_getMinimumRequirement()}',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            _buildSectionTitle('Tournament Date'),
            const SizedBox(height: 12),
            _buildDateSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('Start Time'),
            const SizedBox(height: 12),
            _buildTimeSelector(),
            const SizedBox(height: 24),

            _buildSectionTitle('Match Rules'),
            const SizedBox(height: 12),
            _buildMatchRulesCard(),
            const SizedBox(height: 24),
            // Show rematch & match slider ONLY for round robin/league format
            if (tournamentFormat == "round_robin" && allowRematches) ...[
              _buildSectionTitle('Rematches against Same Team'),
              const SizedBox(height: 24),
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
            ],

            if (widget.teamType == 'Custom') ...[
              const SizedBox(height: 24),
              _buildSectionTitle('NO Consecutive Matches for Same Player'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.green.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Scheduling will ensure no player plays consecutive matches, guaranteeing breaks in between. (You\'ll see the scheduled format and breaks preview in the next step.)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            _buildSectionTitle('Total Number of Matches'),
            SizedBox(height: 12),
            _buildSliderCard(
              value: totalMatches.toDouble(), // ✅ Auto-updates from switch
              min: 1,
              max: maxMatches.toDouble(), // ✅ Dynamic max
              divisions: maxMatches - 1,
              label: totalMatches.toString(),
              onChanged: (value) {
                setState(() {
                  totalMatches = value.toInt().clamp(1, maxMatches);
                });
              },
              suffix: 'matches',
              helperText: allowRematches
                  ? 'Up to $maxMatches matches with rematches'
                  : 'Up to ${_getBaseMaxMatches()} matches (no rematches)',
            ),

            const SizedBox(height: 32),
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

            const SizedBox(height: 24),
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
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: teamsCount >= 2 ? _generateSchedule : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: teamsCount >= 2
                          ? Colors.white
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Next Step',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: teamsCount >= 2
                            ? Colors.white
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      ),
    );
  }

  Widget _buildMatchRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allowRematches ? Colors.orange.shade200 : Colors.blue.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              allowRematches ? Icons.repeat : Icons.shuffle,
              color: allowRematches
                  ? Colors.orange.shade600
                  : Colors.blue.shade600,
              size: 24,
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allowRematches
                      ? 'Teams can play multiple times'
                      : 'Each matchup only once',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: allowRematches,
            activeTrackColor: Colors.orange.shade600,
            inactiveTrackColor: Colors.orange.shade100,
            onChanged: (tournamentFormat == "knockout")
                ? null
                : (value) {
                    setState(() {
                      allowRematches = value;
                      final maxMatches = _getBaseMaxMatches();
                      totalMatches = allowRematches ? totalMatches : maxMatches;
                    });
                  },
          ),
        ],
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
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (showTeamSizeControls)
                      IconButton(
                        onPressed: _incrementTeamSize,
                        icon: Icon(Icons.remove_circle, color: color),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),

                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (showTeamSizeControls)
                      IconButton(
                        onPressed: _decrementTeamSize,
                        icon: Icon(Icons.add_circle, color: color),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                if (showTeamSizeControls)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _getTeamInfo(),
                      style: TextStyle(
                        fontSize: 12,
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

  void _incrementTeamSize() {
    setState(() {
      final currentSize = customTeamSize ?? (widget.members.length ~/ 2);
      final newSize = currentSize + 1;
      if (widget.members.length ~/ newSize >= 2) customTeamSize = newSize;
    });
  }

  void _decrementTeamSize() {
    setState(() {
      final currentSize = customTeamSize ?? (widget.members.length ~/ 2);
      if (currentSize > 2) customTeamSize = currentSize - 1;
    });
  }

  String _getTeamInfo() {
    final teamsCount = _getTeamsCount();
    final teamSize = widget.members.length ~/ teamsCount;
    final pairsPerteam = _getPairsPerTeam(teamSize);
    debugPrint(
      'Calculating team info: teamsCount=$teamsCount, teamSize=$teamSize',
    );
    return '$teamsCount teams × $teamSize members each ($pairsPerteam pairs per team)';
  }

  String _getMinimumRequirement() {
    if (widget.teamType == 'Singles') {
      return '2 players to create a tournament';
    } else if (widget.teamType == 'Doubles') {
      return '4 members (2 teams) to create a tournament';
    } else {
      final minMembers = (customTeamSize ?? 2) * 2;
      return '$minMembers members (2 teams) to create a tournament';
    }
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            Text(
              startTime.format(context),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade600,
                ),
              ),
              Text(
                suffix,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              helperText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.orange.shade600,
              inactiveTrackColor: Colors.orange.shade100,
              thumbColor: Colors.orange.shade600,
              overlayColor: Colors.orange.shade200.withOpacity(0.3),
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

  int _calculateTotalMatchesMaximum() {
    final teamsCount = _getTeamsCount();
    if (teamsCount < 2) return 0;

    if (tournamentFormat == "knockout") {
      // Single elimination: (n-1) matches for n teams
      return teamsCount - 1;
    }

    if (widget.teamType == 'Singles') {
      int uniquePairs = (teamsCount * (teamsCount - 1)) ~/ 2;
      return allowRematches ? uniquePairs * rematches : uniquePairs;
    } else if (widget.teamType == 'Doubles') {
      int uniquePairs = (teamsCount * (teamsCount - 1)) ~/ 2;
      return allowRematches ? uniquePairs * rematches : uniquePairs;
    } else {
      debugPrint('Custom team type selected.');
      final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
      final pairsPerTeam = _getPairsPerTeam(teamSize);
      final teamMatchups = (teamsCount * (teamsCount - 1)) ~/ 2;
      debugPrint(
        'TeamsCount: $teamsCount, TeamSize: $teamSize, PairsPerTeam: $pairsPerTeam, TeamMatchups: $teamMatchups',
      );
      int matchesPerTeamMatchup = pairsPerTeam * pairsPerTeam;
      int totalMatches = teamMatchups * matchesPerTeamMatchup;

      return allowRematches ? totalMatches * rematches : totalMatches;
    }
  }

  int _getMaxMatchesPerTeam() {
    int teamsCount = _getTeamsCount();
    if (teamsCount < 2) return 1;
    return teamsCount - 1;
  }

  String _calculateTotalDuration() {
    int totalMatches = _calculateTotalMatchesMaximum();
    if (totalMatches == 0) return '0m';

    int totalMinutes =
        (totalMatches * matchDuration) +
        ((totalMatches - 1) * breakBetweenMatches);
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  void _generateSchedule() {
    if (_getTeamsCount() < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getMinimumRequirement()),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamReviewScreen(
          members: widget.members,
          teamType: widget.teamType,
          matchesPerTeam: 0,
          startDate: selectedDate,
          startTime: startTime,
          matchDuration: matchDuration,
          breakDuration: breakBetweenMatches,
          allowRematches: allowRematches,
          customTeamSize: customTeamSize,
          tournamentFormat: tournamentFormat,
        ),
      ),
    );
    // Object data = {
    //   'members': widget.members,
    //   'teamType': widget.teamType,
    //   'rematches': rematches,
    //   'startDate': selectedDate,
    //   'startTime': startTime,
    //   'matchDuration': matchDuration,
    //   'breakDuration': breakBetweenMatches,
    //   'totalMatches': totalMatches,
    //   'allowRematches': allowRematches,
    //   'customTeamSize': customTeamSize,
    //   'tournamentFormat': tournamentFormat,
    // };
    // debugPrint('Navigating to TeamReviewScreen with data: $data');
  }
}
