import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TournamentInfoScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final Timestamp startDate;

  const TournamentInfoScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.startDate,
  });

  @override
  State<TournamentInfoScreen> createState() => _TournamentInfoScreenState();
}

class _TournamentInfoScreenState extends State<TournamentInfoScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pageAnimationController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageAnimationController.dispose();
    super.dispose();
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  _getGroupedRegistrations() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('registrations')
          .get();

      Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] ?? 'Uncategorized';
        final fullName = data['fullName'] ?? 'Unknown';
        final participants = List<String>.from(data['participants'] ?? []);
        final status = data['status'] ?? 'pending';

        if (!grouped.containsKey(category)) {
          grouped[category] = [];
        }

        grouped[category]!.add({
          'fullName': fullName,
          'participants': participants,
          'status': status,
          'bookingAmount': data['booking'] ?? 0,
          'registeredAt': data['registeredAt'],
        });
      }

      grouped.forEach((category, registrations) {
        registrations.sort(
          (a, b) =>
              (a['fullName'] as String).compareTo(b['fullName'] as String),
        );
      });

      return grouped;
    } catch (e) {
      debugPrint('Error fetching registrations: $e');
      return {};
    }
  }

  Future<String> _getTournamentStatus() async {
    try {
      final doc = await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();

      if (doc.exists) {
        return doc.data()?['status'] ?? 'open';
      }
      return 'open';
    } catch (e) {
      debugPrint('Error fetching tournament status: $e');
      return 'open';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .snapshots(),
      builder: (context, tournamentSnapshot) {
        // Get tournament status
        String tournamentStatus = 'open';
        if (tournamentSnapshot.hasData && tournamentSnapshot.data!.exists) {
          tournamentStatus =
              tournamentSnapshot.data!['status'] as String? ?? 'open';
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: _buildAppBar(),
          body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: _getGroupedRegistrations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final groupedData = snapshot.data ?? {};

              if (groupedData.isEmpty) {
                return _buildEmptyState();
              }

              _tabController = TabController(
                length: groupedData.length,
                vsync: this,
              );

              return _buildTabbedRegistrations(groupedData);
            },
          ),
          bottomNavigationBar: _buildBottomButton(tournamentStatus),
        );
      },
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
        splashRadius: 28,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tournament Info',
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0).animate(
              CurvedAnimation(
                parent: _pageAnimationController,
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
            'Loading participants...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.teal.shade600),
              strokeWidth: 3.5,
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
            'Error Loading Participants',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
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
              Icons.group_add_rounded,
              size: 64,
              color: Colors.teal.shade300,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No Registrations Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Waiting for participants to register',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabbedRegistrations(
    Map<String, List<Map<String, dynamic>>> groupedData,
  ) {
    final categories = groupedData.keys.toList();
    final totalParticipants = groupedData.values.fold<int>(
      0,
      (sum_, list) => sum_ + list.length,
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // Tournament Info Card
          _buildTournamentInfoCard(totalParticipants, groupedData),

          // Category Tabs
          _buildCategoryTabBar(categories, groupedData),

          // Content with TabBarView inside scrollable area
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: TabBarView(
              controller: _tabController,
              children: categories.map((category) {
                final registrations = groupedData[category]!;
                final color = categoryColors[category] ?? Colors.grey;

                return _buildCategoryContent(
                  category: category,
                  registrations: registrations,
                  color: color,
                );
              }).toList(),
            ),
          ),

          // Extra bottom padding for fixed button
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTournamentInfoCard(
    int totalParticipants,
    Map<String, List<Map<String, dynamic>>> groupedData,
  ) {
    final startDate = widget.startDate.toDate();
    final daysUntilTournament = startDate.difference(DateTime.now()).inDays;
    final formattedDate = DateFormat('EEEE, MMM d').format(startDate);

    return FadeTransition(
      opacity: _pageAnimationController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _pageAnimationController,
                curve: Curves.easeOut,
              ),
            ),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.cyan.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tournament Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.people_rounded,
                      label: 'Total Registrations',
                      value: totalParticipants.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.category_rounded,
                      label: 'Categories',
                      value: groupedData.length.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      icon: daysUntilTournament <= 0
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      label: daysUntilTournament <= 0 ? 'Started' : 'Days Left',
                      value: daysUntilTournament <= 0
                          ? 'Now'
                          : daysUntilTournament.toString(),
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

  Widget _buildStatItem({
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
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabBar(
    List<String> categories,
    Map<String, List<Map<String, dynamic>>> groupedData,
  ) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: categories.asMap().entries.map((entry) {
            final idx = entry.key;
            final category = entry.value;
            final count = groupedData[category]!.length;
            final color = categoryColors[category] ?? Colors.grey;
            final icon = categoryIcons[category] ?? Icons.person;

            return GestureDetector(
              onTap: () => _tabController.animateTo(idx),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.9), color],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryContent({
    required String category,
    required List<Map<String, dynamic>> registrations,
    required Color color,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Category Header
        _buildCategoryHeader(category, registrations.length, color),
        const SizedBox(height: 20),

        // Participants List with Staggered Animation
        ...registrations.asMap().entries.map((entry) {
          final index = entry.key;
          final registration = entry.value;
          final fullName = registration['fullName'] as String;
          final participants = List<String>.from(
            registration['participants'] ?? [],
          );
          final status = registration['status'] as String;

          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _pageAnimationController,
                    curve: Interval(
                      0.2 + (index * 0.05),
                      1.0,
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
            child: _buildParticipantCard(
              fullName: fullName,
              participants: participants,
              color: color,
              index: index,
              total: registrations.length,
              status: status,
            ),
          );
        }).toList(),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCategoryHeader(String category, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcons[category], color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count participant${count > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard({
    required String fullName,
    required List<String> participants,
    required Color color,
    required int index,
    required int total,
    required String status,
  }) {
    final isConfirmed = status == 'confirmed';
    final statusIcon = isConfirmed
        ? Icons.check_circle_rounded
        : Icons.access_time_rounded;
    final statusColor = isConfirmed ? Colors.green : Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    fullName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Name and Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (participants.length > 1)
                      Text(
                        participants.join(', '),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'Solo Entry',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Status and Number
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          isConfirmed ? 'Confirmed' : 'Pending',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Text(
                      '#${(index + 1).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
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

  Widget _buildBottomButton(String status) {
    final isStarted = status == 'started';
    final buttonColor = isStarted ? Colors.orange : Colors.grey;
    final buttonIcon = isStarted
        ? Icons.schedule_rounded
        : Icons.schedule_rounded;
    final buttonText = isStarted ? 'View Schedule' : 'Not yet Started';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [buttonColor.shade700, buttonColor.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: buttonColor.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(buttonIcon, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: buttonColor.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(buttonIcon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
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
}
