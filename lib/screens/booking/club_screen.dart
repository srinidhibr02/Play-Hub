import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.sport} Clubs'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
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
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search clubs...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // City Filter (Optional)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Chennai', 'Chennai'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Davanagere', 'Davanagere'),
                      const SizedBox(width: 8),
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
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading clubs',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
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
                        Icon(
                          Icons.sports,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No clubs available for ${widget.sport}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_selectedCity != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try selecting a different city',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                var clubs = snapshot.data!;

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
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No clubs found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
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
      label: Text(label),
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
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.teal.shade700 : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildClubCard(BuildContext context, Club club) {
    final price = club.pricePerHour[widget.sport] ?? 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectCourtScreen(club: club, sport: widget.sport),
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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
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
                                  size: 60,
                                  color: Colors.teal.shade300,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Icon(
                              Icons.sports,
                              size: 60,
                              color: Colors.teal.shade300,
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
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          club.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${club.address}, ${club.city}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Phone
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        club.phoneNumber,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Amenities
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getDisplayAmenities(club.amenities).map((
                      amenity,
                    ) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.teal.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getAmenityIcon(amenity),
                              size: 14,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              amenity,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.teal.shade700,
                                fontWeight: FontWeight.w600,
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
                            Icons.currency_rupee,
                            size: 18,
                            color: Colors.teal.shade700,
                          ),
                          Text(
                            '${price.toStringAsFixed(0)}/hour',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
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
        // Convert camelCase to Title Case
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

    // Return max 3 amenities
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
