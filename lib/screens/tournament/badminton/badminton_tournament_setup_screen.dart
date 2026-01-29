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
  late AnimationController _pulseController;
  late AnimationController _scaleController;

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

    // Animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

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
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  bool _isValidPlayerCount(int count, String teamType) {
    if (teamType == 'Singles') {
      return true;
    } else if (teamType == 'Doubles' || teamType == 'Custom') {
      return count % 2 == 0;
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
    _scaleController.forward().then((_) => _scaleController.reverse());
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
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.red
                  ? Icons.error_outline
                  : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Remove All Players?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This action will remove all players from the list.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                          colors: [Colors.red.shade600, Colors.red.shade500],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha((255 * 0.3).toInt()),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            members.clear();
                          });
                          Navigator.pop(context);
                          _showSnackBar(
                            'All players removed',
                            Colors.grey.shade700,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Remove All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
      _tabController.animateTo(1);
    } else if (!isOnPlayersTab &&
        members.length >= minPlayers &&
        isValidCount) {
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

    String buttonText;
    IconData buttonIcon;
    bool buttonEnabled;

    if (isOnPlayersTab) {
      if (hasEnoughPlayers) {
        buttonText = 'Next: Choose Format';
        buttonIcon = Icons.arrow_forward_rounded;
        buttonEnabled = true;
      } else {
        buttonText = 'Add More Players';
        buttonIcon = Icons.lock_rounded;
        buttonEnabled = false;
      }
    } else {
      buttonText = 'Continue to Schedule';
      buttonIcon = Icons.calendar_month_rounded;
      buttonEnabled = hasEnoughPlayers;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Tournament',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Badminton Tournament setup',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          if (members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.red.shade600,
                  ),
                  onPressed: _clearAllPlayers,
                  tooltip: 'Clear All',
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Tab Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    setState(() {});
                  },
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade600,
                        Colors.deepOrange.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withAlpha((255 * 0.25).toInt()),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_rounded, size: 20),
                          const SizedBox(width: 8),
                          const Text('Players'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _tabController.index == 0
                                  ? Colors.white.withAlpha((255 * 0.2).toInt())
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              members.length.toString(),
                              style: TextStyle(
                                fontSize: 11,
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
                          Icon(Icons.settings_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Format'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: hasEnoughPlayers ? 1.0 : members.length / minPlayers,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasEnoughPlayers
                        ? Colors.green.shade500
                        : Colors.orange.shade600,
                  ),
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildPlayersTab(minPlayers), _buildFormatTab()],
              ),
            ),

            // Bottom Action Bar
            Container(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasEnoughPlayers && isOnPlayersTab)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
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
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: buttonEnabled
                            ? LinearGradient(
                                colors: [
                                  Colors.orange.shade600,
                                  Colors.deepOrange.shade500,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: buttonEnabled
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withAlpha(
                                    (255 * 0.4).toInt(),
                                  ),
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
                          onPressed: buttonEnabled
                              ? _handleContinueButton
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonEnabled
                                ? Colors.transparent
                                : Colors.grey.shade300,
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
                                buttonIcon,
                                color: buttonEnabled
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                buttonText,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: buttonEnabled
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
        // Header with Input
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
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
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Minimum: $minPlayers players needed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Input Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.02).toInt()),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: TextField(
                  controller: memberController,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Enter player name',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(
                      Icons.person_add_rounded,
                      color: Colors.orange.shade600,
                    ),
                    suffixIcon: GestureDetector(
                      onTap: _addMember,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600,
                              Colors.deepOrange.shade500,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) => _addMember(),
                ),
              ),
            ],
          ),
        ),

        // Players List
        Expanded(
          child: members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withAlpha(
                                  (255 * 0.2).toInt(),
                                ),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: 56,
                            color: Colors.orange.shade300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No Players Added Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add players above to create your tournament',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                          gradient: LinearGradient(
                            colors: [Colors.red.shade500, Colors.red.shade400],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(
                                (255 * 0.05).toInt(),
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade500,
                                  Colors.orange.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.shade300.withAlpha(
                                    (255 * 0.4).toInt(),
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
                              color: Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            'Player ${index + 1} of ${members.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.red.shade500,
                                size: 20,
                              ),
                              onPressed: () => _removeMember(member),
                            ),
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
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select how players will compete',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
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
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withAlpha((255 * 0.08).toInt())
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade200,
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withAlpha((255 * 0.25).toInt()),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.04).toInt()),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [color.withAlpha((255 * 0.7).toInt()), color]
                              : [
                                  color.withAlpha((255 * 0.25).toInt()),
                                  color.withAlpha((255 * 0.4).toInt()),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withAlpha((255 * 0.35).toInt()),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Icon(team['icon'], color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),

                    // Info Section
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
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha((255 * 0.12).toInt()),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: color.withAlpha((255 * 0.2).toInt()),
                              ),
                            ),
                            child: Text(
                              'Min. ${team['minPlayers']} players',
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Selection Indicator
                    if (isSelected)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withAlpha((255 * 0.7).toInt()),
                              color,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha((255 * 0.4).toInt()),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    else
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
