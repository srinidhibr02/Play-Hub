import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:play_hub/screens/clubTournament/tournament_details_screen.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  // NEW: Main initialization loading state
  bool _isInitializing = true;

  Position? _userLocation;
  bool _isLoadingLocation = false;
  bool _hasLocationPermission = false;
  String _permissionStatus = '';

  List<Map<String, dynamic>> _allTournaments = [];
  List<Map<String, dynamic>> _filteredTournaments = [];
  bool _isLoadingTournaments = false;
  bool _isSearching = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      if (mounted) setState(() => _isInitializing = true);

      await _requestLocationPermissionImproved();
      if (_hasLocationPermission) {
        await _getUserLocation();
      }
      await _fetchTournaments();

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _fadeController.forward();
        });
      }
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to load: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // NEW: Full screen loading widget
  Widget _buildFullScreenLoading() {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white70, Colors.white70],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.2),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  onEnd: () {
                    // Restart pulse animation
                  },
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withAlpha((255 * 0.3).toInt()),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 48,
                          color: Colors.teal,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Column(
                  children: [
                    Text(
                      'Loading Tournaments',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.teal,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Finding events near you...',
                      style: TextStyle(fontSize: 16, color: Colors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((255 * 0.15).toInt()),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha((255 * 0.9).toInt()),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestLocationPermissionImproved() async {
    try {
      debugPrint('📍 Checking location services...');

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }

      if (mounted) {
        setState(() {
          _permissionStatus = permission.toString();
        });
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _permissionStatus = 'Permission denied';
          });
        }
        _showPermissionDialog(
          'Location Permission Needed',
          'Enable location to find tournaments near you',
        );
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = false;
            _permissionStatus = 'Permission denied forever';
          });
        }
        _showPermissionDialog(
          'Location Permission Denied Forever',
          'Open settings to enable location access',
        );
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (mounted) {
          setState(() {
            _hasLocationPermission = true;
            _permissionStatus = 'Location enabled';
          });
        }
        debugPrint('✅ Location permission granted: $permission');
      }
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      if (mounted) {
        setState(() {
          _permissionStatus = 'Error: $e';
        });
      }
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_disabled, color: Colors.orange),
            SizedBox(width: 12),
            Text('Location Services Off'),
          ],
        ),
        content: const Text(
          'Please enable location services in device settings',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getUserLocation() async {
    try {
      if (mounted) {
        setState(() => _isLoadingLocation = true);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;

      setState(() {
        _userLocation = position;
        _isLoadingLocation = false;
      });

      debugPrint('✅ Location: ${position.latitude}, ${position.longitude}');
      _sortTournamentsByDistance();
    } catch (e) {
      debugPrint('❌ Location error: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Location error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _fetchTournaments() async {
    try {
      if (mounted) {
        setState(() => _isLoadingTournaments = true);
      }
      debugPrint('📥 Fetching tournaments from Firestore...');

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
            '✅ Tournament: ${merged['name'] ?? 'Unknown'} - Club: ${clubData['name'] ?? 'Unknown'}',
          );
        } catch (e) {
          debugPrint('⚠️ Error processing tournament ${tournamentDoc.id}: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        _allTournaments = tournaments;
        _filteredTournaments = tournaments;
        _isLoadingTournaments = false;
      });

      debugPrint('✅ Fetched ${tournaments.length} tournaments with club data');

      if (_userLocation != null) {
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

  double _calculateDistance(double lat, double lng) {
    if (_userLocation == null) return 0;
    return Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
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
      if (query.trim().isEmpty) {
        setState(() {
          _filteredTournaments = List.from(_allTournaments);
          _isSearching = false;
        });
        if (_userLocation != null) _sortTournamentsByDistance();
        return;
      }

      final q = query.toLowerCase().trim();
      final filtered = _allTournaments.where((t) {
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

      if (!mounted) return;

      setState(() {
        _filteredTournaments = filtered;
        _isSearching = false;
      });
    });
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.teal,
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
      },
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
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Show full-screen loading during initialization
    if (_isInitializing) {
      return _buildFullScreenLoading();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              expandedHeight: 80,
              floating: true,
              pinned: true,
              snap: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              forceElevated: false,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.teal.shade600,
                        Colors.teal.shade700,
                        Colors.teal.shade800,
                      ],
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(right: 16.0, top: 80),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Tournaments',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 25,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (_hasLocationPermission && _userLocation != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((255 * 0.2).toInt()),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLoadingLocation
                                    ? Icons.refresh
                                    : Icons.location_on_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isLoadingLocation ? 'Live' : 'Nearby',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                centerTitle: false,
                expandedTitleScale: 1.1,
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'search_bar',
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
                                : IconButton(
                                    icon: Icon(
                                      Icons.tune_rounded,
                                      color: Colors.grey.shade500,
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Filters coming soon!'),
                                        ),
                                      );
                                    },
                                  ),
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
                    const SizedBox(height: 20),
                    if (!_hasLocationPermission)
                      GestureDetector(
                        onTap: _requestLocationPermissionImproved,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade50,
                                Colors.amber.shade50,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.shade200,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withAlpha(
                                  (255 * 0.2).toInt(),
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
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
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: _isLoadingTournaments
                  ? _buildLoadingShimmer()
                  : _filteredTournaments.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: _filteredTournaments.length,
                      itemBuilder: (context, index) {
                        return _buildTournamentCard(
                          _filteredTournaments[index],
                        );
                      },
                    ),
            ),
          ],
        ),
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
                ? 'No Tournaments Yet'
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
                ? 'Tournaments will appear here soon'
                : 'Try different keywords',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _requestLocationPermissionImproved,
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
    final club = tournament['club'] as Map<String, dynamic>? ?? {};
    final clubName = club['name'] as String? ?? 'Unknown Club';
    final clubCity = club['city'] as String? ?? 'Unknown City';
    final location = club['location'] as GeoPoint?;

    double distance = 0;
    if (location != null && _userLocation != null) {
      distance = _calculateDistance(location.latitude, location.longitude);
    }

    final distanceInKm = (distance / 1000).toStringAsFixed(1);
    final distanceColor = distance < 5000
        ? Colors.green
        : distance < 10000
        ? Colors.orange
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigate to $tournamentName details')),
            );
          },
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
                    if (_userLocation != null && distance > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: distanceColor.withAlpha((255 * 0.1).toInt()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: distanceColor.withAlpha((255 * 0.4).toInt()),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$distanceInKm km',
                          style: TextStyle(
                            fontSize: 13,
                            color: distanceColor,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }
}
