import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:play_hub/constants/models.dart';
import 'package:play_hub/screens/booking/court_screen.dart';
import 'package:play_hub/service/booking_service.dart';

class SelectClubScreen extends StatefulWidget {
  final String sport;

  const SelectClubScreen({super.key, required this.sport});

  @override
  State<SelectClubScreen> createState() => _SelectClubScreenState();
}

class _SelectClubScreenState extends State<SelectClubScreen> {
  final BookingService _bookingService = BookingService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCity;
  Position? _userLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.teal.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Loading Container
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                color: Colors.teal.shade700,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 32),
            // Main Loading Text
            Text(
              'Fetching Your Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.teal.shade700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle Text
            Text(
              'Finding clubs near you...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.teal.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            // Progress Bar
            SizedBox(
              width: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.teal.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.teal.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        await _getUserLocation();
      } else {
        debugPrint('⚠️ Location permission not granted');
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _getUserLocation() async {
    try {
      setState(() => _isLoadingLocation = true);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _userLocation = position;
        _isLoadingLocation = false;
      });

      debugPrint('✅ Location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Location error: $e');
      setState(() => _isLoadingLocation = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  double _calculateDistance(double lat, double lng) {
    if (_userLocation == null) return double.infinity;

    return Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      lat,
      lng,
    );
  }

  List<Club> _sortClubsByDistance(List<Club> clubs) {
    if (_userLocation == null) return clubs;

    final clubsWithDistance = clubs.map((club) {
      final distance = _calculateDistance(
        club.location.latitude,
        club.location.longitude,
      );
      return {'club': club, 'distance': distance};
    }).toList();

    clubsWithDistance.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    return clubsWithDistance.map((e) => e['club'] as Club).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return Scaffold(body: _buildLoadingScreen());
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          '${widget.sport} Clubs',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search clubs by name or location...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.teal.shade700,
                        size: 24,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
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
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // City Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: 10),
                      _buildFilterChip('Chennai', 'Chennai'),
                      const SizedBox(width: 10),
                      _buildFilterChip('Davanagere', 'Davanagere'),
                      const SizedBox(width: 10),
                      _buildFilterChip('Bangalore', 'Bangalore'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Clubs List
          Expanded(
            child: StreamBuilder<List<Club>>(
              stream: _bookingService.getClubs(
                sport: widget.sport,
                city: _selectedCity,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.teal.shade700,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading clubs...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading clubs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                                color: Colors.grey.withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.sports_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No clubs available',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No clubs found for ${widget.sport}${_selectedCity != null ? ' in $_selectedCity' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_selectedCity != null) ...[
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _selectedCity = null);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('View All Cities'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                var clubs = snapshot.data!;

                // Sort by distance if location is available
                if (_userLocation != null) {
                  clubs = _sortClubsByDistance(clubs);
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  clubs = clubs.where((club) {
                    return club.name.toLowerCase().contains(_searchQuery) ||
                        club.address.toLowerCase().contains(_searchQuery) ||
                        club.city.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (clubs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No clubs found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: clubs.length,
                  itemBuilder: (context, index) {
                    return _buildClubCard(context, clubs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? city) {
    final isSelected = _selectedCity == city;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCity = selected ? city : null;
        });
      },
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.teal.shade700 : Colors.grey.shade700,
      ),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
          width: isSelected ? 2 : 1.5,
        ),
      ),
    );
  }

  Widget _buildClubCard(BuildContext context, Club club) {
    final price = club.pricePerHour[widget.sport] ?? 0.0;
    final allowBookings = club.allowBookings ?? true;
    final isDisabled = !allowBookings;

    // Calculate distance
    final distance = _calculateDistance(
      club.location.latitude,
      club.location.longitude,
    );
    final distanceInKm = (distance / 1000).toStringAsFixed(1);

    // Distance color based on proximity
    Color distanceColor;
    if (distance < 5000) {
      distanceColor = Colors.green.shade400;
    } else if (distance < 15000) {
      distanceColor = Colors.orange.shade400;
    } else {
      distanceColor = Colors.red.shade400;
    }

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SelectCourtScreen(club: club, sport: widget.sport),
                ),
              );
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDisabled ? 0.03 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Club Image with Rating Badge
                Stack(
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: club.imageUrl.isNotEmpty
                            ? Image.network(
                                club.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.sports,
                                      size: 64,
                                      color: Colors.teal.shade300,
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          color: Colors.teal.shade700,
                                        ),
                                      );
                                    },
                              )
                            : Center(
                                child: Icon(
                                  Icons.sports,
                                  size: 64,
                                  color: Colors.teal.shade300,
                                ),
                              ),
                      ),
                    ),
                    // Booking Status Overlay
                    if (isDisabled)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: Container(
                          height: 180,
                          color: Colors.black.withOpacity(0.4),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bookings Closed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Rating Badge
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
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              club.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Distance Badge
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
                            color: distanceColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: distanceColor.withOpacity(0.4),
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
                                '$distanceInKm km',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Club Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Club Name
                      Text(
                        club.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDisabled
                              ? Colors.grey.shade500
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

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
                              '${club.address}, ${club.city}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Phone
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            club.phoneNumber,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Amenities
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _getDisplayAmenities(club.amenities).map((
                          amenity,
                        ) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDisabled
                                  ? Colors.grey.shade200
                                  : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDisabled
                                    ? Colors.grey.shade300
                                    : Colors.teal.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getAmenityIcon(amenity),
                                  size: 14,
                                  color: isDisabled
                                      ? Colors.grey.shade500
                                      : Colors.teal.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  amenity,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDisabled
                                        ? Colors.grey.shade500
                                        : Colors.teal.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Price and Arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.currency_rupee_rounded,
                                size: 20,
                                color: isDisabled
                                    ? Colors.grey.shade400
                                    : Colors.teal.shade700,
                              ),
                              Text(
                                '${price.toStringAsFixed(0)}/hour',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDisabled
                                      ? Colors.grey.shade400
                                      : Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDisabled
                                  ? Colors.grey.shade200
                                  : Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: isDisabled
                                  ? Colors.grey.shade400
                                  : Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Disabled Overlay
            if (isDisabled)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _getDisplayAmenities(Map<String, dynamic> amenities) {
    final List<String> displayAmenities = [];

    amenities.forEach((key, value) {
      if (value == true) {
        String displayName = key
            .replaceAllMapped(
              RegExp(r'([A-Z])'),
              (match) => ' ${match.group(1)}',
            )
            .trim();
        displayName = displayName[0].toUpperCase() + displayName.substring(1);
        displayAmenities.add(displayName);
      }
    });

    return displayAmenities.take(3).toList();
  }

  IconData _getAmenityIcon(String amenity) {
    final lowerAmenity = amenity.toLowerCase();

    if (lowerAmenity.contains('parking')) return Icons.local_parking;
    if (lowerAmenity.contains('changing') || lowerAmenity.contains('room')) {
      return Icons.meeting_room;
    }
    if (lowerAmenity.contains('cafeteria') || lowerAmenity.contains('cafe')) {
      return Icons.restaurant;
    }
    if (lowerAmenity.contains('first') || lowerAmenity.contains('aid')) {
      return Icons.medical_services;
    }
    if (lowerAmenity.contains('wifi')) return Icons.wifi;

    return Icons.check_circle;
  }
}
