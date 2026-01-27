import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:play_hub/screens/club_details_screen.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allClubs = [];
  List<Map<String, dynamic>> _filteredClubs = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  Position? _userLocation;
  bool _hasLocationPermission = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const int BATCH_SIZE = 5;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreClubs = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _initializeScreen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreClubs &&
        _searchController.text.isEmpty) {
      _loadMoreClubs();
    }
  }

  Future<void> _initializeScreen() async {
    try {
      await _requestLocationPermission();
      if (!mounted) return;

      if (_hasLocationPermission) {
        await _getUserLocation();
        if (!mounted) return;
      }

      // Start with initial batch
      await _loadInitialClubs();
      if (!mounted) return;

      _fadeController.forward();
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (mounted) {
        setState(() {
          _hasLocationPermission = status.isGranted;
        });
      }
    } catch (e) {
      debugPrint('Permission error: $e');
    }
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = position;
        });
        debugPrint('✅ Location: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _loadInitialClubs() async {
    try {
      if (!mounted) return;

      setState(() {
        _isInitialLoading = true;
        _lastDocument = null;
        _hasMoreClubs = true;
      });

      debugPrint('📥 Loading initial batch of clubs...');

      final snapshot = await _firestore
          .collection('clubs')
          .limit(BATCH_SIZE)
          .get();

      if (!mounted) return;

      final clubs = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          clubs.add(data);
        } catch (e) {
          debugPrint('Error parsing club ${doc.id}: $e');
        }
      }

      setState(() {
        _allClubs = clubs;
        _filteredClubs = clubs;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreClubs = snapshot.docs.length == BATCH_SIZE;
        _isInitialLoading = false;
      });

      debugPrint('✅ Loaded ${clubs.length} clubs');

      if (_userLocation != null && mounted) {
        _sortClubsByDistance();
      }
    } catch (e) {
      debugPrint('Error loading initial clubs: $e');
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading clubs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreClubs() async {
    if (_isLoadingMore || !_hasMoreClubs || _lastDocument == null) return;

    try {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = true;
      });

      debugPrint('📥 Loading more clubs...');

      final snapshot = await _firestore
          .collection('clubs')
          .startAfterDocument(_lastDocument!)
          .limit(BATCH_SIZE)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreClubs = false;
          _isLoadingMore = false;
        });
        return;
      }

      final clubs = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          clubs.add(data);
        } catch (e) {
          debugPrint('Error parsing club ${doc.id}: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _allClubs.addAll(clubs);
        _filteredClubs.addAll(clubs);
        _lastDocument = snapshot.docs.last;
        _hasMoreClubs = snapshot.docs.length == BATCH_SIZE;
        _isLoadingMore = false;
      });

      debugPrint('✅ Loaded ${clubs.length} more clubs');

      if (_userLocation != null && mounted) {
        _sortClubsByDistance();
      }
    } catch (e) {
      debugPrint('Error loading more clubs: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  double _calculateDistance(double lat, double lng) {
    if (_userLocation == null) return 0;
    return Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      lat,
      lng,
    );
  }

  void _sortClubsByDistance() {
    final sorted = List<Map<String, dynamic>>.from(_filteredClubs);
    sorted.sort((a, b) {
      try {
        final aLocation = a['location'] as GeoPoint?;
        final bLocation = b['location'] as GeoPoint?;

        if (aLocation == null || bLocation == null) {
          if (aLocation == null && bLocation != null) return 1;
          if (aLocation != null && bLocation == null) return -1;
          return 0;
        }

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

    if (mounted) {
      setState(() {
        _filteredClubs = sorted;
      });
    }

    debugPrint('✅ Clubs sorted by distance');
  }

  void _searchClubs(String query) {
    setState(() => _isSearching = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      if (query.isEmpty) {
        setState(() {
          _filteredClubs = List.from(_allClubs);
          _isSearching = false;
        });
        if (_userLocation != null) {
          _sortClubsByDistance();
        }
        return;
      }

      final q = query.toLowerCase().trim();
      final filtered = _allClubs.where((club) {
        final name = (club['name'] ?? '').toString().toLowerCase();
        final city = (club['city'] ?? '').toString().toLowerCase();
        final address = (club['address'] ?? '').toString().toLowerCase();
        final sports = (club['sports'] as List?)?.join(' ').toLowerCase() ?? '';

        return name.contains(q) ||
            city.contains(q) ||
            address.contains(q) ||
            sports.contains(q);
      }).toList();

      if (!mounted) return;

      setState(() {
        _filteredClubs = filtered;
        _isSearching = false;
      });

      if (_userLocation != null) {
        _sortClubsByDistance();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isInitialLoading
          ? _buildLoadingScreen()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Modern App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: true,
                    pinned: true,
                    snap: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.teal.shade600,
                              Colors.teal.shade800,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                'Clubs & Venues',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Find the best sports clubs near you',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(
                                    (255 * 0.8).toInt(),
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      collapseMode: CollapseMode.parallax,
                      expandedTitleScale: 1.0,
                    ),
                  ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withAlpha(
                                (255 * 0.15).toInt(),
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _searchClubs,
                          decoration: InputDecoration(
                            hintText: 'Search clubs by name, city, sport...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.teal.shade700,
                              size: 24,
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
                                      _searchClubs('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Clubs List
                  SliverToBoxAdapter(
                    child: _filteredClubs.isEmpty
                        ? _buildEmptyState()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                ..._filteredClubs.map(
                                  (club) => _buildClubCard(club),
                                ),
                                if (_isLoadingMore)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: CircularProgressIndicator(
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white10, Colors.white30],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha((255 * 0.15).toInt()),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: Colors.teal,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Finding nearby clubs...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Locating sports venues in your area',
              style: TextStyle(
                fontSize: 13,
                color: Colors.teal.withAlpha((255 * 0.7).toInt()),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.white.withAlpha((255 * 0.2).toInt()),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
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
                  ),
                ],
              ),
              child: Icon(
                Icons.location_city_outlined,
                size: 60,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isEmpty ? 'No Clubs Found' : 'No Results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty
                  ? 'Clubs will appear here soon'
                  : 'Try a different search',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubCard(Map<String, dynamic> club) {
    final name = club['name'] as String? ?? 'Club';
    final city = club['city'] as String? ?? 'City';
    final address = club['address'] as String? ?? '';
    final imageUrl =
        (club['images'] as List?)?.first as String? ??
        (club['imageUrl'] as String?) ??
        'https://via.placeholder.com/400x300';
    final rating = (club['rating'] as num?)?.toDouble() ?? 0.0;
    final totalRatings = club['totalRatings'] as int? ?? 0;
    final amenities = club['amenities'] as Map<String, dynamic>? ?? {};
    final location = club['location'] as GeoPoint?;
    final sports = club['sports'] as List? ?? [];

    double distance = 0;
    if (location != null && _userLocation != null) {
      distance = _calculateDistance(location.latitude, location.longitude);
    }

    final distanceInKm = (distance / 1000).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.06).toInt()),
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
              MaterialPageRoute(builder: (_) => ClubDetailsScreen(club: club)),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        );
                      },
                    ),
                  ),
                  // Rating badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((255 * 0.15).toInt()),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '$rating',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' ($totalRatings)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Distance badge
                  if (_userLocation != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade700,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withAlpha((255 * 0.4).toInt()),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$distanceInKm km away',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Club name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$city • $address',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Sports tags
                    if (sports.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (sports)
                            .take(3)
                            .map(
                              (sport) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.teal.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  sport,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.teal.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                    const SizedBox(height: 12),

                    // Amenities
                    if (amenities.isNotEmpty)
                      Row(
                        children: [
                          if (amenities['parking'] == true)
                            _buildAmenityIcon(Icons.local_parking, 'Parking'),
                          if (amenities['wifi'] == true)
                            _buildAmenityIcon(Icons.wifi, 'WiFi'),
                          if (amenities['cafeteria'] == true)
                            _buildAmenityIcon(Icons.restaurant, 'Cafe'),
                          if (amenities['changingRoom'] == true)
                            _buildAmenityIcon(Icons.store, 'Changing'),
                        ],
                      ),

                    const SizedBox(height: 12),

                    // View button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View Club'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClubDetailsScreen(club: club),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmenityIcon(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.teal.shade700),
        ),
      ),
    );
  }
}
