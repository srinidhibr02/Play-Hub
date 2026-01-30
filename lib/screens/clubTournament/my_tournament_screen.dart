import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_hub/screens/clubTournament/tournament_info_screen.dart';
import 'package:play_hub/service/auth_service.dart';
import 'package:play_hub/screens/clubTournament/tournament_details_screen.dart';

class MyTournamentsWidget extends StatefulWidget {
  final Future<void> Function() onRequestLocation;

  const MyTournamentsWidget({super.key, required this.onRequestLocation});

  @override
  State<MyTournamentsWidget> createState() => _MyTournamentsWidgetState();
}

class _MyTournamentsWidgetState extends State<MyTournamentsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _registeredTournaments = [];
  bool _isLoading = false;
  String _filterStatus = 'all'; // all, upcoming, completed

  @override
  void initState() {
    super.initState();
    _fetchRegisteredTournaments();
  }

  Future<void> _fetchRegisteredTournaments() async {
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final userId = _authService.currentUserEmailId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('📥 Fetching registered tournaments for user: $userId');

      // Get user document to fetch registeredTournaments array
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found for: $userId');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final registeredTournamentIds = List<String>.from(
        userData['registeredTournaments'] ?? [],
      );

      debugPrint(
        'Found ${registeredTournamentIds.length} registered tournaments',
      );

      final tournaments = <Map<String, dynamic>>[];

      // Fetch each tournament
      for (final tournamentId in registeredTournamentIds) {
        try {
          final tournamentDoc = await _firestore
              .collection('tournaments')
              .doc(tournamentId)
              .get();

          if (!tournamentDoc.exists) {
            debugPrint('⚠️ Tournament $tournamentId not found');
            continue;
          }

          final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
          final clubId = tournamentData['clubId'] as String?;

          // Fetch club data if available
          Map<String, dynamic>? clubData;
          if (clubId != null) {
            final clubDoc = await _firestore
                .collection('clubs')
                .doc(clubId)
                .get();
            if (clubDoc.exists) {
              clubData = clubDoc.data() as Map<String, dynamic>;
            }
          }

          // Fetch registration details from registrations subcollection
          Map<String, dynamic>? registrationData;
          String? registrationId;
          try {
            final registrationsSnapshot = await _firestore
                .collection('tournaments')
                .doc(tournamentId)
                .collection('registrations')
                .where('userId', isEqualTo: userId)
                .limit(1)
                .get();

            if (registrationsSnapshot.docs.isNotEmpty) {
              registrationId = registrationsSnapshot.docs.first.id;
              registrationData = registrationsSnapshot.docs.first.data();
            }
          } catch (e) {
            debugPrint('⚠️ Error fetching registration for $tournamentId: $e');
          }

          final merged = {
            'id': tournamentId,
            ...tournamentData,
            if (clubData != null) 'club': clubData,
            if (registrationId != null) 'registrationId': registrationId,
            if (registrationData != null) 'registration': registrationData,
          };

          tournaments.add(merged);
          debugPrint('✅ Tournament: ${merged['name'] ?? 'Unknown'}');
        } catch (e) {
          debugPrint('⚠️ Error processing tournament $tournamentId: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _registeredTournaments = tournaments;
        _isLoading = false;
      });

      debugPrint('✅ Fetched ${tournaments.length} registered tournaments');
    } catch (e) {
      debugPrint('❌ Error fetching registered tournaments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isUpcoming(Map<String, dynamic> tournament) {
    final dateField = tournament['date'];
    if (dateField == null) return false;

    try {
      DateTime date;

      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else {
        return false;
      }

      return date.isAfter(DateTime.now());
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _getFilteredTournaments() {
    if (_filterStatus == 'all') {
      return _registeredTournaments;
    } else if (_filterStatus == 'upcoming') {
      return _registeredTournaments.where((t) => _isUpcoming(t)).toList();
    } else {
      return _registeredTournaments.where((t) => !_isUpcoming(t)).toList();
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  int _to12Hour(int hour24) => hour24 == 0
      ? 12
      : hour24 > 12
      ? hour24 - 12
      : hour24;

  String _getAmPm(int hour24) => hour24 >= 12 ? 'PM' : 'AM';

  String _formatCategory(String category) {
    // Convert camelCase to readable format
    // e.g., "maleDoubles" -> "Male Doubles"
    return category
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Widget _buildLoadingShimmer() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white70,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.05).toInt()),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(height: 18, width: 200),
                const SizedBox(height: 8),
                _buildShimmerBox(height: 14, width: 150),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildShimmerBox(height: 18, width: 18, isCircle: true),
                    const SizedBox(width: 12),
                    _buildShimmerBox(height: 15, width: 120),
                  ],
                ),
                const SizedBox(height: 20),
                _buildShimmerBox(height: 50, width: double.infinity),
              ],
            ),
          ),
        );
      }, childCount: 3),
    );
  }

  Widget _buildShimmerBox({
    required double height,
    double? width,
    bool isCircle = false,
  }) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: isCircle ? null : BorderRadius.circular(8),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha((255 * 0.1).toInt()),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.bookmark_border,
                size: 64,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Tournaments Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your registered tournaments will appear here',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                DefaultTabController.of(context)?.animateTo(0);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Explore Tournaments'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    final tournamentName = tournament['name'] as String? ?? 'Tournament';
    final club = tournament['club'] as Map<String, dynamic>? ?? {};
    final clubName = club['name'] as String? ?? 'Unknown Club';
    final dateField = tournament['date'];
    final isUpcoming = _isUpcoming(tournament);
    final registrationId = tournament['registrationId'] as String? ?? 'N/A';
    final registration =
        tournament['registration'] as Map<String, dynamic>? ?? {};
    final category = registration['category'] as String? ?? 'N/A';

    // Parse date and time from Timestamp
    String formattedDateTime = 'Date TBA';
    try {
      DateTime date;

      if (dateField is Timestamp) {
        date = dateField.toDate();
      } else if (dateField is String) {
        date = DateTime.parse(dateField);
      } else {
        date = DateTime.now();
      }

      final day = date.day.toString().padLeft(2, '0');
      final month = _getMonthAbbr(date.month);
      final year = date.year;
      final hour12 = _to12Hour(date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = _getAmPm(date.hour);

      formattedDateTime = '$day-$month-$year, $hour12:$minute $amPm';
    } catch (e) {
      debugPrint('Error parsing date: $e');
      formattedDateTime = 'Invalid Date';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.05).toInt()),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TournamentDetailsScreen(
                    tournamentId: tournament['id'] as String,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tournamentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              clubName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
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
                          color: isUpcoming
                              ? Colors.blue.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUpcoming
                                ? Colors.blue.shade300
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          isUpcoming ? 'Upcoming' : 'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: isUpcoming
                                ? Colors.blue.shade700
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatCategory(category),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Date and Time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          formattedDateTime,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Registration ID
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.confirmation_number_rounded,
                          size: 18,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registration ID',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              registrationId,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Courier',
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text(
                        'Tournament Info',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => TournamentInfoScreen(
                              tournamentId: tournament['id'] as String,
                              tournamentName: tournamentName,
                              startDate: tournament['date'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.teal.withAlpha((255 * 0.3).toInt()),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTournaments = _getFilteredTournaments();

    return CustomScrollView(
      slivers: [
        // Filter Chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registered Tournaments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        value: 'all',
                        isSelected: _filterStatus == 'all',
                        onTap: () {
                          setState(() => _filterStatus = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Upcoming',
                        value: 'upcoming',
                        isSelected: _filterStatus == 'upcoming',
                        onTap: () {
                          setState(() => _filterStatus = 'upcoming');
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Completed',
                        value: 'completed',
                        isSelected: _filterStatus == 'completed',
                        onTap: () {
                          setState(() => _filterStatus = 'completed');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tournaments List
        if (_isLoading)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: _buildLoadingShimmer(),
          )
        else if (filteredTournaments.isEmpty)
          _buildEmptyState()
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildTournamentCard(filteredTournaments[index]),
                childCount: filteredTournaments.length,
              ),
            ),
          ),
      ],
    );
  }
}
