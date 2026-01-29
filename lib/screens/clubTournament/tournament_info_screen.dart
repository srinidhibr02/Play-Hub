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
  late AnimationController _scaleController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Color> categoryColors = {
    'Male Singles': Colors.blue,
    'Male Doubles': Colors.orange,
    'Female Singles': Colors.pink,
    'Female Doubles': Colors.purple,
    'Mixed Doubles': Colors.green,
  };

  final Map<String, IconData> categoryIcons = {
    'Male Singles': Icons.person,
    'Male Doubles': Icons.people,
    'Female Singles': Icons.person,
    'Female Doubles': Icons.people,
    'Mixed Doubles': Icons.groups,
  };

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    if (mounted) {
      _tabController.dispose();
      _scaleController.dispose();
    }
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
          'bookingAmount': data['bookingAmount'] ?? 0,
          'registeredAt': data['registeredAt'],
        });
      }

      // Sort participants within each category
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

  @override
  Widget build(BuildContext context) {
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

          // Initialize TabController
          _tabController = TabController(
            length: groupedData.length,
            vsync: this,
          );

          return _buildTabbedRegistrations(groupedData);
        },
      ),
      bottomNavigationBar: _buildStatusButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade500,
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
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _scaleController,
                curve: Curves.elasticOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_rounded,
                size: 48,
                color: Colors.orange.shade600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading participants...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.orange.shade600),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Error loading participants',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_add_rounded,
              size: 56,
              color: Colors.orange.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Registrations Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for participants to register',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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

    return Column(
      children: [
        // Tournament Info Card
        _buildTournamentInfoCard(totalParticipants),

        // Tab Bar with categories
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 0),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            unselectedLabelColor: Colors.grey.shade600,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.grey.shade200,
            splashBorderRadius: BorderRadius.circular(12),
            tabs: categories.asMap().entries.map((entry) {
              final category = entry.value;
              final count = groupedData[category]!.length;
              final color = categoryColors[category] ?? Colors.grey;
              final icon = categoryIcons[category] ?? Icons.person;

              return _buildCategoryTab(
                category: category,
                count: count,
                color: color,
                icon: icon,
              );
            }).toList(),
          ),
        ),

        // TabBarView - Content for each category
        Expanded(
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
      ],
    );
  }

  Widget _buildTournamentInfoCard(int totalParticipants) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.amber.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha((255 * 0.08).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: Colors.orange.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tournament Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat(
                    'EEEE, MMMM d, yyyy',
                  ).format(widget.startDate.toDate()),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                totalParticipants.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab({
    required String category,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha((255 * 0.85).toInt()), color],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((255 * 0.3).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((255 * 0.25).toInt()),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withAlpha((255 * 0.08).toInt()),
                color.withAlpha((255 * 0.05).toInt()),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withAlpha((255 * 0.2).toInt()),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha((255 * 0.15).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(categoryIcons[category], color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${registrations.length} participant${registrations.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Participants List
        ...registrations.asMap().entries.map((entry) {
          final index = entry.key;
          final registration = entry.value;
          final fullName = registration['fullName'] as String;
          final participants = List<String>.from(
            registration['participants'] ?? [],
          );
          final status = registration['status'] as String;

          return _buildParticipantTile(
            fullName: fullName,
            participants: participants,
            color: color,
            participantIndex: index,
            totalParticipants: registrations.length,
            status: status,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStatusButton() {
    final now = DateTime.now();
    final hasStarted =
        now.isAfter(widget.startDate.toDate()) ||
        now.day == widget.startDate.toDate().day;
    final statusColor = hasStarted ? Colors.green : Colors.grey;
    final statusIcon = hasStarted
        ? Icons.check_circle_rounded
        : Icons.schedule_rounded;
    final statusText = hasStarted
        ? 'Tournament Has Started'
        : 'Not yet Started';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.1).toInt()),
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
              colors: [statusColor.withAlpha((255 * 0.9).toInt()), statusColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: statusColor.withAlpha((255 * 0.3).toInt()),
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
                        Icon(statusIcon, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: statusColor,
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  Widget _buildParticipantTile({
    required String fullName,
    required List<String> participants,
    required Color color,
    required int participantIndex,
    required int totalParticipants,
    required String status,
  }) {
    final isConfirmed = status == 'confirmed';
    final statusColor = isConfirmed ? Colors.green : Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha((255 * 0.2).toInt()),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha((255 * 0.7).toInt()), color],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha((255 * 0.3).toInt()),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                fullName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (participants.length > 1)
                  Text(
                    participants.join(', '),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Solo registration',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha((255 * 0.12).toInt()),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: statusColor.withAlpha((255 * 0.3).toInt()),
                  ),
                ),
                child: Text(
                  isConfirmed ? '✓' : '⏳',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${participantIndex + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
