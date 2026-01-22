import 'package:flutter/material.dart';
import 'package:play_hub/screens/tournament/badminton/tournament_configuration_screen.dart';

class BadmintonTournamentSetupScreen extends StatefulWidget {
  const BadmintonTournamentSetupScreen({super.key});

  @override
  State<BadmintonTournamentSetupScreen> createState() =>
      _BadmintonTournamentSetupScreenState();
}

class _BadmintonTournamentSetupScreenState
    extends State<BadmintonTournamentSetupScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> members = [];
  final TextEditingController memberController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String selectedTeamType = 'Singles';
  final List<Map<String, dynamic>> teamTypes = [
    {
      'name': 'Singles',
      'icon': Icons.person,
      'description': '1v1 matches',
      'minPlayers': 2,
      'playersPerTeam': 1,
      'color': Colors.blue,
    },
    {
      'name': 'Doubles',
      'icon': Icons.people,
      'description': '2v2 matches',
      'minPlayers': 4,
      'playersPerTeam': 2,
      'color': Colors.purple,
    },
    {
      'name': 'Custom',
      'icon': Icons.groups,
      'description': 'Random teams & matches',
      'minPlayers': 6,
      'playersPerTeam': 2,
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Auto-focus on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    memberController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isValidPlayerCount(int count, String teamType) {
    if (teamType == 'Singles') {
      return true; // No constraint on odd/even for singles
    } else if (teamType == 'Doubles' || teamType == 'Custom') {
      return count % 2 == 0; // Must be even for Doubles and Custom
    }
    return false;
  }

  void _addMember() {
    final name = memberController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter a player name', Colors.orange);
      return;
    }
    if (members.contains(name)) {
      _showSnackBar('Player already added', Colors.red);
      return;
    }
    setState(() {
      members.add(name);
      memberController.clear();
    });
    _showSnackBar('$name added successfully!', Colors.green);

    // Request focus after adding member
    _focusNode.requestFocus();
  }

  void _removeMember(String name) {
    setState(() {
      members.remove(name);
    });
    _showSnackBar('$name removed', Colors.grey.shade700);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _proceedToScheduling() {
    final selectedTeam = teamTypes.firstWhere(
      (t) => t['name'] == selectedTeamType,
    );
    final minPlayers = selectedTeam['minPlayers'] as int;

    if (members.length < minPlayers) {
      _showSnackBar(
        'Add at least $minPlayers players for $selectedTeamType format',
        Colors.red,
      );
      return;
    }

    if (!_isValidPlayerCount(members.length, selectedTeamType)) {
      if (selectedTeamType == 'Doubles') {
        _showSnackBar('Doubles requires an even number of players', Colors.red);
      } else if (selectedTeamType == 'Custom') {
        _showSnackBar(
          'Custom format requires an even number of players',
          Colors.red,
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentConfigScreen(
          members: members,
          teamType: selectedTeamType,
        ),
      ),
    );
  }

  void _clearAllPlayers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 12),
            const Text('Clear All Players?'),
          ],
        ),
        content: const Text('This will remove all players from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                members.clear();
              });
              Navigator.pop(context);
              _showSnackBar('All players removed', Colors.grey.shade700);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinueButton() {
    final selectedTeam = teamTypes.firstWhere(
      (t) => t['name'] == selectedTeamType,
    );
    final minPlayers = selectedTeam['minPlayers'] as int;
    final isOnPlayersTab = _tabController.index == 0;
    final isValidCount = _isValidPlayerCount(members.length, selectedTeamType);

    if (isOnPlayersTab && members.length >= minPlayers && isValidCount) {
      // Move to Format tab
      _tabController.animateTo(1);
    } else if (!isOnPlayersTab &&
        members.length >= minPlayers &&
        isValidCount) {
      // Proceed to scheduling
      _proceedToScheduling();
    }
  }

  String _getPlayerCountMessage(int minPlayers) {
    final isValidCount = _isValidPlayerCount(members.length, selectedTeamType);

    if (members.length < minPlayers) {
      return 'Add ${minPlayers - members.length} more player${minPlayers - members.length == 1 ? '' : 's'} to continue';
    } else if (!isValidCount) {
      if (selectedTeamType == 'Doubles' || selectedTeamType == 'Custom') {
        return 'Please add 1 more player to make an even number';
      }
    }
    return 'Ready to continue!';
  }

  @override
  Widget build(BuildContext context) {
    final selectedTeam = teamTypes.firstWhere(
      (t) => t['name'] == selectedTeamType,
    );
    final minPlayers = selectedTeam['minPlayers'] as int;
    final isValidCount = _isValidPlayerCount(members.length, selectedTeamType);
    final hasEnoughPlayers = members.length >= minPlayers && isValidCount;
    final isOnPlayersTab = _tabController.index == 0;

    // Determine button state
    String buttonText;
    IconData buttonIcon;
    bool buttonEnabled;

    if (isOnPlayersTab) {
      if (hasEnoughPlayers) {
        buttonText = 'Next: Choose Format';
        buttonIcon = Icons.arrow_forward;
        buttonEnabled = true;
      } else {
        buttonText = 'Add More Players';
        buttonIcon = Icons.lock;
        buttonEnabled = false;
      }
    } else {
      buttonText = 'Continue to Schedule';
      buttonIcon = Icons.calendar_month;
      buttonEnabled = hasEnoughPlayers;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade600,
        elevation: 0,
        title: const Text(
          'Badminton Tournament',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (members.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _clearAllPlayers,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Bar with Progress Indicator
            Container(
              color: Colors.orange.shade600,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (index) {
                        setState(() {}); // Rebuild to update button
                      },
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      labelColor: Colors.orange.shade600,
                      unselectedLabelColor: Colors.white.withAlpha(
                        (255 * 0.7).toInt(),
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add, size: 20),
                              const SizedBox(width: 8),
                              const Text('Players'),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _tabController.index == 0
                                      ? Colors.orange.shade600
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  members.length.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _tabController.index == 0
                                        ? Colors.white
                                        : Colors.orange.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.settings, size: 20),
                              SizedBox(width: 8),
                              Text('Format'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress Indicator
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: hasEnoughPlayers
                            ? 1.0
                            : members.length / minPlayers,
                        backgroundColor: Colors.white.withAlpha(
                          (255 * 0.3).toInt(),
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasEnoughPlayers
                              ? Colors.green.shade400
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildPlayersTab(minPlayers), _buildFormatTab()],
              ),
            ),

            // Bottom Info & Continue Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.05).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasEnoughPlayers && isOnPlayersTab)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getPlayerCountMessage(minPlayers),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: buttonEnabled ? _handleContinueButton : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: buttonEnabled ? 4 : 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              buttonIcon,
                              color: buttonEnabled
                                  ? Colors.white
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              buttonText,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: buttonEnabled
                                    ? Colors.white
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildPlayersTab(int minPlayers) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Players',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Minimum: $minPlayers players',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: memberController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Enter player name',
                  prefixIcon: Icon(Icons.person, color: Colors.orange.shade600),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.add_circle,
                      color: Colors.orange.shade600,
                      size: 28,
                    ),
                    onPressed: _addMember,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.orange.shade600,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => _addMember(),
              ),
            ],
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.orange.shade300,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No players added yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add players to create your tournament',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Dismissible(
                      key: Key(member),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _removeMember(member),
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(
                                (255 * 0.04).toInt(),
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.shade300.withAlpha(
                                    (255 * 0.5).toInt(),
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                member[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            member,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Player ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.red.shade400,
                              size: 22,
                            ),
                            onPressed: () => _removeMember(member),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFormatTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tournament Format',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how players will compete',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ...teamTypes.map((team) {
            final isSelected = team['name'] == selectedTeamType;
            final color = team['color'] as Color;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedTeamType = team['name'];
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withAlpha((255 * 0.1).toInt())
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade200,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withAlpha((255 * 0.3).toInt()),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    else
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
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [color.withAlpha((255 * 0.8).toInt()), color]
                              : [
                                  color.withAlpha((255 * 0.3).toInt()),
                                  color.withAlpha((255 * 0.5).toInt()),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withAlpha((255 * 0.4).toInt()),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Icon(team['icon'], color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team['name'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            team['description'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha((255 * 0.15).toInt()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Min. ${team['minPlayers']} players',
                              style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withAlpha((255 * 0.8).toInt()),
                              color,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha((255 * 0.4).toInt()),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
