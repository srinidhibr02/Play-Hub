import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:play_hub/screens/clubTournament/tournament_details_screen.dart';

class ExploreTournamentsWidget extends StatefulWidget {
  final Position? userLocation;
  final bool hasLocationPermission;
  final Future<void> Function() onRequestLocation;

  const ExploreTournamentsWidget({
    super.key,
    required this.userLocation,
    required this.hasLocationPermission,
    required this.onRequestLocation,
  });

  @override
  State<ExploreTournamentsWidget> createState() =>
      _ExploreTournamentsWidgetState();
}

class _ExploreTournamentsWidgetState extends State<ExploreTournamentsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allTournaments = [];
  List<Map<String, dynamic>> _filteredTournaments = [];
  bool _isLoadingTournaments = false;
  bool _isSearching = false;

  // ✅ NEW: Status filter state
  String _selectedStatus = 'all'; // all, open, active, completed
  final List<String> _statusOptions = ['all', 'open', 'active', 'completed'];

  final Map<String, Color> _statusColors = {
    'all': Colors.grey,
    'open': Colors.blue,
    'active': Colors.orange,
    'completed': Colors.green,
  };

  final Map<String, IconData> _statusIcons = {
    'all': Icons.list_rounded,
    'open': Icons.event_available_rounded,
    'active': Icons.play_circle_outline_rounded,
    'completed': Icons.check_circle_outline_rounded,
  };

  final Map<String, String> _statusLabels = {
    'all': 'All Tournaments',
    'open': 'Open',
    'active': 'Active',
    'completed': 'Completed',
  };

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTournaments() async {
    try {
      if (mounted) {
        setState(() => _isLoadingTournaments = true);
      }
      debugPrint('📥 Fetching tournaments from Firestore...');

      // ✅ Fetch all tournaments without status filter initially
      final tournamentSnapshot = await _firestore
          .collection('tournaments')
          .get();

      if (!mounted) return;

      final tournaments = <Map<String, dynamic>>[];

      for (final tournamentDoc in tournamentSnapshot.docs) {
        try {
          final tournamentData = tournamentDoc.data();
          final clubId = tournamentData['clubId'] as String?;

          if (clubId == null) {
            debugPrint('⚠️ Tournament ${tournamentDoc.id} has no clubId');
            continue;
          }

          final clubDoc = await _firestore
              .collection('clubs')
              .doc(clubId)
              .get();

          if (!clubDoc.exists) {
            debugPrint(
              '⚠️ Club $clubId not found for tournament ${tournamentDoc.id}',
            );
            continue;
          }

          final clubData = clubDoc.data() as Map<String, dynamic>;

          final merged = {
            'id': tournamentDoc.id,
            ...tournamentData,
            'club': clubData,
            'clubId': clubId,
          };

          tournaments.add(merged);
          debugPrint(
            '✅ Tournament: ${merged['name'] ?? 'Unknown'} - Club: ${clubData['name'] ?? 'Unknown'} - Status: ${merged['status'] ?? 'unknown'}',
          );
        } catch (e) {
          debugPrint('⚠️ Error processing tournament ${tournamentDoc.id}: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _allTournaments = tournaments;
        _applyFilters(); // ✅ Apply current filters
        _isLoadingTournaments = false;
      });

      debugPrint('✅ Fetched ${tournaments.length} tournaments with club data');

      if (widget.userLocation != null) {
        _sortTournamentsByDistance();
      }
    } catch (e) {
      debugPrint('❌ Error fetching tournaments: $e');
      if (mounted) {
        setState(() => _isLoadingTournaments = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error fetching tournaments: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// ✅ NEW: Apply both status and search filters
  void _applyFilters() {
    var filtered = List<Map<String, dynamic>>.from(_allTournaments);

    // Apply status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((t) {
        final status = (t['status'] as String?)?.toLowerCase() ?? '';
        return status == _selectedStatus.toLowerCase();
      }).toList();
      debugPrint(
        '🔍 Filtered by status "$_selectedStatus": ${filtered.length} tournaments',
      );
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase().trim();
      filtered = filtered.where((t) {
        final tournamentName = (t['name'] ?? '').toString().toLowerCase();
        final sport = (t['sport'] ?? '').toString().toLowerCase();
        final club = t['club'] as Map<String, dynamic>? ?? {};
        final clubName = (club['name'] ?? '').toString().toLowerCase();
        final city = (club['city'] ?? '').toString().toLowerCase();
        final date = (t['date'] ?? '').toString().toLowerCase();

        return tournamentName.contains(q) ||
            sport.contains(q) ||
            clubName.contains(q) ||
            city.contains(q) ||
            date.contains(q);
      }).toList();
    }

    setState(() {
      _filteredTournaments = filtered;
    });
  }

  double _calculateDistance(double lat, double lng) {
    if (widget.userLocation == null) return 0;
    return Geolocator.distanceBetween(
      widget.userLocation!.latitude,
      widget.userLocation!.longitude,
      lat,
      lng,
    );
  }

  void _sortTournamentsByDistance() {
    final sorted = List<Map<String, dynamic>>.from(_filteredTournaments);
    sorted.sort((a, b) {
      try {
        final aClub = a['club'] as Map<String, dynamic>?;
        final bClub = b['club'] as Map<String, dynamic>?;

        if (aClub == null || bClub == null) return 0;

        final aLocation = aClub['location'] as GeoPoint?;
        final bLocation = bClub['location'] as GeoPoint?;

        if (aLocation == null || bLocation == null) return 0;

        final aDistance = _calculateDistance(
          aLocation.latitude,
          aLocation.longitude,
        );
        final bDistance = _calculateDistance(
          bLocation.latitude,
          bLocation.longitude,
        );

        return aDistance.compareTo(bDistance);
      } catch (e) {
        debugPrint('Error sorting: $e');
        return 0;
      }
    });

    setState(() {
      _filteredTournaments = sorted;
    });
  }

  void _searchTournaments(String query) {
    if (mounted) {
      setState(() => _isSearching = true);
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _applyFilters(); // ✅ Apply both filters
      setState(() => _isSearching = false);
      if (widget.userLocation != null) _sortTournamentsByDistance();
    });
  }

  /// ✅ NEW: Handle status filter change
  void _onStatusFilterChanged(String status) {
    setState(() {
      _selectedStatus = status;
      debugPrint('🔄 Status filter changed to: $status');
    });
    _applyFilters(); // ✅ Apply filters immediately
    if (widget.userLocation != null) _sortTournamentsByDistance();
  }

  /// ✅ NEW: Build status filter pills
  Widget _buildStatusFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: _statusOptions.map((status) {
          final isSelected = _selectedStatus == status;
          final color = _statusColors[status] ?? Colors.grey;
          final icon = _statusIcons[status] ?? Icons.list_rounded;
          final label = _statusLabels[status] ?? status;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _onStatusFilterChanged(status),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.2)
                      : Colors.grey.shade100,
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300,
                    width: isSelected ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected ? color : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? color : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
    return Center(
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
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? 'No Tournaments Found'
                : 'No Results Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Try adjusting your filters'
                : 'Try different keywords or filters',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: widget.onRequestLocation,
            icon: const Icon(Icons.location_on),
            label: const Text('Find Nearby'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> tournament) {
    final tournamentName = tournament['name'] as String? ?? 'Tournament';
    final status = tournament['status'] as String? ?? 'unknown';
    final club = tournament['club'] as Map<String, dynamic>? ?? {};
    final clubName = club['name'] as String? ?? 'Unknown Club';
    final clubCity = club['city'] as String? ?? 'Unknown City';
    final location = club['location'] as GeoPoint?;

    double distance = 0;
    if (location != null && widget.userLocation != null) {
      distance = _calculateDistance(location.latitude, location.longitude);
    }

    final distanceInKm = (distance / 1000).toStringAsFixed(1);
    final distanceColor = distance < 5000
        ? Colors.green
        : distance < 10000
        ? Colors.orange
        : Colors.red;

    // ✅ Status badge styling
    final statusColor = _statusColors[status] ?? Colors.grey;
    final statusIcon = _statusIcons[status] ?? Icons.info_outline_rounded;

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
            onTap: () {},
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      // ✅ Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha((255 * 0.15).toInt()),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withAlpha((255 * 0.4).toInt()),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 16, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          clubCity,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.userLocation != null && distance > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: distanceColor.withAlpha((255 * 0.1).toInt()),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: distanceColor.withAlpha(
                                (255 * 0.4).toInt(),
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$distanceInKm km',
                            style: TextStyle(
                              fontSize: 11,
                              color: distanceColor,
                              fontWeight: FontWeight.bold,
                            ),
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
                        'View Details',
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
                            builder: (context) => TournamentDetailsScreen(
                              tournamentId: tournament['id'] as String,
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              borderRadius: BorderRadius.circular(20),
              elevation: 4,
              shadowColor: Colors.teal.withAlpha((255 * 0.3).toInt()),
              child: TextField(
                controller: _searchController,
                onChanged: _searchTournaments,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search by name, city, sport...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.search_rounded,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  suffixIcon: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _searchTournaments('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          // ✅ NEW: Status Filter Bar
          _buildStatusFilterBar(),

          // Location Permission Banner
          if (!widget.hasLocationPermission)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: widget.onRequestLocation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.amber.shade50],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Find Nearby Tournaments',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              'Enable location for personalized results',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Tournaments List
          _isLoadingTournaments
              ? _buildLoadingShimmer()
              : _filteredTournaments.isEmpty
              ? _buildEmptyState()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  child: Column(
                    children: [
                      ..._filteredTournaments.map(
                        (t) => _buildTournamentCard(t),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

Widget _buildLoadingShimmer() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
    child: Column(
      children: List.generate(4, (index) {
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShimmerBox(height: 20, width: 150),
                  const SizedBox(height: 10),
                  _buildShimmerBox(height: 16, width: 100),
                  const SizedBox(height: 20),
                  _buildShimmerBox(height: 14, width: 80),
                  const SizedBox(height: 16),
                  _buildShimmerBox(height: 14, width: double.infinity),
                  const SizedBox(height: 16),
                  _buildShimmerBox(height: 14, width: double.infinity),
                  const SizedBox(height: 20),
                  _buildShimmerBox(height: 48, width: double.infinity),
                ],
              ),
            ),
          ),
        );
      }),
    ),
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
