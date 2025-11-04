import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:play_hub/screens/tournament/badminton/tournament_schedule_screen.dart';

// Tournament Configuration Screen
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
  int breakBetweenMatches = 15; // minutes
  int matchDuration = 30; // minutes
  bool allowRematches = false;
  num? customTeamSize; // NEW: Track custom team size

  @override
  void initState() {
    super.initState();
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
    int teamsCount = _getTeamsCount(
      customTeamSize,
    ); // CHANGED: Pass customTeamSize

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
            _buildSummaryCard(
              icon: Icons.people,
              title: widget.teamType == 'Singles' ? 'Players' : 'Teams',
              value: teamsCount.toString(),
              subtitle: widget.teamType,
              color: Colors.blue,
              onIncrement:
                  widget.teamType == 'Singles' || widget.teamType == 'Doubles'
                  ? null // No increment for Singles/Doubles
                  : () {
                      setState(() {
                        customTeamSize = (customTeamSize ?? 3) + 1;
                      });
                    },
              onDecrement:
                  widget.teamType == 'Singles' || widget.teamType == 'Doubles'
                  ? null // No decrement for Singles/Doubles
                  : () {
                      setState(() {
                        if ((customTeamSize ?? 3) > 2) {
                          customTeamSize = (customTeamSize ?? 3) - 1;
                        }
                      });
                    },
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
                        'You need at least ${widget.teamType == 'Singles'
                            ? '2 players'
                            : widget.teamType == 'Doubles'
                            ? '4 members (2 teams)'
                            : '${((customTeamSize?.toInt() ?? 3) * 2)} members (2 teams)'} to create a tournament.',
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
            _buildSectionTitle(
              widget.teamType == 'Singles'
                  ? 'Matches against each Player'
                  : 'Matches against each Team',
            ),
            const SizedBox(height: 12),
            _buildSliderCard(
              value: matchesPerTeam.toDouble(),
              min: allowRematches ? 1 : matchesPerTeam.toDouble(),
              max: allowRematches
                  ? _getMaxMatchesPerTeam().toDouble()
                  : matchesPerTeam.toDouble(),
              divisions: allowRematches
                  ? (_getMaxMatchesPerTeam() > 1
                        ? _getMaxMatchesPerTeam() - 1
                        : 1)
                  : 1,
              label: matchesPerTeam.toString(),
              onChanged: allowRematches
                  ? (value) {
                      setState(() {
                        matchesPerTeam = value.toInt();
                      });
                    }
                  : null,
              suffix: matchesPerTeam == 1 ? 'match' : 'matches',
              helperText: allowRematches
                  ? 'Number of times each team plays every other team (rematches allowed)'
                  : 'Each team plays every other team once (round-robin)',
            ),
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
                ],
              ),
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
                      'Generate Schedule',
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
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
  }) {
    final isCustom = subtitle != 'Singles' && subtitle != 'Doubles';

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
                    if (isCustom && onIncrement != null)
                      IconButton(
                        onPressed: onIncrement,
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
                    if (isCustom && onDecrement != null)
                      IconButton(
                        onPressed: onDecrement,
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
                if (isCustom)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _getTeamInfo(value),
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

  String _getTeamInfo(Object value) {
    try {
      final numTeams = int.parse(value.toString());
      final teamSize = widget.members.length ~/ numTeams;
      return 'Note - $numTeams teams of $teamSize members each';
    } catch (e) {
      return '';
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

  int _getTeamsCount([num? totalTeams]) {
    if (widget.teamType == 'Singles') {
      return widget.members.length;
    } else if (widget.teamType == 'Doubles') {
      return widget.members.length ~/ 2;
    } else {
      return widget.members.length ~/ (totalTeams ?? 3).toInt();
    }
  }

  int _calculateTotalMatches() {
    final int teamsCount = _getTeamsCount(customTeamSize);
    if (teamsCount < 2) return 0;

    int uniquePairs = (teamsCount * (teamsCount - 1)) ~/ 2;

    if (allowRematches) {
      return uniquePairs * matchesPerTeam;
    } else {
      return uniquePairs;
    }
  }

  int _getMaxMatchesPerTeam() {
    int teamsCount = _getTeamsCount(customTeamSize);
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
    if (_getTeamsCount(customTeamSize) < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need at least ${widget.teamType == 'Singles' ? '2 players' : '2 teams'} to create a tournament.',
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BadmintonMatchScheduleScreen(
          members: widget.members,
          teamType: widget.teamType,
          matchesPerTeam: matchesPerTeam,
          startDate: selectedDate,
          startTime: startTime,
          matchDuration: matchDuration,
          breakDuration: breakBetweenMatches,
          allowRematches: allowRematches,
        ),
      ),
    );
  }
}
