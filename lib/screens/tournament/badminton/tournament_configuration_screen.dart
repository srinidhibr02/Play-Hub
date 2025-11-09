import 'package:flutter/material.dart';
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
  int matchesPerTeam = 1;
  int breakBetweenMatches = 15;
  int matchDuration = 30;
  bool allowRematches = false;
  int? customTeamSize;

  @override
  void initState() {
    super.initState();
    // Initialize custom team size for Custom type to create 2 teams initially
    if (widget.teamType != 'Singles' && widget.teamType != 'Doubles') {
      customTeamSize = widget.members.length ~/ 2;
      // Ensure minimum team size of 2 for doubles format
      if (customTeamSize! < 2) {
        customTeamSize = 2;
      }
    }

    final teamsCount = _getTeamsCount();
    final maxMatches = allowRematches
        ? _getMaxMatchesPerTeam()
        : (teamsCount > 1 ? teamsCount - 1 : 1);
    if (!allowRematches) {
      matchesPerTeam = maxMatches;
    } else if (matchesPerTeam > maxMatches) {
      matchesPerTeam = maxMatches;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMatches = _calculateTotalMatches();
    final estimatedDuration = _calculateTotalDuration();
    int teamsCount = _getTeamsCount();

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
            // Teams/Players card with +/- controls for custom team size
            _buildSummaryCard(
              icon: Icons.people,
              title: widget.teamType == 'Singles' ? 'Players' : 'Teams',
              value: teamsCount.toString(),
              subtitle: widget.teamType,
              color: Colors.blue,
              showTeamSizeControls:
                  widget.teamType != 'Singles' && widget.teamType != 'Doubles',
            ),
            const SizedBox(height: 16),

            // Warning if not enough teams
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

            if (allowRematches) ...[
              _buildSectionTitle(
                widget.teamType == 'Singles'
                    ? 'Re-matches with each Player'
                    : 'Re-matches against each Team',
              ),
              const SizedBox(height: 12),
              _buildSliderCard(
                value: matchesPerTeam.toDouble(),
                min: 1,
                max: _getMaxMatchesPerTeam().toDouble(),
                divisions: _getMaxMatchesPerTeam() > 1
                    ? _getMaxMatchesPerTeam() - 1
                    : 1,
                label: matchesPerTeam.toString(),
                onChanged: (value) {
                  setState(() {
                    matchesPerTeam = value.toInt();
                  });
                },
                suffix: matchesPerTeam == 1 ? 'match' : 'matches',
                helperText:
                    'Number of times each team plays every other team (rematches allowed)',
              ),
            ],

            const SizedBox(height: 24),
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
              min: 10,
              max: 90,
              divisions: 8,
              label: matchDuration.toString(),
              onChanged: (value) {
                setState(() {
                  matchDuration = value.toInt();
                });
              },
              suffix: 'minutes',
            ),
            const SizedBox(height: 32),

            // Tournament Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade600, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade300.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Tournament Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Total Matches',
                        totalMatches.toString(),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _buildSummaryItem('Duration', estimatedDuration),
                    ],
                  ),
                  if (widget.teamType != 'Singles' &&
                      widget.teamType != 'Doubles' &&
                      teamsCount >= 2) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getMatchFormatInfo(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Next Step Button
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
      child: Column(
        children: [
          Row(
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: allowRematches,
                activeTrackColor: Colors.orange.shade600,
                inactiveTrackColor: Colors.orange.shade100,
                onChanged: (value) {
                  setState(() {
                    allowRematches = value;
                    final maxMatches = _getMaxMatchesPerTeam();
                    if (matchesPerTeam > maxMatches) {
                      matchesPerTeam = maxMatches;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: allowRematches
                  ? Colors.orange.shade50
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  allowRematches
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
                  color: allowRematches
                      ? Colors.orange.shade700
                      : Colors.blue.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allowRematches
                        ? 'Perfect for more matches with fewer teams. Teams will face each other multiple times to reach the target match count.'
                        : 'Round-robin format. Each team plays every other team exactly once for fair competition.',
                    style: TextStyle(
                      fontSize: 11,
                      color: allowRematches
                          ? Colors.orange.shade900
                          : Colors.blue.shade900,
                      height: 1.3,
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
                        onPressed: _decrementTeamSize,
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
                        onPressed: _incrementTeamSize,
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

      // Check if new size would create at least 2 teams
      if (widget.members.length ~/ newSize >= 2) {
        customTeamSize = newSize;
      }
    });
  }

  void _decrementTeamSize() {
    setState(() {
      final currentSize = customTeamSize ?? (widget.members.length ~/ 2);

      // Minimum team size is 2 for doubles format
      if (currentSize > 2) {
        customTeamSize = currentSize - 1;
      }
    });
  }

  String _getTeamInfo() {
    final teamsCount = _getTeamsCount();
    final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
    final pairsPerTeam = _getPairsPerTeam(teamSize);

    return '$teamsCount teams × $teamSize members ($pairsPerTeam doubles pairs each)';
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

  String _getMatchFormatInfo() {
    final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
    final pairsPerTeam = _getPairsPerTeam(teamSize);

    return 'Each doubles pair from one team plays every doubles pair from opposing teams ($pairsPerTeam pairs per team)';
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

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
        ),
      ],
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
    // C(n, 2) = n × (n-1) / 2
    return (teamSize * (teamSize - 1)) ~/ 2;
  }

  int _calculateTotalMatches() {
    final int teamsCount = _getTeamsCount();
    if (teamsCount < 2) return 0;

    if (widget.teamType == 'Singles') {
      // Singles: Simple combinations
      int uniquePairs = (teamsCount * (teamsCount - 1)) ~/ 2;
      return allowRematches ? uniquePairs * matchesPerTeam : uniquePairs;
    } else if (widget.teamType == 'Doubles') {
      // Doubles: Standard team vs team
      int uniquePairs = (teamsCount * (teamsCount - 1)) ~/ 2;
      return allowRematches ? uniquePairs * matchesPerTeam : uniquePairs;
    } else {
      // Custom: Doubles-within-teams format
      final teamSize = customTeamSize ?? (widget.members.length ~/ 2);
      final pairsPerTeam = _getPairsPerTeam(teamSize);
      final teamMatchups = (teamsCount * (teamsCount - 1)) ~/ 2;

      // Each team matchup involves all possible doubles pairs playing each other
      int matchesPerTeamMatchup = pairsPerTeam * pairsPerTeam;
      int totalMatches = teamMatchups * matchesPerTeamMatchup;

      return allowRematches ? totalMatches * matchesPerTeam : totalMatches;
    }
  }

  int _getMaxMatchesPerTeam() {
    int teamsCount = _getTeamsCount();
    if (teamsCount < 2) return 1;
    return teamsCount - 1;
  }

  String _calculateTotalDuration() {
    int totalMatches = _calculateTotalMatches();
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
          matchesPerTeam: matchesPerTeam,
          startDate: selectedDate,
          startTime: startTime,
          matchDuration: matchDuration,
          breakDuration: breakBetweenMatches,
          allowRematches: allowRematches,
          customTeamSize: customTeamSize,
        ),
      ),
    );
  }
}
