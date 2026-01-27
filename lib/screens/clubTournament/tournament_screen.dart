import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:play_hub/screens/clubTournament/explore_tournament_screen.dart';
import 'package:play_hub/screens/clubTournament/my_tournament_screen.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitializing = true;
  Position? _userLocation;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    try {
      if (mounted) setState(() => _isInitializing = true);

      await _requestLocationPermission();
      if (_hasLocationPermission) {
        await _getUserLocation();
      }

      if (mounted) {
        setState(() => _isInitializing = false);
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

  Future<void> _requestLocationPermission() async {
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

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _hasLocationPermission = false);
        }
        _showPermissionDialog(
          'Location Permission Needed',
          'Enable location to find tournaments near you',
        );
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _hasLocationPermission = false);
        }
        _showPermissionDialog(
          'Location Permission Denied Forever',
          'Open settings to enable location access',
        );
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        if (mounted) {
          setState(() => _hasLocationPermission = true);
        }
        debugPrint('✅ Location permission granted: $permission');
      }
    } catch (e) {
      debugPrint('❌ Permission error: $e');
    }
  }

  Future<void> _getUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;

      setState(() => _userLocation = position);
      debugPrint('✅ Location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Location error: $e');
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

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildFullScreenLoading();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        backgroundColor: Colors.white70,
        foregroundColor: Colors.teal,
        title: const Text(
          'Tournaments',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 1,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.teal,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.explore, size: 20),
                      SizedBox(width: 8),
                      Text('Explore'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.bookmark, size: 20),
                      SizedBox(width: 8),
                      Text('My Tournaments'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Explore Tournaments Tab
          ExploreTournamentsWidget(
            userLocation: _userLocation,
            hasLocationPermission: _hasLocationPermission,
            onRequestLocation: _requestLocationPermission,
          ),
          // My Tournaments Tab (to be designed later)
          MyTournamentsWidget(onRequestLocation: _requestLocationPermission),
        ],
      ),
    );
  }
}
